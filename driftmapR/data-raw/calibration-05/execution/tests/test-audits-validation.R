# All panels in this file use only the frozen engineering seed 779/dataset999.
validation05_fixture <- local({
  cache <- new.env(parent = emptyenv())
  function(case_index = 1L, B = 3L) {
    key <- paste(case_index, B, sep = '|')
    if (!exists(key, envir = cache, inherits = FALSE)) {
      f <- study05_fixture(case_index, B)
      f$result <- study05_one(f$job, f$case, f$generated, keep_inner_values = TRUE)
      assign(key, f, envir = cache)
    }
    get(key, envir = cache, inherits = FALSE)
  }
})

testthat::test_that('mechanical validation reconstructs both full estimators and all diagnostic stages', {
  f <- validation05_fixture()
  check <- study05_validate_result(f$result)
  testthat::expect_identical(check$status, 'passed')
  testthat::expect_gt(check$study05_checks, 500L)
  testthat::expect_equal(check$pivot_rows_checked, 2L * 3L * 3L)
  testthat::expect_equal(check$retained_jackknives, 2L * 4L)
  counts <- study05_deletion_accounting(f$result)$summary
  testthat::expect_equal(counts$required_unique, counts$attempted_unique + counts$unattempted_required_unique)
  testthat::expect_equal(counts$attempted_occurrences, counts$successful_occurrences + counts$failed_occurrences)
})

testthat::test_that('all public draw vectors and first two physical parent jackknives agree', {
  f <- validation05_fixture()
  audit <- study05_public_audit(f$result, f$generated)
  testthat::expect_true(all(audit$passed))
  testthat::expect_equal(sum(audit$audit_type == 'full_bootstrap'), 3L)
  testthat::expect_equal(sum(audit$audit_type == 'full_bootstrap_direct_A'), 3L)
  parent <- audit[audit$audit_type == 'expanded_jackknife_covariance', ]
  testthat::expect_equal(nrow(parent), 6L)
  testthat::expect_setequal(parent$replicate_id, 0:2)
  testthat::expect_false(any(audit$replicate_id == 3L & grepl('expanded_jackknife', audit$audit_type), na.rm = TRUE))
  testthat::expect_true(all(c('observed_pca','observed_classical_mds','clean_observed_point_only') %in% audit$audit_type))
  testthat::expect_lt(max(audit$max_vector_abs_diff, na.rm = TRUE), 1e-9)
  testthat::expect_lt(max(audit$max_covariance_abs_diff, na.rm = TRUE), 1e-9)
  retained <- attr(audit, 'public_records')
  testthat::expect_equal(unname(retained$weights), unname(f$result$weights))
  testthat::expect_identical(unname(retained$streams), unname(f$result$streams))
  testthat::expect_length(retained$physical_jackknives, 6L)
})

testthat::test_that('dependent audit and checkpoint assumptions explicitly preserve intentional misspecification', {
  f <- validation05_fixture(case_index = 27L, B = 1L)
  testthat::expect_identical(study05_validate_result(f$result)$status, 'passed')
  audit <- study05_public_audit(f$result, f$generated)
  testthat::expect_true(all(audit$passed))
  testthat::expect_match(attr(audit, 'public_records')$design$assumptions, 'intentionally misspecified')
  testthat::expect_false(grepl('simulation generates iid', attr(audit, 'public_records')$design$assumptions))
})

testthat::test_that('mechanical validator rejects corrupted counts pivots matrices and missing diagnostic stages', {
  f <- validation05_fixture()
  r <- f$result; r$weights[1L, 1L] <- r$weights[1L, 1L]+1L
  testthat::expect_error(study05_validate_result(r), 'multiplicity totals')
  r <- f$result; r$pivots[1L, 1L] <- r$pivots[1L, 1L]+1
  testthat::expect_error(study05_validate_result(r), 'independent pivot')
  r <- f$result; r$geometry$embedding <- r$geometry$embedding[FALSE, ]
  testthat::expect_error(study05_validate_result(r), 'observed reference embedding')
  r <- f$result; r$geometry$embedding$gap_absolute[1L] <- 123
  testthat::expect_error(study05_validate_result(r), 'spectral gaps')
  r <- f$result; r$geometry$matrices$embedding[['1']] <- NULL
  testthat::expect_error(study05_validate_result(r), 'full matrix')
  r <- f$result; r$attempts$max_multiplicity <- NULL
  testthat::expect_error(study05_validate_result(r), 'multiplicity schema')
  r <- f$result; at <- which(r$geometry$embedding$stage == 'embedding_period2')[1L]
  r$geometry$embedding$attempted[at] <- FALSE
  testthat::expect_error(study05_validate_result(r), 'success requires attempt|depends on')
})

testthat::test_that('public audit catches altered stream identities and physical deletion vectors', {
  f <- validation05_fixture(B = 1L)
  r <- f$result; r$streams[1L, 2L] <- r$streams[1L, 2L]+1L
  testthat::expect_error(study05_public_audit(r, f$generated), 'engineering audit mismatch')
  r <- f$result; r$inner[[1L]]$values[1L, 1L, 1L] <- r$inner[[1L]]$values[1L, 1L, 1L]+.01
  error <- tryCatch(study05_public_audit(r, f$generated), error = identity)
  testthat::expect_s3_class(error, 'study05_audit_error')
  testthat::expect_match(conditionMessage(error), 'expanded_jackknife_deletion')
  testthat::expect_true(is.data.frame(error$audit))
})

testthat::test_that('observed rank failure preserves all public slots and unavailable physical parents', {
  f <- study05_fixture(31L, B = 2L)
  f$generated$X <- lapply(f$generated$X, function(X) tcrossprod(X[, 1L], seq_len(f$job$m)))
  for (t in 1:2) f$generated$data[f$generated$data$time == t, f$generated$features] <- f$generated$X[[t]]
  r <- study05_one(f$job, f$case, f$generated, keep_inner_values = TRUE)
  testthat::expect_false(r$observed_success)
  testthat::expect_identical(study05_validate_result(r)$status, 'passed')
  a <- study05_public_audit(r, f$generated)
  testthat::expect_true(all(a$passed))
  testthat::expect_equal(sum(a$audit_type == 'expanded_jackknife_parent_unavailable'), 6L)
  testthat::expect_equal(sum(a$audit_type == 'full_bootstrap'), 2L)
  testthat::expect_false(any(a$n_attempted[a$audit_type == 'full_bootstrap'] > 0L))
  testthat::expect_true(all(is.na(a$max_vector_abs_diff)))
})

testthat::test_that('evaluation-only blocks retain unknown computational region availability', {
  f <- study05_fixture(B = 2L)
  r <- study05_one(f$job, f$case, f$generated, keep_inner_values = TRUE,
    evaluation_register = function(...) stop('Injected evaluation registration failure'))
  testthat::expect_true(r$full_observed_success)
  testthat::expect_true(r$evaluation_only_block)
  testthat::expect_true(all(is.na(r$regions$candidate_region_delivered)))
  testthat::expect_true(r$clean$attempted)
  testthat::expect_identical(study05_validate_result(r)$status, 'passed')
  r$regions$candidate_region_delivered[] <- FALSE
  testthat::expect_error(study05_validate_result(r), 'candidate delivery is unknown')
})

testthat::test_that('exact sample boundary difference is classified without pretending numerical equivalence', {
  f <- study05_fixture(B = 2L)
  U <- eigen(f$generated$model$population_grams[[1L]], symmetric = TRUE)$vectors[, 1:3]
  W <- matrix(0, 3L, f$job$m); W[, 1:3] <- diag(sqrt(f$job$m*c(20,5,5)))
  X <- U %*% W
  f$generated$X <- list(X, X)
  for (t in 1:2) f$generated$data[f$generated$data$time == t, f$generated$features] <- X
  r <- study05_one(f$job, f$case, f$generated, keep_inner_values = TRUE)
  testthat::expect_false(r$observed_success)
  testthat::expect_true(study05_audit_boundary(f$generated, rep(1L, f$job$m)))
  a <- study05_public_audit(r, f$generated)
  testthat::expect_true(all(a$passed))
  testthat::expect_true(any(a$classification == 'expected_boundary_rule_difference'))
  testthat::expect_identical(study05_validate_result(r)$status, 'passed')
})

testthat::test_that('checkpoint set rejects duplicate missing and seed-altered jobs', {
  f <- validation05_fixture(B = 1L)
  testthat::expect_true(study05_validate_checkpoint_set(list(f$result), list(f$job)))
  testthat::expect_error(study05_validate_checkpoint_set(list(), list(f$job)), 'every planned job')
  testthat::expect_error(study05_validate_checkpoint_set(rep(list(f$result), 2L),
    rep(list(f$job), 2L)), 'duplicate')
  r <- f$result; r$job$bootstrap_seed <- r$job$bootstrap_seed+1L
  testthat::expect_error(study05_validate_checkpoint_set(list(r), list(f$job)), 'seed identity')
})
