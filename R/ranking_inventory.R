xml_attributes_to_tbl <- function(nodes) {
  if (length(nodes) == 0) {
    return(tibble::tibble())
  }

  nodes |>
    purrr::map(xml2::xml_attrs) |>
    purrr::map(as.list) |>
    dplyr::bind_rows()
}

label_ranking_inventory <- function(x) {
  x |>
    dplyr::mutate(
      No = as.integer(No),
      Date = as.Date(Date),
      Gender = as.integer(Gender),
      Type = as.integer(Type),
      SubType = as.integer(SubType),
      Version = as.integer(Version),
      gender_name = dplyr::case_when(
        Gender == 0L ~ "Men",
        Gender == 1L ~ "Women",
        TRUE ~ paste0("Gender ", Gender)
      ),
      type_name = dplyr::case_when(
        Type == 1L ~ "FIVB Federation",
        Type == 3L ~ "FIVB World Tour",
        Type == 6L ~ "FIVB Athlete",
        Type == 9L ~ "FIVB World",
        Type == 10L ~ "FIVB Team",
        Type == 13L ~ "CEV Athlete",
        Type == 14L ~ "CEV Team",
        TRUE ~ paste0("Type ", Type)
      ),
      subtype_name = dplyr::case_when(
        SubType == 1L ~ "Player",
        SubType == 2L ~ "PlayerSum",
        SubType == 3L ~ "Team",
        TRUE ~ paste0("SubType ", SubType)
      )
    ) |>
    dplyr::arrange(Date, Gender, Type, No)
}

get_beach_ranking_inventory <- function(save_raw_path = NULL) {
  request_xml <- paste0(
    '<Request Type="GetBeachRankingList" ',
    'Fields="No Date Gender Type SubType Version" />'
  )

  resp <- vis_request(request_xml)
  body <- vis_response_body(resp, "VIS ranking inventory request")

  if (!is.null(save_raw_path)) {
    dir.create(dirname(save_raw_path), recursive = TRUE, showWarnings = FALSE)
    writeLines(body, save_raw_path, useBytes = TRUE)
  }

  doc <- xml2::read_xml(body)
  nodes <- xml2::xml_find_all(doc, ".//*[local-name()='BeachRanking']")
  out <- xml_attributes_to_tbl(nodes)

  if (nrow(out) == 0) {
    stop("VIS returned no BeachRanking inventory nodes.", call. = FALSE)
  }

  out <- label_ranking_inventory(out)
  message("Rankings returned by VIS: ", format(nrow(out), big.mark = ","))
  message("Date range: ", min(out$Date), " to ", max(out$Date))
  out
}

build_archive_inventory <- function(
    ranking_inventory,
    start_date = as.Date("2008-01-01"),
    archive_types = c(6L, 9L, 10L)
) {
  ranking_inventory |>
    dplyr::filter(
      Date >= as.Date(start_date),
      Type %in% as.integer(archive_types)
    ) |>
    dplyr::arrange(Date, Gender, Type, No)
}
