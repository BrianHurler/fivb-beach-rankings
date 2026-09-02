library(dplyr)
library(purrr)
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

ranking_entries <- readRDS(parsed_file)

pair_key <- function(player1, player2) {
  out <- rep(NA_character_, length(player1))
  ok <- !is.na(player1) & !is.na(player2)

  out[ok] <- ifelse(
    player1[ok] <= player2[ok],
    paste(player1[ok], player2[ok], sep = "-"),
    paste(player2[ok], player1[ok], sep = "-")
  )

  out
}

safe_share <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(NA_real_)
  mean(x)
}

safe_spearman <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 2L) return(NA_real_)
  suppressWarnings(cor(x[ok], y[ok], method = "spearman"))
}

x <- ranking_entries |>
  mutate(
    pair_key = pair_key(NoPlayer1, NoPlayer2),
    ranking_year = as.integer(format(ranking_date, "%Y"))
  )

# -----------------------------------------------------------------------------
# 1. Basic archive summary by ranking product
# -----------------------------------------------------------------------------

ranking_type_summary <- x |>
  group_by(
    ranking_type,
    type_name,
    ranking_subtype,
    subtype_name,
    ranking_gender,
    gender_name
  ) |>
  summarise(
    rankings = n_distinct(ranking_no),
    rows = n(),
    first_date = min(ranking_date, na.rm = TRUE),
    last_date = max(ranking_date, na.rm = TRUE),
    .groups = "drop"
  )

utils::write.csv(
  ranking_type_summary,
  file.path(audit_dir, "ranking_type_summary.csv"),
  row.names = FALSE
)

# -----------------------------------------------------------------------------
# 2. Type 10 arithmetic: is Points exactly PointsPlayer1 + PointsPlayer2?
# -----------------------------------------------------------------------------

type10_math <- x |>
  filter(ranking_type == 10L) |>
  mutate(
    component_sum = PointsPlayer1 + PointsPlayer2,
    points_equal_component_sum = case_when(
      is.na(Points) | is.na(component_sum) ~ NA,
      TRUE ~ dplyr::near(Points, component_sum)
    )
  )

type10_math_summary <- type10_math |>
  summarise(
    rows = n(),
    rows_with_both_components = sum(!is.na(PointsPlayer1) & !is.na(PointsPlayer2)),
    share_points_equal_component_sum = safe_share(points_equal_component_sum),
    median_points_minus_component_sum = median(
      Points - component_sum,
      na.rm = TRUE
    )
  )

utils::write.csv(
  type10_math_summary,
  file.path(audit_dir, "type10_points_math_summary.csv"),
  row.names = FALSE
)

# -----------------------------------------------------------------------------
# 3. Type 6 -> Type 10 linkage.
#    Does each Type 10 player component equal that player's Type 6 points on the
#    same ranking date? Preserve mismatches for historical investigation.
# -----------------------------------------------------------------------------

athlete_points_raw <- x |>
  filter(ranking_type == 6L) |>
  transmute(
    ranking_date,
    ranking_gender,
    player_id = NoPlayer1,
    athlete_position = Position,
    athlete_points = Points,
    athlete_ranking_no = ranking_no
  ) |>
  filter(!is.na(player_id))

athlete_duplicate_players <- athlete_points_raw |>
  count(ranking_date, ranking_gender, player_id, name = "rows_for_player") |>
  filter(rows_for_player > 1L) |>
  arrange(ranking_date, ranking_gender, desc(rows_for_player), player_id)

utils::write.csv(
  athlete_duplicate_players,
  file.path(audit_dir, "type6_duplicate_players.csv"),
  row.names = FALSE
)

athlete_points <- athlete_points_raw |>
  arrange(ranking_date, ranking_gender, player_id, athlete_position) |>
  distinct(ranking_date, ranking_gender, player_id, .keep_all = TRUE)

team_components <- bind_rows(
  x |>
    filter(ranking_type == 10L) |>
    transmute(
      ranking_date,
      ranking_gender,
      team_ranking_no = ranking_no,
      team_position = Position,
      pair_key,
      player_slot = 1L,
      player_id = NoPlayer1,
      component_points = PointsPlayer1
    ),
  x |>
    filter(ranking_type == 10L) |>
    transmute(
      ranking_date,
      ranking_gender,
      team_ranking_no = ranking_no,
      team_position = Position,
      pair_key,
      player_slot = 2L,
      player_id = NoPlayer2,
      component_points = PointsPlayer2
    )
) |>
  filter(!is.na(player_id))

type6_type10_player_match <- team_components |>
  inner_join(
    athlete_points,
    by = c("ranking_date", "ranking_gender", "player_id")
  ) |>
  mutate(
    exact_points_match = case_when(
      is.na(component_points) | is.na(athlete_points) ~ NA,
      TRUE ~ dplyr::near(component_points, athlete_points)
    ),
    points_difference = component_points - athlete_points,
    abs_points_difference = abs(points_difference),
    ranking_year = as.integer(format(ranking_date, "%Y"))
  )

type6_type10_match_summary <- type6_type10_player_match |>
  group_by(ranking_year) |>
  summarise(
    matched_player_rows = n(),
    share_exact_points_match = safe_share(exact_points_match),
    mismatched_player_rows = sum(exact_points_match %in% FALSE, na.rm = TRUE),
    median_component_minus_athlete = median(points_difference, na.rm = TRUE),
    median_abs_points_difference_mismatches = if_else(
      any(exact_points_match %in% FALSE),
      median(abs_points_difference[exact_points_match %in% FALSE], na.rm = TRUE),
      0
    ),
    max_abs_points_difference = max(abs_points_difference, na.rm = TRUE),
    .groups = "drop"
  )

utils::write.csv(
  type6_type10_match_summary,
  file.path(audit_dir, "type6_vs_type10_player_component_by_year.csv"),
  row.names = FALSE
)

type6_type10_mismatches <- type6_type10_player_match |>
  filter(exact_points_match %in% FALSE) |>
  arrange(ranking_date, ranking_gender, desc(abs_points_difference))

utils::write.csv(
  type6_type10_mismatches,
  file.path(audit_dir, "type6_vs_type10_mismatches.csv"),
  row.names = FALSE
)

# -----------------------------------------------------------------------------
# 4. Type 9 (World) vs Type 10 (Team / PlayerSum).
#    First diagnose duplicate pair keys. Then canonicalize to one row per pair
#    per snapshot before calculating overlap/correlation metrics.
# -----------------------------------------------------------------------------

world_raw <- x |>
  filter(ranking_type == 9L, !is.na(pair_key)) |>
  transmute(
    ranking_date,
    ranking_gender,
    pair_key,
    world_position = Position,
    world_rank = Rank,
    world_name = Name,
    world_federation = FederationCode,
    world_points = Points,
    world_ranking_no = ranking_no
  )

team_raw <- x |>
  filter(ranking_type == 10L, !is.na(pair_key)) |>
  transmute(
    ranking_date,
    ranking_gender,
    pair_key,
    team_position = Position,
    team_rank = Rank,
    team_name = Name,
    team_federation = FederationCode,
    team_points = Points,
    team_ranking_no = ranking_no
  )

world_duplicate_pairs <- world_raw |>
  count(ranking_date, ranking_gender, pair_key, name = "rows_for_pair") |>
  filter(rows_for_pair > 1L)

team_duplicate_pairs <- team_raw |>
  count(ranking_date, ranking_gender, pair_key, name = "rows_for_pair") |>
  filter(rows_for_pair > 1L)

utils::write.csv(
  world_duplicate_pairs,
  file.path(audit_dir, "world_duplicate_pair_keys.csv"),
  row.names = FALSE
)

utils::write.csv(
  team_duplicate_pairs,
  file.path(audit_dir, "team_duplicate_pair_keys.csv"),
  row.names = FALSE
)

world_duplicate_rows <- world_raw |>
  semi_join(
    world_duplicate_pairs,
    by = c("ranking_date", "ranking_gender", "pair_key")
  ) |>
  arrange(ranking_date, ranking_gender, pair_key, world_position)

team_duplicate_rows <- team_raw |>
  semi_join(
    team_duplicate_pairs,
    by = c("ranking_date", "ranking_gender", "pair_key")
  ) |>
  arrange(ranking_date, ranking_gender, pair_key, team_position)

utils::write.csv(
  world_duplicate_rows,
  file.path(audit_dir, "world_duplicate_pair_rows.csv"),
  row.names = FALSE
)

utils::write.csv(
  team_duplicate_rows,
  file.path(audit_dir, "team_duplicate_pair_rows.csv"),
  row.names = FALSE
)

duplicate_pair_summary <- bind_rows(
  world_duplicate_pairs |>
    mutate(product = "World"),
  team_duplicate_pairs |>
    mutate(product = "Team")
) |>
  mutate(
    year = as.integer(format(ranking_date, "%Y")),
    gender_name = if_else(ranking_gender == 0L, "Men", "Women")
  ) |>
  group_by(product, year, ranking_gender, gender_name) |>
  summarise(
    snapshot_pair_keys_duplicated = n(),
    extra_rows_from_duplicates = sum(rows_for_pair - 1L),
    .groups = "drop"
  )

utils::write.csv(
  duplicate_pair_summary,
  file.path(audit_dir, "duplicate_pair_summary_by_year.csv"),
  row.names = FALSE
)

# Canonical comparison tables: keep the highest-ranked occurrence of a pair.
world <- world_raw |>
  arrange(ranking_date, ranking_gender, world_position) |>
  distinct(ranking_date, ranking_gender, pair_key, .keep_all = TRUE)

team <- team_raw |>
  arrange(ranking_date, ranking_gender, team_position) |>
  distinct(ranking_date, ranking_gender, pair_key, .keep_all = TRUE)

common_snapshots <- inner_join(
  world |>
    distinct(ranking_date, ranking_gender),
  team |>
    distinct(ranking_date, ranking_gender),
  by = c("ranking_date", "ranking_gender")
) |>
  arrange(ranking_date, ranking_gender)

compare_snapshot <- function(ranking_date, ranking_gender) {
  date_value <- ranking_date
  gender_value <- ranking_gender

  w <- world |>
    filter(
      .data$ranking_date == .env$date_value,
      .data$ranking_gender == .env$gender_value
    ) |>
    arrange(world_position)

  t <- team |>
    filter(
      .data$ranking_date == .env$date_value,
      .data$ranking_gender == .env$gender_value
    ) |>
    arrange(team_position)

  joined <- inner_join(
    w,
    t,
    by = c("ranking_date", "ranking_gender", "pair_key"),
    relationship = "one-to-one"
  )

  w_top10 <- w |>
    slice_head(n = 10) |>
    pull(pair_key)

  t_top10 <- t |>
    slice_head(n = 10) |>
    pull(pair_key)

  tibble(
    ranking_date = date_value,
    ranking_gender = gender_value,
    gender_name = if_else(gender_value == 0L, "Men", "Women"),
    n_world_unique_pairs = nrow(w),
    n_team_unique_pairs = nrow(t),
    n_pair_overlap = nrow(joined),
    share_world_pairs_in_team = if_else(nrow(w) > 0L, nrow(joined) / nrow(w), NA_real_),
    share_team_pairs_in_world = if_else(nrow(t) > 0L, nrow(joined) / nrow(t), NA_real_),
    top10_overlap = length(intersect(w_top10, t_top10)),
    same_number_one = if_else(
      length(w_top10) > 0L & length(t_top10) > 0L,
      w_top10[[1]] == t_top10[[1]],
      NA
    ),
    spearman_position = safe_spearman(
      joined$world_position,
      joined$team_position
    ),
    share_exact_position = safe_share(
      joined$world_position == joined$team_position
    ),
    share_exact_points = safe_share(
      dplyr::near(joined$world_points, joined$team_points)
    )
  )
}

world_vs_team_by_snapshot <- pmap_dfr(
  common_snapshots,
  compare_snapshot
)

utils::write.csv(
  world_vs_team_by_snapshot,
  file.path(audit_dir, "world_vs_team_by_snapshot.csv"),
  row.names = FALSE
)

world_vs_team_by_year <- world_vs_team_by_snapshot |>
  mutate(year = as.integer(format(ranking_date, "%Y"))) |>
  group_by(year, ranking_gender, gender_name) |>
  summarise(
    snapshots = n(),
    mean_pair_overlap_world_share = mean(share_world_pairs_in_team, na.rm = TRUE),
    mean_pair_overlap_team_share = mean(share_team_pairs_in_world, na.rm = TRUE),
    mean_top10_overlap = mean(top10_overlap, na.rm = TRUE),
    share_same_number_one = mean(same_number_one, na.rm = TRUE),
    median_spearman_position = median(spearman_position, na.rm = TRUE),
    mean_share_exact_position = mean(share_exact_position, na.rm = TRUE),
    mean_share_exact_points = mean(share_exact_points, na.rm = TRUE),
    .groups = "drop"
  )

utils::write.csv(
  world_vs_team_by_year,
  file.path(audit_dir, "world_vs_team_by_year.csv"),
  row.names = FALSE
)

# -----------------------------------------------------------------------------
# 5. Historically useful sample dates.
#    For each target, choose the closest date on which both Type 9 and Type 10 exist.
# -----------------------------------------------------------------------------

target_dates <- as.Date(c(
  "2015-03-23",
  "2016-06-13",
  "2017-02-13",
  "2018-01-01",
  "2021-06-14",
  "2024-06-10",
  "2026-08-31"
))

nearest_common_date <- function(target_date, gender_value) {
  available <- common_snapshots |>
    filter(ranking_gender == gender_value) |>
    pull(ranking_date)

  if (length(available) == 0L) return(as.Date(NA))

  available[[which.min(abs(as.numeric(available - target_date)))]]
}

sample_plan <- bind_rows(
  lapply(c(0L, 1L), function(gender_value) {
    tibble(
      target_date = target_dates,
      ranking_gender = gender_value,
      gender_name = if_else(gender_value == 0L, "Men", "Women"),
      ranking_date = as.Date(
        vapply(
          target_dates,
          function(d) as.character(nearest_common_date(d, gender_value)),
          character(1)
        )
      )
    )
  })
) |>
  arrange(target_date, ranking_gender)

utils::write.csv(
  sample_plan,
  file.path(audit_dir, "historical_sample_plan.csv"),
  row.names = FALSE
)

sample_top20 <- pmap_dfr(
  sample_plan,
  function(target_date, ranking_gender, gender_name, ranking_date) {
    target_date_value <- target_date
    gender_value <- ranking_gender
    gender_label <- gender_name
    ranking_date_value <- ranking_date

    w <- world |>
      filter(
        .data$ranking_date == .env$ranking_date_value,
        .data$ranking_gender == .env$gender_value
      ) |>
      arrange(world_position) |>
      slice_head(n = 20)

    t <- team |>
      filter(
        .data$ranking_date == .env$ranking_date_value,
        .data$ranking_gender == .env$gender_value
      ) |>
      arrange(team_position) |>
      slice_head(n = 20)

    full_join(
      w,
      t,
      by = c("ranking_date", "ranking_gender", "pair_key"),
      relationship = "one-to-one"
    ) |>
      mutate(
        target_date = .env$target_date_value,
        gender_name = .env$gender_label,
        .before = 1
      ) |>
      arrange(
        coalesce(world_position, 999999L),
        coalesce(team_position, 999999L)
      )
  }
)

utils::write.csv(
  sample_top20,
  file.path(audit_dir, "historical_sample_top20_world_vs_team.csv"),
  row.names = FALSE
)

cat("\nTYPE 10 POINT MATH\n")
print(type10_math_summary)

cat("\nTYPE 6 -> TYPE 10 PLAYER COMPONENT MATCH BY YEAR\n")
print(type6_type10_match_summary, n = Inf, width = Inf)

cat("\nDUPLICATE PAIR KEYS BY YEAR\n")
if (nrow(duplicate_pair_summary) == 0L) {
  cat("None.\n")
} else {
  print(duplicate_pair_summary, n = Inf, width = Inf)
}

cat("\nWORLD VS TEAM -- YEARLY SUMMARY (UNIQUE PAIRS)\n")
print(world_vs_team_by_year, n = Inf, width = Inf)

cat("\nHISTORICAL SAMPLE PLAN\n")
print(sample_plan, n = Inf)

message(
  "Audit complete. Outputs written to ",
  normalizePath(audit_dir, mustWork = FALSE)
)
