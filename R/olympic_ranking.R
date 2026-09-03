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

# Status values 1-8 are documented by the historical VIS client/model.
# Status 9 appears in retained 2016/2020/2024 snapshots on teams that had
# already qualified through another Olympic pathway (for example the prior
# World Championship winners). The current public enum documentation is stale
# and does not name value 9, so keep the label explicitly marked as inferred.
#
# Status 10 appears only in retained Tokyo 2020-cycle snapshots. Its semantic
# meaning has not yet been established from public VIS documentation, so retain
# it explicitly as undocumented rather than converting it to NA or guessing.
OLYMPIC_STATUS_LABELS <- c(
  `1` = "Selected",
  `2` = "SelectedMinHostQuota",
  `3` = "SelectedMinConfederationQuota",
  `4` = "Tie",
  `5` = "NotEnoughTournaments",
  `6` = "CountryQuota",
  `7` = "NotRegistered",
  `8` = "NotEnoughPoints",
  `9` = "AlreadyQualifiedOtherPathway_inferred",
  `10` = "UndocumentedStatus10"
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

  request_node <- paste0("<Request ", paste(attrs, collapse = " "), " />")

  # GetBeachOlympicSelectionRanking is a legacy VIS request that is not
  # available in the single-request/new format. VIS error 1008
  # (NotInNewFormat) requires the request to be enclosed in <Requests>.
  paste0("<Requests>", request_node, "</Requests>")
}

parse_olympic_ranking_body <- function(body,
                                       requested_games_year = NA_integer_,
                                       requested_gender = NA_character_,
                                       requested_reference_date = as.Date(NA)) {
  doc <- xml2::read_xml(body)
  root <- xml2::xml_root(doc)

  error_names <- c("BadParameter", "ParameterMissing", "Error", "Errors")
  error_nodes <- xml2::xml_find_all(
    doc,
    "//*[self::BadParameter or self::ParameterMissing or self::Error or self::Errors]"
  )

  if (xml2::xml_name(root) %in% error_names || length(error_nodes) > 0L) {
    stop(
      "VIS returned an Olympic ranking error:\n",
      as.character(doc),
      call. = FALSE
    )
  }

  ranking_node <- if (xml2::xml_name(root) == "BeachOlympicSelectionRanking") {
    root
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

  if ("Status" %in% names(out)) {
    out <- out |>
      dplyr::mutate(
        StatusLabel = unname(OLYMPIC_STATUS_LABELS[as.character(Status)])
      )
  }

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
