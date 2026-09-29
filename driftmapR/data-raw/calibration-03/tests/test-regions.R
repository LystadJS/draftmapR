# These are research-helper tests, outside the public package test directory.
if (!exists("study03_studentized_region", mode = "function")) {
  candidates <- c("regions.R", "../regions.R",
                  "data-raw/calibration-03/regions.R",
                  "driftmapR/data-raw/calibration-03/regions.R")
  path <- candidates[file.exists(candidates)][1L]
  if (is.na(path)) stop("Cannot locate calibration-03/regions.R.")
  source(path, local = TRUE)
}

study03_region_fixture <- function(...) {
  inputs <- list(observed = c(0.4, -0.2),
                 observed_cov = matrix(c(4, 1, 1, 2), 2L),
                 pivots = seq(0.1, 8, length.out = 199L),
                 truth = c(0.8, 0.5), B = 199L)
  inputs[names(list(...))] <- list(...)
  do.call(study03_studentized_region, inputs)
}

testthat::test_that("joint regions agree with independent two-dimensional calculations", {
  observed <- c(0.4, -0.2)
  truth <- c(0.8, 0.5)
  covariance <- matrix(c(4, 1, 1, 2), 2L)
  pivots <- seq(0.1, 8, length.out = 199L)
  result <- study03_region_fixture()
  expected <- c(stats::qchisq(0.95, 2L),
                unname(stats::quantile(pivots, 0.95, type = 7L)))
  inverse <- matrix(c(2, -1, -1, 4), 2L) / 7
  truth_error <- truth - observed
  testthat::expect_identical(result$method,
                            c("jackknife_wald", "jackknife_studentized"))
  testthat::expect_true(all(result$available & result$delivered & result$gate))
  testthat::expect_identical(result$n_valid, c(NA_integer_, 199L))
  testthat::expect_identical(result$pivot_n, rep(199L, 2L))
  testthat::expect_equal(result$cutoff, expected)
  testthat::expect_equal(result$radius, sqrt(expected))
  testthat::expect_equal(result$area, pi * expected * sqrt(7))
  testthat::expect_equal(result$truth_statistic,
                        rep(drop(truth_error %*% inverse %*% truth_error), 2L))
  testthat::expect_equal(result$null_statistic,
                        rep(drop(observed %*% inverse %*% observed), 2L))
  testthat::expect_equal(result$var_dx, rep(4, 2L))
  testthat::expect_equal(result$var_dy, rep(2, 2L))
  testthat::expect_equal(result$cov_dx_dy, rep(1, 2L))
  testthat::expect_identical(result$covered, result$relaxed_covered)
  testthat::expect_identical(result$rejects_zero, result$relaxed_rejects_zero)
})

testthat::test_that("empirical cutoff uses fixed successful pivots and type seven quantiles", {
  pivots <- c(rep(1, 18L), 10, 30)
  result <- study03_region_fixture(pivots = pivots, B = 20L)
  # h = 1 + (20 - 1) * .95 = 19.05, so q = 10 + .05 * 20.
  testthat::expect_equal(result$cutoff[2L], 11, tolerance = 1e-12)
  testthat::expect_equal(result$cutoff[1L], stats::qchisq(0.95, 2L))
  changed <- study03_region_fixture(pivots = pivots, B = 20L, level = 0.9)
  testthat::expect_equal(changed$cutoff[2L],
                        unname(stats::quantile(pivots, 0.9, type = 7L)))
  testthat::expect_equal(changed$cutoff[1L], stats::qchisq(0.9, 2L))
  # Studentization does not recenter, trim, or cap the supplied radial pivots.
  shifted <- study03_region_fixture(pivots = pivots + 100, B = 20L)
  testthat::expect_equal(shifted$cutoff[2L], result$cutoff[2L] + 100)
  testthat::expect_equal(shifted$center_dx, result$center_dx)
  testthat::expect_equal(shifted$center_dy, result$center_dy)
})

testthat::test_that("jackknife covariance is not divided again by the bootstrap budget", {
  small <- study03_region_fixture(pivots = rep(7, 20L), B = 20L)
  large <- study03_region_fixture(pivots = rep(7, 400L), B = 400L)
  for (field in c("area", "radius", "cutoff", "var_dx", "var_dy",
                  "cov_dx_dy", "truth_statistic", "null_statistic")) {
    testthat::expect_equal(small[[field]], large[[field]])
  }
})

testthat::test_that("null coverage and null rejection are complementary", {
  for (observed in list(c(0, 0), c(0.5, -0.25), c(20, 10))) {
    result <- study03_region_fixture(observed = observed, truth = c(0, 0))
    testthat::expect_true(all(result$delivered))
    testthat::expect_equal(result$truth_statistic, result$null_statistic)
    testthat::expect_identical(result$covered, !result$rejects_zero)
  }
})

testthat::test_that("movement coverage and zero-exclusion power remain separate", {
  result <- study03_region_fixture(observed = c(20, 10), truth = c(20, 10))
  testthat::expect_true(all(result$covered))
  testthat::expect_true(all(result$rejects_zero))
  testthat::expect_equal(result$truth_statistic, rep(0, 2L))
  bad_truth <- study03_region_fixture(observed = c(0, 0), truth = c(20, 10))
  testthat::expect_false(any(bad_truth$covered))
  testthat::expect_false(any(bad_truth$rejects_zero))
})

testthat::test_that("region boundary roundoff allowance does not alter substantive decisions", {
  cutoff <- stats::qchisq(0.95, 2L)
  inside <- study03_region_fixture(observed = c(0, 0), observed_cov = diag(2L),
                                   truth = c(sqrt(cutoff), 0))
  outside <- study03_region_fixture(observed = c(0, 0), observed_cov = diag(2L),
                                    truth = c(1.0001 * sqrt(cutoff), 0))
  testthat::expect_true(inside$covered[1L])
  testthat::expect_false(outside$covered[1L])
})

testthat::test_that("success fraction gates studentization but never jackknife Wald", {
  pass <- study03_region_fixture(pivots = seq_len(190L), B = 199L)
  fail <- study03_region_fixture(pivots = seq_len(189L), B = 199L)
  testthat::expect_identical(pass$gate, c(TRUE, TRUE))
  testthat::expect_identical(pass$delivered, c(TRUE, TRUE))
  testthat::expect_identical(fail$gate, c(TRUE, FALSE))
  testthat::expect_identical(fail$available, c(TRUE, TRUE))
  testthat::expect_identical(fail$delivered, c(TRUE, FALSE))
  testthat::expect_identical(fail$reason, c("ok", "below_success_fraction"))
  testthat::expect_true(is.na(fail$covered[2L]))
  testthat::expect_true(is.na(fail$rejects_zero[2L]))
  testthat::expect_false(is.na(fail$relaxed_covered[2L]))
  testthat::expect_false(is.na(fail$relaxed_rejects_zero[2L]))
  relaxed <- study03_region_fixture(pivots = seq_len(189L), B = 199L,
                                    min_success = 0.9)
  testthat::expect_true(all(relaxed$delivered))
  testthat::expect_equal(fail$cutoff, relaxed$cutoff)
  testthat::expect_equal(fail$area, relaxed$area)
})

testthat::test_that("minimum valid pivot threshold has an explicit unavailable outcome", {
  for (n in c(0L, 1L, 2L, 19L)) {
    result <- study03_region_fixture(pivots = seq_len(n), B = 199L)
    testthat::expect_identical(result$available, c(TRUE, FALSE))
    testthat::expect_identical(result$delivered, c(TRUE, FALSE))
    testthat::expect_identical(result$reason[2L], "insufficient_valid")
    testthat::expect_true(is.na(result$relaxed_covered[2L]))
    testthat::expect_true(is.na(result$area[2L]))
  }
  at_threshold <- study03_region_fixture(pivots = seq_len(20L), B = 20L)
  testthat::expect_true(all(at_threshold$delivered))
})

testthat::test_that("zero empirical cutoff is unavailable rather than certainty", {
  result <- study03_region_fixture(pivots = rep(0, 199L))
  testthat::expect_identical(result$available, c(TRUE, FALSE))
  testthat::expect_identical(result$delivered, c(TRUE, FALSE))
  testthat::expect_identical(result$reason[2L], "nonfinite_or_zero_cutoff")
  testthat::expect_true(is.na(result$covered[2L]))
})

testthat::test_that("numerically invalid observed covariances suppress both regions", {
  fixtures <- list(zero = matrix(0, 2L, 2L), singular = matrix(1, 2L, 2L),
                   negative = matrix(c(1, 2, 2, 1), 2L),
                   near_singular = diag(c(1, 1e-10)),
                   nonfinite = matrix(NA_real_, 2L, 2L),
                   asymmetric = matrix(c(2, 0, 1, 3), 2L))
  for (covariance in fixtures) {
    status <- study03_covariance_status(covariance)
    result <- study03_region_fixture(observed_cov = covariance)
    testthat::expect_false(status$valid)
    testthat::expect_false(any(result$available | result$delivered))
    testthat::expect_identical(result$reason, rep(status$reason, 2L))
    testthat::expect_true(all(is.na(result$covered)))
    testthat::expect_true(all(is.na(result$relaxed_covered)))
    testthat::expect_error(study03_quadratic(c(1, 2), covariance))
  }
  permitted <- study03_region_fixture(observed_cov = diag(c(1, 1e-10)),
                                      cov_tol = 1e-12)
  testthat::expect_true(all(permitted$delivered))
  tiny_roundoff <- matrix(c(4, 1 + 1e-13, 1, 2), 2L)
  testthat::expect_true(study03_covariance_status(tiny_roundoff)$valid)
})

testthat::test_that("common rotations and reflections preserve studentized decisions", {
  observed <- c(0.4, -0.2)
  truth <- c(0.8, 0.5)
  covariance <- matrix(c(4, 1, 1, 2), 2L)
  original <- study03_region_fixture()
  angle <- 0.731
  rotation <- matrix(c(cos(angle), -sin(angle), sin(angle), cos(angle)), 2L)
  for (Q in list(rotation, diag(c(-1, 1)), rotation %*% diag(c(-1, 1)))) {
    changed <- study03_region_fixture(observed = drop(observed %*% Q),
                                      truth = drop(truth %*% Q),
                                      observed_cov = t(Q) %*% covariance %*% Q)
    for (field in c("area", "radius", "cutoff", "truth_statistic", "null_statistic")) {
      testthat::expect_equal(changed[[field]], original[[field]], tolerance = 1e-12)
    }
    testthat::expect_identical(changed$covered, original$covered)
    testthat::expect_identical(changed$rejects_zero, original$rejects_zero)
  }
})

testthat::test_that("physical coordinate rescaling transforms area without changing pivots", {
  original <- study03_region_fixture()
  multiplier <- 7.5
  changed <- study03_region_fixture(observed = multiplier * c(0.4, -0.2),
                                    truth = multiplier * c(0.8, 0.5),
                                    observed_cov = multiplier^2 * matrix(c(4, 1, 1, 2), 2L))
  testthat::expect_equal(changed$area, multiplier^2 * original$area)
  testthat::expect_equal(changed$radius, original$radius)
  testthat::expect_equal(changed$truth_statistic, original$truth_statistic)
  testthat::expect_identical(changed$covered, original$covered)
  testthat::expect_equal(study03_quadratic(c(1e150, -1e150), diag(1e300, 2L)), 2)
  testthat::expect_equal(study03_quadratic(c(1e-150, -1e-150), diag(1e-300, 2L)), 2)
})

testthat::test_that("sample-mean jackknife and Hotelling identities validate scaling only", {
  units <- rbind(c(-2, -1), c(0, 1), c(1, 2), c(3, -2),
                 c(-1, 4), c(2, 0), c(4, 2), c(1, -3))
  m <- nrow(units)
  observed <- colMeans(units)
  leave <- t(vapply(seq_len(m), function(j) colMeans(units[-j, , drop = FALSE]),
                    numeric(2L)))
  centered <- sweep(leave, 2L, colMeans(leave), "-")
  jackknife <- (m - 1) / m * crossprod(centered)
  sample_covariance <- stats::cov(units)
  testthat::expect_equal(jackknife, sample_covariance / m, tolerance = 1e-13)
  quadratic <- study03_quadratic(observed, jackknife)
  manual <- m * drop(observed %*% solve(sample_covariance) %*% observed)
  testthat::expect_equal(quadratic, manual, tolerance = 1e-13)
  p <- 2L
  hotelling_cutoff <- p * (m - 1) / (m - p) * stats::qf(0.95, p, m - p)
  testthat::expect_equal(stats::pf((m - p) / (p * (m - 1)) * hotelling_cutoff,
                                 p, m - p), 0.95, tolerance = 1e-13)
  testthat::expect_identical(quadratic <= hotelling_cutoff,
                            stats::pf((m - p) / (p * (m - 1)) * quadratic,
                                      p, m - p) <= 0.95)
  candidate <- study03_region_fixture(observed = observed, observed_cov = jackknife,
                                      pivots = rep(7, 199L))
  testthat::expect_equal(candidate$cutoff, c(stats::qchisq(0.95, 2L), 7))
  testthat::expect_true(all(abs(candidate$cutoff - hotelling_cutoff) > 1))
})

testthat::test_that("malformed inputs and unaccounted failures are rejected", {
  for (bad in list(1, 1:3, c(0, NA), c(Inf, 0), c("0", "1"), matrix(1, 1L, 2L))) {
    testthat::expect_error(study03_region_fixture(observed = bad))
    testthat::expect_error(study03_region_fixture(truth = bad))
    testthat::expect_error(study03_quadratic(bad, diag(2L)))
  }
  for (bad in list(1:4, matrix(1, 3L, 3L), matrix("a", 2L, 2L), data.frame(a = 1:2, b = 1:2))) {
    testthat::expect_error(study03_region_fixture(observed_cov = bad))
    testthat::expect_error(study03_covariance_status(bad))
  }
  for (bad in list(c(1, NA), c(1, Inf), c(1, -1), matrix(1, 20L, 1L),
                   rep(1, 200L), "1", NULL)) {
    testthat::expect_error(study03_region_fixture(pivots = bad))
  }
  for (bad in list(0, 1, -0.1, NA_real_, Inf, c(0.9, 0.95), "0.95")) {
    testthat::expect_error(study03_region_fixture(level = bad))
  }
  for (bad in list(0, 1.01, -0.1, NA_real_, Inf, c(0.9, 0.95), "0.95")) {
    testthat::expect_error(study03_region_fixture(min_success = bad))
  }
  for (bad in list(0, 1, -0.1, NA_real_, Inf, c(1e-8, 1e-6))) {
    testthat::expect_error(study03_covariance_status(diag(2L), bad))
    testthat::expect_error(study03_region_fixture(cov_tol = bad))
  }
  for (bad in list(0, -1, 3.5, NA_real_, Inf, c(199, 200), "199")) {
    testthat::expect_error(study03_region_fixture(B = bad))
  }
  for (bad in list(0, 2, 3.5, NA_real_, Inf, c(20, 30), "20")) {
    testthat::expect_error(study03_region_fixture(min_valid = bad))
  }
})

testthat::test_that("numerical overflow is reported without fabricating a region", {
  result <- study03_region_fixture(observed = c(-1e308, 0), truth = c(1e308, 0))
  testthat::expect_identical(result$reason, rep("nonfinite_error", 2L))
  testthat::expect_false(any(result$delivered))
  overflow <- study03_region_fixture(observed = c(1e300, 0))
  testthat::expect_identical(overflow$reason, rep("nonfinite_statistic", 2L))
  testthat::expect_false(any(overflow$delivered))
})
