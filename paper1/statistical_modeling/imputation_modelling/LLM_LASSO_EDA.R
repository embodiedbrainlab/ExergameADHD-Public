# ============================================================================
# LASSO REGRESSION FOR FEATURE SELECTION
# ============================================================================
# This script loads the imputed and averaged data, runs LASSO with 
# cross-validation to select important predictors, and saves results.
#
# INPUT:
#   - "results/lasso_ready_data.RDS" - Contains X (predictor matrix) and 
#     y (outcome vector) from convergeImputedData.R
#
# OUTPUT:
#   - "results/lasso_model.RDS" - Fitted cv.glmnet object
#   - "results/selected_features.RDS" - Vector of selected feature names
#   - "results/lasso_coefficients.csv" - Full coefficient table
#
# AUTHOR: Noor Tasnim
# DATE CREATED: October 16, 2025
# DATE MODIFIED: October 16, 2025

# LOAD LIBRARIES ----------------------------------------------------------
library(tidyverse)
library(glmnet)

# LOAD DATA ---------------------------------------------------------------
cat("Loading imputed data...\n")
lasso_data <- readRDS("results/lasso_ready_data.RDS")
final_data <- readRDS("results/imputed_complete_data.RDS")
og_data <- readRDS("results/exergameWideForModel.RDS")

# Extract X and y
X <- lasso_data$X
y <- lasso_data$y
class(X) # should ONLY BE MATRIX, the array is giving you NA warnings!

# REMOVE VARIABLES USED ONLY FOR IMPUTATION -------------------------------
# Remove asset_hyperactive and asset_inattentive - these helped with imputation
# but should not be included in LASSO modeling
vars_to_remove <- c("asset_hyperactive", "asset_inattentive")

# Check which variables are present before removing
vars_present <- vars_to_remove[vars_to_remove %in% colnames(X)]
if(length(vars_present) > 0) {
  cat("\nRemoving variables used only for imputation:\n")
  for(var in vars_present) {
    cat("  -", var, "\n")
  }
  X <- X[, !colnames(X) %in% vars_to_remove, drop = FALSE]
} else {
  cat("\nNote: Variables to remove not found in X matrix\n")
}

cat("Data loaded successfully!\n")
cat("Predictor matrix dimensions:", dim(X), "\n")
cat("Outcome vector length:", length(y), "\n")
cat("Any NAs in X:", any(is.na(X)), "\n")
cat("Any NAs in y:", any(is.na(y)), "\n\n")

# SAVE UPDATED LASSO-READY DATA -------------------------------------------
# Save the cleaned X and y matrices (without imputation-only variables)
saveRDS(list(X = X, y = y), "results/lasso_ready_data_final.RDS")

# ============================================================================
# RUN LASSO WITH CROSS-VALIDATION
# ============================================================================

cat("Running LASSO with 10-fold cross-validation...\n")
set.seed(123)

# Given small sample size, use repeated CV for stability
cv_lasso <- cv.glmnet(
  X, y,
  alpha = 1,        # 1 = LASSO
  nfolds = 10,
  type.measure = "mse"
)

cat("✓ Cross-validation complete!\n\n")

# ============================================================================
# EXTRACT SELECTED FEATURES
# ============================================================================

# Get selected features at lambda.min
best_lambda <- cv_lasso$lambda.min
lasso_coefs <- coef(cv_lasso, s = best_lambda)
selected_features <- rownames(lasso_coefs)[which(lasso_coefs != 0)][-1]  # Remove intercept

cat("=== LASSO RESULTS ===\n")
cat("Best lambda (lambda.min):", best_lambda, "\n")
cat("LASSO selected", length(selected_features), "features out of", ncol(X), "\n\n")

# ============================================================================
# DISPLAY TOP PREDICTORS
# ============================================================================

# Show top 10 predictors by coefficient magnitude
if(length(selected_features) > 0) {
  coef_df <- data.frame(
    variable = selected_features,
    coefficient = lasso_coefs[selected_features, 1]
  ) %>%
    arrange(desc(abs(coefficient))) %>%
    mutate(abs_coefficient = abs(coefficient))
  
  cat("Top 10 selected predictors by absolute coefficient:\n")
  print(head(coef_df %>% select(variable, coefficient, abs_coefficient), 10))
  
} else {
  warning("No features selected! Lambda may be too high.")
}

# ============================================================================
# CROSS-VALIDATION PERFORMANCE
# ============================================================================

cat("\n=== MODEL PERFORMANCE ===\n")
cat("MSE at lambda.min:", min(cv_lasso$cvm), "\n")
cat("MSE at lambda.1se:", cv_lasso$cvm[cv_lasso$lambda == cv_lasso$lambda.1se], "\n")

# R-squared calculation (on training data)
predictions <- predict(cv_lasso, newx = X, s = best_lambda)
ss_res <- sum((y - predictions)^2)
ss_tot <- sum((y - mean(y))^2)
r_squared <- 1 - (ss_res / ss_tot)
cat("Training R-squared:", round(r_squared, 3), "\n")

# ============================================================================
# VISUALIZE RESULTS
# ============================================================================

# Plot CV curve
pdf("results/lasso_cv_plot.pdf", width = 10, height = 6)
plot(cv_lasso)
title("LASSO Cross-Validation Curve", line = 2.5)
dev.off()
cat("\n✓ Saved CV plot to results/lasso_cv_plot.pdf\n")

# Plot coefficient paths
pdf("results/lasso_coefficient_paths.pdf", width = 12, height = 8)
plot(cv_lasso$glmnet.fit, xvar = "lambda", label = TRUE)
abline(v = log(best_lambda), col = "red", lty = 2)
title("LASSO Coefficient Paths", line = 2.5)
dev.off()
cat("✓ Saved coefficient paths to results/lasso_coefficient_paths.pdf\n")

# ============================================================================
# SAVE RESULTS
# ============================================================================

# Save the full model
saveRDS(cv_lasso, "results/lasso_model.RDS")
cat("\n✓ Saved LASSO model to results/lasso_model.RDS\n")

# Save selected features
saveRDS(selected_features, "results/selected_features.RDS")
cat("✓ Saved selected features to results/selected_features.RDS\n")

# Save all coefficients to CSV
all_coefs <- data.frame(
  variable = rownames(lasso_coefs),
  coefficient = as.vector(lasso_coefs),
  selected = rownames(lasso_coefs) %in% c("(Intercept)", selected_features)
) %>%
  arrange(desc(abs(coefficient)))

write_csv(all_coefs, "results/lasso_coefficients.csv")
cat("✓ Saved all coefficients to results/lasso_coefficients.csv\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n=== SUMMARY ===\n")
cat("1. Started with", ncol(X), "predictors\n")
cat("2. LASSO selected", length(selected_features), "important features\n")
cat("3. Reduction:", round((1 - length(selected_features)/ncol(X)) * 100, 1), "%\n")
cat("4. Training R²:", round(r_squared, 3), "\n")
cat("\nData is ready for final modeling!\n")