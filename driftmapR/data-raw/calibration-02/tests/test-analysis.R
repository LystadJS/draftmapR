# Fabricated complete ledgers test denominators and pairing; no fresh study data.
if (!exists("study02_analyze", mode = "function")) {
  candidates <- c("driftmapR/data-raw/calibration-02/analyze.R", "data-raw/calibration-02/analyze.R",
                   "../analyze.R", "analyze.R")
  source(candidates[file.exists(candidates)][1L], local = TRUE)
}

study02_analysis_fixture <- function(budgets = c(199L, 399L)) {
  outer <- expand.grid(m = c(20L, 40L), dataset_id = 1:4, stringsAsFactors = FALSE)
  outer$observed_success <- outer$dataset_id != 1L
  levels <- expand.grid(anchor = c("original", "spread"),
    estimator = c("refit_plugin", "refit_oracle", "tangent_oracle"),
    entity = c("E015", "E003", "E006"), stringsAsFactors = FALSE)
  estimates <- merge(outer, levels, by = NULL)
  x <- c(NA, -1, 1, 0)
  y <- c(NA, 0, 0, 1)
  estimates$dx <- x[estimates$dataset_id]
  estimates$dy <- y[estimates$dataset_id]
  estimates$passes_gate <- estimates$observed_success &
    (max(budgets) == 199L | estimates$dataset_id != 2L)
  regions <- merge(estimates, expand.grid(budget = budgets,
    method = c("wald", "bootstrap_mahalanobis", "bootstrap_ball"), stringsAsFactors = FALSE), by = NULL)
  regions$n_valid <- ifelse(!regions$observed_success, 0L,
    ifelse(regions$dataset_id == 2L & regions$budget == 399L, 375L, regions$budget))
  regions$available <- regions$observed_success
  regions$gate <- regions$n_valid >= 20L & regions$n_valid / regions$budget >= .95
  regions$delivered <- regions$available & regions$gate
  regions$covered <- ifelse(regions$delivered, regions$dataset_id %in% 2:3, NA)
  regions$rejects_zero <- ifelse(regions$delivered, !regions$covered, NA)
  regions$area <- ifelse(regions$available, 10, NA_real_)
  regions$var_dx <- ifelse(regions$available, .4 + regions$dataset_id / 10, NA_real_)
  regions$var_dy <- ifelse(regions$available, .2 + regions$dataset_id / 10, NA_real_)
  regions$cov_dx_dy <- ifelse(regions$available, .05, NA_real_)
  regions$truth_statistic <- ifelse(regions$available, regions$dataset_id^2, NA_real_)
  regions$radius <- ifelse(regions$available, sqrt(stats::qchisq(.95, 2)), NA_real_)
  failures <- merge(estimates[estimates$entity == "E015",
    c("m", "dataset_id", "anchor", "estimator")], data.frame(replicate_id = seq_len(max(budgets))), by = NULL)
  failures$attempted <- failures$dataset_id != 1L
  failures$success <- failures$attempted & (failures$dataset_id != 2L | failures$replicate_id <= 375L)
  list(outer = outer, estimates = estimates, regions = regions, failures = failures)
}

study02_fixture_validate <- function(x, budgets = c(199L, 399L)) {
  do.call(study02_validate_analysis, c(x, list(expected_outer = 4L,
    expected_m = c(20L, 40L), budgets = budgets)))
}

study02_tangent_fixture <- function(fixture) {
  x <- fixture$regions[fixture$regions$estimator == "tangent_oracle" &
    fixture$regions$method == "wald" & fixture$regions$budget == max(fixture$regions$budget) &
    fixture$regions$observed_success, ]
  t <- x[c("m", "dataset_id", "anchor", "entity")]
  t$exact_var_dx <- x$var_dx / 2
  t$exact_var_dy <- x$var_dy / 2
  t$exact_cov_dx_dy <- x$cov_dx_dy / 2
  t$total_trace <- t$exact_var_dx + t$exact_var_dy
  t$embedding_trace <- t$total_trace * .5
  t$alignment_trace <- t$total_trace * .75
  t$cross_trace <- -t$total_trace * .25
  t
}

testthat::test_that("Wilson intervals use outer-dataset counts, including zero denominators", {
  answer <- study02_wilson(c(covered = 1), c(delivered = 2))
  testthat::expect_equal(unname(answer["estimate"]), .5)
  testthat::expect_equal(unname(answer["mcse"]), sqrt(.25 / 2))
  testthat::expect_equal(unname(answer[c("lower", "upper")]), c(.094531205734, .905468794266), tolerance = 1e-10)
  testthat::expect_true(all(is.na(study02_wilson(0, 0))))
  testthat::expect_gt(unname(study02_wilson(0, 240)["upper"]), 0)
  testthat::expect_lt(unname(study02_wilson(240, 240)["lower"]), 1)
  testthat::expect_error(study02_wilson(3, 2), "valid counts")
  testthat::expect_error(study02_wilson(1, 2, 1), "probability level")
})

testthat::test_that("complete ledgers reconcile both nested budgets and missing fits", {
  fixture <- study02_analysis_fixture()
  testthat::expect_invisible(study02_fixture_validate(fixture))
  bad <- fixture
  bad$outer <- bad$outer[-1L, ]
  testthat::expect_error(study02_fixture_validate(bad), "exactly 4")
  bad <- fixture
  bad$regions <- bad$regions[-1L, ]
  testthat::expect_error(study02_fixture_validate(bad), "every planned")
  bad <- fixture
  bad$failures <- bad$failures[-1L, ]
  testthat::expect_error(study02_fixture_validate(bad), "every planned primary")
  bad <- fixture
  k <- which(bad$failures$attempted)[1]
  bad$failures$success[k] <- !bad$failures$success[k]
  testthat::expect_error(study02_fixture_validate(bad), "do not reconcile")
  bad <- fixture
  k <- which(bad$regions$delivered)[1]
  bad$regions$rejects_zero[k] <- bad$regions$covered[k]
  testthat::expect_error(study02_fixture_validate(bad), "null outcomes")
  bad <- fixture
  bad$estimates$dx[!bad$estimates$observed_success] <- 0
  testthat::expect_error(study02_fixture_validate(bad), "finite displacement")
})

testthat::test_that("coverage, operational yield, and delivery keep separate denominators", {
  fixture <- study02_analysis_fixture()
  result <- do.call(study02_coverage_summary, fixture[1:3])
  one <- result[result$m == 20L & result$anchor == "original" & result$estimator == "refit_plugin" &
    result$entity == "E015" & result$method == "wald", ]
  primary <- one[one$budget == 399L, ]
  prefix <- one[one$budget == 199L, ]
  testthat::expect_equal(nrow(result), 2L * 2L * 3L * 3L * 2L * 3L)
  testthat::expect_equal(primary$n_outer, 4L)
  testthat::expect_equal(primary$n_observed_valid, 3L)
  testthat::expect_equal(primary$n_delivered, 2L)
  testthat::expect_equal(primary$conditional_coverage, .5)
  testthat::expect_equal(primary$conditional_null_rejection, .5)
  testthat::expect_equal(primary$delivery_fraction, .5)
  testthat::expect_equal(primary$operational_coverage_and_delivery, .25)
  testthat::expect_equal(prefix$conditional_coverage, 2 / 3)
  testthat::expect_equal(prefix$delivery_fraction, 3 / 4)
  testthat::expect_equal(prefix$operational_coverage_and_delivery, .5)
  fixture$regions$delivered <- FALSE
  result <- do.call(study02_coverage_summary, fixture[1:3])
  testthat::expect_true(all(is.na(result$conditional_coverage)))
  testthat::expect_true(all(result$delivery_fraction == 0))
  testthat::expect_true(all(result$operational_coverage_and_delivery == 0))
})

testthat::test_that("paired standard errors use differences and preserve discordance", {
  a <- c(1, 1, 0, 0)
  b <- c(1, 0, 1, 1)
  z <- study02_paired_difference(a, b)
  delta <- b - a
  testthat::expect_equal(unname(z["difference"]), .25)
  testthat::expect_equal(unname(z["mcse"]), stats::sd(delta) / sqrt(4))
  testthat::expect_equal(unname(z[c("improved", "worsened")]), c(2, 1))
  testthat::expect_equal(unname(study02_paired_difference(a, a)["mcse"]), 0)
  testthat::expect_true(is.na(study02_paired_difference(logical(), logical())["difference"]))
  testthat::expect_error(study02_paired_difference(a, b[-1]), "equally sized")
  fixture <- study02_analysis_fixture()
  z <- study02_paired_contrasts(fixture$regions)
  one <- z[z$m == 20L & z$anchor == "original" & z$estimator == "refit_plugin" &
    z$entity == "E015" & z$method == "wald" & z$comparison_dimension == "budget", ]
  conditional <- one[one$metric == "conditional_coverage_joint_delivery", ]
  yield <- one[one$metric == "operational_yield", ]
  testthat::expect_equal(conditional$n_pairs, 2)
  testthat::expect_equal(conditional$difference, 0)
  testthat::expect_equal(yield$n_pairs, 4)
  testthat::expect_equal(yield$difference, -.25)
  testthat::expect_equal(yield$mcse, .25)
  # Every unchanged anchor/frame comparison has zero paired variability even
  # though each marginal coverage estimate has nonzero binomial variability.
  testthat::expect_true(all(z$mcse[z$comparison_dimension != "budget"] == 0))
})

testthat::test_that("covariance summaries match direct matrix and jackknife calculations", {
  fixture <- study02_analysis_fixture()
  # Include all four observed estimates for an exact leave-one-out check.
  fixture$estimates$observed_success <- TRUE
  fixture$estimates$dx[fixture$estimates$dataset_id == 1L] <- 0
  fixture$estimates$dy[fixture$estimates$dataset_id == 1L] <- -1
  fixture$regions$var_dx[fixture$regions$dataset_id == 1L] <- .5
  fixture$regions$var_dy[fixture$regions$dataset_id == 1L] <- .3
  fixture$regions$cov_dx_dy[fixture$regions$dataset_id == 1L] <- .05
  fixture$regions$n_valid[fixture$regions$dataset_id == 1L] <- 199L
  z <- study02_covariance_summary(fixture$estimates, fixture$regions)
  one <- z[z$m == 20L & z$anchor == "original" & z$estimator == "refit_plugin" &
    z$entity == "E015" & z$budget == 399L, ]
  d <- rbind(c(0, -1), c(-1, 0), c(1, 0), c(0, 1))
  outer <- stats::cov(d)
  traces <- c(.8, 1, 1.2, 1.4)
  ratio <- mean(traces) / sum(diag(outer))
  jack <- vapply(1:4, function(i) mean(traces[-i]) / sum(diag(stats::cov(d[-i, ]))), numeric(1))
  se <- sqrt(3 / 4 * sum((jack - mean(jack))^2))
  testthat::expect_equal(one$n_covariance_pairs, 4L)
  testthat::expect_equal(one$outer_covariance_trace, sum(diag(outer)))
  testthat::expect_equal(one$mean_bootstrap_covariance_trace, mean(traces))
  testthat::expect_equal(one$covariance_trace_ratio, ratio)
  testthat::expect_equal(one$trace_ratio_jackknife_mcse, se)
  expected_ratios <- eigen(matrix(c(.65, .05, .05, .45), 2) / (2 / 3), symmetric = TRUE)$values
  testthat::expect_equal(one$generalized_ratio_min, min(expected_ratios))
  testthat::expect_equal(one$generalized_ratio_max, max(expected_ratios))
})

testthat::test_that("error summaries use fixed-entity vectors and report gate selection", {
  fixture <- study02_analysis_fixture()
  z <- study02_error_summary(fixture$estimates)
  one <- z[z$m == 20 & z$anchor == "original" & z$estimator == "refit_plugin" & z$entity == "E015", ]
  all <- one[one$cohort == "observed_valid", ]
  gate <- one[one$cohort == "primary_budget_gate", ]
  testthat::expect_equal(all$n_selected, 3L)
  testthat::expect_equal(all$bias_dx, 0)
  testthat::expect_equal(all$bias_dy, 1 / 3)
  testthat::expect_equal(all$vector_rmse, 1)
  testthat::expect_equal(all$normalized_vector_rmse, 1)
  testthat::expect_equal(gate$n_selected, 2L)
  testthat::expect_equal(gate$bias_dx, .5)
  testthat::expect_equal(gate$bias_dy, .5)
})

testthat::test_that("analysis supports a single-budget pilot and writes all summaries", {
  for (budgets in list(c(199L, 399L), 199L)) {
    fixture <- study02_analysis_fixture(budgets)
    testthat::expect_invisible(study02_fixture_validate(fixture, budgets))
    directory <- tempfile("study02-analysis-fixture-")
    dir.create(directory)
    filenames <- c("outer.csv", "estimates.csv", "regions.csv", "failures.csv")
    for (i in seq_along(filenames)) utils::write.csv(fixture[[i]], file.path(directory, filenames[i]), row.names = FALSE, na = "")
    utils::write.csv(study02_tangent_fixture(fixture), file.path(directory, "tangent_covariance.csv"), row.names = FALSE)
    result <- study02_analyze(directory, expected_outer = 4L, expected_m = c(20L, 40L),
      expected_budgets = budgets, figures = FALSE)
    testthat::expect_true(all(file.exists(file.path(directory,
      c("coverage-summary.csv", "covariance-summary.csv", "errors-summary.csv", "contrasts-summary.csv", "attempts-summary.csv", "tangent-summary.csv", "analysis-notes.txt")))))
    testthat::expect_true(all(result$covariance$budget == max(budgets)))
    testthat::expect_equal(nrow(result$errors), 2L * 2L * 3L * 3L * 2L)
    if (length(budgets) == 1L) testthat::expect_false(any(result$contrasts$comparison_dimension == "budget"))
    unlink(directory, recursive = TRUE)
  }
})

testthat::test_that("planned placeholders are distinct from failed fit attempts", {
  fixture <- study02_analysis_fixture()
  z <- study02_attempt_summary(fixture$failures)
  one <- z[z$m == 20 & z$anchor == "original" & z$estimator == "refit_plugin" & z$budget == 399, ]
  testthat::expect_equal(one$n_planned, 4L * 399L)
  testthat::expect_equal(one$n_attempted, 3L * 399L)
  testthat::expect_equal(one$n_unattempted, 399L)
  testthat::expect_equal(one$n_successful, 375L + 2L * 399L)
  testthat::expect_equal(one$n_failed_after_attempt, 24L)
  testthat::expect_equal(one$failure_fraction_of_attempted, 24 / (3 * 399))
  testthat::expect_equal(one$outer_failure_fraction_mcse, stats::sd(c(24 / 399, 0, 0)) / sqrt(3))
  bad <- fixture
  bad$failures$attempted[1] <- !bad$failures$attempted[1]
  testthat::expect_error(study02_fixture_validate(bad), "Attempted states")
  bad <- fixture
  bad$outer$observed_success[1] <- !bad$outer$observed_success[1]
  testthat::expect_error(study02_fixture_validate(bad), "Outer observed-success")
})

testthat::test_that("tangent covariance comparison is paired and retains the cross term", {
  fixture <- study02_analysis_fixture()
  tangent <- study02_tangent_fixture(fixture)
  result <- study02_tangent_summary(tangent, fixture$regions, fixture$outer, 399L)
  one <- result[result$m == 20L & result$anchor == "original" & result$entity == "E015", ]
  testthat::expect_equal(one$n_outer, 4L)
  testthat::expect_equal(one$n_exact_available, 3L)
  testthat::expect_equal(one$n_paired_covariances, 3L)
  testthat::expect_equal(one$mean_empirical_to_exact_trace_ratio, 2)
  testthat::expect_equal(one$empirical_to_exact_ratio_mcse, 0)
  testthat::expect_equal(one$mean_embedding_trace + one$mean_alignment_trace + one$mean_cross_trace, one$mean_total_trace)
  testthat::expect_equal(one$mean_alignment_fraction, .75)
  testthat::expect_equal(one$mean_cross_fraction, -.25)
  testthat::expect_equal(one$multinomial_variance_factor, 19 / 20)
  tangent$cross_trace[1L] <- 0
  testthat::expect_error(study02_tangent_summary(tangent, fixture$regions, fixture$outer, 399L), "do not reconcile")
})
