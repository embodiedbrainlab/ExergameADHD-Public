# CALCULATE DIRECT EFFECTS OF INTERVENTION
# Beyond neurophysiological data, heart rate and ratings of perceived exertion
# were collected during each intervention. 
# 
# We need to show that exertion was generally the same between the biking group
# and the dancing group, while the sedentary group did not undergo any sort
# of physical exertion. 
#
# Written by Noor Tasnim on November 13, 2025


# Load Libraries and Data -------------------------------------------------

library(tidyverse)
library(readxl)
library(ggbeeswarm)
library(scales)
library(svglite)
library(stringr)

exertion <- read_excel("data/! BorgRPE_and_HR.xlsx", na = c("", "NA")) %>%
  select(-just_dance_score, -Just_dance_stars) %>%
  mutate(
    timepoint = recode(timepoint,
                       "start" = "Start",
                       "calm_down" = "Song 1",
                       "kill_bill" = "Song 2",
                       "woof" = "Song 3",
                       "despecha" = "Song 4",
                       "this_wish" = "Song 5",
                       "stronger" = "Song 6",
                       "flowers" = "Song 7",
                       "titi_me_pregunto" = "Song 8",
                       "survivor" = "Song 9"
    ),
    timepoint = factor(
      timepoint,
      levels = c("Start","Song 1","Song 2","Song 3","Song 4","Song 5","Song 6","Song 7","Song 8","Song 9")
    ),
    intervention = as.factor(intervention)
  )

participants_to_keep <- c(
  2,3,4,5,10,12,16,18,19,20,21,23,25,31,43,46,47,48,50,51,57,78,79,81,82,84,87,90,97,102,105,107,108,109,
  111,116,117,119,120,121,122,132,133,136,144,145,146,149,154,156,162,164,169,171,172,179,181,182,184,185,188,190,193
)

exertion$participant_id <- as.numeric(gsub("exgm", "", exertion$participant_id))

exertion_filtered <- exertion %>%
  filter(participant_id %in% participants_to_keep) %>%
  mutate(tp_num = as.integer(timepoint))


# Heart Rate Line Plot ----------------------------------------------------

summary_hr <- exertion_filtered %>%
  group_by(intervention, timepoint, tp_num) %>%
  summarise(
    n_nonmiss = sum(!is.na(hr)),
    mean_hr   = mean(hr, na.rm = TRUE),
    sd_hr     = sd(hr,   na.rm = TRUE),
    se        = ifelse(n_nonmiss > 1, sd_hr / sqrt(n_nonmiss), NA_real_),
    tcrit     = ifelse(n_nonmiss > 1, qt(0.975, df = n_nonmiss - 1), NA_real_),
    ci_lower  = mean_hr - tcrit * se,
    ci_upper  = mean_hr + tcrit * se,
    .groups = "drop"
  )

p_hr <- ggplot() +
  geom_point(
    data = exertion_filtered,
    aes(x = tp_num, y = hr, color = intervention),
    position = position_beeswarm(dodge.width = 0.35, cex = 0.5),
    alpha = 0.35, size = 0.9
  ) +
  geom_ribbon(
    data = summary_hr,
    aes(x = tp_num, ymin = ci_lower, ymax = ci_upper, fill = intervention, group = intervention),
    alpha = 0.20
  ) +
  geom_line(
    data = summary_hr,
    aes(x = tp_num, y = mean_hr, color = intervention, group = intervention),
    linewidth = 1.2
  ) +
  geom_point(
    data = summary_hr,
    aes(x = tp_num, y = mean_hr, color = intervention),
    position = position_dodge(width = 0.35),
    size = 3, shape = 16
  ) +
  geom_errorbar(
    data = summary_hr,
    aes(x = tp_num, ymin = ci_lower, ymax = ci_upper, color = intervention),
    position = position_dodge(width = 0.35),
    width = 0.25, linewidth = 0.8
  ) +
  scale_x_continuous(
    breaks = sort(unique(exertion_filtered$tp_num)),
    labels = levels(exertion_filtered$timepoint)
  ) +
  scale_y_continuous(labels = label_number(accuracy = 1), breaks = pretty_breaks(6)) +
  scale_color_manual(values = c("#0072B2", "#E69F00", "#009E73"), name = "Intervention") +
  scale_fill_manual(values = c("#0072B2", "#E69F00", "#009E73"),  name = "Intervention") +
  labs(x = "Stage of Just Dance", y = "Heart Rate (bpm)") +
  theme_classic() +
  theme(
    axis.text  = element_text(size = 13, color = "black"),
    axis.title = element_text(size = 14, face = "bold"),
    legend.title = element_text(size = 11, face = "bold"),
    legend.text  = element_text(size = 10),
    legend.position = c(0.9, 0.9),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.5),
    panel.grid.minor = element_blank()
  )

print(p_hr)
ggsave("results/heart_rate_plot.svg", plot = p_hr, width = 8, height = 5, units = "in")


# Borg RPE Line Plot ----------------------------------------------------------------

exertion_filtered <- exertion_filtered %>%
  mutate(borg_rpe = as.numeric(borg_rpe))

summary_borg <- exertion_filtered %>%
  group_by(intervention, timepoint, tp_num) %>%
  summarise(
    n_nonmiss = sum(!is.na(borg_rpe)),
    mean_borg = mean(borg_rpe, na.rm = TRUE),
    sd_borg   = sd(borg_rpe,   na.rm = TRUE),
    se        = ifelse(n_nonmiss > 1, sd_borg / sqrt(n_nonmiss), NA_real_),
    tcrit     = ifelse(n_nonmiss > 1, qt(0.975, df = n_nonmiss - 1), NA_real_),
    ci_lower  = mean_borg - tcrit * se,
    ci_upper  = mean_borg + tcrit * se,
    .groups = "drop"
  )

p_borg <- ggplot() +
  geom_point(
    data = exertion_filtered,
    aes(x = tp_num, y = borg_rpe, color = intervention),
    position = position_jitterdodge(jitter.width = 0.15, dodge.width = 0.35),
    alpha = 0.35, size = 0.9
  ) +
  geom_ribbon(
    data = summary_borg,
    aes(x = tp_num, ymin = ci_lower, ymax = ci_upper, fill = intervention, group = intervention),
    alpha = 0.20
  ) +
  geom_line(
    data = summary_borg,
    aes(x = tp_num, y = mean_borg, color = intervention, group = intervention),
    linewidth = 1.2
  ) +
  geom_point(
    data = summary_borg,
    aes(x = tp_num, y = mean_borg, color = intervention),
    position = position_dodge(width = 0.35),
    size = 3, shape = 16
  ) +
  geom_errorbar(
    data = summary_borg,
    aes(x = tp_num, ymin = ci_lower, ymax = ci_upper, color = intervention),
    position = position_dodge(width = 0.35),
    width = 0.25, linewidth = 0.8
  ) +
  scale_x_continuous(
    breaks = sort(unique(exertion_filtered$tp_num)),
    labels = levels(exertion_filtered$timepoint)
  ) +
  scale_y_continuous(limits = c(6, 20), breaks = seq(6, 20, by = 2)) +
  scale_color_manual(values = c("#0072B2", "#E69F00", "#009E73"), name = "Intervention") +
  scale_fill_manual(values = c("#0072B2", "#E69F00", "#009E73"),  name = "Intervention") +
  labs(x = "Stage of Just Dance", y = "Borg Rating of Perceived Exertion") +
  theme_classic() +
  theme(
    axis.text  = element_text(size = 13, color = "black"),
    axis.title = element_text(size = 14, face = "bold"),
    legend.title = element_text(size = 11, face = "bold"),
    legend.text  = element_text(size = 10),
    legend.position = c(0.9, 0.9),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.5),
    panel.grid.minor = element_blank()
  )

print(p_borg)
ggsave("results/borg_rpe_plot.svg", plot = p_borg, width = 8, height = 5, units = "in")

# Average HR ----------------------------------------------------

#### Import Data ####
average_HR <- read_excel("data/! BorgRPE_and_HR.xlsx", sheet = 2, na = c("", "NA")) %>%
  #select(-max_hr_bpm) %>%
  mutate(
    intervention = str_to_lower(intervention),
    intervention = case_when(
      str_detect(intervention, "bike") ~ "Biking",
      str_detect(intervention, "dance") ~ "Dance Exergaming",
      str_detect(intervention, "listen") ~ "Music Listening",
      TRUE ~ str_to_title(intervention)
    ),
    intervention = factor(intervention,
                          levels = c("Biking", "Dance Exergaming", "Music Listening"))
  )
  

#### Filter Participants ####
# AVERAGE HR SHOULD ONLY HAVE 63 OBSERVATIONS
average_HR$participant_id <- as.numeric(gsub("exgm", "", average_HR$participant_id, ignore.case = TRUE))
average_HR <- average_HR %>%
  filter(participant_id %in% participants_to_keep)

#### Plot Boxplot ####
p_avgHR <- ggplot(average_HR, aes(x = intervention, y = avg_hr_bpm, fill = intervention)) +
  geom_boxplot(width = 0.6, alpha = 0.3, outlier.shape = NA, linewidth = 0.6) +
  ggbeeswarm::geom_beeswarm(aes(color = intervention), alpha = 0.6, size = 2, cex = 3) +
  scale_fill_manual(values = c(
    "Biking" = "#0072B2",
    "Dance Exergaming" = "#E69F00",
    "Music Listening" = "#009E73"
  )) +
  scale_color_manual(values = c(
    "Biking" = "#0072B2",
    "Dance Exergaming" = "#E69F00",
    "Music Listening" = "#009E73"
  )) +
  labs(x = "Intervention", y = "Average Heart Rate (bpm)") +
  theme_classic(base_size = 12) +
  theme(
    axis.text  = element_text(color = "black", size = 11),
    axis.title = element_text(face = "bold", size = 13),
    legend.position = "none",
    axis.line = element_line(color = "black", linewidth = 0.6),
    axis.ticks = element_line(color = "black", linewidth = 0.6)
  )

print(p_avgHR)

ggsave("results/avg_heart_rate_boxplot.svg", plot = p_avgHR, width = 8, height = 5, units = "in")

#### One-way ANOVA ####
anova_hr <- aov(avg_hr_bpm ~ intervention, data = average_HR)
summary(anova_hr)

#### Post-hoc pairwise comparisons (Tukey) ####
TukeyHSD(anova_hr)

#### Summary Stats ####
avg_hr_summary <- average_HR %>%
  group_by(intervention) %>%
  summarise(
    mean_hr = mean(avg_hr_bpm, na.rm = TRUE),
    sd_hr = sd(avg_hr_bpm, na.rm = TRUE),
    n = n()
  )

# Average Borg ------------------------------------------------------------

#### Calculate Average Borg RPE ####
average_Borg <- exertion_filtered %>%
  group_by(participant_id, intervention) %>%
  summarise(avg_borg = mean(borg_rpe, na.rm = TRUE), .groups = "drop")

#### Plot Boxplot ####
p_avgBorg <- ggplot(average_Borg, aes(x = intervention, y = avg_borg, fill = intervention)) +
  geom_boxplot(width = 0.6, alpha = 0.3, outlier.shape = NA, linewidth = 0.6) +
  ggbeeswarm::geom_beeswarm(aes(color = intervention), alpha = 0.6, size = 2, cex = 3) +
  scale_fill_manual(
    values = c(
      "biking" = "#0072B2",
      "just_dance" = "#E69F00",
      "music_listening" = "#009E73"
    ),
    labels = c(
      "biking" = "Biking",
      "just_dance" = "Dance Exergaming",
      "music_listening" = "Music Listening"
    )
  ) +
  scale_color_manual(
    values = c(
      "biking" = "#0072B2",
      "just_dance" = "#E69F00",
      "music_listening" = "#009E73"
    ),
    labels = c(
      "biking" = "Biking",
      "just_dance" = "Dance Exergaming",
      "music_listening" = "Music Listening"
    )
  ) +
  scale_x_discrete(
    labels = c(
      "biking" = "Biking",
      "just_dance" = "Dance Exergaming",
      "music_listening" = "Music Listening"
    )
  ) +
  labs(x = "Intervention", y = "Average Borg Rating of Perceived Exertion") +
  theme_classic(base_size = 12) +
  theme(
    axis.text  = element_text(color = "black", size = 11),
    axis.title = element_text(face = "bold", size = 13),
    legend.position = "none",
    axis.line = element_line(color = "black", linewidth = 0.6),
    axis.ticks = element_line(color = "black", linewidth = 0.6)
  )

print(p_avgBorg)

ggsave("results/avg_borg_rpe_boxplot.svg", plot = p_avgBorg, width = 8, height = 5, units = "in")

#### One-Way ANOVA ####
anova_borg <- aov(avg_borg ~ intervention, data = average_Borg)
summary(anova_borg)

#### Post-Hoc Comparison ####
TukeyHSD(anova_borg)

#### Summary Stats ####
avg_borg_summary <- average_Borg %>%
  group_by(intervention) %>%
  summarise(
    mean_borg = mean(avg_borg, na.rm = TRUE),
    sd_borg = sd(avg_borg, na.rm = TRUE),
    n = n()
  )

# HR and Borg Correlation -------------------------------------------------

cor_data <- exertion_filtered %>%
  group_by(participant_id) %>%
  summarise(
    mean_hr = mean(hr, na.rm = TRUE),
    mean_borg = mean(borg_rpe, na.rm = TRUE),
    .groups = "drop"
  )

cor_data <- exertion_filtered %>%
  group_by(participant_id, intervention) %>%
  summarise(
    mean_hr   = mean(hr, na.rm = TRUE),
    mean_borg = mean(borg_rpe, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    int_raw = str_squish(str_to_lower(as.character(intervention))),
    intervention = case_when(
      str_detect(int_raw, "bike") ~ "Biking",
      str_detect(int_raw, "dance") ~ "Dance Exergaming",
      str_detect(int_raw, "listen") ~ "Music Listening",
      TRUE ~ str_to_title(int_raw)
    )
  ) %>%
  select(-int_raw)

pal <- c("Biking" = "#0072B2",
         "Dance Exergaming" = "#E69F00",
         "Music Listening" = "#009E73")

cor_data <- cor_data %>%
  mutate(intervention = factor(intervention, levels = names(pal)))

print(levels(cor_data$intervention))

p_corr <- ggplot(cor_data, aes(x = mean_hr, y = mean_borg, color = intervention)) +
  geom_point(size = 2.5, alpha = 0.9) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1) +
  scale_color_manual(values = pal, breaks = names(pal)) +
  labs(
    x = "Average Heart Rate (bpm)",
    y = "Average Borg RPE (6–20)",
    title = "Heart Rate vs. Perceived Exertion by Intervention",
    color = "Intervention"
  ) +
  theme_classic(base_size = 12) +
  theme(
    axis.text  = element_text(color = "black", size = 11),
    axis.title = element_text(face = "bold", size = 13),
    plot.title = element_text(face = "bold", size = 14),
    legend.position = c(0.85, 0.15),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.5)
  )

corr_by_int <- cor_data %>%
  group_by(intervention) %>%
  summarise(
    n = sum(complete.cases(mean_hr, mean_borg)),
    r = if (n > 1) cor(mean_hr, mean_borg, use = "complete.obs", method = "pearson") else NA_real_,
    p = if (n > 1) cor.test(mean_hr, mean_borg, method = "pearson")$p.value else NA_real_,
    .groups = "drop"
  )

fmt_p <- function(p) {
  ifelse(is.na(p), "NA",
         ifelse(p < 0.001, "<0.001",
                sprintf("%.3f", p)))
}

legend_labels <- setNames(
  paste0(
    as.character(corr_by_int$intervention),
    " (r=", round(corr_by_int$r, 2),
    ", p=", fmt_p(corr_by_int$p),
    ", n=", corr_by_int$n, ")"
  ),
  as.character(corr_by_int$intervention)
)

p_corr <- ggplot(cor_data, aes(x = mean_hr, y = mean_borg, color = intervention)) +
  geom_point(size = 2.5, alpha = 0.9) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1) +
  scale_color_manual(values = pal,
                     breaks = names(pal),
                     labels = legend_labels[names(pal)]) +
  labs(
    x = "Average Heart Rate (bpm)",
    y = "Average Borg RPE (6–20)",
    title = "Heart Rate vs. Perceived Exertion by Intervention",
    color = "Intervention (r, p, n)"
  ) +
  theme_classic(base_size = 12) +
  theme(
    axis.text  = element_text(color = "black", size = 11),
    axis.title = element_text(face = "bold", size = 13),
    plot.title = element_text(face = "bold", size = 14),
    legend.position = c(0.85, 0.15),
    legend.background = element_rect(fill = "white", color = "black", linewidth = 0.5)
  )

x_pos <- max(cor_data$mean_hr, na.rm = TRUE)
yr <- range(cor_data$mean_borg, na.rm = TRUE)
y_seq <- seq(from = yr[2], to = yr[2] - diff(yr) * 0.25, length.out = length(levels(cor_data$intervention)))

label_df <- corr_by_int |>
  dplyr::mutate(
    x = x_pos,
    y = y_seq[match(as.character(intervention), levels(cor_data$intervention))],
    label = paste0("r=", round(r, 2), ", p=", fmt_p(p))
  )

p_corr <- p_corr +
  geom_text(data = label_df,
            aes(x = x, y = y, label = label, color = intervention),
            hjust = 1, vjust = 1, size = 3.5, show.legend = FALSE)

print(p_corr)

ggsave("results/hr_borg_correlation_plot.png",
       plot = p_corr, width = 6.5, height = 4.75, dpi = 300)




