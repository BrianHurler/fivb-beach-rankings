library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(tibble)

source("R/vis_request.R")
source("R/ranking_parse.R")
source("R/ranking_download.R")

inventory_file <- file.path("data", "inventory", "archive_inventory.rds")
raw_dir <- file.path("data", "raw")
log_dir <- file.path("data", "logs")
validation_file <- file.path(log_dir, "preflight_validation.rds")

if (!file.exists(inventory_file)) {
  stop("Missing archive inventory. Run scripts/01_build_inventory.R first.", call. = FALSE)
}

dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

archive_inventory <- readRDS(inventory_file)

# Validate one historical example from every ranking shape we plan to archive:
# men/women x FIVB Athlete (6), FIVB World (9), FIVB Team (10).
preflight_samples <- archive_inventory |>
  group_by(Type, SubType, Gender) |>
  slice_min(Date, n = 1L, with_ties = FALSE) |>
  ungroup() |>
  arrange(Type, Gender)

message("Preflight will validate ", nrow(preflight_samples), " representative rankings.")

results <- vector("list", nrow(preflight_samples))

for (i in seq_len(nrow(preflight_samples))) {
  row <- preflight_samples[i, ]

  message(
    sprintf(
      "[%d/%d] %s | %s | %s | ranking %d",
      i,
      nrow(preflight_samples),
      row$Date,
      row$gender_name,
      row$type_name,
      row$No
    )
  )

  result <- tryCatch(
    {
      body <- get_beach_ranking_raw(
        ranking_no = row$No,
        subtype = row$SubType,
        max_tries = 5L,
        validate = TRUE
      )

      validated <- validate_ranking_body(
        body,
        expected_no = row$No,
        min_entries = 1L
      )

      writeLines(
        body,
        file.path(raw_dir, sprintf("ranking_%06d.xml", row$No)),
        useBytes = TRUE
      )

      tibble(
        ranking_no = row$No,
        ranking_date = row$Date,
        type = row$Type,
        type_name = row$type_name,
        subtype = row$SubType,
        gender = row$Gender,
        gender_name = row$gender_name,
        n_entries = validated$n_entries,
        passed = TRUE,
        error = NA_character_
      )
    },
    error = function(e) {
      tibble(
        ranking_no = row$No,
        ranking_date = row$Date,
        type = row$Type,
        type_name = row$type_name,
        subtype = row$SubType,
        gender = row$Gender,
        gender_name = row$gender_name,
        n_entries = NA_integer_,
        passed = FALSE,
        error = conditionMessage(e)
      )
    }
  )

  results[[i]] <- result
}

preflight_validation <- bind_rows(results)

saveRDS(preflight_validation, validation_file)
utils::write.csv(
  preflight_validation,
  file.path(log_dir, "preflight_validation.csv"),
  row.names = FALSE
)

print(preflight_validation, n = Inf)

if (!all(preflight_validation$passed)) {
  stop(
    "Archive preflight failed. Do not launch the bulk download until all six sample rankings pass.",
    call. = FALSE
  )
}

message(
  "Archive preflight passed: ",
  nrow(preflight_validation),
  "/",
  nrow(preflight_validation),
  " representative rankings validated."
)
