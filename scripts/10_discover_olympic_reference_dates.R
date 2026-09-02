library(dplyr)
library(tibble)

source("R/olympic_ranking.R")

discovery_dir <- file.path("data", "olympic_discovery")
dir.create(discovery_dir, recursive = TRUE, showWarnings = FALSE)

checkpoint_file <- file.path(discovery_dir, "olympic_reference_date_scan.csv")
reference_dates_file <- file.path(discovery_dir, "olympic_reference_dates.csv")
summary_file <- file.path(discovery_dir, "olympic_reference_date_summary.csv")

# Scan the full Olympic-ranking window one calendar date at a time because VIS
# exposes ReferenceDate but no Olympic-ranking list endpoint. This is deliberately
# exhaustive and resumable: an exact date with no calculated ranking returns an
# empty ranking, while a stored snapshot returns rows.
#
# Tokyo's original Olympic Ranking window began 2018-09-01 and was extended after
# the postponement through the final ranking in June 2021.
cycle_windows <- tibble::tribble(
  ~games_year, ~scan_start, ~scan_end,
  2012L, as.Date("2011-01-01"), as.Date("2012-06-18"),
  2016L, as.Date("2015-01-01"), as.Date("2016-06-12"),
  2020L, as.Date("2018-09-01"), as.Date("2021-06-14"),
  2024L, as.Date("2023-01-01"), as.Date("2024-06-10")
)

build_scan_plan <- function() {
  bind_rows(lapply(seq_len(nrow(cycle_windows)), function(i) {
    row <- cycle_windows[i, ]
    dates <- seq.Date(row$scan_start, row$scan_end, by = "day")

    bind_rows(lapply(c("M", "W"), function(gender_value) {
      tibble(
        games_year = row$games_year,
        gender = gender_value,
        reference_date = dates
      )
    }))
  })) |>
    arrange(games_year, reference_date, gender)
}

read_checkpoint <- function() {
  if (!file.exists(checkpoint_file)) {
    return(tibble(
      games_year = integer(),
      gender = character(),
      reference_date = as.Date(character()),
      ok = logical(),
      rows = integer(),
      error = character()
    ))
  }

  read.csv(checkpoint_file, stringsAsFactors = FALSE) |>
    as_tibble() |>
    mutate(
      games_year = as.integer(games_year),
      reference_date = as.Date(reference_date),
      ok = as.logical(ok),
      rows = as.integer(rows)
    )
}

write_checkpoint <- function(x) {
  x |>
    arrange(games_year, reference_date, gender) |>
    utils::write.csv(checkpoint_file, row.names = FALSE)
}

scan_one <- function(games_year, gender, reference_date) {
  result <- tryCatch(
    get_olympic_ranking(
      gender = gender,
      games_year = games_year,
      reference_date = reference_date,
      fields = c("GamesYear", "Position")
    ),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    return(tibble(
      games_year = games_year,
      gender = gender,
      reference_date = reference_date,
      ok = FALSE,
      rows = NA_integer_,
      error = conditionMessage(result)
    ))
  }

  tibble(
    games_year = games_year,
    gender = gender,
    reference_date = reference_date,
    ok = TRUE,
    rows = nrow(result$entries),
    error = NA_character_
  )
}

scan_plan <- build_scan_plan()
scan_results <- read_checkpoint()

# Successful requests are permanent discovery results. Failed requests are retried
# on the next run so temporary HTTP/network problems do not create false gaps.
done_keys <- scan_results |>
  filter(ok) |>
  transmute(key = paste(games_year, gender, reference_date, sep = "|")) |>
  pull(key)

pending <- scan_plan |>
  mutate(key = paste(games_year, gender, reference_date, sep = "|")) |>
  filter(!key %in% done_keys) |>
  select(-key)

message(
  "Olympic reference-date discovery: ",
  nrow(scan_plan), " total date/gender probes; ",
  nrow(scan_plan) - nrow(pending), " already completed; ",
  nrow(pending), " pending."
)

if (nrow(pending) > 0L) {
  for (i in seq_len(nrow(pending))) {
    row <- pending[i, ]

    result <- scan_one(
      games_year = row$games_year,
      gender = row$gender,
      reference_date = row$reference_date
    )

    # Replace a prior failed row for this key, if present.
    scan_results <- scan_results |>
      filter(!(
        games_year == row$games_year &
          gender == row$gender &
          reference_date == row$reference_date
      )) |>
      bind_rows(result)

    if (isTRUE(result$ok[[1]]) && !is.na(result$rows[[1]]) && result$rows[[1]] > 0L) {
      message(
        "FOUND | GamesYear=", row$games_year,
        " | ", row$gender,
        " | ", row$reference_date,
        " | rows=", result$rows[[1]]
      )
    } else if (i %% 50L == 0L) {
      message(
        "Progress: ", i, "/", nrow(pending),
        " pending probes checked in this run."
      )
    }

    if (i %% 25L == 0L || i == nrow(pending)) {
      write_checkpoint(scan_results)
    }

    Sys.sleep(0.10)
  }
}

write_checkpoint(scan_results)

reference_dates <- scan_results |>
  filter(ok, !is.na(rows), rows > 0L) |>
  arrange(games_year, reference_date, gender)

utils::write.csv(reference_dates, reference_dates_file, row.names = FALSE)

summary <- reference_dates |>
  group_by(games_year, gender) |>
  summarise(
    snapshots = n(),
    first_reference_date = min(reference_date),
    last_reference_date = max(reference_date),
    min_rows = min(rows),
    max_rows = max(rows),
    .groups = "drop"
  )

utils::write.csv(summary, summary_file, row.names = FALSE)

paired_dates <- reference_dates |>
  count(games_year, reference_date, name = "genders_with_snapshot") |>
  group_by(games_year) |>
  summarise(
    distinct_reference_dates = n(),
    dates_with_both_genders = sum(genders_with_snapshot == 2L),
    dates_with_one_gender_only = sum(genders_with_snapshot == 1L),
    .groups = "drop"
  )

errors <- scan_results |>
  filter(!ok)

cat("\nOLYMPIC REFERENCE-DATE DISCOVERY SUMMARY\n\n")
print(summary, n = Inf, width = Inf)

cat("\nREFERENCE-DATE GENDER ALIGNMENT\n\n")
print(paired_dates, n = Inf, width = Inf)

cat("\nDISCOVERED REFERENCE DATES\n\n")
print(
  reference_dates |>
    select(games_year, gender, reference_date, rows),
  n = Inf,
  width = Inf
)

if (nrow(errors) > 0L) {
  message(
    nrow(errors),
    " request(s) failed and will be retried automatically the next time this script runs."
  )
}

message(
  "Discovery complete. Outputs written to ",
  normalizePath(discovery_dir, mustWork = FALSE)
)
