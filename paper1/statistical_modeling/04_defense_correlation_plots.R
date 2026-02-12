# CREATING CORRELATION PLOTS FOR DEFENSE
# Some of the alpha power metrics were signficant predictors of ASRS, however, 
# we never ran a simple pearson's correlation between these values and the 18-item
# ASRS scores.
#
# This script will pull values the final dataframe used for statistical modeling
# because that dataframe will have already provided appropriate 0/NaN values for
# participants who were modeled or omitted from the specific clusters of interest.
#
# During the defense, we only highlighted activity from the Right Paracentral
# Lobule, which is Component 12.
#
# We also wanted to highlight correlations from the FC matrices. The only 2 that
# were relevant for our final model were DMN - digitforward and DAN - stroop.
#
# Written by Noor Tasnim on December 3, 2025

# Load Libraries and Data -------------------------------------------------
library(tidyverse)
source("../demographicsPsych/00_plottingFunctions.R") #plotting function

# load dataframe used for modeling
exergame <- readRDS('results/exergame_forFinalModel.rds') %>%
  mutate(asrs_6_total_category = factor(asrs_6_total_category,
                                        levels = c("low_negative","high_negative","high_positive","low_positive"),
                                        labels = c("Low Negative","High Negative","High Positive","Low Positive")),
         sex = case_when(
           sex == "female" ~ "Female",
           sex == "male" ~ "Male"))


# Extract Relevant Datasets -----------------------------------------------
# gonogo alpha data
gonogo <- exergame %>%
  select(participant_id, asrs_18_total, asrs_6_total_category, sex, cluster12_gonogo_alpha)

# tandem alpha data
tandem <- exergame %>%
  select(participant_id, asrs_18_total, asrs_6_total_category, sex, cluster12_tandem_1_alpha)

# DMN - digit forward
dmn_digitforward <- exergame %>%
  select(participant_id, asrs_18_total, asrs_6_total_category, sex, DMN_digitforward_alpha)

# DAN - stroop
dan_stroop <- exergame %>%
  select(participant_id, asrs_18_total, asrs_6_total_category, sex, DAN_stroop_alpha)

# Pull Relevant Data ------------------------------------------------------

plot_gonogo <- exergame_corrPlot(
  data = gonogo,
  x_var = "cluster12_gonogo_alpha",
  x_label = "Right Paracentral Lobule Alpha Power - Go/No-Go"
)

plot_tandem <- exergame_corrPlot(
  data = tandem,
  x_var = "cluster12_tandem_1_alpha",
  x_label = "Right Paracentral Lobule Alpha Power - Tandem Stance"
)

plot_dmn_digitforward <- exergame_corrPlot(
  data = dmn_digitforward,
  x_var = "DMN_digitforward_alpha",
  x_label = "DMN Connectivity (MIM) - Digit Forward"
)

plot_dan_stroop <- exergame_corrPlot(
  data = dan_stroop,
  x_var = "DAN_stroop_alpha",
  x_label = "DAN Connectivitty (DAN) - Stroop"
)


# Save Plots --------------------------------------------------------------
# SVG Version
ggsave("defensePlots/gonogo_corr.svg", plot_gonogo, width = 10, height = 8)
ggsave("defensePlots/tandem_corr.svg", plot_tandem, width = 10, height = 8)
ggsave("defensePlots/dmn_digitForward_corr.svg", plot_dmn_digitforward, width = 10, height = 8)
ggsave("defensePlots/dan_stroop_corr.svg", plot_dan_stroop, width = 10, height = 8)

