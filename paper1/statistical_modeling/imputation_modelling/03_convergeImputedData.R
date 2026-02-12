# COMBINE IMPUTED DATASETS AND PERFORM DIAGNOSTICS
# This script combines the 25 separate imputation jobs into a single mice object,
# then performs convergence checks, diagnostic tests, and prepares the final
# dataset for LASSO regression.
#
# INPUT
#   - "results/imputed_job_01.RDS" through "results/imputed_job_25.RDS" - 
#     Individual imputation results from each job array task
#   - "results/exergameWideForModel.RDS" - Original data (needed for diagnostics)
#
# OUTPUT
#   - "results/imputed_mice_object.RDS" - Combined mice object with 25 imputations
#   - "results/imputed_complete_data.RDS" - Averaged complete dataset
#   - "results/lasso_ready_data.RDS" - Matrices X and y ready for LASSO
#
# AUTHOR: Noor Tasnim
# DATE CREATED: October 16, 2025
# DATE MODIFIED: October 16, 2025

# IMPORT LIBRARIES --------------------------------------------------------
library(tidyverse)
library(mice)
library(VIM)

# LOAD ORIGINAL DATA ------------------------------------------------------
# Need original data to identify missing variables for diagnostics
modeling_df <- readRDS("results/exergameWideForModel.RDS") %>%
  select(-asrs_6_total, -asrs_6_total_category)

missing_vars <- names(modeling_df)[colSums(is.na(modeling_df)) > 0]
missing_percent <- colMeans(is.na(modeling_df[missing_vars])) * 100

cat("Original data loaded\n")
cat("Number of variables with missing data:", length(missing_vars), "\n")
cat("Missing percentages range from", 
    round(min(missing_percent), 1), "% to", 
    round(max(missing_percent), 1), "%\n\n")

# LOAD AND COMBINE ALL 25 IMPUTED DATASETS -------------------------------
cat("Loading 25 imputed datasets...\n")

imputed_list <- list()
for(i in 1:25) {
  file_name <- sprintf("results/imputed_job_%02d.RDS", i)
  
  if(file.exists(file_name)) {
    imputed_list[[i]] <- readRDS(file_name)
    cat(sprintf("  ✓ Loaded job %02d\n", i))
  } else {
    stop(sprintf("ERROR: Missing file: %s\n", file_name))
  }
}

cat("\nCombining all imputations with ibind()...\n")

# Combine all imputations into single mice object
cat("\nCombining imputations sequentially...\n")
imputed_data <- imputed_list[[1]]

for(i in 2:25) {
  cat(sprintf("  Adding imputation %d of 25...\n", i))
  imputed_data <- ibind(imputed_data, imputed_list[[i]])
}

# Verify combination
cat(sprintf("✓ Combined successfully!\n"))
cat(sprintf("Total imputations in combined object: %d\n\n", imputed_data$m))

if(imputed_data$m != 25) {
  stop(sprintf("ERROR: Expected 25 imputations, got %d\n", imputed_data$m))
}

# Set number of imputations for downstream code
m_imputations <- 25

# CONVERGENCE CHECK -------------------------------------------------------

# Check convergence for variables with highest missingness
plot(imputed_data, layout = c(2, 3))


# DIAGNOSTIC CHECK --------------------------------------------------------

# Check distributions for variables with >10% missing
high_missing <- missing_vars[colMeans(is.na(modeling_df[missing_vars])) > 0.10]

if(length(high_missing) > 0) {
  # Plot first 6 high-missing variables
  vars_to_plot <- high_missing[1:min(6, length(high_missing))]
  densityplot(imputed_data, as.formula(paste("~", paste(vars_to_plot, collapse = "+"))))
}

# Verify no impossible values were created
complete_data_1 <- complete(imputed_data, 1)

# Check reaction times aren't negative
rt_vars <- names(complete_data_1)[grep("meanrt|meanRT", names(complete_data_1), ignore.case = TRUE)]
if(length(rt_vars) > 0) {
  negative_rts <- sapply(complete_data_1[rt_vars], function(x) any(x < 0, na.rm = TRUE))
  if(any(negative_rts)) {
    warning("Negative reaction times detected - PMM should prevent this!")
  } else {
    cat("\n✓ All reaction times are positive\n")
  }
}

# Check spectral power values aren't negative (power can't be negative)
power_vars <- names(complete_data_1)[grep("cluster.*_(theta|alpha|low_beta||high_beta|gamma)", names(complete_data_1))]
if(length(power_vars) > 0) {
  negative_power <- sapply(complete_data_1[power_vars], function(x) any(x < 0, na.rm = TRUE))
  if(any(negative_power)) {
    warning("Negative power values detected - Check these variables!")
  } else {
    cat("✓ All spectral power values are non-negative\n")
  }
}


# CREATE FINAL DATASET FOR LASSO ------------------------------------------

# For LASSO, we'll average across all imputations
# This is simpler than stacking and works well with regularization

final_data <- complete(imputed_data, 1)

# Average only the previously missing values across all imputations
for(i in 2:m_imputations) {
  temp_complete <- complete(imputed_data, i)
  for(var in missing_vars) {
    missing_idx <- is.na(modeling_df[[var]])
    if(any(missing_idx)) {
      # Running average
      final_data[missing_idx, var] <- ((i-1) * final_data[missing_idx, var] + 
                                         temp_complete[missing_idx, var]) / i
    }
  }
}

# REMOVE VARIABLES WITH REMAINING NAs -------------------------------------
# Check for any variables (excluding ID and outcome) with NAs
predictor_vars <- final_data %>% 
  select(-participant_id, -asrs_18_total)

na_counts <- colSums(is.na(predictor_vars))
vars_with_na <- names(na_counts[na_counts > 0])

if(length(vars_with_na) > 0) {
  cat("\n=== REMOVING PREDICTORS WITH MISSING DATA ===\n")
  cat("Variables being removed:\n")
  for(var in vars_with_na) {
    cat(sprintf("  - %s: %d NAs (%.1f%%)\n", 
                var, 
                na_counts[var], 
                100 * na_counts[var] / nrow(final_data)))
  }
  
  # Remove these variables
  final_data <- final_data %>% select(-all_of(vars_with_na))
  
  cat(sprintf("\nRemoved %d predictor(s) with NAs\n", length(vars_with_na)))
} else {
  cat("\nNo predictors with NAs - all good!\n")
}

# Export List of Variables with NA
if(length(vars_with_na) > 0) {
  write_csv(
    data.frame(
      variable = vars_with_na,
      n_missing = na_counts[vars_with_na],
      percent_missing = 100 * na_counts[vars_with_na] / nrow(final_data)
    ),
    "results/removed_variables.csv"
  )
  cat("Saved list of removed variables to results/removed_variables.csv\n")
}

# Prepare matrices for LASSO
X <- as.matrix(final_data %>% select(-participant_id, -asrs_18_total))
y <- final_data$asrs_18_total

cat("\n=== IMPUTATION COMPLETE ===\n")
cat("Final dataset dimensions:", dim(X), "\n")
cat("Any remaining NAs:", any(is.na(X)), "\n")



# SAVE MATRICES FOR LASSO WITH CROSS-VAL ----------------------------------

saveRDS(imputed_data, "results/imputed_mice_object.RDS")
saveRDS(final_data, "results/imputed_complete_data.RDS")
saveRDS(list(X = X, y = y), "results/lasso_ready_data.RDS")

cat("\n=== SUMMARY ===\n")
cat("1. Imputed", length(missing_vars), "continuous variables using PMM\n")
cat("2. Maximum missingness was", round(max(missing_percent), 1), "%\n")
cat("3. Used", m_imputations, "imputations\n")