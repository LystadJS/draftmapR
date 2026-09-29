source("../covariance-analysis.R", local = TRUE)

study05_cov_test_tables <- function(n = 24L) {
  angle <- seq_len(n) * 2 * pi / n
  errors <- cbind(2 * cos(angle), sin(angle))
  e <- data.frame(case_id = "synthetic", frame = "core", entity = "E015",
    dataset_id = seq_len(n), observed_success = TRUE, dx = errors[, 1L], dy = errors[, 2L],
    truth_dx = 0, truth_dy = 0, observed_jackknife_ok = TRUE)
  S <- stats::cov(errors)
  make <- function(method, multiplier) data.frame(e[, c("case_id", "frame", "entity", "dataset_id")],
    method = method, delivered = TRUE, var_dx = multiplier * S[1L, 1L],
    var_dy = multiplier * S[2L, 2L], cov_dx_dy = multiplier * S[1L, 2L])
  list(estimates = e, regions = rbind(make("wald", 2), make("jackknife_wald", 3)))
}

testthat::test_that("covariance ratios and generalized spectra use matched cohorts", {
  tables <- study05_cov_test_tables()
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  testthat::expect_equal(x$summary$covariance_trace_ratio, c(2, 3), tolerance = 1e-12)
  testthat::expect_equal(x$summary$generalized_ratio_min, c(2, 3), tolerance = 1e-12)
  testthat::expect_equal(x$summary$generalized_ratio_max, c(2, 3), tolerance = 1e-12)
  testthat::expect_identical(x$summary$ratio_se_status, c("available", "available"))
  testthat::expect_true(all(is.finite(x$summary$covariance_trace_ratio_jackknife_mcse)))
  testthat::expect_equal(nrow(x$outer_deletions), 48L)
  testthat::expect_true(all(x$outer_deletions$attempted & x$outer_deletions$success))
  testthat::expect_equal(nrow(x$variability), 24L)
  testthat::expect_equal(x$summary$generalized_orientation_identified, c(0, 0))
  testthat::expect_equal(x$summary$principal_axis_angle_degrees, c(0, 0), tolerance = 1e-6)

  # The first two error vectors are changed drastically but their bootstrap
  # covariance is absent, so neither is in that covariance ratio denominator.
  tables$estimates$dx[1:2] <- c(100, -100)
  tables$regions$var_dx[tables$regions$method == "wald" & tables$regions$dataset_id <= 2L] <- NA_real_
  S <- stats::cov(cbind(tables$estimates$dx[-(1:2)], tables$estimates$dy[-(1:2)]))
  use <- tables$regions$method == "wald" & tables$regions$dataset_id > 2L
  tables$regions[use, c("var_dx", "var_dy", "cov_dx_dy")] <-
    rep(list(2 * S[1L, 1L], 2 * S[2L, 2L], 2 * S[1L, 2L]), 1)
  tables$regions$delivered[use] <- FALSE
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  b <- x$summary[x$summary$method == "wald", ]
  testthat::expect_equal(b$n_covariance_pairs, 22L)
  testthat::expect_equal(b$covariance_trace_ratio, 2, tolerance = 1e-12)
  testthat::expect_equal(b$n_matched_region_delivered, 0L)
  testthat::expect_gt(x$all_observed$var_dx, b$outer_var_dx * 10)
  testthat::expect_equal(b$outer_var_dx, S[1L, 1L])
  testthat::expect_true(all(x$outer_deletions$excluded_dataset_id[x$outer_deletions$method == "wald"] > 2L))
})

testthat::test_that("outer deletion recomputes numerator and denominator", {
  tables <- study05_cov_test_tables()
  tables$regions$var_dx[tables$regions$method == "wald"] <- seq_len(24L) / 10
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  first <- x$outer_deletions[x$outer_deletions$method == "wald" &
    x$outer_deletions$excluded_dataset_id == 1L, ]
  r <- tables$regions[tables$regions$method == "wald" & tables$regions$dataset_id != 1L, ]
  errors <- as.matrix(tables$estimates[-1L, c("dx", "dy")])
  expected <- mean(r$var_dx + r$var_dy) / sum(diag(stats::cov(errors)))
  testthat::expect_equal(first$covariance_trace_ratio, expected, tolerance = 1e-12)
  jack <- x$outer_deletions$covariance_trace_ratio[x$outer_deletions$method == "wald"]
  expected_se <- sqrt(23 / 24 * sum((jack - mean(jack))^2))
  testthat::expect_equal(x$summary$covariance_trace_ratio_jackknife_mcse[1L], expected_se, tolerance = 1e-12)
})

testthat::test_that("one failed required outer deletion invalidates every ratio SE", {
  tables <- study05_cov_test_tables(20L)
  tables$estimates$dx <- seq_len(20L)
  tables$estimates$dy <- c(rep(0, 19L), 1)
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  testthat::expect_equal(x$summary$generalized_ratio_status, rep("available", 2L))
  testthat::expect_equal(x$summary$ratio_se_status, rep("required_outer_deletion_failed", 2L))
  testthat::expect_true(all(is.na(x$summary$covariance_trace_ratio_jackknife_mcse)))
  testthat::expect_true(all(is.na(x$summary$generalized_ratio_min_jackknife_mcse)))
  testthat::expect_true(all(is.na(x$summary$generalized_ratio_max_jackknife_mcse)))
  testthat::expect_equal(x$summary$n_outer_deletions_failed, c(1L, 1L))
  testthat::expect_equal(x$summary$n_outer_deletions_attempted, c(20L, 20L))
  failed <- x$outer_deletions[x$outer_deletions$failed_after_attempt, ]
  testthat::expect_equal(failed$excluded_dataset_id, c(20L, 20L))
  testthat::expect_equal(failed$status, rep("outer_covariance_not_spd", 2L))
  testthat::expect_true(all(is.finite(failed$covariance_trace_ratio)))
  testthat::expect_true(all(is.na(failed$generalized_ratio_min)))
})

testthat::test_that("tiny and empty matched cohorts retain counts without invented SEs", {
  tables <- study05_cov_test_tables(19L)
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  testthat::expect_equal(x$summary$ratio_se_status, rep("fewer_than_20_matched_panels", 2L))
  testthat::expect_true(all(is.finite(x$summary$covariance_trace_ratio)))
  testthat::expect_true(all(!x$outer_deletions$attempted & x$outer_deletions$required))
  testthat::expect_equal(x$summary$n_outer_deletions_unattempted, c(19L, 19L))

  tables$estimates$observed_success <- FALSE
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  testthat::expect_equal(x$summary$n_covariance_pairs, c(0L, 0L))
  testthat::expect_equal(x$summary$n_covariance_available, c(19L, 19L))
  testthat::expect_true(all(is.na(x$summary$covariance_trace_ratio)))
  testthat::expect_equal(nrow(x$outer_deletions), 0L)
  testthat::expect_equal(x$all_observed$n_finite_observed_error, 0L)
  x <- study05_covariance_analysis(tables$estimates[FALSE, ], tables$regions[FALSE, ])
  testthat::expect_true(all(vapply(x, nrow, integer(1)) == 0L))
})

testthat::test_that("nonfinite errors, JK status, and delivery define separate cohorts", {
  tables <- study05_cov_test_tables()
  tables$estimates$dx[1] <- NA_real_
  tables$estimates$observed_jackknife_ok[2:3] <- FALSE
  tables$regions$delivered <- FALSE
  x <- study05_covariance_analysis(tables$estimates, tables$regions)
  testthat::expect_equal(x$summary$n_finite_observed_error, c(23L, 23L))
  testthat::expect_equal(x$summary$n_covariance_available, c(24L, 22L))
  testthat::expect_equal(x$summary$n_covariance_pairs, c(23L, 21L))
  testthat::expect_equal(x$summary$n_region_delivered, c(0L, 0L))
})

testthat::test_that("SPD threshold and covariance orientation are explicit and unridged", {
  errors <- rbind(c(-2, 0), c(2, 0), c(0, -1), c(0, 1))
  covs <- matrix(rep(c(16 / 3, 2 / 3, 0), 4L), ncol = 3L, byrow = TRUE)
  x <- study05_cov_ratio(errors, covs)
  testthat::expect_equal(x$values[c("generalized_ratio_min", "generalized_ratio_max")],
    c(generalized_ratio_min = 1, generalized_ratio_max = 2), tolerance = 1e-12)
  testthat::expect_equal(unname(x$values[c("generalized_max_dx", "generalized_max_dy")]), c(1, 0))
  testthat::expect_equal(x$values["generalized_orientation_identified"], c(generalized_orientation_identified = 1))
  weak <- errors
  weak[, 2L] <- weak[, 2L] * 1e-5
  x <- study05_cov_ratio(weak, covs)
  testthat::expect_identical(x$status, "outer_covariance_not_spd")
  testthat::expect_true(is.finite(x$values["outer_eigen_min"]))
  testthat::expect_lt(x$values["outer_eigen_ratio"], 1e-8)
  testthat::expect_true(is.na(x$values["generalized_ratio_min"]))
})

testthat::test_that("covariance analysis rejects duplicate or unmatched panel identities", {
  tables <- study05_cov_test_tables()
  testthat::expect_error(study05_covariance_analysis(rbind(tables$estimates, tables$estimates[1L, ]),
    tables$regions), "Duplicate observed")
  testthat::expect_error(study05_covariance_analysis(tables$estimates,
    rbind(tables$regions, tables$regions[1L, ])), "Duplicate method")
  tables$regions$dataset_id[1L] <- 500L
  testthat::expect_error(study05_covariance_analysis(tables$estimates, tables$regions), "no matching")
})
