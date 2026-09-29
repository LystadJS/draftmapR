# Small fabricated ledgers verify analysis denominators; no calibration outcome
# or tuning decision is involved in these fixtures.
if (!exists("calibration_analyze", mode = "function")) {
  candidates <- c("driftmapR/data-raw/calibration-01/analyze.R",
                  "data-raw/calibration-01/analyze.R", "../analyze.R", "analyze.R")
  source(candidates[file.exists(candidates)][1L], local = TRUE)
}

analysis_test_fixture <- function() {
  scenarios <- c("regular_null", "regular_movement", "few_units", "high_noise",
                 "rare_axis", "dependent_units")
  outer <- expand.grid(dataset_id = 1:4, scenario = scenarios,
                       stringsAsFactors = FALSE)
  outer <- outer[c("scenario", "dataset_id")]
  outer$m <- ifelse(outer$scenario %in% c("few_units", "rare_axis"), 12L, 40L)
  outer$rare_count <- ifelse(outer$scenario == "rare_axis", outer$dataset_id - 1L, NA_integer_)
  outer$observed_success <- outer$bootstrap_started <- outer$dataset_id != 1L
  outer$n_attempted <- ifelse(outer$observed_success, 3L, 0L)
  outer$n_valid <- c(0L, 1L, 3L, 3L)[outer$dataset_id]
  outer$n_failed <- outer$n_attempted - outer$n_valid
  outer$passes_gate <- outer$dataset_id >= 3L
  outer$rare_weight_mean_all <- ifelse(outer$scenario == "rare_axis" &
                                        outer$observed_success, outer$dataset_id - 1, NA_real_)
  outer$rare_weight_mean_success <- outer$rare_weight_mean_all
  outer$rare_weight_mean_success[outer$scenario == "rare_axis" & outer$dataset_id == 2L] <- 3
  estimates <- merge(outer[outer$observed_success, ],
                     data.frame(entity = c("E015", "E003", "E006")), by = NULL)
  estimates$target_role <- ifelse(estimates$entity == "E015", "primary", "secondary")
  estimates$normalized_error_dx <- estimates$dataset_id - 1
  estimates$normalized_error_dy <- 0
  estimates$error_dx <- estimates$normalized_error_dx * sqrt(estimates$m)
  estimates$error_dy <- 0
  regions <- merge(outer,
                    expand.grid(entity = c("E015", "E003", "E006"),
                                 method = c("wald", "bootstrap_mahalanobis", "bootstrap_ball"),
                                 policy = c("production", "relaxed"), stringsAsFactors = FALSE), by = NULL)
  regions$target_role <- ifelse(regions$entity == "E015", "primary", "secondary")
  regions$region_computable <- regions$observed_success
  regions$gate_passed <- regions$passes_gate
  regions$delivered <- regions$observed_success &
    (regions$policy == "relaxed" | regions$passes_gate)
  regions$covered <- ifelse(regions$region_computable, regions$dataset_id %in% c(2L, 3L), NA)
  regions$rejects_zero <- ifelse(regions$region_computable, regions$dataset_id %in% c(2L, 4L), NA)
  regions$area <- ifelse(regions$region_computable, 10, NA_real_)
  regions$normalized_area <- regions$area / regions$m
  attempts <- merge(outer[outer$bootstrap_started, ], data.frame(replicate_id = 1:3), by = NULL)
  attempts$success <- attempts$dataset_id != 2L | attempts$replicate_id == 3L
  attempts$rare_weight <- ifelse(attempts$scenario == "rare_axis",
                                  ifelse(attempts$dataset_id == 2L,
                                           ifelse(attempts$replicate_id == 3L, 3, 0),
                                           attempts$dataset_id - 1L), NA_real_)
  list(outer = outer, estimates = estimates, regions = regions, attempts = attempts)
}

testthat::test_that("Wilson intervals use the supplied independent-dataset denominator", {
  answer <- calibration_wilson(1, 2)
  testthat::expect_equal(unname(answer["estimate"]), .5)
  testthat::expect_equal(unname(answer["mcse"]), sqrt(.25 / 2))
  testthat::expect_equal(unname(answer[c("lower", "upper")]),
                        c(.094531205734, .905468794266), tolerance = 1e-10)
  testthat::expect_true(all(is.na(calibration_wilson(0, 0))))
  testthat::expect_equal(unname(calibration_wilson(0, 80)["lower"]), 0)
  testthat::expect_gt(unname(calibration_wilson(0, 80)["upper"]), .04)
  testthat::expect_error(calibration_wilson(3, 2), "valid integer")
})

testthat::test_that("analysis validation detects missing outer records and inconsistent ledgers", {
  fixture <- analysis_test_fixture()
  testthat::expect_invisible(do.call(calibration_validate_analysis,
                                     c(fixture, list(expected_outer = 4L))))
  bad <- fixture
  bad$outer <- bad$outer[-1L, ]
  testthat::expect_error(do.call(calibration_validate_analysis,
                                 c(bad, list(expected_outer = 4L))), "exactly 4")
  bad <- fixture
  bad$regions <- bad$regions[-1L, ]
  testthat::expect_error(do.call(calibration_validate_analysis,
                                 c(bad, list(expected_outer = 4L))), "every dataset")
  bad <- fixture
  bad$attempts <- bad$attempts[-1L, ]
  testthat::expect_error(do.call(calibration_validate_analysis,
                                 c(bad, list(expected_outer = 4L))), "does not reconcile")
  bad <- fixture
  bad$estimates$normalized_error_dx[1L] <- 100
  testthat::expect_error(do.call(calibration_validate_analysis,
                                 c(bad, list(expected_outer = 4L))), "normalization")
})

testthat::test_that("coverage, delivery, and operational yield remain distinct", {
  fixture <- analysis_test_fixture()
  result <- calibration_coverage_summary(fixture$outer, fixture$regions)
  primary <- result[result$scenario == "regular_null" & result$entity == "E015" &
                      result$method == "wald", ]
  production <- primary[primary$policy == "production", ]
  relaxed <- primary[primary$policy == "relaxed", ]
  testthat::expect_equal(nrow(result), 6L * 3L * 3L * 2L)
  testthat::expect_equal(production$n_outer, 4L)
  testthat::expect_equal(production$n_observed_valid, 3L)
  testthat::expect_equal(production$n_delivered, 2L)
  testthat::expect_equal(production$conditional_coverage, .5)
  testthat::expect_equal(production$delivery_fraction, .5)
  testthat::expect_equal(production$operational_coverage_and_delivery, .25)
  testthat::expect_equal(relaxed$conditional_coverage, 2 / 3)
  testthat::expect_equal(relaxed$delivery_fraction, 3 / 4)
  testthat::expect_equal(relaxed$operational_coverage_and_delivery, .5)
  testthat::expect_identical(production$zero_exclusion_interpretation, "null_rejection")
  testthat::expect_true(all(result$zero_exclusion_interpretation[result$scenario != "regular_null"] ==
                             "descriptive_zero_exclusion"))
  fixture$regions$delivered <- FALSE
  empty <- calibration_coverage_summary(fixture$outer, fixture$regions)
  testthat::expect_true(all(is.na(empty$conditional_coverage)))
  testthat::expect_true(all(empty$delivery_fraction == 0))
  testthat::expect_true(all(empty$operational_coverage_and_delivery == 0))
})

testthat::test_that("selection errors and rare multiplicities use outer-dataset means", {
  fixture <- analysis_test_fixture()
  result <- calibration_selection_summary(fixture$outer, fixture$estimates)
  selected <- result[result$scenario == "rare_axis" & result$entity == "E015", ]
  all <- selected[selected$cohort == "all_observed_valid", ]
  gate <- selected[selected$cohort == "production_gate", ]
  testthat::expect_equal(all$n_selected, 3L)
  testthat::expect_equal(all$normalized_bias_dx, 2)
  testthat::expect_equal(all$normalized_vector_rmse, sqrt(14 / 3))
  testthat::expect_equal(gate$n_selected, 2L)
  testthat::expect_equal(gate$normalized_bias_dx, 2.5)
  testthat::expect_equal(gate$normalized_vector_rmse, sqrt(6.5))
  rare <- calibration_rare_summary(fixture$outer, fixture$attempts)
  composition <- rare[rare$type == "K_composition" & rare$cohort == "all_outer" &
                       rare$rare_count == 0L, ]
  testthat::expect_equal(composition$proportion, .25)
  mean_rows <- rare[rare$type == "draw_multiplicity", ]
  testthat::expect_equal(mean_rows$mean[mean_rows$cohort == "all_planned_paired"], 2)
  testthat::expect_equal(mean_rows$mean[mean_rows$cohort == "successful_paired"], 8 / 3)
  testthat::expect_equal(mean_rows$mean[mean_rows$cohort == "success_minus_planned_paired"], 2 / 3)
  failures <- rare[rare$type == "bootstrap_failure_by_K" & rare$rare_count == 1L, ]
  testthat::expect_equal(failures$n_attempted, 3L)
  testthat::expect_equal(failures$zero_rare_attempts, 2L)
  testthat::expect_equal(failures$zero_rare_failed, 2L)
  testthat::expect_equal(failures$positive_rare_failed, 0L)
  testthat::expect_equal(failures$theoretical_zero_rare_probability, (11 / 12)^12)
  testthat::expect_equal(failures$actual_failure_fraction, 2 / 3)
  testthat::expect_equal(failures$n_observed_valid, 1L)
  testthat::expect_equal(failures$n_gate_passed, 0L)
  zero <- rare[rare$type == "bootstrap_failure_by_K" & rare$rare_count == 0L, ]
  testthat::expect_true(is.na(zero$actual_failure_fraction))
  testthat::expect_equal(zero$theoretical_zero_rare_probability, 1)
  testthat::expect_equal(zero$n_attempted, 0L)
})

testthat::test_that("the analysis writer creates all three complete summary files", {
  fixture <- analysis_test_fixture()
  directory <- tempfile("calibration-analysis-fixture-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  filenames <- c("outer-results.csv", "estimates.csv", "regions.csv", "bootstrap-attempts.csv")
  for (i in seq_along(filenames)) {
    utils::write.csv(fixture[[i]], file.path(directory, filenames[i]), row.names = FALSE, na = "")
  }
  result <- calibration_analyze(directory, expected_outer = 4L, figures = FALSE)
  testthat::expect_true(all(file.exists(file.path(directory,
                                                 c("coverage-summary.csv", "selection-summary.csv",
                                                   "rare-selection-summary.csv")))))
  testthat::expect_equal(nrow(result$coverage), 108L)
  testthat::expect_equal(nrow(result$selection), 36L)
})
