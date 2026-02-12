# Model ERP Components for Intervention Paper
# We found a few effects of our interventions on our ERP components. We now need
# to determine if any of them affected mean amplitude, fractional latency,
# or onset latency.
#
# `06_ExtractERPs.R` originally compiled the .txt outputs from ERPLAB's measurement
# function into single .csv files for analyis.
#
# This script will load those .csv files, calculate change scores, and then 
# start modeling with our demographic variables.
#
# Written by Noor Tasnim on November 14, 2025

# Import Libraries and Data -----------------------------------------------
library(tidyverse)
library(readxl)
library(ggbeeswarm)
library(tidyr)
library(broom)
library(janitor)

demographics <- readRDS("results/Paper2_BaseDataForModeling.rds")

# Go/No-Go ----------------------------------------------------------------

gonogo_erp <- read_csv("data/erp/gonogo_erp_data.csv") %>%
  filter(!measurement %in% c("PeakAmp", "PeakLat")) %>% 
  select(-worklat,-ERPset,-filename) %>%
  # Rename Bin Labels for Easier Column Naming in Wide Dataframe
  mutate(binlabel = recode(binlabel,
                           "NoGo_minus_Go_Related_Difference_Wave" = "nogo_go_related",
                           "GO_Unrelated_minus_Related_Difference_Wave" = "go_unrelated_related",
                           "NOGO_Unrelated_minus_Related_Difference_Wave" = "nogo_unrelated_related",
                           "Go_minus_NoGo_Related_Difference_Wave" = "go_nogo_related"
  )) %>%
  # Widen dataframe
  pivot_wider(
    names_from = c(session, chlabel, component, measurement, binlabel),
    values_from = value,
    names_glue = "{session}_{chlabel}_{component}_{measurement}_{binlabel}"
  ) %>%
  filter(!participant_id %in% c(77, 152, 160, 175))# exclude dropouts


# WCST --------------------------------------------------------------------
# Note that the only unique binlabel for this dataframe is
# "Incorrect_minus_Correct_Difference_Wave". So don't need to include it in
# our widened dataframe columns

# Fz was also the only channel used for ERP measurements, so we can also remove
# the chlabel column before widening
#
# We should only have 61 observations because exgm031 and exgm190 had less than 
# 6 errors for both sessions.

wcst_erp <- read_csv("data/erp/wcst_erp_data.csv") %>%
  filter(!measurement %in% c("PeakAmp", "PeakLat")) %>% 
  select(-worklat,-ERPset,-filename) %>%
  # Remove session and binlabel variable for clean widening
  select(-binlabel, -chlabel) %>%
  # Widen dataframe
  pivot_wider(
    names_from = c(session, component, measurement),
    values_from = value,
    names_glue = "{session}_{component}_{measurement}"
  ) %>%
  filter(!participant_id %in% c(77, 152, 160, 175))# exclude dropouts


# Stroop ------------------------------------------------------------------

stroop_erp <- read_csv("../demographicsPsych/data/erp/stroop_erp_data.csv") %>%
  filter(!measurement %in% c("PeakAmp", "PeakLat")) %>% 
  select(-worklat,-ERPset,-filename) %>%
  # Rename Bin Labels for Easier Column Naming in Wide Dataframe
  mutate(binlabel = recode(binlabel,
                           "Incongruent_minus_Control_Difference_Wave" = "incongruent_control",
                           "Congruent_minus_Control_Difference_Wave" = "congruent_control"
  )) %>%
  # Widen dataframe
  pivot_wider(
    names_from = c(session, chlabel, component, measurement, binlabel),
    values_from = value,
    names_glue = "{session}_{chlabel}_{component}_{measurement}_{binlabel}"
  ) %>%
  filter(!participant_id %in% c(77, 152, 160, 175))# exclude dropouts


# Join All Datasets -------------------------------------------------------

erp_join <- demographics %>%
  left_join(gonogo_erp, by = "participant_id") %>%
  left_join(stroop_erp, by = "participant_id") %>%
  left_join(wcst_erp, by = "participant_id")

# Calculate Changes -------------------------------------------------------

# Extract variable names from baseline columns
baseline_cols <- grep("^baseline", names(erp_join), value = TRUE)
var_names <- sub("^baseline_?", "", baseline_cols)

# Create difference columns
diff_data <- map_dfc(var_names, function(var) {
  baseline <- erp_join[[paste0("baseline_", var)]]
  intervention <- erp_join[[paste0("intervention_", var)]]
  tibble(!!paste0("diff_", var) := intervention - baseline)
})

# Modeling Dataframe
erp_modeling_df <- bind_cols(erp_join, diff_data)
write_csv(erp_modeling_df, "results/Paper2_ERPmodeling_df.csv")

# Explore Models ----------------------------------------------------------

#Define outcome variables
outcomes <- c("Fz_N2_FracAreaLat_nogo_go_related", 
              "Fz_N2_MeanAmp_nogo_go_related", "Fz_N2_OnsetLat_nogo_go_related", 
              "Cz_P3b_FracAreaLat_go_unrelated_related", "Cz_P3b_FracAreaLat_nogo_unrelated_related", 
              "Cz_P3b_MeanAmp_go_unrelated_related", "Cz_P3b_MeanAmp_nogo_unrelated_related", 
              "Cz_P3b_OnsetLat_go_unrelated_related", "Cz_P3b_OnsetLat_nogo_unrelated_related", 
              "Pz_P3b_FracAreaLat_go_nogo_related", "Pz_P3b_MeanAmp_go_nogo_related", 
              "Pz_P3b_OnsetLat_go_nogo_related", "Fz_N2_FracAreaLat_incongruent_control", 
              "Fz_N2_FracAreaLat_congruent_control", "Fz_N2_MeanAmp_incongruent_control", 
              "Fz_N2_MeanAmp_congruent_control", "Fz_N2_OnsetLat_incongruent_control", 
              "Fz_N2_OnsetLat_congruent_control", "Pz_P3b_FracAreaLat_incongruent_control", 
              "Pz_P3b_FracAreaLat_congruent_control", "Pz_P3b_MeanAmp_incongruent_control", 
              "Pz_P3b_MeanAmp_congruent_control", "Pz_P3b_OnsetLat_incongruent_control", 
              "Pz_P3b_OnsetLat_congruent_control", "ERN_FracAreaLat", 
              "ERN_MeanAmp", "ERN_OnsetLat", "FRN_FracAreaLat", 
              "FRN_MeanAmp", "FRN_OnsetLat")

# Define common covariates
covariates <- c("days_diff", "min_diff", "sex_male", 
                "stimulant","antidepressant", "asrs_18_total")

# Create a function to fit and summarize models
fit_model <- function(outcome, data, covariates) {
  # Build formula dynamically
  formula_str <- paste0(
    "diff_", outcome, " ~ intervention + baseline_", outcome, " + ",
    paste(covariates, collapse = " + ")
  )
  
  # Fit model
  model <- lm(as.formula(formula_str), data = data)
  
  # Return tidy results
  tidy(model, conf.int = TRUE, conf.level = 0.95) %>%
    select(term, estimate, conf.low, conf.high, p.value) %>%
    mutate(outcome = outcome, .before = 1)  # Add outcome identifier
}

# Apply function to all outcomes
model_results <- map_df(outcomes, ~fit_model(.x, erp_modeling_df, covariates))

# Separate by outcome if preferred
results_list <- map(outcomes, ~fit_model(.x, erp_modeling_df, covariates))
names(results_list) <- outcomes

# Visualize Effect of Intervention on All EF Outcomes ---------------------

model_results %>%
  filter(term %in% c("interventionBiking", "interventionDance")) %>%
  mutate(
    outcome = str_remove(outcome, "_total"),
    outcome = str_replace_all(outcome, "_", " "),
    outcome = str_to_title(outcome),
    intervention = str_remove(term, "intervention"),
    significant = if_else(p.value < 0.05, "Yes", "No")
  ) %>%
  ggplot(aes(x = estimate, y = reorder(outcome, estimate))) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(aes(color = significant), size = 3) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high, color = intervention),
                width = 0.2,
                orientation = "y") +
  scale_color_manual(values = c("No" = "gray60", "Yes" = "#2E86AB")) +
  facet_wrap(~intervention, ncol = 2) +
  labs(
    title = "Intervention Effects: Biking vs Dance",
    x = "Effect Size (95% CI)",
    y = "Outcome",
    color = "p < 0.05"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")


# Export All P3b ERP Models -----------------------------------------------

ERP_export <- model_results %>%
  filter(grepl("P3b", outcome)) %>%
  filter(term == "interventionBiking" | term == "interventionDance" | term == "sex_male" | str_detect(term, "baseline"))

write_csv(ERP_export,"results/All_P3b_models.csv")

#### FDR Correction for ERP P-Values ####
p3_bike <- ERP_export %>%
  filter(term == "interventionBiking")
p3_bike$adj_p_value <- p.adjust(p3_bike$p.value, method = "BH")

p3_dance <- ERP_export %>%
  filter(term == "interventionDance")
p3_dance$adj_p_value <- p.adjust(p3_dance$p.value, method = "BH")


# Dive Deeper in P3b - Pz In Congruent Difference Wave --------------------

results_list$Pz_P3b_MeanAmp_congruent_control
results_list$Pz_P3b_FracAreaLat_congruent_control
results_list$Pz_P3b_OnsetLat_congruent_control


# Calculate Summary Differences -------------------------------------------

erp_diff_summary <- erp_modeling_df %>%
  select(participant_id, intervention, 
         diff_Pz_P3b_MeanAmp_congruent_control,
         diff_Pz_P3b_FracAreaLat_congruent_control,
         diff_Pz_P3b_OnsetLat_congruent_control) %>%
  pivot_longer(cols = starts_with("diff_"),
               names_to = "measure",
               values_to = "value") %>%
  group_by(intervention, measure) %>%
  summarise(mean = mean(value, na.rm = TRUE),
            sd = sd(value, na.rm = TRUE),
            n = n(),
            .groups = "drop")

write_csv(erp_diff_summary,"results/p3b_diff_summary.csv")


# Generate Summary Statistics for Publication Paper -----------------------

# Function to calculate mean and SD formatted as "x̄ (N, SD)"
calc_stats <- function(data, intervention_group, session_prefix, variable) {
  col_name <- paste0(session_prefix, "_", variable)
  
  values <- data %>%
    filter(intervention == intervention_group) %>%
    pull(!!sym(col_name))
  
  values <- values[!is.na(values)]
  
  if (length(values) == 0) {
    return("- (-, -)")
  }
  
  mean_val <- mean(values, na.rm = TRUE)
  sd_val <- sd(values, na.rm = TRUE)
  n_val <- length(values)
  
  return(sprintf("%.2f (%d, %.2f)", mean_val, n_val, sd_val))
}

# Determine interventions (assuming you have groups like "Music Listening", "Biking", "Dance Exergame")
interventions <- sort(unique(erp_modeling_df$intervention))

cat("COPY THE OUTPUT BELOW AND PASTE DIRECTLY INTO YOUR WORD TABLE\n")
cat(rep("=", 100), "\n\n", sep = "")

# Table structure matching your Word document
sections <- list(
  list(
    title = "Mean Amplitude (µV)",
    rows = list(
      list(label = "P3b in Pz\nVertical Go minus\nHorizontal No-Go",
           var = "Pz_P3b_MeanAmp_go_nogo_related"),
      list(label = "P3b in Cz\nHorizontal Go minus\nVertical Go",
           var = "Cz_P3b_MeanAmp_go_unrelated_related"),
      list(label = "P3b in Cz\nVertical No-Go minus\nHorizontal No-Go",
           var = "Cz_P3b_MeanAmp_nogo_unrelated_related"),
      list(label = "P3b in Pz\nIncongruent minus Control",
           var = "Pz_P3b_MeanAmp_incongruent_control"),
      list(label = "P3b in Pz\nCongruent minus Control",
           var = "Pz_P3b_MeanAmp_congruent_control")
    )
  ),
  list(
    title = "50% Area Latency (ms)",
    rows = list(
      list(label = "P3b in Pz\nVertical Go minus\nHorizontal No-Go",
           var = "Pz_P3b_FracAreaLat_go_nogo_related"),
      list(label = "P3b in Cz\nHorizontal Go minus\nVertical Go",
           var = "Cz_P3b_FracAreaLat_go_unrelated_related"),
      list(label = "P3b in Cz\nVertical No-Go minus\nHorizontal No-Go",
           var = "Cz_P3b_FracAreaLat_nogo_unrelated_related"),
      list(label = "P3b in Pz\nIncongruent minus Control",
           var = "Pz_P3b_FracAreaLat_incongruent_control"),
      list(label = "P3b in Pz\nCongruent minus Control",
           var = "Pz_P3b_FracAreaLat_congruent_control")
    )
  ),
  list(
    title = "50% Peak Latency (ms)",
    rows = list(
      list(label = "P3b in Pz\nVertical Go minus\nHorizontal No-Go",
           var = "Pz_P3b_OnsetLat_go_nogo_related"),
      list(label = "P3b in Cz\nHorizontal Go minus\nVertical Go",
           var = "Cz_P3b_OnsetLat_go_unrelated_related"),
      list(label = "P3b in Cz\nVertical No-Go minus\nHorizontal No-Go",
           var = "Cz_P3b_OnsetLat_nogo_unrelated_related"),
      list(label = "P3b in Pz\nIncongruent minus Control",
           var = "Pz_P3b_OnsetLat_incongruent_control"),
      list(label = "P3b in Pz\nCongruent minus Control",
           var = "Pz_P3b_OnsetLat_congruent_control")
    )
  )
)

# Generate output for each section
for (section in sections) {
  cat("\n")
  cat(section$title, "\n")
  
  for (row_info in section$rows) {
    # Print row label (replace \n with space for single line)
    cat(gsub("\n", " ", row_info$label), "\t")
    
    # For each intervention
    for (int in interventions) {
      # Session 1
      s1 <- calc_stats(erp_modeling_df, int, "baseline", row_info$var)
      cat(s1, "\t")
      
      # Session 2
      s2 <- calc_stats(erp_modeling_df, int, "intervention", row_info$var)
      cat(s2, "\t")
    }
    cat("\n")
  }
  cat("\n")
}

cat(rep("=", 100), "\n", sep = "")
cat("\nFormat: Mean (N, SD)\n")
cat("To paste into Word:\n")
cat("1. Select and copy the output above (between the section titles)\n")
cat("2. In Word, click in the first empty cell of the corresponding row\n")
cat("3. Paste (Ctrl+V or Cmd+V)\n")
cat("4. The values should populate across the columns automatically\n\n")

# Also create a CSV file for easier import
output_list <- list()

for (section in sections) {
  for (row_info in section$rows) {
    row_data <- list(
      Section = section$title,
      Measurement = gsub("\n", " ", row_info$label)
    )
    
    for (int in interventions) {
      row_data[[paste0(int, "_Session1")]] <- calc_stats(erp_modeling_df, int, "baseline", row_info$var)
      row_data[[paste0(int, "_Session2")]] <- calc_stats(erp_modeling_df, int, "intervention", row_info$var)
    }
    
    output_list[[length(output_list) + 1]] <- row_data
  }
}

output_df <- bind_rows(output_list)
write.csv(output_df, "results/erp_summary_stats.csv", row.names = FALSE)

cat("Summary statistics also saved to: erp_summary_stats.csv\n")
