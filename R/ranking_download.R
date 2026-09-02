get_entry_fields <- function(subtype) {
  subtype <- as.integer(subtype)

  common <- c(
    "NoRanking", "Position", "Rank", "Name", "FederationCode",
    "NoPlayer1", "Player1FederationCode", "Player1TeamName",
    "Points", "PointsPlayer1"
  )

  fields <- switch(
    as.character(subtype),
    `1` = c(common, "NbTakenResultsPlayer1", "NbTotalResultsPlayer1"),
    `2` = c(
      common,
      "NoPlayer2", "Player2FederationCode", "Player2TeamName",
      "PointsPlayer2", "NbTakenResultsPlayer1", "NbTotalResultsPlayer1",
      "NbTakenResultsPlayer2", "NbTotalResultsPlayer2"
    ),
    `3` = c(
      common,
      "NoPlayer2", "Player2FederationCode", "Player2TeamName",
      "NbTakenResultsTeam", "NbTotalResultsTeam"
    ),
    common
  )

  paste(fields, collapse = " ")
}

build_get_beach_ranking_request <- function(ranking_no, subtype, entries_fields = NULL) {
  if (is.null(entries_fields)) {
    entries_fields <- get_entry_fields(subtype)
  }

  sprintf(
    paste0(
      '<Request Type="GetBeachRanking" ',
      'No="%s" ',
      'Fields="No Date Gender Type SubType Version" ',
      'EntriesFields="%s" />'
    ),
    as.integer(ranking_no),
    entries_fields
  )
}

get_beach_ranking_raw <- function(
    ranking_no,
    subtype,
    entries_fields = NULL,
    max_tries = 5L,
    validate = TRUE
) {
  request_xml <- build_get_beach_ranking_request(
    ranking_no = ranking_no,
    subtype = subtype,
    entries_fields = entries_fields
  )

  for (attempt in seq_len(max_tries)) {
    resp <- tryCatch(vis_request(request_xml), error = function(e) NULL)

    if (!is.null(resp)) {
      status <- httr2::resp_status(resp)
      body <- httr2::resp_body_string(resp)

      if (status == 200) {
        if (isTRUE(validate)) {
          if (!exists("validate_ranking_body", mode = "function")) {
            stop(
              "validate_ranking_body() is not loaded. Source R/ranking_parse.R before requesting rankings.",
              call. = FALSE
            )
          }

          validate_ranking_body(
            body,
            expected_no = ranking_no,
            min_entries = 1L
          )
        }

        return(body)
      }

      if (status >= 400 && status < 500 && status != 429) {
        stop(
          "VIS request failed for ranking ", ranking_no,
          ". HTTP ", status, "\n", body,
          call. = FALSE
        )
      }
    }

    if (attempt < max_tries) {
      Sys.sleep(min(2^(attempt - 1), 30))
    }
  }

  stop(
    "Failed to retrieve ranking ", ranking_no,
    " after ", max_tries, " attempts.",
    call. = FALSE
  )
}

initialize_download_log <- function(inventory) {
  inventory |>
    dplyr::transmute(
      ranking_no = No,
      ranking_date = Date,
      gender = Gender,
      gender_name,
      type = Type,
      type_name,
      subtype = SubType,
      subtype_name,
      downloaded = FALSE,
      attempts = 0L,
      last_status = NA_character_,
      last_error = NA_character_,
      downloaded_at = as.POSIXct(NA)
    )
}

download_ranking_archive <- function(
    inventory,
    raw_dir = file.path("data", "raw"),
    log_file = file.path("data", "logs", "download_log.rds"),
    sleep_seconds = 0.25,
    max_tries = 5L
) {
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

  log <- if (file.exists(log_file)) {
    readRDS(log_file)
  } else {
    initialize_download_log(inventory)
  }

  for (i in seq_len(nrow(inventory))) {
    row <- inventory[i, ]
    ranking_no <- row$No
    file_path <- file.path(raw_dir, sprintf("ranking_%06d.xml", ranking_no))
    log_row <- which(log$ranking_no == ranking_no)

    if (file.exists(file_path)) {
      # Existing files are revalidated before being trusted. This protects
      # against a prior run having saved VIS error XML under a ranking name.
      existing_body <- paste(readLines(file_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      existing_ok <- tryCatch(
        {
          validate_ranking_body(existing_body, expected_no = ranking_no, min_entries = 1L)
          TRUE
        },
        error = function(e) {
          message("Existing file failed validation for ranking ", ranking_no, ": ", conditionMessage(e))
          FALSE
        }
      )

      if (existing_ok) {
        if (length(log_row) == 1L) {
          log$downloaded[log_row] <- TRUE
          if (is.na(log$last_status[log_row])) log$last_status[log_row] <- "existing"
        }
        message(sprintf("[%d/%d] ranking %d -- exists", i, nrow(inventory), ranking_no))
        next
      }

      unlink(file_path)
    }

    message(sprintf(
      "[%d/%d] %s | %s | %s | ranking %d",
      i, nrow(inventory), row$Date, row$gender_name, row$type_name, ranking_no
    ))

    if (length(log_row) == 1L) log$attempts[log_row] <- log$attempts[log_row] + 1L

    body <- tryCatch(
      get_beach_ranking_raw(
        ranking_no = ranking_no,
        subtype = row$SubType,
        max_tries = max_tries,
        validate = TRUE
      ),
      error = function(e) {
        if (length(log_row) == 1L) {
          log$downloaded[log_row] <- FALSE
          log$last_status[log_row] <- "error"
          log$last_error[log_row] <- conditionMessage(e)
        }
        message("ERROR ranking ", ranking_no, ": ", conditionMessage(e))
        NULL
      }
    )

    if (!is.null(body)) {
      writeLines(body, file_path, useBytes = TRUE)
      if (length(log_row) == 1L) {
        log$downloaded[log_row] <- TRUE
        log$last_status[log_row] <- "success"
        log$last_error[log_row] <- NA_character_
        log$downloaded_at[log_row] <- Sys.time()
      }
    }

    saveRDS(log, log_file)
    Sys.sleep(sleep_seconds)
  }

  saveRDS(log, log_file)
  utils::write.csv(log, sub("\\.rds$", ".csv", log_file), row.names = FALSE)
  invisible(log)
}
