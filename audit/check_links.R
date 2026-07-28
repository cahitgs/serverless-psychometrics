# Automated availability probe for audited application URLs.
# Pre-screening only: any URL that returns 2XX is still classified manually
# (shinyapps.io sleep/suspended pages return HTTP 200 -- see audit/protocol.md).
#
# Usage: Rscript audit/check_links.R [input_csv] [output_dir]
#   input_csv  default "audit/results.csv"; must contain a column `app_url`
#   output_dir default "audit/probes"; one dated CSV appended per run

library(httr2)

TIMEOUT_SEC <- 30
USER_AGENT <- "Mozilla/5.0 (Windows NT 10.0; Win64; x64) BRM-availability-audit/1.0"

# Text markers of pages that return 200 but are not the working application.
# This list is a pre-screen; markers found are recorded, and the manual pass
# refines classification (protocol section 4).
SOFT_FAIL_PATTERNS <- c(
  "has been suspended",
  "application is currently unavailable",
  "usage limit",
  "exceeded its allotted",
  "sleeping",
  "wake it up",
  "no application configured",
  "failed to start",
  "domain (is )?parked",
  "account (has been )?closed"
)

probe_url <- function(url) {
  started <- Sys.time()
  result <- list(
    app_url = url,
    checked_at = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    http_status = NA_integer_,
    response_time_s = NA_real_,
    final_url = NA_character_,
    redirected = NA,
    soft_fail_markers = NA_character_,
    auto_class = NA_character_,
    error_message = NA_character_
  )
  resp <- tryCatch(
    request(url) |>
      req_timeout(TIMEOUT_SEC) |>
      req_user_agent(USER_AGENT) |>
      req_error(is_error = function(resp) FALSE) |>
      req_perform(),
    error = function(e) e
  )
  result$response_time_s <- round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2)

  if (inherits(resp, "error")) {
    msg <- conditionMessage(resp)
    result$error_message <- substr(msg, 1, 200)
    result$auto_class <- if (grepl("resolve host|resolve proxy", msg, ignore.case = TRUE)) {
      "dns_error"
    } else if (grepl("timed out|timeout", msg, ignore.case = TRUE)) {
      "timeout"
    } else if (grepl("SSL|certificate", msg, ignore.case = TRUE)) {
      "ssl_error"
    } else {
      "conn_error"
    }
    return(result)
  }

  result$http_status <- resp_status(resp)
  result$final_url <- resp_url(resp)
  result$redirected <- !identical(sub("/$", "", resp_url(resp)), sub("/$", "", url))

  if (result$http_status == 202) {
    # shinyapps.io serves HTTP 202 with a "starting up" interstitial while a
    # sleeping app wakes -- a useful pre-screen signal for intermittent apps.
    result$auto_class <- "waking_202"
  } else if (result$http_status >= 200 && result$http_status < 300) {
    body <- tryCatch(resp_body_string(resp), error = function(e) "")
    hits <- SOFT_FAIL_PATTERNS[vapply(SOFT_FAIL_PATTERNS, function(p)
      grepl(p, body, ignore.case = TRUE), logical(1))]
    result$soft_fail_markers <- if (length(hits)) paste(hits, collapse = "; ") else ""
    result$auto_class <- if (length(hits)) "soft_fail_suspect" else "ok_needs_manual"
  } else if (result$http_status >= 400 && result$http_status < 500) {
    result$auto_class <- "client_error"
  } else if (result$http_status >= 500) {
    result$auto_class <- "server_error"
  } else {
    result$auto_class <- "other_status"
  }
  result
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  input_csv <- if (length(args) >= 1) args[1] else "audit/results.csv"
  output_dir <- if (length(args) >= 2) args[2] else "audit/probes"

  urls <- unique(read.csv(input_csv)$app_url)
  urls <- urls[!is.na(urls) & nzchar(urls)]
  message(sprintf("Probing %d URLs (timeout %ds each)...", length(urls), TIMEOUT_SEC))

  rows <- lapply(urls, function(u) {
    message("  ", u)
    as.data.frame(probe_url(u), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_file <- file.path(output_dir,
                        sprintf("probe-%s.csv", format(Sys.Date(), "%Y-%m-%d")))
  write.csv(out, out_file, row.names = FALSE)
  message("Wrote ", out_file)
  invisible(out)
}

if (sys.nframe() == 0) main()
