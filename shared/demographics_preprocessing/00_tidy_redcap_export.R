# Tidy REDCap Export
# The initial export from REDCap contains rows of data from participants who
# completed the screening questionnaire, but did not officially participate in
# the study. This code keeps the rows of data from participants who fully
# participated in both session of the study.

# Import Libraries --------------------------------------------------------
library(tidyverse)

# Read Data ---------------------------------------------------------------
exergame <- read_csv('data/ExergameAndADHDVTIRB_DATA_2025-06-18_1300.csv')

# List of Participants to Keep --------------------------------------------
## The following participants will be excluded: 7,24
## Note that 77,152,160,175 will only be included for baseline analysis

participants_to_keep <- c(2,3,4,5,10,12,16,18,19,20,21,23,25,31,43,46,47,48,50,
                          51,57,77,78,79,81,82,84,87,90,97,102,105,107,108,109,
                          111,116,117,119,120,121,122,132,133,136,144,145,146,149,
                          152,154,156,160,162,164,169,171,172,175,179,181,182,184,
                          185,188,190,193)

# Filter the dataframe to keep only rows with participant IDs in the list
exergame_filtered <- exergame %>%
  filter(participant_id %in% participants_to_keep)

# Extract Screening Questionnaire -----------------------------

screening <- exergame_filtered %>%
  filter(redcap_event_name == "initial_data_arm_1") %>%
  select(-redcap_event_name,-screening_questionnaire_timestamp) %>% #remove REDCap metadata
  select(where(~ !all(is.na(.)))) # remove columns associated with demographics

write_csv(screening,"data/tidy/screening.csv")

# Extract Demographics and Mental Health Questionnaire --------------------------------------

demographics_mh <- exergame_filtered %>%
  filter(redcap_event_name == "baseline_visit_arm_1") %>%
  select(where(~ !all(is.na(.)))) %>% # remove columns from screening questionnaire
  select(-redcap_event_name,-demographics_questionnaire_timestamp,
         -mental_health_questionnaire_timestamp)

write_csv(demographics_mh,"data/tidy/demographics_baseline_mental_health.csv")

# Join Screening and Demographics -----------------------------------------

compiled_data <- left_join(screening,demographics_mh,by = "participant_id")

write_csv(compiled_data,"data/tidy/screening_demographics_baseline_mental_health.csv")

# Extract Intervention Session Mental Health Questionnaire ----------------

## Remove participants who were drop outs (77,152,160,175)
dropouts <- c(77,152,160,175)

intervention_mh <- exergame_filtered %>%
  filter(redcap_event_name == "intervention_visit_arm_1") %>%
  select(where(~ !all(is.na(.)))) %>% # remove columns from screening questionnaire
  select(-redcap_event_name,-mental_health_questionnaire_timestamp) %>%
  filter(!participant_id %in% dropouts)

write_csv(intervention_mh,"data/tidy/intervention_mental_health.csv")

