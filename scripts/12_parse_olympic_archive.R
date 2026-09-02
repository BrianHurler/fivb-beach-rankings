library(dplyr)
library(purrr)
library(tibble)

source("R/olympic_ranking.R")

raw_dir <- file.path("data", "olympic", "raw")
parsed_dir <- file.path("data", "olympic", "parsed")
dir.create(parsed_dir, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(raw_dir)) {
  stop(
    "Missing Olympic raw archive. Run scripts/11_download_olympic_archive.R first.",
    call. = FALSE
  )
}

raw_files <- list.files(
  raw_dir,
  pattern = "^olympic_[0-9]{4}_[MW]_[0-9]{4}-[0-9]{2}-[0-9]{2}\\.xml$",
  full.names = TRUE
) |>
  sort()

if (length(raw_files) == 0L) {
  stop("No Olympic raw XML files found in ", raw_dir, call. = FALSE)
}

parse_file_metadata <- function(path) {
  name <- basename(path)
  m <- regexec(
    "^olympic_([0-9]{4})_([MW])_([0-9]{4}-[0-9]{2}-[0-9]{2})\\.xml$",
    name
  )
  parts <- regmatches(name, m)[[1]]

  if (length(parts) != 4L) {
    stop("Unexpected Olympic archive filename: ", name, call. = FALSE)
  }

  list(
    games_year = as.integer(parts[[2]]),
    gender = parts[[3]],
    reference_date = as.Date(parts[[4]])
  )
}

parse_one_file <- function(path) {
  meta <- parse_file_metadata(path)
  body <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  parsed <- parse_olympic_ranking_body(
    body,
    requested_games_year = meta$games_year,
    requested_gender = meta$gender,
    requested_reference_date = meta$reference_date
  )

  if (nrow(parsed$entries) == 0L) {
    stop("Olympic archive file has zero entries: ", path, call. = FALSE)
  }

  parsed$entries |>
    mutate(source_file = basename(path), .after = requested_reference_date)
}

message("Parsing ", length(raw_files), " Olympic ranking XML files.")

entries <- purrr::map_dfr(seq_along(raw_files), function(i) {
  if (i %% 25L == 0L || i == 1L || i == length(raw_files)) {
    message("Parsing [", i, "/", length(raw_files), "] ", basename(raw_files[[i]]))
  }
  parse_one_file(raw_files[[i]])
}) |>
  rename(
    games_year = requested_games_year,
    gender = requested_gender,
    reference_date = requested_reference_date
  ) |>
  arrange(games_year, reference_date, gender, Position)

rds_path <- file.path(parsed_dir, "fivb_olympic_ranking_entries.rds")
csv_path <- file.path(parsed_dir, "fivb_olympic_ranking_entries.csv")
summary_path <- file.path(parsed_dir, "fivb_olympic_ranking_summary.csv")

saveRDS(entries, rds_path)
utils::write.csv(entries, csv_path, row.names = FALSE)

summary <- entries |>
  group_by(games_year, gender) |>
  summarise(
    snapshots = n_distinct(reference_date),
    rows = n(),
    first_reference_date = min(reference_date),
    last_reference_date = max(reference_date),
    max_position = max(Position, na.rm = TRUE),
    selected_status_1_3 = sum(Status %in% c(1, 2, 3), na.rm = TRUE),
    already_qualified_other_pathway = sum(Status == 9, na.rm = TRUE),
    .groups = "drop"
  )

utils::write.csv(summary, summary_path, row.names = FALSE)

cat("\nOLYMPIC ARCHIVE PARSE SUMMARY\n\n")
print(summary, n = Inf, width = Inf)

cat("\nOVERALL\n\n")
print(
  tibble(
    rows = nrow(entries),
    snapshots = n_distinct(paste(entries$games_year, entries$gender, entries$reference_date)),
    distinct_reference_dates = n_distinct(paste(entries$games_year, entries$reference_date)),
    first_reference_date = min(entries$reference_date),
    last_reference_date = max(entries$reference_date)
  )
)

message("Parsed Olympic archive written to ", normalizePath(parsed_dir, mustWork = FALSE))
