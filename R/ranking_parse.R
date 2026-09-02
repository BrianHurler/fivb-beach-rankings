find_ranking_node <- function(doc) {
  xml2::xml_find_first(
    doc,
    "/*[local-name()='BeachRanking'] | .//*[local-name()='BeachRanking']"
  )
}

find_ranking_entry_nodes <- function(doc) {
  ranking_node <- find_ranking_node(doc)

  if (inherits(ranking_node, "xml_missing")) {
    return(xml2::xml_find_all(doc, ".//*[false()]"))
  }

  # Validated against VIS GetBeachRanking response for ranking No. 774:
  # BeachRanking is the root and ranking rows are child <Entry> nodes.
  entries <- xml2::xml_find_all(
    ranking_node,
    "./*[local-name()='Entry']"
  )

  # Defensive fallback for any older/different VIS response shape.
  if (length(entries) == 0L) {
    entries <- xml2::xml_find_all(
      ranking_node,
      ".//*[@Position]"
    )
  }

  entries
}

validate_ranking_body <- function(body, expected_no = NULL, min_entries = 1L) {
  doc <- tryCatch(
    xml2::read_xml(body),
    error = function(e) {
      stop("VIS response is not valid XML: ", conditionMessage(e), call. = FALSE)
    }
  )

  root <- xml2::xml_root(doc)
  root_name <- xml2::xml_name(root)

  if (!identical(root_name, "BeachRanking")) {
    stop(
      "Expected VIS <BeachRanking> response but received <",
      root_name,
      ">: ",
      substr(body, 1L, 500L),
      call. = FALSE
    )
  }

  ranking_attrs <- xml2::xml_attrs(root)

  if (!is.null(expected_no)) {
    returned_no <- suppressWarnings(as.integer(ranking_attrs[["No"]]))

    if (is.na(returned_no) || returned_no != as.integer(expected_no)) {
      stop(
        "VIS returned ranking No=", returned_no,
        " when No=", as.integer(expected_no), " was requested.",
        call. = FALSE
      )
    }
  }

  entries <- find_ranking_entry_nodes(doc)

  if (length(entries) < as.integer(min_entries)) {
    stop(
      "Ranking ", ranking_attrs[["No"]],
      " returned ", length(entries),
      " entry nodes; expected at least ", as.integer(min_entries), ".",
      call. = FALSE
    )
  }

  invisible(list(
    doc = doc,
    ranking_attributes = ranking_attrs,
    entries = entries,
    n_entries = length(entries)
  ))
}

inspect_ranking_response <- function(body, preview_chars = 3000L) {
  doc <- xml2::read_xml(body)
  root <- xml2::xml_root(doc)
  entries <- find_ranking_entry_nodes(doc)

  out <- list(
    root_name = xml2::xml_name(root),
    root_attributes = xml2::xml_attrs(root),
    element_names = unique(xml2::xml_name(xml2::xml_find_all(doc, ".//*"))),
    n_entries = length(entries),
    preview = substr(body, 1L, preview_chars)
  )

  cat("Root element:", out$root_name, "\n\n")
  cat("Root attributes:\n")
  print(out$root_attributes)
  cat("\nElement names:\n")
  print(out$element_names)
  cat("\nRanking entry nodes:", out$n_entries, "\n\n")
  cat("Response preview:\n\n", out$preview, "\n", sep = "")

  invisible(out)
}

parse_ranking_xml <- function(file_path) {
  doc <- tryCatch(
    xml2::read_xml(file_path),
    error = function(e) {
      warning("Could not parse ", file_path, ": ", conditionMessage(e))
      NULL
    }
  )

  if (is.null(doc)) return(tibble::tibble())

  ranking_node <- find_ranking_node(doc)
  if (inherits(ranking_node, "xml_missing")) {
    warning("No BeachRanking node in ", file_path)
    return(tibble::tibble())
  }

  ranking_attrs <- as.list(xml2::xml_attrs(ranking_node))
  entries <- find_ranking_entry_nodes(doc)

  if (length(entries) == 0L) {
    warning("No ranking Entry nodes in ", file_path)
    return(tibble::tibble())
  }

  out <- entries |>
    purrr::map(xml2::xml_attrs) |>
    purrr::map(as.list) |>
    dplyr::bind_rows()

  out |>
    dplyr::mutate(
      ranking_no = suppressWarnings(as.integer(ranking_attrs$No)),
      ranking_date = as.Date(ranking_attrs$Date),
      ranking_gender = suppressWarnings(as.integer(ranking_attrs$Gender)),
      ranking_type = suppressWarnings(as.integer(ranking_attrs$Type)),
      ranking_subtype = suppressWarnings(as.integer(ranking_attrs$SubType)),
      ranking_version = suppressWarnings(as.integer(ranking_attrs$Version)),
      source_file = basename(file_path),
      .before = 1
    )
}

clean_ranking_entries <- function(x) {
  integer_fields <- c(
    "No", "NoRanking", "Position", "Rank", "NoPlayer1", "NoPlayer2",
    "NbTakenResultsPlayer1", "NbTotalResultsPlayer1",
    "NbTakenResultsPlayer2", "NbTotalResultsPlayer2",
    "NbTakenResultsTeam", "NbTotalResultsTeam"
  )

  numeric_fields <- c("Points", "PointsPlayer1", "PointsPlayer2")

  x |>
    dplyr::mutate(
      dplyr::across(dplyr::any_of(integer_fields), ~ suppressWarnings(as.integer(.x))),
      dplyr::across(dplyr::any_of(numeric_fields), ~ suppressWarnings(as.numeric(.x))),
      gender_name = dplyr::case_when(
        ranking_gender == 0L ~ "Men",
        ranking_gender == 1L ~ "Women",
        TRUE ~ paste0("Gender ", ranking_gender)
      ),
      type_name = dplyr::case_when(
        ranking_type == 6L ~ "FIVB Athlete",
        ranking_type == 9L ~ "FIVB World",
        ranking_type == 10L ~ "FIVB Team",
        TRUE ~ paste0("Type ", ranking_type)
      ),
      subtype_name = dplyr::case_when(
        ranking_subtype == 1L ~ "Player",
        ranking_subtype == 2L ~ "PlayerSum",
        ranking_subtype == 3L ~ "Team",
        TRUE ~ paste0("SubType ", ranking_subtype)
      )
    ) |>
    dplyr::arrange(ranking_date, ranking_gender, ranking_type, Position)
}
