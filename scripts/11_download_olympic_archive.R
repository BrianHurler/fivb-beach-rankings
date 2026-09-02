library(dplyr)
library(tibble)

source("R/olympic_ranking.R")

reference_dates_file <- file.path(
  "data", "olympic_discovery", "olympic_reference_dates.csv"
)

archive_dir <- file.path("data", "olympic")
raw_dir <- file.path(archive_dir, "raw")
log_dir <- file.path(archive_dir, "logs")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

manifest_file <- file.path(log_dir, "olympic_download_manifest.csv")

if (!file.exists(reference_dates_file)) {
  stop(
    "Missing discovered Olympic reference dates. Run scripts/10_discover_olympic_reference_dates.R first.",
    call. = FALSE
  )
}

queue <- read.csv(reference_dates_file, stringsAsFactors = FALSE) |>
  as_tibble() |>
  transmute(
    games_year = as.integer(games_year),
    gender = as.character(gender),
    reference_date = as.Date(reference_date)
  ) |>
  distinct() |>
  arrange(games_year, reference_date, gender)

raw_path_for <- function(games_year, gender, reference_date) {
  file.path(
    raw_dir,
    paste0(
      "olympic_", games_year, "_", gender, "_",
      format(reference_date, "%Y-%m-%d"), ".xml"
    )
  )
}

validate_raw_file <- function(path, games_year, gender, reference_date) {
  if (!file.exists(path)) return(FALSE)

  body <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  parsed <- tryCatch(
    parse_olympic_ranking_body(
      body,
      requested_games_year = games_year,
      requested_gender = gender,
      requested_reference_date = reference_date
    ),
    error = function(e) NULL
  )

  if (is.null(parsed) || nrow(parsed$entries) == 0L) return(FALSE)

  if ("GamesYear" %in% names(parsed$entries)) {
    values <- unique(parsed$entries$GamesYear[!is.na(parsed$entries$GamesYear)])
    if (length(values) > 0L && !all(values == games_year)) return(FALSE)
  }

  TRUE
}

queue <- queue |>
  rowwise() |>
  mutate(
    raw_path = raw_path_for(games_year, gender, reference_date),
    already_valid = validate_raw_file(raw_path, games_year, gender, reference_date)
  ) |>
  ungroup()

pending <- queue |>
  filter(!already_valid)

message(
  "Olympic archive download: ", nrow(queue), " discovered snapshots; ",
  sum(queue$already_valid), " already present and valid; ",
  nrow(pending), " pending."
)

manifest <- if (file.exists(manifest_file)) {
  read.csv(manifest_file, stringsAsFactors = FALSE) |>
    as_tibble() |>
    mutate(reference_date = as.Date(reference_date))
} else {
  tibble(
    games_year = integer(),
    gender = character(),
    reference_date = as.Date(character()),
    rows = integer(),
    downloaded_at = character(),
    ok = logical(),
    error = character()
  )
}

write_manifest <- function(x) {
  x |>
    arrange(games_year, reference_date, gender) |>
    utils::write.csv(manifest_file, row.names = FALSE)
}

if (nrow(pending) > 0L) {
  for (i in seq_len(nrow(pending))) {
    row <- pending[i, ]

    result <- tryCatch(
      get_olympic_ranking(
        gender = row$gender,
        games_year = row$games_year,
        reference_date = row$reference_date,
        fields = OLYMPIC_RANKING_FIELDS
      ),
      error = function(e) e
    )

    if (inherits(result, "error")) {
      log_row <- tibble(
        games_year = row$games_year,
        gender = row$gender,
        reference_date = row$reference_date,
        rows = NA_integer_,
        downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        ok = FALSE,
        error = conditionMessage(result)
      )
    } else if (nrow(result$entries) == 0L) {
      log_row <- tibble(
        games_year = row$games_year,
        gender = row$gender,
        reference_date = row$reference_date,
        rows = 0L,
        downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        ok = FALSE,
        error = "Previously discovered reference date returned an empty ranking during full download."
      )
    } else {
      target <- row$raw_path
      temp <- paste0(target, ".tmp")
      writeLines(result$body, temp, useBytes = TRUE)

      if (!validate_raw_file(temp, row$games_year, row$gender, row$reference_date)) {
        unlink(temp)
        stop(
          "Downloaded Olympic XML failed validation for GamesYear=", row$games_year,
          " gender=", row$gender,
          " ReferenceDate=", row$reference_date,
          call. = FALSE
        )
      }

      if (!file.rename(temp, target)) {
        unlink(temp)
        stop("Could not move validated Olympic XML into place: ", target, call. = FALSE)
      }

      log_row <- tibble(
        games_year = row$games_year,
        gender = row$gender,
        reference_date = row$reference_date,
        rows = nrow(result$entries),
        downloaded_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        ok = TRUE,
        error = NA_character_
      )
    }

    manifest <- manifest |>
      filter(!(
        games_year == row$games_year &
          gender == row$gender &
          reference_date == row$reference_date
      )) |>
      bind_rows(log_row)

    write_manifest(manifest)

    completed_overall <- sum(queue$already_valid) + i
    successful_files <- sum(file.exists(queue$raw_path))
    failures <- sum(!manifest$ok, na.rm = TRUE)

    if (isTRUE(log_row$ok[[1]])) {
      message(
        "[", completed_overall, "/", nrow(queue), "] ",
        row$reference_date, " | ", row$gender,
        " | GamesYear ", row$games_year,
        " | rows=", log_row$rows[[1]]
      )
    } else {
      message(
        "FAILED | ", row$reference_date, " | ", row$gender,
        " | GamesYear ", row$games_year,
        " | ", log_row$error[[1]]
      )
    }

    if (i %% 10L == 0L || i == nrow(pending)) {
      message(
        "STATUS | ", completed_overall, "/", nrow(queue), " processed (",
        round(100 * completed_overall / nrow(queue), 1), "%)",
        " | raw files=", successful_files,
        " | failures=", failures
      )
    }

    Sys.sleep(0.10)
  }
}

final_valid <- vapply(
  seq_len(nrow(queue)),
  function(i) {
    validate_raw_file(
      queue$raw_path[[i]],
      queue$games_year[[i]],
      queue$gender[[i]],
      queue$reference_date[[i]]
    )
  },
  logical(1)
)

cat("\nOLYMPIC ARCHIVE DOWNLOAD SUMMARY\n\n")
print(
  tibble(
    discovered_snapshots = nrow(queue),
    valid_raw_files = sum(final_valid),
    missing_or_invalid = sum(!final_valid),
    pct_complete = round(100 * mean(final_valid), 2)
  )
)

if (!all(final_valid)) {
  stop(
    sum(!final_valid),
    " discovered Olympic snapshot(s) are still missing or invalid. Re-run this script to retry.",
    call. = FALSE
  )
}

message("Olympic raw archive complete: ", normalizePath(raw_dir, mustWork = FALSE))
