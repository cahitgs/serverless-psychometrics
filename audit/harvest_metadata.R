# Supplementary candidate harvest via metadata APIs (Crossref + Semantic
# Scholar). Complements harvest_epmc.R: EPMC only sees the open-access subset,
# whereas title/abstract metadata exists for ALL BRM articles. Limitation:
# only finds articles that mention Shiny in title/abstract, and app URLs can
# only be auto-extracted when they appear in the abstract; everything else
# stays flagged for the manual Springer Link full-text search (protocol.md).
#
# Output: audit/candidates_metadata.csv

library(httr2)

ISSN <- "1554-3528"
URL_RE <- "https?://[A-Za-z0-9.-]*shiny[A-Za-z0-9.-]*(:[0-9]+)?(/[A-Za-z0-9_/.~%-]*)?"
UA <- "BRM-availability-audit/1.0 (mailto:cahitgs@gmail.com)"

`%||%` <- function(a, b) if (is.null(a)) b else a

crossref_search <- function(query) {
  out <- list()
  cursor <- "*"
  repeat {
    resp <- request("https://api.crossref.org/works") |>
      req_url_query(
        query = query, rows = 200, cursor = cursor,
        filter = sprintf("issn:%s,from-pub-date:2015-01-01,until-pub-date:2025-12-31", ISSN),
        select = "DOI,title,abstract,published,author"
      ) |>
      req_user_agent(UA) |>
      req_perform() |>
      resp_body_json()
    items <- resp$message$items
    out <- c(out, items)
    if (length(items) == 0) break
    cursor <- resp$message$`next-cursor`
    Sys.sleep(1)
  }
  out
}

s2_search <- function(query) {
  out <- list()
  token <- NULL
  repeat {
    req <- request("https://api.semanticscholar.org/graph/v1/paper/search/bulk") |>
      req_url_query(query = query, venue = "Behavior Research Methods",
                    year = "2015-2025",
                    fields = "title,abstract,year,externalIds") |>
      req_user_agent(UA)
    if (!is.null(token)) req <- req_url_query(req, token = token)
    resp <- tryCatch(req_perform(req) |> resp_body_json(), error = function(e) NULL)
    if (is.null(resp)) break
    out <- c(out, resp$data)
    token <- resp$token
    if (is.null(token)) break
    Sys.sleep(1.5)
  }
  out
}

first_author <- function(cr_item) {
  a <- cr_item$author
  if (is.null(a) || !length(a)) return("")
  paste(a[[1]]$family %||% "", a[[1]]$given %||% "")
}

extract_urls <- function(text) {
  if (is.null(text) || !nzchar(text)) return("")
  m <- gregexpr(URL_RE, text, ignore.case = TRUE, perl = TRUE)
  urls <- unique(sub("[.,;)]+$", "", unlist(regmatches(text, m))))
  paste(urls, collapse = " | ")
}

main <- function() {
  cr <- unique(c(crossref_search("shiny"), crossref_search("shinyapps")))
  message(sprintf("Crossref hits: %d", length(cr)))
  cr_rows <- do.call(rbind, lapply(cr, function(it) data.frame(
    api = "crossref",
    doi = tolower(it$DOI %||% ""),
    year = it$published$`date-parts`[[1]][[1]] %||% NA,
    first_author = first_author(it),
    title = it$title[[1]] %||% "",
    abstract_urls = extract_urls(it$abstract %||% ""),
    stringsAsFactors = FALSE
  )))

  s2 <- s2_search("shiny")
  message(sprintf("Semantic Scholar hits: %d", length(s2)))
  s2_rows <- if (length(s2)) do.call(rbind, lapply(s2, function(it) data.frame(
    api = "s2",
    doi = tolower(it$externalIds$DOI %||% ""),
    year = it$year %||% NA,
    first_author = "",
    title = it$title %||% "",
    abstract_urls = extract_urls(it$abstract %||% ""),
    stringsAsFactors = FALSE
  ))) else NULL

  out <- rbind(cr_rows, s2_rows)
  out <- out[!duplicated(out$doi) & nzchar(out$doi), ]
  write.csv(out, "audit/candidates_metadata.csv", row.names = FALSE)
  message(sprintf("Wrote audit/candidates_metadata.csv (%d unique DOIs)", nrow(out)))
  invisible(out)
}

if (sys.nframe() == 0) main()
