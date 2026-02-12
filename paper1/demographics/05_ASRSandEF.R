# Plotting Executive Function Task Performance
# The goal for this script is to determine whether ASRS-18 can predict performance
# on each task.
#
# Because we have checked for multicolinearity, we should just use the final
# dataset that was prepared for imputation during our statistical modeling phase.
#
# Make sure we take note of the sample size for each measurement, particularly 
# for Go/No-Go
#
# Written by Noor Tasnim on October 23, 2025

# Load Libraries and Datasets ---------------------------------------------
library(tidyverse)
library(effectsize)
exergame <- readRDS("../statistical_modeling/results/exergame_forImputation.rds")

# Pull in information on ASSET
asset <- read_csv("data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  select(participant_id,asset_hyperactive,asset_inattentive)

exergame <- exergame %>%
  left_join(asset, by = "participant_id") %>%
  relocate((asset_hyperactive:asset_inattentive),.before = stimulant)

# Pull Correlations Function Used for Figure 2
source("00_plottingFunctions.R")

# Plot Variables of Interest ---------------------------------------------------------
# Get all variables between gonogo_omissionerror_v and digit_bTE_ML
col_start <- which(names(exergame) == "gonogo_omissionerror_v")
col_end <- which(names(exergame) == "digit_bTE_ML")
vars_to_plot <- names(exergame)[col_start:col_end]

# Generate and save all plots
walk(vars_to_plot, function(var) {
  plot <- exergame_corrPlot(data = exergame, x_var = var, x_label = var)
  ggsave(paste0("results/executiveFunctionCorrelations/", var, ".png"),
         plot, width = 10, height = 8, dpi = 300)
  cat("Saved:", var, "\n")
})

# Generate Summary Table --------------------------------------------------
summary_table <- exergame_summaryTable(
  data = exergame,
  col_start = "gonogo_omissionerror_v",
  col_end = "digit_bTE_ML",
  digits = 2
)

# View it
print(summary_table)

# Save it
write.csv(summary_table, "results/executive_function_summary.csv", row.names = FALSE)

# ANOVA Tests -------------------------------------------------------------

# no_lowNeg <- exergame %>%
#   filter(asrs_6_total_category != "low_negative")
# 
# # One-way ANOVA
# anova_result <- aov(stroop_propcorrect_incongruent ~ asrs_6_total_category, data = no_lowNeg)
# summary(anova_result)
# eta_squared(anova_result)
