# Creating Wide Dataframe for Modeling Baseline Session Data
# Leading up to this point, you should have already gathered the following outputs
# needed to curate a linear model to predict ASRS-18 scores. 
# 
# The variables needed for your model include the following data in wide format:
#     1. Demographic Variables
#     2. Baseline Mental Health Outcomes
#     3. Session 1 Times (whether participant's session was in the morning/afternoon)
#     4. Executive function tasks (4 total) results
#     5. ERP results associated with 3 of the tasks
#     6. COP outcomes associated with shoulder width and tandem stances
#     7. SpecParam Peak Power across all tasks
#     8. DMN-DAN connectivity averages across all tasks
#
# NOTE: We needed to make a special consideration for exgm108 and exgm136 because
# they did not appropriately complete the Go/No-Go Task. You will see that their
# EF values and Functional Connectivity values were replaced with NA in this
# script.
#
# The final output will be a super wide dataframe, with each row corresponding
# to each participant. This dataframe will then be carefully imputed to fill 
# in missing values before being run through a linear model with LASSO 
# regularization.

# Import Libraries -----------------------------------------------
library(tidyverse)
library(readxl)
library(janitor)

# DEMOGRAPHIC AND MENTAL HEALTH DATA -----------------
#### Load Data ####
exergame <- read_csv("../demographicsPsych/data/tidy/exergame_DemoBaselineMH_TOTALS.csv") %>%
  #### Select Columns of Interest ####
  # we are leaving out depression_dsm and anxiety_dsm because we have bdi and bai scores
  select(participant_id,asrs_18_total,asrs_6_total,asrs_6_total_category,asset_inattentive,
         asset_hyperactive,adhd_med_type,stimulant,antidepressant,sex,weight,height,
         race,ethnicity,income,education,bdi_total,bai_total,
         anger_dsm,mania_dsm,somatic_symptoms_dsm:substance_use_dsm, lower_injury) %>%
  #### Transform Coded Categorical Variables ####
  mutate(sex = case_when(
    sex == 1 ~ "female",
    sex == 2 ~ "male"),
    income = case_when(
      income == 1 ~ "under 15k",
      income == 2 ~ "15k-24k",
      income == 3 ~ "25k-34k",
      income == 4 ~ "35k-49k",
      income == 5 ~ "50k-74k",
      income == 6 ~ "75k-99k",
      income == 7 ~ "100k-149k",
      income == 8 ~ "150k-199k",
      income == 9 ~ "over 200k",
      income == 10 ~ "unknown"),
    education = case_when(
      education == 3 ~ "Finished HS or Received GED",
      education == 4 ~ "Some College",
      education == 5 ~ "Bachelor's Degree",
      education == 6 ~ "Advanced Degree")
    ) %>%
  # Convert NA values for Ethnicity to "unknown"
  mutate(ethnicity = replace_na(ethnicity, "unknown")) %>%
  #### Factor Categorical Variables ####
  mutate(
    asrs_6_total_category = fct_relevel(asrs_6_total_category,"low_negative"),
    adhd_med_type = fct_relevel(adhd_med_type,"none"),
    sex = fct_relevel(sex,"female"),
    race = fct_relevel(race,"white"),
    ethnicity = fct_relevel(ethnicity,"not_hispanic_latino"),
    education = fct_relevel(education,"Some College"),
    income = fct_relevel(income, "unknown")
  ) %>%
  #### Convert yes/no variables to binary numeric variables ####
  mutate(
    stimulant = as.numeric(tolower(stimulant) == "yes"),
    lower_injury = as.numeric(tolower(lower_injury) == "yes"),
    # Convert TRUE/FALSE logical to 0/1
    antidepressant = as.numeric(antidepressant),
    across(anger_dsm:substance_use_dsm, as.numeric)
  )


# SESSION TIMES -----------------------------------------------------------

session1_times <- read_csv("../demographicsPsych/data/session_times.csv") %>%
  filter(session == 1) %>% #only use baseline session times
  select(id,time) %>% #keep id and time columns
  mutate(participant_id = as.numeric(str_extract(id, "\\d+"))) %>% #convert ids to numeric values
  select(-id) %>% # get rid of old id column
  select(participant_id,time) %>% # move participant_id to first column
  mutate(time = fct_relevel(time,"morning"))

# EXECUTIVE FUNCTION RESULTS ----------------------------------------------------------------

#### Go/No-Go ####
# Note that two participants completed the task incorrectly, so their rows of data
# need to be filled with NA

# Excluded Participants
gonogo_exclude_ids <- c(108,136) #exgm108 and exgm136

gonogo_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_cuedgonogo_summary_merge.xlsx") %>%
  # Continue restructuring dataframe
  select(subjectid,errorrate:meanrt_horizontalcue_gotarget) %>%
  mutate(across(c(meanrt, meanrt_verticalcue_gotarget, meanrt_horizontalcue_gotarget), as.numeric)) %>%
  rename_with(~ paste0("gonogo_", .x)) %>%
  mutate(participant_id = as.numeric(str_extract(gonogo_subjectid, "\\d+"))) %>% 
  relocate(participant_id, .before = everything()) %>%
  select(-gonogo_subjectid) %>%
  # Replace excluded participants' values with NA
  mutate(across(-participant_id, 
                ~ifelse(participant_id %in% gonogo_exclude_ids, NA, .)))

#### Wisconsin Card Sort Task (WCST) ####

wcst_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_wcst_summary_merge.xlsx") %>%
    clean_names() %>%
    select(subjectid,percent_errors,percent_p_responses,percent_p_errors,percent_other_errors,learning_to_learn) %>%
    rename_with(~ paste0("wcst_", .x)) %>%
    mutate(participant_id = as.numeric(str_extract(wcst_subjectid, "\\d+"))) %>% 
    relocate(participant_id, .before = everything()) %>%
    select(-wcst_subjectid)

#### Stroop ####

stroop_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_stroopwithcontrolkeyboard_summary_merge.xlsx") %>%
    select(subjectid,propcorrect:meanRTcorr_control) %>%
    rename_with(~ paste0("stroop_", .x)) %>%
    mutate(participant_id = as.numeric(str_extract(stroop_subjectid, "\\d+"))) %>% 
    relocate(participant_id, .before = everything()) %>%
    select(-stroop_subjectid)

#### Digit Span ####

digitspan_ef <- read_excel("../demographicsPsych/data/inquisit/baseline/baseline_digitspanvisual_summary_merge.xlsx") %>%
    select(subjectid,fTE_ML:bMS) %>%
    rename_with(~ paste0("digit_", .x)) %>%
    mutate(participant_id = as.numeric(str_extract(digit_subjectid, "\\d+"))) %>% 
    relocate(participant_id, .before = everything()) %>%
    select(-digit_subjectid)


# ERP RESULTS --------------------------------------------------------------

#### Go/No-Go ####
gonogo_erp <- read_csv("../demographicsPsych/data/erp/gonogo_erp_data.csv") %>%
    select(-worklat,-ERPset,-filename) %>%
    # Rename Bin Labels for Easier Column Naming in Wide Dataframe
    mutate(binlabel = recode(binlabel,
                             "NoGo_minus_Go_Related_Difference_Wave" = "nogo_go_related",
                             "GO_Unrelated_minus_Related_Difference_Wave" = "go_unrelated_related",
                             "NOGO_Unrelated_minus_Related_Difference_Wave" = "nogo_unrelated_related",
                             "Go_minus_NoGo_Related_Difference_Wave" = "go_nogo_related"
                             )) %>%
    # Filter for Baseline Data
    filter(session == "baseline") %>%
    # Remove session variable for clean widening
    select(-session) %>%
    # Widen dataframe
    pivot_wider(
      names_from = c(chlabel, component, measurement, binlabel),
      values_from = value,
      names_glue = "{chlabel}_{component}_{measurement}_{binlabel}"
    )

#### WCST ####

# Note that the only unique binlabel for this dataframe is
# "Incorrect_minus_Correct_Difference_Wave". So don't need to include it in
# our widened dataframe columns

# Fz was also the only channel used for ERP measurements, so we can also remove
# the chlabel column before widening

wcst_erp <- read_csv("../demographicsPsych/data/erp/wcst_erp_data.csv") %>%
  select(-worklat,-ERPset,-filename) %>%
  # Filter for Baseline Data
  filter(session == "baseline") %>%
  # Remove session and binlabel variable for clean widening
  select(-session, -binlabel, -chlabel) %>%
  # Widen dataframe
  pivot_wider(
    names_from = c(component, measurement),
    values_from = value,
    names_glue = "{component}_{measurement}"
  )

#### Stroop ####

stroop_erp <- read_csv("../demographicsPsych/data/erp/stroop_erp_data.csv") %>%
  select(-worklat,-ERPset,-filename) %>%
  # Rename Bin Labels for Easier Column Naming in Wide Dataframe
  mutate(binlabel = recode(binlabel,
                           "Incongruent_minus_Control_Difference_Wave" = "incongruent_control",
                           "Congruent_minus_Control_Difference_Wave" = "congruent_control"
  )) %>%
  # Filter for Baseline Data
  filter(session == "baseline") %>%
  # Remove session variable for clean widening
  select(-session) %>%
  # Widen dataframe
  pivot_wider(
    names_from = c(chlabel, component, measurement, binlabel),
    values_from = value,
    names_glue = "{chlabel}_{component}_{measurement}_{binlabel}"
  )


# COP RESULTS -------------------------------------------------------------
# double check that all data points are here because technically everyone completed
# balance assessments

cop <- read_csv('../force/data/force_long_09202025.csv') %>%
  mutate(participant_id = as.numeric(str_extract(subject_id, "\\d+"))) %>% #convert ids to numeric values
  select(-subject_id) %>% # remove old subject ID column
  relocate(participant_id) %>% # Make new participant_id column first column
  filter(session == 'baseline') %>%
  select(-session) %>% #removes session column now that we're only working with baseline data
  mutate(trial = case_when(
    trial == "1-1" ~ 1,
    trial == "1-2" ~ 2,
    trial == "1-3" ~ 3)) %>%
  pivot_wider(
    names_from = c(stance, metric, trial),
    values_from = value,
    names_glue = "{stance}_{metric}_trial{trial}"
  ) %>%
  clean_names() %>% # makes RDIST and MVELO lowercase in column names
  relocate(shoulder_rdist_trial2, shoulder_mvelo_trial2, .after = shoulder_mvelo_trial1) # keep columns in order


# SPECPARAM PEAK POWER ----------------------------------------------------

peaks <- read_csv('results/wideClusterData/peaks_wide_all_clusters.csv') %>%
  rename_with(~ paste0("cluster", .x)) %>%
  # Bring "clusteric_in_#" to the beginning of the dataframe
  relocate(c(clusteric_in_3, clusteric_in_5, clusteric_in_9,
             clusteric_in_10, clusteric_in_11, clusteric_in_12, clusteric_in_13),
           .before = cluster3_prebaseline_theta) %>%
  # Rename "clusteric_in_#" columns
  rename_with(
    .fn = ~ str_replace(., "clusteric_in_", "ic_in_cluster"),
    .cols = starts_with("clusteric_in_")) %>%
  mutate(participant_id = as.numeric(str_extract(clustersubject, "\\d+"))) %>% #convert ids to numeric values
  select(-clustersubject) %>% # remove old subject ID column
  relocate(participant_id)

# FUNCTIONAL CONNECTIVITY -------------------------------------------------
# Note that the spreadsheet being loaded only has data from session 1 as of 
# October 9, 2025. To double-check, you can use `unique(fc$session)`

#### Replace EXGM108 and EXGM136 Values with NA ####
# Note that these two participants completed the task incorrectly and will need
# to have their values replaced with NA 

fc <- read_csv('results/connectivity_analysis_results.csv') %>%
  mutate(
    DMN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DMN_connectivity
    ),
    DAN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DAN_connectivity
    ),
    DMN_DAN_connectivity = if_else(
      id %in% c("exgm108", "exgm136") & session_number == 1 & task == "gonogo",
      NA_real_,
      DMN_DAN_connectivity
    )
  )

#### Clean up dataframe for merging ####
fc_final <- fc %>%
  select(-session_number) %>%
  rename_with(~ str_remove(., "_connectivity"), contains("connectivity")) %>%
  pivot_wider(
    id_cols = id,
    names_from = c(task, frequency_band),
    values_from = c(DMN, DAN, DMN_DAN),
    names_sep = "_",
    names_glue = "{.value}_{task}_{frequency_band}"
  ) %>%
  # Create proper participant_id column for merging
  mutate(participant_id = as.numeric(str_extract(id, "\\d+"))) %>% #convert ids to numeric values
  select(-id) %>% # remove old subject ID column
  relocate(participant_id)

# Merge All Dataframes ----------------------------------------------------
# Final Dataframe must have 67 rows (1 row per participant)

datasets_to_join <- list(session1_times, gonogo_ef, wcst_ef, stroop_ef, digitspan_ef,
                         gonogo_erp, wcst_erp, stroop_erp, cop, peaks, fc_final)

# Perform all joins at once
modeling_df <- reduce(
  datasets_to_join,
  ~ left_join(.x, .y, by = "participant_id"),
  .init = exergame
)

# Save Wide Dataframe as .rds file for imputation -------------------------
saveRDS(modeling_df, file = "results/exergameWideForModel.RDS")
write_csv(modeling_df,"results/exergameWideForModel.csv")

