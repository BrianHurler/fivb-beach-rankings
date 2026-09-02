library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/vis_request.R")
source("R/ranking_parse.R")
source("R/ranking_download.R")

inventory_file <- file.path("data", "inventory", "archive_inventory.rds")
preflight_file <- file.path("data", "logs", "preflight_validation.rds")

if (!file.exists(inventory_file)) {
  stop("Missing archive inventory. Run scripts/01_build_inventory.R first.", call. = FALSE)
}

if (!file.exists(preflight_file)) {
  stop(
    "Archive preflight has not been completed. Run scripts/02b_validate_archive_samples.R first.",
    call. = FALSE
  )
}

preflight_validation <- readRDS(preflight_file)

if (
  nrow(preflight_validation) != 6L ||
  !all(preflight_validation$passed)
) {
  stop(
    "Archive preflight is incomplete or contains failures. ",
    "Run scripts/02b_validate_archive_samples.R and resolve all failures before bulk downloading.",
    call. = FALSE
  )
}

archive_inventory <- readRDS(inventory_file)

message(
  "Preflight passed. Launching archive download for ",
  format(nrow(archive_inventory), big.mark = ","),
  " rankings."
)

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
