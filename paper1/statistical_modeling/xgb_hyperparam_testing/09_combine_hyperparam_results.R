#!/usr/bin/env Rscript

# ============================================================================
# ANALYZE HYPERPARAMETER TUNING RESULTS
# ============================================================================

library(tidyverse)
library(ggplot2)
library(plotly)
library(corrplot)

cat("\n=== ANALYZING HYPERPARAMETER TUNING RESULTS ===\n")

# ============================================================================
# LOAD RESULTS
# ============================================================================

# Check if results file exists
if (!file.exists("results/all_hyperparameter_results.csv")) {
  stop("Results file not found. Please run 08_xgboost_hyperparam_tuning_HPC.R first.")
}

# Load results
all_results <- read.csv("results/all_hyperparameter_results.csv")

cat(sprintf("Loaded results for %d parameter combinations\n", nrow(all_results)))

# ============================================================================
# ADDITIONAL ANALYSIS AND VISUALIZATION
# ============================================================================

# 1. Parameter Importance Heatmap
param_cols <- c("nrounds", "max_depth", "eta", "gamma", "colsample_bytree", 
                "min_child_weight", "subsample", "lambda", "alpha")

# Calculate correlation with performance metrics
param_performance_cor <- cor(
  all_results[, param_cols],
  all_results[, c("test_r2_median", "test_r2_sd", "combined_score")]
)

# Plot correlation heatmap
png("results/parameter_performance_correlation.png", width = 10, height = 8, 
    units = "in", res = 300)
corrplot(param_performance_cor, method = "color", type = "full",
         order = "hclust", addCoef.col = "black", number.cex = 0.7,
         tl.cex = 0.8, tl.col = "black", 
         title = "Hyperparameter Correlation with Performance Metrics",
         mar = c(0,0,2,0))
dev.off()

cat("  Created: parameter_performance_correlation.png\n")

# 2. Distribution of performance metrics
p2 <- all_results %>%
  select(test_r2_median, test_rmse_median, test_stability) %>%
  pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
  ggplot(aes(x = value, fill = metric)) +
  geom_histogram(bins = 30, alpha = 0.7) +
  facet_wrap(~metric, scales = "free") +
  labs(
    title = "Distribution of Performance Metrics Across All Hyperparameter Sets",
    subtitle = sprintf("Total combinations tested: %d", nrow(all_results))
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("results/metric_distributions.png", p2, width = 12, height = 5, dpi = 300)
cat("  Created: metric_distributions.png\n")

# 3. Create interactive 3D plot for exploration
if (requireNamespace("plotly", quietly = TRUE)) {
  p3d <- plot_ly(
    data = all_results,
    x = ~test_r2_median,
    y = ~test_r2_sd,
    z = ~test_rmse_median,
    color = ~combined_score,
    text = ~paste("nrounds:", nrounds, "<br>",
                  "max_depth:", max_depth, "<br>",
                  "eta:", eta, "<br>",
                  "lambda:", lambda, "<br>",
                  "alpha:", alpha),
    type = "scatter3d",
    mode = "markers",
    marker = list(size = 5)
  ) %>%
    layout(
      title = "3D: Performance Space Exploration",
      scene = list(
        xaxis = list(title = "Median R²"),
        yaxis = list(title = "R² SD"),
        zaxis = list(title = "Median RMSE")
      )
    )
  
  htmlwidgets::saveWidget(p3d, "results/hyperparameter_3d_exploration.html")
  cat("  Created: hyperparameter_3d_exploration.html (interactive)\n")
}

# ============================================================================
# PARAMETER SENSITIVITY ANALYSIS
# ============================================================================

cat("\n=== PARAMETER SENSITIVITY ANALYSIS ===\n")

# Calculate average performance for each parameter value
sensitivity_analysis <- list()

for (param in param_cols) {
  param_summary <- all_results %>%
    group_by(!!sym(param)) %>%
    summarise(
      mean_r2 = mean(test_r2_median),
      sd_r2 = sd(test_r2_median),
      mean_stability = mean(test_stability),
      n = n(),
      .groups = 'drop'
    ) %>%
    mutate(parameter = param)
  
  sensitivity_analysis[[param]] <- param_summary
}

# Find most influential parameters
param_influence <- map_df(sensitivity_analysis, function(df) {
  data.frame(
    parameter = df$parameter[1],
    r2_range = max(df$mean_r2) - min(df$mean_r2),
    stability_range = max(df$mean_stability) - min(df$mean_stability)
  )
}) %>%
  arrange(desc(r2_range))

cat("\nParameter Influence on R² (range of mean values):\n")
print(param_influence)

# Plot parameter sensitivity
sensitivity_plots <- list()
for (i in 1:min(6, length(param_cols))) {
  param <- param_influence$parameter[i]
  
  p <- sensitivity_analysis[[param]] %>%
    ggplot(aes(x = as.factor(get(param)), y = mean_r2)) +
    geom_boxplot(data = all_results, 
                 aes(x = as.factor(get(param)), y = test_r2_median),
                 fill = "lightblue", alpha = 0.6) +
    geom_point(size = 3, color = "red") +
    geom_errorbar(aes(ymin = mean_r2 - sd_r2, ymax = mean_r2 + sd_r2), 
                  width = 0.2, color = "red") +
    labs(
      title = paste("Sensitivity:", param),
      x = param,
      y = "Test R² (median)"
    ) +
    theme_minimal()
  
  sensitivity_plots[[i]] <- p
}

# Combine sensitivity plots
library(gridExtra)
combined_sensitivity <- do.call(grid.arrange, c(sensitivity_plots, ncol = 3))
ggsave("results/parameter_sensitivity.png", combined_sensitivity, 
       width = 15, height = 10, dpi = 300)
cat("  Created: parameter_sensitivity.png\n")

# ============================================================================
# BEST PARAMETERS BY DIFFERENT CRITERIA
# ============================================================================

cat("\n=== BEST PARAMETERS BY DIFFERENT CRITERIA ===\n")

# Load the recommended parameters
recommended_params <- readRDS("results/recommended_xgboost_params.rds")

cat("\n1. BEST OVERALL (Combined Score):\n")
print(recommended_params$best_overall)

cat("\n2. MOST STABLE (Lowest Variance):\n")
print(recommended_params$most_stable)

cat("\n3. BEST R² (Highest Median):\n")
print(recommended_params$best_r2)

if (!is.null(recommended_params$robust_choice)) {
  cat("\n4. ROBUST CHOICE (Appears in Multiple Top Lists):\n")
  print(recommended_params$robust_choice)
}

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

cat("\n=== RECOMMENDATIONS FOR SMALL SAMPLE (N=67) ===\n")

# Analyze best performers for patterns
best_10 <- head(all_results, 10)

cat("\nCommon characteristics of top 10 parameter sets:\n")
cat(sprintf("  Max depth: %.1f ± %.1f (prefer shallow trees)\n", 
            mean(best_10$max_depth), sd(best_10$max_depth)))
cat(sprintf("  Min child weight: %.1f ± %.1f (higher values for small data)\n", 
            mean(best_10$min_child_weight), sd(best_10$min_child_weight)))
cat(sprintf("  Lambda (L2): %.2f ± %.2f (regularization crucial)\n", 
            mean(best_10$lambda), sd(best_10$lambda)))
cat(sprintf("  Subsample: %.2f ± %.2f\n", 
            mean(best_10$subsample), sd(best_10$subsample)))
cat(sprintf("  Learning rate (eta): %.3f ± %.3f\n", 
            mean(best_10$eta), sd(best_10$eta)))
cat(sprintf("  Number of rounds: %.0f ± %.0f\n", 
            mean(best_10$nrounds), sd(best_10$nrounds)))

# Performance range
cat("\nPerformance range of top 10 parameter sets:\n")
cat(sprintf("  R² range: [%.4f, %.4f]\n", 
            min(best_10$test_r2_median), max(best_10$test_r2_median)))
cat(sprintf("  RMSE range: [%.4f, %.4f]\n", 
            min(best_10$test_rmse_median), max(best_10$test_rmse_median)))

# ============================================================================
# CREATE FINAL COMPARISON PLOT
# ============================================================================

# Compare top parameter sets
top_20 <- head(all_results, 20)
top_20$rank <- 1:20

p_comparison <- ggplot(top_20, aes(x = rank)) +
  geom_line(aes(y = test_r2_median, color = "R² (median)"), size = 1.2) +
  geom_point(aes(y = test_r2_median), color = "blue", size = 3) +
  geom_ribbon(aes(ymin = test_r2_q25, ymax = test_r2_q75), 
              alpha = 0.2, fill = "blue") +
  geom_line(aes(y = test_r2_sd * 5, color = "R² SD (×5)"), size = 1.2, linetype = "dashed") +
  geom_point(aes(y = test_r2_sd * 5), color = "red", size = 3) +
  scale_color_manual(values = c("R² (median)" = "blue", "R² SD (×5)" = "red")) +
  labs(
    title = "Top 20 Parameter Sets: Performance vs Stability Trade-off",
    subtitle = "Blue ribbon shows IQR of R²",
    x = "Rank (by combined score)",
    y = "Value",
    color = "Metric"
  ) +
  theme_minimal() +
  theme(legend.position = "top")

ggsave("results/top20_comparison.png", p_comparison, width = 12, height = 7, dpi = 300)
cat("\n  Created: top20_comparison.png\n")

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

cat("\n=== OVERALL STATISTICS ===\n")
cat(sprintf("Total parameter combinations tested: %d\n", nrow(all_results)))
cat(sprintf("Best R² achieved (median): %.4f\n", max(all_results$test_r2_median)))
cat(sprintf("Most stable R² SD: %.4f\n", min(all_results$test_r2_sd)))
cat(sprintf("Best RMSE achieved (median): %.4f\n", min(all_results$test_rmse_median)))

# Count parameter sets meeting different thresholds
good_r2 <- sum(all_results$test_r2_median > 0.3)
stable <- sum(all_results$test_r2_sd < median(all_results$test_r2_sd))
good_and_stable <- sum(all_results$test_r2_median > 0.3 & 
                       all_results$test_r2_sd < median(all_results$test_r2_sd))

cat(sprintf("\nParameter sets with R² > 0.3: %d (%.1f%%)\n", 
            good_r2, 100 * good_r2 / nrow(all_results)))
cat(sprintf("Parameter sets with below-median variance: %d (%.1f%%)\n", 
            stable, 100 * stable / nrow(all_results)))
cat(sprintf("Parameter sets with both: %d (%.1f%%)\n", 
            good_and_stable, 100 * good_and_stable / nrow(all_results)))

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Visualizations saved in results/\n")
cat("Ready to run 10_final_xgboost_model.R with optimal parameters\n")
