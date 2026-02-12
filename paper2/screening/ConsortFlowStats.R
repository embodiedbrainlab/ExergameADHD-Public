# CALCULATE SAMPLE SIZES FOR CONSORT DIAGRAM
# To properly adhere to clinical trial standards, it is important to fully report
# participants screened for eligibility and randomized to your respective
# interventions.
#
# Note about duplicate participants:
# After checking REDCap, there are two pairs of duplicates (neither participated
# in the study):
#   - Participants 99 and 155
#   - Participants 200 and 205
#
# Note that data collection was complete after participant 197.
#
# Written by Noor Tasnim on November 11, 2025
# ---
# Edited on 11/13/2025 to account for duplicates and participants after power 
# was achieved

# Import Libraries and Data -----------------------------------------------
library(tidyverse)
screener_raw <- read_csv("~/Google Drive/Shared drives/Embodied Brain Lab/Exergame and ADHD (IRB 23-811)/! Screening/ExergameAndADHDVTIRB_DATA_2025-11-11_1620.csv") %>%
  filter(screening_questionnaire_complete == 2) %>%
  filter(consent == 1) %>%
  filter(!(participant_id %in% c(155, 205))) %>% # Remove duplicate participants
  mutate(neuro_exclude = if_else(
    other_neuro_conditions___1 == 1 | 
      other_neuro_conditions___2 == 1 | 
      other_neuro_conditions___3 == 1,
    1,
    0
  ))


# Filter out 5 participants who completed after power was achieved -------------------------------------------
# Power was achieved around the time exgm197 signed up for our study
screener <- screener_raw %>%
  filter(participant_id < 200)

# List of Participants to Keep --------------------------------------------
## This list includes all 69 participants 
## The following participants were excluded for overall analysis: 7,24
## 77,152,160,175 were included for baseline analysis, but later dropped 
## because of a lapse in time between sessions 1 and 2

participants_to_keep <- c(2,3,4,5,7,10,12,16,18,19,20,21,23,24,25,31,43,46,47,48,50,
                          51,57,77,78,79,81,82,84,87,90,97,102,105,107,108,109,
                          111,116,117,119,120,121,122,132,133,136,144,145,146,149,
                          152,154,156,160,162,164,169,171,172,175,179,181,182,184,
                          185,188,190,193)

# Segment Screener --------------------------------------------------------
# We'll create two dataframes:

# 1. Participants from whom we collected data
screener_kept <- screener %>%
  filter(participant_id %in% participants_to_keep)

# 2. Participants who were not included in our study/randomized
screener_excluded <- screener %>%
  filter(!participant_id %in% participants_to_keep)

# Reasons for exclusion ---------------------------------------------------
adhdOnly <- screener_excluded %>%
  filter(adhd == 1)

ageRange <- adhdOnly %>%
  filter(age <= 24)

noNeuroDisorders <- ageRange %>%
  filter(neuro_exclude == 0)

ADHDexclude_n <- nrow(screener_excluded) - nrow(adhdOnly)
ageExclude_n <- nrow(adhdOnly) - nrow(ageRange)
neuroExclude_n <- nrow(ageRange) - nrow(noNeuroDisorders)

unaccounted <- nrow(screener_excluded) - (ADHDexclude_n + ageExclude_n + neuroExclude_n)

# Number of No Responses --------------------------------------------------

screener_excluded <- screener_excluded %>%
  mutate(
    exclusion_adhd = if_else(adhd == 0, 1, 0),
    exclusion_age = if_else(age > 24, 1, 0),
    exclusion_count = exclusion_adhd + exclusion_age + neuro_exclude
  )

didNotRespond <- sum(screener_excluded$exclusion_count == 0)
totalExcluded <- sum(screener_excluded$exclusion_count > 0)

# Check to see if All Excluded Participants Accounted For -----------------
matchingMissing <- unaccounted == didNotRespond


