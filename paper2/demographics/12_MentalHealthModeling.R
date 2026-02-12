# Comparison of Mental Health Metrics between Baseline and Intervention
# Some mental health metrics were collected during both sessions, so this script
# will determine if interventions influences changes in ASSET, BDI, and BAI.
#
# It would be great if we could do color-coded dots for asrs_6_subscale, with
# X-Axis as Pre vs. Post and facet each metrics (ASSET, BDI, and BAI) by
# intervention type.


# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(readxl)
library(ggbeeswarm)
library(tidyr)
library(broom)

# Load Dataset ------------------------------------------------------------
baseline_mh <- read_csv("data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  filter(!participant_id %in% c(77, 152, 160, 175)) %>% # exclude dropouts
  mutate(sex = case_when(
    sex == 1 ~ "female",
    sex == 2 ~ "male"))

intervention_mh_raw <- read_csv("data/tidy/intervention_mental_health.csv") %>%
  select(-consume) # remove food diary column

intervention_assignments <- read_excel("data/intervention_assignments.xlsx") %>%
  select(-id) %>%
  mutate(intervention = case_when(
    intervention == "A" ~ "dance",
    intervention == "B" ~ "bike",
    intervention == "C" ~ "listen",
    TRUE ~ intervention  # keeps any other values unchanged
  ))

timing <- read_csv("results/time_between_sessions.csv") %>%
  select(-intervention) %>%
  rename(days_diff = elapsed_time,
         min_diff = time_diff_minutes)

# Score Intervention mental health outcomes -------------------------------

intervention_mh <- intervention_mh_raw %>%
  #### ASSET variables ####
  mutate(asset_inattentive = asset_attn*0.16 + asset_forget*0.17 + asset_follow*0.19 +
           asset_organize*0.2 + asset_misplace*0.15 + asset_productivity*0.13,
         asset_hyperactive = asset_fidget*0.31 + asset_impatience*0.36 + asset_anxiety*0.13 +
           asset_mood*0.19,
         asset_total = asset_inattentive + asset_hyperactive) %>%

  #### BDI total score ####
  mutate(bdi_total = sadness_bdi + pessimism_bdi + failure_bdi + loss_satisfaction_bdi + guilt_bdi + 
           punish_bdi + disaapoint_bdi + self_critical_bdi + suicidal_thoughts_bdi + 
           crying_bdi + irritable_bdi + interest_loss_bdi + indecisive_bdi + self_image_bdi +
           motivation_bdi + sleep_bdi + tired_bdi + appetite_bdi + weight_bdi + 
           worry_health_bdi + sex_bdi) %>%
  
  #### BAI total score ####
  mutate(bai_total = bai_1 + bai_2 + bai_3 + bai_4 + bai_5 + bai_6 + bai_7 + bai_8 +
           bai_9 + bai_10 + bai_11 + bai_12 + bai_13 + bai_14 + bai_15 +
           bai_16 + bai_17 + bai_18 + bai_19 + bai_20 + bai_21) %>%
  
  #### Keep Variables of Interest ####
  select(participant_id,asset_inattentive:bai_total)


# Prune Baseline Mental Measures for Easier Merge -------------------------

baseline_mh_tidy <- baseline_mh %>%
  select(participant_id,sex,stimulant,antidepressant,asrs_18_total,asset_inattentive,
         asset_hyperactive,asset_total,bdi_total,bai_total) %>%
  rename_with(~ paste0("baseline_", .), 
              asset_inattentive:bai_total)

# Add intervention assignments to intervention data frame -----------------
intervention_mh_tidy <- intervention_mh %>%
  left_join(intervention_assignments, by = "participant_id") %>%
  relocate(intervention, .before = asset_inattentive) %>%
  rename_with(~ paste0("intervention_", .), 
              asset_inattentive:bai_total)


# Prep Final Dataframe for Modeling -----------------------------------------------------

combined <- baseline_mh_tidy %>%
  left_join(intervention_mh_tidy, by = "participant_id") %>% # Join Dataframes
  relocate(intervention, .before = sex) %>% # Move Intervention Column
  mutate(
    sex = case_when(
      sex == "female" ~ 0,
      sex == "male" ~ 1), # Binary Sex Variable
    stimulant = as.numeric(tolower(stimulant) == "yes"), # Binary Stimulant Variable
    antidepressant = as.numeric(antidepressant), # Binary Antidepressant Variable
    intervention = factor(intervention,
                          levels = c("listen","bike","dance"),
                          labels = c("Music Listening","Biking","Dance")) # Factor intervention
    ) %>%
  rename(sex_male = sex) # Rename Sex Variable for Clarity

# Add timing of sessions
combined_timing <- combined %>%
  left_join(timing, by = "participant_id") %>%
  relocate(days_diff, min_diff, .after = intervention)


# Calculate Change Scores -------------------------------------------------

# Extract variable names from baseline columns
baseline_cols <- grep("^baseline", names(combined_timing), value = TRUE)
var_names <- sub("^baseline_?", "", baseline_cols)

# Create difference columns
diff_data <- map_dfc(var_names, function(var) {
  baseline <- combined_timing[[paste0("baseline_", var)]]
  intervention <- combined_timing[[paste0("intervention_", var)]]
  tibble(!!paste0("diff_", var) := intervention - baseline)
})

# Combine with original dataframe and export as .csv
combined_diff <- bind_cols(combined_timing, diff_data)
write_csv(combined_diff,"results/Paper2_MentalHealthModeling_df.csv")


# Export Demographics DF for Other Models ---------------------------------

demographics_df <- combined_diff %>%
  select(participant_id:asrs_18_total)
saveRDS(demographics_df, file = "results/Paper2_BaseDataForModeling.rds")

# Model Mental Health Outcomes -------------------------------------------------------

#Define outcome variables
outcomes <- c("asset_total", "asset_hyperactive", "asset_inattentive", "bdi_total", "bai_total")

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
model_results <- map_df(outcomes, ~fit_model(.x, combined_diff, covariates))

# Separate by outcome if preferred
results_list <- map(outcomes, ~fit_model(.x, combined_diff, covariates))
names(results_list) <- outcomes


# Visualize Effects of Interventions --------------------------------------

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


# Summary of Differences --------------------------------------------------

mh_summary_stats <- combined_diff %>%
  select(participant_id, intervention, 
         diff_asset_hyperactive, diff_asset_inattentive,
         diff_bdi_total, diff_bai_total) %>%
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

write_csv(mh_summary_stats,"results/mh_summary_stats.csv")


# General Summary Statistics ----------------------------------------------

combined_diff_summary <- combined_diff %>%
  select(participant_id, intervention,
         baseline_asset_hyperactive, intervention_asset_hyperactive,
         baseline_asset_inattentive, intervention_asset_inattentive,
         baseline_bdi_total, intervention_bdi_total,
         baseline_bai_total, intervention_bai_total) %>%
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

write_csv(combined_diff_summary,"results/combined_diff_summary.csv")

# # ASSET Plot --------------------------------------------------------------
# 
# asset_df <- combined %>%
#   pivot_longer(cols = c(asset_total_session1, asset_total_session2),
#                names_to = "session",
#                values_to = "asset_total") %>%
#   mutate(session = recode(session,
#                           "asset_total_session1" = "Session 1",
#                           "asset_total_session2" = "Session 2"))
# 
# # Create plot
# ggplot(asset_df, 
#        aes(x = session, 
#            y = asset_total, 
#            color = asrs_6_total_category)) +
#   geom_boxplot(aes(fill = asrs_6_total_category), 
#                outlier.shape = NA, 
#                alpha = 0.2,
#                position = position_dodge(width = 0.8)) +
#   geom_beeswarm(dodge.width = 0.8,
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "ASSET Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "ASSET Total Score",
#        color = "ASRS-6 Category",
#        fill = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
# 
# # Grouped Plot
# 
# ggplot(asset_df, 
#        aes(x = session, 
#            y = asset_total)) +
#   geom_boxplot(outlier.shape = NA, 
#                alpha = 0.5,
#                fill = "grey90") +
#   geom_beeswarm(aes(color = asrs_6_total_category),
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "ASSET Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "ASSET Total Score",
#        color = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
# 
# 
# # Depression Plot ----------------------------------------------------------------
# 
# bdi_df <- combined %>%
#   pivot_longer(cols = c(bdi_total_session1, bdi_total_session2),
#                names_to = "session",
#                values_to = "bdi_total") %>%
#   mutate(session = recode(session,
#                           "bdi_total_session1" = "Session 1",
#                           "bdi_total_session2" = "Session 2"))
# 
# # Create the plot
# ggplot(bdi_df, 
#        aes(x = session, 
#            y = bdi_total, 
#            color = asrs_6_total_category)) +
#   geom_boxplot(aes(fill = asrs_6_total_category), 
#                outlier.shape = NA, 
#                alpha = 0.2,
#                position = position_dodge(width = 0.8)) +
#   geom_beeswarm(dodge.width = 0.8,
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "BDI Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "BDI Total Score",
#        color = "ASRS-6 Category",
#        fill = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
# 
# # Grouped Plot
# ggplot(bdi_df, 
#        aes(x = session, 
#            y = bdi_total)) +
#   geom_boxplot(outlier.shape = NA, 
#                alpha = 0.5,
#                fill = "grey90") +
#   geom_beeswarm(aes(color = asrs_6_total_category),
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "BDI Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "BDI Total Score",
#        color = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
# 
# 
# # Anxiety Plot ----------------------------------------------------------------
# 
# bai_df <- combined %>%
#   pivot_longer(cols = c(bai_total_session1, bai_total_session2),
#                names_to = "session",
#                values_to = "bai_total") %>%
#   mutate(session = recode(session,
#                           "bai_total_session1" = "Session 1",
#                           "bai_total_session2" = "Session 2"))
# 
# # Create the plot
# ggplot(bai_df, 
#        aes(x = session, 
#            y = bai_total, 
#            color = asrs_6_total_category)) +
#   geom_boxplot(aes(fill = asrs_6_total_category), 
#                outlier.shape = NA, 
#                alpha = 0.2,
#                position = position_dodge(width = 0.8)) +
#   geom_beeswarm(dodge.width = 0.8,
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "BAI Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "BAI Total Score",
#        color = "ASRS-6 Category",
#        fill = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
# 
# # Grouped Plot
# ggplot(bai_df, 
#        aes(x = session, 
#            y = bai_total)) +
#   geom_boxplot(outlier.shape = NA, 
#                alpha = 0.5,
#                fill = "grey90") +
#   geom_beeswarm(aes(color = asrs_6_total_category),
#                 size = 2.5, 
#                 alpha = 0.7, 
#                 cex = 2) +
#   facet_wrap(~intervention) +
#   labs(title = "BAI Total Score: Session 1 vs Session 2 by Intervention",
#        x = "Session",
#        y = "BAI Total Score",
#        color = "ASRS-6 Category") +
#   theme_minimal() +
#   theme(legend.position = "bottom")
