# Create Summary Table of Cluster Data
# We need to report average power for each frequency band across all experiences
# for each cluster.

# Written by Noor Tasnim on October 31, 2025

# Load and prepare data ---------------------------------------------------
library(tidyverse)
peaks <- read_csv("../results/specparam/final_model/peaks.csv") %>%
  filter(freq_band != "delta") %>%
  filter(cluster == 3 | cluster == 11 | cluster == 12) %>%
  mutate(pw_db = pw * 10)

# Calculate summary statistics
summary_stats <- peaks %>%
  group_by(freq_band, cluster, experience) %>%
  summarise(
    mean_pw_db = mean(pw_db, na.rm = TRUE),
    sd_pw_db = sd(pw_db, na.rm = TRUE),
    n = n(),
    .groups = 'drop'
  ) %>%
  mutate(
    # Create the mean (SD) column with 2 decimal places
    mean_sd = sprintf("%.2f (%.2f)", mean_pw_db, sd_pw_db)
  )

# Define custom order for experiences
experience_order <- c("prebaseline", "digitforward", "digitbackward",
                      "gonogo","wcst","stroop","shoulder_1","shoulder_2",
                      "shoulder_3","tandem_1","tandem_2","tandem_3")
summary_stats <- summary_stats %>%
  mutate(experience = factor(experience, levels = experience_order))


# Create the row labels (cluster - experience)
summary_stats <- summary_stats %>%
  mutate(row_label = paste0("cluster ", cluster, " - ", experience))

# Reshape the data to wide format
# First, create separate columns for mean_sd and n for each freq_band
wide_mean_sd <- summary_stats %>%
  select(row_label, freq_band, mean_sd) %>%
  pivot_wider(
    names_from = freq_band,
    values_from = mean_sd,
    names_prefix = "mean_sd_"
  )

wide_n <- summary_stats %>%
  select(row_label, freq_band, n) %>%
  pivot_wider(
    names_from = freq_band,
    values_from = n,
    names_prefix = "n_"
  )

# Merge the two wide tables
wide_table <- wide_mean_sd %>%
  left_join(wide_n, by = "row_label")

# Reorder columns to interleave mean_sd and n for each freq_band
# Define custom order for freq_band
freq_band_order <- c("theta","alpha", "low_beta", "high_beta","gamma")
col_order <- c("row_label")
for (fb in freq_band_order) {
  col_order <- c(col_order, paste0("mean_sd_", fb), paste0("n_", fb))
}

# Select and reorder columns (only those that exist)
col_order_existing <- col_order[col_order %in% names(wide_table)]
wide_table <- wide_table %>%
  select(all_of(col_order_existing))

# Rename columns for clarity
names(wide_table) <- gsub("mean_sd_", "", names(wide_table))
names(wide_table) <- gsub("^n_", "n_", names(wide_table))

# Sort rows by cluster and experience
wide_table <- wide_table %>%
  mutate(
    cluster_num = as.numeric(gsub("cluster (\\d+) - .*", "\\1", row_label)),
    experience_temp = factor(gsub("cluster \\d+ - ", "", row_label), levels = experience_order)
  ) %>%
  arrange(cluster_num, experience_temp) %>%
  select(-cluster_num, -experience_temp)

# Write to CSV
write.csv(wide_table, "../results/specparam/final_model/peaks_summary_table.csv", row.names = FALSE)

# Print the table to console for verification
print(wide_table)

cat("\nSummary table has been saved to 'peaks_summary_table.csv'\n")
