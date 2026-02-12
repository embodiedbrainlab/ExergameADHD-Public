# clean_model_clusters_with_log.R
# Goal: Keep only subjects that appear in model_metrics (from final model
# for Paper 1) for each cluster,
# Save cleaned cluster CSVs, and log per-cluster kept/dropped counts.

library(tidyverse)

# ------------------------------------------------------------------
# Paths (adjust if needed)
# ------------------------------------------------------------------
mm_path  <- "../results/specparam/final_model/model_metrics.csv"
in_dir   <- "../results/IC_clusters/pruned_clusters"
out_dir  <- "../results/IC_clusters/final_model_clusters"

# Ensure output folder exists
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)


# Unique subject x cluster pairs from model_metrics -----------------------
mm_pairs <- readr::read_csv(mm_path, show_col_types = FALSE) %>%
  transmute(
    subject = as.character(subject),
    cluster = as.integer(cluster)
  ) %>%
  drop_na(subject, cluster) %>%
  distinct()


# Function to clean one cluster file + return a small log row -------------
clean_one_cluster <- function(k) {
  # Preferred file: "Cls_{k}_prune.csv"
  infile <- file.path(in_dir, sprintf("Cls_%d_prune.csv", k))
  # Fallback: "Cls_{k}.csv"
  if (!file.exists(infile)) {
    alt <- file.path(in_dir, sprintf("Cls_%d.csv", k))
    if (file.exists(alt)) infile <- alt
  }
  
  if (!file.exists(infile)) {
    message(sprintf(">> Cluster %2d: file not found, skipping.", k))
    return(tibble(
      cluster              = k,
      file_in              = NA_character_,
      n_subjects_in_model  = mm_pairs %>% filter(cluster == k) %>% n_distinct(subject),
      n_subjects_input     = NA_integer_,
      n_subjects_kept      = NA_integer_,
      n_subjects_dropped   = NA_integer_,
      n_rows_input         = NA_integer_,
      n_rows_kept          = NA_integer_,
      n_rows_dropped       = NA_integer_,
      file_out             = NA_character_,
      status               = "file_not_found"
    ))
  }
  
  # Read the cluster file
  df_in <- readr::read_csv(infile, show_col_types = FALSE) %>%
    mutate(subject = as.character(subject))
  
  # Subjects allowed for this cluster (from model_metrics)
  keep_subjects <- mm_pairs %>%
    filter(cluster == k) %>%
    pull(subject) %>%
    unique()
  
  # Filter rows
  df_out <- df_in %>%
    semi_join(tibble(subject = keep_subjects), by = "subject")
  
  # Prepare counts
  n_subj_model   <- length(keep_subjects)
  n_subj_input   <- df_in  %>% distinct(subject) %>% nrow()
  n_subj_kept    <- df_out %>% distinct(subject) %>% nrow()
  n_subj_dropped <- n_subj_input - n_subj_kept
  
  n_rows_input   <- nrow(df_in)
  n_rows_kept    <- nrow(df_out)
  n_rows_dropped <- n_rows_input - n_rows_kept
  
  # Write cleaned file
  outfile <- file.path(out_dir, sprintf("Cls_%d_prune_clean.csv", k))
  readr::write_csv(df_out, outfile)
  
  # Lightweight console message
  message(sprintf(
    ">> Cluster %2d: subjects kept=%-3d dropped=%-3d | rows kept=%-5d dropped=%-5d",
    k, n_subj_kept, n_subj_dropped, n_rows_kept, n_rows_dropped
  ))
  
  tibble(
    cluster              = k,
    file_in              = basename(infile),
    n_subjects_in_model  = n_subj_model,
    n_subjects_input     = n_subj_input,
    n_subjects_kept      = n_subj_kept,
    n_subjects_dropped   = n_subj_dropped,
    n_rows_input         = n_rows_input,
    n_rows_kept          = n_rows_kept,
    n_rows_dropped       = n_rows_dropped,
    file_out             = basename(outfile),
    status               = "ok"
  )
}


# Run for clusters 3..13, save a CSV log, and print a compact summ --------

clusters <- 3:13

log_tbl <- purrr::map_dfr(clusters, clean_one_cluster)

# Save the log to the output directory
log_path <- file.path(out_dir, "cluster_cleaning_log.csv")
readr::write_csv(log_tbl, log_path)

# (Optional) Print a compact on-screen summary of kept/dropped subjects
log_tbl %>%
  select(cluster, n_subjects_input, n_subjects_kept, n_subjects_dropped) %>%
  arrange(cluster) %>%
  print(n = Inf)

# If you ever want a plain-text log as well, uncomment:
# txt_path <- file.path(out_dir, "cluster_cleaning_log.txt")
# readr::write_lines(
#   paste0(capture.output(
#     log_tbl %>%
#       select(cluster, n_subjects_input, n_subjects_kept, n_subjects_dropped) %>%
#       arrange(cluster) %>%
#       print(n = Inf)
#   ), collapse = "\n"),
#   txt_path
# )
