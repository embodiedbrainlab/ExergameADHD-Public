# Tidy REDCap Export
# The initial export from REDCap contains rows of data from participants who
# completed the screening questionnaire, but did not officially participate in
# the study. This code keeps the rows of data from participants who fully
# participated in both session of the study.

# Import Libraries --------------------------------------------------------
library(tidyverse)
library(ggplot2)
library(readxl)

# Read Data ---------------------------------------------------------------
exergame <- read_csv('data/ExergameAndADHDVTIRB_DATA_2025-06-18_1300.csv')

# List of Participants to Keep --------------------------------------------
## The following participants will be excluded: exgm007, exgm024
participants_to_keep <- c(2,3,4,5,10,12,16,18,19,20,21,23,25,31,43,46,47,48,50,
                          51,57,78,79,81,82,84,87,90,97,102,105,107,108,109,
                          111,116,117,119,120,121,122,132,133,136,144,145,146,149,
                          154,156,162,164,169,171,172,179,181,182,184,185,188,190,
                          193) 

# Filter the dataframe to keep only rows with participant IDs in the list
exergame_filtered <- exergame %>%
  filter(participant_id %in% participants_to_keep)

# Extract Demographics and Mental Health Questionnaire --------------------------------------

demographics_mh <- exergame_filtered %>%
  filter(redcap_event_name == "baseline_visit_arm_1" |redcap_event_name == "intervention_visit_arm_1" ) %>%
  select(where(~ !all(is.na(.)))) %>% # remove columns from screening questionnaire
  select(participant_id,redcap_event_name,mental_health_questionnaire_timestamp) %>%
  rename(session = redcap_event_name, timestamp = mental_health_questionnaire_timestamp) %>%
  pivot_wider(
    names_from = session,
    values_from = timestamp)


# Convert columns to date/time --------------------------------------------

demographics_mh <- demographics_mh %>%
  mutate(
    elapsed_time = as.numeric(difftime(as.Date(intervention_visit_arm_1),
                                       as.Date(baseline_visit_arm_1),
                                       units = "days")),
    time_diff_minutes = abs(as.numeric(difftime(
      as.POSIXct(format(intervention_visit_arm_1, "%H:%M:%S"), format = "%H:%M:%S"),
      as.POSIXct(format(baseline_visit_arm_1, "%H:%M:%S"), format = "%H:%M:%S"),
      units = "mins"
    )))
  )


# Summarizing Elapsed Time ------------------------------------------------

# Summarize All Values
durations <- demographics_mh %>%
  summarise(
    total_values = n(),
    mean_elapsed_time = mean(elapsed_time, na.rm = TRUE),
    median_elapsed_time = median(elapsed_time, na.rm = TRUE),
    sd_elapsed_time = sd(elapsed_time, na.rm = TRUE)
  )

# Identify Significant Outliers
duration_outliers <- demographics_mh %>%
  filter(abs(elapsed_time - mean(elapsed_time, na.rm = TRUE)) > 3 * sd(elapsed_time, na.rm = TRUE))

# Show Distribution of Elapsed Time
ggplot(demographics_mh,aes(x=elapsed_time)) + 
  geom_histogram(binwidth = 1)

# Create clean timespan dataframe
timespan <- demographics_mh %>%
  select(participant_id,elapsed_time, time_diff_minutes)

# Calculate Timespans Across Interventions --------------------------------
intervention_assignments <- read_excel("data/intervention_assignments.xlsx") %>%
  select(-id) %>%
  mutate(intervention = case_when(
    intervention == "A" ~ "dance",
    intervention == "B" ~ "bike",
    intervention == "C" ~ "listen",
    TRUE ~ intervention  # keeps any other values unchanged
  ))

# Join interventions with time data

timespan_intervention <- timespan %>%
  left_join(intervention_assignments, by = "participant_id")


# Summarize Data ----------------------------------------------------------

summary_stats <- timespan_intervention %>%
  group_by(intervention) %>%
  summarise(
    n = n(),
    elapsed_time_mean = mean(elapsed_time, na.rm = TRUE),
    elapsed_time_sd = sd(elapsed_time, na.rm = TRUE),
    time_diff_minutes_mean = mean(time_diff_minutes, na.rm = TRUE),
    time_diff_minutes_sd = sd(time_diff_minutes, na.rm = TRUE)
  )


# Total Dataset Summary ---------------------------------------------------

elapsed_time_mean <- mean(timespan$elapsed_time)
elapsed_time_sd = sd(timespan$elapsed_time)
time_diff_minutes_mean <- mean(timespan$time_diff_minutes)
time_diff_minutes_sd <- sd(timespan$time_diff_minutes)


# Export Timeframe Information with Sessions ------------------------------

write_csv(timespan_intervention,'results/time_between_sessions.csv')
