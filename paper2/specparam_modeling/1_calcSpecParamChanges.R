# Calculate Changes for SpecParam Peak Values
# We used the tidyPaper2SpecparamForModeling.R script to extract peak values for
# each frequency band.
#
# We will now import the fully widened .csv file, and calculate difference columns of
# interest.
#
# Note to self, we extracted pre and post baseline values from session. For this
# difference, we should only use the baselines from the second session to accurately
# measure acute effects. For the other tasks, we shouldn't need to consider differences
# in pre-baseline across the two sessions because we are already accounting for
# the baseline measurement for that task from session 1.
#
# Written by Noor Tasnim on November 15, 2025


# Import Libraries and Data -----------------------------------------------

library(tidyverse)
peaks <- read_csv("results/wideClusterData/peaks_wide_all_clusters.csv") %>%
  select(-matches("baseline_([3-9]|1[0-2])_prebaseline")) %>% # remove s1_prebaseline
  select(-matches("baseline_([3-9]|1[0-2])_postbaseline")) %>% # remove s1_postbaseline columns
  select(-contains("ic_in")) # remove ic_in columns

# Calculate Differences for Variables Except Baseline ---------------------------------------------------

# Extract variable names from baseline columns
baseline_cols <- grep("^baseline", names(peaks), value = TRUE)
var_names <- sub("^baseline_?", "", baseline_cols)

# Create difference columns
diff_data <- map_dfc(var_names, function(var) {
  baseline <- peaks[[paste0("baseline_", var)]]
  intervention <- peaks[[paste0("intervention_", var)]]
  tibble(!!paste0("diff_", var) := intervention - baseline)
})

# Calculate Differences for Prebaseline/Postbaseline Pairs ----------------

# Extract intervention prebaseline columns
prebaseline_cols <- grep("^intervention_.*_prebaseline_", names(peaks), value = TRUE)

# Create difference columns for prebaseline/postbaseline pairs
prepost_diff_data <- map_dfc(prebaseline_cols, function(pre_col) {
  # Create the corresponding postbaseline column name
  post_col <- sub("_prebaseline_", "_postbaseline_", pre_col)
  
  # Check if the postbaseline column exists
  if (post_col %in% names(peaks)) {
    # Calculate difference (postbaseline - prebaseline)
    diff <- peaks[[post_col]] - peaks[[pre_col]]
    
    # Create diff column name: intervention_5_prebaseline_alpha -> diff_5_baseline_alpha
    diff_col_name <- sub("^intervention_", "diff_", sub("_prebaseline_", "_baseline_", pre_col))
    
    tibble(!!diff_col_name := diff)
  }
})

# Modeling Dataframe
peaks_modeling_df <- bind_cols(peaks, diff_data, prepost_diff_data)

# Save Final Dataframe for Modeling
write_csv(peaks_modeling_df, "results/peaks_modeling_df.csv")
