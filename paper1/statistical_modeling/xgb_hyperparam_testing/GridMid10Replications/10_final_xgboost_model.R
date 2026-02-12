#!/usr/bin/env Rscript

# ============================================================================
# FINAL XGBOOST MODEL WITH OPTIMAL HYPERPARAMETERS
# Complete evaluation with uncertainty quantification
# ============================================================================

library(tidyverse)
library(fastDummies)
library(xgboost)
library(caret)
library(SHAPforxgboost)
library(ggplot2)

cat("\n=== FINAL XGBOOST MODEL WITH OPTIMAL PARAMETERS ===\n")

# ============================================================================
# LOAD OPTIMAL PARAMETERS
# ============================================================================

# Check if hyperparameter tuning has been completed
if (!file.exists("results/recommended_xgboost_params.rds")) {
  stop("Please run hyperparameter tuning first (scripts 08 and 09)")
}

recommended_params <- readRDS("results/recommended_xgboost_params.rds")

# Select which parameter set to use
# Options: best_overall, most_stable, best_r2, robust_choice
# You can change this based on your preference
PARAM_CHOICE <- "robust_choice"  # Change this to select different parameter set

if (PARAM_CHOICE == "robust_choice" && is.null(recommended_params$robust_choice)) {
  cat("No robust choice available, using best_overall instead\n")
  PARAM_CHOICE <- "best_overall"
}

best_params <- recommended_params[[PARAM_CHOICE]]
cat(sprintf("\nUsing parameter set: %s\n", PARAM_CHOICE))
print(best_params)

# ============================================================================
# CONFIGURATION
# ============================================================================

set.seed(123)
N_BOOTSTRAP <- 100       # Number of bootstrap samples for confidence intervals
N_REPEATS <- 50         # Number of train-test splits
N_CV_FOLDS <- 5         # Cross-validation folds

# ============================================================================
# LOAD AND PREPARE DATA
# ============================================================================

exergame <- readRDS("results/exergame_forImputation.rds") %>%
  select(-asrs_6_total, -asrs_6_total_category) %>%
  dummy_cols(remove_first_dummy = TRUE,
             remove_selected_columns = TRUE) %>%
  relocate(sex_male:time_afternoon, .before = weight) %>%
  select(-participant_id)

# ============================================================================
# REPEATED EVALUATION WITH OPTIMAL PARAMETERS
# ============================================================================

cat("\n=== EVALUATING FINAL MODEL WITH REPEATED SPLITS ===\n")

# Storage
performance_results <- data.frame()
all_shap_values <- list()
all_predictions <- list()
feature_importance_list <- list()

pb <- txtProgressBar(min = 0, max = N_REPEATS, style = 3)

for (rep in 1:N_REPEATS) {
  
  setTxtProgressBar(pb, rep)
  
  # Create train-test split
  train_idx <- createDataPartition(exergame$asrs_18_total, p = 0.7, list = FALSE)
  train_data <- exergame[train_idx, ]
  test_data <- exergame[-train_idx, ]
  
  # Prepare data
  X_train_raw <- train_data %>% select(-asrs_18_total)
  y_train <- train_data$asrs_18_total
  X_test_raw <- test_data %>% select(-asrs_18_total)
  y_test <- test_data$asrs_18_total
  
  # Imputation
  preproc_model <- preProcess(X_train_raw, method = "bagImpute")
  X_train_imputed <- predict(preproc_model, X_train_raw)
  X_test_imputed <- predict(preproc_model, X_test_raw)
  
  X_train <- as.matrix(X_train_imputed)
  X_test <- as.matrix(X_test_imputed)
  
  # Cross-validation for this split
  cv_folds <- createFolds(y_train, k = N_CV_FOLDS, list = TRUE)
  cv_scores <- numeric(N_CV_FOLDS)
  fold_shap_values <- list()
  
  for (fold in 1:N_CV_FOLDS) {
    cv_train_idx <- setdiff(1:length(y_train), cv_folds[[fold]])
    cv_val_idx <- cv_folds[[fold]]
    
    X_cv_train <- X_train[cv_train_idx, ]
    y_cv_train <- y_train[cv_train_idx]
    X_cv_val <- X_train[cv_val_idx, ]
    y_cv_val <- y_train[cv_val_idx]
    
    # Train with optimal parameters
    cv_model <- xgboost(
      data = X_cv_train,
      label = y_cv_train,
      nrounds = best_params$nrounds,
      max_depth = best_params$max_depth,
      eta = best_params$eta,
      gamma = ifelse("gamma" %in% names(best_params), best_params$gamma, 0),
      colsample_bytree = best_params$colsample_bytree,
      min_child_weight = best_params$min_child_weight,
      subsample = best_params$subsample,
      lambda = best_params$lambda,
      alpha = best_params$alpha,
      objective = "reg:squarederror",
      verbose = 0
    )
    
    # Validation performance
    cv_pred <- predict(cv_model, X_cv_val)
    cv_scores[fold] <- sqrt(mean((y_cv_val - cv_pred)^2))
    
    # SHAP values
    if (rep <= 10) {  # Calculate SHAP for first 10 splits (computational efficiency)
      shap_vals <- shap.values(xgb_model = cv_model, X_train = X_cv_val)
      fold_shap_values[[fold]] <- shap_vals$shap_score
    }
  }
  
  if (rep <= 10) {
    all_shap_values[[rep]] <- do.call(rbind, fold_shap_values)
  }
  
  # Train final model on full training set
  final_model <- xgboost(
    data = X_train,
    label = y_train,
    nrounds = best_params$nrounds,
    max_depth = best_params$max_depth,
    eta = best_params$eta,
    gamma = ifelse("gamma" %in% names(best_params), best_params$gamma, 0),
    colsample_bytree = best_params$colsample_bytree,
    min_child_weight = best_params$min_child_weight,
    subsample = best_params$subsample,
    lambda = best_params$lambda,
    alpha = best_params$alpha,
    objective = "reg:squarederror",
    verbose = 0
  )
  
  # Test performance
  y_pred <- predict(final_model, X_test)
  
  # Calculate metrics
  test_rmse <- sqrt(mean((y_test - y_pred)^2))
  test_r2 <- 1 - sum((y_test - y_pred)^2) / sum((y_test - mean(y_train))^2)
  test_mae <- mean(abs(y_test - y_pred))
  test_mape <- mean(abs((y_test - y_pred) / y_test)) * 100
  
  # Store results
  performance_results <- rbind(performance_results, data.frame(
    repetition = rep,
    cv_rmse_mean = mean(cv_scores),
    cv_rmse_sd = sd(cv_scores),
    test_rmse = test_rmse,
    test_r2 = test_r2,
    test_mae = test_mae,
    test_mape = test_mape
  ))
  
  # Store predictions
  all_predictions[[rep]] <- data.frame(
    repetition = rep,
    actual = y_test,
    predicted = y_pred,
    residual = y_test - y_pred
  )
  
  # Feature importance
  importance <- xgb.importance(model = final_model)
  importance$repetition <- rep
  feature_importance_list[[rep]] <- importance
}

close(pb)

# ============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# ============================================================================

cat("\n\n=== CALCULATING BOOTSTRAP CONFIDENCE INTERVALS ===\n")

bootstrap_r2 <- numeric(N_BOOTSTRAP)
bootstrap_rmse <- numeric(N_BOOTSTRAP)

set.seed(456)
for (b in 1:N_BOOTSTRAP) {
  boot_sample <- sample(performance_results$test_r2, replace = TRUE)
  bootstrap_r2[b] <- mean(boot_sample)
  
  boot_sample_rmse <- sample(performance_results$test_rmse, replace = TRUE)
  bootstrap_rmse[b] <- mean(boot_sample_rmse)
}

# ============================================================================
# AGGREGATE RESULTS
# ============================================================================

# Performance summary
perf_summary <- performance_results %>%
  summarise(
    # R² statistics
    r2_mean = mean(test_r2),
    r2_median = median(test_r2),
    r2_sd = sd(test_r2),
    r2_q25 = quantile(test_r2, 0.25),
    r2_q75 = quantile(test_r2, 0.75),
    r2_ci_lower_boot = quantile(bootstrap_r2, 0.025),
    r2_ci_upper_boot = quantile(bootstrap_r2, 0.975),
    
    # RMSE statistics
    rmse_mean = mean(test_rmse),
    rmse_median = median(test_rmse),
    rmse_sd = sd(test_rmse),
    rmse_ci_lower_boot = quantile(bootstrap_rmse, 0.025),
    rmse_ci_upper_boot = quantile(bootstrap_rmse, 0.975),
    
    # MAE and MAPE
    mae_mean = mean(test_mae),
    mae_sd = sd(test_mae),
    mape_mean = mean(test_mape),
    mape_sd = sd(test_mape),
    
    # CV performance
    cv_rmse_mean_overall = mean(cv_rmse_mean),
    cv_rmse_sd_overall = mean(cv_rmse_sd)
  )

# Feature importance aggregation
combined_shap <- do.call(rbind, all_shap_values)
feature_importance_summary <- data.frame(
  feature = colnames(combined_shap),
  shap_mean = colMeans(abs(combined_shap)),
  shap_median = apply(abs(combined_shap), 2, median),
  shap_sd = apply(abs(combined_shap), 2, sd),
  shap_q25 = apply(abs(combined_shap), 2, quantile, probs = 0.25),
  shap_q75 = apply(abs(combined_shap), 2, quantile, probs = 0.75)
) %>%
  mutate(
    cv_coefficient = shap_sd / shap_mean,
    iqr = shap_q75 - shap_q25,
    stability_score = iqr / shap_median
  ) %>%
  arrange(desc(shap_median))

# ============================================================================
# PRINT RESULTS
# ============================================================================

cat("\n=== FINAL MODEL PERFORMANCE SUMMARY ===\n")
cat(sprintf("Based on %d train-test splits (70/30)\n\n", N_REPEATS))

cat("R² Performance:\n")
cat(sprintf("  Mean: %.4f (SD: %.4f)\n", perf_summary$r2_mean, perf_summary$r2_sd))
cat(sprintf("  Median: %.4f [IQR: %.4f - %.4f]\n", 
            perf_summary$r2_median, perf_summary$r2_q25, perf_summary$r2_q75))
cat(sprintf("  95%% Bootstrap CI: [%.4f, %.4f]\n", 
            perf_summary$r2_ci_lower_boot, perf_summary$r2_ci_upper_boot))

cat("\nRMSE Performance:\n")
cat(sprintf("  Mean: %.4f (SD: %.4f)\n", perf_summary$rmse_mean, perf_summary$rmse_sd))
cat(sprintf("  95%% Bootstrap CI: [%.4f, %.4f]\n", 
            perf_summary$rmse_ci_lower_boot, perf_summary$rmse_ci_upper_boot))

cat("\nAdditional Metrics:\n")
cat(sprintf("  MAE: %.4f (SD: %.4f)\n", perf_summary$mae_mean, perf_summary$mae_sd))
cat(sprintf("  MAPE: %.2f%% (SD: %.2f%%)\n", perf_summary$mape_mean, perf_summary$mape_sd))

cat("\n=== TOP 15 FEATURES BY MEDIAN |SHAP| ===\n")
print(head(feature_importance_summary %>% 
             select(feature, shap_median, shap_sd, cv_coefficient, stability_score), 15))

# ============================================================================
# VISUALIZATION
# ============================================================================

# 1. Performance Distribution
p1 <- ggplot(performance_results, aes(x = test_r2)) +
  geom_histogram(bins = 15, fill = "steelblue", alpha = 0.7, color = "black") +
  geom_vline(xintercept = perf_summary$r2_median, 
             color = "red", linetype = "dashed", size = 1) +
  geom_vline(xintercept = c(perf_summary$r2_ci_lower_boot, 
                            perf_summary$r2_ci_upper_boot),
             color = "red", linetype = "dotted", size = 0.8) +
  annotate("text", x = perf_summary$r2_median, y = Inf, vjust = 2,
           label = sprintf("Median R² = %.3f\n95%% CI: [%.3f, %.3f]", 
                          perf_summary$r2_median,
                          perf_summary$r2_ci_lower_boot,
                          perf_summary$r2_ci_upper_boot)) +
  labs(
    title = "Final Model Performance: Test R² Distribution",
    subtitle = sprintf("Based on %d train-test splits with optimal hyperparameters", N_REPEATS),
    x = "Test R²",
    y = "Frequency"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/final_model_r2_distribution.png", p1, width = 10, height = 6, dpi = 300)
print(p1)

# 2. Feature Importance with Uncertainty
p2 <- ggplot(feature_importance_summary[1:20,], 
             aes(x = reorder(feature, shap_median), y = shap_median)) +
  geom_bar(stat = "identity", fill = "steelblue", alpha = 0.8) +
  geom_errorbar(aes(ymin = shap_q25, ymax = shap_q75), 
                width = 0.2, color = "darkred") +
  coord_flip() +
  labs(
    title = "Top 20 Features: Median |SHAP| Values with IQR",
    subtitle = "Based on nested cross-validation across multiple splits",
    x = "Features",
    y = "Median |SHAP| Value"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/final_model_feature_importance.png", p2, width = 10, height = 8, dpi = 300)
print(p2)

# 3. Actual vs Predicted (aggregate all predictions)
all_preds_df <- do.call(rbind, all_predictions)

p3 <- ggplot(all_preds_df, aes(x = actual, y = predicted)) +
  geom_point(alpha = 0.3, color = "steelblue", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "darkgreen", 
              linetype = "solid", size = 0.8) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", 
              color = "red", size = 1) +
  annotate("text", x = min(all_preds_df$actual), y = max(all_preds_df$predicted),
           label = sprintf("Median R² = %.3f\nMedian RMSE = %.3f",
                          perf_summary$r2_median,
                          perf_summary$rmse_median),
           hjust = 0, vjust = 1, size = 4, fontface = "bold") +
  labs(
    title = "Actual vs Predicted Values: All Test Sets Combined",
    subtitle = sprintf("Aggregated predictions from %d test sets", N_REPEATS),
    x = "Actual ASRS-18 Total",
    y = "Predicted ASRS-18 Total"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/final_model_predictions.png", p3, width = 10, height = 8, dpi = 300)
print(p3)

# 4. Residual Analysis
p4 <- ggplot(all_preds_df, aes(x = predicted, y = residual)) +
  geom_point(alpha = 0.3, color = "coral", size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red", size = 1) +
  geom_smooth(method = "loess", se = TRUE, color = "darkblue", size = 0.8) +
  labs(
    title = "Residual Plot: Checking for Systematic Patterns",
    subtitle = "Loess smoothing to detect non-linearity",
    x = "Predicted Values",
    y = "Residuals (Actual - Predicted)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/final_model_residuals.png", p4, width = 10, height = 6, dpi = 300)
print(p4)

# ============================================================================
# SAVE FINAL RESULTS
# ============================================================================

# Save all results
save(
  best_params,
  performance_results,
  perf_summary,
  feature_importance_summary,
  all_predictions,
  all_shap_values,
  file = "results/final_xgboost_model_results.RData"
)

# Save summary tables
write.csv(perf_summary, "results/final_model_performance_summary.csv", row.names = FALSE)
write.csv(feature_importance_summary, "results/final_model_feature_importance.csv", row.names = FALSE)
write.csv(performance_results, "results/final_model_all_splits_performance.csv", row.names = FALSE)

# Save parameters used
write.csv(best_params, "results/final_model_parameters.csv", row.names = FALSE)

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Results saved to:\n")
cat("  - results/final_xgboost_model_results.RData\n")
cat("  - results/final_model_*.csv\n")
cat("  - Visualizations: results/final_model_*.png\n")

# ============================================================================
# FINAL RECOMMENDATIONS
# ============================================================================

cat("\n=== RECOMMENDATIONS ===\n")
cat("Given the small sample size (N=67) and high dimensionality (p=109):\n")
cat("1. The model shows ", ifelse(perf_summary$r2_median > 0.3, "reasonable", "limited"), 
    " predictive performance\n")
cat("2. Confidence intervals are wide, indicating uncertainty in predictions\n")
cat("3. Consider the top features for interpretation but note their stability scores\n")
cat("4. Use this model with caution for individual predictions\n")
cat("5. Consider collecting more data to improve model reliability\n")

if (perf_summary$r2_median < 0.2) {
  cat("\nWARNING: Low R² suggests limited predictive power.\n")
  cat("Consider simpler models or feature engineering.\n")
}
