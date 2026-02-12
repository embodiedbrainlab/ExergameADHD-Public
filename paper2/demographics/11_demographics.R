# Create Demographics Table for Exergame Paper 2 - Effects of Intervention

# Import Libraries and Datasets -------------------------------------------
library(tidyverse)
library(readxl)

baseline_mh <- read_csv("data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  filter(!participant_id %in% c(77, 152, 160, 175))# exclude dropouts

intervention_assignments <- read_excel("data/intervention_assignments.xlsx") %>%
  select(-id) %>%
  mutate(intervention = case_when(
    intervention == "A" ~ "dance",
    intervention == "B" ~ "bike",
    intervention == "C" ~ "listen",
    TRUE ~ intervention  # keeps any other values unchanged
  ))

# Select Demographic Variables --------------------------------------------

demographics <- baseline_mh %>%
  select(participant_id,asrs_18_total,asrs_6_total,asrs_6_total_category,
         adhd_type,adhd_med_type,stimulant,antidepressant,antidepressant_type,age,
         sex,race,ethnicity,bmi,education,income,(depression_dsm:substance_use_dsm),
         vig_activity_days,mod_activity_days,walk_days,sit_hours)

# Merge Data Frames --------------------------------------------------------

intervention_demographics <- demographics %>%
  left_join(intervention_assignments, by = "participant_id") %>%
  relocate(intervention, .before = asrs_18_total)

# Calculate Summary Statistics by Intervention --------------------------------------------

intervention_demographics_report <- intervention_demographics %>%
  group_by(intervention) %>%
  summarise(
    #### Sample Size ####
    n = n(),
    
    #### ADHD Subtype (1 = hyperactive/impulsive, 2 = inattentive, 3 = combined) ####
    hyperactive = paste0(sum(adhd_type == 1, na.rm = TRUE), " (", 
                         round(mean(adhd_type == 1, na.rm = TRUE) * 100, 1), "%)"),
    inattentive = paste0(sum(adhd_type == 2, na.rm = TRUE), " (", 
                         round(mean(adhd_type == 2, na.rm = TRUE) * 100, 1), "%)"),
    combined = paste0(sum(adhd_type == 3, na.rm = TRUE), " (", 
                      round(mean(adhd_type == 3, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Age statistics ####
    age = paste0(round(mean(age, na.rm = TRUE), 2), " (", 
                 round(sd(age, na.rm = TRUE), 2), ")"),
    
    #### Sex distribution (1 = Female, 2 = Male) ####
    female = paste0(sum(sex == 1, na.rm = TRUE), " (", 
                    round(mean(sex == 1, na.rm = TRUE) * 100, 1), "%)"),
    male = paste0(sum(sex == 2, na.rm = TRUE), " (", 
                  round(mean(sex == 2, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Race distribution ####
    white = paste0(sum(race == "white", na.rm = TRUE), " (", 
                   round(mean(race == "white", na.rm = TRUE) * 100, 1), "%)"),
    black = paste0(sum(race == "black_african_american", na.rm = TRUE), " (", 
                   round(mean(race == "black_african_american", na.rm = TRUE) * 100, 1), "%)"),
    amerindian = paste0(sum(race == "american_indian_alaska_native", na.rm = TRUE), " (", 
                        round(mean(race == "american_indian_alaska_native", na.rm = TRUE) * 100, 1), "%)"),
    asian = paste0(sum(race == "asian", na.rm = TRUE), " (", 
                   round(mean(race == "asian", na.rm = TRUE) * 100, 1), "%)"),
    hawaiianPI = paste0(sum(race == "native_hawaiian_PI", na.rm = TRUE), " (", 
                        round(mean(race == "native_hawaiian_PI", na.rm = TRUE) * 100, 1), "%)"),
    other_race = paste0(sum(race == "other", na.rm = TRUE), " (", 
                        round(mean(race == "other", na.rm = TRUE) * 100, 1), "%)"),
    multiracial = paste0(sum(race == "multiracial", na.rm = TRUE), " (", 
                         round(mean(race == "multiracial", na.rm = TRUE) * 100, 1), "%)"),
    
    #### Ethnicity Distribution - DOUBLE CHECK PERCENTAGE!####
    hispanic = paste0(sum(ethnicity == "hispanic_latino", na.rm = TRUE), " (", 
                      round(sum(ethnicity == "hispanic_latino", na.rm = TRUE) / length(ethnicity) * 100, 1), "%)"),
    nonhispanic = paste0(sum(ethnicity == "not_hispanic_latino", na.rm = TRUE), " (", 
                         round(sum(ethnicity == "not_hispanic_latino", na.rm = TRUE) / length(ethnicity) * 100, 1), "%)"),
    ethnicity_unknown = paste0(sum(is.na(ethnicity)), " (", 
                               round(mean(is.na(ethnicity)) * 100, 1), "%)"),
    
    #### BMI Distribution ####
    bmi = paste0(round(mean(bmi, na.rm = TRUE), 2), " (", 
                 round(sd(bmi, na.rm = TRUE), 2), ")"),
    
    #### Education ####
    currently_hs = paste0(sum(education == 1, na.rm = TRUE), " (", 
                          round(mean(education == 1, na.rm = TRUE) * 100, 1), "%)"),
    no_hs_ged = paste0(sum(education == 2, na.rm = TRUE), " (", 
                       round(mean(education == 2, na.rm = TRUE) * 100, 1), "%)"),
    hs_ged = paste0(sum(education == 3, na.rm = TRUE), " (", 
                    round(mean(education == 3, na.rm = TRUE) * 100, 1), "%)"),
    some_college = paste0(sum(education == 4, na.rm = TRUE), " (", 
                          round(mean(education == 4, na.rm = TRUE) * 100, 1), "%)"),
    bachelors = paste0(sum(education == 5, na.rm = TRUE), " (", 
                       round(mean(education == 5, na.rm = TRUE) * 100, 1), "%)"),
    advanced = paste0(sum(education == 6, na.rm = TRUE), " (", 
                      round(mean(education == 6, na.rm = TRUE) * 100, 1), "%)"),
    dont_know_education = paste0(sum(education == 7, na.rm = TRUE), " (", 
                                 round(mean(education == 7, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Income distribution ####
    under_15k = paste0(sum(income == 1, na.rm = TRUE), " (", 
                       round(mean(income == 1, na.rm = TRUE) * 100, 1), "%)"),
    income_15k_24k = paste0(sum(income == 2, na.rm = TRUE), " (", 
                            round(mean(income == 2, na.rm = TRUE) * 100, 1), "%)"),
    income_25k_34k = paste0(sum(income == 3, na.rm = TRUE), " (", 
                            round(mean(income == 3, na.rm = TRUE) * 100, 1), "%)"),
    income_35k_49k = paste0(sum(income == 4, na.rm = TRUE), " (", 
                            round(mean(income == 4, na.rm = TRUE) * 100, 1), "%)"),
    income_50k_74k = paste0(sum(income == 5, na.rm = TRUE), " (", 
                            round(mean(income == 5, na.rm = TRUE) * 100, 1), "%)"),
    income_75k_99k = paste0(sum(income == 6, na.rm = TRUE), " (", 
                            round(mean(income == 6, na.rm = TRUE) * 100, 1), "%)"),
    income_100k_149k = paste0(sum(income == 7, na.rm = TRUE), " (", 
                              round(mean(income == 7, na.rm = TRUE) * 100, 1), "%)"),
    income_150k_199k = paste0(sum(income == 8, na.rm = TRUE), " (", 
                              round(mean(income == 8, na.rm = TRUE) * 100, 1), "%)"),
    income_200k_over = paste0(sum(income == 9, na.rm = TRUE), " (", 
                              round(mean(income == 9, na.rm = TRUE) * 100, 1), "%)"),
    income_unknown = paste0(sum(income == 10, na.rm = TRUE), " (", 
                            round(mean(income == 10, na.rm = TRUE) * 100, 1), "%)"),
    
    .groups = 'drop'
  )

#### Export results ####
write_csv(intervention_demographics_report,"results/demographics/Paper2/intervention_demographics.csv")


# Calculate Summary Statistic Totals --------------------------------------------

total_demographics_report <- intervention_demographics %>%
  summarise(
    #### Sample Size ####
    n = n(),
    
    #### ADHD Subtype (1 = hyperactive/impulsive, 2 = inattentive, 3 = combined) ####
    hyperactive = paste0(sum(adhd_type == 1, na.rm = TRUE), " (", 
                         round(mean(adhd_type == 1, na.rm = TRUE) * 100, 1), "%)"),
    inattentive = paste0(sum(adhd_type == 2, na.rm = TRUE), " (", 
                         round(mean(adhd_type == 2, na.rm = TRUE) * 100, 1), "%)"),
    combined = paste0(sum(adhd_type == 3, na.rm = TRUE), " (", 
                      round(mean(adhd_type == 3, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Age statistics ####
    age = paste0(round(mean(age, na.rm = TRUE), 2), " (", 
                 round(sd(age, na.rm = TRUE), 2), ")"),
    
    #### Sex distribution (1 = Female, 2 = Male) ####
    female = paste0(sum(sex == 1, na.rm = TRUE), " (", 
                    round(mean(sex == 1, na.rm = TRUE) * 100, 1), "%)"),
    male = paste0(sum(sex == 2, na.rm = TRUE), " (", 
                  round(mean(sex == 2, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Race distribution ####
    white = paste0(sum(race == "white", na.rm = TRUE), " (", 
                   round(mean(race == "white", na.rm = TRUE) * 100, 1), "%)"),
    black = paste0(sum(race == "black_african_american", na.rm = TRUE), " (", 
                   round(mean(race == "black_african_american", na.rm = TRUE) * 100, 1), "%)"),
    amerindian = paste0(sum(race == "american_indian_alaska_native", na.rm = TRUE), " (", 
                        round(mean(race == "american_indian_alaska_native", na.rm = TRUE) * 100, 1), "%)"),
    asian = paste0(sum(race == "asian", na.rm = TRUE), " (", 
                   round(mean(race == "asian", na.rm = TRUE) * 100, 1), "%)"),
    hawaiianPI = paste0(sum(race == "native_hawaiian_PI", na.rm = TRUE), " (", 
                        round(mean(race == "native_hawaiian_PI", na.rm = TRUE) * 100, 1), "%)"),
    other_race = paste0(sum(race == "other", na.rm = TRUE), " (", 
                        round(mean(race == "other", na.rm = TRUE) * 100, 1), "%)"),
    multiracial = paste0(sum(race == "multiracial", na.rm = TRUE), " (", 
                         round(mean(race == "multiracial", na.rm = TRUE) * 100, 1), "%)"),
    
    #### Ethnicity Distribution ####
    hispanic = paste0(sum(ethnicity == "hispanic_latino", na.rm = TRUE), " (", 
                      round(sum(ethnicity == "hispanic_latino", na.rm = TRUE) / length(ethnicity) * 100, 1), "%)"),
    nonhispanic = paste0(sum(ethnicity == "not_hispanic_latino", na.rm = TRUE), " (", 
                         round(sum(ethnicity == "not_hispanic_latino", na.rm = TRUE) / length(ethnicity) * 100, 1), "%)"),
    ethnicity_unknown = paste0(sum(is.na(ethnicity)), " (", 
                               round(mean(is.na(ethnicity)) * 100, 1), "%)"),
    
    #### BMI Distribution ####
    bmi = paste0(round(mean(bmi, na.rm = TRUE), 2), " (", 
                 round(sd(bmi, na.rm = TRUE), 2), ")"),
    
    #### Education ####
    currently_hs = paste0(sum(education == 1, na.rm = TRUE), " (", 
                          round(mean(education == 1, na.rm = TRUE) * 100, 1), "%)"),
    no_hs_ged = paste0(sum(education == 2, na.rm = TRUE), " (", 
                       round(mean(education == 2, na.rm = TRUE) * 100, 1), "%)"),
    hs_ged = paste0(sum(education == 3, na.rm = TRUE), " (", 
                    round(mean(education == 3, na.rm = TRUE) * 100, 1), "%)"),
    some_college = paste0(sum(education == 4, na.rm = TRUE), " (", 
                          round(mean(education == 4, na.rm = TRUE) * 100, 1), "%)"),
    bachelors = paste0(sum(education == 5, na.rm = TRUE), " (", 
                       round(mean(education == 5, na.rm = TRUE) * 100, 1), "%)"),
    advanced = paste0(sum(education == 6, na.rm = TRUE), " (", 
                      round(mean(education == 6, na.rm = TRUE) * 100, 1), "%)"),
    dont_know_education = paste0(sum(education == 7, na.rm = TRUE), " (", 
                                 round(mean(education == 7, na.rm = TRUE) * 100, 1), "%)"),
    
    #### Income distribution ####
    under_15k = paste0(sum(income == 1, na.rm = TRUE), " (", 
                       round(mean(income == 1, na.rm = TRUE) * 100, 1), "%)"),
    income_15k_24k = paste0(sum(income == 2, na.rm = TRUE), " (", 
                            round(mean(income == 2, na.rm = TRUE) * 100, 1), "%)"),
    income_25k_34k = paste0(sum(income == 3, na.rm = TRUE), " (", 
                            round(mean(income == 3, na.rm = TRUE) * 100, 1), "%)"),
    income_35k_49k = paste0(sum(income == 4, na.rm = TRUE), " (", 
                            round(mean(income == 4, na.rm = TRUE) * 100, 1), "%)"),
    income_50k_74k = paste0(sum(income == 5, na.rm = TRUE), " (", 
                            round(mean(income == 5, na.rm = TRUE) * 100, 1), "%)"),
    income_75k_99k = paste0(sum(income == 6, na.rm = TRUE), " (", 
                            round(mean(income == 6, na.rm = TRUE) * 100, 1), "%)"),
    income_100k_149k = paste0(sum(income == 7, na.rm = TRUE), " (", 
                              round(mean(income == 7, na.rm = TRUE) * 100, 1), "%)"),
    income_150k_199k = paste0(sum(income == 8, na.rm = TRUE), " (", 
                              round(mean(income == 8, na.rm = TRUE) * 100, 1), "%)"),
    income_200k_over = paste0(sum(income == 9, na.rm = TRUE), " (", 
                              round(mean(income == 9, na.rm = TRUE) * 100, 1), "%)"),
    income_unknown = paste0(sum(income == 10, na.rm = TRUE), " (", 
                            round(mean(income == 10, na.rm = TRUE) * 100, 1), "%)"),
    
    .groups = 'drop'
  )

#### Export results ####
write_csv(total_demographics_report,"results/demographics/Paper2/total_demographics.csv")


# Intervention Age and BMI -------------------------------------------------------------
intervention_age_bmi <- intervention_demographics %>%
  summarise(
    mean_age = round(mean(age, na.rm = TRUE), 1),
    sd_age = round(sd(age, na.rm = TRUE), 1),
    mean_bmi = round(mean(bmi, na.rm = TRUE), 1),
    sd_bmi = round(sd(bmi, na.rm = TRUE), 1)
  )
write_csv(intervention_age_bmi,"results/demographics/Paper2/intervention_ageBMIsummary.csv")

# Medication Use by Intervention DOUBLE CHECK PERCENTAGE! ----------------------------------------------------------------------
intervention_medications <- intervention_demographics %>%
  group_by(intervention) %>%
  summarise(
  amphetamine = paste0(sum(adhd_med_type=="amphetamine", na.rm = TRUE), " (", 
                        round(mean(adhd_med_type=="amphetamine", na.rm = TRUE) * 100, 1), "%)"),
  methylphenidate = paste0(sum(adhd_med_type=="methylphenidate", na.rm = TRUE), " (", 
                        round(mean(adhd_med_type=="methylphenidate", na.rm = TRUE) * 100, 1), "%)"),
  none = paste0(sum(adhd_med_type=="none", na.rm = TRUE), " (", 
                round(mean(adhd_med_type=="none", na.rm = TRUE) * 100, 1), "%)"),
  other = paste0(sum(adhd_med_type=="other", na.rm = TRUE), " (", 
                round(mean(adhd_med_type=="other", na.rm = TRUE) * 100, 1), "%)"),
  ssri = paste0(sum(antidepressant_type=="ssri", na.rm = TRUE), " (", 
                round(sum(antidepressant_type == "ssri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
  ndri = paste0(sum(antidepressant_type=="ndri", na.rm = TRUE), " (", 
                round(sum(antidepressant_type == "ndri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
  snri = paste0(sum(antidepressant_type=="snri", na.rm = TRUE), " (", 
                round(sum(antidepressant_type == "snri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
  )
write_csv(intervention_medications,"results/demographics/Paper2/intervention_medications_summary.csv")

# Medication Use Total ----------------------------------------------------------------------
total_medications <- intervention_demographics %>%
  summarise(
    amphetamine = paste0(sum(adhd_med_type=="amphetamine", na.rm = TRUE), " (", 
                         round(mean(adhd_med_type=="amphetamine", na.rm = TRUE) * 100, 1), "%)"),
    methylphenidate = paste0(sum(adhd_med_type=="methylphenidate", na.rm = TRUE), " (", 
                             round(mean(adhd_med_type=="methylphenidate", na.rm = TRUE) * 100, 1), "%)"),
    none = paste0(sum(adhd_med_type=="none", na.rm = TRUE), " (", 
                  round(mean(adhd_med_type=="none", na.rm = TRUE) * 100, 1), "%)"),
    other = paste0(sum(adhd_med_type=="other", na.rm = TRUE), " (", 
                   round(mean(adhd_med_type=="other", na.rm = TRUE) * 100, 1), "%)"),
    ssri = paste0(sum(antidepressant_type=="ssri", na.rm = TRUE), " (", 
                  round(sum(antidepressant_type == "ssri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
    ndri = paste0(sum(antidepressant_type=="ndri", na.rm = TRUE), " (", 
                  round(sum(antidepressant_type == "ndri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
    snri = paste0(sum(antidepressant_type=="snri", na.rm = TRUE), " (", 
                  round(sum(antidepressant_type == "snri", na.rm = TRUE) / length(antidepressant_type) * 100, 1), "%)"),
  )
write_csv(total_medications,"results/demographics/Paper2/total_medications_summary.csv")

# ASRS Scores by Intervention ------------------------------------------------------------------------
intervention_asrs <- intervention_demographics %>%
  group_by(intervention) %>%
  summarise(
    asrs_18 = paste0(round(mean(asrs_18_total, na.rm = TRUE), 2), " (", 
                 round(sd(asrs_18_total, na.rm = TRUE), 2), ")"),
    asrs_6 = paste0(round(mean(asrs_6_total, na.rm = TRUE), 2), " (", 
                 round(sd(asrs_6_total, na.rm = TRUE), 2), ")"),
    low_negative = paste0(sum(asrs_6_total_category=="low_negative", na.rm = TRUE), " (", 
                         round(mean(asrs_6_total_category=="low_negative", na.rm = TRUE) * 100, 1), "%)"),
    high_negative = paste0(sum(asrs_6_total_category=="high_negative", na.rm = TRUE), " (", 
                           round(mean(asrs_6_total_category=="high_negative", na.rm = TRUE) * 100, 1), "%)"),
    low_positive = paste0(sum(asrs_6_total_category=="low_positive", na.rm = TRUE), " (", 
                          round(mean(asrs_6_total_category=="low_positive", na.rm = TRUE) * 100, 1), "%)"),
    high_positive = paste0(sum(asrs_6_total_category=="high_positive", na.rm = TRUE), " (", 
                           round(mean(asrs_6_total_category=="high_positive", na.rm = TRUE) * 100, 1), "%)"),
  )

write_csv(intervention_asrs,"results/demographics/Paper2/intervention_asrs_summary.csv")

# ASRS Scores Total --------------------------------------------------------------------------------
total_asrs <- intervention_demographics %>%
  summarise(
    asrs_18 = paste0(round(mean(asrs_18_total, na.rm = TRUE), 2), " (", 
                             round(sd(asrs_18_total, na.rm = TRUE), 2), ")"),
    asrs_6 = paste0(round(mean(asrs_6_total, na.rm = TRUE), 2), " (", 
                            round(sd(asrs_6_total, na.rm = TRUE), 2), ")"),
    low_negative = paste0(sum(asrs_6_total_category=="low_negative", na.rm = TRUE), " (", 
                          round(mean(asrs_6_total_category=="low_negative", na.rm = TRUE) * 100, 1), "%)"),
    high_negative = paste0(sum(asrs_6_total_category=="high_negative", na.rm = TRUE), " (", 
                           round(mean(asrs_6_total_category=="high_negative", na.rm = TRUE) * 100, 1), "%)"),
    low_positive = paste0(sum(asrs_6_total_category=="low_positive", na.rm = TRUE), " (", 
                          round(mean(asrs_6_total_category=="low_positive", na.rm = TRUE) * 100, 1), "%)"),
    high_positive = paste0(sum(asrs_6_total_category=="high_positive", na.rm = TRUE), " (", 
                           round(mean(asrs_6_total_category=="high_positive", na.rm = TRUE) * 100, 1), "%)"),
  )

write_csv(total_asrs,"results/demographics/Paper2/total_asrs_summary.csv")

# DSM-5 TR Cross Cutting Totals -----------------------------------------------------------------------------
total_dsm5 <- intervention_demographics %>%
  summarise(
    depression_total = paste0(round(mean(depression_dsm, na.rm = TRUE), 2), " (", 
                     round(sd(depression_dsm, na.rm = TRUE), 2), ")"),
    anger_total = paste0(round(mean(anger_dsm, na.rm = TRUE), 2), " (", 
                    round(sd(anger_dsm, na.rm = TRUE), 2), ")"),
    mania_total = paste0(round(mean(mania_dsm, na.rm = TRUE), 2), " (", 
                     round(sd(mania_dsm, na.rm = TRUE), 2), ")"),
    anxiety_total = paste0(round(mean(anxiety_dsm, na.rm = TRUE), 2), " (", 
                         round(sd(anxiety_dsm, na.rm = TRUE), 2), ")"),
    somatic_symptoms_total = paste0(round(mean(somatic_symptoms_dsm, na.rm = TRUE), 2), " (", 
                    round(sd(somatic_symptoms_dsm, na.rm = TRUE), 2), ")"),
    suicidal_ideation_total = paste0(round(mean(suicidal_idea_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(suicidal_idea_dsm, na.rm = TRUE), 2), ")"),
    psychosis_total = paste0(round(mean(psychosis_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(psychosis_dsm, na.rm = TRUE), 2), ")"),
    sleep_problems_total = paste0(round(mean(sleep_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(sleep_dsm, na.rm = TRUE), 2), ")"),
    memory_total = paste0(round(mean(memory_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(memory_dsm, na.rm = TRUE), 2), ")"),
    repetitive_thoughts_and_behaviors_total = paste0(round(mean(repetitive_thoughts_behaviors_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(repetitive_thoughts_behaviors_dsm, na.rm = TRUE), 2), ")"),
    dissociation_total = paste0(round(mean(dissociation_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(dissociation_dsm, na.rm = TRUE), 2), ")"),
    personality_functioning_total = paste0(round(mean(personality_functioning_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(personality_functioning_dsm, na.rm = TRUE), 2), ")"),
    substance_use_total = paste0(round(mean(substance_use_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(substance_use_dsm, na.rm = TRUE), 2), ")"),
  )
write_csv(total_dsm5,"results/demographics/Paper2/total_dsm5_summary.csv")

# DSM-5 TR Cross Cutting by Intervention
intervention_dsm5 <- intervention_demographics %>%
  group_by(intervention) %>%
  summarise(
    depression = paste0(round(mean(depression_dsm, na.rm = TRUE), 2), " (", 
                        round(sd(depression_dsm, na.rm = TRUE), 2), ")"),
    anger = paste0(round(mean(anger_dsm, na.rm = TRUE), 2), " (", 
                   round(sd(anger_dsm, na.rm = TRUE), 2), ")"),
    mania = paste0(round(mean(mania_dsm, na.rm = TRUE), 2), " (", 
                   round(sd(mania_dsm, na.rm = TRUE), 2), ")"),
    anxiety = paste0(round(mean(anxiety_dsm, na.rm = TRUE), 2), " (", 
                         round(sd(anxiety_dsm, na.rm = TRUE), 2), ")"),
    somatic_symptoms = paste0(round(mean(somatic_symptoms_dsm, na.rm = TRUE), 2), " (", 
                              round(sd(somatic_symptoms_dsm, na.rm = TRUE), 2), ")"),
    suicidal_ideation = paste0(round(mean(suicidal_idea_dsm, na.rm = TRUE), 2), " (", 
                               round(sd(suicidal_idea_dsm, na.rm = TRUE), 2), ")"),
    psychosis = paste0(round(mean(psychosis_dsm, na.rm = TRUE), 2), " (", 
                       round(sd(psychosis_dsm, na.rm = TRUE), 2), ")"),
    sleep_problems = paste0(round(mean(sleep_dsm, na.rm = TRUE), 2), " (", 
                            round(sd(sleep_dsm, na.rm = TRUE), 2), ")"),
    memory = paste0(round(mean(memory_dsm, na.rm = TRUE), 2), " (", 
                    round(sd(memory_dsm, na.rm = TRUE), 2), ")"),
    repetitive_thoughts_and_behaviors = paste0(round(mean(repetitive_thoughts_behaviors_dsm, na.rm = TRUE), 2), " (", 
                                               round(sd(repetitive_thoughts_behaviors_dsm, na.rm = TRUE), 2), ")"),
    dissociation = paste0(round(mean(dissociation_dsm, na.rm = TRUE), 2), " (", 
                          round(sd(dissociation_dsm, na.rm = TRUE), 2), ")"),
    personality_functioning = paste0(round(mean(personality_functioning_dsm, na.rm = TRUE), 2), " (", 
                                     round(sd(personality_functioning_dsm, na.rm = TRUE), 2), ")"),
    substance_use = paste0(round(mean(substance_use_dsm, na.rm = TRUE), 2), " (", 
                           round(sd(substance_use_dsm, na.rm = TRUE), 2), ")"),
  )
write_csv(intervention_dsm5,"results/demographics/Paper2/intervention_dsm5_summary.csv")

# Total Physical Activity -------------------------------------------------------------------------------
total_physical_activity <- intervention_demographics %>%
  summarise(
    vigorous_activity_total = paste0(round(mean(vig_activity_days, na.rm = TRUE), 2), " (", 
                            round(sd(vig_activity_days, na.rm = TRUE), 2), ")"),
    moderate_activity_total = paste0(round(mean(mod_activity_days, na.rm = TRUE), 2), " (", 
                                     round(sd(mod_activity_days, na.rm = TRUE), 2), ")"),
    walking_total = paste0(round(mean(walk_days, na.rm = TRUE), 2), " (", 
                                     round(sd(walk_days, na.rm = TRUE), 2), ")"),
    sitting_total = paste0(round(mean(sit_hours, na.rm = TRUE), 2), " (", 
                                     round(sd(sit_hours, na.rm = TRUE), 2), ")"),
  )
write_csv(total_physical_activity,"results/demographics/Paper2/total_physical_activity_summary.csv")
    
# Physical Activity and BMI by Intervention ------------------------------------------------------------
intervention_physicalactivity_bmi <- intervention_demographics %>%
  group_by(intervention) %>%
  summarise(
    vigorous_activity = paste0(round(mean(vig_activity_days, na.rm = TRUE), 2), " (", 
                                     round(sd(vig_activity_days, na.rm = TRUE), 2), ")"),
    moderate_activity = paste0(round(mean(mod_activity_days, na.rm = TRUE), 2), " (", 
                                     round(sd(mod_activity_days, na.rm = TRUE), 2), ")"),
    walking = paste0(round(mean(walk_days, na.rm = TRUE), 2), " (", 
                           round(sd(walk_days, na.rm = TRUE), 2), ")"),
    sitting = paste0(round(mean(sit_hours, na.rm = TRUE), 2), " (", 
                           round(sd(sit_hours, na.rm = TRUE), 2), ")"),
    bmi = paste0(round(mean(bmi, na.rm = TRUE), 2), " (", 
                     round(sd(bmi, na.rm = TRUE), 2), ")"),
  )
write_csv(intervention_physicalactivity_bmi,"results/demographics/Paper2/intervention_physicalactivity_bmi_summary.csv")   
    
