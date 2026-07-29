# Simulate 2PL response data with known DIF for validation and benchmarking.
# 20 dichotomous items, two groups (ref/focal) with equal ability
# distributions (no impact). Planted DIF:
#   item3  - uniform DIF   (focal difficulty +0.6 logits)
#   item7  - non-uniform DIF (focal discrimination x0.4, difficulty +0.3)
#   item12 - uniform DIF   (focal difficulty -0.5, favors focal)
# All other items are DIF-free.

simulate_dif <- function(n_total, seed = 2026) {
  set.seed(seed)
  n_g <- n_total / 2
  k <- 20
  a <- runif(k, 0.8, 2.0)
  b <- seq(-2, 2, length.out = k)
  theta <- rnorm(n_total)
  group <- rep(c("ref", "focal"), each = n_g)
  a_mat <- matrix(a, n_total, k, byrow = TRUE)
  b_mat <- matrix(b, n_total, k, byrow = TRUE)
  focal <- group == "focal"
  b_mat[focal, 3] <- b[3] + 0.6
  a_mat[focal, 7] <- a[7] * 0.4
  b_mat[focal, 7] <- b[7] + 0.3
  b_mat[focal, 12] <- b[12] - 0.5
  p <- 1 / (1 + exp(-a_mat * (theta - b_mat)))
  x <- (matrix(runif(n_total * k), n_total, k) < p) * 1L
  colnames(x) <- sprintf("item%02d", 1:k)
  data.frame(group = group, x)
}

main <- function() {
  dir.create("benchmark/datasets", recursive = TRUE, showWarnings = FALSE)
  for (n in c(1000, 5000, 50000)) {
    d <- simulate_dif(n)
    f <- sprintf("benchmark/datasets/dif_sim_n%d.csv", n)
    write.csv(d, f, row.names = FALSE)
    message("wrote ", f, "  (", round(file.size(f) / 1e6, 2), " MB)")
  }
}

if (sys.nframe() == 0) main()
