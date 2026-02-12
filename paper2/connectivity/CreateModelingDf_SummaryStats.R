# SUMMARY TABLE FOR DMN/DAN VALUES FROM ROI CONNECT
# We needed a table that summarized the average value and standard deviation of 
# alpha connectivity in the DMN, DAN, and across the DMN-DAN in our 26x26 
# connectivity matrices. 
# 
# The MATLAB script, `../statistical_modeling/reshapeROIconnect.m`, took the 68x68
# matrices calculated using ROIconnect and transformed them into DMN-DAN 
# connectivity matrices. The same script calculated averages using MATLAB's triu
# function to give us average connectivity in DMN, DAN, and DMN-DAN for all
# frequency bands and tasks for each participant.
#
# This R script will work with that MATLAB script's. .csv output.
#
# Written by Noor Tasnim on November 2, 2025


# Import Libraries and data --------------------------------------------------------

library(tidyverse)

fc <- read_csv("~/Google Drive/Shared drives/Embodied Brain Lab/Exergame and ADHD (IRB 23-811)/! Paper 2 Statistics/connectivity_analysis_results.csv") %>%
  filter(frequency_band == "alpha") %>%
  select(-frequency_band) %>% # remove frequency_band column because we only have alpha data
  select(-DMN_DAN_connectivity) %>%
  mutate(
    DMN_connectivity = if_else(
      (id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo") |
        (id == "exgm021" & session_number == 2 & task == "gonogo"),
      NA_real_,
      DMN_connectivity),
    DAN_connectivity = if_else(
      (id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo") |
        (id == "exgm021" & session_number == 2 & task == "gonogo"),
      NA_real_,
      DAN_connectivity)
    ) %>%
  mutate(participant_id = as.numeric(str_extract(id, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-id) %>%
  filter(!(session_number == 1 & task == "prebaseline")) # remove prebaseline from session 1
  

# Load Intervention Information
intervention_info <- readRDS("../demographicsPsych/results/Paper2_BaseDataForModeling.rds") %>%
  select(participant_id,intervention)

# Join Intervention Information
fc_intervention <- fc %>%
  left_join(intervention_info, by = "participant_id")

# Calculate Summary Statistics --------------------------------------------
# we will need to information on session and intervention
# Calculate mean and SD for each column by task
summary_stats <- fc_intervention %>%
  group_by(task,session_number,intervention) %>%
  summarise(
    DMN_connectivity = sprintf("%.2f (%.2f)", 
                               mean(DMN_connectivity, na.rm = TRUE), 
                               sd(DMN_connectivity, na.rm = TRUE)),
    DAN_connectivity = sprintf("%.2f (%.2f)", 
                               mean(DAN_connectivity, na.rm = TRUE), 
                               sd(DAN_connectivity, na.rm = TRUE))
  )

# Write to CSV
write.csv(summary_stats, "results/connectivity_summary_stats.csv", row.names = FALSE)


# Prepare Modeling Dataframes -----------------------------------------------------

#### Load Demographic Data ####
demographics <- readRDS("../demographicsPsych/results/Paper2_BaseDataForModeling.rds")

#### Balance Dataframe ####
balance <- fc %>%
  rename(session = session_number) %>%
  filter(str_detect(task, "shoulder|tandem")) %>%
  separate(task, into = c("stance", "trial"), sep = "_") %>%
  mutate(
    # Factor trial with specified levels
    trial = factor(trial, levels = c("1", "2", "3")),
    
    # Rename session levels
    session = factor(session, 
                     levels = c(1,2),
                     labels = c("session1", "session2"))
  )

# Join with Demographic Data
balance_model_df <- demographics %>%
  left_join(balance, by = "participant_id")

#### Cognition Dataframe ####
cognition <- fc %>%
  rename(session = session_number) %>%
  mutate(session = recode(session, `1` = "baseline", `2` = "intervention")) %>%
  filter(!str_detect(task, "shoulder|tandem")) %>%
  filter(!str_detect(task, "baseline")) %>%
  pivot_wider(
    names_from = session,
    values_from = c(DMN_connectivity, DAN_connectivity),
    names_glue = "{session}_{.value}"
  ) %>%
  mutate(diff_DMN_connectivity = intervention_DMN_connectivity - baseline_DMN_connectivity,
         diff_DAN_connectivity = intervention_DAN_connectivity - baseline_DAN_connectivity) %>%
  pivot_wider(
    names_from = task,
    values_from = c(baseline_DMN_connectivity, intervention_DMN_connectivity, baseline_DAN_connectivity,
    intervention_DAN_connectivity, diff_DMN_connectivity, diff_DAN_connectivity)
  )

# Join with Demographic Data
cognition_model_df <- demographics %>%
  left_join(cognition, by = "participant_id")

#### Baseline Dataframes ####

baseline <- fc %>%
  filter(str_detect(task, "baseline")) %>%
  select(-session_number) %>%
  pivot_wider(
    names_from = task,
    values_from = c(DMN_connectivity, DAN_connectivity)
  ) %>%
  mutate(
    diff_DMN_connectivity_baseline = DMN_connectivity_postbaseline - DMN_connectivity_prebaseline,
    diff_DAN_connectivity_baseline = DAN_connectivity_postbaseline - DAN_connectivity_prebaseline
  )

# Join with Demographic Data
baseline_model_df <- demographics %>%
  left_join(baseline, by = "participant_id")

# Save Modeling dataframes for analysis -----------------------------------

save(balance_model_df, baseline_model_df, cognition_model_df, file = "results/roiConnect_modeling_data.RData")


