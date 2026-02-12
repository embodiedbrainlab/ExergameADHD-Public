# LINEAR MODELING WITH LASSO PENALIZATION
# Now that the final dataframe has been created, we will use the glmnet library
# using cross-validation and LASSO penalization to create a model for our data.

# UPDATE: Looks like bottom chunk of code decided that 30 predictors is enough,
# and that lambda.1se will help reduce it to 17 main predictors. It'll explain
# about 30-40% of your data, so it's a helpful start in terms of exploratory
# research into adults with ADHD.

# Load Parameters ----------------------------------------------------------
# Libraries
library(tidyverse)
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

# Create Model ------------------------------------------------------------
cvfit <- cv.glmnet(X_train,y_train, alpha = 0, nfolds = 3)
plot(cvfit)

lambda_min <- cvfit$lambda.min
lambda_1se <- cvfit$lambda.1se


# Predict -----------------------------------------------------------------

predictions <- predict(cvfit, X_test, s = "lambda.min")

# Calculate performance metrics
rmse_value <- rmse(y_test, predictions)
mae_value <- mae(y_test, predictions)
r_squared <- cor(y_test, predictions)^2

# Print results
cat("RMSE:", rmse_value, "\n")
cat("MAE:", mae_value, "\n")
cat("R-squared:", r_squared, "\n")

