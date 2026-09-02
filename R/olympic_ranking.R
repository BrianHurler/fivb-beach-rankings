library(xml2)
library(dplyr)
library(tibble)

source("R/vis_request.R")

`%||%` <- function(x, y) if (is.null(x)) y else x

OLYMPIC_RANKING_FIELDS <- c(
  "GamesYear",
  "Position",
  "NoPlayer1",
  "NoPlayer2",
  "TeamName",
  "TeamCountryCode",
  "NbParticipations",
  "SelectionRank",
  "Points",
  "Status"
)

build_olympic_ranking_request <- function(gender,
                                          games_year = NULL,
                                          reference_date = NULL,
                                          only_selected = NULL,
                                          fields = OLYMPIC_RANKING_FIELDS) {
  attrs <- c(
    'Type="GetBeachOlympicSelectionRanking"',
    paste0('Gender="', gender, '"')
  )

  if (!is.null(games_year)) {
    attrs <- c(attrs, paste0('GamesYear="', as.integer(games_year), '"'))
  }

  if (!is.null(reference_date)) {
    attrs <- c(
      attrs,
      paste0('ReferenceDate="', format(as.Date(reference_date), "%Y-%m-%d"), '"')
    )
  }

  if (!is.null(only_selected)) {
    attrs <- c(
      attrs,
      paste0('OnlySelected="', tolower(as.character(isTRUE(only_selected))), '"')
    )
  }

  attrs <- c(
    attrs,
    paste0('Fields="', paste(fields, collapse = " "), '"')
  )

  paste0("<Request ", paste(attrs, collapse = " "), " />")
}

parse_olympic_ranking_body <- function(body,
                                       requested_games_year = NA_integer_,
                                       requested_gender = NA_character_,
                                       requested_reference_date = as.Date(NA)) {
  doc <- xml2::read_xml(body)

  error_nodes <- xml2::xml_find_all(doc, ".//BadParameter | .//ParameterMissing | .//Error")
  if (length(error_nodes) > 0L) {
    stop(
      "VIS returned an Olympic ranking error:\n",
      paste(vapply(error_nodes, xml2::as_xml_document, character(1)), collapse = "\n"),
      call. = FALSE
    )
  }

  ranking_node <- if (xml2::xml_name(xml2::xml_root(doc)) == "BeachOlympicSelectionRanking") {
    xml2::xml_root(doc)
  } else {
    xml2::xml_find_first(doc, ".//BeachOlympicSelectionRanking")
  }

  entries <- xml2::xml_find_all(doc, ".//BeachOlympicSelectionRankingEntry")

  if (length(entries) == 0L) {
    return(list(
      root_attributes = if (!inherits(ranking_node, "xml_missing")) xml2::xml_attrs(ranking_node) else character(),
      entries = tibble::tibble(),
      body = body
    ))
  }

  attrs <- lapply(entries, xml2::xml_attrs)
  all_names <- unique(unlist(lapply(attrs, names), use.names = FALSE))

  out <- lapply(attrs, function(a) {
    values <- setNames(rep(NA_character_, length(all_names)), all_names)
    values[names(a)] <- unname(a)
    as.list(values)
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      requested_games_year = requested_games_year,
      requested_gender = requested_gender,
      requested_reference_date = requested_reference_date,
      .before = 1
    )

  numeric_fields <- intersect(
    c("GamesYear", "Position", "NoPlayer1", "NoPlayer2", "NbParticipations", "SelectionRank", "Points", "Status"),
    names(out)
  )

  out <- out |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(numeric_fields),
        ~ suppressWarnings(as.numeric(.x))
      )
    )

  list(
    root_attributes = if (!inherits(ranking_node, "xml_missing")) xml2::xml_attrs(ranking_node) else character(),
    entries = out,
    body = body
  )
}

get_olympic_ranking <- function(gender,
                                games_year = NULL,
                                reference_date = NULL,
                                only_selected = NULL,
                                fields = OLYMPIC_RANKING_FIELDS) {
  request_xml <- build_olympic_ranking_request(
    gender = gender,
    games_year = games_year,
    reference_date = reference_date,
    only_selected = only_selected,
    fields = fields
  )

  resp <- vis_request(request_xml)
  body <- vis_response_body(
    resp,
    context = paste(
      "Olympic ranking request",
      games_year %||% "latest",
      gender,
      if (!is.null(reference_date)) as.character(as.Date(reference_date)) else "latest-date"
    )
  )

  parse_olympic_ranking_body(
    body,
    requested_games_year = if (is.null(games_year)) NA_integer_ else as.integer(games_year),
    requested_gender = gender,
    requested_reference_date = if (is.null(reference_date)) as.Date(NA) else as.Date(reference_date)
  )
}
