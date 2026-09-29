# Independent corruption tests: the fixture estimator is run once, and changes
# affect copied engineering records only. Acceptance never depends on coverage.
study05_review_fixture_cache <- new.env(parent = emptyenv())
study05_review_fixture <- function() {
  if (is.null(study05_review_fixture_cache$result)) {
    fixture <- study05_fixture(1L, B = 1L)
    study05_review_fixture_cache$result <- study05_one(fixture$job, fixture$case,
      generated = fixture$generated, keep_inner_values = TRUE)
  }
  study05_review_fixture_cache$result
}

testthat::test_that('independent review fixture passes full mechanical reconstruction', {
  result <- study05_review_fixture()
  validation <- study05_validate_result(result)
  testthat::expect_identical(validation$status, 'passed')
  testthat::expect_gt(validation$checks, 0L)
  testthat::expect_equal(nrow(result$attempts), 1L)
  testthat::expect_equal(nrow(result$studentization), 3L)
  testthat::expect_equal(nrow(result$regions), 15L)
})

testthat::test_that('mechanical validation rejects lost or duplicated geometry', {
  original <- study05_review_fixture()
  for (kind in c('embedding', 'registration')) {
    changed <- original
    changed$geometry[[kind]] <- changed$geometry[[kind]][-1L, , drop = FALSE]
    testthat::expect_error(study05_validate_result(changed))
    changed <- original
    changed$geometry[[kind]] <- rbind(changed$geometry[[kind]], changed$geometry[[kind]][1L, ])
    testthat::expect_error(study05_validate_result(changed))
    changed <- original
    field <- if (kind == 'embedding') 'projector_distance' else 'source_s2'
    changed$geometry[[kind]][[field]] <- NULL
    testthat::expect_error(study05_validate_result(changed))
  }
})

testthat::test_that('mechanical validation rejects changed spectral and full-matrix evidence', {
  original <- study05_review_fixture()
  changed <- original
  i <- which(changed$geometry$embedding$success)[1L]
  changed$geometry$embedding$lambda2[i] <- changed$geometry$embedding$lambda2[i] + 1
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$geometry$matrices$embedding <- list()
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$geometry$matrices$registration <- list()
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  i <- which(changed$geometry$registration$success)[1L]
  changed$geometry$registration$attempted[i] <- FALSE
  testthat::expect_error(study05_validate_result(changed))
})

testthat::test_that('mechanical validation rejects missing targets and changed numerical evidence', {
  original <- study05_review_fixture()
  changed <- original
  changed$studentization <- changed$studentization[-1L, , drop = FALSE]
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$frame$studentization <- rbind(changed$frame$studentization,
    changed$frame$studentization[1L, , drop = FALSE])
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$observed_jackknife$covariance[[1L]][1L, 1L] <-
    changed$observed_jackknife$covariance[[1L]][1L, 1L] + 1
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$regions$delivered[1L] <- !changed$regions$delivered[1L]
  testthat::expect_error(study05_validate_result(changed))
  changed <- original
  changed$attempts$max_multiplicity <- NULL
  testthat::expect_error(study05_validate_result(changed))
})

testthat::test_that('candidate delivery cannot become spuriously unknown', {
  changed <- study05_review_fixture()
  testthat::expect_false(changed$evaluation_only_block)
  changed$regions$candidate_region_delivered[1L] <- NA
  testthat::expect_error(study05_validate_result(changed))
})
