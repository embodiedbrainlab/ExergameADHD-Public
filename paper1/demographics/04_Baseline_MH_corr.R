# ============================================================================
# Correlation Analysis: ASRS-18 Total vs. Multiple Variables
# ============================================================================
# This script creates scatter plots with regression lines comparing ASRS-18 
# Total scores with three different variables: ASSET Total, BDI Total, and 
# BAI Total. Each plot includes correlation coefficient and p-value.
# 
# Points are colored by ASRS-6 Total Category using the Dark2 palette.
# ============================================================================

library(tidyverse)
source("00_plottingFunctions.R")

# Load data
exergame <- read_csv("data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  mutate(asrs_6_total_category = factor(asrs_6_total_category,
                                        levels = c("low_negative","high_negative","high_positive","low_positive"),
                                        labels = c("Low Negative","High Negative","High Positive","Low Positive")),
         sex = case_when(
           sex == 1 ~ "Female",
           sex == 2 ~ "Male"))

# ============================================================================
# Generate plots
# ============================================================================

# Plot 1: Asset Total vs ASRS-18 Total
plot_asset <- exergame_corrPlot(
  data = exergame,
  x_var = "asset_total",
  x_label = "ASSET-BS"
)

# Plot 2: BDI Total vs ASRS-18 Total
plot_bdi <- exergame_corrPlot(
  data = exergame,
  x_var = "bdi_total",
  x_label = "BDI"
)

# Plot 3: BAI Total vs ASRS-18 Total
plot_bai <- exergame_corrPlot(
  data = exergame,
  x_var = "bai_total",
  x_label = "BAI"
)

# Display plots
print(plot_asset)
print(plot_bdi)
print(plot_bai)

# Save plots
# PNG Version
ggsave("results/mentalhealth/plot_asset_asrs.png", plot_asset, width = 10, height = 8, dpi = 300)
ggsave("results/mentalhealth/plot_bdi_asrs.png", plot_bdi, width = 10, height = 8, dpi = 300)
ggsave("results/mentalhealth/plot_bai_asrs.png", plot_bai, width = 10, height = 8, dpi = 300)
# SVG Version
ggsave("results/mentalhealth/plot_asset_asrs.svg", plot_asset, width = 10, height = 8)
ggsave("results/mentalhealth/plot_bdi_asrs.svg", plot_bdi, width = 10, height = 8)
ggsave("results/mentalhealth/plot_bai_asrs.svg", plot_bai, width = 10, height = 8)
