# Assessing Change in Balance Across Interventions
# The balance outcomes are unique because we are measuring them across 6 time
# points, not two (baseline and intervention). So it's not as simple as
# using a "change" variable.
#
# Model will be:
# {RMS Distance / Mean Velocity} ~ session*intervention + trial + covariates +
#     + (1 | participant_id)
#
# Note that the original "force" input only has baseline values for the 4 
# dropout participants. Once you filter them out, you should have 1512 
# observations (24 observations x 63 participants)
# 
# Written by Noor Tasnim on November 16, 2025


# Import Libraries and Data -----------------------------------------------

library(tidyverse)
library(lme4)
library(broom.mixed) # for tidy model output
library(lmerTest)
library(ggbeeswarm)
library(svglite)

# Import force plate data
force <- read_csv('data/force_long_09202025.csv') %>%
  rename(participant_id = subject_id)
force$participant_id <- as.numeric(gsub("exgm", "", force$participant_id))

# Get list of participants with lower limb injuries\
lower_injury_list <- read_csv("../demographicsPsych/data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  filter(lower_injury == "yes") %>%
  pull(participant_id)

# Filter Dataframe and Change Trial Information
force_filt <- force %>%
  filter(!participant_id %in% c(77,152,160,175)) %>% # participant dropouts
  filter(participant_id != 3) %>% # was an extreme outlier identified in Paper 1 
  filter(!participant_id %in% lower_injury_list) %>% # Remove participants with lower injuries
  mutate(trial = case_when(
    trial == "1-1" ~ "1",
    trial == "1-2" ~ "2",
    trial == "1-3" ~ "3",
    trial == "2-1" ~ "1",
    trial == "2-2" ~ "2",
    trial == "2-3" ~ "3", 
    TRUE ~ trial),
  )

# Factor Variables for Modeling -------------------------------------------

# Transform Trial to Factor
force_filt$trial <- factor(force_filt$trial, levels = c("1", "2","3"))

# Transform time point variables to different names with factors
force_filt$session <- factor(force_filt$session, 
                             levels = c("baseline", "intervention"),
                             labels = c("session1", "session2"))

# Join Demographic and Intervention Data ----------------------------------

demographics <- readRDS("../demographicsPsych/results/Paper2_BaseDataForModeling.rds") %>%
  filter(participant_id != 3) %>% # was an extreme outlier identified in Paper 1 
  filter(!participant_id %in% lower_injury_list) # Remove participants with lower injuries

force_model_df <- force_filt %>%
  left_join(demographics, by = "participant_id") %>%
  relocate(intervention:asrs_18_total, .before = session)

# Segment Dataframe -------------------------------------------------------
# Make sure you join demographic + intervention data before segment
# 4 total dataframes for 4 models: (2 stances) x (2 metrics)
shoulder_rms <- force_model_df %>%
  filter(metric == "RDIST" & stance == "shoulder")

shoulder_mvelo <- force_model_df %>%
  filter(metric == "MVELO" & stance == "shoulder")

tandem_rms <- force_model_df %>%
  filter(metric == "RDIST" & stance == "tandem")

tandem_mvelo <- force_model_df %>%
  filter(metric == "MVELO" & stance == "tandem")

# Run 4 Unique LME Models -------------------------------------------------

#### Shoulder RMS Distance Model ####
# no significant effects observed
shoulder_rms_model <- lmer(value ~ session*intervention + trial + days_diff + 
                             min_diff + sex_male + stimulant + antidepressant + 
                             asrs_18_total + (1 | participant_id),
                           data = shoulder_rms)

tidy(shoulder_rms_model, effects = "fixed", conf.int = TRUE) %>%
  select(term, estimate, std.error, statistic, conf.low, conf.high, p.value)

#### Shoulder Mean Velocity Model ####
# biking is significant!
shoulder_mvelo_model <- lmer(value ~ session*intervention + trial + days_diff + 
                             min_diff + sex_male + stimulant + antidepressant + 
                             asrs_18_total + (1 | participant_id),
                           data = shoulder_mvelo)

tidy(shoulder_mvelo_model, effects = "fixed", conf.int = TRUE) %>%
  select(term, estimate, std.error, statistic, conf.low, conf.high, p.value)

#### Tandem RMS Distance Model ####

tandem_rms_model <- lmer(value ~ session*intervention + trial + days_diff + 
                             min_diff + sex_male + stimulant + antidepressant + 
                             asrs_18_total + (1 | participant_id),
                           data = tandem_rms)

tidy(tandem_rms_model, effects = "fixed", conf.int = TRUE) %>%
  select(term, estimate, std.error, statistic, conf.low, conf.high, p.value)

#### Tandem Mean Velocity ####
tandem_mvelo_model <- lmer(value ~ session*intervention + trial + days_diff + 
                               min_diff + sex_male + stimulant + antidepressant + 
                               asrs_18_total + (1 | participant_id),
                             data = tandem_mvelo)

tidy(tandem_mvelo_model, effects = "fixed", conf.int = TRUE) %>%
  select(term, estimate, std.error, statistic, conf.low, conf.high, p.value)


# Plot All Model Outcomes -------------------------------------------------

### Extract results from all models ####

# Function to extract and label results
extract_results <- function(model, outcome_name) {
  tidy(model, effects = "fixed", conf.int = TRUE) %>%
    filter(term %in% c("sessionsession2", 
                       "sessionsession2:interventionBiking",
                       "sessionsession2:interventionDance")) %>%
    mutate(outcome = outcome_name) %>%
    select(outcome, term, estimate, conf.low, conf.high)
}

# Extract from all models
shoulder_rms_results <- extract_results(shoulder_rms_model, "Shoulder RMS")
shoulder_mvelo_results <- extract_results(shoulder_mvelo_model, "Shoulder Mean Velocity")
tandem_rms_results <- extract_results(tandem_rms_model, "Tandem RMS")
tandem_mvelo_results <- extract_results(tandem_mvelo_model, "Tandem Mean Velocity")

# Combine all results
all_results <- bind_rows(
  shoulder_rms_results,
  shoulder_mvelo_results,
  tandem_rms_results,
  tandem_mvelo_results
) %>%
  mutate(
    # Create cleaner labels for groups
    group = case_when(
      term == "sessionsession2" ~ "Control",
      term == "sessionsession2:interventionBiking" ~ "Biking",
      term == "sessionsession2:interventionDance" ~ "Dance",
      TRUE ~ term
    ),
    # Create factor for ordering
    group = factor(group, levels = c("Dance", "Biking", "Control")),
    outcome = factor(outcome, levels = c("Shoulder RMS", "Shoulder Mean Velocity",
                                         "Tandem RMS", "Tandem Mean Velocity")),
    # Determine if CI crosses zero (for coloring)
    significant = ifelse(conf.low > 0 | conf.high < 0, "Significant", "Not Significant"),
    # Create label with estimate and CI
    label_text = sprintf("%.2f\n[%.2f, %.2f]", estimate, conf.low, conf.high)
  )

#### Create the forest plot with free scales ####

forest_plot <- ggplot(all_results, aes(x = estimate, y = group, color = significant)) +
  # Add vertical line at zero
  geom_vline(xintercept = 0, linetype = "dashed", color = "black", linewidth = 0.8) +
  # Add confidence intervals
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), 
                 height = 0.3, linewidth = 1.1) +
  # Add point estimates
  geom_point(size = 4.5, shape = 18) +
  # Facet by outcome with FREE x-axis scales
  facet_wrap(~outcome, ncol = 2, scales = "free_x") +
  # Color scheme
  scale_color_manual(
    values = c("Significant" = "#D6604D", "Not Significant" = "#4393C3"),
    name = NULL,
    labels = c("Not Significant" = "95% CI includes zero", 
               "Significant" = "95% CI excludes zero")
  ) +
  # Labels
  labs(
    title = "Intervention Effects Across Balance Outcomes",
    subtitle = "Change from pre- to post-intervention (95% CI)",
    x = "Coefficient Estimate",
    y = NULL,
    caption = "Note: Dashed line indicates no effect (zero). X-axis scales differ between RMS and mean velocity outcomes."
  ) +
  # Theme
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "gray80", fill = NA, linewidth = 0.5),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
    plot.subtitle = element_text(hjust = 0.5, face = "italic", size = 12),
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = "gray70"),
    legend.position = "bottom",
    legend.text = element_text(size = 10),
    plot.caption = element_text(hjust = 0, face = "italic", size = 9, color = "gray40")
  )

print(forest_plot)


# Final Summary Stats and Boxplots for Paper 2 ----------------------------

#### Create Dataframe for Summary Table ####
force_summary_df <- force_model_df %>%
  select(participant_id,intervention,sex_male,session:value) %>%
  mutate(sex = if_else(sex_male == 1, "male", "female")) %>%
  select(-sex_male)

#### Generate Table ####
summary_stats <- force_summary_df %>%
  group_by(intervention, session, metric, stance, trial) %>%
  summarise(
    mean_val = mean(value, na.rm = TRUE),
    sd_val = sd(value, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(
    formatted = sprintf("%.2f (%.2f)", mean_val, sd_val),
    intervention = case_when(
      grepl("Music", intervention, ignore.case = TRUE) ~ "Music Listening",
      grepl("Bik", intervention, ignore.case = TRUE) ~ "Biking",
      grepl("Dance", intervention, ignore.case = TRUE) ~ "Dance Exergaming",
      TRUE ~ intervention
    ),
    session = case_when(
      grepl("1", session) ~ "Session 1",
      grepl("2", session) ~ "Session 2",
      TRUE ~ paste("Session", session)
    ),
    metric = case_when(
      metric == "RDIST" ~ "RMS Distance",
      metric == "MVELO" ~ "Mean Velocity",
      TRUE ~ metric
    ),
    stance = case_when(
      grepl("shoulder", stance, ignore.case = TRUE) ~ "Shoulder Width",
      grepl("tandem", stance, ignore.case = TRUE) ~ "Tandem",
      TRUE ~ stance
    ),
    row_id = paste0(stance, " - Trial ", trial),
    col_id = paste(intervention, session, sep = " x ")
  )

wide_format <- summary_stats %>%
  select(metric, row_id, col_id, formatted) %>%
  pivot_wider(
    names_from = col_id,
    values_from = formatted
  )

desired_cols <- c(
  "Music Listening x Session 1",
  "Music Listening x Session 2",
  "Biking x Session 1",
  "Biking x Session 2",
  "Dance Exergaming x Session 1",
  "Dance Exergaming x Session 2"
)

final_table <- wide_format %>%
  arrange(
    factor(metric, levels = c("RMS Distance", "Mean Velocity")),
    factor(row_id, levels = c(
      "Shoulder Width - Trial 1",
      "Shoulder Width - Trial 2",
      "Shoulder Width - Trial 3",
      "Tandem - Trial 1",
      "Tandem - Trial 2",
      "Tandem - Trial 3"
    ))
  ) %>%
  rename(Variable = row_id) %>%
  select(metric, Variable, any_of(desired_cols))

write.csv(final_table, "results/force_summary_table.csv", row.names = FALSE, na = "")

# Created Faceted Box Plot (Page Length) ----------------------------------

plot_data <- force_summary_df %>%
  mutate(
    metric_label = case_when(
      metric == "RDIST" ~ "RMS Distance",
      metric == "MVELO" ~ "Mean Velocity",
      TRUE ~ metric
    ),
    stance_label = case_when(
      grepl("shoulder", stance, ignore.case = TRUE) ~ "Shoulder Width",
      grepl("tandem", stance, ignore.case = TRUE) ~ "Tandem",
      TRUE ~ stance
    ),
    session_label = case_when(
      grepl("1", session) ~ "Session 1",
      grepl("2", session) ~ "Session 2",
      TRUE ~ session
    ),
    trial_factor = factor(trial)
  )

p <- ggplot(plot_data, aes(x = trial_factor, y = value)) +
  geom_boxplot(outlier.shape = NA, fill = "white") +
  geom_beeswarm(aes(color = intervention, shape = sex), 
                size = 2.5, 
                cex = 2.5,
                alpha = 0.6) +
  facet_grid(stance_label + metric_label ~ session_label,
             scales = "free_y") +
  labs(x = "Trial", 
       y = "Value",
       color = "Intervention",
       shape = "Sex") +
  theme_classic(base_size = 14) +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.text = element_text(size = 12, color = "black"),
    axis.title = element_text(size = 14, face = "bold"),
    strip.text = element_text(size = 12, face = "bold"),
    strip.background = element_rect(fill = "gray95", color = "black"),
    legend.position = "bottom",
    legend.text = element_text(size = 11),
    legend.title = element_text(size = 12, face = "bold"),
    panel.spacing = unit(1, "lines")
  ) +
  scale_color_manual(values = c("Music Listening" = "#1f77b4",
                                "Biking" = "#ff7f0e", 
                                "Dance" = "#2ca02c")) +
  scale_shape_manual(values = c(16, 17))

ggsave("results/force_distribution_plots.svg", 
       plot = p, 
       width = 10, 
       height = 14, 
       units = "in",
       device = "svg")

print(p)
