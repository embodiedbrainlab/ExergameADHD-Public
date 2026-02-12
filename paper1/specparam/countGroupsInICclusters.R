# COUNT NUMBER OF DATASETS IN EACH CLUSTER
# The Salminen et al. (2025) paper showed all the clusters they used for their
# analysis, however, the ones they presented in their main text had at least 50%
# representation of all groups that were being compared.
#
# This script will run through each of the clusters that were identified using
# dipole locations and optimal k-means clustering (including the 3 SD outlier
# group [cluster 2]) and count how many participants from each group are included
# within the cluster. 
#
# This will also calculate how many clusters each participant was included in.
# We will most likely include all participants, but this will also be worthwhile
# supplementary information.
#
# IMPORTANT: This assumes that you already have an `exergame_tidy` spreadsheet
# created from cleaning the REDCap export and adding medication status groupings
# to each participant.
#
# IMPORTANT EDIT: These values are only based on the ICs that were entered into the
# initial model but DO NOT include 229 spectra that were removed due to poor data quality
# and model fitting.
#   - So we will need to find who had their respective spectra removed, what activities these
#     spectra were associated with to determine what to analyze further.
#
# Written by Noor Tasnim on August 28, 2025
# ---
# Edited by Noor on October 28, 2025 to group by ASRS categories instead of stimulant meds

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(fs)

# Set Directories ---------------------------------------------------------

# Location of IC cluster files
cluster_data_path <- "../results/IC_clusters/pruned_clusters/"

# Read the exergame data and select for id and med_type
exergame_data <- read_csv("../demographicsPsych/data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  select(participant_id,asrs_6_total_category)

# Functions to standardize subject IDs for matching ------------------------
standardize_subject_id <- function(subject_id) {
  # Remove "exgm" prefix and leading zeros, convert to numeric then back to character
  # This handles both formats: "exgm002" -> "2", "2" -> "2"
  if (is.character(subject_id)) {
    # Remove "exgm" prefix if present
    cleaned_id <- str_replace(subject_id, "^exgm", "")
    # Convert to numeric to remove leading zeros, then back to character
    as.character(as.numeric(cleaned_id))
  } else {
    as.character(subject_id)
  }
}

# Convert participant_id to character for matching
exergame_data <- exergame_data %>%
  mutate(participant_id = as.character(participant_id))

# Standardize participant_id for matching
exergame_data <- exergame_data %>%
  mutate(standardized_id = standardize_subject_id(as.character(participant_id)))



# Get all cluster CSV files in the specified directory
cluster_files <- dir_ls(path = cluster_data_path, glob = "*.csv")

# Read and combine all cluster data
all_cluster_data <- map_dfr(cluster_files, function(file) {
  cluster_name <- str_remove(basename(file), "\\.csv$")
  
  read_csv(file) %>%
    mutate(
      cluster_name = cluster_name,
      standardized_subject = standardize_subject_id(subject)
    )
})

# Join cluster data with medication information
cluster_with_asrs <- all_cluster_data %>%
  left_join(exergame_data, 
            by = c("standardized_subject" = "participant_id"))

# 1. Count participants by medication type in each cluster
participants_by_cluster_med <- cluster_with_asrs %>%
  group_by(cluster_name, asrs_6_total_category) %>%
  summarise(
    n_participants = n_distinct(standardized_subject),
    .groups = "drop"
  ) %>%
  # Create a complete grid to show all combinations (including zeros)
  complete(cluster_name, asrs_6_total_category, fill = list(n_participants = 0)) %>%
  arrange(cluster_name, asrs_6_total_category)

# 2. Count number of clusters each subject appears in
clusters_per_subject <- all_cluster_data %>%
  group_by(standardized_subject) %>%
  summarise(
    original_subject_id = first(subject),
    n_clusters = n_distinct(cluster_name),
    clusters_list = paste(sort(unique(cluster_name)), collapse = ", "),
    .groups = "drop"
  ) %>%
  # Add medication information
  left_join(exergame_data, 
            by = c("standardized_subject" = "participant_id")) %>%
  arrange(desc(n_clusters), standardized_subject)

# Display results
cat("=== PARTICIPANTS BY MEDICATION TYPE IN EACH CLUSTER ===\n")
print(participants_by_cluster_med)

cat("\n=== SUMMARY: Total participants by medication type across all clusters ===\n")
participants_by_cluster_med %>%
  group_by(asrs_6_total_category) %>%
  summarise(total_participant_instances = sum(n_participants)) %>%
  print()

cat("\n=== CLUSTERS PER SUBJECT ===\n")
print(clusters_per_subject)

cat("\n=== SUMMARY: Distribution of subjects by number of clusters ===\n")
clusters_per_subject %>%
  count(n_clusters, name = "n_subjects") %>%
  mutate(percentage = round(n_subjects / sum(n_subjects) * 100, 1)) %>%
  print()

# Save results to CSV files
write_csv(participants_by_cluster_med, "../results/specparam/participants_by_cluster_medication.csv")
write_csv(clusters_per_subject, "../results/specparam/clusters_per_subject.csv")

# Create a wide format table for easier viewing
participants_wide <- participants_by_cluster_med %>%
  pivot_wider(
    names_from = asrs_6_total_category,
    values_from = n_participants,
    values_fill = 0
  )

write_csv(participants_wide, "../results/specparam/participants_by_cluster_medication_wide.csv")

cat("\n=== FILES SAVED ===\n")
cat("- participants_by_cluster_medication.csv (long format)\n")
cat("- participants_by_cluster_medication_wide.csv (wide format)\n") 
cat("- clusters_per_subject.csv\n")

# Optional: Create a summary of unmatched subjects
unmatched_cluster_subjects <- all_cluster_data %>%
  anti_join(exergame_data, by = c("standardized_subject" = "participant_id")) %>%
  distinct(subject, standardized_subject)

unmatched_exergame_subjects <- exergame_data %>%
  anti_join(all_cluster_data, by = c("participant_id" = "standardized_subject")) %>%
  distinct(participant_id, participant_id)

if (nrow(unmatched_cluster_subjects) > 0) {
  cat("\n=== WARNING: Subjects in cluster files but not in exergame data ===\n")
  print(unmatched_cluster_subjects)
}

if (nrow(unmatched_exergame_subjects) > 0) {
  cat("\n=== WARNING: Subjects in exergame data but not in cluster files ===\n")
  print(unmatched_exergame_subjects)
}