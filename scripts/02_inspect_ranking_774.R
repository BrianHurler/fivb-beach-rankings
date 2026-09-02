library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/vis_request.R")
source("R/ranking_download.R")
source("R/ranking_parse.R")

raw_dir <- file.path("data", "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# Men's FIVB World ranking, 2015-03-23.
test_xml <- get_beach_ranking_raw(
  ranking_no = 774L,
  subtype = 3L
)

inspection <- inspect_ranking_response(test_xml)

writeLines(
  test_xml,
  file.path(raw_dir, "ranking_000774.xml"),
  useBytes = TRUE
)

if (inspection$n_position_nodes == 0L) {
  stop(
    "Ranking 774 returned no nodes with a Position attribute. ",
    "Inspect the response preview above before running the bulk archive downloader.",
    call. = FALSE
  )
}

message("Ranking 774 validation passed with ", inspection$n_position_nodes, " entry nodes.")
