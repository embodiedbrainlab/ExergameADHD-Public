# DEMOGRAPHICS TABLES
# Summarizing Demographics data for Papers 1 and 2.
# The Baseline Demographics Section creates the demographics table for Paper 1
# (n=67) and groups results by the asrs_6_total_category.
# 
# Because the Baseline Demographics Table is dependent upon asrs_6_total_category,
# this table can only be created once you run 02_baseline_mental_health_IMPROVED.
#
# ---
# EDIT ON NOV. 3, 2025: Removed calculation of intervention demographics. They
# are now performed in 11_demographics.r

# Load Libraries
library(tidyverse)
library(readxl)

# Baseline Demographics ------------------------------------------------------------

# Load dataset
exergame <- read_csv("data/tidy/exergame_DemoBaselineMH_TOTALS.csv")

# Calculate Summary Statistics
baseline_demographics <- exergame %>%
  group_by(asrs_6_total_category) %>%
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
                      round(mean(ethnicity == "hispanic_latino", na.rm = TRUE) * 100, 1), "%)"),
    nonhispanic = paste0(sum(ethnicity == "not_hispanic_latino", na.rm = TRUE), " (", 
                         round(mean(ethnicity == "not_hispanic_latino", na.rm = TRUE) * 100, 1), "%)"),
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
write_csv(baseline_demographics,'results/demographics/baseline_demographics.csv')


# Baseline Age and BMI -------------------------------------------------------------
baseline_age_bmi <- exergame %>%
  summarise(
    mean_age = round(mean(age, na.rm = TRUE), 1),
    sd_age = round(sd(age, na.rm = TRUE), 1),
    mean_bmi = round(mean(bmi, na.rm = TRUE), 1),
    sd_bmi = round(sd(bmi, na.rm = TRUE), 1)
  )
write_csv(baseline_age_bmi,'results/demographics/baseline_ageBMIsummary.csv')

