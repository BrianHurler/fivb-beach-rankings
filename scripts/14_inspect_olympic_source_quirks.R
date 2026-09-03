library(dplyr)
library(tibble)

parsed_file <- file.path(
  "data", "olympic", "parsed", "fivb_olympic_ranking_entries.rds"
)
qa_dir <- file.path("data", "olympic", "qa")
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(parsed_file)) {
  stop("Missing parsed Olympic archive. Run scripts/12_parse_olympic_archive.R first.", call. = FALSE)
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
    )
  )

# ---- Undocumented Tokyo status 10 ------------------------------------------
status10_rows <- x |>
  filter(Status == 10) |>
  arrange(gender, reference_date, Position) |>
  select(
    games_year, gender, reference_date, Position, SelectionRank,
    TeamName, TeamCountryCode, NoPlayer1, NoPlayer2,
    NbParticipations, Points, Status, StatusLabel
  )

status10_summary <- status10_rows |>
  group_by(games_year, gender) |>
  summarise(
    rows = n(),
    distinct_pairs = n_distinct(paste(pmin(NoPlayer1, NoPlayer2), pmax(NoPlayer1, NoPlayer2), sep = "|")),
    first_date = min(reference_date),
    last_date = max(reference_date),
    min_position = min(Position, na.rm = TRUE),
    max_position = max(Position, na.rm = TRUE),
    .groups = "drop"
  )

utils::write.csv(
  status10_rows,
  file.path(qa_dir, "olympic_status10_rows.csv"),
  row.names = FALSE
)
utils::write.csv(
  status10_summary,
  file.path(qa_dir, "olympic_status10_summary.csv"),
  row.names = FALSE
)

# Add adjacent-snapshot context for every pair that ever receives Status 10.
status10_pairs <- status10_rows |>
  transmute(
    gender,
    pair_key = paste(pmin(NoPlayer1, NoPlayer2), pmax(NoPlayer1, NoPlayer2), sep = "|")
  ) |>
  distinct()

status10_history <- x |>
  semi_join(status10_pairs, by = c("gender", "pair_key")) |>
  filter(games_year == 2020) |>
  arrange(gender, pair_key, reference_date, Position) |>
  select(
    games_year, gender, reference_date, pair_key,
    Position, SelectionRank, TeamName, TeamCountryCode,
    NbParticipations, Points, Status, StatusLabel
  )

utils::write.csv(
  status10_history,
  file.path(qa_dir, "olympic_status10_pair_history.csv"),
  row.names = FALSE
)

# ---- Duplicate pair keys within a snapshot ---------------------------------
duplicate_pair_groups <- x |>
  filter(!is.na(pair_key)) |>
  count(games_year, gender, reference_date, pair_key, name = "rows_for_pair") |>
  filter(rows_for_pair > 1L) |>
  arrange(games_year, gender, reference_date, pair_key)

duplicate_pair_rows <- x |>
  semi_join(
    duplicate_pair_groups,
    by = c("games_year", "gender", "reference_date", "pair_key")
  ) |>
  arrange(games_year, gender, reference_date, pair_key, Position) |>
  select(
    games_year, gender, reference_date, pair_key,
    Position, SelectionRank, TeamName, TeamCountryCode,
    NoPlayer1, NoPlayer2, NbParticipations, Points, Status, StatusLabel
  )

duplicate_pair_summary <- duplicate_pair_groups |>
  group_by(games_year, gender) |>
  summarise(
    snapshots_with_duplicate_pair = n_distinct(reference_date),
    duplicate_pair_groups = n(),
    extra_rows_from_duplicate_pairs = sum(rows_for_pair - 1L),
    first_date = min(reference_date),
    last_date = max(reference_date),
    .groups = "drop"
  )

# Diagnose whether duplicate rows differ by order, points, status, or selection rank.
duplicate_pair_characteristics <- duplicate_pair_rows |>
  group_by(games_year, gender, reference_date, pair_key) |>
  summarise(
    rows = n(),
    positions = paste(Position, collapse = ","),
    team_names = paste(unique(TeamName), collapse = " | "),
    player_orders = paste(paste(NoPlayer1, NoPlayer2, sep = "/"), collapse = " | "),
    distinct_points = n_distinct(Points, na.rm = FALSE),
    points = paste(Points, collapse = ","),
    distinct_selection_ranks = n_distinct(SelectionRank, na.rm = FALSE),
    selection_ranks = paste(SelectionRank, collapse = ","),
    distinct_statuses = n_distinct(Status, na.rm = FALSE),
    statuses = paste(Status, collapse = ","),
    reversed_player_order = n_distinct(paste(NoPlayer1, NoPlayer2, sep = "|")) > 1L,
    .groups = "drop"
  )

utils::write.csv(
  duplicate_pair_rows,
  file.path(qa_dir, "olympic_duplicate_pair_rows.csv"),
  row.names = FALSE
)
utils::write.csv(
  duplicate_pair_summary,
  file.path(qa_dir, "olympic_duplicate_pair_summary.csv"),
  row.names = FALSE
)
utils::write.csv(
  duplicate_pair_characteristics,
  file.path(qa_dir, "olympic_duplicate_pair_characteristics.csv"),
  row.names = FALSE
)

cat("\nUNDOCUMENTED STATUS 10 SUMMARY\n\n")
if (nrow(status10_summary) == 0L) {
  cat("No Status 10 rows found.\n")
} else {
  print(status10_summary, n = Inf, width = Inf)
  cat("\nSTATUS 10 ROWS (first 30)\n\n")
  print(status10_rows |> slice_head(n = 30), n = 30, width = Inf)
}

cat("\nDUPLICATE PAIR SUMMARY\n\n")
if (nrow(duplicate_pair_summary) == 0L) {
  cat("No duplicate player-pair keys found within snapshots.\n")
} else {
  print(duplicate_pair_summary, n = Inf, width = Inf)

  cat("\nDUPLICATE PAIR CHARACTERISTICS (first 40 groups)\n\n")
  print(
    duplicate_pair_characteristics |> slice_head(n = 40),
    n = 40,
    width = Inf
  )
}

message(
  "Olympic source-quirk diagnostics written to ",
  normalizePath(qa_dir, mustWork = FALSE)
)
