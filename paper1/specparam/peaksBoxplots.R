# BOXPLOTS COMPARING IDENTIFIED PEAKS FROM SPECPARAM
# Once SpecParam was run on pre-processed EEG data, peaks from delta-gamma were
# identified with their respective relative power, center of frequency, and 
# bandwidth.
#
# Because we are only working with Clusters 3, 11, and 12 for our final manuscript
# we will solely report their specific peaks.
#
# The goal of this script is to plot power from theta, alpha, low beta, high beta,
# and gamma for the final manuscript.
#
# Alpha power will at the very least be added to each cluster figure. We will also
# need to report how many peaks are on each boxplot, because PSDs show total number
# of participants, but it is very possible that some individuals did not have a 
# peak. So we will need a final count for each.
# 
# Written by Noor Tasnim on 10/30/2025
# Refactored on 10/30/2025

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(ggbeeswarm)

# Create output directory structure if it doesn't exist
base_dir <- "../results/specparam/final_model/peaks_boxplots/"
freq_bands <- c("theta", "alpha", "low_beta", "high_beta", "gamma")

for (fb in freq_bands) {
  dir.create(paste0(base_dir, fb), recursive = TRUE, showWarnings = FALSE)
}

# Load and prepare data ---------------------------------------------------
exergame <- readRDS("../statistical_modeling/results/exergame_forFinalModel.rds") %>%
  select(participant_id, asrs_6_total_category, sex)

peaks <- read_csv("../results/specparam/final_model/peaks.csv") %>%
  filter(freq_band != "delta") %>%
  filter(cluster == 3 | cluster == 11 | cluster == 12) %>%
  mutate(pw_db = pw * 10) %>%
  select(subject:freq_band, pw_db) %>%
  mutate(participant_id = as.numeric(sub("exgm", "", subject))) %>%
  relocate(participant_id) %>% 
  select(-subject) %>%
  left_join(exergame, by = "participant_id")

# Refactor experience variable with proper ordering and labels ------------
# Define the order and labels
experience_levels <- c('prebaseline', 'digitforward', 'digitbackward', 'gonogo', 
                       'wcst', 'stroop', 'shoulder_1', 'shoulder_2', 'shoulder_3', 
                       'tandem_1', 'tandem_2', 'tandem_3')

experience_labels <- c('Resting State', 'Digit Forward', 'Digit Backward', 
                       'Go/No-Go', 'WCST', 'Stroop', 'Shoulder T1', 
                       'Shoulder T2', 'Shoulder T3', 'Tandem T1', 
                       'Tandem T2', 'Tandem T3')

# Apply to the main peaks dataframe
peaks <- peaks %>%
  mutate(experience = factor(experience, 
                             levels = experience_levels, 
                             labels = experience_labels),
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

# Create Cluster Datasets -------------------------------------------------
cluster3 <- peaks %>% filter(cluster == 3)
cluster11 <- peaks %>% filter(cluster == 11)
cluster12 <- peaks %>% filter(cluster == 12)

# Define plotting function ------------------------------------------------
create_peak_boxplot <- function(data, cluster_num, freq_band_name) {
  
  # Filter data for the specific frequency band
  plot_data <- data %>%
    filter(freq_band == freq_band_name)
  
  # Calculate sample sizes for each experience level
  sample_sizes <- plot_data %>%
    group_by(experience) %>%
    summarise(n = n(), 
              y_pos = max(pw_db, na.rm = TRUE) + 1.5) %>%
    mutate(label = paste0("(n=", n, ")"))
  
  # Create the plot
  p <- ggplot(plot_data, aes(x = experience, y = pw_db)) +
    geom_boxplot(outlier.shape = NA, linewidth = 1) +
    geom_beeswarm(aes(color = asrs_6_total_category, shape = sex), 
                  alpha = 0.65, 
                  cex = 1.5,
                  size = 2) +
    geom_text(data = sample_sizes, 
              aes(x = experience, y = y_pos, label = label),
              size = 4) +
    scale_color_manual(
      values = c("Low Negative" = "#1B9E77", 
                 "High Negative" = "#D95F02", 
                 "Low Positive" = "#E7298A", 
                 "High Positive" = "#7570B3"),
      drop = FALSE
    ) +
    labs(x = "Experience", 
         y = "Power (dB)",
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
  
  # Save as PNG with same dimensions as SVG
  ggsave(filename = paste0(base_dir, freq_band_name, "/",
                           "cluster", cluster_num, "_", freq_band_name, ".png"),
         plot = p,
         width = 306 * 3,
         height = 450,
         units = "px",
         dpi = 96)
  
  # Save as SVG (3x width of original PNG)
  ggsave(filename = paste0(base_dir, freq_band_name, "/",
                           "cluster", cluster_num, "_", freq_band_name, ".svg"),
         plot = p,
         width = (306 * 3) / 96,
         height = 450 / 96,
         units = "in")
  
  return(p)
}

# Generate all plots ------------------------------------------------------
# Define clusters
clusters <- list(
  list(data = cluster3, num = 3),
  list(data = cluster11, num = 11),
  list(data = cluster12, num = 12)
)

# Loop through clusters and frequency bands
for (cluster_info in clusters) {
  for (freq_band in freq_bands) {
    cat(paste0("Creating plot for Cluster ", cluster_info$num, 
               " - ", freq_band, " band...\n"))
    
    create_peak_boxplot(
      data = cluster_info$data,
      cluster_num = cluster_info$num,
      freq_band_name = freq_band
    )
  }
}

cat("\nAll plots have been generated and saved!\n")
cat("Location: ../results/specparam/final_model/peaks_boxplots/\n")
cat("Organized by frequency band subdirectories\n")
cat("Each plot contains all 12 experiences for comparison\n")
