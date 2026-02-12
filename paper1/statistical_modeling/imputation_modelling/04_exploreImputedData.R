# EXPLORING IMPUTED DATA
# The script 03_convergeImputedData.R filled in the NA columns of our original 
# wide dataframe (with the exception of cluster11_gonogo_theta).
#
# This script compares our original dataframe to our new and complete dataframe.
#
# Geom_plot will be use to plot datapoints from all rows for each column that
# originally had an NA using our new dataframe.
#
# Datapoints that were originally NA, but are now imputed in the new dataframe
# will be plotted a size larger and in red.
#
# Note that the new and complete dataframe has 3 less columns because we removed
# the following columns before/after imputation:
#   1. asrs_6_total
#   2. asrs_6_total_category
#   3. cluster11_gonogo_theta
#
# Plots will be saved to the results folder.

# Import Libraries and Data --------------------------------------------------------
library(tidyverse)
original_data <- readRDS("results/exergameWideForModel.RDS")
final_data <- readRDS("results/imputed_complete_data.RDS")

# Identify Variables with Missing Data --------------------------------------------
# Find columns that had missing data in the original dataframe
missing_vars <- names(original_data)[colSums(is.na(original_data)) > 0]

# Keep only variables that exist in final_data (removes asrs_6_total, etc.)
missing_vars <- missing_vars[missing_vars %in% names(final_data)]

# Remove participant_id and outcome variable from plotting
missing_vars <- setdiff(missing_vars, c("participant_id", "asrs_18_total"))

cat("=== IMPUTATION VISUALIZATION ===\n")
cat("Found", length(missing_vars), "variables with missing data to visualize\n")
cat("First 10 variables:", paste(head(missing_vars, 10), collapse = ", "), "...\n\n")

# Create Output Directory ----------------------------------------------------------
if(!dir.exists("results/imputation_plots")) {
  dir.create("results/imputation_plots", recursive = TRUE)
  cat("✓ Created output directory: results/imputation_plots\n\n")
}

# Generate Individual Plots --------------------------------------------------------
cat("Generating individual plots...\n")

for(i in seq_along(missing_vars)) {
  var_name <- missing_vars[i]
  
  # Progress indicator every 50 variables
  if(i %% 50 == 0) {
    cat(sprintf("  Processing variable %d of %d\n", i, length(missing_vars)))
  }
  
  # Create plotting dataframe
  plot_data <- data.frame(
    participant_id = final_data$participant_id,
    value = final_data[[var_name]],
    was_missing = is.na(original_data[[var_name]]),
    stringsAsFactors = FALSE
  )
  
  # Calculate statistics
  n_imputed <- sum(plot_data$was_missing)
  n_original <- sum(!plot_data$was_missing)
  pct_imputed <- round(100 * n_imputed / nrow(plot_data), 1)
  
  # Determine if variable is binary (only 0 and 1 values)
  unique_vals <- unique(plot_data$value)
  is_binary <- all(unique_vals %in% c(0, 1))
  
  # Create the plot
  if(is_binary) {
    # For binary variables, use jitter to see overlapping points
    p <- ggplot(plot_data, aes(x = participant_id, y = value)) +
      geom_point(data = filter(plot_data, !was_missing),
                 color = "black", size = 2, alpha = 0.6,
                 position = position_jitter(height = 0.05, width = 0)) +
      geom_point(data = filter(plot_data, was_missing),
                 color = "red", size = 3.5, alpha = 0.8,
                 position = position_jitter(height = 0.05, width = 0)) +
      scale_y_continuous(breaks = c(0, 1), limits = c(-0.1, 1.1))
  } else {
    # For continuous variables, standard point plot
    p <- ggplot(plot_data, aes(x = participant_id, y = value)) +
      geom_point(data = filter(plot_data, !was_missing),
                 color = "black", size = 2, alpha = 0.6) +
      geom_point(data = filter(plot_data, was_missing),
                 color = "red", size = 3.5, alpha = 0.8)
  }
  
  # Add labels and theme
  p <- p +
    labs(
      title = paste("Variable:", var_name),
      subtitle = paste0("Black = Original (n=", n_original, ") | ",
                        "Red = Imputed (n=", n_imputed, ", ", pct_imputed, "%)"),
      x = "Participant ID",
      y = "Value"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 11, face = "bold"),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.title = element_text(size = 10),
      panel.grid.minor = element_blank()
    )
  
  # Save plot with numbered prefix for easy sorting
  safe_var_name <- gsub("[^[:alnum:]_]", "_", var_name)
  filename <- sprintf("results/imputation_plots/%03d_%s.pdf", i, safe_var_name)
  
  ggsave(filename, plot = p, width = 10, height = 6, units = "in")
}

cat("✓ All", length(missing_vars), "plots generated successfully!\n\n")

# Generate Summary Statistics ------------------------------------------------------
cat("Calculating summary statistics...\n")

imputation_summary <- map_dfr(missing_vars, function(var_name) {
  original_vals <- original_data[[var_name]]
  final_vals <- final_data[[var_name]]
  was_missing <- is.na(original_vals)
  
  # Get range of original values
  orig_min <- min(original_vals, na.rm = TRUE)
  orig_max <- max(original_vals, na.rm = TRUE)
  
  # Get range of imputed values (if any)
  if(sum(was_missing) > 0) {
    imp_min <- min(final_vals[was_missing], na.rm = TRUE)
    imp_max <- max(final_vals[was_missing], na.rm = TRUE)
  } else {
    imp_min <- NA_real_
    imp_max <- NA_real_
  }
  
  tibble(
    variable = var_name,
    n_original = sum(!was_missing),
    n_imputed = sum(was_missing),
    percent_imputed = round(100 * sum(was_missing) / length(was_missing), 1),
    original_min = orig_min,
    original_max = orig_max,
    imputed_min = imp_min,
    imputed_max = imp_max,
    below_range = !is.na(imp_min) && imp_min < orig_min,
    above_range = !is.na(imp_max) && imp_max > orig_max
  )
})

# Save summary statistics
write_csv(imputation_summary, "results/imputation_summary_statistics.csv")
cat("✓ Summary statistics saved to: results/imputation_summary_statistics.csv\n")

# Check for Out-of-Range Imputations ----------------------------------------------
out_of_range <- imputation_summary %>%
  filter(below_range | above_range)

if(nrow(out_of_range) > 0) {
  cat("\n⚠ WARNING: Found", nrow(out_of_range), "variables with imputed values outside original range:\n")
  print(out_of_range %>% 
          select(variable, original_min, original_max, imputed_min, imputed_max))
  
  write_csv(out_of_range, "results/imputation_out_of_range.csv")
  cat("\nDetails saved to: results/imputation_out_of_range.csv\n")
  cat("Review plots for these variables carefully!\n")
} else {
  cat("\n✓ All imputed values are within the range of original observed values!\n")
}

# Display Top Variables by Missingness ---------------------------------------------
cat("\n=== TOP 10 VARIABLES BY MISSINGNESS ===\n")
top_missing <- imputation_summary %>%
  arrange(desc(percent_imputed)) %>%
  head(10) %>%
  select(variable, n_imputed, percent_imputed)

print(top_missing, n = 10)

# Final Summary --------------------------------------------------------------------
cat("\n=== SUMMARY ===\n")
cat("Total variables visualized:", length(missing_vars), "\n")
cat("Total plots generated:", length(missing_vars), "\n")
cat("Output directory: results/imputation_plots/\n")
cat("Summary file: results/imputation_summary_statistics.csv\n")

cat("\n✓ Imputation visualization complete!\n")
cat("\nNext steps:\n")
cat("1. Review plots in results/imputation_plots/ directory\n")
cat("2. Pay special attention to variables flagged as out-of-range\n")
cat("3. Check imputation_summary_statistics.csv for detailed ranges\n")