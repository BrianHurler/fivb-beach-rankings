library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/ranking_parse.R")

raw_dir <- file.path("data", "raw")
parsed_dir <- file.path("data", "parsed")
dir.create(parsed_dir, recursive = TRUE, showWarnings = FALSE)

raw_files <- list.files(
  raw_dir,
  pattern = "^ranking_[0-9]+\\.xml$",
  full.names = TRUE
)

if (length(raw_files) == 0L) {
  stop("No raw ranking XML files found in data/raw.", call. = FALSE)
}

message("Parsing ", format(length(raw_files), big.mark = ","), " ranking XML files.")

ranking_entries <- raw_files |>
  purrr::map_dfr(parse_ranking_xml) |>
  clean_ranking_entries()

saveRDS(
  ranking_entries,
  file.path(parsed_dir, "fivb_historical_ranking_entries.rds")
)

utils::write.csv(
  ranking_entries,
  file.path(parsed_dir, "fivb_historical_ranking_entries.csv"),
  row.names = FALSE
)

print(
  ranking_entries |>
    summarise(
      rows = n(),
      rankings = n_distinct(ranking_no),
      first_date = min(ranking_date, na.rm = TRUE),
      last_date = max(ranking_date, na.rm = TRUE)
    )
)
