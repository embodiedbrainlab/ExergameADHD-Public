# Plotting Extended Properties for Components of Interest
# Initial observations of correlations with ASRS-18 and the XGBoost model showed
# that a few of our measured components have predictive value for ASRS.
#
# Thus, we are creating comprehensive plots that consist of each ASRS-6 category's
# ERP difference wave and scalp maps. But this script is meant to create .svg
# figures of interest so that all figures can be compiled on Illustrator for
# production.
# 
# COMPONENTS OF INTEREST:
# N2 - Nogo minus go related difference wave - gonogo
#   - Correlate with go RT on vertical cue
# P3b - congruent - control difference wave - stroop
#   - Correlate with RT difference (congruent - control)
# P3b - Incongruent minus Control - stroop
#   - Correlate with RT difference (incongruent - control)
# Error-Related Negativity - wcst
#   - Correlate with Perseverative Errors
# Feedback-Related Negativity - wcst
#   - Correlate with Perseverative Errors
#
# Written by Noor Tasnim on October 26, 2025

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

# Clean Dataframe for Plotting/Analysis -----------------------------------

erp_df <- exergame %>%
  select(asrs_18_total,asrs_6_total_category,sex,
         (gonogo_meanrt_verticalcue_gotarget:wcst_percent_p_errors),
         (stroop_meanRTcorr_congruent:stroop_meanRTcorr_incongruent),
         (Fz_N2_FracAreaLat_nogo_go_related:Pz_P3b_OnsetLat_congruent_control))
         # (Fz_N2_FracAreaLat_nogo_go_related:Fz_N2_OnsetLat_nogo_go_related),
         # (ERN_FracAreaLat:FRN_OnsetLat),
         # (Pz_P3b_FracAreaLat_incongruent_control:Pz_P3b_OnsetLat_congruent_control))

# Plot Correlations with ASRS v1.1 18-item -----------------------------------
# Plotting as .svg images
col_start <- which(names(erp_df) == "Fz_N2_FracAreaLat_nogo_go_related")
col_end <- which(names(erp_df) == "Pz_P3b_OnsetLat_congruent_control")
vars_to_plot <- names(erp_df)[col_start:col_end]

# Generate and save all plots
walk(vars_to_plot, function(var) {
  plot <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var)
  ggsave(paste0("results/ERPandASRS/svgForFigures/ASRScorr/", var, ".svg"),
         plot, width = 10, height = 8)
  cat("Saved:", var, "\n")
})


# Special Correlations with EF --------------------------------------------

#### Go/No-Go with Vertical Response Time ####
vert_col_start <- which(names(erp_df) == "Fz_N2_FracAreaLat_nogo_go_related")
vert_col_end <- which(names(erp_df) == "Pz_P3b_OnsetLat_go_nogo_related")
vert_vars_to_plot <- names(erp_df)[vert_col_start:vert_col_end]

walk(vert_vars_to_plot, function(var) {
  vert_RT <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var,
                             y_var = "gonogo_meanrt_verticalcue_gotarget",
                             y_label = "Vertical Cue with Go Target RT (ms)")
  ggsave(paste0("results/ERPandASRS/svgForFigures/EFcorr/gonogo/", var, ".svg"),
         vert_RT, width = 10, height = 8)
  cat("Saved:", var, "\n")
})

#### Go/No-Go with Horizontal Response Time ####
horizgo_indices <- grep("_go_unrelated_", names(erp_df))
horizgo_vars_to_plot <- names(erp_df)[horizgo_indices]

walk(horizgo_vars_to_plot, function(var) {
  horiz_RT <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var,
                               y_var = "gonogo_meanrt_horizontalcue_gotarget",
                               y_label = "Horizical Cue with Go Target RT (ms)")
  ggsave(paste0("results/ERPandASRS/svgForFigures/EFcorr/gonogo/", var, "_HorizGO.svg"),
         horiz_RT, width = 10, height = 8)
  cat("Saved:", var, "\n")
})


#### ERN/FRN with Perseverative Errors ####
WCST_col_start <- which(names(erp_df) == "ERN_FracAreaLat")
WCST_col_end <- which(names(erp_df) == "FRN_OnsetLat")
WCST_vars_to_plot <- names(erp_df)[WCST_col_start:WCST_col_end]

walk(WCST_vars_to_plot, function(var) {
  WCST_RT <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var,
                             y_var = "wcst_percent_p_errors",
                             y_label = "Percent Perseverative Errors")
  ggsave(paste0("results/ERPandASRS/svgForFigures/EFcorr/wcst/", var, ".svg"),
         WCST_RT, width = 10, height = 8)
  cat("Saved:", var, "\n")
})

#### Stroop Components with Response Times ####

##### Congruent Minus Control #####
congruent_indices <- grep("_congruent_", names(erp_df))
congruent_vars_to_plot <- names(erp_df)[congruent_indices]

walk(congruent_vars_to_plot, function(var) {
  ERN_RT <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var,
                              y_var = "stroop_meanRTcorr_congruent",
                              y_label = "Mean Congruent Trial Response Time (ms)")
  ggsave(paste0("results/ERPandASRS/svgForFigures/EFcorr/stroop/", var, ".svg"),
         ERN_RT, width = 10, height = 8)
  cat("Saved:", var, "\n")
})

##### Incongruent Minus Control #####
incongruent_indices <- grep("_incongruent_", names(erp_df))
incongruent_vars_to_plot <- names(erp_df)[incongruent_indices]

walk(incongruent_vars_to_plot, function(var) {
  ERN_RT <- exergame_corrPlot(data = erp_df, x_var = var, x_label = var,
                              y_var = "stroop_meanRTcorr_incongruent",
                              y_label = "Mean Incongruent Trial Response Time (ms)")
  ggsave(paste0("results/ERPandASRS/svgForFigures/EFcorr/stroop/", var, ".svg"),
         ERN_RT, width = 10, height = 8)
  cat("Saved:", var, "\n")
})





