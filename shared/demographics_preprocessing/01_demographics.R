# Describe Study Population
# The script below first joins data regarding participants' medication type and
# intervention assignments. It then gets a basic overview of participants'
# backgrounds

# Load Libraries ----------------------------------------------------------
library(tidyverse)
library(readxl)
library(ggplot2)

# Load Datasets -----------------------------------------------------------
# Tidy Screening and Baseline Session Survey Data
screen_demo <- read_csv("data/tidy/screening_demographics_baseline_mental_health.csv") %>%
  select(-age,-medications,-med_intake) # we are going to variables below
# Medication Spreadsheet
medications <- read_excel("data/participant_medication_types.xlsx",na = c("NA")) %>%
  mutate(antidepressant = as.logical(antidepressant)) %>% # transform data into logical values
  select(-med_intake,-notes) # remove additional notes
# Calculated ages
ages <- read_csv("data/calculated_ages.csv") %>%
  select(-entry) # remove additional notes

# Join the Datasets
exergame <- left_join(ages,medications,by="participant_id")
exergame <- left_join(exergame,screen_demo,by="participant_id")

# Changing and Creating Variables -----------------------------------------------
# Create "Other" Medication Type Group
exergame <- exergame %>%
  mutate(adhd_med_type = ifelse(adhd_med_type %in% c("alpha_agonist", "combo","nri"), "other", adhd_med_type))


# Add stimulant column ----------------------------------------------------

exergame <- exergame %>%
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
  relocate(stimulant, .after = adhd_med_type)

# Calculate BMI
exergame$bmi <- (exergame$weight / (exergame$height^2)) * 703

# Race/Ethnicity
## Creating Race Variable
exergame <- exergame %>%
  unite("racebinary", race___0:race___5, sep = '', remove = FALSE)

exergame$race <- ifelse(exergame$racebinary == "100000", "white",
                        ifelse(exergame$racebinary == "010000", "black_african_american",
                               ifelse(exergame$racebinary == "001000", "american_indian_alaska_native",
                                      ifelse(exergame$racebinary == "000100", "asian",
                                             ifelse(exergame$racebinary == "000010", "native_hawaiian_PI",
                                                    ifelse(exergame$racebinary == "000001", "other",
                                                           "multiracial"))))))

## Changing Ethnicity Variable to Categorical
exergame$ethnicity <- factor(exergame$ethnicity, levels = c(0, 1), labels = c("hispanic_latino", "not_hispanic_latino"))


# Create Summaries for Demographics Table ---------------------------------
demographics <- exergame %>%
  group_by(adhd_med_type) %>%
  summarise(
    # Sample Size
    n = n(),
    
    # ADHD Subtype (1 = hyperactive/impulsive, 2 = inattentive, 3 = combined)
    n_hyperactive = sum(adhd_type == 1, na.rm = TRUE),
    n_inattentive = sum(adhd_type == 2, na.rm = TRUE),
    n_combined = sum(adhd_type == 3, na.rm = TRUE),
    pct_hyperactive = round(mean(adhd_type == 1, na.rm = TRUE) * 100, 1),
    pct_inattentive = round(mean(adhd_type == 2, na.rm = TRUE) * 100, 1),
    pct_combined = round(mean(adhd_type == 3, na.rm = TRUE) * 100, 1), 
    
    # Age statistics
    mean_age = mean(age, na.rm = TRUE),
    sd_age = sd(age, na.rm = TRUE),
    
    # Sex distribution (1 = Female, 2 = Male)
    n_female = sum(sex == 1, na.rm = TRUE),
    n_male = sum(sex == 2, na.rm = TRUE),
    pct_female = round(mean(sex == 1, na.rm = TRUE) * 100, 1),
    pct_male = round(mean(sex == 2, na.rm = TRUE) * 100, 1),
    
    # Race distribution
    n_white = sum(race == "white", na.rm = TRUE),
    n_black = sum(race == "black_african_american", na.rm = TRUE),
    n_amerindian = sum(race == "american_indian_alaska_native", na.rm = TRUE),
    n_asian = sum(race == "asian", na.rm = TRUE),
    n_hawaiianPI = sum(race == "native_hawaiian_PI", na.rm = TRUE),
    n_other = sum(race == "other", na.rm = TRUE),
    n_multi = sum(race == "multiracial", na.rm = TRUE),
    
    # Ethnicity Distribution
    n_hispanic = sum(ethnicity == "hispanic_latino", na.rm = TRUE),
    n_nonhispanic = sum(ethnicity == "not_hispanic_latino", na.rm = TRUE),
    
    # BMI Distribution
    mean_bmi = mean(bmi, na.rm = TRUE),
    sd_bmi = sd(bmi, na.rm = TRUE),
    
    # Education
    n_currently_hs = sum(education == 1, na.rm = TRUE),
    n_no_hs_ged = sum(education == 2, na.rm = TRUE),
    n_hs_ged = sum(education == 3, na.rm = TRUE),
    n_some_college = sum(education == 4, na.rm = TRUE),
    n_bachelors = sum(education == 5, na.rm = TRUE),
    n_advanced = sum(education == 6, na.rm = TRUE),
    n_dont_know = sum(education == 7, na.rm = TRUE),
    
    pct_currently_hs = round(mean(education == 1, na.rm = TRUE) * 100, 1),
    pct_no_hs_ged = round(mean(education == 2, na.rm = TRUE) * 100, 1),
    pct_hs_ged = round(mean(education == 3, na.rm = TRUE) * 100, 1),
    pct_some_college = round(mean(education == 4, na.rm = TRUE) * 100, 1),
    pct_bachelors = round(mean(education == 5, na.rm = TRUE) * 100, 1),
    pct_advanced = round(mean(education == 6, na.rm = TRUE) * 100, 1),
    pct_dont_know = round(mean(education == 7, na.rm = TRUE) * 100, 1),
    
    # Income distribution
    n_under_15k = sum(income == 1, na.rm = TRUE),
    n_15k_24k = sum(income == 2, na.rm = TRUE),
    n_25k_34k = sum(income == 3, na.rm = TRUE),
    n_35k_49k = sum(income == 4, na.rm = TRUE),
    n_50k_74k = sum(income == 5, na.rm = TRUE),
    n_75k_99k = sum(income == 6, na.rm = TRUE),
    n_100k_149k = sum(income == 7, na.rm = TRUE),
    n_150k_199k = sum(income == 8, na.rm = TRUE),
    n_200k_over = sum(income == 9, na.rm = TRUE),
    n_income_unknown = sum(income == 10, na.rm = TRUE),
    
    pct_under_15k = round(mean(income == 1, na.rm = TRUE) * 100, 1),
    pct_15k_24k = round(mean(income == 2, na.rm = TRUE) * 100, 1),
    pct_25k_34k = round(mean(income == 3, na.rm = TRUE) * 100, 1),
    pct_35k_49k = round(mean(income == 4, na.rm = TRUE) * 100, 1),
    pct_50k_74k = round(mean(income == 5, na.rm = TRUE) * 100, 1),
    pct_75k_99k = round(mean(income == 6, na.rm = TRUE) * 100, 1),
    pct_100k_149k = round(mean(income == 7, na.rm = TRUE) * 100, 1),
    pct_150k_199k = round(mean(income == 8, na.rm = TRUE) * 100, 1),
    pct_200k_over = round(mean(income == 9, na.rm = TRUE) * 100, 1),
    pct_income_unknown = round(mean(income == 10, na.rm = TRUE) * 100, 1),
    
    .groups = 'drop'
  )

# Export results
write_csv(demographics,'results/demographics/demographics.csv')

# Age and BMI Stats -------------------------------------------------------
# Summarizing Age and BMI for the entire sample
age_bmi <- exergame %>%
  summarise(
    mean_age = round(mean(age, na.rm = TRUE), 1),
    sd_age = round(sd(age, na.rm = TRUE), 1),
    mean_bmi = round(mean(bmi, na.rm = TRUE), 1),
    sd_bmi = round(sd(bmi, na.rm = TRUE), 1)
  )
write_csv(age_bmi,'results/demographics/ageBMIsummary.csv')

# Export Exergame Dataframe -----------------------------------------------
# Exporting the dataframe for further analysis through separate scripts
write_csv(exergame,'data/tidy/exergame_demographics_tidy.csv')

######## PREVIOUS CODE ######## 
# BMI ---------------------------------------------------------------------

# ggplot(exergame, aes(x = bmi)) +
#   geom_histogram(binwidth = 1, fill = "skyblue", color = "black", alpha = 0.7) +
#   labs(title = "BMI Distribution", x = "BMI", y = "Frequency") +
#   theme_minimal()
# 
# # Physical Activity -------------------------------------------------------
# physical_activity <- sapply(exergame[c("vig_activity_days", "mod_activity_days",
#                                  "walk_days","sit_hours")], summary)
# print(physical_activity)
# 
# ## Total Walking Minutes
# exergame$walk_minutes <- as.numeric(exergame$walk_minutes)
# exergame$walk_min_total <- exergame$walk_hours * 60 + exergame$walk_minutes
# summary(exergame$walk_min_total)
# 
# # ADHD Types and Medications ---------------------------------------------------------------
# ## ADHD Type
# exergame$adhd_type <- factor(exergame$adhd_type, levels = c(1,2,3), labels = c("hyperactive_impulsive", "inattentive","combined"))
# table(exergame$adhd_type)
# ## Medication Intake
# table(exergame$adhd_med_type)



# Intervention Assignments ------------------------------------------------
# exergame$intervention <- factor(exergame$intervention, levels = c("A","B","C"), labels = c("dance", "bike","sit"))
# table(exergame$intervention)
# 
# intervention_sex <- exergame %>%
#   group_by(intervention,sex) %>%
#   summarise(count = n(), .groups = "drop")
# 
# intervention_adhdtype <- exergame %>%
#   group_by(intervention,adhd_type) %>%
#   summarise(count = n(), .groups = "drop")
# 
# intervention_medtype <- exergame %>%
#   group_by(intervention,adhd_med_type) %>%
#   summarise(count = n(), .groups = "drop")


