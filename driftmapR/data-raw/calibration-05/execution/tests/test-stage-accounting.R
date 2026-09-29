testthat::test_that('stage accounting separates fits, target views and occurrences', {
  f <- study05_fixture(1L, B = 3L)
  r <- study05_one(f$job, f$case, generated = f$generated)
  a <- study05_stage_accounting(r)
  testthat::expect_true(all(a$required == a$attempted + a$unattempted_required))
  testthat::expect_true(all(a$attempted == a$successful + a$failed_after_attempt))
  testthat::expect_true(all(a$planned == a$required + a$not_required))
  keys <- paste(a$frame, a$stage, a$entity, a$method)
  testthat::expect_false(anyDuplicated(keys) > 0L)
  for (frame in c('core', 'population_frame_oracle')) {
    observed <- a[a$frame == frame & a$stage == 'observed_deletion', ]
    inner <- a[a$frame == frame & a$stage == 'inner_deletion', ]
    testthat::expect_equal(observed$required_occurrences, 40L)
    testthat::expect_equal(inner$required_occurrences, 3L * 40L)
    testthat::expect_equal(inner$required, sum(r$weights > 0L))
    testthat::expect_equal(inner$attempted_occurrences,
      inner$successful_occurrences + inner$failed_occurrences)
    testthat::expect_equal(sum(a$planned[a$frame == frame & a$stage == 'pivot']), 9L)
    testthat::expect_equal(sum(a$planned[a$frame == frame & a$stage == 'study_evaluable_delivery']), 15L)
  }
  testthat::expect_equal(a$planned[a$frame == 'core' & a$stage == 'bootstrap_full'], 3L)
  testthat::expect_equal(a$attempted[a$frame == 'clean_observed_point'], 1L)
})

testthat::test_that('evaluation-only blocks preserve unknown candidate delivery accounting', {
  f <- study05_fixture(1L, B = 2L)
  r <- study05_one(f$job, f$case, generated = f$generated,
    evaluation_register = function(...) stop('engineering evaluation registration failure'))
  a <- study05_stage_accounting(r)
  testthat::expect_true(r$full_observed_success)
  testthat::expect_true(r$evaluation_only_block)
  testthat::expect_equal(a$failed_after_attempt[a$frame == 'core' & a$stage == 'evaluation_registration'], 1L)
  unknown <- a[a$stage == 'candidate_delivery_known', ]
  testthat::expect_equal(sum(unknown$planned), 30L)
  testthat::expect_equal(sum(unknown$unattempted_required), 30L)
  testthat::expect_equal(sum(unknown$failed_after_attempt), 0L)
  testthat::expect_equal(sum(a$attempted[a$stage == 'bootstrap_full']), 0L)
  testthat::expect_equal(sum(a$unattempted_required_occurrences[a$stage == 'inner_deletion']), 160L)
  testthat::expect_equal(a$attempted[a$frame == 'clean_observed_point'], 1L)
})

testthat::test_that('failed required deletions block covariance without early stopping later work', {
  f <- study05_fixture(1L, B = 2L)
  fail <- function(context) {
    if (context$role == 'core' && context$parent_id == 0L && context$unit_index == 1L)
      stop('engineering required deletion failure')
  }
  r <- study05_one(f$job, f$case, generated = f$generated, hooks = list(fit = fail))
  a <- study05_stage_accounting(r)
  core <- a[a$frame == 'core' & a$stage == 'observed_deletion', ]
  direct <- a[a$frame == 'population_frame_oracle' & a$stage == 'observed_deletion', ]
  testthat::expect_equal(core$attempted, 40L)
  testthat::expect_equal(core$failed_after_attempt, 1L)
  testthat::expect_equal(core$successful, 39L)
  testthat::expect_equal(direct$attempted, 39L)
  testthat::expect_equal(direct$unattempted_required_occurrences, 1L)
  testthat::expect_equal(sum(a$attempted[a$stage == 'observed_covariance']), 0L)
  testthat::expect_equal(sum(a$unattempted_required[a$stage == 'observed_covariance']), 6L)
  testthat::expect_equal(a$attempted[a$frame == 'core' & a$stage == 'bootstrap_full'], 2L)
  testthat::expect_equal(sum(a$required[a$stage == 'pivot']), 12L)
})
