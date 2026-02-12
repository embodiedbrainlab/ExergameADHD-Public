# Testing XGBoost
# Load Parameters ----------------------------------------------------------
# Libraries
library(tidyverse)
library(xgboost)
library(glmnet)
library(fastDummies)
library(Metrics)

# Set Seed for Train/Test Split and Cross-Validation
set.seed(123)

# Load Datasets -----------------------------------------------------------
exergame <- readRDS("results/exergame_forModel.RDS")

# Create Dummy Variables for Imputed Dataset
exergame_dummy <- exergame %>%
  dummy_cols(remove_first_dummy = TRUE, # create dummy variables for factors
             remove_selected_columns = TRUE) %>% # remove original factor columns
  relocate(sex_male:time_afternoon, .before = weight) %>% # relocate new dummy columns
  select(-participant_id) # no id needed for modeling

# Create Predictor and Outcome Matrices -----------------------------------

# Create train indices
train_index <- sample(1:nrow(exergame_dummy), 0.7 * nrow(exergame_dummy))

# Training Data
X_train <- as.matrix(exergame_dummy[train_index, !names(exergame_dummy) %in% "asrs_18_total"])
y_train <- exergame_dummy$asrs_18_total[train_index]

# Test Data
X_test <- as.matrix(exergame_dummy[-train_index, !names(exergame_dummy) %in% "asrs_18_total"])
y_test <- exergame_dummy$asrs_18_total[-train_index]

# Try XGBoost -------------------------------------------------------------

xgb_model <- xgboost(data = X_train, label = y_train, 
                     nrounds = 100, objective = "reg:squarederror", verbose = 0)
xg_predictions <- predict(xgb_model, X_test)

# Evaluate
# Calculate performance metrics
xg_rmse_value <- rmse(y_test, xg_predictions)
xg_mae_value <- mae(y_test, xg_predictions)
xg_r_squared <- cor(y_test, xg_predictions)^2

# Print results
cat("RMSE:", xg_rmse_value, "\n")
cat("MAE:", xg_mae_value, "\n")
cat("R-squared:", xg_r_squared, "\n")

# Compare R squared
# Get training predictions
train_predictions <- predict(xgb_model, X_train)
train_r_squared <- cor(y_train, train_predictions)^2

cat("Training R-squared:", train_r_squared, "\n")
cat("Test R-squared:", xg_r_squared, "\n")


# Aggressive Feature Reduction --------------------------------------------

library(caret)

# Use the same reasonable parameters but with LOOCV
xgb_grid <- expand.grid(
  nrounds = c(50, 75, 100),
  max_depth = c(1, 2),
  eta = c(0.01, 0.02),
  gamma = c(5, 10),
  colsample_bytree = 0.3,
  min_child_weight = 15,
  subsample = 0.7
)

# LOOCV instead of 10-fold
ctrl <- trainControl(method = "LOOCV")

set.seed(123)
xgb_loocv <- train(
  x = X_train,
  y = y_train,
  method = "xgbTree",
  trControl = ctrl,
  tuneGrid = xgb_grid,
  verbose = FALSE
)

# Check results
print(xgb_loocv$results)
best <- xgb_loocv$results[which.max(xgb_loocv$results$Rsquared), ]
cat("\nBest LOOCV R²:", round(best$Rsquared, 3), "\n")
cat("RMSE:", round(best$RMSE, 3), "\n")

# Compare to test set
test_pred <- predict(xgb_loocv, X_test)
test_r2 <- cor(y_test, test_pred)^2
cat("Test R²:", round(test_r2, 3), "\n")