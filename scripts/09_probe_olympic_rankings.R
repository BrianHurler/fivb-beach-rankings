library(dplyr)
library(purrr)
library(tibble)

source("R/olympic_ranking.R")

probe_dir <- file.path("data", "olympic_probe")
raw_dir <- file.path(probe_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# Expected final Olympic-ranking reference dates from the qualification systems.
# ReferenceDate is the date of the ranking calculation, which can differ from
# the following-day public announcement date. Rio's qualification window ended
# on 2016-06-12 and FIVB published the final list on 2016-06-13.
# Tokyo remained GamesYear = 2020 even though the final ranking was in 2021.
cycle_targets <- tibble::tribble(
  ~games_year, ~expected_final_reference_date, ~published_final_date,
  2012L, as.Date("2012-06-18"), as.Date("2012-06-18"),
  2016L, as.Date("2016-06-12"), as.Date("2016-06-13"),
  2020L, as.Date("2021-06-14"), as.Date("2021-06-14"),
  2024L, as.Date("2024-06-10"), as.Date("2024-06-11")
)

probe_one <- function(games_year, gender, reference_date = NULL, label) {
  message(
    "Probing Olympic ranking: GamesYear=", games_year,
    " | gender=", gender,
    " | ", label,
    if (!is.null(reference_date)) paste0(" | ReferenceDate=", reference_date) else ""
  )

  result <- tryCatch(
    get_olympic_ranking(
      gender = gender,
      games_year = games_year,
      reference_date = reference_date
    ),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    return(list(
      summary = tibble(
        games_year = games_year,
        gender = gender,
        probe = label,
        reference_date = if (is.null(reference_date)) as.Date(NA) else as.Date(reference_date),
        ok = FALSE,
        rows = NA_integer_,
        games_year_in_entries = NA_character_,
        selected_rows = NA_integer_,
        already_qualified_other_pathway_rows = NA_integer_,
        root_attributes = NA_character_,
        error = conditionMessage(result)
      ),
      entries = tibble(),
      body = NA_character_
    ))
  }

  entries <- result$entries

  file_tag <- if (is.null(reference_date)) {
    "latest"
  } else {
    format(as.Date(reference_date), "%Y-%m-%d")
  }

  raw_path <- file.path(
    raw_dir,
    paste0("olympic_", games_year, "_", gender, "_", file_tag, ".xml")
  )
  writeLines(result$body, raw_path, useBytes = TRUE)

  selected_rows <- if (nrow(entries) > 0L && "Status" %in% names(entries)) {
    sum(entries$Status %in% c(1, 2, 3), na.rm = TRUE)
  } else {
    0L
  }

  already_qualified_rows <- if (nrow(entries) > 0L && "Status" %in% names(entries)) {
    sum(entries$Status == 9, na.rm = TRUE)
  } else {
    0L
  }

  games_year_values <- if (nrow(entries) > 0L && "GamesYear" %in% names(entries)) {
    paste(sort(unique(entries$GamesYear)), collapse = ",")
  } else {
    NA_character_
  }

  root_attr_text <- if (length(result$root_attributes) > 0L) {
    paste(
      paste(names(result$root_attributes), result$root_attributes, sep = "="),
      collapse = "; "
    )
  } else {
    ""
  }

  list(
    summary = tibble(
      games_year = games_year,
      gender = gender,
      probe = label,
      reference_date = if (is.null(reference_date)) as.Date(NA) else as.Date(reference_date),
      ok = TRUE,
      rows = nrow(entries),
      games_year_in_entries = games_year_values,
      selected_rows = selected_rows,
      already_qualified_other_pathway_rows = already_qualified_rows,
      root_attributes = root_attr_text,
      error = NA_character_
    ),
    entries = entries,
    body = result$body
  )
}

cycle_gender <- bind_rows(
  lapply(c("M", "W"), function(gender_value) {
    cycle_targets |>
      mutate(gender = gender_value)
  })
)

probe_plan <- bind_rows(
  cycle_gender |>
    transmute(
      games_year,
      gender,
      reference_date = expected_final_reference_date,
      probe = "expected_final"
    ),
  cycle_gender |>
    transmute(
      games_year,
      gender,
      reference_date = as.Date(NA),
      probe = "latest_for_cycle"
    )
) |>
  arrange(games_year, gender, probe)

results <- vector("list", nrow(probe_plan))

for (i in seq_len(nrow(probe_plan))) {
  row <- probe_plan[i, ]
  ref_date <- if (is.na(row$reference_date)) NULL else row$reference_date

  results[[i]] <- probe_one(
    games_year = row$games_year,
    gender = row$gender,
    reference_date = ref_date,
    label = row$probe
  )

  Sys.sleep(0.15)
}

summary <- purrr::map_dfr(results, "summary")
entries <- purrr::map2_dfr(
  results,
  seq_along(results),
  function(result, i) {
    if (nrow(result$entries) == 0L) return(tibble())
    result$entries |>
      mutate(probe_id = i, .before = 1)
  }
)

utils::write.csv(
  summary,
  file.path(probe_dir, "olympic_cycle_probe_summary.csv"),
  row.names = FALSE
)

if (nrow(entries) > 0L) {
  utils::write.csv(
    entries,
    file.path(probe_dir, "olympic_cycle_probe_entries.csv"),
    row.names = FALSE
  )
}

cat("\nOLYMPIC RANKING VIS PROBE SUMMARY\n\n")
print(summary, n = Inf, width = Inf)

cat("\nNON-EMPTY PROBES: TOP FIVE\n\n")
for (i in seq_along(results)) {
  if (nrow(results[[i]]$entries) == 0L) next

  s <- results[[i]]$summary
  cat(
    "\nGamesYear ", s$games_year,
    " | ", s$gender,
    " | ", s$probe,
    if (!is.na(s$reference_date)) paste0(" | ", s$reference_date) else "",
    "\n",
    sep = ""
  )

  print(
    results[[i]]$entries |>
      select(
        any_of(c(
          "GamesYear", "Position", "NoPlayer1", "NoPlayer2", "TeamName",
          "TeamCountryCode", "NbParticipations", "SelectionRank", "Points",
          "Status", "StatusLabel"
        ))
      ) |>
      slice_head(n = 5),
    n = 5,
    width = Inf
  )
}

message(
  "Olympic ranking probe complete. Outputs written to ",
  normalizePath(probe_dir, mustWork = FALSE)
)
