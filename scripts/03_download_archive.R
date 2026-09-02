library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/vis_request.R")
source("R/ranking_download.R")
source("R/ranking_parse.R")

inventory_file <- file.path("data", "inventory", "archive_inventory.rds")
validation_file <- file.path("data", "raw", "ranking_000774.xml")

if (!file.exists(inventory_file)) {
  stop("Missing archive inventory. Run scripts/01_build_inventory.R first.", call. = FALSE)
}

if (!file.exists(validation_file)) {
  stop("Ranking 774 has not been validated. Run scripts/02_inspect_ranking_774.R first.", call. = FALSE)
}

validation_doc <- xml2::read_xml(validation_file)
validation_entries <- find_ranking_entry_nodes(validation_doc)

if (length(validation_entries) == 0L) {
  stop(
    "Saved ranking 774 response contains no Position nodes. ",
    "Resolve the response format before bulk downloading.",
    call. = FALSE
  )
}

archive_inventory <- readRDS(inventory_file)

message("Launching archive download for ", format(nrow(archive_inventory), big.mark = ","), " rankings.")

download_log <- download_ranking_archive(
  archive_inventory,
  raw_dir = file.path("data", "raw"),
  log_file = file.path("data", "logs", "download_log.rds"),
  sleep_seconds = 0.25,
  max_tries = 5L
)

print(
  download_log |>
    summarise(
      queued = n(),
      downloaded = sum(downloaded, na.rm = TRUE),
      failed = sum(!downloaded, na.rm = TRUE),
      pct_complete = round(100 * downloaded / queued, 2)
    )
)
