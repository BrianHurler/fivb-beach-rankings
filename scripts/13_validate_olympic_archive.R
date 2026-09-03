library(dplyr)
library(tibble)

parsed_file <- file.path(
  "data", "olympic", "parsed", "fivb_olympic_ranking_entries.rds"
)
discovery_file <- file.path(
  "data", "olympic_discovery", "olympic_reference_dates.csv"
)
qa_dir <- file.path("data", "olympic", "qa")
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(parsed_file)) {
  stop("Missing parsed Olympic archive. Run scripts/12_parse_olympic_archive.R first.", call. = FALSE)
}
if (!file.exists(discovery_file)) {
  stop("Missing Olympic discovery output. Run scripts/10_discover_olympic_reference_dates.R first.", call. = FALSE)
}

x <- readRDS(parsed_file) |>
  mutate(
    games_year = as.integer(games_year),
    reference_date = as.Date(reference_date),
    Position = as.numeric(Position),
    SelectionRank = as.numeric(SelectionRank),
    Points = as.numeric(Points),
    Status = as.numeric(Status),
    pair_key = if_else(
      !is.na(NoPlayer1) & !is.na(NoPlayer2),
      paste(pmin(NoPlayer1, NoPlayer2), pmax(NoPlayer1, NoPlayer2), sep = "|"),
      NA_character_
    ),
    snapshot_key = paste(games_year, gender, reference_date, sep = "|")
  )

discovery <- read.csv(discovery_file, stringsAsFactors = FALSE) |>
  as_tibble() |>
  transmute(
    games_year = as.integer(games_year),
    gender,
    reference_date = as.Date(reference_date),
    discovered_rows = as.integer(rows),
    snapshot_key = paste(games_year, gender, reference_date, sep = "|")
  )

snapshot_summary <- x |>
  group_by(games_year, gender, reference_date, snapshot_key) |>
  summarise(
    rows = n(),
    min_position = suppressWarnings(min(Position, na.rm = TRUE)),
    max_position = suppressWarnings(max(Position, na.rm = TRUE)),
    distinct_positions = n_distinct(Position, na.rm = TRUE),
    duplicate_positions = n() - n_distinct(Position, na.rm = TRUE),
    duplicate_pair_keys = sum(duplicated(pair_key[!is.na(pair_key)])),
    missing_player1 = sum(is.na(NoPlayer1)),
    missing_player2 = sum(is.na(NoPlayer2)),
    missing_points = sum(is.na(Points)),
    negative_points = sum(!is.na(Points) & Points < 0),
    missing_status = sum(is.na(Status)),
    selected_status_1_3 = sum(Status %in% c(1, 2, 3), na.rm = TRUE),
    status_9 = sum(Status == 9, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    min_position = if_else(is.infinite(min_position), NA_real_, min_position),
    max_position = if_else(is.infinite(max_position), NA_real_, max_position)
  ) |>
  left_join(discovery, by = c("games_year", "gender", "reference_date", "snapshot_key")) |>
  mutate(rows_match_discovery = rows == discovered_rows)

utils::write.csv(
  snapshot_summary,
  file.path(qa_dir, "olympic_snapshot_qa.csv"),
  row.names = FALSE
)

# Compare the parsed archive's exact snapshot set with the exhaustive discovery output.
parsed_keys <- snapshot_summary |>
  distinct(snapshot_key)
discovered_keys <- discovery |>
  distinct(snapshot_key)

missing_from_parsed <- discovered_keys |>
  anti_join(parsed_keys, by = "snapshot_key")
extra_in_parsed <- parsed_keys |>
  anti_join(discovered_keys, by = "snapshot_key")

# Status values are important historical source data. Do not force them into the stale
# documented 1-8 enum: status 9 is retained and empirically interpreted elsewhere.
status_summary <- x |>
  count(games_year, gender, Status, StatusLabel, name = "rows") |>
  arrange(games_year, gender, Status)

utils::write.csv(
  status_summary,
  file.path(qa_dir, "olympic_status_counts.csv"),
  row.names = FALSE
)

# Final reference dates validated from the Olympic qualification systems / VIS archive.
final_dates <- tibble::tribble(
  ~games_year, ~final_reference_date,
  2012L, as.Date("2012-06-18"),
  2016L, as.Date("2016-06-12"),
  2020L, as.Date("2021-06-14"),
  2024L, as.Date("2024-06-10")
)

final_snapshots <- x |>
  inner_join(final_dates, by = "games_year") |>
  filter(reference_date == final_reference_date) |>
  group_by(games_year, gender, reference_date) |>
  summarise(
    rows = n(),
    top_team = TeamName[which.min(Position)],
    top_points = Points[which.min(Position)],
    selected_status_1_3 = sum(Status %in% c(1, 2, 3), na.rm = TRUE),
    status_9 = sum(Status == 9, na.rm = TRUE),
    country_quota = sum(Status == 6, na.rm = TRUE),
    not_enough_tournaments = sum(Status == 5, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(games_year, gender)

utils::write.csv(
  final_snapshots,
  file.path(qa_dir, "olympic_final_snapshot_qa.csv"),
  row.names = FALSE
)

# Known row counts from the retained final VIS rankings. These are hard validation
# targets because each final snapshot was independently probed before the archive run.
expected_finals <- tibble::tribble(
  ~games_year, ~gender, ~expected_rows, ~expected_selected_status_1_3,
  2012L, "M", 288L, 16L,
  2012L, "W", 237L, 16L,
  2016L, "M", 370L, 16L,
  2016L, "W", 305L, 16L,
  2020L, "M", 751L, 16L,
  2020L, "W", 616L, 16L,
  2024L, "M", 673L, 17L,
  2024L, "W", 618L, 17L
)

final_validation <- final_snapshots |>
  left_join(expected_finals, by = c("games_year", "gender")) |>
  mutate(
    rows_match = rows == expected_rows,
    selected_count_match = selected_status_1_3 == expected_selected_status_1_3
  )

utils::write.csv(
  final_validation,
  file.path(qa_dir, "olympic_final_validation.csv"),
  row.names = FALSE
)

overall <- tibble(
  parsed_rows = nrow(x),
  parsed_snapshots = nrow(snapshot_summary),
  discovered_snapshots = nrow(discovery),
  missing_discovered_snapshots = nrow(missing_from_parsed),
  extra_parsed_snapshots = nrow(extra_in_parsed),
  snapshots_with_row_count_mismatch = sum(!snapshot_summary$rows_match_discovery, na.rm = TRUE),
  snapshots_with_duplicate_positions = sum(snapshot_summary$duplicate_positions > 0L, na.rm = TRUE),
  snapshots_with_duplicate_pairs = sum(snapshot_summary$duplicate_pair_keys > 0L, na.rm = TRUE),
  rows_missing_player1 = sum(is.na(x$NoPlayer1)),
  rows_missing_player2 = sum(is.na(x$NoPlayer2)),
  rows_missing_points = sum(is.na(x$Points)),
  rows_with_negative_points = sum(!is.na(x$Points) & x$Points < 0),
  final_row_count_checks_pass = all(final_validation$rows_match),
  final_selected_count_checks_pass = all(final_validation$selected_count_match)
)

cat("\nOLYMPIC ARCHIVE FINAL QA\n\n")
print(overall, width = Inf)

cat("\nFINAL OLYMPIC SNAPSHOTS\n\n")
print(final_validation, n = Inf, width = Inf)

cat("\nSTATUS VALUES BY CYCLE / GENDER\n\n")
print(status_summary, n = Inf, width = Inf)

if (nrow(missing_from_parsed) > 0L) {
  cat("\nDISCOVERED SNAPSHOTS MISSING FROM PARSED ARCHIVE\n\n")
  print(missing_from_parsed, n = Inf, width = Inf)
}

if (nrow(extra_in_parsed) > 0L) {
  cat("\nPARSED SNAPSHOTS NOT PRESENT IN DISCOVERY LIST\n\n")
  print(extra_in_parsed, n = Inf, width = Inf)
}

hard_fail <- nrow(missing_from_parsed) > 0L ||
  nrow(extra_in_parsed) > 0L ||
  any(!snapshot_summary$rows_match_discovery) ||
  !all(final_validation$rows_match) ||
  !all(final_validation$selected_count_match)

if (hard_fail) {
  stop("Olympic archive QA found a hard validation failure. Inspect data/olympic/qa/.", call. = FALSE)
}

message("Olympic archive hard QA checks passed. Diagnostic outputs written to ", normalizePath(qa_dir, mustWork = FALSE))
