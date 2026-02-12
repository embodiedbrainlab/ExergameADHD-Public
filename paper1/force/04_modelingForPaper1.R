# COP Plotting for Paper 1
# The goal of this script is to summarize averages for COP data across all trials.
# Then create 8 plots:
# - Shoulder/Tandem x MVELO/RDIST - boxplots across all three trials
#     - Points should be colored based on ASRS scale
# - For each combination above, plot separate linear models, don't color by ASRS, 
#     rather, color by trial number
#
# Written by Noor Tasnim on October 27, 2025

# Load Libraries and Datasets ---------------------------------------------
library(tidyverse)
library(ggbeeswarm)
library(ggpubr)
library(lme4)
library(lmerTest)
library(performance)

# Load Dataset
exergame <- readRDS("../statistical_modeling/results/exergameWideForModel.RDS")

# Pull Correlations Function Used for Figure 2
source("../demographicsPsych/00_plottingFunctions.R")

# Clean dataframe to keep relevant variables ------------------------------

# Also exclude 7 participants who had some sort of lower limb injury
cop <- exergame %>%
  select((participant_id:height),lower_injury,time,
         bdi_total,bai_total,
         shoulder_rdist_trial1:tandem_mvelo_trial3) %>%
  filter(lower_injury == 0)


# Identify Extreme Outliers Before Summarizing ----------------------------

# Assuming your 6 columns are named col1, col2, col3, col4, col5, col6
cols_to_check <- names(cop)[which(names(cop) == "shoulder_rdist_trial1"):which(names(cop) == "tandem_mvelo_trial3")]

# Find extreme outliers (>3 SD from mean)
outliers <- lapply(cols_to_check, function(col) {
  values <- cop[[col]]
  z_scores <- abs(scale(values))
  extreme <- which(z_scores > 3)
  if(length(extreme) > 0) {
    data.frame(
      participant_id = cop$participant_id[extreme],
      column = col,
      value = values[extreme],
      z_score = z_scores[extreme]
    )
  }
})

# Combine results
outlier_cop <- do.call(rbind, outliers[!sapply(outliers, is.null)])
print(outlier_cop)

# Remove EXGM003 because of Outlier Data ----------------------------------
# EXGM003 constantly had outlier data and I'm not too sure if it's reliable. Thus
# it'll be removed. The following other data points were marked as extreme outliers,
# but given that the rest of their trials were fine, we'll keep them for the
# analysis:

# 1. 160 shoulder_rdist_trial1
# 2. 102   tandem_rdist_trial1
# 3. 105 tandem_rdist_trial3 - possible they were just getting tired

cop <- cop %>%
  filter(participant_id != 3)

# Force Summary Table -----------------------------------------------------

force_summaryTable <- exergame_summaryTable(data = cop,
                                            col_start = "shoulder_rdist_trial1",
                                            col_end = "tandem_mvelo_trial3")
write_csv(force_summaryTable, "results/BaselineForceSummaryTable.csv")


# Correlation with ASRS-18 ------------------------------------------------

col_start <- which(names(exergame) == "shoulder_rdist_trial1")
col_end <- which(names(exergame) == "tandem_mvelo_trial3")
vars_to_plot <- names(exergame)[col_start:col_end]

# Generate and save all plots
walk(vars_to_plot, function(var) {
  plot <- exergame_corrPlot(data = cop, x_var = var, x_label = var)
  ggsave(paste0("results/ASRS_correlations/", var, ".png"),
         plot, width = 10, height = 8, dpi = 300)
  cat("Saved:", var, "\n")
})


# Create Long Dataframe ------------------------------------------

cop_long <- cop %>%
  pivot_longer(
    cols = shoulder_rdist_trial1:tandem_mvelo_trial3,
    names_to = c("stance", "measurement", "trial"),
    names_sep = "_",
    values_to = "value"
  )


# Generate Boxplots -------------------------------------------------------
# Create Box plots with trials on x-axis and value on y, with points colored using
# ggbeeswarm

# Factor trial with custom labels
cop_long <- cop_long %>%
  mutate(trial = factor(trial, 
                        levels = c("trial1", "trial2", "trial3"),
                        labels = c("Trial 1", "Trial 2", "Trial 3")))

# Define the stance and measure combinations
stances <- c("shoulder", "tandem")
measures <- c("rdist", "mvelo")

# Create a list to store plots
plots <- list()

# Loop through each combination
for (s in stances) {
  for (m in measures) {
    # Filter data for this combination
    plot_data <- cop_long %>%
      filter(stance == s, measurement == m)
    
    # Create y-axis label
    y_label <- paste0(s, "_", m)
    
    # Create plot
    p <- ggplot(plot_data, aes(x = trial, y = value)) +
      geom_boxplot(lwd = 1, outlier.shape = NA) +  # Thicker lines, hide outliers
      geom_beeswarm(aes(color = asrs_6_total_category), 
                    size = 3, 
                    cex = 2.5,
                    alpha = 0.6) +  # Add transparency
      scale_color_brewer(palette = "Dark2") +  # Dark2 color scheme
      labs(x = "Trial", y = y_label, color = "ASRS-6 Category") +
      theme_classic(base_size = 12) +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(linewidth = 0.5),
        axis.ticks = element_line(linewidth = 0.5)
      )
    
    # Store plot
    plot_name <- paste0(s, "_", m)
    plots[[plot_name]] <- p
    
    # Display plot
    print(p)
    
    # Save plot as SVG
    ggsave(filename = paste0("results/plots/", s, "_", m, ".svg"),
           plot = p,
           width = 6,
           height = 5,
           units = "in")
  }
}

# Create Linear Regressions -----------------------------------------------

# Create a list to store plots
regression_plots <- list()

# Loop through each combination
for (s in stances) {
  for (m in measures) {
    # Filter data for this combination
    plot_data <- cop_long %>%
      filter(stance == s, measurement == m)
    
    # Create x-axis label
    x_label <- paste0(s, "_", m)
    
    # Create plot with facets for each trial
    p <- ggplot(plot_data, aes(x = value, y = asrs_18_total)) +
      geom_point(aes(color = asrs_6_total_category, shape = sex), 
                 size = 3, alpha = 0.6) +
      geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1) +
      stat_cor(method = "pearson", 
               aes(label = paste(after_stat(r.label), after_stat(p.label), sep = "~`,`~")),
               label.x.npc = "left",
               label.y.npc = "top",
               size = 3.5) +
      scale_color_brewer(palette = "Dark2") +
      facet_wrap(~trial, ncol = 3) +
      labs(x = x_label, 
           y = "ASRS-18 Total", 
           color = "ASRS-6 Category",
           shape = "Sex") +
      theme_classic(base_size = 12) +
      theme(
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(linewidth = 0.5),
        axis.ticks = element_line(linewidth = 0.5),
        strip.background = element_rect(fill = "white", color = "black"),
        strip.text = element_text(face = "bold")
      )
    
    # Store plot
    plot_name <- paste0(s, "_", m, "_regression")
    regression_plots[[plot_name]] <- p
    
    # Display plot
    print(p)
    
    # Save plot as SVG
    ggsave(filename = paste0("results/plots/", s, "_", m, "_regression.svg"),
           plot = p,
           width = 10,
           height = 4,
           units = "in")
  }
}


# Linear mixed effects model ----------------------------------------------

# Convert trial back to numeric for the model (1, 2, 3)
cop_modeldf <- cop_long %>%
  mutate(trial_num = as.numeric(gsub("Trial ", "", trial)))

# Store models
models <- list()
model_summaries <- list()

# Loop through each combination
for (s in stances) {
  for (m in measures) {
    # Filter data
    model_data <- cop_modeldf %>%
      filter(stance == s, measurement == m)
    
    # Fit linear mixed effects model
    model <- lmer(value ~ asrs_18_total +
                    stimulant + antidepressant + 
                    sex + weight + height + time + trial_num +
                    (1 | participant_id),
                  data = model_data)
    
    # Store model
    model_name <- paste0(s, "_", m)
    models[[model_name]] <- model
    
    # Print results
    cat("\n", rep("=", 60), "\n")
    cat("Model:", model_name, "\n")
    cat(rep("=", 60), "\n\n")
    
    # Model summary with p-values
    print(summary(model))
    
    # R-squared values
    r2 <- r2(model)
    cat("\n--- Model Fit ---\n")
    cat("Conditional R² (total variance explained):", round(r2$R2_conditional, 3), "\n")
    cat("Marginal R² (variance explained by fixed effects):", round(r2$R2_marginal, 3), "\n\n")
    
    # Store summary for later
    model_summaries[[model_name]] <- list(
      summary = summary(model),
      r2 = r2
    )
  }
}


# Repeated measures T-test ------------------------------------------------
# To show that tandem is indeed a lot less stable than standing shoulder width

cop_ttest <- cop %>%
  mutate(shoulder_mvelo_avg = rowMeans(across(c(shoulder_mvelo_trial1, shoulder_mvelo_trial2, shoulder_mvelo_trial3))),
         shoulder_rdist_avg = rowMeans(across(c(shoulder_rdist_trial1, shoulder_rdist_trial2, shoulder_rdist_trial3))),
         tandem_mvelo_avg = rowMeans(across(c(tandem_mvelo_trial1, tandem_mvelo_trial2, tandem_mvelo_trial3))),
         tandem_rdist_avg = rowMeans(across(c(tandem_rdist_trial1, tandem_rdist_trial2, tandem_rdist_trial3))),
         ) %>%
  select(participant_id, shoulder_mvelo_avg, shoulder_rdist_avg,tandem_mvelo_avg,tandem_rdist_avg)

# MVELO Comparison
t.test(cop_ttest$shoulder_mvelo_avg, cop_ttest$tandem_mvelo_avg, paired = TRUE)
shoulder_mvelo_mean <- mean(cop_ttest$shoulder_mvelo_avg)
shoulder_mvelo_sd <- sd(cop_ttest$shoulder_mvelo_avg)
tandem_mvelo_mean <- mean(cop_ttest$tandem_mvelo_avg)
tandem_mvelo_sd <- sd(cop_ttest$tandem_mvelo_avg)

# RDIST Comparison
t.test(cop_ttest$shoulder_rdist_avg, cop_ttest$tandem_rdist_avg, paired = TRUE)
shoulder_rdist_mean <- mean(cop_ttest$shoulder_rdist_avg)
shoulder_rdist_sd <- sd(cop_ttest$shoulder_rdist_avg)
tandem_rdist_mean <- mean(cop_ttest$tandem_rdist_avg)
tandem_rdist_sd <- sd(cop_ttest$tandem_rdist_avg)
