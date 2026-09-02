find_ranking_node <- function(doc) {
  xml2::xml_find_first(
    doc,
    "/*[local-name()='BeachRanking'] | .//*[local-name()='BeachRanking']"
  )
}

find_ranking_entry_nodes <- function(doc) {
  # Entry tag names can vary across VIS response shapes. Position is a
  # documented ranking-entry attribute and is a safer discovery key.
  xml2::xml_find_all(doc, ".//*[@Position]")
}

inspect_ranking_response <- function(body, preview_chars = 3000L) {
  doc <- xml2::read_xml(body)
  root <- xml2::xml_root(doc)
  entries <- find_ranking_entry_nodes(doc)

  out <- list(
    root_name = xml2::xml_name(root),
    root_attributes = xml2::xml_attrs(root),
    element_names = unique(xml2::xml_name(xml2::xml_find_all(doc, ".//*"))),
    n_position_nodes = length(entries),
    preview = substr(body, 1L, preview_chars)
  )

  cat("Root element:", out$root_name, "\n\n")
  cat("Root attributes:\n")
  print(out$root_attributes)
  cat("\nElement names:\n")
  print(out$element_names)
  cat("\nNodes with Position attribute:", out$n_position_nodes, "\n\n")
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
    warning("No ranking entry nodes with Position attribute in ", file_path)
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
    "NoRanking", "Position", "Rank", "NoPlayer1", "NoPlayer2",
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
