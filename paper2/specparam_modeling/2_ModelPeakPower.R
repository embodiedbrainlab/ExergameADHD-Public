# Model Peaks Data
# This script creates linear models for spectral parameter outcomes from a wide dataframe
# with outcome variables starting with "diff_".
# 
# Two types of outcomes are modeled:
# 1. Regular intervention outcomes: diff_{outcome} = intervention_{outcome} - baseline_{outcome}
#    Model form: diff_{outcome} ~ intervention + baseline_{outcome} + covariates
#
# 2. Baseline task outcomes: diff calculated from baseline TASK during intervention SESSION
#    e.g., diff_3_baseline_high_beta = intervention_3_postbaseline_high_beta - intervention_3_prebaseline_high_beta
#    Model form: diff_{outcome} ~ intervention + intervention_{#}_prebaseline_{frequency_band} + covariates
#
# The script automatically identifies baseline task outcomes (those containing "baseline" in name)
# and applies the appropriate model structure to each outcome type.
#
# Each model reports the number of complete cases used in the analysis.
#
# Originally written by Noor Tasnim on November 15, 2025
#
# --- EDITS ---
# Nov. 16 - We will need a linear mixed effects model to account for trials in
# balance tasks. So they will need to go through a separate process.

# Import Libraries and Data -----------------------------------------------
library(tidyverse)
library(readxl)
library(ggbeeswarm)
library(tidyr)
library(broom)
library(janitor)
library(lme4)
library(broom.mixed)
library(lmerTest)

demographics <- readRDS("../demographicsPsych/results/Paper2_BaseDataForModeling.rds")
peaks <- read_csv("results/peaks_modeling_df.csv") %>%
  mutate(participant_id = as.numeric(gsub("exgm", "", subject)), .before = 1) %>%
  select(-subject)

# Merge Dataframes
joined_df <- demographics %>%
  left_join(peaks, by = "participant_id")

#### Balance Dataframe for Modeling ####
balance <- joined_df %>%
  select(participant_id:asrs_18_total, contains("shoulder"), contains("tandem")) %>%
  select(-contains("diff_"))

#### General Dataframe for Modeling ####
specparam_model_df <- joined_df %>%
  select(-contains("shoulder"), -contains("tandem"))


# Create Balance Long Dataframe -----------------------------------

balance_long <- balance %>%
  pivot_longer(
    cols = -c(participant_id, intervention, days_diff, min_diff, sex_male, stimulant, 
              antidepressant, asrs_18_total),
    names_to = c("session", "cluster", "stance", "trial", "frequency_band"),
    names_pattern = "^([^_]+)_([^_]+)_([^_]+)_([^_]+)_(.+)$",
    values_to = "power"
  ) %>%
  mutate(
    # Factor trial with specified levels
    trial = factor(trial, levels = c("1", "2", "3")),
    
    # Rename session levels
    session = factor(session, 
                     levels = c("baseline", "intervention"),
                     labels = c("session1", "session2")),
    
    # Turn column in numeric values
    cluster = as.numeric(cluster)
  ) %>%
  filter(!cluster %in% c(3,5,10,11)) %>%
  # Widen dataframe a little by using FrequencyBand_power
  pivot_wider(
    names_from = frequency_band,
    values_from = power,
    names_glue = "{frequency_band}_power"
  )


# Linear Mixed Effects Modeling for Balance ------------------------------

#### Define frequency bands and stances ####
frequency_bands <- c("theta", "alpha", "low_beta", "high_beta", "gamma")
stances <- c("shoulder", "tandem")

#### Define common covariates ####
covariates <- c("days_diff", "min_diff", "sex_male", 
                "stimulant", "antidepressant", "asrs_18_total")

#### Function to fit and summarize lmer models ####
fit_lmer_model <- function(cluster_val, stance_val, freq_band, data, return_model = FALSE) {
  # Filter data for specific cluster and stance
  filtered_data <- data %>%
    filter(cluster == cluster_val, stance == stance_val)
  
  # Count rows before fitting
  n_rows_filtered <- nrow(filtered_data)
  
  # Build outcome variable name
  outcome_var <- paste0(freq_band, "_power")
  
  # Build formula dynamically
  formula_str <- paste0(
    outcome_var, " ~ session*intervention + trial + ",
    paste(covariates, collapse = " + "),
    " + (1 | participant_id)"
  )
  
  # Fit model with error handling
  model <- tryCatch({
    lmer(as.formula(formula_str), data = filtered_data)
  }, error = function(e) {
    return(NULL)
  })
  
  # If return_model = TRUE, just return the model object
  if (return_model) {
    return(model)
  }
  
  if (is.null(model)) {
    # Return empty tibble with metadata if model fails
    return(tibble(
      cluster = cluster_val,
      stance = stance_val,
      frequency_band = freq_band,
      outcome = outcome_var,
      n_rows_filtered = n_rows_filtered,
      n_complete_cases = NA,
      n_missing = NA,
      model_status = "failed"
    ))
  }
  
  # Count complete cases used in model
  n_complete <- nobs(model)
  
  # Return tidy results with metadata
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    filter(effect == "fixed") %>%  # Only keep fixed effects
    select(term, estimate, std.error, statistic, conf.low, conf.high, p.value) %>%
    mutate(
      cluster = cluster_val,
      stance = stance_val,
      frequency_band = freq_band,
      outcome = outcome_var,
      n_rows_filtered = n_rows_filtered,
      n_complete_cases = n_complete,
      n_missing = n_rows_filtered - n_complete,
      model_status = "success",
      .before = 1
    )
}

#### Get unique clusters ####
clusters <- sort(unique(balance_long$cluster))

#### Fit all models and get tidy results ####
balance_results <- expand_grid(
  cluster = clusters,
  stance = stances,
  frequency_band = frequency_bands
) %>%
  pmap_df(function(cluster, stance, frequency_band) {
    fit_lmer_model(cluster, stance, frequency_band, balance_long, return_model = FALSE)
  })

#### Store actual model objects in a list ####
balance_model_list <- expand_grid(
  cluster = clusters,
  stance = stances,
  frequency_band = frequency_bands
) %>%
  pmap(function(cluster, stance, frequency_band) {
    fit_lmer_model(cluster, stance, frequency_band, balance_long, return_model = TRUE)
  })

# Create meaningful names for the list
balance_model_names <- expand_grid(
  cluster = clusters,
  stance = stances,
  frequency_band = frequency_bands
) %>%
  mutate(name = paste0("cluster", cluster, "_", stance, "_", frequency_band)) %>%
  pull(name)

names(balance_model_list) <- balance_model_names

# Defining Outcome Variables for Cognitive Power ----------------------------------------------
outcomes <- names(specparam_model_df) %>%
  .[grepl("^diff_", .)] %>%
  sub("^diff_", "", .)

# Create Model Outcomes and Functions -------------------------------------

#### Separate baseline task outcomes from regular intervention outcomes ####
# Baseline task outcomes contain "baseline" in their name (e.g., "3_baseline_high_beta")
baseline_task_outcomes <- outcomes[grepl("baseline", outcomes)]
regular_outcomes <- outcomes[!grepl("baseline", outcomes)]

#### Define common covariates ####
covariates <- c("days_diff", "min_diff", "sex_male", 
                "stimulant","antidepressant", "asrs_18_total")

#### Function to fit and summarize models for REGULAR intervention outcomes ####
fit_regular_model <- function(outcome, data, covariates) {
  # Build formula dynamically
  formula_str <- paste0(
    "diff_", outcome, " ~ intervention + baseline_", outcome, " + ",
    paste(covariates, collapse = " + ")
  )
  
  # Fit model
  model <- lm(as.formula(formula_str), data = data)
  
  # Count complete cases
  n_complete <- nobs(model)
  
  # Return tidy results with complete case count
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    select(term, estimate, conf.low, conf.high, p.value) %>%
    mutate(
      outcome = outcome,
      n_complete_cases = n_complete,
      model_type = "regular_intervention",
      .before = 1
    )
}

#### Function to fit and summarize models for BASELINE TASK outcomes ####
# These use intervention_#_prebaseline_{frequency_band} as the baseline covariate
fit_baseline_task_model <- function(outcome, data, covariates) {
  # For baseline task outcomes, construct the prebaseline variable name
  # e.g., if outcome is "3_baseline_high_beta", baseline var is "intervention_3_prebaseline_high_beta"
  baseline_var <- paste0("intervention_", outcome)
  baseline_var <- gsub("_baseline_", "_prebaseline_", baseline_var)
  
  # Build formula dynamically
  formula_str <- paste0(
    "diff_", outcome, " ~ intervention + ", baseline_var, " + ",
    paste(covariates, collapse = " + ")
  )
  
  # Fit model
  model <- lm(as.formula(formula_str), data = data)
  
  # Count complete cases
  n_complete <- nobs(model)
  
  # Return tidy results with complete case count
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    select(term, estimate, conf.low, conf.high, p.value) %>%
    mutate(
      outcome = outcome,
      n_complete_cases = n_complete,
      model_type = "baseline_task",
      baseline_variable_used = baseline_var,
      .before = 1
    )
}


# Apply Functions ---------------------------------------------------------
# Apply function to regular outcomes
regular_results <- map_df(regular_outcomes, ~fit_regular_model(.x, specparam_model_df, covariates))

# Apply function to baseline task outcomes
baseline_task_results <- map_df(baseline_task_outcomes, ~fit_baseline_task_model(.x, specparam_model_df, covariates))


# Organize Model Results --------------------------------------------------

#### Combine all results ####
model_results <- bind_rows(regular_results, baseline_task_results) %>%
  arrange(outcome)

#### Create separate lists by outcome if preferred ####
regular_results_list <- map(regular_outcomes, ~fit_regular_model(.x, specparam_model_df, covariates))
names(regular_results_list) <- regular_outcomes

baseline_task_results_list <- map(baseline_task_outcomes, ~fit_baseline_task_model(.x, specparam_model_df, covariates))
names(baseline_task_results_list) <- baseline_task_outcomes

#### Combined list ####
results_list <- c(regular_results_list, baseline_task_results_list)

#### Create summary of complete cases by outcome ####
complete_cases_summary <- model_results %>%
  select(outcome, model_type, n_complete_cases) %>%
  distinct() %>%
  arrange(desc(n_complete_cases))

# Save Model Objects for Further Analysis ---------------------------------

save(specparam_model_df, balance_long, balance_results, balance_model_list, 
     model_results, results_list, complete_cases_summary, 
     file = "results/peak_power_models.RData")
