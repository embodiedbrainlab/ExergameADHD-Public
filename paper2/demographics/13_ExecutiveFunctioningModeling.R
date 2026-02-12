# Studying the Effects of Intervention on EF Outcomes
# We will use the EF outcomes reported in Paper 1:
# https://docs.google.com/document/d/1HwB-mlos-8Y7g1gQOBp6-oBxWDNDKrQvo3tGxzw3JFE/edit?usp=sharing
# 
# The first step will be to extract the raw values from the Inquisit Excel Files
# located in "demographicsPsych/data/inquisit/", which contains separate 
# folders for "baseline" and "intervention"
#
# Each spreadsheet should only pull the variables of interest. There are also
# three cases where values should be replaced with NAs, they are documented 
# here:
# https://drive.google.com/file/d/1JUMyhc_tUM5hLyBxU0xaFz0iglXwsLyL/view?usp=sharing
#     - exgm108_s1_gonogo - did not respond at all
#     - exgm136_s1_gonogo - misread instructions
#     - exgm021_s2_gonogo - pressed space bar on no-go
# 
# Written by Noor Tasnim on November 14, 2025

# Import Libraries and Data -----------------------------------------------

library(tidyverse)
library(readxl)
library(ggbeeswarm)
library(tidyr)
library(broom)
library(janitor)

demographics <- readRDS("results/Paper2_BaseDataForModeling.rds")

# Go/No-Go ---------------------------------------------------------

#### Define Participants to be excluded ####
gonogo_baseline_exclude_ids <- c(108,136) #exgm108 and exgm136 for session 1
gonogo_intervention_exclude_ids <- c(21)

#### Import Baseline Data ####
gonogo_baseline_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_cuedgonogo_summary_merge.xlsx") %>%
  select(subjectid,meanrt_verticalcue_gotarget,meanrt_horizontalcue_gotarget) %>%
  mutate(across(c(meanrt_verticalcue_gotarget, meanrt_horizontalcue_gotarget), as.numeric)) %>%
  rename_with(~ paste0("baseline_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(baseline_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-baseline_subjectid) %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) %>% # exclude dropouts
  # Replace excluded participants' values with NA
  mutate(across(-participant_id, 
                ~ifelse(participant_id %in% gonogo_baseline_exclude_ids, NA, .)))

#### Import Intervention Data ####
gonogo_intervention_ef <- read_excel("../demographicsPsych/data/inquisit/intervention/intervention_cuedgonogo_summary_merge.xlsx") %>%
  select(subjectid,meanrt_verticalcue_gotarget,meanrt_horizontalcue_gotarget) %>%
  mutate(across(c(meanrt_verticalcue_gotarget, meanrt_horizontalcue_gotarget), as.numeric)) %>%
  rename_with(~ paste0("intervention_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(intervention_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-intervention_subjectid) %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) %>% # exclude dropouts
  # Replace excluded participants' values with NA
  mutate(across(-participant_id, 
                ~ifelse(participant_id %in% gonogo_intervention_exclude_ids, NA, .)))

#### Modeling Dataframe ####
gonogo <- gonogo_baseline_ef %>%
  left_join(gonogo_intervention_ef, by = "participant_id") %>%
  mutate(
    diff_meanrt_verticalcue_gotarget = intervention_meanrt_verticalcue_gotarget - baseline_meanrt_verticalcue_gotarget,
    diff_meanrt_horizontalcue_gotarget = intervention_meanrt_horizontalcue_gotarget - baseline_meanrt_horizontalcue_gotarget,
  )

# WCST -----------------------------------------------------------

#### Import Baseline Data ####
wcst_baseline_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_wcst_summary_merge.xlsx") %>%
  clean_names() %>%
  select(subjectid,percent_p_errors,learning_to_learn) %>%
  rename_with(~ paste0("baseline_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(baseline_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-baseline_subjectid) %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) # exclude dropouts

#### Import Intervention Data ####
wcst_intervention_ef <- read_excel("../demographicsPsych/data/inquisit/intervention/intervention_wcst_summary_merge.xlsx") %>%
  clean_names() %>%
  select(subjectid,percent_p_errors,learning_to_learn) %>%
  rename_with(~ paste0("intervention_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(intervention_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-intervention_subjectid)

#### Modeling Dataframe ####
wcst <- wcst_baseline_ef %>%
  left_join(wcst_intervention_ef, by = "participant_id") %>%
  mutate(diff_percent_p_errors = intervention_percent_p_errors - baseline_percent_p_errors,
         diff_learning_to_learn = intervention_learning_to_learn - baseline_learning_to_learn)

# Stroop ------------------------------------------------------------------

#### Import Baseline Data ####
stroop_baseline_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_stroopwithcontrolkeyboard_summary_merge.xlsx") %>%
  select(subjectid,propcorrect_congruent:meanRTcorr_control) %>%
  rename_with(~ paste0("baseline_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(baseline_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-baseline_subjectid) %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) # exclude dropouts

#### Import Intervention Data ####
stroop_intervention_ef <- read_excel("../demographicsPsych/data/inquisit/intervention/intervention_stroopwithcontrolkeyboard_summary_merge.xlsx") %>%
  select(subjectid,propcorrect_congruent:meanRTcorr_control) %>%
  rename_with(~ paste0("intervention_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(intervention_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-intervention_subjectid)

#### Calculate Change ####

# Merge Datasets for Calculations
stroop_merge <- stroop_baseline_ef %>%
  left_join(stroop_intervention_ef, by = "participant_id")

# Extract variable names from baseline columns
baseline_cols <- grep("^baseline", names(stroop_merge), value = TRUE)
var_names <- sub("^baseline_?", "", baseline_cols)

# Create difference columns
diff_data <- map_dfc(var_names, function(var) {
  baseline <- stroop_merge[[paste0("baseline_", var)]]
  intervention <- stroop_merge[[paste0("intervention_", var)]]
  tibble(!!paste0("diff_", var) := intervention - baseline)
})

#### Modeling Dataframe ####
stroop <- bind_cols(stroop_merge, diff_data)

# Digit Span --------------------------------------------------------------

#### Import Baseline Data ####
digitspan_baseline_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_digitspanvisual_summary_merge.xlsx") %>%
  select(subjectid,fTE_ML,bTE_ML) %>%
  rename_with(~ paste0("baseline_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(baseline_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-baseline_subjectid) %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) # exclude dropouts

#### Import Intervention Data ####
digitspan_intervention_ef <- read_excel("../demographicsPsych/data/inquisit/intervention/intervention_digitspanvisual_summary_merge.xlsx") %>%
  select(subjectid,fTE_ML,bTE_ML) %>%
  rename_with(~ paste0("intervention_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(intervention_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-intervention_subjectid)

#### Modeling Dataframe ####
digitspan <- digitspan_baseline_ef %>%
  left_join(digitspan_intervention_ef, by = "participant_id") %>%
  mutate(
    diff_fTE_ML = intervention_fTE_ML - baseline_fTE_ML,
    diff_bTE_ML = intervention_bTE_ML - baseline_bTE_ML
  )


# Compile EF Modeling Dataframe -------------------------------------------

ef_modeling_df <- demographics %>%
  left_join(gonogo, by = "participant_id") %>%
  left_join(wcst, by = "participant_id") %>%
  left_join(stroop, by = "participant_id") %>%
  left_join(digitspan, by = "participant_id")

write_csv(ef_modeling_df, "results/Paper2_EFmodeling_df.csv")

# Model EF Outcomes -------------------------------------------------------

#Define outcome variables
outcomes <- c("meanrt_verticalcue_gotarget", 
              "meanrt_horizontalcue_gotarget","percent_p_errors", "learning_to_learn",
              "propcorrect_congruent", "propcorrect_incongruent", 
              "propcorrect_control", "meanRTcorr_congruent", "meanRTcorr_incongruent", 
              "meanRTcorr_control","fTE_ML", "bTE_ML")

# Define common covariates
covariates <- c("days_diff", "min_diff", "sex_male", "stimulant", 
                "antidepressant", "asrs_18_total")

# Create a function to fit and summarize models
fit_model <- function(outcome, data, covariates) {
  # Build formula dynamically
  formula_str <- paste0(
    "diff_", outcome, " ~ intervention + baseline_", outcome, " + ",
    paste(covariates, collapse = " + ")
  )
  
  # Fit model
  model <- lm(as.formula(formula_str), data = data)
  
  # Return tidy results
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    select(term, estimate, conf.low, conf.high, p.value) %>%
    mutate(outcome = outcome, .before = 1)  # Add outcome identifier
}

# Apply function to all outcomes
model_results <- map_df(outcomes, ~fit_model(.x, ef_modeling_df, covariates))

# Separate by outcome if preferred
results_list <- map(outcomes, ~fit_model(.x, ef_modeling_df, covariates))
names(results_list) <- outcomes

# Visualize Effect of Intervention on All EF Outcomes ---------------------

model_results %>%
  filter(term %in% c("interventionBiking", "interventionDance")) %>%
  mutate(
    outcome = str_remove(outcome, "_total"),
    outcome = str_replace_all(outcome, "_", " "),
    outcome = str_to_title(outcome),
    intervention = str_remove(term, "intervention"),
    significant = if_else(p.value < 0.05, "Yes", "No")
  ) %>%
  ggplot(aes(x = estimate, y = reorder(outcome, estimate))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(aes(color = significant), size = 3) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high, color = intervention),
                width = 0.2,
                orientation = "y") +
  scale_color_manual(values = c("No" = "gray60", "Yes" = "#2E86AB")) +
  facet_wrap(~intervention, ncol = 2) +
  labs(
    title = "Intervention Effects: Biking vs Dance",
    x = "Effect Size (95% CI)",
    y = "Outcome",
    color = "p < 0.05"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")


# General Summary Statistics ----------------------------------------------

EF_summary <- ef_modeling_df %>%
  select(participant_id, intervention,
         baseline_meanrt_verticalcue_gotarget, baseline_meanrt_horizontalcue_gotarget, 
         intervention_meanrt_verticalcue_gotarget, intervention_meanrt_horizontalcue_gotarget, 
         baseline_percent_p_errors, baseline_learning_to_learn, intervention_percent_p_errors, 
         intervention_learning_to_learn, baseline_propcorrect_congruent, baseline_propcorrect_incongruent, 
         baseline_propcorrect_control, baseline_meanRTcorr_congruent, baseline_meanRTcorr_incongruent, 
         baseline_meanRTcorr_control, intervention_propcorrect_congruent, intervention_propcorrect_incongruent, 
         intervention_propcorrect_control, intervention_meanRTcorr_congruent, intervention_meanRTcorr_incongruent, 
         intervention_meanRTcorr_control, baseline_fTE_ML, baseline_bTE_ML, intervention_fTE_ML, intervention_bTE_ML) %>%
  pivot_longer(
    cols = -c(participant_id, intervention),
    names_to = "measure",
    values_to = "value"
  ) %>%
  # Extract session and variable name
  mutate(
    session = if_else(grepl("^baseline_", measure), "Session 1", "Session 2"),
    Variable = sub("^(baseline|intervention)_", "", measure)
  ) %>%
  # Calculate summary statistics
  group_by(intervention, session, Variable) %>%
  summarise(
    Mean = mean(value, na.rm = TRUE),
    SD = sd(value, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(
    cell_value = sprintf("%.2f (%.2f)", Mean, SD)
  ) %>%
  pivot_wider(
    id_cols = Variable,
    names_from = c(intervention, session),
    values_from = cell_value,
    names_sep = "_"
  ) %>%
  arrange(Variable)

write_csv(EF_summary,"results/EF_summary.csv")


# Full Report on Executive Function Models --------------------------------

model_export <- model_results %>%
  filter(term == "interventionBiking" | term == "interventionDance" | term == "sex_male" | str_detect(term, "baseline"))
write_csv(model_export, "results/EF_models_full.csv")


# Summary Differences for WCST Differences --------------------------------

wcst_stats <- ef_modeling_df %>%
  select(participant_id, intervention, 
         diff_percent_p_errors, diff_learning_to_learn) %>%
  pivot_longer(cols = starts_with("diff_"),
               names_to = "measure",
               values_to = "value") %>%
  group_by(intervention, measure) %>%
  summarize(
    mean_diff = mean(value, na.rm = TRUE),
    sd_diff = sd(value, na.rm = TRUE),
    n = sum(!is.na(value)),
    .groups = "drop"
  )

write_csv(wcst_stats,"results/wcst_stats.csv")