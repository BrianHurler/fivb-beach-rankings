library(dplyr)

parsed_file <- file.path("data", "parsed", "fivb_historical_ranking_entries.rds")

if (!file.exists(parsed_file)) {
  stop("Parsed archive not found. Run scripts/04_parse_archive.R first.", call. = FALSE)
}

ranking_entries <- readRDS(parsed_file)

get_world_ranking_as_of <- function(date, gender = c("M", "W")) {
  gender <- match.arg(gender)
  target_date <- as.Date(date)
  gender_code <- if (gender == "M") 0L else 1L

  available_date <- ranking_entries |>
    filter(
      ranking_type == 9L,
      ranking_subtype == 3L,
      ranking_gender == gender_code,
      ranking_date <= target_date
    ) |>
    summarise(ranking_date = max(ranking_date, na.rm = TRUE)) |>
    pull(ranking_date)

  if (length(available_date) == 0L || is.na(available_date)) {
    stop("No FIVB World ranking exists on or before ", target_date, ".", call. = FALSE)
  }

  message("Requested date: ", target_date, " | Ranking used: ", available_date)

  ranking_entries |>
    filter(
      ranking_type == 9L,
      ranking_subtype == 3L,
      ranking_gender == gender_code,
      ranking_date == available_date
    ) |>
    arrange(Position)
}

# Example:
# men_2015_03_23 <- get_world_ranking_as_of("2015-03-23", "M")
