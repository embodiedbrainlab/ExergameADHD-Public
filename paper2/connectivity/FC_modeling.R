# Model Functional Connectivity Data
# Up to this point, you've reshaped functional connectivity data using 
# '../statistical_modeling/reshapeROIconnect.m', which created a .csv file
# that summarized DMN and DAN connectivity from the ROIconnect matrices
# produced by MATLAB.
#
# Using this .csv file, we created properly structured dataframes to run 
# three categories of models:
# 1) Linear mixed effects models for balance data
# 2) Linear Models for cognition data
# 3) Linear Models for baseline data
#
# Written by Noor Tasnim on November 17, 2025


# Import Libraries and Data -----------------------------------------------

library(tidyverse)
library(lme4)
library(lmerTest)
library(broom)
library(broom.mixed)

load("results/roiConnect_modeling_data.RData")


# BALANCE FC -------------------------------
# 4 total models (stance x 2) x (connectivity x 2)

#### Filter by Stance ####
tandem_df <- balance_model_df %>%
  filter(stance == "tandem")

shoulder_df <- balance_model_df %>%
  filter(stance == "shoulder")

#### Run Models ####
# Shoulder DMN
shoulder_DMN <- lmer(DMN_connectivity ~ session*intervention + trial + days_diff + 
                             min_diff + sex_male + stimulant + antidepressant + 
                             asrs_18_total + (1 | participant_id),
                           data = shoulder_df)

# Shoulder DAN
shoulder_DAN <- lmer(DAN_connectivity ~ session*intervention + trial + days_diff + 
                       min_diff + sex_male + stimulant + antidepressant + 
                       asrs_18_total + (1 | participant_id),
                     data = shoulder_df)

# Tandem DMN
tandem_DMN <- lmer(DMN_connectivity ~ session*intervention + trial + days_diff + 
                       min_diff + sex_male + stimulant + antidepressant + 
                       asrs_18_total + (1 | participant_id),
                     data = tandem_df)

# Tandem DAN
tandem_DAN <- lmer(DAN_connectivity ~ session*intervention + trial + days_diff + 
                       min_diff + sex_male + stimulant + antidepressant + 
                       asrs_18_total + (1 | participant_id),
                     data = tandem_df)

#### Store Model Results ####
# Store models in a named list
models <- list(
  Shoulder_DMN = shoulder_DMN,
  Shoulder_DAN = shoulder_DAN,
  Tandem_DMN = tandem_DMN,
  Tandem_DAN = tandem_DAN
)

# Apply tidy to all models and combine
balance_model_results <- map_dfr(models, 
                            ~tidy(.x, effects = "fixed", conf.int = TRUE) %>%
                              select(term, estimate, std.error, statistic, conf.low, conf.high, p.value),
                            .id = "model"
)

# Visualize Effects of Interventions on BALANCE --------------------------------------

balance_model_results %>%
  filter(term %in% c("sessionsession2:interventionBiking", "sessionsession2:interventionDance")) %>%
  mutate(
    # Parse model name into components
    stance = str_extract(model, "^[^_]+"),  # Shoulder or Tandem
    network = str_extract(model, "[^_]+$"), # DMN or DAN
    outcome = paste(stance, network, sep = " - "),
    
    # Extract intervention type
    intervention = case_when(
      str_detect(term, "Biking") ~ "Biking",
      str_detect(term, "Dance") ~ "Dance"
    ),
    
    # Determine if it's main effect or interaction
    effect_type = if_else(str_detect(term, ":"), "Interaction (Session × Intervention)", "Main Effect (Intervention)"),
    
    # Significance flag
    significant = if_else(p.value < 0.05, "Yes", "No")
  ) %>%
  ggplot(aes(x = estimate, y = reorder(outcome, estimate))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(aes(color = significant), size = 3) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high, color = significant),
                width = 0.2) +
  scale_color_manual(values = c("No" = "gray60", "Yes" = "#2E86AB")) +
  facet_grid(effect_type ~ intervention) +
  labs(
    title = "Intervention Effects on Balance-Related Connectivity",
    subtitle = "Linear Mixed Effects Models: Stance × Network",
    x = "Effect Size (95% CI)",
    y = "Outcome (Stance - Network)",
    color = "p < 0.05"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold")
  )


# COGNITIVE FC ----------------------------------------

#Define outcome variables
outcomes <- c("DMN_connectivity_digitbackward","DMN_connectivity_digitforward","DMN_connectivity_gonogo",
              "DMN_connectivity_stroop","DMN_connectivity_wcst","DAN_connectivity_digitbackward",
              "DAN_connectivity_digitforward","DAN_connectivity_gonogo","DAN_connectivity_stroop",
              "DAN_connectivity_wcst")

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
cognition_model_results <- map_df(outcomes, ~fit_model(.x, cognition_model_df, covariates))

# Separate by outcome if preferred
cognition_results_list <- map(outcomes, ~fit_model(.x, cognition_model_df, covariates))
names(cognition_results_list) <- outcomes

# Visualize Effects of Interventions on COGNITION --------------------------------------

cognition_model_results %>%
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


# BASELINE FC -------------------------------------------------------------

# DMN
baseline_DMN <- lm(diff_DMN_connectivity_baseline ~ intervention + DMN_connectivity_prebaseline +
                     days_diff + min_diff + sex_male + stimulant + antidepressant + asrs_18_total,
                   data = baseline_model_df)
# DAN
baseline_DAN <- lm(diff_DAN_connectivity_baseline ~ intervention + DAN_connectivity_prebaseline +
                     days_diff + min_diff + sex_male + stimulant + antidepressant + asrs_18_total,
                   data = baseline_model_df)

# Store Model Results
models <- list(
  Baseline_DMN = baseline_DMN,
  Baseline_DAN = baseline_DAN)

# Apply tidy to all models and combine
baseline_model_results <- map_dfr(models, 
                                 ~tidy(.x, conf.int = TRUE) %>%
                                   select(term, estimate, conf.low, conf.high, p.value),
                                 .id = "model"
)


# Baseline FC Forest Plot -------------------------------------------------

baseline_model_results %>%
  filter(term %in% c("interventionBiking", "interventionDance")) %>%
  mutate(
    # Extract network type from model name
    outcome = str_extract(model, "DMN|DAN"),
    
    # Extract intervention type
    intervention = str_remove(term, "intervention"),
    
    # Significance flag
    significant = if_else(p.value < 0.05, "Yes", "No")
  ) %>%
  ggplot(aes(x = estimate, y = outcome)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(aes(color = significant), size = 3) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high, color = significant),
                width = 0.2) +
  scale_color_manual(values = c("No" = "gray60", "Yes" = "#2E86AB")) +
  facet_wrap(~intervention, ncol = 2) +
  labs(
    title = "Intervention Effects on Baseline Connectivity: Biking vs Dance",
    x = "Effect Size (95% CI)",
    y = "Network",
    color = "p < 0.05"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")


# Summarize Model Results and Adjust P Values -----------------------------
# Filter Model Results
cognition_filt <- cognition_model_results %>%
  filter(term == "interventionBiking" | term == "interventionDance" | term == "sex_male" | str_detect(term, "baseline"))
baseline_filt <- baseline_model_results %>%
  filter(term == "interventionBiking" | term == "interventionDance" | term == "sex_male" | str_detect(term, "baseline"))
balance_filt <- balance_model_results %>%
  filter(term == "sex_male" | term == "sessionsession2:interventionBiking" | term == "sessionsession2:interventionDance")

# Exported Filtered Results for Compilation
write_csv(cognition_filt,"results/FC_cognition.csv")
write_csv(baseline_filt,"results/FC_baseline.csv")
write_csv(balance_filt,"results/FC_balance.csv")

# summarize stroop DMN
stoop_dmn <- cognition_model_df %>%
  select(participant_id,intervention,diff_DMN_connectivity_stroop) %>%
  group_by(intervention) %>%
  summarise(mean = mean(diff_DMN_connectivity_stroop),
            sd = sd(diff_DMN_connectivity_stroop))

# adjust p values for dance and bike cognition
baseline_forMerge <- baseline_model_results %>%
  rename(outcome = model)

dance_fc <- bind_rows(baseline_forMerge,cognition_model_results) %>%
  filter(term == "interventionDance")
dance_fc$adj_p_value <- p.adjust(dance_fc$p.value, method = "fdr")

biking_fc <- bind_rows(baseline_forMerge,cognition_model_results) %>%
  filter(term == "interventionBiking")
biking_fc$adj_p_value <- p.adjust(biking_fc$p.value, method = "fdr")

# adjust p values for dance and bike - balance
dance_balance <- balance_model_results %>%
  filter(term == "sessionsession2:interventionDance")
dance_balance$adj_p_value <- p.adjust(dance_balance$p.value, method = "fdr")

bike_balance <- balance_model_results %>%
  filter(term == "sessionsession2:interventionBiking")
bike_balance$adj_p_value <- p.adjust(bike_balance$p.value, method = "fdr")