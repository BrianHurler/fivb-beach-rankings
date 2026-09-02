library(dplyr)
library(tibble)

parsed_file <- file.path(
  "data",
  "parsed",
  "fivb_historical_ranking_entries.rds"
)

validation_dir <- file.path("data", "validation")
dir.create(validation_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(parsed_file)) {
  stop(
    "Missing parsed ranking archive. Run scripts/04_parse_archive.R first.",
    call. = FALSE
  )
}

ranking_entries <- readRDS(parsed_file)
target_date <- as.Date("2017-02-13")

normalize_pair_name <- function(x) {
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)

  vapply(
    strsplit(x, "/", fixed = TRUE),
    function(parts) {
      parts <- gsub("[^a-z0-9]", "", parts)
      paste(sort(parts), collapse = "/")
    },
    character(1)
  )
}

# Contemporaneous published FIVB World Ranking reproduced by VolleyMob,
# dated February 13, 2017.
#
# Note: the published table displays ties by printing the rank once and leaving
# the following tied row blank. We therefore treat a VIS sequential Position as
# compatible when it falls anywhere inside the block of rows sharing the same
# point total.
expected <- tribble(
  ~ranking_gender, ~gender_name, ~published_position, ~published_name, ~published_points,
  0L, "Men",   1L, "Lucena/Dalhausser",        4920,
  0L, "Men",   2L, "Samoilovs/Smedins",        4650,
  0L, "Men",   3L, "Alison/Bruno Schmidt",     4620,
  0L, "Men",   4L, "Pedro Solberg/Evandro",    4450,
  0L, "Men",   5L, "Losiak/Kantor",            3800,
  0L, "Men",   6L, "Brouwer/Meeuwsen",         3790,
  0L, "Men",   7L, "Guto/Saymon",              3680,
  0L, "Men",   8L, "Herrera/Gavira",           3620,
  0L, "Men",   9L, "Nicolai/Lupo",             3520,
  0L, "Men",   9L, "Gibb/Patterson",            3520,
  1L, "Women", 1L, "Larissa/Talita",           5420,
  1L, "Women", 2L, "Walsh Jennings/Ross",      5160,
  1L, "Women", 3L, "Ludwig/Walkenhorst",       5080,
  1L, "Women", 4L, "Laboureur/Sude",           4170,
  1L, "Women", 5L, "Borger/Buthe",             3840,
  1L, "Women", 6L, "Liliana/Elsa",             3730,
  1L, "Women", 7L, "Duda/Elize Maia",          3320,
  1L, "Women", 8L, "Meppelink/van Iersel",     3290,
  1L, "Women", 9L, "Holtwick/Semmler",         3260,
  1L, "Women", 10L, "Heidrich/Zumkehr",        3180
) |>
  mutate(
    expected_id = row_number(),
    pair_name_key = normalize_pair_name(published_name)
  )

actual <- ranking_entries |>
  filter(
    ranking_type == 9L,
    ranking_date == target_date
  ) |>
  transmute(
    ranking_gender,
    vis_position = Position,
    vis_rank = Rank,
    vis_name = Name,
    vis_points = Points,
    vis_ranking_no = ranking_no,
    pair_name_key = normalize_pair_name(Name)
  )

if (nrow(actual) == 0L) {
  available_dates <- ranking_entries |>
    filter(ranking_type == 9L) |>
    distinct(ranking_date) |>
    mutate(distance_days = abs(as.integer(ranking_date - target_date))) |>
    arrange(distance_days, ranking_date) |>
    slice_head(n = 10)

  print(available_dates)

  stop(
    "No Type 9 ranking exists on 2017-02-13. Nearest dates printed above.",
    call. = FALSE
  )
}

# Canonicalize exact duplicate name keys within gender. This keeps the best
# sequential position while preserving the original snapshot separately below.
actual_by_name <- actual |>
  arrange(ranking_gender, vis_position) |>
  distinct(ranking_gender, pair_name_key, .keep_all = TRUE)

# First-pass match by normalized team name.
comparison <- expected |>
  left_join(
    actual_by_name,
    by = c("ranking_gender", "pair_name_key")
  ) |>
  mutate(match_method = if_else(!is.na(vis_name), "name", NA_character_))

# For names that do not normalize identically, use a conservative fallback:
# match by points only when that point total identifies exactly one VIS row for
# the gender on this date. This is intended to surface historical naming aliases
# such as surname variants, initials, or shortened player names without forcing
# ambiguous matches.
unique_point_candidates <- actual |>
  group_by(ranking_gender, vis_points) |>
  mutate(point_candidate_count = n()) |>
  ungroup() |>
  filter(point_candidate_count == 1L) |>
  select(
    ranking_gender,
    vis_points,
    fallback_position = vis_position,
    fallback_rank = vis_rank,
    fallback_name = vis_name,
    fallback_ranking_no = vis_ranking_no
  )

comparison <- comparison |>
  left_join(
    unique_point_candidates,
    by = c("ranking_gender", "published_points" = "vis_points")
  ) |>
  mutate(
    use_points_fallback = is.na(vis_name) & !is.na(fallback_name),
    vis_position = if_else(use_points_fallback, fallback_position, vis_position),
    vis_rank = if_else(use_points_fallback, fallback_rank, vis_rank),
    vis_name = if_else(use_points_fallback, fallback_name, vis_name),
    vis_points = if_else(use_points_fallback, published_points, vis_points),
    vis_ranking_no = if_else(use_points_fallback, fallback_ranking_no, vis_ranking_no),
    match_method = if_else(use_points_fallback, "unique_points", match_method)
  ) |>
  select(-starts_with("fallback_"), -use_points_fallback)

# Determine the VIS position range occupied by each point total. This makes the
# validation robust to tied teams being listed in either sequential order.
point_position_ranges <- actual |>
  group_by(ranking_gender, vis_points) |>
  summarise(
    point_position_min = min(vis_position, na.rm = TRUE),
    point_position_max = max(vis_position, na.rm = TRUE),
    point_rows = n(),
    .groups = "drop"
  )

comparison <- comparison |>
  left_join(
    point_position_ranges,
    by = c("ranking_gender", "published_points" = "vis_points")
  ) |>
  mutate(
    found_in_vis = !is.na(vis_name),
    name_match = found_in_vis & pair_name_key == normalize_pair_name(vis_name),
    points_match = found_in_vis & dplyr::near(published_points, vis_points),
    exact_position_match = found_in_vis & published_position == vis_position,
    tie_compatible_position = found_in_vis &
      points_match &
      published_position >= point_position_min &
      published_position <= point_position_max,
    position_match = exact_position_match | tie_compatible_position,
    ranking_match = found_in_vis & points_match & position_match
  ) |>
  arrange(ranking_gender, published_position, published_name)

summary <- comparison |>
  group_by(ranking_gender, gender_name) |>
  summarise(
    published_rows = n(),
    found_in_vis = sum(found_in_vis),
    name_matches = sum(name_match),
    points_matches = sum(points_match),
    exact_position_matches = sum(exact_position_match),
    tie_compatible_position_matches = sum(position_match),
    ranking_matches = sum(ranking_match),
    all_rows_ranking_match = all(ranking_match),
    .groups = "drop"
  )

utils::write.csv(
  comparison,
  file.path(validation_dir, "feb2017_world_ranking_comparison.csv"),
  row.names = FALSE
)

utils::write.csv(
  summary,
  file.path(validation_dir, "feb2017_world_ranking_summary.csv"),
  row.names = FALSE
)

utils::write.csv(
  actual |>
    arrange(ranking_gender, vis_position),
  file.path(validation_dir, "feb2017_type9_actual_snapshot.csv"),
  row.names = FALSE
)

cat("\nFEBRUARY 13, 2017 PUBLISHED WORLD RANKING VALIDATION\n\n")
print(summary, n = Inf, width = Inf)

cat("\nROW-BY-ROW COMPARISON\n\n")
print(
  comparison |>
    select(
      gender_name,
      published_position,
      published_name,
      published_points,
      vis_position,
      vis_name,
      vis_points,
      match_method,
      name_match,
      points_match,
      position_match,
      ranking_match
    ),
  n = Inf,
  width = Inf
)

if (all(summary$all_rows_ranking_match)) {
  message(
    "Ranking validation passed: all ",
    nrow(expected),
    " published February 13, 2017 rows match the archived Type 9 ranking ",
    "after accounting for tied sequential positions and historical name aliases."
  )
} else {
  message(
    "Validation still has unresolved rows. Inspect data/validation/",
    "feb2017_world_ranking_comparison.csv and feb2017_type9_actual_snapshot.csv."
  )
}
