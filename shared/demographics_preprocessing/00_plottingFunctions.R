# PLOTTING FUNCTIONS
# Use this as a source code to define specific functions that you would like to
# define for plotting


# Plotting Single Correlations --------------------------------------
exergame_corrPlot <- function(data, x_var, y_var = "asrs_18_total", 
                                    color_var = "asrs_6_total_category",
                                    shape_var = "sex",
                                    x_label, y_label = "ASRS-18") {
  
  # Calculate correlation and p-value
  cor_test <- cor.test(data[[x_var]], data[[y_var]])
  cor_value <- round(cor_test$estimate, 3)
  p_value <- cor_test$p.value
  
  # Format p-value
  p_text <- ifelse(p_value < 0.001, "p < 0.001", paste("p =", round(p_value, 3)))
  
  # Create label text
  stats_label <- paste0("r = ", cor_value, "\n", p_text)
  
  # Create the plot
  ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]])) +
    geom_point(aes(color = .data[[color_var]], shape = .data[[shape_var]]), 
               size = 5, alpha = 0.7) +
    geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1) +
    scale_color_brewer(palette = "Dark2") +
    annotate("text", 
             x = Inf, y = -Inf,
             label = stats_label,
             hjust = 1.1, vjust = -0.5,
             size = 12,
             fontface = "bold") +
    labs(
      x = x_label,
      y = y_label,
      color = "ASRS-6 Category",
      shape = "Sex"
    ) +
    theme_minimal(base_size = 14) +
    theme(
      legend.position = "bottom",
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.line = element_line(color = "black", linewidth = 1),
      axis.text = element_text(size = 14),
      axis.title = element_text(size = 14)
    )
}


# Creating Summary Table --------------------------------------------------
exergame_summaryTable <- function(data, 
                                  col_start, 
                                  col_end,
                                  group_var = "asrs_6_total_category",
                                  digits = 2) {
  
  # Get column indices if names are provided
  if (is.character(col_start)) {
    col_start_idx <- which(names(data) == col_start)
  } else {
    col_start_idx <- col_start
  }
  
  if (is.character(col_end)) {
    col_end_idx <- which(names(data) == col_end)
  } else {
    col_end_idx <- col_end
  }
  
  # Get column names in range
  cols_to_summarize <- names(data)[col_start_idx:col_end_idx]
  
  # Get unique categories
  categories <- unique(data[[group_var]]) %>% na.omit() %>% sort()
  
  # Create summary for each variable
  summary_list <- lapply(cols_to_summarize, function(col) {
    result <- data.frame(Variable = col)
    
    # Calculate for ALL participants first
    values_all <- data[[col]]
    values_all <- values_all[!is.na(values_all)]
    
    mean_all <- mean(values_all, na.rm = TRUE)
    sd_all <- sd(values_all, na.rm = TRUE)
    n_all <- length(values_all)
    
    mean_sd_all <- sprintf(paste0("%.", digits, "f (%.", digits, "f)"), 
                           mean_all, sd_all)
    
    result[["All"]] <- mean_sd_all
    result[["All_n"]] <- paste0("n=", n_all)
    
    # Then calculate for each category
    for (cat in categories) {
      # Filter data for this category
      cat_data <- data[data[[group_var]] == cat & !is.na(data[[group_var]]), ]
      
      # Calculate statistics
      values <- cat_data[[col]]
      values <- values[!is.na(values)]
      
      mean_val <- mean(values, na.rm = TRUE)
      sd_val <- sd(values, na.rm = TRUE)
      n_val <- length(values)
      
      # Format mean (SD)
      mean_sd_text <- sprintf(paste0("%.", digits, "f (%.", digits, "f)"), 
                              mean_val, sd_val)
      
      # Add columns for this category
      result[[as.character(cat)]] <- mean_sd_text
      result[[paste0(as.character(cat), "_n")]] <- paste0("n=", n_val)
    }
    
    return(result)
  })
  
  # Combine all rows
  table_final <- do.call(rbind, summary_list)
  
  return(table_final)
}


# EXAMPLE USAGE:
# summary_table <- exergame_summaryTable(
#   data = exergame,
#   col_start = "gonogo_omissionerror_v",
#   col_end = "digit_bTE_ML"
# )
# 
# # View the table
# print(summary_table)
# 
# # Save as CSV for easy copy-paste into Word
# write.csv(summary_table, "results/summary_table.csv", row.names = FALSE)
# 
# # Or use knitr::kable for a nicely formatted table
# library(knitr)
# kable(summary_table)


