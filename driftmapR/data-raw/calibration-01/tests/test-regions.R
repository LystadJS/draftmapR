# Standalone verification: this file is deliberately outside package testthat/
# because candidate regions belong to the bounded study, not the public API.
if (!exists("calibration_regions", mode = "function") ||
    !exists("calibration_gauge_rotation", mode = "function")) {
  candidates <- c(
    "regions.R", "../regions.R", "data-raw/calibration-01/regions.R",
    "driftmapR/data-raw/calibration-01/regions.R",
    "/workspace/scratch/837e4400dd1d/driftmapR/data-raw/calibration-01/regions.R"
  )
  path <- candidates[file.exists(candidates)][1L]
  if (is.na(path)) stop("Cannot locate calibration-01/regions.R.")
  source(path, local = TRUE)
}

region_row <- function(x, method) x[x$method == method, , drop = FALSE]

circle_draws <- function(n = 200L, radius = 1) {
  theta <- 2 * pi * (seq_len(n) - 1L) / n
  radius * cbind(cos(theta), sin(theta))
}

gauge_fit <- function(x, ids = letters[seq_len(nrow(x))], aligned = FALSE) {
  z <- data.frame(entity = ids, period_index = 1L, x = x[, 1L], y = x[, 2L])
  if (aligned) list(coordinates = transform(z, x = x + 100), aligned = z)
  else list(coordinates = z, aligned = NULL)
}

testthat::test_that("all candidate regions agree with independent quadratic calculations", {
  observed <- c(0.45, -0.2)
  truth <- c(0.7, -0.15)
  draws <- sweep(circle_draws() %*% matrix(c(0.8, 0.2, -0.1, 0.4), 2),
                 2L, observed + c(0.2, -0.15), "+")
  result <- calibration_regions(observed, draws, truth, level = 0.9)
  testthat::expect_identical(result$method,
                            c("wald", "bootstrap_mahalanobis", "bootstrap_ball"))
  testthat::expect_true(all(result$available))
  testthat::expect_equal(result$n_valid, rep(nrow(draws), 3L))
  testthat::expect_equal(result$center_dx, rep(observed[1L], 3L))
  testthat::expect_equal(result$center_dy, rep(observed[2L], 3L))
  covariance <- stats::cov(draws)
  inverse <- solve(covariance)
  errors <- sweep(draws, 2L, observed, "-")
  thresholds <- c(
    stats::qchisq(0.9, 2L),
    unname(stats::quantile(rowSums((errors %*% inverse) * errors), 0.9, type = 7L)),
    unname(stats::quantile(sqrt(rowSums(errors^2)), 0.9, type = 7L))
  )
  truth_error <- truth - observed
  truth_quadratic <- as.numeric(t(truth_error) %*% inverse %*% truth_error)
  null_quadratic <- as.numeric(t(observed) %*% inverse %*% observed)
  testthat::expect_equal(result$var_dx, rep(covariance[1L, 1L], 3L))
  testthat::expect_equal(result$var_dy, rep(covariance[2L, 2L], 3L))
  testthat::expect_equal(result$cov_dx_dy, rep(covariance[1L, 2L], 3L))
  testthat::expect_equal(result$truth_statistic,
                        c(truth_quadratic, truth_quadratic, sqrt(sum(truth_error^2))))
  testthat::expect_equal(result$null_statistic,
                        c(null_quadratic, null_quadratic, sqrt(sum(observed^2))))
  testthat::expect_equal(result$radius, c(sqrt(thresholds[1:2]), thresholds[3L]))
  expected_area <- c(pi * thresholds[1:2] * sqrt(det(covariance)),
                     pi * thresholds[3L]^2)
  testthat::expect_equal(result$area, unname(expected_area))
  testthat::expect_identical(result$covered, result$truth_statistic <= thresholds)
  testthat::expect_identical(result$rejects_zero, result$null_statistic > thresholds)
})

testthat::test_that("Wald uses the known two-dimensional chi-square cutoff", {
  n <- 200L
  draws <- circle_draws(n, sqrt(2 * (n - 1L) / n))
  testthat::expect_equal(stats::cov(draws), diag(2L), tolerance = 1e-13)
  cutoff <- stats::qchisq(0.95, df = 2L)
  inside <- calibration_regions(c(0, 0), draws, c(0.999 * sqrt(cutoff), 0))
  outside <- calibration_regions(c(0, 0), draws, c(1.001 * sqrt(cutoff), 0))
  wald <- region_row(inside, "wald")
  testthat::expect_equal(wald$radius, sqrt(cutoff), tolerance = 1e-12)
  testthat::expect_equal(wald$area, pi * cutoff, tolerance = 1e-12)
  testthat::expect_true(wald$covered)
  testthat::expect_false(region_row(outside, "wald")$covered)
  testthat::expect_false(wald$rejects_zero)
})

testthat::test_that("bootstrap covariance estimates sampling variance and is not divided by B", {
  draws <- circle_draws(200L, 2)
  result <- calibration_regions(c(0, 0), draws, c(0, 0))
  covariance <- stats::cov(draws)
  testthat::expect_equal(result$var_dx, rep(covariance[1L, 1L], 3L))
  testthat::expect_gt(result$var_dx[1L], covariance[1L, 1L] / nrow(draws) * 100)
  testthat::expect_equal(region_row(result, "wald")$area,
                        pi * stats::qchisq(0.95, 2L) * sqrt(det(covariance)))
})

testthat::test_that("bootstrap error cutoffs preserve bias relative to the observed estimate", {
  observed <- c(0, 0)
  centered <- circle_draws(200L, 0.2)
  shifted <- sweep(centered, 2L, c(1, 0.5), "+")
  baseline <- calibration_regions(observed, centered, c(0.5, 0.5))
  biased <- calibration_regions(observed, shifted, c(0.5, 0.5))
  testthat::expect_equal(region_row(baseline, "wald")$radius,
                        region_row(biased, "wald")$radius)
  testthat::expect_equal(region_row(baseline, "wald")$area,
                        region_row(biased, "wald")$area)
  testthat::expect_gt(region_row(biased, "bootstrap_mahalanobis")$radius,
                     3 * region_row(baseline, "bootstrap_mahalanobis")$radius)
  testthat::expect_gt(region_row(biased, "bootstrap_ball")$radius,
                     3 * region_row(baseline, "bootstrap_ball")$radius)
  testthat::expect_equal(biased$center_dx, rep(0, 3L))
  testthat::expect_equal(biased$center_dy, rep(0, 3L))
})

testthat::test_that("region coverage is invariant to rotation and reflection of the frame", {
  observed <- c(0.2, -0.5)
  truth <- c(-0.1, -0.1)
  draws <- sweep(circle_draws() %*% matrix(c(0.9, 0.2, 0.4, 0.6), 2L),
                 2L, c(0.3, -0.3), "+")
  original <- calibration_regions(observed, draws, truth)
  theta <- 0.713
  rotation <- matrix(c(cos(theta), -sin(theta), sin(theta), cos(theta)), 2L)
  for (transform in list(rotation, diag(c(-1, 1)), rotation %*% diag(c(-1, 1)))) {
    changed <- calibration_regions(drop(observed %*% transform), draws %*% transform,
                                   drop(truth %*% transform))
    for (field in c("radius", "area", "truth_statistic", "null_statistic")) {
      testthat::expect_equal(changed[[field]], original[[field]], tolerance = 1e-10)
    }
    testthat::expect_identical(changed$covered, original$covered)
    testthat::expect_identical(changed$rejects_zero, original$rejects_zero)
  }
})

testthat::test_that("coordinate rescaling preserves decisions and transforms area correctly", {
  observed <- c(0.2, 0.4)
  truth <- c(0.5, -0.1)
  draws <- sweep(circle_draws() %*% diag(c(0.8, 0.3)), 2L, observed, "+")
  original <- calibration_regions(observed, draws, truth)
  factor <- 7.5
  changed <- calibration_regions(factor * observed, factor * draws, factor * truth)
  testthat::expect_identical(changed$covered, original$covered)
  testthat::expect_identical(changed$rejects_zero, original$rejects_zero)
  testthat::expect_equal(changed$area, factor^2 * original$area)
  testthat::expect_equal(changed$radius[1:2], original$radius[1:2])
  testthat::expect_equal(changed$radius[3L], factor * original$radius[3L])
  testthat::expect_equal(changed$var_dx, factor^2 * original$var_dx)
  testthat::expect_equal(changed$var_dy, factor^2 * original$var_dy)
  testthat::expect_equal(changed$cov_dx_dy, factor^2 * original$cov_dx_dy)
})

testthat::test_that("singular covariance leaves the positive-radius bootstrap ball available", {
  draws <- cbind(seq(-1, 1, length.out = 40L), 0)
  result <- calibration_regions(c(0, 0), draws, c(0.1, 0))
  testthat::expect_identical(result$available, c(FALSE, FALSE, TRUE))
  testthat::expect_identical(result$reason[1:2], rep("singular_covariance", 2L))
  testthat::expect_true(all(is.na(result$covered[1:2])))
  testthat::expect_true(all(is.na(result$rejects_zero[1:2])))
  testthat::expect_true(region_row(result, "bootstrap_ball")$covered)
  testthat::expect_gt(region_row(result, "bootstrap_ball")$radius, 0)
})

testthat::test_that("near singular covariance is rejected using a relative spectral tolerance", {
  draws <- circle_draws(100L) %*% diag(c(1, 1e-5))
  result <- calibration_regions(c(0, 0), draws, c(0, 0), cov_tol = 1e-8)
  testthat::expect_identical(result$available, c(FALSE, FALSE, TRUE))
  permitted <- calibration_regions(c(0, 0), draws, c(0, 0), cov_tol = 1e-12)
  testthat::expect_true(all(permitted$available))
})

testthat::test_that("constant bootstrap draws distinguish zero radius from nonzero bias", {
  at_observed <- matrix(rep(c(0.2, 0.3), each = 40L), ncol = 2L)
  result <- calibration_regions(c(0.2, 0.3), at_observed, c(0.2, 0.3))
  testthat::expect_false(any(result$available))
  testthat::expect_identical(region_row(result, "bootstrap_ball")$reason, "zero_radius")
  shifted <- calibration_regions(c(0, 0), at_observed, c(0, 0))
  testthat::expect_identical(shifted$available, c(FALSE, FALSE, TRUE))
  testthat::expect_equal(region_row(shifted, "bootstrap_ball")$radius,
                        sqrt(0.2^2 + 0.3^2))
})

testthat::test_that("insufficient valid draws are explicitly unavailable without imputation", {
  for (n in c(0L, 1L, 2L, 19L)) {
    draws <- matrix(seq_len(2L * n), ncol = 2L)
    result <- calibration_regions(c(0, 0), draws, c(0, 0))
    testthat::expect_equal(nrow(result), 3L)
    testthat::expect_false(any(result$available))
    testthat::expect_identical(result$reason, rep("insufficient_valid", 3L))
    testthat::expect_equal(result$n_valid, rep(n, 3L))
    testthat::expect_true(all(is.na(result$covered)))
    testthat::expect_true(all(is.na(result$rejects_zero)))
  }
  at_threshold <- calibration_regions(c(0, 0), circle_draws(20L), c(0, 0))
  testthat::expect_true(all(at_threshold$available))
})

testthat::test_that("malformed region inputs are errors rather than silently dropped draws", {
  draws <- circle_draws()
  for (bad in list(NA_real_, c(0, NA), c(Inf, 0), 1, 1:3, c("0", "1"))) {
    testthat::expect_error(calibration_regions(bad, draws, c(0, 0)))
    testthat::expect_error(calibration_regions(c(0, 0), draws, bad))
  }
  bad_draws <- list(as.data.frame(draws), as.vector(draws), matrix(1, 30L, 3L),
                    matrix("a", 30L, 2L), replace(draws, 1L, NA_real_),
                    replace(draws, 1L, Inf))
  for (bad in bad_draws) {
    testthat::expect_error(calibration_regions(c(0, 0), bad, c(0, 0)))
  }
  for (bad in list(0, 1, -0.1, 1.1, NA_real_, Inf, c(0.9, 0.95))) {
    testthat::expect_error(calibration_regions(c(0, 0), draws, c(0, 0), level = bad))
  }
  for (bad in list(0, 1, -0.1, NA_real_, Inf, c(1e-8, 1e-6))) {
    testthat::expect_error(calibration_regions(c(0, 0), draws, c(0, 0), cov_tol = bad))
  }
  for (bad in list(0, 2, 3.5, NA_real_, Inf, c(20L, 30L))) {
    testthat::expect_error(calibration_regions(c(0, 0), draws, c(0, 0), min_valid = bad))
  }
})

testthat::test_that("gauge rotation recovers known row-vector transforms despite translation", {
  population <- rbind(c(-2, -1), c(2, -1), c(1, 2), c(-1, 1), c(0.5, -0.4))
  theta <- 0.731
  rotation <- matrix(c(cos(theta), -sin(theta), sin(theta), cos(theta)), 2L)
  for (transform in list(diag(2L), rotation, diag(c(-1, 1)), rotation %*% diag(c(-1, 1)))) {
    observed <- sweep(population %*% t(transform), 2L, c(8, -13), "+")
    recovered <- calibration_gauge_rotation(gauge_fit(observed), gauge_fit(population))
    testthat::expect_equal(unname(recovered), transform, tolerance = 1e-12)
    testthat::expect_equal(unname(crossprod(recovered)), diag(2L), tolerance = 1e-12)
    testthat::expect_equal(det(recovered), det(transform), tolerance = 1e-12)
  }
})

testthat::test_that("gauge rotation matches entity identities and uses the aligned baseline", {
  population <- rbind(c(-2, -1), c(2, -1), c(1, 2), c(-1, 1), c(0.5, -0.4))
  rotation <- matrix(c(0, 1, -1, 0), 2L)
  observed <- sweep(population %*% t(rotation), 2L, c(-3, 6), "+")
  source <- gauge_fit(observed, aligned = TRUE)
  source$coordinates$x <- source$coordinates$x^2
  source$aligned <- source$aligned[c(5, 2, 4, 1, 3), ]
  target <- gauge_fit(population, aligned = TRUE)
  target$aligned <- target$aligned[c(3, 4, 1, 5, 2), ]
  source$aligned <- rbind(source$aligned,
                          transform(source$aligned, period_index = 2L, x = 1e5, y = -1e5))
  recovered <- calibration_gauge_rotation(source, target)
  testthat::expect_equal(unname(recovered), rotation, tolerance = 1e-12)
})

testthat::test_that("gauge anchors exclude moving or unmatched entities without fitting a scale", {
  population <- rbind(c(-2, -1), c(2, -1), c(1, 2), c(-1, 1), c(0.5, -0.4))
  rotation <- matrix(c(0, -1, 1, 0), 2L)
  observed <- sweep(3 * population %*% t(rotation), 2L, c(-3, 6), "+")
  observed[5L, ] <- c(100, -80)
  source <- gauge_fit(observed)
  target <- gauge_fit(population)
  target$coordinates$entity[5L] <- "new"
  recovered <- calibration_gauge_rotation(source, target, anchors = letters[1:4])
  testthat::expect_equal(unname(recovered), rotation, tolerance = 1e-12)
  testthat::expect_equal(unname(crossprod(recovered)), diag(2L), tolerance = 1e-12)
})

testthat::test_that("gauge rejects insufficient or nonidentifiable fitting geometry", {
  proper <- rbind(c(-2, -1), c(2, -1), c(1, 2), c(-1, 1), c(0.5, -0.4))
  line <- cbind(seq_len(5L), seq_len(5L))
  testthat::expect_error(calibration_gauge_rotation(gauge_fit(line), gauge_fit(proper)))
  testthat::expect_error(calibration_gauge_rotation(gauge_fit(proper), gauge_fit(line)))
  testthat::expect_error(calibration_gauge_rotation(gauge_fit(proper), gauge_fit(proper),
                                                  anchors = letters[1:2]))
  insufficient <- gauge_fit(proper)
  insufficient$coordinates$entity <- c("a", "b", "x", "y", "z")
  testthat::expect_error(calibration_gauge_rotation(gauge_fit(proper), insufficient))
  # Each map has rank two, but their centered cross-product is singular.
  source <- cbind(c(1, -1, 0, 0), c(0, 0, 1, -1))
  target <- cbind(c(1, -1, 0, 0), c(1, 1, -1, -1))
  testthat::expect_equal(qr(scale(source, scale = FALSE))$rank, 2L)
  testthat::expect_equal(qr(scale(target, scale = FALSE))$rank, 2L)
  testthat::expect_error(calibration_gauge_rotation(gauge_fit(source), gauge_fit(target)))
})
