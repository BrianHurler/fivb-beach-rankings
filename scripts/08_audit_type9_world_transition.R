library(dplyr)
library(tibble)

parsed_file <- file.path(
  "data",
  "parsed",
  "fivb_historical_ranking_entries.rds"
)

audit_dir <- file.path("data", "audit")
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(parsed_file)) {
  stop(
    "Missing parsed ranking archive. Run scripts/04_parse_archive.R first.",
    call. = FALSE
  )
}

x <- readRDS(parsed_file) |>
  filter(ranking_type == 9L) |>
  mutate(
    taken = NbTakenResultsTeam,
    total = NbTotalResultsTeam,
    expected_best8 = if_else(!is.na(total), pmin(total, 8L), NA_integer_),
    expected_best10 = if_else(!is.na(total), pmin(total, 10L), NA_integer_),
    fits_best8 = !is.na(taken) & !is.na(expected_best8) & taken == expected_best8,
    fits_best10 = !is.na(taken) & !is.na(expected_best10) & taken == expected_best10
  )

safe_mean <- function(z) {
  z <- z[!is.na(z)]
  if (length(z) == 0L) return(NA_real_)
  mean(z)
}

snapshot_summary <- x |>
  group_by(
    ranking_date,
    ranking_gender,
    gender_name,
    ranking_no,
    ranking_version
  ) |>
  summarise(
    rows = n(),
    rows_with_taken = sum(!is.na(taken)),
    rows_with_total = sum(!is.na(total)),
    rows_with_both_counts = sum(!is.na(taken) & !is.na(total)),
    min_taken = if_else(rows_with_taken > 0L, min(taken, na.rm = TRUE), NA_integer_),
    median_taken = if_else(rows_with_taken > 0L, median(taken, na.rm = TRUE), NA_real_),
    max_taken = if_else(rows_with_taken > 0L, max(taken, na.rm = TRUE), NA_integer_),
    max_total = if_else(rows_with_total > 0L, max(total, na.rm = TRUE), NA_integer_),
    share_fit_best8 = safe_mean(fits_best8),
    share_fit_best10 = safe_mean(fits_best10),
    share_taken_eq_8 = safe_mean(taken == 8L),
    share_taken_eq_10 = safe_mean(taken == 10L),
    .groups = "drop"
  ) |>
  arrange(ranking_date, ranking_gender)

utils::write.csv(
  snapshot_summary,
  file.path(audit_dir, "type9_result_count_by_snapshot.csv"),
  row.names = FALSE
)

year_summary <- snapshot_summary |>
  mutate(year = as.integer(format(ranking_date, "%Y"))) |>
  group_by(year, ranking_gender, gender_name) |>
  summarise(
    snapshots = n(),
    snapshots_with_result_counts = sum(rows_with_both_counts > 0L),
    median_share_fit_best8 = median(share_fit_best8, na.rm = TRUE),
    median_share_fit_best10 = median(share_fit_best10, na.rm = TRUE),
    max_taken_observed = suppressWarnings(max(max_taken, na.rm = TRUE)),
    .groups = "drop"
  ) |>
  mutate(
    max_taken_observed = if_else(is.infinite(max_taken_observed), NA_integer_, as.integer(max_taken_observed))
  )

utils::write.csv(
  year_summary,
  file.path(audit_dir, "type9_result_count_by_year.csv"),
  row.names = FALSE
)

# Candidate transition logic:
# A snapshot is "strong best-8 evidence" when at least 95% of rows with populated
# counts equal min(total results, 8). A snapshot is "strong best-10 evidence" under
# the analogous rule. These are diagnostics only; historical regulations remain the
# authoritative definition of the ranking formula.
strong8 <- snapshot_summary |>
  filter(
    rows_with_both_counts >= 25L,
    !is.na(share_fit_best8),
    share_fit_best8 >= 0.95
  )

strong10 <- snapshot_summary |>
  filter(
    rows_with_both_counts >= 25L,
    !is.na(share_fit_best10),
    share_fit_best10 >= 0.95
  )

first_strong8 <- strong8 |>
  group_by(ranking_gender, gender_name) |>
  slice_min(ranking_date, n = 1, with_ties = FALSE) |>
  ungroup()

last_strong10 <- strong10 |>
  group_by(ranking_gender, gender_name) |>
  slice_max(ranking_date, n = 1, with_ties = FALSE) |>
  ungroup()

# Inspect the transition window explicitly. We already have documentary evidence that
# 2016 used a season ranking (best 10 over the season) and that by Feb. 13, 2017 the
# public FIVB World Ranking was a rolling 365-day team ranking; the 2017 regulations
# define it as the best 8 performances together.
transition_window <- snapshot_summary |>
  filter(ranking_date >= as.Date("2016-11-01"),
         ranking_date <= as.Date("2017-03-31"))

utils::write.csv(
  transition_window,
  file.path(audit_dir, "type9_transition_window_2016_2017.csv"),
  row.names = FALSE
)

cat("\nTYPE 9 RESULT-COUNT FIELDS BY YEAR\n\n")
print(year_summary, n = Inf, width = Inf)

cat("\nFIRST SNAPSHOT WITH STRONG BEST-8 COUNT PATTERN\n\n")
if (nrow(first_strong8) == 0L) {
  cat("No snapshots had sufficiently populated result-count fields to establish a best-8 pattern.\n")
} else {
  print(
    first_strong8 |>
      select(
        ranking_gender, gender_name, ranking_date, ranking_no, ranking_version,
        rows_with_both_counts, max_taken, share_fit_best8, share_fit_best10
      ),
    n = Inf,
    width = Inf
  )
}

cat("\nLAST SNAPSHOT WITH STRONG BEST-10 COUNT PATTERN\n\n")
if (nrow(last_strong10) == 0L) {
  cat("No snapshots had sufficiently populated result-count fields to establish a best-10 pattern.\n")
} else {
  print(
    last_strong10 |>
      select(
        ranking_gender, gender_name, ranking_date, ranking_no, ranking_version,
        rows_with_both_counts, max_taken, share_fit_best8, share_fit_best10
      ),
    n = Inf,
    width = Inf
  )
}

cat("\nTYPE 9 TRANSITION WINDOW: NOV 2016 - MAR 2017\n\n")
print(
  transition_window |>
    select(
      ranking_date, ranking_gender, gender_name, ranking_no, ranking_version,
      rows, rows_with_both_counts, max_taken, max_total,
      share_fit_best8, share_fit_best10
    ),
  n = Inf,
  width = Inf
)

message(
  "Transition audit complete. Outputs written to ",
  normalizePath(audit_dir, mustWork = FALSE)
)
