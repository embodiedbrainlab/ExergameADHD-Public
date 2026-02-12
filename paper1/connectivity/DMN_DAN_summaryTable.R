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

fc <- read_csv("../statistical_modeling/results/connectivity_analysis_results.csv") %>%
  filter(frequency_band == "alpha") %>%
  mutate(
    DMN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DMN_connectivity),
    DAN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DAN_connectivity),
    DMN_DAN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DMN_DAN_connectivity
    ))

# Calculate Summary Statistics --------------------------------------------

# Calculate mean and SD for each column by task
summary_stats <- fc %>%
  group_by(task) %>%
  summarise(
    DMN_connectivity = sprintf("%.2f (%.2f)", 
                               mean(DMN_connectivity, na.rm = TRUE), 
                               sd(DMN_connectivity, na.rm = TRUE)),
    DAN_connectivity = sprintf("%.2f (%.2f)", 
                               mean(DAN_connectivity, na.rm = TRUE), 
                               sd(DAN_connectivity, na.rm = TRUE)),
    DMN_DAN_connectivity = sprintf("%.2f (%.2f)", 
                                   mean(DMN_DAN_connectivity, na.rm = TRUE), 
                                   sd(DMN_DAN_connectivity, na.rm = TRUE))
  )

# Write to CSV
write.csv(summary_stats, "../results/DMN_DAN_plotting/connectivity_summary_stats.csv", row.names = FALSE)


# Calculate Correlations with ASRS ----------------------------------------

# Pull in main dataframe
exergame <- readRDS("../statistical_modeling/results/exergame_forFinalModel.rds") %>%
  select(participant_id, asrs_18_total)

# Widen functional connectivity dataframe
fc_wide <- fc %>%
  select(-session_number, -frequency_band) %>%
  mutate(participant_id = as.numeric(sub("exgm", "", id))) %>%
  relocate(participant_id) %>% 
  select(-id) %>%
  pivot_wider(
    names_from = task,
    values_from = c(DMN_connectivity, DAN_connectivity, DMN_DAN_connectivity),
    names_glue = "{task}_{.value}"
  )

# Join with exergame dataframe
combined_data <- exergame %>%
  left_join(fc_wide, by = "participant_id")

# Calculate Pearson correlations with asrs_18_total
# Exclude participant_id from correlations
correlation_results <- combined_data %>%
  select(-participant_id) %>%
  names() %>%
  setdiff("asrs_18_total") %>%  # Get all column names except asrs_18_total
  sapply(function(col) {
    test <- cor.test(combined_data[[col]], 
                     combined_data$asrs_18_total, 
                     method = "pearson", 
                     use = "complete.obs")
    sprintf("%.3f (%.3f)", test$estimate, test$p.value)
  }) %>%
  data.frame(
    Variable = names(.),
    `Correlation (p-value)` = .,
    row.names = NULL,
    check.names = FALSE
  )

# Export to CSV
write.csv(correlation_results, "../results/DMN_DAN_plotting/connectivity_correlations_with_asrs.csv", row.names = FALSE)

# Display results
print(correlation_results)
  
