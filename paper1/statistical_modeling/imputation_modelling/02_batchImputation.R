# IMPUTE MISSING VALUES
# For our multiple linear regression model to work, we need to impute missing 
# values. 
#
# Multiple imputation is often recommended, and we will use the (mice) library
# to perform this computation.
#
# Before imputing, it is important to find what values will be imputed. Thus,
# we'll first explore the values of our widened dataframe.
#
# INPUT
#   - "results/exergameWideForModel.RDS" - contains our wide dataframe that stored
#     metadata for each variable (this is important to maintain factored variables)
#
# AUTHOR: Noor Tasnim
# DATE CREATED: October 9, 2025
# DATE MODIFIED: October 9, 2025

# IMPORT LIBRARIES --------------------------------------------------------
library(tidyverse)
library(mice)

# GET TASK ID -------------------------------------------------------------
# Get job array task ID from environment
task_id <- as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID"))

# START LOGGING -----------------------------------------------------------
# Create logs directory if it doesn't exist
if(!dir.exists("logs")) dir.create("logs", recursive = TRUE)

# Open log file for this job
log_file <- sprintf("logs/imputation_%02d.log", task_id)
log_con <- file(log_file, open = "wt")

# Redirect output and messages
sink(log_con, split = TRUE)
sink(log_con, type = "message")

# Print start time
cat(sprintf("\n========================================\n"))
cat(sprintf("JOB %d STARTED\n", task_id))
cat(sprintf("Start time: %s\n", Sys.time()))
cat(sprintf("========================================\n\n"))

# LOAD DATA AND SELECT OUTCOME OF INTEREST -----------------------------------
# The dataframe has 3 possible outcomes that we can use for modelling. Ideally,
# we want to keep a dataframe that has the following structure of columns:
# {id,outcome,predictor1...predictorX}

# We will remove asrs_6_total and asrs_6_total_category for now, but they can be
# used in the future

# Load dataframe
modeling_df <- readRDS("results/exergameWideForModel.RDS") %>%
  select(-asrs_6_total,-asrs_6_total_category)

# Calculate percentage missing per variable and export
missing_summary <- modeling_df %>%
  summarise_all(~sum(is.na(.)/n()*100))
write_csv(missing_summary, sprintf("results/Missing_Data_Summary_job%02d.csv", task_id))

# Record Keeping of Missing Variables
missing_vars <- names(modeling_df)[colSums(is.na(modeling_df)) > 0]
cat("Number of variables with missing data:", length(missing_vars), "\n")
missing_percent <- colMeans(is.na(modeling_df[missing_vars])) * 100
cat("\nMissing percentages range from", 
    round(min(missing_percent), 1), "% to", 
    round(max(missing_percent), 1), "%\n")

# SETTING UP MICE ---------------------------------------------------------
# Since all missing data is continuous, we only need one imputation method
# PMM (Predictive Mean Matching) is ideal because it:
# - Preserves the original data distribution
# - Cannot create impossible values (e.g., negative reaction times)
# - Works well with skewed distributions (common in reaction time/neural data)

# Initialize mice
init_mice <- mice(modeling_df, maxit = 0, printFlag = FALSE)

# Set ALL imputation methods to PMM (for continuous variables)
methods <- init_mice$method
methods[methods != ""] <- "pmm"  # Change all non-empty methods to pmm

# Don't impute complete variables or IDs
methods["participant_id"] <- ""
methods["asrs_18_total"] <- ""  # Your outcome variable

# OPTIMIZE PREDICTOR SELECTION --------------------------------------------
# With 729 predictors and 67 participants, we need smart predictor selection
# Use quickpred to automatically select variables that should predict each
# missing variable
#
# INPUTS
# - mincor = 0.1 -> Only includes variables with correlation ≥ 0.1 with the target variable
# - minpuc = 0.05 -> Only includes variables that have at least 5% of cases where 
#   both the predictor and target are observed
# - include = (variables ALWAYS used to predict each missing variable)

pred_matrix <- quickpred(
  modeling_df,
  mincor = 0.1,     # Lower threshold since we have many variables
  minpuc = 0.05,    # Minimum proportion of usable cases
  include = c("asrs_18_total", "asset_inattentive","asset_hyperactive",
              "adhd_med_type","antidepressant","sex","bdi_total","bai_total",
              "race","ethnicity","education","time"),
  exclude = "participant_id",
  method = "pearson"
)

# Special handling for Go/No-Go variables (participants 108 & 136)
# Ensure Go/No-Go variables predict each other since they're from same task
gonogo_vars <- names(modeling_df)[grep("go", names(modeling_df))]
gonogo_missing <- gonogo_vars[gonogo_vars %in% missing_vars]

if(length(gonogo_missing) > 0) {
  for(var in gonogo_missing) {
    # Use other gonogo variables to predict missing gonogo values
    pred_matrix[var, gonogo_vars] <- 1
  }
}

# Similarly for ERP components - use related components as predictors

erp_patterns <- c("_N2_","Pz_P3b_","Cz_P3b_","ERN_", "FRN_")
for(pattern in erp_patterns) {
  erp_vars <- names(modeling_df)[grep(pattern, names(modeling_df))]
  erp_missing <- erp_vars[erp_vars %in% missing_vars]
  
  if(length(erp_missing) > 0) {
    for(var in erp_missing) {
      pred_matrix[var, erp_vars] <- 1
    }
  }
}

# Group clusters for cluster-specific predictors
clusters <- c(3, 5, 9, 10, 11, 12, 13)

for(cluster_num in clusters) {
  # Pattern to match this specific cluster's variables
  cluster_pattern <- paste0("^cluster", cluster_num, "_")
  cluster_vars <- names(modeling_df)[grep(cluster_pattern, names(modeling_df))]
  cluster_missing <- cluster_vars[cluster_vars %in% missing_vars]
  
  if(length(cluster_missing) > 0) {
    for(var in cluster_missing) {
      # Use same-cluster variables as predictors
      pred_matrix[var, cluster_vars] <- 1
    }
  }
  
  # Also use the cluster membership indicator as predictor
  ic_var <- paste0("ic_in_cluster", cluster_num)
  if(ic_var %in% names(modeling_df)) {
    pred_matrix[cluster_missing, ic_var] <- 1
  }
}


# PERFORM SINGLE IMPUTATION ---------------------------------------------

# Use task_id to ensure unique seed
seed_value <- 100 + task_id  # Seeds: 101, 102, ..., 125
set.seed(seed_value)

cat(sprintf("\n========================================\n"))
cat(sprintf("STARTING IMPUTATION\n"))
cat(sprintf("Job ID: %d\n", task_id))
cat(sprintf("Seed: %d\n", seed_value))
cat(sprintf("Imputation start time: %s\n", Sys.time()))
cat(sprintf("========================================\n\n"))

imputed_data_single <- mice(
  modeling_df,
  m = 1,# single imputation
  method = methods,
  predictorMatrix = pred_matrix,
  maxit = 5,        # Usually sufficient for PMM with <25% missing
  seed = seed_value,
  printFlag = TRUE
)

cat(sprintf("\n========================================\n"))
cat(sprintf("IMPUTATION COMPLETE\n"))
cat(sprintf("Imputation end time: %s\n", Sys.time()))
cat(sprintf("========================================\n\n"))

# Save with task ID in filename
output_file <- sprintf("results/imputed_job_%02d.RDS", task_id)
saveRDS(imputed_data_single, output_file)
cat(sprintf("Saved to: %s\n", output_file))

# COMPLETION MESSAGES -----------------------------------------------------
cat(sprintf("\n========================================\n"))
cat(sprintf("JOB %d FINISHED SUCCESSFULLY\n", task_id))
cat(sprintf("End time: %s\n", Sys.time()))
cat(sprintf("========================================\n"))

# Close log file
sink(type = "message")
sink()
close(log_con)