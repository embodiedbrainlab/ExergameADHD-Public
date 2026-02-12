# MODEL COP
# Now that extreme outliers have been removed from the dataset. We can create a
# linear mixed effects model that considers key demographic and mental health
# variables to determine what are significant predicts of mean velocity and
# RMS distance in shoulder and tandem stance.
#
# Script is incomplete and possibly needs to scale additional variables, include
# them in existing model for tandem mean velocity, and additional models need
# to be created.
#
# NOTE: CURRENT SCRIPT ANALYZES BASELINE DATA ONLY FOR NOW.
#
# Edited on September 20, 2025

# Import Libraries and Data --------------------------------------------------------
library(tidyverse)
library(ggbeeswarm)
library(lme4)
library(lmerTest)
cop <- read_csv('data/baseline_cop_data_forModeling.csv')
# Import Session Times to consider for final model
session_times <- read_csv("../demographicsPsych/data/session_times.csv") %>%
  filter(session == 1) %>%
  select(id, time) %>%
  rename(participant_id = id) %>%
  mutate(participant_id = as.numeric(str_remove(participant_id, "exgm")))

# Add session times to main cop dataframe
cop <- cop %>%
  left_join(session_times, by = "participant_id")

# Reformat Variables to Prepare for Modelling -----------------------------

# Convert Categorical Variables to Factors
cop4model <- cop %>%
  mutate(adhd_med_type = as.factor(adhd_med_type),
         sex = factor(sex, levels = c(1,2), labels = c("Female","Male")),
         stimulant = as.factor(stimulant),
         antidepressant = as.factor(antidepressant),
         ethnicity = as.factor(ethnicity),
         adhd_type = factor(adhd_type, levels = c(1,2,3), labels = c("Hyperactive/Impulsive","Inattentive","Combined")),
         race = as.factor(race),
         trial = as.factor(trial),
         time = as.factor(time),
         participant_id = as.factor(participant_id)
         )

# Scale Continuous Predictors
continuous_vars <- c("bmi","asrs_18_total","asset_total","bdi_total","bai_total")

cop4model <- cop4model %>%
  mutate(across(all_of(continuous_vars), 
                ~scale(.x, center = TRUE, scale = TRUE)[,1],
                .names = "{.col}_scaled"))

# Set Reference for Factors
cop4model$stimulant <- relevel(cop4model$stimulant, ref = "no")
cop4model$antidepressant <- relevel(cop4model$antidepressant, ref = "FALSE")
cop4model$ethnicity <- relevel(cop4model$ethnicity, ref = "not_hispanic_latino")
cop4model$race

# Split Datasets ----------------------------------------------------------

## Tandem
tandem <- cop4model %>% 
  filter(stance == "tandem")

tandem_mvelo <- tandem %>%
  filter(metric == "Mean Velocity")

tandem_rdist <- tandem %>%
  filter(metric == "RMS Distance")

## Shoulder
shoulder <- cop4model %>%
  filter(stance == "shoulder")

shoulder_mvelo <- shoulder %>%
  filter(metric == "Mean Velocity")

shoulder_rdist <- shoulder %>%
  filter(metric == "RMS Distance")

# Plot Overall Shoulder Distribution -----------------------------------------------
ggplot(shoulder, aes(x = metric, y = value, fill = trial)) +
  geom_boxplot() + 
  geom_beeswarm(aes(color = trial), dodge.width = 0.75, alpha = 0.6, size = 1) +
  scale_fill_brewer(type = "qual", palette = "Set2") +
  scale_color_brewer(type = "qual", palette = "Dark2") +
  ggtitle("Standing with Feet Shoulder Width Apart")

ggsave("results/shoulder_stance_summmary.png")

# Get Shoulder Summary and Export
shoulder_summary <- shoulder %>%
  group_by(metric, trial) %>%
  summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    n_total = n(),
    n_valid = sum(!is.na(value)),
    n_na = sum(is.na(value)),
    .groups = "drop"
  )

write_csv(shoulder_summary,'results/shoulder_summary.csv')

# Plot Overall Tandem Distribution ----------------------------------------
ggplot(tandem, aes(x = metric, y = value, fill = trial)) +
  geom_boxplot() + 
  geom_beeswarm(aes(color = trial), dodge.width = 0.75, alpha = 0.6, size = 1) +
  scale_fill_brewer(type = "qual", palette = "Set2") +
  scale_color_brewer(type = "qual", palette = "Dark2") +
  ggtitle("Standing with Feet in Tandem")

ggsave("results/tandem_stance_summmary.png")

# Get Tandem Summary
tandem_summary <- tandem %>%
  group_by(metric, trial) %>%
  summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    n_total = n(),
    n_valid = sum(!is.na(value)),
    n_na = sum(is.na(value)),
    .groups = "drop"
  )

write_csv(tandem_summary,'results/tandem_summary.csv')

# Tandem Mean Velocity Model ---------------------------

tandem_mvelo_lme <- lmer(value ~
                       sex + stimulant + antidepressant + time +
                         asrs_18_total_scaled + asset_total_scaled + bdi_total_scaled + bai_total_scaled +
                       (1 | participant_id),
                     data = tandem_mvelo,
                     REML = TRUE
                       )

# Model outputs
summary(tandem_mvelo_lme)

# Linear Mixed Effects Models for RMS Distance ----------------------------


