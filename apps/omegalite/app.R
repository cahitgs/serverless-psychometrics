# OmegaLite: single-file reliability analysis app.
# Runs unmodified under both server Shiny and Shinylive (webR): it depends
# only on base R (stats) and shiny, so every computation is guaranteed to
# work in the browser.

library(shiny)

# Default upload cap is 5 MB; large response matrices (e.g. N = 50,000) need more.
options(shiny.maxRequestSize = 100 * 1024^2)

# ---- reliability functions (base R only) ------------------------------------

cronbach_alpha <- function(x) {
  k <- ncol(x)
  S <- cov(x)
  k / (k - 1) * (1 - sum(diag(S)) / sum(S))
}

# McDonald's omega_total from a one-factor ML solution (standardized loadings).
mcdonald_omega <- function(x) {
  f <- factanal(x, factors = 1)
  l <- as.numeric(f$loadings)
  sum(l)^2 / (sum(l)^2 + sum(1 - l^2))
}

# Nonparametric bootstrap percentile CI; fixed seed so results are
# reproducible across the server and browser versions of this app.
boot_ci <- function(x, stat, B, conf = 0.95, seed = 1) {
  set.seed(seed)
  est <- rep(NA_real_, B)
  for (b in seq_len(B)) {
    xb <- x[sample(nrow(x), replace = TRUE), , drop = FALSE]
    est[b] <- tryCatch(stat(xb), error = function(e) NA_real_)
  }
  quantile(est, c((1 - conf) / 2, 1 - (1 - conf) / 2), na.rm = TRUE, names = FALSE)
}

item_stats <- function(x) {
  total <- rowSums(x)
  idx <- seq_len(ncol(x))
  data.frame(
    item = colnames(x),
    item_total_r = vapply(idx, function(i) cor(x[, i], total - x[, i]), numeric(1)),
    alpha_if_deleted = vapply(idx, function(i)
      cronbach_alpha(x[, -i, drop = FALSE]), numeric(1)),
    omega_if_deleted = vapply(idx, function(i)
      tryCatch(mcdonald_omega(x[, -i, drop = FALSE]), error = function(e) NA_real_),
      numeric(1)),
    row.names = NULL
  )
}

# ---- app --------------------------------------------------------------------

# Stripping the HTML download attribute is required for downloads to work under
# Shinylive on Chromium browsers (Chromium issue 468227); harmless in server Shiny.
download_btn <- downloadButton("download", "Download results (CSV)")
download_btn$attribs$download <- NULL

ui <- fluidPage(
  titlePanel("OmegaLite"),
  p("Reliability analysis that runs entirely in your browser — your data never leaves this page."),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload CSV", accept = ".csv"),
      uiOutput("item_selector"),
      numericInput("B", "Bootstrap samples for CIs", 200, min = 50, max = 2000, step = 50),
      actionButton("run", "Analyze", class = "btn-primary"),
      hr(),
      download_btn
    ),
    mainPanel(
      verbatimTextOutput("summary"),
      tableOutput("item_table")
    )
  )
)

server <- function(input, output, session) {
  raw <- reactive({
    req(input$file)
    read.csv(input$file$datapath)
  })

  output$item_selector <- renderUI({
    numeric_cols <- names(raw())[vapply(raw(), is.numeric, logical(1))]
    selectInput("items", "Item columns (select 3 or more)", choices = numeric_cols,
                selected = numeric_cols, multiple = TRUE)
  })

  results <- eventReactive(input$run, {
    req(input$items)
    validate(need(length(input$items) >= 3, "Select at least 3 item columns."))
    x <- as.matrix(na.omit(raw()[, input$items, drop = FALSE]))
    validate(need(nrow(x) >= 10, "Fewer than 10 complete rows after listwise deletion."))
    withProgress(message = "Bootstrapping confidence intervals...", value = NULL, {
      list(
        n = nrow(x), k = ncol(x),
        alpha = cronbach_alpha(x),
        omega = tryCatch(mcdonald_omega(x), error = function(e) NA_real_),
        a_ci = boot_ci(x, cronbach_alpha, input$B),
        o_ci = boot_ci(x, mcdonald_omega, input$B),
        items = item_stats(x)
      )
    })
  })

  output$summary <- renderPrint({
    r <- results()
    cat(sprintf("Complete cases: %d    Items: %d\n\n", r$n, r$k))
    cat(sprintf("McDonald's omega_t:  %.3f  [%.3f, %.3f]  (95%% bootstrap CI)\n",
                r$omega, r$o_ci[1], r$o_ci[2]))
    cat(sprintf("Cronbach's alpha:    %.3f  [%.3f, %.3f]\n",
                r$alpha, r$a_ci[1], r$a_ci[2]))
    if (is.na(r$omega))
      cat("\nNote: the one-factor model did not converge; omega is unavailable.\n")
  })

  output$item_table <- renderTable(results()$items, digits = 3)

  output$download <- downloadHandler(
    filename = function() "omegalite_results.csv",
    content = function(file) {
      r <- results()
      scale_rows <- data.frame(
        name = "scale",
        statistic = c("omega_t", "alpha"),
        estimate = c(r$omega, r$alpha),
        ci_lower = c(r$o_ci[1], r$a_ci[1]),
        ci_upper = c(r$o_ci[2], r$a_ci[2])
      )
      item_rows <- data.frame(
        name = rep(r$items$item, times = 3),
        statistic = rep(c("item_total_r", "alpha_if_deleted", "omega_if_deleted"),
                        each = r$k),
        estimate = c(r$items$item_total_r, r$items$alpha_if_deleted,
                     r$items$omega_if_deleted),
        ci_lower = NA_real_, ci_upper = NA_real_
      )
      write.csv(rbind(scale_rows, item_rows), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
