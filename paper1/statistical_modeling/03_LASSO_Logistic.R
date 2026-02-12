# Combined Median Imputation and LASSO Pipeline with Multiple Splits
# MULTINOMIAL REGRESSION VERSION
# This script runs multiple train/test splits, performs unique imputation for each,
# runs multinomial LASSO regression, and generates comprehensive performance report

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(caret)
library(fastDummies)
library(glmnet)

# Set Parameters ----------------------------------------------------------
n_splits <- 50  # Number of train/test splits to test
train_proportion <- 0.7  # Proportion of data for training
set_cutoff <- 0.9 # threshold for correlations in data
set_alpha <- 1 # LASSO regression (alpha=1), Ridge (alpha=0), Elastic Net (0<alpha<1)
set.seed(123)  # For reproducibility

# Load and Prepare Data ---------------------------------------------------
exergame <- readRDS("results/exergame_forFinalModel.rds") %>%
  select(-asrs_18_total, -asrs_6_total) %>%
  filter(asrs_6_total_category != "low_negative") %>%
  # Refactor with specific level ordering
  mutate(asrs_6_total_category = factor(asrs_6_total_category, 
                                        levels = c("high_negative", 
                                                   "low_positive", 
                                                   "high_positive"))) %>%
  dummy_cols(
    select_columns = c("sex", "time"),  # specify only the columns to dummy code
    remove_first_dummy = TRUE,
    remove_selected_columns = TRUE
  ) %>%
  relocate(sex_male:time_afternoon, .before = stimulant) %>%
  select(-participant_id)

# Identify missingness and report -----------------------------
missingness <- exergame %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  pivot_longer(everything(), 
               names_to = "column", 
               values_to = "na_count") %>%
  mutate(na_percentage = na_count / nrow(exergame) * 100)
# Export to CSV
write_csv(missingness, "results/logistic_regression_report/missingness_report.csv")

# Initialize storage for results ------------------------------------------
results_list <- list()
predictor_selections <- list()
coefficient_values <- list()  # Store coefficient values for plots
confusion_matrices <- list()  # Store confusion matrices
removed_cols <- list()  # Store removed correlated columns

# Main Loop: Multiple Train/Test Splits ----------------------------------
cat("Running", n_splits, "train/test splits with imputation and multinomial LASSO...\n")

for (i in 1:n_splits) {
  
  # Progress indicator
  if (i %% 10 == 0) {
    cat("Completed", i, "of", n_splits, "splits...\n")
  }
  
  # Step 1: Create train/test split
  set.seed(123 + i)  # Different seed for each split
  train_index <- createDataPartition(exergame$asrs_6_total_category, 
                                     p = train_proportion, 
                                     list = FALSE)
  train_data <- exergame[train_index, ]
  test_data <- exergame[-train_index, ]
  
  # Step 2: Separate predictors and outcome
  X_train <- train_data %>% select(-asrs_6_total_category)
  y_train <- train_data$asrs_6_total_category
  X_test <- test_data %>% select(-asrs_6_total_category)
  y_test <- test_data$asrs_6_total_category
  
  # Step 3: Perform median imputation (fit on train, apply to both)
  preproc_model <- preProcess(X_train, method = "medianImpute")
  X_train_imputed <- predict(preproc_model, X_train)
  X_test_imputed <- predict(preproc_model, X_test)
  
  # Step 3.2 Find Highly Correlated Variables Using Train Set
  X_train_Cor <- cor(X_train_imputed)
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
  
  # Step 5: Fit multinomial LASSO with cross-validation
  cvfit <- cv.glmnet(X_train_mat, y_train, 
                     nfolds = 10, 
                     family = "multinomial", 
                     alpha = set_alpha,
                     type.measure = "class")  # Use classification error for CV
  
  # Step 6: Make predictions on test set (CLASS predictions)
  predictions_class <- predict(cvfit, X_test_mat, s = "lambda.min", type = "class")
  predictions_class <- factor(predictions_class, levels = levels(y_test))
  
  # Also get probability predictions for log-loss
  predictions_prob <- predict(cvfit, X_test_mat, s = "lambda.min", type = "response")
  
  # Step 7: Calculate classification performance metrics
  
  # Confusion Matrix
  cm <- confusionMatrix(predictions_class, y_test)
  
  # Extract metrics
  accuracy <- cm$overall["Accuracy"]
  kappa <- cm$overall["Kappa"]
  
  # Class-specific metrics (weighted average)
  class_metrics <- cm$byClass
  
  # For multi-class, byClass returns a matrix. Calculate weighted averages
  if (is.matrix(class_metrics)) {
    # Weight by class frequency in test set
    class_weights <- table(y_test) / length(y_test)
    
    precision <- weighted.mean(class_metrics[, "Precision"], w = class_weights, na.rm = TRUE)
    recall <- weighted.mean(class_metrics[, "Recall"], w = class_weights, na.rm = TRUE)
    f1_score <- weighted.mean(class_metrics[, "F1"], w = class_weights, na.rm = TRUE)
  } else {
    # If only 2 classes somehow
    precision <- class_metrics["Precision"]
    recall <- class_metrics["Recall"]
    f1_score <- class_metrics["F1"]
  }
  
  # Calculate log-loss (multinomial deviance)
  # Convert predictions_prob array to proper format
  pred_probs_matrix <- predictions_prob[,,1]
  
  # Manual log-loss calculation
  n_obs <- length(y_test)
  log_loss <- 0
  for (j in 1:n_obs) {
    true_class <- as.character(y_test[j])
    true_class_idx <- which(colnames(pred_probs_matrix) == true_class)
    pred_prob <- pred_probs_matrix[j, true_class_idx]
    # Avoid log(0)
    pred_prob <- pmax(pmin(pred_prob, 1 - 1e-15), 1e-15)
    log_loss <- log_loss - log(pred_prob)
  }
  log_loss <- log_loss / n_obs
  
  # Step 8: Extract selected predictors and coefficients
  # For multinomial, coef returns a list with one matrix per class
  coef_list <- coef(cvfit, s = "lambda.min")
  
  # Process coefficients for each class
  all_predictors_selected <- c()
  
  for (class_name in names(coef_list)) {
    coef_matrix <- coef_list[[class_name]]
    
    # Get non-zero predictors (excluding intercept)
    selected_idx <- which(coef_matrix != 0)
    selected_names <- rownames(coef_matrix)[selected_idx]
    selected_names <- selected_names[selected_names != "(Intercept)"]
    
    all_predictors_selected <- c(all_predictors_selected, selected_names)
    
    # Store coefficients with class information
    coef_df_class <- data.frame(
      predictor = rownames(coef_matrix),
      coefficient = as.vector(coef_matrix),
      class = class_name,
      split = i,
      stringsAsFactors = FALSE
    ) %>%
      filter(predictor != "(Intercept)")
    
    coefficient_values[[length(coefficient_values) + 1]] <- coef_df_class
  }
  
  # Get unique predictors selected across all classes
  unique_predictors <- unique(all_predictors_selected)
  
  # Store confusion matrix
  confusion_matrices[[i]] <- list(
    split = i,
    confusion_matrix = cm$table,
    overall = cm$overall,
    byClass = cm$byClass
  )
  
  # Store results
  results_list[[i]] <- data.frame(
    split = i,
    accuracy = accuracy,
    kappa = kappa,
    precision = precision,
    recall = recall,
    f1_score = f1_score,
    log_loss = log_loss,
    n_predictors = length(unique_predictors),
    lambda_min = cvfit$lambda.min
  )
  
  predictor_selections[[i]] <- unique_predictors
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

# Calculate coefficient statistics by class -------------------------------
cat("\nCalculating coefficient statistics by class...\n")

coef_summary <- all_coefficients %>%
  filter(coefficient != 0) %>%  # Only analyze non-zero coefficients
  group_by(predictor, class) %>%
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

# Calculate overall predictor importance (across all classes)
coef_importance <- coef_summary %>%
  group_by(predictor) %>%
  summarise(
    avg_abs_coef = mean(abs(mean_coef)),
    max_selection_pct = max(selection_percentage),
    n_classes_selected = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(max_selection_pct), desc(avg_abs_coef))

# Save coefficient data ---------------------------------------------------
write_csv(coef_summary %>% arrange(class, desc(selection_percentage)), 
          "results/logistic_regression_report/coefficient_summary_by_class.csv")
write_csv(coef_importance, 
          "results/logistic_regression_report/coefficient_importance_overall.csv")
write_csv(all_coefficients, "results/logistic_regression_report/all_coefficients_by_split.csv")

# Export Removed Columns Data ---------------------------------------------
all_removed_cols <- bind_rows(removed_cols)
write_csv(all_removed_cols, "results/logistic_regression_report/removed_correlated_columns_by_split.csv")

# Create visualizations ---------------------------------------------------
cat("\nGenerating visualizations...\n")

# 1. Distribution of Performance Metrics
p1 <- results_df %>%
  pivot_longer(cols = c(accuracy, kappa, precision, recall, f1_score, log_loss), 
               names_to = "metric", 
               values_to = "value") %>%
  ggplot(aes(x = value, fill = metric)) +
  geom_histogram(bins = 30, alpha = 0.7, color = "black") +
  facet_wrap(~metric, scales = "free") +
  theme_minimal() +
  labs(title = paste("Distribution of Classification Metrics Across", n_splits, "Splits"),
       x = "Value", y = "Count") +
  theme(legend.position = "none",
        plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/logistic_regression_report/performance_distributions.svg", p1, 
       width = 14, height = 8)

# 2. Predictor Selection Frequency (Top 30)
p2 <- predictor_freq %>%
  head(30) %>%
  ggplot(aes(x = reorder(Predictor, Frequency), y = Percentage)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  coord_flip() +
  theme_minimal() +
  labs(title = "Top 30 Predictors by Selection Frequency",
       x = "Predictor", 
       y = "Percentage of Splits Selected (%)") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/logistic_regression_report/predictor_frequency.svg", p2, 
       width = 10, height = 8)

# 3. Number of Predictors Selected per Split
p3 <- ggplot(results_df, aes(x = n_predictors)) +
  geom_histogram(bins = 30, fill = "coral", alpha = 0.7, color = "black") +
  theme_minimal() +
  labs(title = "Distribution of Number of Predictors Selected",
       x = "Number of Predictors", y = "Count") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/logistic_regression_report/n_predictors_distribution.svg", p3, 
       width = 8, height = 6)

# 4. Relationship between Accuracy and F1-Score
p4 <- ggplot(results_df, aes(x = accuracy, y = f1_score)) +
  geom_point(alpha = 0.5, color = "darkgreen", size = 2) +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  theme_minimal() +
  labs(title = "Relationship between Accuracy and F1-Score",
       x = "Accuracy", y = "F1-Score") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/logistic_regression_report/accuracy_vs_f1.svg", p4, 
       width = 8, height = 6)

# 5. Coefficient Forest Plot by Class (Top 20 predictors)
top_predictors <- coef_importance %>% head(20) %>% pull(predictor)

p5 <- coef_summary %>%
  filter(predictor %in% top_predictors) %>%
  ggplot(aes(x = mean_coef, y = reorder(predictor, mean_coef), color = class)) +
  geom_point(size = 3, position = position_dodge(width = 0.5)) +
  geom_errorbar(aes(xmin = ci_lower, xmax = ci_upper), 
                width = 0.2,
                orientation = "y",
                position = position_dodge(width = 0.5)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  theme_minimal() +
  labs(title = "Coefficient Estimates by Class (Top 20 Predictors)",
       x = "Mean Coefficient Estimate (95% CI)",
       y = "Predictor",
       color = "Class") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("results/logistic_regression_report/coefficient_forest_plot.svg", p5, 
       width = 12, height = 10)

# 6. Average Confusion Matrix
# Calculate average confusion matrix across all splits
avg_cm <- Reduce("+", lapply(confusion_matrices, function(x) x$confusion_matrix)) / n_splits

# Convert to data frame for plotting
avg_cm_df <- as.data.frame.table(avg_cm)
colnames(avg_cm_df) <- c("Predicted", "Actual", "Count")

p6 <- ggplot(avg_cm_df, aes(x = Actual, y = Predicted, fill = Count)) +
  geom_tile(color = "white") +
  geom_text(aes(label = round(Count, 1)), size = 5) +
  scale_fill_gradient(low = "white", high = "steelblue") +
  theme_minimal() +
  labs(title = paste("Average Confusion Matrix Across", n_splits, "Splits"),
       x = "Actual Class",
       y = "Predicted Class") +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"),
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("results/logistic_regression_report/average_confusion_matrix.svg", p6,
       width = 8, height = 7)

# Save Results ------------------------------------------------------------
cat("\nSaving results...\n")

# Save all data
save(results_df, predictor_freq, predictor_selections, 
     all_coefficients, coef_summary, coef_importance,
     confusion_matrices, avg_cm,
     file = "results/logistic_regression_report/lasso_multiple_splits_results.RData")

# Save summary tables as CSV
write_csv(results_df, "results/logistic_regression_report/performance_metrics_all_splits.csv")
write_csv(predictor_freq, "results/logistic_regression_report/predictor_selection_frequency.csv")

# Save average confusion matrix
write_csv(as.data.frame.table(avg_cm), 
          "results/logistic_regression_report/average_confusion_matrix.csv")

# Create a detailed summary report ----------------------------------------
sink("results/logistic_regression_report/summary_report.txt")
cat(rep("=", 80), "\n")
cat("MULTINOMIAL LASSO REGRESSION - MULTIPLE TRAIN/TEST SPLITS REPORT\n")
cat(rep("=", 80), "\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Number of splits:", n_splits, "\n")
cat("Train/test proportion:", train_proportion, "/", 1 - train_proportion, "\n")
cat("Outcome variable:", "asrs_6_total_category\n")
cat("Classes:", paste(levels(exergame$asrs_6_total_category), collapse = ", "), "\n\n")

cat("CLASSIFICATION PERFORMANCE METRICS SUMMARY\n")
cat(rep("-", 80), "\n")
print(summary(results_df[, c("accuracy", "kappa", "precision", "recall", "f1_score", "log_loss", "n_predictors")]))

cat("\n\nAVERAGE CONFUSION MATRIX\n")
cat(rep("-", 80), "\n")
print(round(avg_cm, 2))

cat("\n\nTOP 20 PREDICTORS BY OVERALL IMPORTANCE\n")
cat(rep("-", 80), "\n")
print(coef_importance %>% head(20))

cat("\n\nTOP 20 PREDICTORS BY SELECTION FREQUENCY\n")
cat(rep("-", 80), "\n")
print(predictor_freq %>% head(20), row.names = FALSE)

cat("\n\nPREDICTORS SELECTED IN 100% OF SPLITS\n")
cat(rep("-", 80), "\n")
always_selected <- predictor_freq %>% filter(Percentage == 100)
if (nrow(always_selected) > 0) {
  print(always_selected, row.names = FALSE)
  cat("\nCoefficient Statistics for Always-Selected Predictors (by class):\n")
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

cat("\n\nCOEFFICIENT SUMMARY BY CLASS (Top 10 per class)\n")
cat(rep("-", 80), "\n")
for (class_name in unique(coef_summary$class)) {
  cat("\nClass:", class_name, "\n")
  class_coefs <- coef_summary %>% 
    filter(class == class_name) %>%
    arrange(desc(selection_percentage)) %>%
    head(10) %>%
    as.data.frame()  # Convert to data frame to avoid tibble print issues
  print(class_coefs, row.names = FALSE)
}

sink()

cat("\nAnalysis complete! Results saved to results/logistic_regression_report/\n")
