# CREATING MENTAL HEALTH TABLE - IMPROVED VERSION
# Now that we have a tidied version of the REDCap data from the baseline sessions,
# we will now determine the distribution of the following variables for our Mental
# Health Table for Paper 1 (Describing Adult ADHD)
#
# 1. Antidepressant Intake (With details of antidepresant type)
# 2. ASRS - Scoring Criteria (so just a sum)
# 3. ASSET - Show Subscores
# 4. DSM 5 - Cross Cutting
# 5. BDI
# 6. BAI
# 7. Lower Limb Injury

# Import Libraries --------------------------------------------------------
library(tidyverse)

# Import Dataset ----------------------------------------------------------
exergame <- read_csv('data/tidy/exergame_demographics_tidy.csv')

# Calculate Variables of Interest -----------------------------------------
# This will include calculations for ASRS total, ASSET total and subscores, 
# Beck Depression Inventory, Beck Anxiety Inventory, and Lower Limb Injury
# (to control for balance scores)

exergame <- exergame %>%
  #### ASRS total score ####
  mutate(asrs_18_total = rowSums(select(., asrs_1:asrs_18)),
         asrs_6_total = rowSums(select(., asrs_1:asrs_6)),
         asrs_6_total_category = case_when(
           asrs_6_total >= 0 & asrs_6_total <= 9 ~ "low_negative",
           asrs_6_total >= 10 & asrs_6_total <= 13 ~ "high_negative", 
           asrs_6_total >= 14 & asrs_6_total <= 17 ~ "low_positive",
           asrs_6_total >= 18 & asrs_6_total <= 24 ~ "high_positive",
           TRUE ~ NA_character_
         )) %>%
  
  #### ASSET variables ####
  mutate(asset_inattentive = asset_attn*0.16 + asset_forget*0.17 + asset_follow*0.19 +
           asset_organize*0.2 + asset_misplace*0.15 + asset_productivity*0.13,
         asset_hyperactive = asset_fidget*0.31 + asset_impatience*0.36 + asset_anxiety*0.13 +
           asset_mood*0.19,
         asset_total = asset_inattentive + asset_hyperactive) %>%
  
  #### DSM Cross Cutting composite scores ####
  mutate(depression_dsm = depression_1 + depression_2,
         anger_dsm = anger,
         mania_dsm = mania_1 + mania_2,
         anxiety_dsm = anxiety_1 + anxiety_2 + anxiety_3,
         somatic_symptoms_dsm = somatic_1 + somatic_2,
         suicidal_idea_dsm = suicidal_idea,
         psychosis_dsm = psychosis_1 + psychosis_2,
         sleep_dsm = sleep,
         memory_dsm = memory,
         repetitive_thoughts_behaviors_dsm = repetitive_1 + repetitive_2,
         dissociation_dsm = dissociation,
         personality_functioning_dsm = personality_1 + personality_2,
         substance_use_dsm = substance_1 + substance_2 + substance_3) %>%
  
  #### BDI total score ####
  mutate(bdi_total = sadness_bdi + pessimism_bdi + failure_bdi + loss_satisfaction_bdi + guilt_bdi + 
           punish_bdi + disaapoint_bdi + self_critical_bdi + suicidal_thoughts_bdi + 
           crying_bdi + irritable_bdi + interest_loss_bdi + indecisive_bdi + self_image_bdi +
           motivation_bdi + sleep_bdi + tired_bdi + appetite_bdi + weight_bdi + 
           worry_health_bdi + sex_bdi,
         bdi_category = case_when(
           bdi_total >= 0 & bdi_total <= 9 ~ "minimal",
           bdi_total >= 10 & bdi_total <= 18 ~ "mild", 
           bdi_total >= 19 & bdi_total <= 29 ~ "moderate",
           bdi_total >= 30 & bdi_total <= 63 ~ "severe",
           TRUE ~ NA_character_
         )) %>%
  
  #### BAI total score ####
  mutate(bai_total = bai_1 + bai_2 + bai_3 + bai_4 + bai_5 + bai_6 + bai_7 + bai_8 +
           bai_9 + bai_10 + bai_11 + bai_12 + bai_13 + bai_14 + bai_15 +
           bai_16 + bai_17 + bai_18 + bai_19 + bai_20 + bai_21,
         bai_category = case_when(
           bai_total >= 0 & bai_total <= 7 ~ "minimal",
           bai_total >= 8 & bai_total <= 15 ~ "mild", 
           bai_total >= 16 & bai_total <= 25 ~ "moderate",
           bai_total >= 26 & bai_total <= 63 ~ "severe",
           TRUE ~ NA_character_
         )) %>%
  
  #### lower injury variable ####
  mutate(lower_injury = if_else(
    lower_injury___1 == 1 | lower_injury___2 == 1 | lower_injury___3 == 1, 
    "yes", 
    "no"
  ))

exergame_export <- exergame %>%
  select(-bdi_category,-bai_category)

# Export Dataframe with Totals --------------------------------------------
write_csv(exergame_export, 'data/tidy/exergame_DemoBaselineMH_TOTALS.csv')


# HELPER FUNCTIONS FOR SUMMARY STATISTICS ---------------------------------

# Function to calculate mean (SD) format
format_mean_sd <- function(vec, digits = 2) {
  paste0(round(mean(vec, na.rm = TRUE), digits), 
         " (", round(sd(vec, na.rm = TRUE), digits), ")")
}

# Function to calculate count (percentage%) format
format_count_pct <- function(vec, digits = 1) {
  paste0(sum(vec, na.rm = TRUE), 
         " (", round(mean(vec, na.rm = TRUE) * 100, digits), "%)")
}

# Function to create comprehensive mental health summary
create_mental_health_summary <- function(data, group_var = NULL) {
  
  # List of DSM variables to summarize
  dsm_vars <- c("depression_dsm", "anger_dsm", "mania_dsm", "anxiety_dsm",
                "somatic_symptoms_dsm", "suicidal_idea_dsm", "psychosis_dsm",
                "sleep_dsm", "memory_dsm", "repetitive_thoughts_behaviors_dsm",
                "dissociation_dsm", "personality_functioning_dsm", "substance_use_dsm")
  
  # Start with grouping if specified
  if (!is.null(group_var)) {
    data <- data %>% group_by(!!sym(group_var))
  }
  
  # Create comprehensive summary
  summary_data <- data %>%
    summarise(
      n = n(),
      
      # ASRS variables
      asrs_18_total = format_mean_sd(asrs_18_total),
      asrs_6_total = format_mean_sd(asrs_6_total),
      
      # ASSET variables
      asset_inattentive = format_mean_sd(asset_inattentive),
      asset_hyperactive = format_mean_sd(asset_hyperactive),
      asset_total = format_mean_sd(asset_total),
      
      # DSM-5 Cross Cutting Variables (now continuous sum scores - use Mean (SD))
      across(all_of(dsm_vars), 
             ~format_mean_sd(.x), 
             .names = "{.col}_summary"),
      
      # BDI and BAI totals
      bdi_total = format_mean_sd(bdi_total),
      bai_total = format_mean_sd(bai_total),
      
      # BDI categories
      bdi_minimal = format_count_pct(bdi_category == "minimal"),
      bdi_mild = format_count_pct(bdi_category == "mild"),
      bdi_moderate = format_count_pct(bdi_category == "moderate"),
      bdi_severe = format_count_pct(bdi_category == "severe"),
      
      # BAI categories
      bai_minimal = format_count_pct(bai_category == "minimal"),
      bai_mild = format_count_pct(bai_category == "mild"),
      bai_moderate = format_count_pct(bai_category == "moderate"),
      bai_severe = format_count_pct(bai_category == "severe"),
      
      # ADHD medication types
      adhd_med_amphetamine = format_count_pct(adhd_med_type == "amphetamine"),
      adhd_med_methylphenidate = format_count_pct(adhd_med_type == "methylphenidate"),
      adhd_med_none = format_count_pct(adhd_med_type == "none"),
      adhd_med_other = format_count_pct(adhd_med_type == "other"),
      
      # Lower injury
      lower_injury_yes = format_count_pct(lower_injury == "yes"),
      lower_injury_no = format_count_pct(lower_injury == "no"),
      
      # Antidepressant use
      antidepressant_yes = format_count_pct(antidepressant == TRUE),
      antidepressant_no = format_count_pct(antidepressant == FALSE),
      
      .groups = 'drop'
    )
  
  # Clean up DSM variable names for readability
  summary_data <- summary_data %>%
    rename_with(~str_remove(.x, "_dsm_summary"), ends_with("_dsm_summary"))
  
  return(summary_data)
}

# Function to create detailed categorical breakdowns
create_categorical_summaries <- function(data, group_var = NULL) {
  
  # ASRS-6 categories
  if (!is.null(group_var) && group_var != "asrs_6_total_category") {
    asrs_categories <- data %>%
      group_by(!!sym(group_var), asrs_6_total_category) %>%
      summarise(n = n(), .groups = 'drop_last') %>%
      mutate(percentage = round(n/sum(n)*100, 1)) %>%
      ungroup()
  } else {
    asrs_categories <- data %>%
      group_by(asrs_6_total_category) %>%
      summarise(n = n(), .groups = 'drop') %>%
      mutate(percentage = round(n/sum(n)*100, 1))
  }
  
  # Antidepressant types (only for those taking antidepressants)
  if (!is.null(group_var) && group_var != "antidepressant_type") {
    antidepressant_types <- data %>%
      filter(antidepressant == TRUE & !is.na(antidepressant_type)) %>%
      group_by(!!sym(group_var), antidepressant_type) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(!!sym(group_var), desc(n))
  } else {
    antidepressant_types <- data %>%
      filter(antidepressant == TRUE & !is.na(antidepressant_type)) %>%
      group_by(antidepressant_type) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(desc(n))
  }
  
  # ADHD medication types
  if (!is.null(group_var) && group_var != "adhd_med_type") {
    adhd_med_types <- data %>%
      group_by(!!sym(group_var), adhd_med_type) %>%
      summarise(n = n(), .groups = 'drop_last') %>%
      mutate(percentage = round(n/sum(n)*100, 1)) %>%
      ungroup()
  } else {
    adhd_med_types <- data %>%
      group_by(adhd_med_type) %>%
      summarise(n = n(), .groups = 'drop') %>%
      mutate(percentage = round(n/sum(n)*100, 1))
  }
  
  # BDI categories
  if (!is.null(group_var) && group_var != "bdi_category") {
    bdi_categories <- data %>%
      group_by(!!sym(group_var), bdi_category) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(!!sym(group_var), desc(n))
  } else {
    bdi_categories <- data %>%
      group_by(bdi_category) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(desc(n))
  }
  
  # BAI categories
  if (!is.null(group_var) && group_var != "bai_category") {
    bai_categories <- data %>%
      group_by(!!sym(group_var), bai_category) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(!!sym(group_var), desc(n))
  } else {
    bai_categories <- data %>%
      group_by(bai_category) %>%
      summarise(n = n(), .groups = 'drop') %>%
      arrange(desc(n))
  }
  
  return(list(
    asrs_categories = asrs_categories,
    antidepressant_types = antidepressant_types,
    adhd_med_types = adhd_med_types,
    bdi_categories = bdi_categories,
    bai_categories = bai_categories
  ))
}


# GENERATE ALL SUMMARIES --------------------------------------------------

cat("=========================================================================\n")
cat("MENTAL HEALTH SUMMARY STATISTICS\n")
cat("=========================================================================\n\n")

# 1. OVERALL SUMMARY (All 67 participants)
cat("1. OVERALL SUMMARY FOR ALL 67 PARTICIPANTS\n")
cat("=" %>% rep(80) %>% paste(collapse = ""), "\n")
overall_summary <- create_mental_health_summary(exergame)
print(overall_summary)
cat("\n")

# 2. OVERALL CATEGORICAL BREAKDOWNS
cat("2. OVERALL CATEGORICAL BREAKDOWNS\n")
cat("=" %>% rep(80) %>% paste(collapse = ""), "\n\n")
overall_categorical <- create_categorical_summaries(exergame)

cat("ASRS-6 Categories:\n")
print(overall_categorical$asrs_categories)
cat("\n")

cat("Antidepressant Types (among users):\n")
print(overall_categorical$antidepressant_types)
cat("\n")

cat("ADHD Medication Types:\n")
print(overall_categorical$adhd_med_types)
cat("\n")

cat("BDI Categories:\n")
print(overall_categorical$bdi_categories)
cat("\n")

cat("BAI Categories:\n")
print(overall_categorical$bai_categories)
cat("\n\n")

# 3. GROUP-SPECIFIC SUMMARY (By ASRS-6 category)
cat("3. SUMMARY BY ASRS-6 TOTAL CATEGORY (SUBGROUPS)\n")
cat("=" %>% rep(80) %>% paste(collapse = ""), "\n")
group_summary <- create_mental_health_summary(exergame, group_var = "asrs_6_total_category")
print(group_summary)
cat("\n")

# 4. GROUP-SPECIFIC CATEGORICAL BREAKDOWNS
cat("4. GROUP-SPECIFIC CATEGORICAL BREAKDOWNS\n")
cat("=" %>% rep(80) %>% paste(collapse = ""), "\n\n")
group_categorical <- create_categorical_summaries(exergame, group_var = "asrs_6_total_category")

cat("ASRS-6 Categories by Group:\n")
print(group_categorical$asrs_categories)
cat("\n")

cat("Antidepressant Types by Group:\n")
print(group_categorical$antidepressant_types)
cat("\n")

cat("ADHD Medication Types by Group:\n")
print(group_categorical$adhd_med_types)
cat("\n")

cat("BDI Categories by Group:\n")
print(group_categorical$bdi_categories)
cat("\n")

cat("BAI Categories by Group:\n")
print(group_categorical$bai_categories)
cat("\n")


# EXPORT ALL RESULTS ------------------------------------------------------

cat("\n")
cat("EXPORTING RESULTS TO CSV FILES\n")
cat("=" %>% rep(80) %>% paste(collapse = ""), "\n")

# Create output directories if they don't exist
dir.create("results/mentalhealth/overall", recursive = TRUE, showWarnings = FALSE)
dir.create("results/mentalhealth/subgroups", recursive = TRUE, showWarnings = FALSE)

# Export overall summaries
write_csv(overall_summary, "results/mentalhealth/overall/comprehensive_summary.csv")
write_csv(overall_categorical$asrs_categories, "results/mentalhealth/overall/asrs6_categories.csv")
write_csv(overall_categorical$antidepressant_types, "results/mentalhealth/overall/antidepressant_types.csv")
write_csv(overall_categorical$adhd_med_types, "results/mentalhealth/overall/adhd_med_types.csv")
write_csv(overall_categorical$bdi_categories, "results/mentalhealth/overall/bdi_categories.csv")
write_csv(overall_categorical$bai_categories, "results/mentalhealth/overall/bai_categories.csv")

# Export group-specific summaries
write_csv(group_summary, "results/mentalhealth/subgroups/comprehensive_summary.csv")
write_csv(group_categorical$asrs_categories, "results/mentalhealth/subgroups/asrs6_categories.csv")
write_csv(group_categorical$antidepressant_types, "results/mentalhealth/subgroups/antidepressant_types.csv")
write_csv(group_categorical$adhd_med_types, "results/mentalhealth/subgroups/adhd_med_types.csv")
write_csv(group_categorical$bdi_categories, "results/mentalhealth/subgroups/bdi_categories.csv")
write_csv(group_categorical$bai_categories, "results/mentalhealth/subgroups/bai_categories.csv")

cat("\n✓ Analysis complete! All summary tables saved to results/mentalhealth/\n")
cat("✓ Overall summaries: results/mentalhealth/overall/\n")
cat("✓ Subgroup summaries: results/mentalhealth/subgroups/\n")
