#!/usr/bin/env Rscript

# ============================================================================
# XGBOOST HYPERPARAMETER TUNING - OVERFITTING-AWARE VERSION
# Robust approach for small sample (67 observations, 109 predictors)
# NOW MONITORS TRAIN-TEST GAP TO DETECT OVERFITTING
# ============================================================================

# Load Libraries
library(tidyverse)
library(fastDummies)
library(xgboost)
library(caret)
library(doParallel)
library(foreach)

cat("\n=================================================================\n")
cat("XGBoost Hyperparameter Tuning - Parallel Processing\n")
cat("WITH OVERFITTING MONITORING\n")
cat("=================================================================\n")

# ============================================================================
# PARALLEL SETUP
# ============================================================================

# Detect available cores (use all available on HPC, leave 1 free on local)
n_cores <- 96

cat(sprintf("\nUsing %d cores for parallel processing\n", n_cores))

# Set up parallel backend
cl <- makeCluster(n_cores)
registerDoParallel(cl)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Set global seed for reproducibility
set.seed(123)

# Number of repetitions for stability
N_TRAIN_TEST_SPLITS <- 20  # Splits per parameter set
N_OUTER_CV_FOLDS <- 5      # Outer CV for evaluation

# ============================================================================
# HYPERPARAMETER GRID - OPTIMIZED TO COMBAT OVERFITTING
# ============================================================================

cat("\n=== SETTING UP PARAMETER GRID ===\n")

# CRITICAL CHANGES FOR OVERFITTING PREVENTION:
# 1. Lower nrounds (10-50 instead of 50-100)
# 2. Stronger regularization (higher lambda, alpha, gamma, min_child_weight)
# 3. Shallower trees (max_depth 2-3 instead of 3-4)
# 4. More aggressive subsampling

param_grid <- expand.grid(
  nrounds = c(10, 20, 30, 40, 50),           # MUCH LOWER - combat overfitting
  max_depth = c(2, 3),                       # Shallower trees
  eta = c(0.05, 0.1),                        # Learning rate
  gamma = c(1, 2, 5),                        # HIGHER - more pruning (removed 0)
  colsample_bytree = c(0.5, 0.6, 0.8),       # Less features per tree
  min_child_weight = c(5, 10, 15),           # HIGHER - larger leaves (removed 3)
  subsample = c(0.6, 0.7, 0.85),             # Less data per tree
  lambda = c(2, 5, 10, 20),                  # HIGHER L2 regularization
  alpha = c(0.5, 1, 2, 5)                    # HIGHER L1 regularization (removed 0)
)

total_params <- nrow(param_grid)
cat(sprintf("Total parameter combinations to test: %d\n", total_params))
cat(sprintf("Total models to train: %d\n", 
            total_params * N_TRAIN_TEST_SPLITS * N_OUTER_CV_FOLDS))

# Add unique ID to each parameter set
param_grid$param_id <- 1:nrow(param_grid)

# ============================================================================
# LOAD AND PREPARE DATA
# ============================================================================

cat("\n=== LOADING DATA ===\n")

# Load Data
exergame <- readRDS("exergame_forImputation.rds") %>%
  select(-asrs_6_total, -asrs_6_total_category) %>%
  dummy_cols(remove_first_dummy = TRUE,
             remove_selected_columns = TRUE) %>%
  relocate(sex_male:time_afternoon, .before = weight) %>%
  select(-participant_id)

cat(sprintf("Data dimensions: %d observations, %d features\n", 
            nrow(exergame), ncol(exergame) - 1))

# ============================================================================
# DEFINE EVALUATION FUNCTION - NOW WITH OVERFITTING MONITORING
# ============================================================================

evaluate_params <- function(params_row, exergame_data, n_splits = 10, n_folds = 5) {
  
  # Extract parameters
  current_params <- params_row
  
  # Set seed for this parameter set (ensures reproducibility)
  set.seed(123 + params_row$param_id)
  
  # Storage for this parameter set
  param_results <- data.frame()
  
  for (split in 1:n_splits) {
    
    # Create train-test split
    train_idx <- createDataPartition(exergame_data$asrs_18_total, 
                                    p = 0.7, list = FALSE)
    train_data <- exergame_data[train_idx, ]
    test_data <- exergame_data[-train_idx, ]
    
    # Prepare features and target
    X_train_raw <- train_data %>% select(-asrs_18_total)
    y_train <- train_data$asrs_18_total
    X_test_raw <- test_data %>% select(-asrs_18_total)
    y_test <- test_data$asrs_18_total
    
    # Imputation (fit on train, apply to test)
    preproc_model <- preProcess(X_train_raw, method = "bagImpute")
    X_train_imputed <- predict(preproc_model, X_train_raw)
    X_test_imputed <- predict(preproc_model, X_test_raw)
    
    X_train <- as.matrix(X_train_imputed)
    X_test <- as.matrix(X_test_imputed)
    
    # NESTED CROSS-VALIDATION
    outer_folds <- createFolds(y_train, k = n_folds, list = TRUE)
    cv_scores <- numeric(n_folds)
    
    for (fold_idx in 1:n_folds) {
      
      # Outer CV split
      outer_train_idx <- setdiff(1:length(y_train), outer_folds[[fold_idx]])
      outer_val_idx <- outer_folds[[fold_idx]]
      
      X_outer_train <- X_train[outer_train_idx, ]
      y_outer_train <- y_train[outer_train_idx]
      X_outer_val <- X_train[outer_val_idx, ]
      y_outer_val <- y_train[outer_val_idx]
      
      # Train model with current hyperparameters
      xgb_model <- xgboost(
        data = X_outer_train,
        label = y_outer_train,
        nrounds = current_params$nrounds,
        max_depth = current_params$max_depth,
        eta = current_params$eta,
        gamma = current_params$gamma,
        colsample_bytree = current_params$colsample_bytree,
        min_child_weight = current_params$min_child_weight,
        subsample = current_params$subsample,
        lambda = current_params$lambda,
        alpha = current_params$alpha,
        objective = "reg:squarederror",
        verbose = 0,
        nthread = 1  # Single thread per model
      )
      
      # Validate on outer fold
      pred_val <- predict(xgb_model, X_outer_val)
      cv_scores[fold_idx] <- sqrt(mean((y_outer_val - pred_val)^2))
    }
    
    # Average CV score for this split
    cv_rmse_mean <- mean(cv_scores)
    cv_rmse_sd <- sd(cv_scores)
    
    # Train final model on full training set
    xgb_final <- xgboost(
      data = X_train,
      label = y_train,
      nrounds = current_params$nrounds,
      max_depth = current_params$max_depth,
      eta = current_params$eta,
      gamma = current_params$gamma,
      colsample_bytree = current_params$colsample_bytree,
      min_child_weight = current_params$min_child_weight,
      subsample = current_params$subsample,
      lambda = current_params$lambda,
      alpha = current_params$alpha,
      objective = "reg:squarederror",
      verbose = 0,
      nthread = 1
    )
    
    # ========================================================================
    # CRITICAL: CALCULATE BOTH TRAIN AND TEST PERFORMANCE
    # ========================================================================
    
    # Training set performance
    y_pred_train <- predict(xgb_final, X_train)
    train_rmse <- sqrt(mean((y_train - y_pred_train)^2))
    train_r2 <- 1 - sum((y_train - y_pred_train)^2) / sum((y_train - mean(y_train))^2)
    train_mae <- mean(abs(y_train - y_pred_train))
    
    # Test set performance
    y_pred_test <- predict(xgb_final, X_test)
    test_rmse <- sqrt(mean((y_test - y_pred_test)^2))
    test_r2 <- 1 - sum((y_test - y_pred_test)^2) / sum((y_test - mean(y_train))^2)
    test_mae <- mean(abs(y_test - y_pred_test))
    
    # OVERFITTING METRICS
    r2_gap <- train_r2 - test_r2
    rmse_gap <- test_rmse - train_rmse
    
    # Store results
    param_results <- rbind(param_results, data.frame(
      split = split,
      cv_rmse_mean = cv_rmse_mean,
      cv_rmse_sd = cv_rmse_sd,
      train_rmse = train_rmse,
      train_r2 = train_r2,
      train_mae = train_mae,
      test_rmse = test_rmse,
      test_r2 = test_r2,
      test_mae = test_mae,
      r2_gap = r2_gap,
      rmse_gap = rmse_gap
    ))
  }
  
  # Aggregate results across all splits for this parameter set
  summary_row <- data.frame(
    param_id = current_params$param_id,
    nrounds = current_params$nrounds,
    max_depth = current_params$max_depth,
    eta = current_params$eta,
    gamma = current_params$gamma,
    colsample_bytree = current_params$colsample_bytree,
    min_child_weight = current_params$min_child_weight,
    subsample = current_params$subsample,
    lambda = current_params$lambda,
    alpha = current_params$alpha,
    
    # CV metrics
    cv_rmse_mean = mean(param_results$cv_rmse_mean),
    cv_rmse_sd = mean(param_results$cv_rmse_sd),
    cv_stability = sd(param_results$cv_rmse_mean),
    
    # Training set metrics
    train_r2_mean = mean(param_results$train_r2),
    train_r2_median = median(param_results$train_r2),
    train_r2_sd = sd(param_results$train_r2),
    train_rmse_mean = mean(param_results$train_rmse),
    train_rmse_median = median(param_results$train_rmse),
    
    # Test set metrics
    test_r2_mean = mean(param_results$test_r2),
    test_r2_median = median(param_results$test_r2),
    test_r2_sd = sd(param_results$test_r2),
    test_r2_q25 = quantile(param_results$test_r2, 0.25),
    test_r2_q75 = quantile(param_results$test_r2, 0.75),
    test_rmse_mean = mean(param_results$test_rmse),
    test_rmse_median = median(param_results$test_rmse),
    test_rmse_sd = sd(param_results$test_rmse),
    test_stability = sd(param_results$test_rmse),
    r2_stability = sd(param_results$test_r2),
    
    # OVERFITTING METRICS - CRITICAL!
    r2_gap_mean = mean(param_results$r2_gap),
    r2_gap_median = median(param_results$r2_gap),
    r2_gap_sd = sd(param_results$r2_gap),
    rmse_gap_mean = mean(param_results$rmse_gap),
    rmse_gap_median = median(param_results$rmse_gap)
  )
  
  return(summary_row)
}

# ============================================================================
# PARALLEL HYPERPARAMETER SEARCH
# ============================================================================

cat("\n=== STARTING PARALLEL HYPERPARAMETER SEARCH ===\n")
cat(sprintf("Using %d cores to evaluate %d parameter sets\n", n_cores, total_params))
cat("This may take 30-60 minutes depending on your system...\n\n")

# Start timing
start_time <- Sys.time()

# Export necessary objects to parallel workers
clusterExport(cl, c("exergame", "N_TRAIN_TEST_SPLITS", "N_OUTER_CV_FOLDS", 
                    "evaluate_params"))

# Export required libraries to workers
clusterEvalQ(cl, {
  library(tidyverse)
  library(xgboost)
  library(caret)
})

# Run parallel evaluation with progress reporting
# Split into chunks for progress updates
chunk_size <- max(1, floor(total_params / 20))  # 20 progress updates
n_chunks <- ceiling(total_params / chunk_size)

all_results <- list()

for (chunk in 1:n_chunks) {
  start_idx <- (chunk - 1) * chunk_size + 1
  end_idx <- min(chunk * chunk_size, total_params)
  
  cat(sprintf("Processing parameters %d-%d of %d (%.1f%%)...\n", 
              start_idx, end_idx, total_params, 
              100 * end_idx / total_params))
  
  # Process chunk in parallel
  chunk_results <- foreach(
    i = start_idx:end_idx,
    .packages = c('tidyverse', 'xgboost', 'caret'),
    .combine = rbind,
    .errorhandling = 'remove'
  ) %dopar% {
    evaluate_params(param_grid[i, ], exergame, N_TRAIN_TEST_SPLITS, N_OUTER_CV_FOLDS)
  }
  
  all_results[[chunk]] <- chunk_results
}

# Combine all chunks
results_df <- do.call(rbind, all_results)

# End timing
end_time <- Sys.time()
runtime <- difftime(end_time, start_time, units = "mins")
cat(sprintf("\n\nTotal runtime: %.1f minutes\n", as.numeric(runtime)))

# ============================================================================
# CALCULATE COMPOSITE SCORES - NOW INCLUDING OVERFITTING PENALTY
# ============================================================================

cat("\n=== CALCULATING COMPOSITE SCORES ===\n")

# Normalize metrics for fair comparison
results_df <- results_df %>%
  mutate(
    # Performance score (higher test R² is better)
    performance_score = scale(test_r2_median)[,1] - scale(test_rmse_median)[,1],
    
    # Stability score (lower variability is better)
    stability_score = -scale(cv_stability)[,1] - scale(test_stability)[,1] - scale(r2_stability)[,1],
    
    # Robustness score (narrower IQR is better)
    robustness_score = -scale(test_r2_q75 - test_r2_q25)[,1],
    
    # OVERFITTING PENALTY (lower gap is better)
    overfitting_penalty = -scale(r2_gap_median)[,1],
    
    # Combined score with weights - NOW INCLUDES OVERFITTING
    combined_score = 0.35 * performance_score + 
                     0.25 * stability_score + 
                     0.15 * robustness_score +
                     0.25 * overfitting_penalty  # NEW: Penalize overfitting
  ) %>%
  arrange(desc(combined_score))

# ============================================================================
# IDENTIFY BEST PARAMETERS
# ============================================================================

# Top performers by different criteria
top_combined <- head(results_df, 20)
top_r2 <- results_df %>% arrange(desc(test_r2_median)) %>% head(20)
top_stable <- results_df %>% arrange(test_r2_sd) %>% head(20)
top_no_overfit <- results_df %>% arrange(r2_gap_median) %>% head(20)  # NEW

# Find robust parameters (appear in multiple top lists)
robust_params <- results_df %>%
  mutate(
    in_top_combined = param_id %in% top_combined$param_id,
    in_top_r2 = param_id %in% top_r2$param_id,
    in_top_stable = param_id %in% top_stable$param_id,
    in_top_no_overfit = param_id %in% top_no_overfit$param_id,
    top_list_count = in_top_combined + in_top_r2 + in_top_stable + in_top_no_overfit
  ) %>%
  filter(top_list_count >= 2) %>%
  arrange(desc(combined_score))

# ============================================================================
# SAVE RESULTS
# ============================================================================

cat("\n=== SAVING RESULTS ===\n")

# Save all results
write.csv(results_df, "results/all_hyperparameter_results.csv", row.names = FALSE)

# Save top performers
write.csv(top_combined, "results/top20_combined_score.csv", row.names = FALSE)
write.csv(top_r2, "results/top20_by_r2.csv", row.names = FALSE)
write.csv(top_stable, "results/top20_most_stable.csv", row.names = FALSE)
write.csv(top_no_overfit, "results/top20_least_overfitting.csv", row.names = FALSE)
write.csv(robust_params, "results/robust_parameter_sets.csv", row.names = FALSE)

# Save best parameters for easy loading
best_params <- results_df[1, c("nrounds", "max_depth", "eta", "gamma", 
                               "colsample_bytree", "min_child_weight", 
                               "subsample", "lambda", "alpha")]

recommended_params <- list(
  best_overall = best_params,
  most_stable = top_stable[1, c("nrounds", "max_depth", "eta", "gamma", 
                                "colsample_bytree", "min_child_weight", 
                                "subsample", "lambda", "alpha")],
  best_r2 = top_r2[1, c("nrounds", "max_depth", "eta", "gamma", 
                       "colsample_bytree", "min_child_weight", 
                       "subsample", "lambda", "alpha")],
  least_overfitting = top_no_overfit[1, c("nrounds", "max_depth", "eta", "gamma",
                                          "colsample_bytree", "min_child_weight",
                                          "subsample", "lambda", "alpha")],
  robust_choice = if(nrow(robust_params) > 0) {
    robust_params[1, c("nrounds", "max_depth", "eta", "gamma", 
                      "colsample_bytree", "min_child_weight", 
                      "subsample", "lambda", "alpha")]
  } else NULL
)

saveRDS(recommended_params, "results/recommended_xgboost_params.rds")

# ============================================================================
# PRINT SUMMARY WITH OVERFITTING METRICS
# ============================================================================

cat("\n=== TOP 5 PARAMETER SETS (BY COMBINED SCORE) ===\n")
print(head(results_df %>% 
             select(param_id, test_r2_median, train_r2_median, r2_gap_median,
                    test_stability, combined_score), 5))

cat("\n=== BEST OVERALL PARAMETERS ===\n")
print(best_params)

cat("\nPerformance of best parameter set:\n")
best_perf <- results_df[1, ]
cat(sprintf("  Median Train R²: %.4f (SD: %.4f)\n", 
            best_perf$train_r2_median, best_perf$train_r2_sd))
cat(sprintf("  Median Test R²: %.4f (SD: %.4f)\n", 
            best_perf$test_r2_median, best_perf$test_r2_sd))
cat(sprintf("  R² Gap (Train-Test): %.4f (SD: %.4f)\n",
            best_perf$r2_gap_median, best_perf$r2_gap_sd))
cat(sprintf("  Stability Score: %.4f\n", best_perf$test_stability))

# OVERFITTING ASSESSMENT
cat("\n=== OVERFITTING ASSESSMENT ===\n")
if (best_perf$r2_gap_median < 0.10) {
  cat("✓ EXCELLENT: Minimal overfitting detected\n")
} else if (best_perf$r2_gap_median < 0.20) {
  cat("⚠ ACCEPTABLE: Moderate overfitting\n")
} else if (best_perf$r2_gap_median < 0.30) {
  cat("⚠ CONCERNING: Substantial overfitting\n")
} else {
  cat("✗ SEVERE: Critical overfitting - results may not be reliable\n")
}

if (nrow(robust_params) > 0) {
  cat(sprintf("\n%d parameter sets appear in multiple top-20 lists (robust choices)\n", 
              nrow(robust_params)))
}

# ============================================================================
# VISUALIZATIONS
# ============================================================================

cat("\n=== CREATING VISUALIZATIONS ===\n")

# Plot 1: Performance vs Stability
p1 <- ggplot(results_df, aes(x = test_r2_median, y = test_r2_sd)) +
  geom_point(aes(color = combined_score), alpha = 0.6, size = 2) +
  geom_point(data = head(results_df, 10), color = "red", size = 4, shape = 17) +
  scale_color_gradient2(low = "blue", mid = "gray", high = "green", 
                        midpoint = median(results_df$combined_score)) +
  labs(
    title = "XGBoost Hyperparameter Tuning: Performance vs Stability",
    subtitle = sprintf("Red triangles = Top 10 | Total combinations tested: %d", nrow(results_df)),
    x = "Median Test R² (Higher is better)",
    y = "Test R² Standard Deviation (Lower is better)",
    color = "Combined\nScore"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/hyperparameter_performance_stability.png", p1, 
       width = 10, height = 7, dpi = 300)

# Plot 2: Overfitting Assessment (NEW!)
p2 <- ggplot(results_df, aes(x = test_r2_median, y = r2_gap_median)) +
  geom_point(aes(color = combined_score, size = train_r2_median), alpha = 0.6) +
  geom_point(data = head(results_df, 10), color = "red", size = 4, shape = 17) +
  geom_hline(yintercept = c(0.1, 0.2), linetype = "dashed", color = "orange") +
  scale_color_gradient2(low = "blue", mid = "gray", high = "green",
                        midpoint = median(results_df$combined_score)) +
  labs(
    title = "Overfitting Assessment: Test R² vs Train-Test Gap",
    subtitle = "Lower gap = better generalization | Dashed lines at 0.1 and 0.2",
    x = "Median Test R²",
    y = "R² Gap (Train - Test)",
    color = "Combined\nScore",
    size = "Train R²"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/overfitting_assessment.png", p2,
       width = 10, height = 7, dpi = 300)

# Plot 3: Train vs Test R² (NEW!)
p3 <- ggplot(results_df, aes(x = train_r2_median, y = test_r2_median)) +
  geom_point(aes(color = r2_gap_median), alpha = 0.6, size = 3) +
  geom_point(data = head(results_df, 10), color = "red", size = 4, shape = 17) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "black") +
  scale_color_gradient(low = "green", high = "red", name = "R² Gap") +
  labs(
    title = "Train vs Test R²: Overfitting Detection",
    subtitle = "Points near diagonal = good generalization | Red triangles = Top 10",
    x = "Median Train R²",
    y = "Median Test R²"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave("results/train_vs_test_r2.png", p3,
       width = 10, height = 7, dpi = 300)

cat("  Saved: hyperparameter_performance_stability.png\n")
cat("  Saved: overfitting_assessment.png\n")
cat("  Saved: train_vs_test_r2.png\n")

# Clean up
stopCluster(cl)

# ============================================================================
# FINAL MESSAGE
# ============================================================================

cat("\n=================================================================\n")
cat("HYPERPARAMETER TUNING COMPLETE!\n")
cat("=================================================================\n")
cat("\nKey outputs saved:\n")
cat("  - results/all_hyperparameter_results.csv (all results)\n")
cat("  - results/top20_*.csv (best parameters by different metrics)\n")
cat("  - results/top20_least_overfitting.csv (NEW - lowest train-test gap)\n")
cat("  - results/recommended_xgboost_params.rds (for use in final model)\n")
cat("  - results/hyperparameter_performance_stability.png\n")
cat("  - results/overfitting_assessment.png (NEW)\n")
cat("  - results/train_vs_test_r2.png (NEW)\n")
cat("\nNext steps:\n")
cat("  1. Review overfitting metrics in results files\n")
cat("  2. Check train_vs_test_r2.png to visualize overfitting\n")
cat("  3. Use parameters from 'least_overfitting' or 'robust_choice'\n")
cat("  4. Run final model script with selected parameters\n")
cat("\n")
