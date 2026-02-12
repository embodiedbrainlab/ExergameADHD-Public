# Calculate Age
# Take shifted dates from survey completion dates and dob to calculate age.
# Some datapoints are missing and will need to be filled manually.

# Import Libraries --------------------------------------------------------
library(tidyverse)

# Read Data ---------------------------------------------------------------
age <- read_csv('data/age.csv')

# List of Participants to Keep --------------------------------------------
## The following participants will be excluded: exgm007, exgm024
participants_to_keep <- c(2,3,4,5,10,12,16,18,19,20,21,23,25,31,43,46,47,48,50,
                          51,57,78,79,81,82,84,87,90,97,102,105,107,108,109,
                          111,116,117,119,120,121,122,132,133,136,144,145,146,149,
                          154,156,162,164,169,171,172,179,181,182,184,185,188,190,
                          193) 

# Filter the dataframe to keep only rows with participant IDs in the list
age_filtered <- age %>%
  filter(participant_id %in% participants_to_keep)

# Extract Baseline Dates -----------------------------

baseline_dates <- age_filtered %>%
  filter(redcap_event_name == "baseline_visit_arm_1") %>%
  select(-redcap_event_name)

# Calculate Age --------------------------------------

age_calculation <- baseline_dates %>%
  mutate(
    intake = mdy_hm(demographics_questionnaire_timestamp),
    dob_shift = mdy(dob),
    age = interval(dob_shift, intake) %/% months(1) %/% 12
  ) %>%
  select(-demographics_questionnaire_timestamp,-dob,-intake,-dob_shift)

# Export Ages -------------------------------------------------------------

write_csv(age_calculation,'data/calculated_ages.csv')
