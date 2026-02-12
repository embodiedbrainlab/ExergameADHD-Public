# Exploring Effects of Dance on Spectral Power
# We created 600 models accounting for the effects of dance on spectral power
# across 10 clusters x 5 frequency bands x 12 experiences (baseline [intervention
# only], digit forward, digit backward, gonogo, stroop, wcst, shoulder 1-3, 
# tandem 1-3).
# 
# We will now look through the separate effects of dance and see what clusters
# are worth reporting on/exploring.
# 
# Before exploring, we also need to determine which clusters we should look into
# further. We should aim for those with at least 50% participants that have 
# data for both sessions. Total numbers for interventions were:
#   Dance: 22
#   Biking: 21
#   Listening: 20
# 
# When calculating percentages in each cluster, we excluded the following clusters
# for having at least 1 group with less than 50% representation:
#   Cluster 3, Cluster 5, Cluster 10, Cluster 11
# 
# Written by Noor Tasnim on November 15, 2025

# Import Libraries and Data -----------------------------------------------
library(tidyverse)
library(broom.mixed)
library(broom)
# set directory
setwd("~/Documents/repos/ExergameADHD/Paper2_SpecParamModeling")
load("results/peak_power_models.RData")


# Determine Distribution of ICs for Each Cluster --------------------------

#### Import Datasets ####
demographics <- readRDS("../demographicsPsych/results/Paper2_BaseDataForModeling.rds") %>%
  select(participant_id,intervention)
peaks <- read_csv("results/wideClusterData/peaks_wide_all_clusters.csv") %>%
  select(subject,contains("ic_in")) %>%
  mutate(participant_id = as.numeric(gsub("exgm", "", subject)), .before = 1) %>%
  select(-subject)
# merge
clusterCounting_DF <- demographics %>%
  left_join(peaks, by = "participant_id")

#### Generate Summary ####
# Define sample sizes for each intervention
sample_sizes <- c("Biking" = 21, "Dance" = 22, "Music Listening" = 20)

# Create percentage summary
percentage_summary <- clusterCounting_DF %>%
  group_by(intervention) %>%
  summarise(
    cluster_3 = sum(baseline_ic_in_3 == 1 & intervention_ic_in_3 == 1, na.rm = TRUE),
    cluster_4 = sum(baseline_ic_in_4 == 1 & intervention_ic_in_4 == 1, na.rm = TRUE),
    cluster_5 = sum(baseline_ic_in_5 == 1 & intervention_ic_in_5 == 1, na.rm = TRUE),
    cluster_6 = sum(baseline_ic_in_6 == 1 & intervention_ic_in_6 == 1, na.rm = TRUE),
    cluster_7 = sum(baseline_ic_in_7 == 1 & intervention_ic_in_7 == 1, na.rm = TRUE),
    cluster_8 = sum(baseline_ic_in_8 == 1 & intervention_ic_in_8 == 1, na.rm = TRUE),
    cluster_9 = sum(baseline_ic_in_9 == 1 & intervention_ic_in_9 == 1, na.rm = TRUE),
    cluster_10 = sum(baseline_ic_in_10 == 1 & intervention_ic_in_10 == 1, na.rm = TRUE),
    cluster_11 = sum(baseline_ic_in_11 == 1 & intervention_ic_in_11 == 1, na.rm = TRUE),
    cluster_12 = sum(baseline_ic_in_12 == 1 & intervention_ic_in_12 == 1, na.rm = TRUE)
  ) %>%
  mutate(n = sample_sizes[intervention]) %>%
  mutate(across(starts_with("cluster_"), ~ (.x / n) * 100)) %>%
  select(-n)
write_csv(percentage_summary,"results/ClusterPercentageByIntervention.csv")

# Filter for Dance --------------------------------------------------------
#### Alpha ####
dance_alpha_primary <- model_results %>%
  mutate(cluster = str_extract(outcome, "^\\d+")) %>%
  filter(!grepl("^(3_|5_|10_|11_)", outcome)) %>% # Removing Cluster 3, Cluster 5, Cluster 10, Cluster 11
  filter(term == "interventionDance") %>%
  filter(grepl("alpha", outcome, ignore.case = TRUE)) %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() #%>%
  #filter(p.value < 0.05)

#### Other Frequency Bands ####
dance_exploratory <- model_results %>%
  mutate(cluster = str_extract(outcome, "^\\d+")) %>%
  filter(!grepl("^(3_|5_|10_|11_)", outcome)) %>%
  filter(term == "interventionDance") %>%
  filter(!grepl("alpha", outcome, ignore.case = TRUE)) %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() %>%
  filter(p.value < 0.05)

# Filter for Biking -------------------------------------------------------
#### Alpha ####
bike_alpha_primary <- model_results %>%
  mutate(cluster = str_extract(outcome, "^\\d+")) %>%
  filter(!grepl("^(3_|5_|10_|11_)", outcome)) %>% # Removing Cluster 3, Cluster 5, Cluster 10, Cluster 11
  filter(term == "interventionBiking") %>%
  filter(grepl("alpha", outcome, ignore.case = TRUE)) %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() #%>%
  #filter(p.value < 0.05)

#### Other Frequency Bands ####
bike_exploratory <- model_results %>%
  mutate(cluster = str_extract(outcome, "^\\d+")) %>%
  filter(!grepl("^(3_|5_|10_|11_)", outcome)) %>%
  filter(term == "interventionBiking") %>%
  filter(!grepl("alpha", outcome, ignore.case = TRUE)) %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() %>%
  filter(p.value < 0.05)

# Looking at Balance Neural Data ------------------------------------------

#### Effects of Dance ####
BALANCE_dance_alpha_primary <- balance_results %>%
  filter(term == "sessionsession2:interventionDance") %>%
  filter(frequency_band == "alpha") %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() #%>%
  #filter(p.value < 0.05)

BALANCE_dance_exploratory_primary <- balance_results %>%
  filter(term == "sessionsession2:interventionDance") %>%
  filter(frequency_band != "alpha") %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() %>%
  filter(p.value < 0.05)

#### Effects of Biking ####
BALANCE_BIKE_alpha_primary <- balance_results %>%
  filter(term == "sessionsession2:interventionBiking") %>%
  filter(frequency_band == "alpha") %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() #%>%
  #filter(p.value < 0.05)

BALANCE_BIKE_exploratory_primary <- balance_results %>%
  filter(term == "sessionsession2:interventionBiking") %>%
  filter(frequency_band != "alpha") %>%
  group_by(cluster) %>%
  mutate(p.adjusted = p.adjust(p.value, method = "BH")) %>%
  ungroup() %>%
  filter(p.value < 0.05)

# Summary Stats for Paper 2 Tables ----------------------------------------

#### Alpha COGNITION Table ####
results_list$`4_wcst_alpha`
results_list$`4_stroop_alpha`
results_list$`6_stroop_alpha`
results_list$`7_gonogo_alpha`
results_list$`8_baseline_alpha`
results_list$`8_digitbackward_alpha`

alpha_stats <- specparam_model_df %>%
  select(participant_id, intervention, 
         diff_4_wcst_alpha, diff_4_stroop_alpha, 
         diff_6_stroop_alpha, diff_7_gonogo_alpha,
         diff_8_baseline_alpha, diff_8_digitbackward_alpha) %>%
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
write_csv(alpha_stats,"results/alpha_stats.csv")

#### Pre/Post Alpha Power Averages ####
cognitive_alpha_summary <- specparam_model_df %>%
  select(participant_id, intervention,
         # Baseline columns
         baseline_4_wcst_alpha, baseline_4_stroop_alpha,
         baseline_6_stroop_alpha, baseline_7_gonogo_alpha,
         intervention_8_prebaseline_alpha, baseline_8_digitbackward_alpha,
         # Intervention columns
         intervention_4_wcst_alpha, intervention_4_stroop_alpha,
         intervention_6_stroop_alpha, intervention_7_gonogo_alpha,
         intervention_8_postbaseline_alpha, intervention_8_digitbackward_alpha
  ) %>%
  pivot_longer(
    cols = -c(participant_id, intervention),
    names_to = "measure",
    values_to = "alpha_power"
  ) %>%
  # Extract session and cluster_task from measure name
  mutate(
    session = case_when(
      grepl("^baseline_", measure) ~ "session1",
      measure == "intervention_8_prebaseline_alpha" ~ "session1",
      grepl("^intervention_", measure) ~ "session2"
    ),
    cluster_task = case_when(
      measure == "intervention_8_prebaseline_alpha" ~ "8_baseline_alpha",
      measure == "intervention_8_postbaseline_alpha" ~ "8_baseline_alpha",
      TRUE ~ sub("^(baseline|intervention)_", "", measure)
    )
  ) %>%
  # Calculate summary statistics
  group_by(intervention, session, cluster_task) %>%
  summarise(
    N = sum(!is.na(alpha_power)),
    Mean = mean(alpha_power, na.rm = TRUE),
    SD = sd(alpha_power, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(
    Variable = cluster_task,
    cell_value = sprintf("%.2f (%d, %.2f)", Mean, N, SD)
  ) %>%
  pivot_wider(
    id_cols = Variable,
    names_from = c(intervention, session),
    values_from = cell_value,
    names_sep = "_"
  ) %>%
  arrange(Variable)

write.csv(cognitive_alpha_summary, "results/cognitive_alpha_summary.csv", row.names = FALSE)

#### Other Frequency Bands COGNITION ####
results_list$`4_gonogo_theta`
results_list$`4_stroop_low_beta`
results_list$`4_digitbackward_high_beta`
results_list$`6_stroop_low_beta`
results_list$`6_wcst_low_beta`
results_list$`7_wcst_theta`
results_list$`7_digitforward_low_beta`
results_list$`7_digitbackward_high_beta`
results_list$`8_baseline_high_beta`
results_list$`9_baseline_gamma`
results_list$`9_wcst_gamma`

#### Export Cognition Models for Double Checking Results ####
selected_results <- bind_rows(
  results_list$`4_wcst_alpha`,
  results_list$`4_stroop_alpha`,
  results_list$`6_stroop_alpha`,
  results_list$`7_gonogo_alpha`,
  results_list$`8_baseline_alpha`,
  results_list$`8_digitbackward_alpha`,
  results_list$`4_gonogo_theta`,
  results_list$`4_stroop_low_beta`,
  results_list$`4_digitbackward_high_beta`,
  results_list$`6_stroop_low_beta`,
  results_list$`6_wcst_low_beta`,
  results_list$`7_wcst_theta`,
  results_list$`7_digitforward_low_beta`,
  results_list$`7_digitbackward_high_beta`,
  results_list$`8_baseline_high_beta`,
  results_list$`9_baseline_gamma`,
  results_list$`9_wcst_gamma`,
  .id = "model"
)

write.csv(selected_results, "results/linear_model_results.csv", row.names = FALSE)

#### Other Frequency Band Summary Stats ####
explore_cognition_stats <- specparam_model_df %>%
  select(participant_id, intervention, 
         diff_4_gonogo_theta, diff_4_stroop_low_beta, 
         diff_4_digitbackward_high_beta, diff_6_stroop_low_beta,
         diff_6_wcst_low_beta, diff_7_wcst_theta,
         diff_7_digitforward_low_beta, diff_7_digitbackward_high_beta,
         diff_8_baseline_high_beta, diff_9_baseline_gamma,
         diff_9_wcst_gamma) %>%
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
write_csv(explore_cognition_stats, "results/explore_cognition_stats.csv")


# Export All Alpha Models -------------------------------------------------

alpha_whole <- model_results %>%
  mutate(cluster = str_extract(outcome, "^\\d+")) %>%
  filter(!grepl("^(3_|5_|10_|11_)", outcome)) %>% # Removing Cluster 3, Cluster 5, Cluster 10, Cluster 11
  filter(term == "interventionBiking" | term == "interventionDance" | term == "sex_male" | str_detect(term, "baseline")) %>%
  filter(grepl("alpha", outcome, ignore.case = TRUE))
write_csv(alpha_whole,"results/all_alpha_models.csv")


# Export All BALANCE Alpha Models -----------------------------------------

balance_alpha_whole <- balance_results %>%
  filter(frequency_band == "alpha") %>%
  filter(term == "sessionsession2:interventionBiking" | term == "sessionsession2:interventionDance" | term == "sex_male")
write_csv(balance_alpha_whole,"results/all_BALANCE_alpha_models.csv")


# Export Balance Models for Tables ----------------------------------------

write_csv(BALANCE_dance_alpha_primary, "results/balance_alpha_dance.csv")
write_csv(BALANCE_BIKE_alpha_primary, "results/balance_alpha_bike.csv")

# Export Balance Exploratory Models ---------------------------------------

balance_explore_export <- balance_results %>%
  filter(frequency_band == "low_beta" | frequency_band == "high_beta") %>%
  filter(term == "sessionsession2:interventionBiking" | term == "sessionsession2:interventionDance") %>%
  filter(cluster != 6)
write_csv(balance_explore_export,"results/balance_exploratory_models.csv")


# Balance Alpha Power Summary Statistics ----------------------------------

balance_alpha_summary <- balance_long %>%
  select(participant_id,intervention,session,cluster,stance,trial,alpha_power) %>%
  filter(cluster == 8 | cluster == 12)

# Function to create summary table for a specific cluster
create_cluster_table <- function(data, cluster_num) {
  data %>%
    filter(cluster == cluster_num) %>%
    group_by(intervention, session, stance, trial) %>%
    summarise(
      N = sum(!is.na(alpha_power)),
      Mean = mean(alpha_power, na.rm = TRUE),
      SD = sd(alpha_power, na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    mutate(
      Variable = paste0(
        tools::toTitleCase(stance), 
        " Width - Trial ", 
        trial
      ),
      # Format the cell values as "MEAN (N, SD)"
      cell_value = sprintf("%.2f (%d, %.2f)", Mean, N, SD)
    ) %>%
    pivot_wider(
      id_cols = Variable,
      names_from = c(intervention, session),
      values_from = cell_value,
      names_sep = "_"
    ) %>%
    arrange(Variable)
}

# Create table for Cluster 8
cluster_8_table <- create_cluster_table(balance_alpha_summary, 8)
print("=== CLUSTER 8 ===")
write.csv(cluster_8_table, "results/cluster_8_alpha_summary.csv", row.names = FALSE)

# Create table for Cluster 12
cluster_12_table <- create_cluster_table(balance_alpha_summary, 12)
print("\n=== CLUSTER 12 ===")
write.csv(cluster_12_table, "results/cluster_12_alpha_summary.csv", row.names = FALSE)


# Get other predictor values for balance models ---------------------------
tidy(balance_model_list$cluster12_shoulder_alpha, effects = "fixed", conf.int = TRUE) %>%
  select(term, estimate, conf.low, conf.high, p.value)

# Save all variables for statistics review --------------------------------

save.image("results/SpecParam_Statistical_Modeling.RData")
