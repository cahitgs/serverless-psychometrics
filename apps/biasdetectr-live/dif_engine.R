# Base-R DIF engine for dichotomous (0/1) items.
#
# Methods:
#  - Mantel-Haenszel with total-score stratification (Holland & Thayer, 1988),
#    ETS delta metric (deltaMH = -2.35 * ln(alphaMH)) and A/B/C classification
#    by |deltaMH| (< 1: A, 1-1.5: B, >= 1.5: C; magnitude-based simplification
#    of the full ETS rule).
#  - Binary logistic regression DIF (Swaminathan & Rogers, 1990): three nested
#    models (score; + group; + score:group), likelihood-ratio tests for
#    overall / uniform / non-uniform DIF, and Nagelkerke delta-R2 with
#    Jodoin & Gierl (2001) thresholds (< .035 negligible, .035-.07 moderate,
#    > .07 large).
#
# Matching criterion is the raw total score including the studied item, which
# mirrors the defaults of difR::difMH / difR::difLogistic so results are
# directly comparable. No purification (documented simplification).

dif_mh <- function(items, group, focal) {
  g_focal <- group == focal
  total <- rowSums(items)
  res <- lapply(seq_len(ncol(items)), function(i) {
    item <- items[, i]
    strata <- factor(total)
    tab <- table(item = factor(item, levels = c(1, 0)),
                 group = factor(ifelse(g_focal, "focal", "ref"),
                                levels = c("ref", "focal")),
                 strata = strata)
    a <- tab["1", "ref", ]; b <- tab["0", "ref", ]
    c_ <- tab["1", "focal", ]; d <- tab["0", "focal", ]
    t_ <- a + b + c_ + d
    ok <- t_ > 0
    alpha_mh <- sum(a[ok] * d[ok] / t_[ok]) / sum(b[ok] * c_[ok] / t_[ok])
    delta_mh <- -2.35 * log(alpha_mh)
    mh <- tryCatch(stats::mantelhaen.test(tab, correct = TRUE),
                   error = function(e) list(statistic = NA, p.value = NA))
    ets <- if (!is.finite(delta_mh)) NA_character_
           else if (abs(delta_mh) < 1) "A"
           else if (abs(delta_mh) < 1.5) "B" else "C"
    data.frame(item = colnames(items)[i],
               alpha_mh = alpha_mh,
               delta_mh = delta_mh,
               mh_chisq = as.numeric(mh$statistic),
               p_value = mh$p.value,
               ets_class = ets)
  })
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  out
}

nagelkerke_r2 <- function(model) {
  n <- length(model$y)
  (1 - exp((model$deviance - model$null.deviance) / n)) /
    (1 - exp(-model$null.deviance / n))
}

dif_logistic <- function(items, group, focal) {
  g <- as.integer(group == focal)
  total <- rowSums(items)
  res <- lapply(seq_len(ncol(items)), function(i) {
    y <- items[, i]
    m1 <- stats::glm(y ~ total, family = binomial)
    m2 <- stats::glm(y ~ total + g, family = binomial)
    m3 <- stats::glm(y ~ total * g, family = binomial)
    lrt <- function(small, big) {
      stat <- small$deviance - big$deviance
      df <- small$df.residual - big$df.residual
      c(stat = stat, p = stats::pchisq(stat, df, lower.tail = FALSE))
    }
    overall <- lrt(m1, m3)
    uniform <- lrt(m1, m2)
    nonunif <- lrt(m2, m3)
    d_r2 <- nagelkerke_r2(m3) - nagelkerke_r2(m1)
    jg <- if (d_r2 < 0.035) "negligible"
          else if (d_r2 <= 0.07) "moderate" else "large"
    data.frame(item = colnames(items)[i],
               lrt_overall = overall["stat"], p_overall = overall["p"],
               lrt_uniform = uniform["stat"], p_uniform = uniform["p"],
               lrt_nonuniform = nonunif["stat"], p_nonuniform = nonunif["p"],
               delta_r2 = d_r2, jodoin_gierl = jg)
  })
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  out
}
