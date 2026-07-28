# Harvest candidate BRM articles (2015-2025) that mention Shiny, via the
# Europe PMC REST API, and extract application URLs from the full text.
#
# Coverage note: Europe PMC full-text search only covers the open-access
# subset of BRM. This harvest therefore SEEDS the sampling frame; the
# Springer Link full-text search in protocol.md remains the primary frame
# and must supplement this list for non-OA articles.
#
# EPMC quirk (documented 2026-07-27): BODY:"shinyapps.io" matches almost
# nothing because URLs are tokenized; BODY:"Shiny" is the reliable pre-filter,
# with URL extraction done locally by regex on the full-text XML.
#
# Output: audit/candidates_epmc.csv (one row per article, URLs pipe-joined)

library(httr2)

EPMC <- "https://www.ebi.ac.uk/europepmc/webservices/rest"
QUERY <- '(ISSN:"1554-3528") AND (BODY:"Shiny") AND (PUB_YEAR:[2015 TO 2025])'
# shinyapps.io URLs, plus any URL whose host contains "shiny" (institutional
# Shiny servers). Everything else is left to manual screening.
URL_RE <- "https?://[A-Za-z0-9.-]*shiny[A-Za-z0-9.-]*(:[0-9]+)?(/[A-Za-z0-9_/.~%-]*)?"

`%||%` <- function(a, b) if (is.null(a)) b else a

epmc_search <- function(query) {
  hits <- list()
  cursor <- "*"
  repeat {
    resp <- request(EPMC) |>
      req_url_path_append("search") |>
      req_url_query(query = query, format = "json", pageSize = 100,
                    resultType = "lite", cursorMark = cursor) |>
      req_user_agent("BRM-availability-audit/1.0") |>
      req_perform() |>
      resp_body_json()
    hits <- c(hits, resp$resultList$result)
    if (is.null(resp$nextCursorMark) || identical(resp$nextCursorMark, cursor) ||
        length(resp$resultList$result) == 0) break
    cursor <- resp$nextCursorMark
  }
  hits
}

extract_urls <- function(pmcid) {
  if (is.null(pmcid) || !nzchar(pmcid)) return(character(0))
  xml <- tryCatch(
    request(EPMC) |>
      req_url_path_append(pmcid, "fullTextXML") |>
      req_user_agent("BRM-availability-audit/1.0") |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform() |>
      resp_body_string(),
    error = function(e) ""
  )
  if (!nzchar(xml)) return(character(0))
  m <- gregexpr(URL_RE, xml, ignore.case = TRUE, perl = TRUE)
  urls <- unique(unlist(regmatches(xml, m)))
  urls <- sub("[.,;)]+$", "", urls)
  # drop non-app hosts that merely document Shiny itself
  urls[!grepl("shiny\\.rstudio\\.com|shiny\\.posit\\.co|cran|github\\.com/rstudio",
              urls, ignore.case = TRUE)]
}

main <- function() {
  hits <- epmc_search(QUERY)
  message(sprintf("Europe PMC returned %d articles", length(hits)))
  rows <- lapply(hits, function(h) {
    urls <- extract_urls(h$pmcid)
    Sys.sleep(0.4)
    data.frame(
      pmcid = h$pmcid %||% "",
      doi = h$doi %||% "",
      year = h$pubYear %||% "",
      first_author = h$authorString %||% "",
      title = h$title %||% "",
      is_open_access = h$isOpenAccess %||% "",
      app_urls = paste(urls, collapse = " | "),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  write.csv(out, "audit/candidates_epmc.csv", row.names = FALSE)
  message("Wrote audit/candidates_epmc.csv")
  invisible(out)
}

if (sys.nframe() == 0) main()
