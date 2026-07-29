# BiasDetectR Live: differential item functioning (DIF) analysis that runs
# entirely in the browser. Depends only on base R (stats) + shiny; the DIF
# engine (dif_engine.R) is validated to machine precision against difR
# (see benchmark/equivalence_engine_vs_difR.csv).

library(shiny)

options(shiny.maxRequestSize = 200 * 1024^2)

source("dif_engine.R", local = TRUE)

# Chromium issue 468227: downloads need the download attribute stripped in
# Shinylive; harmless in server Shiny.
download_btn <- downloadButton("download", "Download results (CSV)")
download_btn$attribs$download <- NULL

ui <- fluidPage(
  titlePanel("BiasDetectR Live"),
  p("Mantel–Haenszel and logistic-regression DIF for dichotomous items — runs entirely in your browser; your data never leaves this page."),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload CSV (0/1 item scores + a group column)", accept = ".csv"),
      uiOutput("group_selector"),
      uiOutput("focal_selector"),
      uiOutput("item_selector"),
      actionButton("run", "Analyze", class = "btn-primary"),
      hr(),
      download_btn
    ),
    mainPanel(
      verbatimTextOutput("summary"),
      plotOutput("delta_plot", height = "300px"),
      h4("Mantel–Haenszel"),
      tableOutput("mh_table"),
      h4("Logistic regression"),
      tableOutput("lr_table")
    )
  )
)

server <- function(input, output, session) {
  raw <- reactive({
    req(input$file)
    read.csv(input$file$datapath)
  })

  output$group_selector <- renderUI({
    selectInput("group_col", "Group column", choices = names(raw()))
  })
  output$focal_selector <- renderUI({
    req(input$group_col)
    lv <- unique(raw()[[input$group_col]])
    selectInput("focal", "Focal group", choices = lv, selected = lv[length(lv)])
  })
  output$item_selector <- renderUI({
    req(input$group_col)
    binary <- names(raw())[vapply(raw(), function(x)
      is.numeric(x) && all(x %in% c(0, 1, NA)), logical(1))]
    binary <- setdiff(binary, input$group_col)
    selectInput("items", "Item columns (0/1)", choices = binary,
                selected = binary, multiple = TRUE)
  })

  results <- eventReactive(input$run, {
    req(input$items, input$group_col, input$focal)
    validate(need(length(input$items) >= 4, "Select at least 4 item columns."))
    dat <- raw()[, c(input$group_col, input$items)]
    dat <- dat[stats::complete.cases(dat), ]
    grp <- as.character(dat[[input$group_col]])
    validate(need(length(unique(grp)) == 2,
                  "The group column must have exactly 2 levels."),
             need(input$focal %in% grp, "Focal level not found in data."))
    x <- as.matrix(dat[, input$items, drop = FALSE])
    withProgress(message = "Running DIF analyses...", value = NULL, {
      list(n = nrow(x), k = ncol(x),
           n_focal = sum(grp == input$focal),
           mh = dif_mh(x, grp, input$focal),
           lr = dif_logistic(x, grp, input$focal))
    })
  })

  output$summary <- renderPrint({
    r <- results()
    cat(sprintf("Complete cases: %d (focal: %d, reference: %d)   Items: %d\n",
                r$n, r$n_focal, r$n - r$n_focal, r$k))
    flagged <- r$mh$item[r$mh$ets_class %in% c("B", "C")]
    cat("MH-flagged items (ETS B/C):",
        if (length(flagged)) paste(flagged, collapse = ", ") else "none", "\n")
  })

  output$delta_plot <- renderPlot({
    r <- results()
    cols <- c(A = "grey50", B = "orange", C = "red")[r$mh$ets_class]
    plot(seq_len(r$k), r$mh$delta_mh, pch = 19, col = cols, xaxt = "n",
         xlab = "", ylab = expression(Delta[MH]),
         main = "ETS delta by item (|1| = B, |1.5| = C thresholds)",
         ylim = range(c(-2, 2, r$mh$delta_mh), finite = TRUE))
    axis(1, at = seq_len(r$k), labels = r$mh$item, las = 2, cex.axis = 0.8)
    abline(h = c(-1.5, -1, 1, 1.5), lty = c(3, 2, 2, 3), col = "grey60")
    abline(h = 0, col = "grey80")
  })

  output$mh_table <- renderTable(results()$mh, digits = 3)
  output$lr_table <- renderTable(results()$lr, digits = 3)

  output$download <- downloadHandler(
    filename = function() "biasdetectr_results.csv",
    content = function(file) {
      r <- results()
      write.csv(merge(r$mh, r$lr, by = "item", sort = FALSE),
                file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
