# Plotting ERP Components with ASRS
# We didn't see much of a strong correlation between behavioral performance
# and ASRS scores with any of our 4 executive function tasks.
#
# So we'll look into whether their scores have an impact on their ERPs by
# also plotting them on correlation plots.
#
# Written by Noor Tasnim on October 23, 2025

# Load Libraries and Datasets ---------------------------------------------
library(tidyverse)
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
col_start <- which(names(exergame) == "Fz_N2_FracAreaLat_nogo_go_related")
col_end <- which(names(exergame) == "Pz_P3b_OnsetLat_congruent_control")
vars_to_plot <- names(exergame)[col_start:col_end]

# Generate and save all plots
walk(vars_to_plot, function(var) {
  plot <- exergame_corrPlot(data = exergame, x_var = var, x_label = var)
  ggsave(paste0("results/ERPandASRS/", var, ".png"),
         plot, width = 10, height = 8, dpi = 300)
  cat("Saved:", var, "\n")
})

# Generate Summary Table --------------------------------------------------
erp_summary_table <- exergame_summaryTable(
  data = exergame,
  col_start = "Fz_N2_FracAreaLat_nogo_go_related",
  col_end = "Pz_P3b_OnsetLat_congruent_control",
  digits = 2
)

write.csv(erp_summary_table, "results/ERPandASRS/erp_summary_table.csv", row.names = FALSE)

# Go/NoGo Statistics -----------------------

#### Cohen's D for P3b in Pz ####
# Mean amplitude compared to  0

#### Compare Rare minus Frequent Amplitudes - Repeated Samples ####

gonogo_rarefrequentStat <- t.test(exergame$Cz_P3b_MeanAmp_go_unrelated_related, exergame$Cz_P3b_MeanAmp_nogo_unrelated_related, paired = TRUE)

# Calculate differences (removing NAs)
differences <- exergame$Cz_P3b_MeanAmp_go_unrelated_related - exergame$Cz_P3b_MeanAmp_nogo_unrelated_related
differences <- differences[!is.na(differences)]

# Extract key statistics
cat("Paired Samples T-Test Results\n",
    "=============================\n",
    "Mean difference:", round(gonogo_rarefrequentStat$estimate, 3), "\n",
    "t-statistic:", round(gonogo_rarefrequentStat$statistic, 3), "\n",
    "df:", gonogo_rarefrequentStat$parameter, "\n",
    "p-value:", format.pval(gonogo_rarefrequentStat$p.value, digits = 3), "\n",
    "95% CI: [", round(gonogo_rarefrequentStat$conf.int[1], 3), ", ", 
    round(gonogo_rarefrequentStat$conf.int[2], 3), "]\n",
    "Effect size (Cohen's d):", 
    round(gonogo_rarefrequentStat$estimate / sd(differences), 3), "\n",
    sep = "")
