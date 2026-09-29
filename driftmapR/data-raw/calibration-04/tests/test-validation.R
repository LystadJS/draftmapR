for (relative in c('../../calibration-01/model.R', '../../calibration-01/regions.R',
                   '../../calibration-02/kernel.R', '../../calibration-03/jackknife.R',
                   '../../calibration-03/regions.R', '../../calibration-03/model.R',
                   '../../calibration-03/run.R', '../../calibration-03/audit.R',
                   '../../calibration-03/validate.R', '../frame.R', '../validate.R',
                   '../audit.R')) source(relative, local = TRUE)

validation04_fixture <- function(B = 4L, sparse_unavailable = FALSE, oracle_register = study02_register) {
  cases <- study03_cases()
  case <- cases[if (sparse_unavailable) nrow(cases) else 4L, , drop = FALSE]
  case$B <- as.integer(B)
  RNGkind("L'Ecuyer-CMRG", 'Inversion', 'Rejection'); set.seed(778L)
  job <- list(case_id = case$case_id, case_index = case$case_index,
    dataset_id = 999L, m = as.integer(case$m), data_stream = .Random.seed,
    bootstrap_seed = 778L, stage = 'reserved_validation_fixture')
  g <- study03_generate(job, case)
  if (sparse_unavailable) {
    g$X <- lapply(1:2, function(t) tcrossprod(g$model$H %*% g$model$layout$latent[[t]][, 1L], seq_len(job$m)))
    for (t in 1:2) g$data[g$data$time == t, g$features] <- g$X[[t]]
    g$rare[] <- FALSE; g$rare_count <- 0L
  }
  list(g = g, result = study04_one(job, case, generated = g,
    keep_inner_values = TRUE, oracle_register = oracle_register))
}

testthat::test_that('mechanical reconstruction validates both frames and expanded occurrence covariances', {
  f <- validation04_fixture(B = 21L)
  verified <- study04_validate_result(f$result)
  testthat::expect_identical(verified$status, 'passed')
  testthat::expect_gt(verified$core_checks, 100L)
  testthat::expect_gt(verified$frame_checks, 100L)
  testthat::expect_equal(verified$checks, verified$core_checks + verified$frame_checks)
  testthat::expect_equal(verified$pivot_rows_checked, 2L * 21L * 3L)
  testthat::expect_equal(verified$retained_jackknives, 2L * 22L)
  testthat::expect_equal(verified$expanded_occurrence_vectors_reconstructed, 2L * 22L * 3L * f$result$job$m)
  counts <- study04_deletion_accounting(f$result)
  testthat::expect_equal(nrow(counts$summary), 4L)
  testthat::expect_setequal(counts$summary$estimator_frame, c('observed_reference', 'population_reference'))
  testthat::expect_equal(sum(counts$summary$failed_unique), 0L)
  testthat::expect_equal(nrow(counts$events), 0L)
})

testthat::test_that('oracle-only observed failure preserves core and all later diagnostic attempts', {
  counter <- 0L
  fail_observed <- function(source, target, anchors) {
    counter <<- counter + 1L
    if (counter == 1L) stop('Injected observed oracle registration failure')
    study02_register(source, target, anchors)
  }
  f <- validation04_fixture(oracle_register = fail_observed)
  testthat::expect_true(f$result$observed_success)
  testthat::expect_false(f$result$frame$observed_success)
  testthat::expect_true(all(f$result$attempts$success))
  testthat::expect_true(all(f$result$frame$attempts$attempted))
  testthat::expect_true(all(f$result$frame$attempts$success))
  testthat::expect_true(all(f$result$frame$observed_jackknife$ledger$attempted))
  testthat::expect_true(all(is.na(f$result$frame$pivots)))
  testthat::expect_false(any(f$result$frame$regions$delivered))
  testthat::expect_identical(study04_validate_result(f$result)$status, 'passed')
})

testthat::test_that('oracle deletion failures are accounted independently without successful-only covariance', {
  counter <- 0L
  fail_deletion <- function(source, target, anchors) {
    counter <<- counter + 1L
    if (counter == 2L) stop('Injected observed oracle deletion failure')
    study02_register(source, target, anchors)
  }
  f <- validation04_fixture(oracle_register = fail_deletion)
  testthat::expect_identical(study04_validate_result(f$result)$status, 'passed')
  counts <- study04_deletion_accounting(f$result)
  testthat::expect_equal(counts$summary$failed_unique,
    c(0L, 0L, 1L, 0L))
  testthat::expect_equal(nrow(counts$events), 1L)
  testthat::expect_identical(counts$events$estimator_frame, 'population_reference')
  testthat::expect_identical(counts$events$phase, 'observed')
  testthat::expect_equal(counts$events$multiplicity, 1L)
})

testthat::test_that('unavailable sparse observed fits preserve every draw and unattempted deletion', {
  f <- validation04_fixture(sparse_unavailable = TRUE)
  testthat::expect_identical(study04_validate_result(f$result)$status, 'passed')
  accounting <- study04_deletion_accounting(f$result)$summary
  testthat::expect_equal(sum(accounting$attempted_unique), 0L)
  testthat::expect_equal(sum(accounting$failed_unique), 0L)
  testthat::expect_equal(sum(accounting$required_unique), sum(accounting$unattempted_required_unique))
  testthat::expect_equal(sum(accounting$required_occurrences), 2L * 5L * f$result$job$m)
  testthat::expect_equal(nrow(f$result$frame$studentization), 12L)
  testthat::expect_false(any(f$result$frame$regions$delivered))
})

testthat::test_that('mechanical oracle checks reject altered rotations, pivots, covariance and attempts', {
  f <- validation04_fixture()
  changed <- f$result; changed$frame$rotations[1L, 1L, 1L] <- 12
  testthat::expect_error(study04_validate_result(changed), 'orthogonal per-fit')
  changed <- f$result; changed$frame$pivots[1L, 1L] <- changed$frame$pivots[1L, 1L] + 1
  testthat::expect_error(study04_validate_result(changed), 'independently reconstructed pivot')
  changed <- f$result; changed$frame$observed_jackknife$covariance[[1L]][1L, 1L] <- 42
  testthat::expect_error(study04_validate_result(changed), 'scatter normalization')
  changed <- f$result; changed$frame$attempts$attempted[1L] <- FALSE
  testthat::expect_error(study04_validate_result(changed), 'oracle attempts depend')
  changed <- f$result; changed$frame$inner[[1L]]$ledger$attempted[1L] <-
    !changed$frame$inner[[1L]]$ledger$attempted[1L]
  testthat::expect_error(study04_validate_result(changed), 'registration attempts require')
  changed <- f$result; changed$frame$inner[[1L]]$values[1L, 1L, 1L] <- 42
  testthat::expect_error(study04_validate_result(changed), 'expanded occurrence mean')
})

testthat::test_that('physical public PCA audits agree in both frames including non-null leaveouts', {
  f <- validation04_fixture()
  audit <- study04_public_audit(f$result, f$g)
  testthat::expect_true(all(audit$passed))
  testthat::expect_equal(nrow(audit), 14L)
  testthat::expect_equal(table(audit$estimator_frame),
    table(c(rep('observed_reference', 6L), rep('population_reference', 8L))))
  testthat::expect_lt(max(audit$max_vector_abs_diff, na.rm = TRUE), 1e-9)
  testthat::expect_lt(max(audit$max_covariance_abs_diff, na.rm = TRUE), 1e-9)
  oracle <- audit[audit$estimator_frame == 'population_reference', ]
  testthat::expect_equal(oracle$replicate_id, rep(0:3, each = 2L))
  testthat::expect_true(all(oracle$failure_ledger_identical))
  testthat::expect_true(all(oracle$covariance_status_identical[seq(2L, 8L, by = 2L)]))
})

testthat::test_that('physical sparse audit includes planned skips and catches altered oracle vectors', {
  f <- validation04_fixture(sparse_unavailable = TRUE)
  audit <- study04_public_audit(f$result, f$g)
  testthat::expect_equal(nrow(audit), 10L)
  testthat::expect_true(all(audit$passed))
  testthat::expect_equal(sum(audit$n_attempted), 2L)
  f <- validation04_fixture()
  f$result$frame$values[2L, 1L, 1L] <- f$result$frame$values[2L, 1L, 1L] + .01
  testthat::expect_error(study04_public_audit(f$result, f$g), 'oracle_expanded_full\\[2\\]')
})

testthat::test_that('directory validation preserves frozen job identities and writes frame-separated counts', {
  f <- validation04_fixture(B = 2L)
  out <- tempfile('study04-validation-fixture-'); dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  dir.create(file.path(out, 'checkpoints')); dir.create(file.path(out, 'core'))
  dir.create(file.path(out, 'frame'))
  frozen <- list(stage = 'reserved_seed_778_dataset_999_fixture')
  f$result$freeze <- frozen
  saveRDS(f$result, file.path(out, 'checkpoints', 'fixture.rds'))
  saveRDS(list(f$result$job), file.path(out, 'seed-plan.rds'))
  saveRDS(frozen, file.path(out, 'frozen-design.rds'))
  testthat::expect_error(study04_validate_directory(out, workers = 1L,
    analysis_schema = FALSE), 'completed study execution marker')
  writeLines('Reserved fixture complete', file.path(out, 'execution.txt'))
  answer <- study04_validate_directory(out, workers = 1L, analysis_schema = FALSE)
  testthat::expect_identical(answer$status, 'passed')
  testthat::expect_true(file.exists(file.path(out, 'mechanical-validation.txt')))
  accounting <- read.csv(file.path(out, 'deletion-accounting.csv'))
  testthat::expect_equal(nrow(accounting), 4L)
  testthat::expect_setequal(accounting$estimator_frame, c('observed_reference', 'population_reference'))
  f$result$job$bootstrap_seed <- 779L
  saveRDS(f$result, file.path(out, 'checkpoints', 'fixture.rds'))
  testthat::expect_error(study04_validate_directory(out, workers = 1L,
    analysis_schema = FALSE), 'job/freeze signature mismatch')
})
