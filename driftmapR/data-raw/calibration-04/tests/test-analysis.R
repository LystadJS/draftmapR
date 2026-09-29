# Handbuilt deterministic analysis fixtures. No study 04 random stream is used.
study04_test_null_estimates <- function() {
  grid <- expand.grid(dataset_id = 1:400, entity = c("E015", "E003", "E006"),
    case_id = c("regular_null_m40", "regular_null_m160"), stringsAsFactors = FALSE)
  grid$scenario <- "regular_null"; grid$m <- ifelse(grid$case_id == "regular_null_m40", 40L, 160L)
  grid$observed_success <- TRUE; grid$truth_dx <- grid$truth_dy <- 0
  grid$dx <- sin(grid$dataset_id * .173) / 10
  grid$dy <- cos(grid$dataset_id * .277) / 8
  grid
}

study04_test_null_plan <- function() data.frame(case_id = c("regular_null_m40", "regular_null_m160"), M = 400L)

study04_test_sparse <- function() {
  meta <- data.frame(case_id = "rare_axis_m12", scenario = "rare_axis", m = 12L, dataset_id = 1:7)
  outer <- data.frame(meta, observed_success = c(FALSE, rep(TRUE, 6)), rare_count = c(0, 1, 2, 2, 3, 4, 5),
    B = 199L, observed_jackknife_required = 12L, observed_jackknife_success = c(0L, 11L, rep(12L, 5)))
  estimates <- data.frame(meta, entity = "E015", observed_jackknife_ok = c(FALSE, FALSE, FALSE, rep(TRUE, 4)))
  regions <- data.frame(meta, entity = "E015", method = "jackknife_studentized", n_valid = c(0L, 0L, 199L, 19L, 189L, 199L, 199L),
    available = c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, TRUE), gate = c(FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE),
    delivered = c(rep(FALSE, 6), TRUE), covered = c(rep(NA, 6), TRUE),
    relaxed_covered = c(NA, NA, NA, NA, TRUE, NA, TRUE), area = c(rep(NA_real_, 4), 1, NA, 1), cutoff = 6)
  list(outer = outer, estimates = estimates, regions = regions)
}

testthat::test_that("primary replication tests use two fixed fresh conditional denominators", {
  coverage <- data.frame(case_id = c("regular_null_m40", "regular_null_m160"), entity = c("E006", "E003"),
    method = "jackknife_studentized", policy = "production", n_delivered = c(400L, 0L), n_covered = c(360L, 0L), n_outer = 400L)
  result <- study04_primary_replication(coverage)
  testthat::expect_equal(result$p_one_sided[1], stats::pbinom(360L, 400L, .95))
  testthat::expect_equal(result$p_bonferroni[1], min(1, 2 * stats::pbinom(360L, 400L, .95)))
  testthat::expect_equal(result$bonferroni_alpha, rep(.025, 2))
  testthat::expect_true(result$rejects_nominal_after_multiplicity[1])
  testthat::expect_true(is.na(result$p_one_sided[2]))
  testthat::expect_true(is.na(result$rejects_nominal_after_multiplicity[2]))
  testthat::expect_equal(result$historical_covered, c(109L, 110L))
  testthat::expect_match(result$selection_caution[2], "selected")
  testthat::expect_error(study04_primary_replication(rbind(coverage, coverage[1, ])), "exactly one")
})

testthat::test_that("observed point agreement pairs by identity and allows diagnostic-only non-delivery", {
  core <- study04_test_null_estimates()[1:12, ]; frame <- core[12:1, ]
  x <- study04_frame_agreement(core, frame)
  testthat::expect_equal(x$summary$n_jointly_observed, 12L)
  testthat::expect_equal(x$summary$max_absolute_point_difference, 0)
  frame$observed_success[1] <- FALSE; frame$dx[1] <- frame$dy[1] <- NA_real_
  x <- study04_frame_agreement(core, frame)
  testthat::expect_equal(x$summary$n_oracle_only_failure, 1L)
  frame$dx[2] <- frame$dx[2] + 1e-6
  testthat::expect_error(study04_frame_agreement(core, frame), "beyond")
  testthat::expect_error(study04_frame_agreement(core, frame[-1, ]), "planned keys")
})

testthat::test_that("sparse non-delivery has exactly one frozen reason per planned panel", {
  f <- study04_test_sparse()
  x <- study04_nondelivery_reasons(f$outer, f$estimates, f$regions, "core")
  testthat::expect_equal(x$reason, c("observed_fit_unavailable", "required_observed_deletion_failed",
    "observed_covariance_invalid", "fewer_than_20_valid_pivots", "valid_pivot_fraction_below_0.95",
    "final_geometry_unavailable", "delivered"))
  testthat::expect_equal(x$rare_bin, c("0", "1", "2", "2", "3", "4+", "4+"))
  summary <- study04_nondelivery_summary(x)
  all <- summary[summary$rare_bin == "all", ]
  testthat::expect_equal(sum(all$n_in_reason), 7L)
  testthat::expect_equal(all$n_planned, rep(7L, 7))
  testthat::expect_equal(all$conditional_coverage, rep(1, 7))
  testthat::expect_equal(all$operational_coverage_and_delivery, rep(1/7, 7))
  testthat::expect_equal(nrow(summary), 42L)
  f$outer$rare_count[1] <- NA_integer_
  testthat::expect_error(study04_nondelivery_reasons(f$outer, f$estimates, f$regions, "core"), "rare-unit count")
})

testthat::test_that("crossfit donors are exclusively the opposite frozen half", {
  e <- study04_test_null_estimates(); plan <- study04_test_null_plan()
  x <- study04_crossfit_covariance(plan, e)
  testthat::expect_equal(nrow(x$panels), 2400L)
  testthat::expect_equal(nrow(x$donors), 12L)
  testthat::expect_equal(nrow(x$summary), 18L)
  testthat::expect_true(all(x$panels$delivered))
  testthat::expect_true(all(x$donors$n_donor_finite == 200L))
  testthat::expect_true(all(x$donors$donor_half != x$donors$evaluation_half))
  e$dx[e$dataset_id <= 200L] <- 3 * e$dx[e$dataset_id <= 200L]
  y <- study04_crossfit_covariance(plan, e)
  h1 <- x$donors$evaluation_half == 1L; h2 <- !h1
  testthat::expect_equal(x$donors$var_dx[h1], y$donors$var_dx[h1])
  testthat::expect_equal(9 * x$donors$var_dx[h2], y$donors$var_dx[h2], tolerance = 1e-12)
  testthat::expect_false(any(grepl("mcse|wilson", names(x$summary))))
})

testthat::test_that("crossfit donor boundary is 190 of 200 and unavailable panels remain", {
  e <- study04_test_null_estimates(); plan <- study04_test_null_plan()
  use <- e$dataset_id <= 10L
  e$observed_success[use] <- FALSE; e$dx[use] <- e$dy[use] <- NA_real_
  x <- study04_crossfit_covariance(plan, e)
  testthat::expect_true(all(x$donors$covariance_ok))
  testthat::expect_equal(sum(!x$panels$delivered), 60L)
  use <- e$dataset_id == 11L
  e$observed_success[use] <- FALSE; e$dx[use] <- e$dy[use] <- NA_real_
  y <- study04_crossfit_covariance(plan, e)
  testthat::expect_true(all(!y$donors$covariance_ok[y$donors$evaluation_half == 2L]))
  testthat::expect_equal(sum(!y$panels$delivered), 1266L)
  testthat::expect_equal(nrow(y$panels), 2400L)
  testthat::expect_true(all(y$panels$reason[y$panels$evaluation_half == 2L] == "fewer_than_190_of_200_finite_donors"))
  testthat::expect_error(study04_crossfit_covariance(plan, e[-1, ]), "every planned")
  plan$M[1] <- 401L
  testthat::expect_error(study04_crossfit_covariance(plan, e), "400-panel")
})

testthat::test_that("crossfit singular covariance does not deliver a nominal ellipse", {
  e <- study04_test_null_estimates(); e$dy <- 2 * e$dx
  x <- study04_crossfit_covariance(study04_test_null_plan(), e)
  testthat::expect_false(any(x$panels$delivered))
  testthat::expect_true(all(is.na(x$panels$covered)))
  testthat::expect_equal(nrow(x$panels), 2400L)
})

testthat::test_that("paired frame metrics use joint delivery and covariance cohorts", {
  f <- study04_test_sparse(); a <- f$regions[rep(7L, 3L), ]; a$dataset_id <- 1:3
  a$var_dx <- .01; a$var_dy <- .02; a$cov_dx_dy <- .001; a$rejects_zero <- FALSE
  b <- a; b$area <- 2 * a$area; b$cutoff <- 2 * a$cutoff; b$var_dx <- 2 * a$var_dx
  b$var_dy <- 2 * a$var_dy; b$cov_dx_dy <- 2 * a$cov_dx_dy
  x <- study04_frame_comparisons(a, b[3:1, ])
  testthat::expect_equal(x$difference[x$metric == "log_area_ratio_joint_delivery"], log(2))
  testthat::expect_equal(x$difference[x$metric == "log_covariance_trace_ratio_joint_positive"], log(2))
  testthat::expect_equal(x$difference[x$metric == "conditional_coverage_joint_delivery"], 0)
  b$delivered[1] <- FALSE; b$covered[1] <- b$rejects_zero[1] <- NA
  x <- study04_frame_comparisons(a, b)
  testthat::expect_equal(x$n_pairs[x$metric == "conditional_coverage_joint_delivery"], 2)
  testthat::expect_equal(x$difference[x$metric == "delivery"], -1/3)
  testthat::expect_equal(x$n_pairs[x$metric == "covariance_trace_joint_finite"], 3)
})

testthat::test_that("frame rotation variation first aggregates within outer panels", {
  a <- data.frame(case_id = "regular_null_m40", scenario = "regular_null", m = 40L,
    dataset_id = c(1L, 1L, 2L, 2L), success = c(TRUE, FALSE, TRUE, TRUE), attempted = TRUE,
    rotation_distance_from_observed = c(1, NA, 2, 4), rotation_determinant = c(1, NA, 1, -1))
  x <- study04_frame_variation(a)
  testthat::expect_equal(x$panels$mean_rotation_distance, c(1, 3))
  testthat::expect_equal(x$summary$mean_rotation_distance, 2)
  testthat::expect_equal(x$summary$rotation_distance_outer_mcse, 1)
  testthat::expect_equal(x$summary$n_outer_defined, 2L)
})

testthat::test_that("analytic sparse rank benchmark preserves the frozen 190 of 199 gate", {
  x <- study04_sparse_rank_benchmark()
  testthat::expect_equal(sum(x$observed_count_probability), 1, tolerance = 1e-14)
  testthat::expect_equal(sum(x$expected_panels_of_120), 120, tolerance = 1e-12)
  testthat::expect_equal(x$rank_only_delivery_probability_given_count[1:2], c(0, 0))
  testthat::expect_equal(x$rank_only_delivery_probability_given_count[13], 1)
  testthat::expect_equal(x$bootstrap_full_rank_probability[1], 0)
  testthat::expect_equal(x$bootstrap_complete_jackknife_rank_probability[13], 1)
  p <- 1 - stats::dbinom(0, 12, 3/12) - stats::dbinom(1, 12, 3/12)
  testthat::expect_equal(x$rank_only_delivery_probability_given_count[4], sum(stats::dbinom(190:199, 199, p)))
})
