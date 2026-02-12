# Combined Median Imputation and LASSO Pipeline with Multiple Splits
# ENHANCED VERSION: Collects coefficients and creates forest plot
# This script runs multiple train/test splits, performs unique imputation for each,
# runs LASSO regression, and generates a comprehensive performance report
# PLUS: Collects all coefficient values and creates publication-quality visualization

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(caret)
library(fastDummies)
library(glmnet)
library(Metrics)

# Set Parameters ----------------------------------------------------------
n_splits <- 50  # Number of train/test splits to test
train_proportion <- 0.7  # Proportion of data for training
set_cutoff <- 0.9 # threshold for correlations in data
set_alpha <- 1 # LASSO regression/Ridge/Enet
set.seed(123)  # For reproducibility

# Load and Prepare Data ---------------------------------------------------
exergame <- readRDS("results/exergame_forFinalModel.rds") %>%
  select(-asrs_6_total, -asrs_6_total_category) %>%
  dummy_cols(
    remove_first_dummy = TRUE,
    remove_selected_columns = TRUE
  ) %>%
  relocate(sex_male:time_afternoon, .before = stimulant) %>%
  select(-participant_id)


# Report Non-Zero Variance ------------------------------------------------
# We've checked and there is none, but we'll at least report a .csv to show
# that we've checked
nzv <- nearZeroVar(exergame, saveMetrics= TRUE)
write.csv(nzv, "results/final_model_report/nonZeroVariance_report.csv", row.names = TRUE)

# Identify missingness and report -----------------------------
missingness <- exergame %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  pivot_longer(everything(), 
               names_to = "column", 
               values_to = "na_count") %>%
  mutate(na_percentage = na_count / nrow(exergame) * 100)
# Export to CSV
write_csv(missingness, "results/final_model_report/missingness_report.csv")

# Initialize storage for results ------------------------------------------
results_list <- list()
predictor_selections <- list()
coefficient_values <- list()  #Store coefficient values for plots
removed_cols <- list()  # Store removed correlated columns

# Main Loop: Multiple Train/Test Splits ----------------------------------
cat("Running", n_splits, "train/test splits with imputation and LASSO...\n")

for (i in 1:n_splits) {
  
  # Progress indicator
  if (i %% 10 == 0) {
    cat("Completed", i, "of", n_splits, "splits...\n")
  }
  
  # Step 1: Create train/test split
  set.seed(123 + i)  # Different seed for each split
  train_index <- createDataPartition(exergame$asrs_18_total, 
                                     p = train_proportion, 
                                     list = FALSE)
  train_data <- exergame[train_index, ]
  test_data <- exergame[-train_index, ]
  
  # Step 2: Separate predictors and outcome
  X_train <- train_data %>% select(-asrs_18_total)
  y_train <- train_data$asrs_18_total
  X_test <- test_data %>% select(-asrs_18_total)
  y_test <- test_data$asrs_18_total
  
  # Step 3: Perform median imputation (fit on train, apply to both)
  preproc_model <- preProcess(X_train, method = "medianImpute")
  X_train_imputed <- predict(preproc_model, X_train)
  X_test_imputed <- predict(preproc_model, X_test)
  
  # Step 3.2 Find Highly Correlated Variables Using Test Set
  # Correlation matrix
  X_train_Cor <- cor(X_train_imputed)
  # Find high correlations and select columns for removal
  highCorXtrain <- findCorrelation(X_train_Cor, cutoff = set_cutoff)
  cols_to_remove <- colnames(X_train_imputed)[highCorXtrain]
  
  # Store removed columns for this split
  removed_cols[[i]] <- data.frame(split = i, removed_column = cols_to_remove, stringsAsFactors = FALSE)
  
  # Remove Highly Correlated Columns for Train/Test
  X_train_filt <- X_train_imputed %>% select(-all_of(cols_to_remove))
  X_test_filt <- X_test_imputed %>% select(-all_of(cols_to_remove))
  
  # Step 4: Convert to matrices for glmnet
  X_train_mat <- as.matrix(X_train_filt)
  X_test_mat <- as.matrix(X_test_filt)
  
  # Step 5: Fit LASSO with cross-validation
  cvfit <- cv.glmnet(X_train_mat, y_train, nfolds = 10, alpha = set_alpha)
  
  # Step 6: Make predictions on test set
  predictions <- predict(cvfit, X_test_mat, s = "lambda.min")
  
  # Step 7: Calculate performance metrics
  predictions_vec <- as.vector(predictions)
  rmse_value <- rmse(y_test, predictions_vec)
  mae_value <- mae(y_test, predictions_vec)
  r_squared <- as.numeric(cor(y_test, predictions_vec)^2)
  
  # Step 8: Extract selected predictors and coefficients
  coef_matrix <- coef(cvfit, s = "lambda.min")
  selected_predictors <- rownames(coef_matrix)[coef_matrix[, 1] != 0]
  selected_predictors <- selected_predictors[selected_predictors != "(Intercept)"]
  
  # Store all coefficient values (including zeros)
  coef_df <- data.frame(
    predictor = rownames(coef_matrix),
    coefficient = as.vector(coef_matrix),
    split = i,
    stringsAsFactors = FALSE
  ) %>%
    filter(predictor != "(Intercept)")
  
  coefficient_values[[i]] <- coef_df
  
  # Store results
  results_list[[i]] <- data.frame(
    split = i,
    rmse = rmse_value,
    mae = mae_value,
    r_squared = r_squared,
    n_predictors = length(selected_predictors),
    lambda_min = cvfit$lambda.min
  )
  
  predictor_selections[[i]] <- selected_predictors
}

# Combine results into dataframes -----------------------------------------
results_df <- bind_rows(results_list)
all_coefficients <- bind_rows(coefficient_values)

# Calculate predictor selection frequency ---------------------------------
predictor_freq <- table(unlist(predictor_selections)) %>%
  as.data.frame() %>%
  rename(Predictor = Var1, Frequency = Freq) %>%
  mutate(Percentage = (Frequency / n_splits) * 100) %>%
  arrange(desc(Frequency))

# Calculate coefficient statistics ----------------------------------------
cat("\nCalculating coefficient statistics...\n")

coef_summary <- all_coefficients %>%
  filter(coefficient != 0) %>%  # Only analyze non-zero coefficients
  group_by(predictor) %>%
  summarise(
    mean_coef = mean(coefficient),
    sd_coef = sd(coefficient),
    se_coef = sd(coefficient) / sqrt(n()),
    n_times_selected = n(),
    ci_lower = mean(coefficient) - 1.96 * se_coef,
    ci_upper = mean(coefficient) + 1.96 * se_coef,
    .groups = "drop"
  ) %>%
  mutate(
    selection_percentage = (n_times_selected / n_splits) * 100
  )

# Save coefficient data ---------------------------------------------------
write_csv(coef_summary %>% arrange(desc(selection_percentage)), 
          "results/final_model_report/coefficient_summary.csv")
write_csv(all_coefficients, "results/final_model_report/all_coefficients_by_split.csv")

# Export Removed Columns Data ---------------------------------------------
all_removed_cols <- bind_rows(removed_cols)
write_csv(all_removed_cols, "results/final_model_report/removed_correlated_columns_by_split.csv")

# Create publication-quality forest plot ------------------------------------
cat("\nGenerating coefficient forest plot...\n")

# Select top predictors - you can adjust this number
top_n_predictors <- 20

# Prepare data: Ranked by SELECTION FREQUENCY (most frequently selected)
plot_data <- coef_summary %>%
  arrange(desc(selection_percentage)) %>%
  head(top_n_predictors) %>%
  mutate(
    rank = row_number(),
    predictor = factor(predictor, levels = rev(predictor)),
    sign = ifelse(mean_coef > 0, "Positive", "Negative")
  )

# Create full forest plot with legend
p_forest_full <- ggplot(plot_data, aes(x = mean_coef, y = predictor, color = sign)) +
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper), 
                height = 0.3, linewidth = 0.8, alpha = 0.8, orientation = "y") +
  geom_point(size = 3.5, alpha = 0.9) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray30", linewidth = 0.6) +
  scale_color_manual(
    name = "Direction",
    values = c("Positive" = "#0072B2", "Negative" = "#D55E00"),
    labels = c("Negative" = "Negative", "Positive" = "Positive")
  ) +
  labs(
    title = "LASSO Regression Coefficients Across Multiple Train/Test Splits",
    subtitle = paste0("Top ", top_n_predictors, " most frequently selected predictors (ranked by selection frequency)"),
    x = "Mean Coefficient (95% CI)",
    y = ""
  ) +
  theme_classic(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    axis.text.y = element_text(size = 10, color = "black"),
    axis.text.x = element_text(size = 10, color = "black"),
    axis.title.x = element_text(size = 12, face = "bold", margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
    plot.margin = margin(15, 15, 15, 15)
  )

# Save the full plot
ggsave("results/final_model_report/coefficient_forest_plot_full.svg", p_forest_full, 
       width = 11, height = 8)


# Create Zoomed In Plot for Group of Predictors ---------------------------

# Create filtered plot: top 7, ranks 9-14, and ranks 17-20
# (excluding ranks 8, 15, 16 which are likely the outliers)
plot_data_filtered <- plot_data %>%
  filter(rank %in% c(1,3:7, 9:14, 17:20)) %>%
  mutate(predictor = factor(predictor, levels = rev(unique(predictor))))

p_forest_zoomed <- ggplot(plot_data_filtered, aes(x = mean_coef, y = predictor, color = sign)) +
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper), 
                height = 0.3, linewidth = 0.8, alpha = 0.8, orientation = "y") +
  geom_point(size = 3.5, alpha = 0.9) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray30", linewidth = 0.6) +
  scale_color_manual(
    name = "Direction",
    values = c("Positive" = "#0072B2", "Negative" = "#D55E00"),
    labels = c("Negative" = "Negative", "Positive" = "Positive")
  ) +
  coord_cartesian(xlim = c(-0.6, 0.6)) +  # Zoom
  labs(
    title = "LASSO Regression Coefficients (Zoomed View)",
    subtitle = "Selected predictors with coefficients in -1 to 1 range (ranks 1,3-7, 9-14, 17-20)",
    x = "Mean Coefficient (95% CI)",
    y = ""
  ) +
  theme_classic(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    axis.text.y = element_text(size = 10, color = "black"),
    axis.text.x = element_text(size = 10, color = "black"),
    axis.title.x = element_text(size = 12, face = "bold", margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
    plot.margin = margin(15, 15, 15, 15)
  )

# Save the zoomed plot
ggsave("results/final_model_report/coefficient_forest_plot_zoomed.svg", p_forest_zoomed, 
       width = 11, height = 7)


# Create Zoomed in Plot for Sex Predictor ---------------------------------
# The Sex variable was out of frame for the in the Zoomed in plot and needs 
# its own plot

plot_data_sex <- plot_data %>%
  filter(rank %in% c(2)) %>%
  mutate(predictor = factor(predictor, levels = rev(unique(predictor))))

p_forest_sex <- ggplot(plot_data_sex, aes(x = mean_coef, y = predictor, color = sign)) +
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper), 
                height = 0.3, linewidth = 0.8, alpha = 0.8, orientation = "y") +
  geom_point(size = 3.5, alpha = 0.9) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray30", linewidth = 0.6) +
  scale_color_manual(
    name = "Direction",
    values = c("Positive" = "#0072B2", "Negative" = "#D55E00"),
    labels = c("Negative" = "Negative", "Positive" = "Positive")
  ) +
  coord_cartesian(xlim = c(-3.25, 0)) +
  labs(
    title = "LASSO Regression Coefficients (Sex Variable Only)",
    x = "Mean Coefficient (95% CI)",
    y = ""
  ) +
  theme_classic(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    axis.text.y = element_text(size = 10, color = "black"),
    axis.text.x = element_text(size = 10, color = "black"),
    axis.title.x = element_text(size = 12, face = "bold", margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
    plot.margin = margin(15, 15, 15, 15)
  )

# Save the zoomed plot
ggsave("results/final_model_report/coefficient_forest_plot_sex_only.svg", p_forest_sex, 
       width = 11, height = 7)


# Create visualizations (original plots) ----------------------------------
cat("\nGenerating original visualizations...\n")

# 1. Distribution of Performance Metrics
p1 <- results_df %>%
  pivot_longer(cols = c(rmse, mae, r_squared), 
               names_to = "metric", 
               values_to = "value") %>%
  ggplot(aes(x = value, fill = metric)) +
  geom_histogram(bins = 30, alpha = 0.7, color = "black") +
  facet_wrap(~metric, scales = "free") +
  theme_minimal() +
  labs(title = paste("Distribution of Performance Metrics Across", n_splits, "Splits"),
       x = "Value", y = "Count") +
  theme(legend.position = "none",
        plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/final_model_report/performance_distributions.svg", p1, 
       width = 12, height = 4)

# 2. Predictor Selection Frequency (Top 20)
p2 <- plot_data %>%
  ggplot(aes(x = reorder(predictor, n_times_selected), y = selection_percentage)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  coord_flip() +
  theme_minimal() +
  labs(title = "Top 20 Predictors by Selection Frequency",
       x = "Predictor", 
       y = "Percentage of Splits Selected (%)") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/final_model_report/predictor_frequency.svg", p2, 
       width = 10, height = 8)

# 3. Number of Predictors Selected per Split
p3 <- ggplot(results_df, aes(x = n_predictors)) +
  geom_histogram(bins = 30, fill = "coral", alpha = 0.7, color = "black") +
  theme_minimal() +
  labs(title = "Distribution of Number of Predictors Selected For 50 Test/Train Splits",
       x = "Number of Predictors in Test/Train Split", y = "Count") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/final_model_report/n_predictors_distribution.svg", p3, 
       width = 8, height = 6)

# 4. Correlation between metrics
p4 <- ggplot(results_df, aes(x = rmse, y = r_squared)) +
  geom_point(alpha = 0.5, color = "darkgreen") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  theme_minimal() +
  labs(title = "Relationship between RMSE and R-squared",
       x = "RMSE", y = "R-squared") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/final_model_report/rmse_vs_rsquared.svg", p4, 
       width = 8, height = 6)

# Save Results ------------------------------------------------------------
cat("\nSaving results...\n")

# Save all data
save(results_df, predictor_freq, predictor_selections, 
     all_coefficients, coef_summary,
     file = "results/final_model_report/lasso_multiple_splits_results.RData")

# Save summary tables as CSV
write_csv(results_df, "results/final_model_report/performance_metrics_all_splits.csv")
write_csv(predictor_freq, "results/final_model_report/predictor_selection_frequency.csv")

# Create a detailed summary report ----------------------------------------
sink("results/final_model_report/summary_report.txt")
cat(rep("=", 80), "\n")
cat("LASSO REGRESSION WITH MULTIPLE TRAIN/TEST SPLITS - DETAILED REPORT\n")
cat(rep("=", 80), "\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Number of splits:", n_splits, "\n")
cat("Train/test proportion:", train_proportion, "/", 1 - train_proportion, "\n\n")

cat("PERFORMANCE METRICS SUMMARY\n")
cat(rep("-", 80), "\n")
print(summary(results_df[, c("rmse", "mae", "r_squared", "n_predictors")]))

cat("\n\nTOP 20 PREDICTORS BY SELECTION FREQUENCY\n")
cat(rep("-", 80), "\n")
print(coef_summary %>% arrange(desc(selection_percentage)) %>% head(20))

cat("\n\nALL PREDICTORS SELECTED (SORTED BY FREQUENCY)\n")
cat(rep("-", 80), "\n")
print(predictor_freq, row.names = FALSE)

cat("\n\nPREDICTORS SELECTED IN 100% OF SPLITS\n")
cat(rep("-", 80), "\n")
always_selected <- predictor_freq %>% filter(Percentage == 100)
if (nrow(always_selected) > 0) {
  print(always_selected, row.names = FALSE)
  cat("\nCoefficient Statistics for Always-Selected Predictors:\n")
  always_selected_coefs <- coef_summary %>% 
    filter(predictor %in% always_selected$Predictor)
  print(always_selected_coefs, row.names = FALSE)
} else {
  cat("No predictors selected in all splits\n")
}

cat("\n\nPREDICTORS SELECTED IN >90% OF SPLITS\n")
cat(rep("-", 80), "\n")
frequently_selected <- predictor_freq %>% filter(Percentage > 90, Percentage < 100)
if (nrow(frequently_selected) > 0) {
  print(frequently_selected, row.names = FALSE)
} else {
  cat("No predictors in this category\n")
}

sink()
