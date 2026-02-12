# BOXPLOTS COMPARING DMN AND DAN FUNCTIONAL CONNECTIVITY
#
# The MATLAB script, `../statistical_modeling/reshapeROIconnect.m`, took the 68x68
# matrices calculated using ROIconnect and transformed them into DMN-DAN 
# connectivity matrices. The same script calculated averages using MATLAB's triu
# function to give us average connectivity in DMN, DAN, and DMN-DAN for all
# frequency bands and tasks for each participant.
#
# Because our final statistical model is focused on alpha connectivity and that
# DMN-DAN connectivity is heavily correlated with DMN and DAN activity, we'll
# show boxplots for each network for our functional connectivity figure.
#
# We should have values for everyone except the two participants who performed
# Go/No-Go correctly, so we'll also check for NA values in the .csv file to
# report sample sizes appropriately.
# 
# Written by Noor Tasnim on 11/02/2025
# Refactored on 11/02/2025

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(ggbeeswarm)

# Create output directory structure if it doesn't exist
base_dir <- "../results/DMN_DAN_plotting/alpha/"
dir.create(base_dir, recursive = TRUE, showWarnings = FALSE)

# Load and prepare data ---------------------------------------------------
exergame <- readRDS("../statistical_modeling/results/exergame_forFinalModel.rds") %>%
  select(participant_id, asrs_6_total_category, sex)

fc <- read_csv("../statistical_modeling/results/connectivity_analysis_results.csv") %>%
  filter(frequency_band == "alpha") %>%
  select(-DMN_DAN_connectivity) %>% 
  mutate(
    DMN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DMN_connectivity
    ),
    DAN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DAN_connectivity
    )) %>%
  mutate(participant_id = as.numeric(sub("exgm", "", id))) %>%
  relocate(participant_id) %>% 
  select(-id) %>%
  left_join(exergame, by = "participant_id")


# Refactor task variable with proper ordering and labels -----------------
# Define the order and labels
task_levels <- c('prebaseline', 'digitforward', 'digitbackward', 'gonogo', 
                 'wcst', 'stroop', 'shoulder_1', 'shoulder_2', 'shoulder_3', 
                 'tandem_1', 'tandem_2', 'tandem_3')

task_labels <- c('Resting State', 'Digit Forward', 'Digit Backward', 
                 'Go/No-Go', 'WCST', 'Stroop', 'Shoulder T1', 
                 'Shoulder T2', 'Shoulder T3', 'Tandem T1', 
                 'Tandem T2', 'Tandem T3')

# Apply to the main fc dataframe
fc <- fc %>%
  mutate(task = factor(task, 
                       levels = task_levels, 
                       labels = task_labels),
         asrs_6_total_category = case_when(
           asrs_6_total_category == "low_negative" ~ "Low Negative",
           asrs_6_total_category == "high_negative" ~ "High Negative",
           asrs_6_total_category == "high_positive" ~ "High Positive",
           asrs_6_total_category == "low_positive" ~ "Low Positive",
           TRUE ~ asrs_6_total_category
         ),
         asrs_6_total_category = factor(asrs_6_total_category,
                                        levels = c("Low Negative", "High Negative", 
                                                   "Low Positive", "High Positive")),
         sex = case_when(
           sex == "female" ~ "Female",
           sex == "male" ~ "Male",
           TRUE ~ sex
         ))

# Generate participant count summary --------------------------------------
cat("\n=== PARTICIPANT COUNTS BY TASK ===\n\n")

# Count participants with valid DMN connectivity values
dmn_counts <- fc %>%
  group_by(task) %>%
  summarise(
    total_observations = n(),
    valid_dmn = sum(!is.na(DMN_connectivity)),
    missing_dmn = sum(is.na(DMN_connectivity)),
    unique_participants = n_distinct(participant_id)
  ) %>%
  arrange(task)

cat("DMN Connectivity:\n")
print(dmn_counts, n = Inf)
cat("\n")

# Count participants with valid DAN connectivity values
dan_counts <- fc %>%
  group_by(task) %>%
  summarise(
    total_observations = n(),
    valid_dan = sum(!is.na(DAN_connectivity)),
    missing_dan = sum(is.na(DAN_connectivity)),
    unique_participants = n_distinct(participant_id)
  ) %>%
  arrange(task)

cat("DAN Connectivity:\n")
print(dan_counts, n = Inf)
cat("\n")

# Save the counts to CSV files
write_csv(dmn_counts, paste0(base_dir, "dmn_participant_counts.csv"))
write_csv(dan_counts, paste0(base_dir, "dan_participant_counts.csv"))

cat("Participant count summaries saved to CSV files.\n\n")

# Define task groupings --------------------------------------------------
cognitive_tasks <- c('Resting State', 'Digit Forward', 'Digit Backward', 
                     'Go/No-Go', 'WCST', 'Stroop')

motor_tasks <- c('Shoulder T1', 'Shoulder T2', 'Shoulder T3', 
                 'Tandem T1', 'Tandem T2', 'Tandem T3')

# Define plotting function ------------------------------------------------
create_connectivity_boxplot <- function(data, network_name, y_var, y_label, 
                                        task_subset, task_type, y_limits) {
  
  # Filter data for specific tasks
  plot_data <- data %>%
    filter(task %in% task_subset) %>%
    mutate(task = factor(task, levels = task_subset))
  
  # Create the plot
  p <- ggplot(plot_data, aes(x = task, y = .data[[y_var]])) +
    geom_boxplot(outlier.shape = NA, linewidth = 1) +
    geom_beeswarm(aes(color = asrs_6_total_category, shape = sex), 
                  alpha = 0.65, 
                  cex = 1.5,
                  size = 2) +
    scale_color_manual(
      values = c("Low Negative" = "#1B9E77", 
                 "High Negative" = "#D95F02", 
                 "Low Positive" = "#E7298A", 
                 "High Positive" = "#7570B3"),
      drop = FALSE
    ) +
    scale_y_continuous(limits = y_limits) +
    labs(x = "Task", 
         y = y_label,
         color = "ASRS-6 Category",
         shape = "Sex") +
    theme_classic(base_size = 12) +
    theme(
      axis.title.x = element_text(face = "bold", size = 13.5, margin = margin(t = 5)),
      axis.title.y = element_text(face = "bold", size = 13.5, margin = margin(r = 5)),
      axis.text.x = element_text(size = 8.5),
      axis.text.y = element_text(size = 10.5),
      axis.line = element_line(linewidth = 1),
      axis.ticks = element_line(linewidth = 0.5),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.box = "vertical",
      legend.title = element_text(face = "bold", size = 10.5),
      legend.text = element_text(size = 9),
      legend.key.size = unit(0.3, "cm"),
      legend.margin = margin(t = 2, b = 2),
      legend.box.spacing = unit(0.1, "cm"),
      plot.margin = margin(5, 5, 5, 5)
    ) +
    guides(
      color = guide_legend(nrow = 1, title.position = "top"),
      shape = guide_legend(nrow = 1, title.position = "top")
    )
  
  # Create filename
  filename_base <- paste0(network_name, "_", task_type, "_alpha")
  
  # Calculate 60% of original width
  plot_width <- 306 * 3 * 0.6
  
  # Save as PNG with 60% width
  ggsave(filename = paste0(base_dir, filename_base, ".png"),
         plot = p,
         width = plot_width,
         height = 450,
         units = "px",
         dpi = 96)
  
  # Save as SVG with 60% width
  ggsave(filename = paste0(base_dir, filename_base, ".svg"),
         plot = p,
         width = plot_width / 96,
         height = 450 / 96,
         units = "in")
  
  return(p)
}

# Generate plots ----------------------------------------------------------
cat("Creating DMN cognitive tasks plot...\n")
dmn_cognitive_plot <- create_connectivity_boxplot(
  data = fc,
  network_name = "DMN",
  y_var = "DMN_connectivity",
  y_label = "DMN Connectivity (Alpha)",
  task_subset = cognitive_tasks,
  task_type = "cognitive",
  y_limits = c(0, 0.2)
)

cat("Creating DMN motor tasks plot...\n")
dmn_motor_plot <- create_connectivity_boxplot(
  data = fc,
  network_name = "DMN",
  y_var = "DMN_connectivity",
  y_label = "DMN Connectivity (Alpha)",
  task_subset = motor_tasks,
  task_type = "motor",
  y_limits = c(0.125, 0.45)
)

cat("Creating DAN cognitive tasks plot...\n")
dan_cognitive_plot <- create_connectivity_boxplot(
  data = fc,
  network_name = "DAN",
  y_var = "DAN_connectivity",
  y_label = "DAN Connectivity (Alpha)",
  task_subset = cognitive_tasks,
  task_type = "cognitive",
  y_limits = c(0, 0.2)
)

cat("Creating DAN motor tasks plot...\n")
dan_motor_plot <- create_connectivity_boxplot(
  data = fc,
  network_name = "DAN",
  y_var = "DAN_connectivity",
  y_label = "DAN Connectivity (Alpha)",
  task_subset = motor_tasks,
  task_type = "motor",
  y_limits = c(0.125, 0.45)
)

cat("\nAll plots have been generated and saved!\n")
cat("Location: ", base_dir, "\n")
cat("Files created:\n")
cat("  - DMN_cognitive_alpha.png/svg\n")
cat("  - DMN_motor_alpha.png/svg\n")
cat("  - DAN_cognitive_alpha.png/svg\n")
cat("  - DAN_motor_alpha.png/svg\n")
cat("  - dmn_participant_counts.csv\n")
cat("  - dan_participant_counts.csv\n")
