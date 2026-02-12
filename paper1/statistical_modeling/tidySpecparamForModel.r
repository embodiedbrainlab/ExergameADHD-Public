# EEG Spectral Peaks Data Transformation for LASSO GLM Analysis (Simplified Version)
# Transform long-format EEG spectral peak data into wide-format dataframes 
# suitable for generalized linear models (GLM) with LASSO penalization.
#
# PURPOSE:
# This script transforms spectral peak data from SpecParam models into wide-format
# dataframes. Each cluster is processed separately, and all clusters are combined
# into a single wide dataframe for multi-cluster analysis.
#
# INPUT DATA:
# - peaks.csv: Contains identified spectral peaks with power values (pw), 
#   frequency bands, clusters, and experiences
# - model_metrics.csv: Lists all participants with valid independent components 
#   in each cluster and which experiences were analyzed
#
# OUTPUT:
# Wide-format dataframes where:
# - Each row = one participant (67 total)
# - Columns per cluster:
#   - subject: Participant ID
#   - ic_in_X: Binary cluster membership (1 = has component, 0 = no component)
#   - {cluster}_{experience}_{freq_band}: Power values for each combination
# - Values:
#   - Numeric (>0): Average power of peaks in that frequency band
#   - 0: Participant in cluster but no peak found for that frequency band
#   - NA: Participant not in cluster OR participant in cluster but experience not analyzed
#
# KEY FEATURES:
# - Handles multiple peaks per frequency band by averaging power values
# - Maintains custom ordering of experiences and frequency bands
# - Processes clusters 3, 5, 9, 10, 11, 12, 13 only
# - Creates individual cluster files and combined multi-cluster file
#
# FREQUENCY BANDS:
# theta, alpha, low_beta, high_beta, gamma
#
# EXPERIENCES (in order):
# prebaseline, digitforward, digitbackward, gonogo, stroop, wcst,
# shoulder_1, shoulder_2, shoulder_3, tandem_1, tandem_2, tandem_3
#
# OUTPUT FILES:
# - Individual: results/wideClusterData/cluster_X_wide.csv
# - Combined: results/wideClusterData/peaks_wide_all_clusters.csv
#
# AUTHOR: Noor Tasnim
# DATE: October 2025
# VERSION: 2.0 (Simplified)

# Load Libraries ---------------------------------------------------------------
library(tidyverse)

# Configuration ----------------------------------------------------------------
# Define clusters to process
clusters_to_process <- c(3, 5, 9, 10, 11, 12, 13)

# Define all participants in the study (67 total)
participants_to_keep <- c(2, 3, 4, 5, 10, 12, 16, 18, 19, 20, 21, 23, 25, 31, 43, 
                          46, 47, 48, 50, 51, 57, 77, 78, 79, 81, 82, 84, 87, 90, 
                          97, 102, 105, 107, 108, 109, 111, 116, 117, 119, 120, 
                          121, 122, 132, 133, 136, 144, 145, 146, 149, 152, 154, 
                          156, 160, 162, 164, 169, 171, 172, 175, 179, 181, 182, 
                          184, 185, 188, 190, 193)

all_study_subjects <- paste0("exgm", sprintf("%03d", participants_to_keep))

# Define custom order for variables
all_experiences <- c("prebaseline", "digitforward", "digitbackward", "gonogo", 
                     "stroop", "wcst", "shoulder_1", "shoulder_2", "shoulder_3",
                     "tandem_1", "tandem_2", "tandem_3")

all_freq_bands <- c("theta", "alpha", "low_beta", "high_beta", "gamma")

# Load Data --------------------------------------------------------------------
cat("Loading data files...\n")

# Load and filter model metrics
model_metrics <- read_csv("../results/specparam/final_model/model_metrics.csv") %>%
  filter(cluster %in% clusters_to_process)

# Load and process peaks data (convert power to dB)
peaks <- read_csv("../results/specparam/final_model/peaks.csv") %>%
  mutate(pw_db = pw * 10) %>%
  filter(cluster %in% clusters_to_process)

cat("Data loaded successfully\n")
cat("Model metrics entries:", nrow(model_metrics), "\n")
cat("Peaks entries:", nrow(peaks), "\n\n")

# Process Each Cluster ---------------------------------------------------------
process_cluster <- function(cluster_num, 
                            peaks_data, 
                            model_metrics_data, 
                            all_subjects,
                            experiences = all_experiences,
                            freq_bands = all_freq_bands) {
  
  cat("Processing cluster", cluster_num, "...\n")
  
  # Filter data for this specific cluster
  peaks_cluster <- peaks_data %>% 
    filter(cluster == cluster_num)
  
  model_metrics_cluster <- model_metrics_data %>% 
    filter(cluster == cluster_num)
  
  # Get participants in this cluster
  participants_in_cluster <- model_metrics_cluster %>%
    distinct(subject) %>%
    pull(subject)
  
  cat("  Participants in cluster:", length(participants_in_cluster), "\n")
  
  # Get valid subject-experience combinations from model_metrics
  valid_combinations <- model_metrics_cluster %>%
    distinct(subject, experience)
  
  # Process peaks: average power when multiple peaks exist in same frequency band
  peaks_averaged <- peaks_cluster %>%
    group_by(subject, experience, freq_band) %>%
    summarise(pw_db = mean(pw_db, na.rm = TRUE), 
              .groups = "drop")
  
  # Create complete grid for participants IN the cluster
  if (length(participants_in_cluster) > 0) {
    # Grid for participants in cluster
    cluster_grid <- expand_grid(
      subject = participants_in_cluster,
      experience = experiences,
      freq_band = freq_bands
    ) %>%
      # Mark which combinations are valid based on model_metrics
      left_join(
        valid_combinations %>% mutate(has_data = TRUE),
        by = c("subject", "experience")
      ) %>%
      # Join with peaks data
      left_join(
        peaks_averaged,
        by = c("subject", "experience", "freq_band")
      ) %>%
      # Set values based on data availability
      mutate(
        pw_db = case_when(
          is.na(has_data) ~ NA_real_,  # Experience not analyzed for this participant
          is.na(pw_db) ~ 0,             # No peak found (but data exists)
          TRUE ~ pw_db                  # Peak found - use the value
        )
      ) %>%
      select(-has_data)
  } else {
    # Empty tibble if no participants in cluster
    cluster_grid <- tibble()
  }
  
  # Create data for participants NOT in the cluster (all NAs)
  participants_not_in_cluster <- setdiff(all_subjects, participants_in_cluster)
  
  if (length(participants_not_in_cluster) > 0) {
    not_in_cluster_grid <- expand_grid(
      subject = participants_not_in_cluster,
      experience = experiences,
      freq_band = freq_bands
    ) %>%
      mutate(pw_db = NA_real_)  # All NAs for participants not in cluster
    
    # Combine both grids
    complete_grid <- bind_rows(cluster_grid, not_in_cluster_grid)
  } else {
    complete_grid <- cluster_grid
  }
  
  # Pivot to wide format
  peaks_wide <- complete_grid %>%
    # Create column names
    mutate(
      column_name = paste(cluster_num, experience, freq_band, sep = "_"),
      # Ensure proper ordering
      experience = factor(experience, levels = experiences),
      freq_band = factor(freq_band, levels = freq_bands)
    ) %>%
    # Pivot wider
    pivot_wider(
      id_cols = subject,
      names_from = column_name,
      values_from = pw_db
    ) %>%
    # Add cluster membership indicator
    mutate(
      !!paste0("ic_in_", cluster_num) := if_else(subject %in% participants_in_cluster, 1, 0)
    ) %>%
    # Reorder columns: subject, ic_in_X, then features
    select(subject, paste0("ic_in_", cluster_num), everything()) %>%
    # Sort by subject
    arrange(subject)
  
  # Verification statistics
  feature_cols <- peaks_wide %>% 
    select(-subject, -starts_with("ic_in"))
  
  cat("  Final dimensions:", nrow(peaks_wide), "rows x", ncol(peaks_wide), "columns\n")
  cat("  Participants with IC in cluster:", sum(peaks_wide[[paste0("ic_in_", cluster_num)]]), "\n")
  cat("  Non-zero values in features:", sum(feature_cols > 0, na.rm = TRUE), "\n")
  cat("  Zero values in features:", sum(feature_cols == 0, na.rm = TRUE), "\n")
  cat("  NA values in features:", sum(is.na(feature_cols)), "\n\n")
  
  return(peaks_wide)
}

# Main Processing --------------------------------------------------------------
cat("Starting cluster processing...\n\n")

# Process each cluster and store results
cluster_data_list <- list()

for (cluster_num in clusters_to_process) {
  cluster_data_list[[paste0("cluster_", cluster_num)]] <- process_cluster(
    cluster_num = cluster_num,
    peaks_data = peaks,
    model_metrics_data = model_metrics,
    all_subjects = all_study_subjects
  )
}

# Create output directory if it doesn't exist
if (!dir.exists("results/wideClusterData")) {
  dir.create("results/wideClusterData", recursive = TRUE)
  cat("Created output directory: results/wideClusterData\n")
}

# Save Individual Cluster Files ------------------------------------------------
cat("\nSaving individual cluster files...\n")

for (cluster_name in names(cluster_data_list)) {
  filename <- paste0("results/wideClusterData/", cluster_name, "_wide.csv")
  write_csv(cluster_data_list[[cluster_name]], filename)
  cat("  Saved:", filename, "\n")
}

# Create Combined Wide Dataframe -----------------------------------------------
cat("\nCreating combined wide dataframe...\n")

# Join all cluster dataframes by subject
peaks_wide_all_clusters <- cluster_data_list %>%
  reduce(full_join, by = "subject") %>%
  arrange(subject)

# Verification of combined dataframe
cat("\nCombined dataframe summary:\n")
cat("  Dimensions:", nrow(peaks_wide_all_clusters), "rows x", 
    ncol(peaks_wide_all_clusters), "columns\n")
cat("  Number of participants:", nrow(peaks_wide_all_clusters), 
    "(expected: 67)\n")

# Calculate expected columns
n_clusters <- length(clusters_to_process)
n_features_per_cluster <- length(all_experiences) * length(all_freq_bands)
expected_cols <- 1 + n_clusters + (n_clusters * n_features_per_cluster)
cat("  Expected columns:", expected_cols, "\n")
cat("    - 1 subject column\n")
cat("    -", n_clusters, "cluster membership indicators\n")
cat("    -", n_clusters * n_features_per_cluster, "feature columns\n")

# Check data integrity
cat("\nData integrity checks:\n")
cat("  All participants present?", 
    all(all_study_subjects %in% peaks_wide_all_clusters$subject), "\n")
cat("  Any duplicate columns?", 
    any(duplicated(names(peaks_wide_all_clusters))), "\n")
cat("  Any missing participants?", 
    any(!all_study_subjects %in% peaks_wide_all_clusters$subject), "\n")

# Display sample of combined dataframe
cat("\nSample of combined dataframe (first 5 rows, first 10 columns):\n")
print(peaks_wide_all_clusters[1:5, 1:min(10, ncol(peaks_wide_all_clusters))])

# Save combined dataframe
combined_filename <- "results/wideClusterData/peaks_wide_all_clusters.csv"
write_csv(peaks_wide_all_clusters, combined_filename)
cat("\nSaved combined file:", combined_filename, "\n")

# Final Summary ----------------------------------------------------------------
cat("\n" , strrep("=", 60), "\n")
cat("PROCESSING COMPLETE\n")
cat(strrep("=", 60), "\n")
cat("Processed", length(clusters_to_process), "clusters:", 
    paste(clusters_to_process, collapse = ", "), "\n")
cat("Output files created:\n")
cat("  - Individual cluster files:", length(cluster_data_list), "files\n")
cat("  - Combined file: peaks_wide_all_clusters.csv\n")
cat("Total participants:", length(all_study_subjects), "\n")
cat("Total features per cluster:", n_features_per_cluster, "\n")
cat(strrep("=", 60), "\n")
