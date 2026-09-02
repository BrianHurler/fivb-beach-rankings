VIS_URL <- "https://www.fivb.org/Vis2009/XmlRequest.asmx"

vis_request <- function(request_xml) {
  httr2::request(VIS_URL) |>
    httr2::req_body_form(Request = request_xml) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
}

vis_response_body <- function(resp, context = "VIS request") {
  status <- httr2::resp_status(resp)
  body <- httr2::resp_body_string(resp)

  if (status != 200) {
    stop(
      context,
      " failed. HTTP ", status,
      "\n\n", body,
      call. = FALSE
    )
  }

  body
}
