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
  mutate(pair_name_key = normalize_pair_name(published_name))

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

comparison <- expected |>
  left_join(
    actual,
    by = c("ranking_gender", "pair_name_key")
  ) |>
  mutate(
    found_in_vis = !is.na(vis_name),
    position_match = found_in_vis & published_position == vis_position,
    points_match = found_in_vis & dplyr::near(published_points, vis_points),
    exact_match = found_in_vis & position_match & points_match
  ) |>
  arrange(ranking_gender, published_position, published_name)

summary <- comparison |>
  group_by(ranking_gender, gender_name) |>
  summarise(
    published_rows = n(),
    found_in_vis = sum(found_in_vis),
    position_matches = sum(position_match),
    points_matches = sum(points_match),
    exact_matches = sum(exact_match),
    all_rows_exact = all(exact_match),
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

cat("\nFEBRUARY 13, 2017 PUBLISHED WORLD RANKING VALIDATION\n\n")
print(summary, n = Inf)

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
      exact_match
    ),
  n = Inf
)

if (all(summary$all_rows_exact)) {
  message(
    "Exact validation passed: the archived Type 9 snapshot matches all ",
    nrow(expected),
    " published February 13, 2017 World Ranking rows."
  )
} else {
  message(
    "Validation was not fully exact. Inspect data/validation/",
    "feb2017_world_ranking_comparison.csv for discrepancies."
  )
}
