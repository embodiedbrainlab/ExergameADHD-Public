# EXTRACT ERP COMPONENTS MEASURES FROM .TXT FILES
# ERPLAB exports ERP components measures at .txt files. This script compiles these
# .txt files for each task (Go/No-Go, WCST, Stroop), tidies their respective
# dataframes, and saves each as a .csv file in `data/erp/`
#
# These .csv files can then be imported in separate scripts for further analysis.
#
# Written by Noor Tasnim on September 26, 2025

# Import Libraries
library(tidyverse)

# Create output directory if it doesn't exist
dir.create("data/erp", recursive = TRUE, showWarnings = FALSE)

# Function to process ERP files for a given task
process_erp_task <- function(task_name, input_path = "../results/erp/measurements", output_path = "data/erp") {
  
  cat("Processing", task_name, "files...\n")
  
  # Get file list for specific task
  file_list <- list.files(path = input_path, pattern = paste0("^", task_name, ".*\\.txt$"), full.names = TRUE)
  
  cat("Found", length(file_list), "files for", task_name, "\n")
  
  # Function to safely read each file with base R
  safe_read_file <- function(file_path) {
    filename <- basename(file_path)
    
    # Extract measurement type
    measurement_type <- str_extract(filename, "(?<=_)[^_]+(?=\\.txt$)")
    
    tryCatch({
      df <- read.delim(file_path, stringsAsFactors = FALSE)  # Base R preserves order
      
      # Check if dataframe is empty or has no columns
      if (nrow(df) == 0 || ncol(df) == 0) {
        warning(paste("Empty file:", filename))
        return(NULL)
      }
      
      df$measurement <- measurement_type
      df$filename <- filename
      return(df)
      
    }, error = function(e) {
      warning(paste("Error reading", filename, ":", e$message))
      return(NULL)
    })
  }
  
  # Apply to all files and remove NULL results
  file_data <- map(file_list, safe_read_file)
  file_data <- file_data[!sapply(file_data, is.null)]
  
  # Combine all dataframes
  components <- bind_rows(file_data)
  
  # Clean Component Dataframe
  components <- components %>%
    mutate(
      # Extract subjectID: remove "exgm" and leading zeros, convert to numeric then back to character
      participant_id = str_extract(ERPset, "^exgm\\d+") %>%
        str_remove("^exgm") %>%
        as.numeric() %>%
        as.character(),
      
      # Extract and transform session
      session = case_when(
        str_detect(ERPset, "_s1$|_s1_") ~ "baseline",
        str_detect(ERPset, "_s2$|_s2_") ~ "intervention",
        TRUE ~ NA_character_  # For any unexpected values
      ),
      
      # Extract component from filename (2nd element after splitting by underscore)
      component = str_split(filename, "_") %>%
        map_chr(~ .x[2])
    ) %>%
    # Clean Channel Label Column to Remove Extra Spaces before label
    mutate(chlabel = str_trim(chlabel)) %>%
    # Reorder Columns
    select(participant_id, session, component, measurement, worklat, chlabel, binlabel, value, ERPset, filename)
  
  # Save as CSV
  output_file <- file.path(output_path, paste0(task_name, "_erp_data.csv"))
  write_csv(components, output_file)
  
  cat("Saved", task_name, "data to", output_file, "\n")
  cat("Final dataframe dimensions:", nrow(components), "x", ncol(components), "\n\n")
  
  return(components)
}

# Process all three tasks
gonogo_data <- process_erp_task("gonogo")
wcst_data <- process_erp_task("wcst")
stroop_data <- process_erp_task("stroop")