# SUMMARIZE CENTER OF PRESSURE OUTPUTS
# Summarize metrics from all stances during baseline session and identify extreme 
# outliers.
#
# IMPORTANT NOTE: Make sure you review the outliers to ensure that recording took
# place properly. Dr. Arena suggested looking at their stabilograms. You can 
# also look at the time series for ML and AP COP displacement.
#
# Final result is a long-format .csv spreadsheet that can be used for modelling.
#
# Edited on September 23, 2025

# Import Libraries --------------------------------------------------------
library(tidyverse)
library(ggbeeswarm)

# Import Data -------------------------------------------------------------
cop <- read_csv('data/cop_tidy.csv') %>%
  mutate(metric = case_when(
    metric == "RDIST" ~ "RMS Distance",
    metric == "MVELO" ~ "Mean Velocity",
    TRUE ~ metric),
    trial = case_when(
      trial == "1-1" ~ "1",
      trial == "1-2" ~ "2",
      trial == "1-3" ~ "3",
      TRUE ~ trial),
    )  # keeps all other values unchanged

# Refactor Variabels to set order for plotting (plot yes before no)
cop$stimulant <- factor(cop$stimulant, levels = c("yes", "no"))
cop$stance <- factor(cop$stance, levels = c("shoulder", "tandem"))
cop$trial <- factor(cop$trial, levels = c("1", "2","3"))

# Create Dataframes for each metric ---------------------------------------

meanvelocity <- cop %>%
  filter(metric == 'Mean Velocity')

RMSdist <- cop  %>%
  filter(metric == "RMS Distance")


# Plot Spread for Each Metric ---------------------------------------------

# General Mean Velocity
ggplot(meanvelocity,aes(x=stance,y=value)) + 
  geom_boxplot()

# Mean Velocity Across Trials
ggplot(meanvelocity,aes(x=stance,y=value,fill=trial)) + 
  geom_boxplot()

# General RMS Distance
ggplot(RMSdist,aes(x=stance,y=value)) + 
  geom_boxplot()

# RMS distance across trials
ggplot(RMSdist,aes(x=stance,y=value,fill=trial)) + 
  geom_boxplot()

# Find Outliers -----------------------------

# Mean Velocity - Shoulder
meanvel_shoulder_outliers <- meanvelocity %>%
  filter(stance == 'shoulder') %>%  # Filter by stance first
  mutate(z_score = abs(as.numeric(scale(value)))) %>%  # Calculate z-scores
  filter(z_score > 3) # Keep extreme outliers (z-score > 3)

# Mean Velocity - Tandem
meanvel_tandem_outliers <- meanvelocity %>%
  filter(stance == 'tandem') %>%  # Filter by stance first
  mutate(z_score = abs(as.numeric(scale(value)))) %>%  # Calculate z-scores
  filter(z_score > 3) # Keep extreme outliers (z-score > 3)

# RMS Distance - Shoulder
rms_shoulder_outliers <- RMSdist %>%
  filter(stance == 'shoulder') %>%  # Filter by stance first
  mutate(z_score = abs(as.numeric(scale(value)))) %>%  # Calculate z-scores
  filter(z_score > 3) # Keep extreme outliers (z-score > 3)

# RMS Distance - Tandem
rms_tandem_outliers <- RMSdist %>%
  filter(stance == 'tandem') %>%  # Filter by stance first
  mutate(z_score = abs(as.numeric(scale(value)))) %>%  # Calculate z-scores
  filter(z_score > 3) # Keep extreme outliers (z-score > 3)

# Combine All outliers for a unified dataframe
extreme_outliers <- bind_rows(meanvel_shoulder_outliers, meanvel_tandem_outliers,
                              rms_shoulder_outliers, rms_tandem_outliers) %>%
  select(participant_id,session:z_score)

write_csv(extreme_outliers,'results/baseline_extreme_outliers.csv')

# Export Final Data Frame for Modelling -----------------------------------

write_csv(cop,'data/baseline_cop_data_forModeling.csv')
