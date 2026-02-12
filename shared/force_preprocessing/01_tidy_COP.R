# TIDY CENTER OF PRESSURE OUTPUTS
# Once the python scripts are used to process all .csv files from our force plate,
# we can integrate it with existing data on ADHD medication type and intervention
# assignments.

# Import Libraries --------------------------------------------------------
library(tidyverse)
library(readxl)

# Import Data -------------------------------------------------------------
force <- read_csv('data/force_long_09202025.csv') %>%
  rename(participant_id = subject_id) %>%
  filter(session == 'baseline') # we'll work with baseline first, then look at intervention data
exergame <- read_csv('../demographicsPsych/data/tidy/exergame_DemoBaselineMH_tidy_TOTALS.csv') %>%
  select(participant_id,adhd_med_type, sex, antidepressant, ethnicity, adhd_type, bmi:lower_injury)
#intervention_assignments <- read_excel('../demographicsPsych/data/intervention_assignments.xlsx') %>%
#  select(-id)

# Transform subject IDs from force to numeric
force$participant_id <- as.numeric(gsub("exgm", "", force$participant_id))

# Join all datasets -------------------------------------------------------

cop <- exergame %>%
  #left_join(intervention_assignments, by = "participant_id") %>%
  left_join(force, by = "participant_id")

# Edit Joined Dataset -----------------------------------------------------
cop<- cop %>%
  
  # Create Stimulant Variable
  mutate(stimulant = case_when(
    adhd_med_type %in% c('amphetamine', 'methylphenidate') ~ 'yes',
    adhd_med_type %in% c('none', 'other') ~ 'no',
    TRUE ~ NA_character_  # handles any other values as NA
  )) %>%
  
  # Change Values for some `combo` participants who were taking stimulants
  mutate(stimulant = case_when(
    participant_id %in% c(51, 164, 182) ~ "yes", # changing value to yes
    TRUE ~ stimulant  # keep all other values the same
  )) %>%
  
  # Shift stimulant column to earlier in the dataframe
  relocate(stimulant, .after = adhd_med_type) #%>%
  
  # Change Intervention Labels
  # mutate(intervention = case_when(
  #   intervention == "A" ~ "dance",
  #   intervention == "B" ~ "bike",
  #   intervention == "C" ~ "listen",
  #   TRUE ~ intervention  # keeps any other values unchanged
  # ))

# Filter Out Participants with Lower Limb Injuries ------------------------

# Find Participants with a lower-limb injury
injured_participants <- cop %>%
  filter(lower_injury == 'yes')

# Export Exlcuded participants as .csv file
write_csv(injured_participants,'results/injured_participants.csv')

# Remove Injured Participants
cop_filt <- cop %>%
  filter(lower_injury == 'no')

# Export Tidy Dataset -----------------------------------------------------
write_csv(cop_filt,'data/cop_tidy.csv')


