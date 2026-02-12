# EEG Spectral Peaks Data Transformation for Paper 2 Linear Models
# Transform long-format EEG spectral peak data into wide-format dataframes 
# suitable for the calculation of changes in power for linear modeling in 
# Paper 2.
#
# PURPOSE:
# This script transforms spectral peak data from SpecParam models into wide-format
# dataframes. Each cluster is processed separately, and all clusters are combined
# into a single wide dataframe for multi-cluster analysis. NOW HANDLES TWO SESSIONS.
#
# INPUT DATA:
# - peaks.csv: Contains identified spectral peaks with power values (pw), 
#   frequency bands, clusters, experiences, and SESSIONS
# - model_metrics.csv: Lists all participants with valid independent components 
#   in each cluster, which experiences were analyzed, and SESSIONS
#
# OUTPUT:
# Wide-format dataframes where:
# - Each row = one participant (63 total)
# - Columns per cluster per session:
#   - subject: Participant ID
#   - {session}_ic_in_X: Binary cluster membership per session (1 = has component, 0 = no component)
#   - {session}_{cluster}_{experience}_{freq_band}: Power values for each combination
#     where session is "baseline" (s1) or "intervention" (s2)
# - Values:
#   - Numeric (>0): Average power of peaks in that frequency band
#   - 0: Participant-session in cluster but no peak found for that frequency band
#   - NA: Participant-session not in cluster OR participant-session in cluster but experience not analyzed
#
# KEY FEATURES:
# - Handles multiple peaks per frequency band by averaging power values
# - Maintains custom ordering of experiences and frequency bands
# - Processes clusters 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
# - Creates individual cluster files and combined multi-cluster file
# - Tracks baseline (s1) and intervention (s2) sessions separately
# - Handles postbaseline experience (intervention-only)
#
# FREQUENCY BANDS:
# theta, alpha, low_beta, high_beta, gamma
#
# EXPERIENCES (in order):
# prebaseline, digitforward, digitbackward, gonogo, stroop, wcst,
# shoulder_1, shoulder_2, shoulder_3, tandem_1, tandem_2, tandem_3, postbaseline
# NOTE: postbaseline only occurs in intervention (s2) session
#
# OUTPUT FILES:
# - Individual: results/wideClusterData/cluster_X_wide.csv
# - Combined: results/wideClusterData/peaks_wide_all_clusters.csv
#
# AUTHOR: Noor Tasnim
# DATE: November 2025
# VERSION: 3.0 (Two-Session Support)

# Load Libraries ---------------------------------------------------------------
library(tidyverse)

# Configuration ----------------------------------------------------------------
# Define clusters to process
clusters_to_process <- c(3,4,5,6,7,8,9,10,11,12)

# Define all participants in the study (63 total)
participants_to_keep <- c(2,3,4,5,10,12,16,18,19,20,21,23,25,31,43,46,47,48,50,
                          51,57,78,79,81,82,84,87,90,97,102,105,107,108,109,
                          111,116,117,119,120,121,122,132,133,136,144,145,146,149,
                          154,156,162,164,169,171,172,179,181,182,184,
                          185,188,190,193)

all_study_subjects <- paste0("exgm", sprintf("%03d", participants_to_keep))

# Define sessions and their labels
sessions <- c("s1", "s2")
session_labels <- c(s1 = "baseline", s2 = "intervention")

# Define custom order for variables
all_experiences <- c("prebaseline", "digitforward", "digitbackward", "gonogo", 
                     "stroop", "wcst", "shoulder_1", "shoulder_2", "shoulder_3",
                     "tandem_1", "tandem_2", "tandem_3", "postbaseline")

all_freq_bands <- c("theta", "alpha", "low_beta", "high_beta", "gamma")

# Load Data --------------------------------------------------------------------
cat("Loading data files...\n")

# Load and filter model metrics
model_metrics <- read_csv("data/Paper2_sedentary_model_metrics.csv") %>%
  filter(cluster %in% clusters_to_process)

# Load and process peaks data (convert power to dB)
peaks <- read_csv("data/Paper2_sedentary_peaks.csv") %>%
  mutate(pw_db = pw * 10) %>%
  filter(cluster %in% clusters_to_process)

cat("Data loaded successfully\n")
cat("Model metrics entries:", nrow(model_metrics), "\n")
cat("Peaks entries:", nrow(peaks), "\n")
cat("Sessions in data:", paste(unique(model_metrics$session), collapse = ", "), "\n\n")

# Process Each Cluster ---------------------------------------------------------
process_cluster <- function(cluster_num, 
                            peaks_data, 
                            model_metrics_data, 
                            all_subjects,
                            experiences = all_experiences,
                            freq_bands = all_freq_bands,
                            sessions = sessions,
                            session_labels = session_labels) {
  
  cat("Processing cluster", cluster_num, "...\n")
  
  # Filter data for this specific cluster
  peaks_cluster <- peaks_data %>% 
    filter(cluster == cluster_num)
  
  model_metrics_cluster <- model_metrics_data %>% 
    filter(cluster == cluster_num)
  
  # Get participant-session combinations in this cluster
  participants_sessions_in_cluster <- model_metrics_cluster %>%
    distinct(subject, session)
  
  cat("  Subject-Session pairs in cluster:", nrow(participants_sessions_in_cluster), "\n")
  
  # Get valid subject-session-experience combinations from model_metrics
  valid_combinations <- model_metrics_cluster %>%
    distinct(subject, session, experience)
  
  # Process peaks: average power when multiple peaks exist in same frequency band
  peaks_averaged <- peaks_cluster %>%
    group_by(subject, session, experience, freq_band) %>%
    summarise(pw_db = mean(pw_db, na.rm = TRUE), 
              .groups = "drop")
  
  # Create complete grid for ALL subjects and sessions
  # We'll handle who's in the cluster vs not in the process
  complete_grid <- expand_grid(
    subject = all_subjects,
    session = sessions,
    experience = experiences,
    freq_band = freq_bands
  ) %>%
    # Add indicator for whether this subject-session is in cluster
    left_join(
      participants_sessions_in_cluster %>% mutate(in_cluster = TRUE),
      by = c("subject", "session")
    ) %>%
    # Mark which subject-session-experience combinations are valid based on model_metrics
    left_join(
      valid_combinations %>% mutate(has_data = TRUE),
      by = c("subject", "session", "experience")
    ) %>%
    # Join with peaks data
    left_join(
      peaks_averaged,
      by = c("subject", "session", "experience", "freq_band")
    ) %>%
    # Set values based on data availability and cluster membership
    mutate(
      pw_db = case_when(
        is.na(in_cluster) ~ NA_real_,    # Subject-session not in cluster
        is.na(has_data) ~ NA_real_,      # Experience not analyzed for this subject-session
        is.na(pw_db) ~ 0,                # No peak found (but data exists)
        TRUE ~ pw_db                     # Peak found - use the value
      )
    ) %>%
    select(-has_data, -in_cluster)
  
  # Pivot to wide format
  peaks_wide <- complete_grid %>%
    # Create column names with session labels
    mutate(
      session_label = session_labels[session],
      column_name = paste(session_label, cluster_num, experience, freq_band, sep = "_"),
      # Ensure proper ordering
      experience = factor(experience, levels = experiences),
      freq_band = factor(freq_band, levels = freq_bands),
      session = factor(session, levels = sessions)
    ) %>%
    # Pivot wider
    pivot_wider(
      id_cols = subject,
      names_from = column_name,
      values_from = pw_db
    )
  
  # Add cluster membership indicators for each session
  for (sess in sessions) {
    sess_label <- session_labels[sess]
    participants_in_session <- participants_sessions_in_cluster %>%
      filter(session == sess) %>%
      pull(subject)
    
    peaks_wide <- peaks_wide %>%
      mutate(
        !!paste0(sess_label, "_ic_in_", cluster_num) := 
          if_else(subject %in% participants_in_session, 1, 0)
      )
  }
  
  # Reorder columns: subject, ic_in indicators, then features
  ic_cols <- paste0(session_labels, "_ic_in_", cluster_num)
  peaks_wide <- peaks_wide %>%
    select(subject, all_of(ic_cols), everything()) %>%
    arrange(subject)
  
  # Verification statistics
  feature_cols <- peaks_wide %>% 
    select(-subject, -starts_with("baseline_ic_in"), -starts_with("intervention_ic_in"))
  
  cat("  Final dimensions:", nrow(peaks_wide), "rows x", ncol(peaks_wide), "columns\n")
  for (sess in sessions) {
    sess_label <- session_labels[sess]
    ic_col <- paste0(sess_label, "_ic_in_", cluster_num)
    cat("  Participants with IC in", sess_label, "session:", 
        sum(peaks_wide[[ic_col]]), "\n")
  }
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
    all_subjects = all_study_subjects,
    sessions = sessions,
    session_labels = session_labels
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
    "(expected: 63)\n")

# Calculate expected columns
n_clusters <- length(clusters_to_process)
n_sessions <- length(sessions)
n_features_per_cluster_session <- length(all_experiences) * length(all_freq_bands)
# Each cluster has: 2 ic_in columns (baseline + intervention) + (2 sessions * features)
expected_cols <- 1 + (n_clusters * n_sessions) + (n_clusters * n_sessions * n_features_per_cluster_session)
cat("  Expected columns:", expected_cols, "\n")
cat("    - 1 subject column\n")
cat("    -", n_clusters * n_sessions, "cluster membership indicators (", n_clusters, 
    "clusters x", n_sessions, "sessions)\n")
cat("    -", n_clusters * n_sessions * n_features_per_cluster_session, 
    "feature columns (", n_clusters, "clusters x", n_sessions, "sessions x", 
    n_features_per_cluster_session, "features)\n")

# Check data integrity
cat("\nData integrity checks:\n")
cat("  All participants present?", 
    all(all_study_subjects %in% peaks_wide_all_clusters$subject), "\n")
cat("  Any duplicate columns?", 
    any(duplicated(names(peaks_wide_all_clusters))), "\n")
cat("  Any missing participants?", 
    any(!all_study_subjects %in% peaks_wide_all_clusters$subject), "\n")

# Display sample of combined dataframe
cat("\nSample of combined dataframe (first 5 rows, first 12 columns):\n")
print(peaks_wide_all_clusters[1:5, 1:min(12, ncol(peaks_wide_all_clusters))])

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
cat("Sessions processed: baseline (s1) and intervention (s2)\n")
cat("Output files created:\n")
cat("  - Individual cluster files:", length(cluster_data_list), "files\n")
cat("  - Combined file: peaks_wide_all_clusters.csv\n")
cat("Total participants:", length(all_study_subjects), "\n")
cat("Total features per cluster per session:", n_features_per_cluster_session, "\n")
cat("Total features per cluster (both sessions):", 
    n_features_per_cluster_session * n_sessions, "\n")
cat(strrep("=", 60), "\n")
