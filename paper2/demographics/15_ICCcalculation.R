# Intra-Class Correlation Calculation
# After the dissertation defense, we received valuable feedback that all 
# psychological questionnaires should report consistency of ratings using 
# intra-class correlation (ICC). 
#
# The following script will load tidy datasets from both sessions and calculate
# ICC for the following sessions/metrics:
#
# SESSION 1:
#  - ASRS
#  - BDI
#  - BAI
#  - ASSET
#
# SESSION 2:
#  - BDI
#  - BAI
#  - ASSET
#
# Written by Noor Tasnim on December 12, 2025

# Import Data and Libraries -----------------------------------------------
library(tidyverse)
library(psych)

# Set switch
use_pruned <- TRUE  # Set to FALSE to use full baseline (n=67)

baseline <- read_csv('data/tidy/demographics_baseline_mental_health.csv')
intervention <- read_csv('data/tidy/intervention_mental_health.csv')

# Apply filter conditionally
if (use_pruned) {
  baseline <- baseline %>%
    filter(!participant_id %in% c(77, 152, 160, 175))
}

# Subset Dataframes -------------------------------------------------------
#### Baseline ####
asrs <- baseline %>%
  select(asrs_1:asrs_18)
bdi_baseline <- baseline %>%
  select(sadness_bdi:worry_health_bdi)
bai_baseline <- baseline %>%
  select(bai_1:bai_21)
asset_baseline <- baseline %>%
  select(asset_attn:asset_mood)

#### Intervention ####
bdi_intervention <- intervention %>%
  select(sadness_bdi:worry_health_bdi)
bai_intervention <- intervention %>%
  select(bai_1:bai_21)
asset_intervention <- intervention %>%
  select(asset_attn:asset_mood)


# Calculate ICC -----------------------------------------------------------

#### Baseline ICCs ####
asrs_ICC <- ICC(asrs)
bdi_baseline_ICC <- ICC(bdi_baseline)
bai_baseline_ICC <- ICC(bai_baseline)
asset_baseline_ICC <- ICC(asset_baseline)

#### Intervention ICCs ####
bdi_intervention_ICC <- ICC(bdi_intervention)
bai_intervention_ICC <- ICC(bai_intervention)
asset_intervention_ICC <- ICC(asset_intervention)

# Print ICC Results -------------------------------------------------------

cat("=== BASELINE ICCs ===\n")
print(list(ASRS = asrs_ICC, BDI = bdi_baseline_ICC, 
           BAI = bai_baseline_ICC, ASSET = asset_baseline_ICC))

cat("\n=== INTERVENTION ICCs ===\n")
print(list(BDI = bdi_intervention_ICC, BAI = bai_intervention_ICC, 
           ASSET = asset_intervention_ICC))