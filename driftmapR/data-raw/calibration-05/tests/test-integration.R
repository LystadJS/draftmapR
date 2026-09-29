testthat::test_that('a weak-gap anchor-change engineering panel integrates with the frozen candidate', {
  f <- study05_fixture(17L, B = 21L)
  testthat::expect_identical(f$job$dataset_id, 999L)
  testthat::expect_identical(f$case$contract, 'iid_units_nominal_contract')
  result <- study04_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  testthat::expect_identical(dim(result$weights), c(21L, 40L))
  testthat::expect_true(all(rowSums(result$weights) == 40L))
  testthat::expect_equal(nrow(result$attempts), 21L)
  testthat::expect_equal(nrow(result$studentization), 63L)
  testthat::expect_equal(nrow(result$regions), 15L)
  testthat::expect_identical(result$weights, result$frame$weights)
  # These assertions check numerical agreement, never coverage or delivery rate.
  if (result$observed_success) {
    testthat::expect_equal(result$estimate, result$frame$estimate, tolerance = 1e-9)
    physical <- study03_expanded_leaveouts(f$generated, rep(1L, 40L), result$observed$reference)
    testthat::expect_identical(physical$ledger$success, result$observed_jackknife$ledger$success)
    if (physical$all_required_success) for (j in 1:3)
      testthat::expect_equal(physical$covariance[[j]], result$observed_jackknife$covariance[[j]],
                            tolerance = 1e-9, ignore_attr = TRUE)
  }
  for (frame in list(result, result$frame)) {
    ledger <- study05_validate_ledger(frame$observed_jackknife$ledger)
    testthat::expect_equal(ledger$required_occurrences, 40L)
    for (b in 1:21) {
      ledger <- study05_validate_ledger(frame$inner[[b]]$ledger)
      testthat::expect_equal(ledger$required_occurrences, 40L)
      testthat::expect_equal(ledger$required_unique, sum(result$weights[b, ] > 0))
    }
  }
})

testthat::test_that('analytic plan export is complete and cannot overwrite existing output', {
  source(file.path(source_dir, 'plan.R'))
  d <- tempfile('study05-plan-'); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  bounds <- study05_write_plan(d, source_dir)
  testthat::expect_equal(bounds$planned_panels, 1640L)
  testthat::expect_equal(bounds$planned_bootstrap_draws, 326360L)
  testthat::expect_equal(bounds$required_observed_occurrences, 156960L)
  testthat::expect_equal(bounds$required_inner_occurrences_upper_bound, 31235040L)
  testthat::expect_equal(bounds$reserved_measurement_panels_generated, 0L)
  testthat::expect_false(bounds$runner_implemented)
  testthat::expect_equal(length(readRDS(file.path(d, 'seed-plan.rds'))), 1640L)
  testthat::expect_equal(nrow(read.csv(file.path(d, 'population-targets.csv'))), 93L)
  testthat::expect_error(study05_write_plan(d, source_dir), 'never overwrite')
})
