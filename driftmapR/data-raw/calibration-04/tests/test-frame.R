for (relative in c('../../calibration-01/model.R', '../../calibration-01/regions.R',
                   '../../calibration-02/kernel.R', '../../calibration-03/jackknife.R',
                   '../../calibration-03/regions.R', '../../calibration-03/model.R',
                   '../../calibration-03/run.R', '../frame.R')) source(relative, local = TRUE)

frame_fixture <- function(m = 20L, B = 3L, movement = TRUE) {
  case <- study03_cases()[if (movement) 4L else 1L, , drop = FALSE]
  case$m <- as.integer(m); case$B <- as.integer(B)
  case$case_id <- paste0(case$scenario, '_m', m)
  RNGkind("L'Ecuyer-CMRG", 'Inversion', 'Rejection'); set.seed(778L)
  job <- list(case_id = case$case_id, case_index = case$case_index,
    dataset_id = 999L, m = as.integer(m), data_stream = .Random.seed,
    bootstrap_seed = 778L, stage = 'reserved_implementation_fixture')
  list(job = job, case = case, generated = study03_generate(job, case))
}

frame_strip_timing <- function(x) {
  x$outer$elapsed_seconds <- NULL; x$frame <- NULL; x
}

testthat::test_that('oracle augmentation preserves every candidate result and resampling plan', {
  f <- frame_fixture(B = 21L)
  ordinary <- study03_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  augmented <- study04_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  testthat::expect_identical(frame_strip_timing(ordinary), frame_strip_timing(augmented))
  testthat::expect_equal(unname(augmented$frame$estimate), unname(augmented$estimate), tolerance = 1e-11)
  testthat::expect_equal(nrow(augmented$frame$attempts), 21L)
  testthat::expect_equal(nrow(augmented$frame$studentization), 63L)
  testthat::expect_equal(nrow(augmented$frame$regions), 15L)
  testthat::expect_true(all(augmented$frame$attempts$success))
})

testthat::test_that('each oracle bootstrap and deletion equals an independent direct population refit', {
  f <- frame_fixture(B = 3L)
  result <- study04_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  g <- f$generated; m <- f$job$m; A <- g$model$population_points[[1L]]
  anchors <- g$model$anchors; targets <- g$model$target_rows
  for (b in seq_len(result$B)) {
    counts <- as.integer(result$weights[b, ])
    expanded <- rep(seq_len(m), counts)
    grams <- lapply(g$X, function(x) tcrossprod(x[, expanded, drop = FALSE]) / m)
    direct <- study03_fit(grams[[1L]], grams[[2L]], A, anchors)
    testthat::expect_equal(unname(result$frame$values[b, , ]),
      unname(direct$displacement[targets, , drop = FALSE]), tolerance = 1e-10)
    expected <- result$frame$inner[[b]]$values
    positive <- which(counts > 0L)
    for (i in seq_along(positive)) {
      omitted <- counts; omitted[positive[i]] <- omitted[positive[i]] - 1L
      index <- rep(seq_len(m), omitted)
      deleted <- lapply(g$X, function(x) tcrossprod(x[, index, drop = FALSE]) / (m - 1L))
      refit <- study03_fit(deleted[[1L]], deleted[[2L]], A, anchors)
      expected[i, , ] <- refit$displacement[targets, , drop = FALSE]
      testthat::expect_equal(unname(result$frame$inner[[b]]$values[i, , ]),
        unname(expected[i, , ]), tolerance = 1e-10)
    }
    testthat::expect_equal(result$frame$inner[[b]]$covariance,
      study03_jackknife_covariance(expected, counts), tolerance = 1e-10)
  }
  observed_direct <- study03_jackknife(g$X, rep(1L, m), A, anchors, targets)
  testthat::expect_equal(unname(result$frame$observed_jackknife$values),
    unname(observed_direct$values), tolerance = 1e-10)
  testthat::expect_equal(lapply(result$frame$observed_jackknife$covariance, unname),
    lapply(observed_direct$covariance, unname), tolerance = 1e-10)
  testthat::expect_gt(max(abs(result$frame$inner[[1L]]$values - result$inner[[1L]]$values)), 1e-6)
})

testthat::test_that('oracle covariance transforms correctly under rigid changes of population coordinates', {
  f <- frame_fixture(B = 2L)
  original <- study04_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  Q <- matrix(c(0, 1, 1, 0), 2L)
  g <- f$generated
  g$model$population_points <- lapply(g$model$population_points,
    function(x) sweep(x %*% Q, 2L, c(9, -4), '+'))
  g$model$truth <- g$model$truth %*% Q
  dimnames(g$model$truth) <- dimnames(f$generated$model$truth)
  transformed <- study04_one(f$job, f$case, generated = g, keep_inner_values = TRUE)
  testthat::expect_equal(unname(transformed$frame$estimate),
    unname(original$frame$estimate %*% Q), tolerance = 1e-10)
  for (j in seq_len(3L)) {
    testthat::expect_equal(unname(transformed$frame$observed_jackknife$covariance[[j]]),
      unname(t(Q) %*% original$frame$observed_jackknife$covariance[[j]] %*% Q), tolerance = 1e-10)
    testthat::expect_equal(transformed$frame$pivots[, j], original$frame$pivots[, j], tolerance = 1e-9)
  }
})

testthat::test_that('oracle failures never alter the core estimator or suppress later required deletions', {
  f <- frame_fixture(B = 2L)
  reference <- study03_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  counter <- 0L
  fail_second <- function(source, target, anchors) {
    counter <<- counter + 1L
    if (counter == 2L) stop('Injected oracle deletion failure')
    if (counter == 3L) warning('Retained oracle registration warning')
    study02_register(source, target, anchors)
  }
  result <- study04_one(f$job, f$case, generated = f$generated,
    keep_inner_values = TRUE, oracle_register = fail_second)
  testthat::expect_identical(frame_strip_timing(result), frame_strip_timing(reference))
  testthat::expect_true(result$frame$observed_success)
  testthat::expect_equal(result$frame$observed_jackknife$n_attempted_unique, f$job$m)
  testthat::expect_equal(result$frame$observed_jackknife$n_successful_unique, f$job$m - 1L)
  testthat::expect_false(any(result$frame$observed_jackknife$covariance_ok))
  testthat::expect_true(all(vapply(result$frame$observed_jackknife$covariance, function(x) all(is.na(x)), logical(1L))))
  testthat::expect_identical(result$frame$observed_jackknife$ledger$stage[1L], 'oracle_registration')
  testthat::expect_identical(result$frame$observed_jackknife$ledger$warnings[2L], 'Retained oracle registration warning')
  testthat::expect_true(all(result$frame$attempts$success))
  testthat::expect_false(any(result$frame$regions$delivered[result$frame$regions$method == 'jackknife_studentized']))
})

testthat::test_that('unavailable observed oracle still retains subsequent covariance attempts', {
  f <- frame_fixture(B = 2L); counter <- 0L
  fail_first <- function(source, target, anchors) {
    counter <<- counter + 1L
    if (counter == 1L) stop('Injected observed oracle failure')
    study02_register(source, target, anchors)
  }
  result <- study04_one(f$job, f$case, generated = f$generated, oracle_register = fail_first)
  testthat::expect_true(result$observed_success)
  testthat::expect_false(result$frame$observed_success)
  testthat::expect_true(all(result$frame$attempts$success))
  testthat::expect_true(all(result$frame$studentization$covariance_ok))
  testthat::expect_false(any(result$frame$studentization$pivot_ok))
  testthat::expect_true(all(result$frame$studentization$stage == 'observed_oracle_unavailable'))
  testthat::expect_false(any(result$frame$regions$delivered))
})

testthat::test_that('core observed failure retains all planned frame rows without false attempts', {
  f <- frame_fixture(B = 3L); g <- f$generated
  g$X[[1L]][, ] <- 0
  result <- study04_one(f$job, f$case, generated = g)
  testthat::expect_false(result$observed_success)
  testthat::expect_false(result$frame$observed_success)
  testthat::expect_equal(nrow(result$frame$attempts), 3L)
  testthat::expect_equal(nrow(result$frame$studentization), 9L)
  testthat::expect_false(any(result$frame$attempts$attempted))
  testthat::expect_false(any(result$frame$studentization$attempted))
  testthat::expect_equal(result$frame$observed_jackknife$n_attempted_unique, 0L)
  testthat::expect_true(all(vapply(result$frame$inner, function(x) x$n_attempted_unique == 0L, logical(1L))))
  testthat::expect_equal(vapply(result$frame$inner, function(x) nrow(x$ledger), integer(1L)), rep(f$job$m, 3L))
})

testthat::test_that('failed core deletion is explicitly unavailable to the oracle without skipping later deletions', {
  f <- frame_fixture(B = 1L); count <- 0L
  fail_core <- function(C1, C2, reference_points, anchors) {
    count <<- count + 1L
    if (count == 2L) stop('Injected core deletion failure')
    study03_fit(C1, C2, reference_points, anchors)
  }
  result <- study04_one(f$job, f$case, generated = f$generated, fit_fun = fail_core)
  jk <- result$frame$observed_jackknife
  testthat::expect_equal(jk$n_attempted_unique, f$job$m - 1L)
  testthat::expect_false(jk$all_required_success)
  testthat::expect_identical(jk$ledger$stage[1L], 'core_leaveout_unavailable')
  testthat::expect_false(jk$ledger$attempted[1L])
  testthat::expect_true(tail(jk$ledger$success, 1L))
  testthat::expect_true(all(result$frame$attempts$success))
})

testthat::test_that('oracle covariance retains occurrence multiplicity when a repeated-unit deletion fails', {
  f <- frame_fixture(B = 1L)
  reference <- study04_one(f$job, f$case, generated = f$generated)
  counts <- as.integer(reference$weights[1L, ]); positive <- which(counts > 0L)
  repeated_index <- which(counts[positive] > 1L)[1L]
  unit <- positive[repeated_index]
  fail_at <- 1L + f$job$m + 1L + repeated_index; counter <- 0L
  fail_repeated <- function(source, target, anchors) {
    counter <<- counter + 1L
    if (counter == fail_at) stop('Injected repeated-unit oracle deletion failure')
    study02_register(source, target, anchors)
  }
  result <- study04_one(f$job, f$case, generated = f$generated, oracle_register = fail_repeated)
  jk <- result$frame$inner[[1L]]
  testthat::expect_identical(frame_strip_timing(result), frame_strip_timing(reference))
  testthat::expect_equal(jk$n_required_occurrences, f$job$m)
  testthat::expect_equal(jk$n_attempted_unique, length(positive))
  testthat::expect_equal(jk$n_successful_occurrences, f$job$m - counts[unit])
  testthat::expect_equal(jk$n_successful_unique, length(positive) - 1L)
  testthat::expect_false(any(jk$covariance_ok))
  testthat::expect_true(all(result$frame$studentization$stage == 'inner_oracle_leaveout_fit'))
})

testthat::test_that('oracle leaveouts agree with physical column PCA using the public adapter', {
  f <- frame_fixture(B = 1L)
  result <- study04_one(f$job, f$case, generated = f$generated, keep_inner_values = TRUE)
  g <- f$generated; counts <- as.integer(result$weights[1L, ])
  positive <- which(counts > 0L); A <- g$model$population_points[[1L]]
  for (i in seq_len(min(3L, length(positive)))) {
    deleted <- counts; deleted[positive[i]] <- deleted[positive[i]] - 1L
    indices <- rep(seq_along(counts), deleted)
    features <- sprintf('column%03d', seq_along(indices))
    panel <- do.call(rbind, lapply(1:2, function(t) {
      x <- g$X[[t]][, indices, drop = FALSE]; colnames(x) <- features
      data.frame(entity = g$model$ids, time = t, x, check.names = FALSE)
    }))
    public <- driftmapR::embed_snapshots(panel, features) |>
      driftmapR::align_snapshots(anchors = g$model$ids[g$model$anchors])
    baseline <- as.matrix(public$aligned[public$aligned$period_index == 1L, c('x', 'y')]) / sqrt(f$job$m - 1L)
    Q <- study02_register(baseline, A, g$model$anchors)$rotation
    movement <- as.matrix(driftmapR::measure_drift(public)[c('dx', 'dy')]) / sqrt(f$job$m - 1L)
    expected <- (movement %*% Q)[g$model$target_rows, , drop = FALSE]
    testthat::expect_equal(unname(result$frame$inner[[1L]]$values[i, , ]), unname(expected), tolerance = 1e-10)
  }
})

testthat::test_that('core evaluation failure is distinct from a successful oracle registration', {
  f <- frame_fixture(B = 2L)
  stage_environment <- environment(study03_one)
  original_stage <- get('study03_stage', envir = stage_environment)
  withr::defer(assign('study03_stage', original_stage, envir = stage_environment))
  assign('study03_stage', function(expression, stage) {
    if (stage == 'evaluation_registration') stop(structure(
      list(message = 'Injected core evaluation failure', call = NULL, stage = stage),
      class = c('simpleError', 'error', 'condition')))
    original_stage(expression, stage)
  }, envir = stage_environment)
  result <- study04_one(f$job, f$case, generated = f$generated)
  testthat::expect_true(result$full_observed_success)
  testthat::expect_false(result$evaluation_success)
  testthat::expect_false(result$frame$observed_success)
  testthat::expect_true(result$frame$observed_diagnostic$attempted)
  testthat::expect_true(result$frame$observed_diagnostic$registration_success)
  testthat::expect_identical(result$frame$observed_diagnostic$stage, 'core_evaluation_unavailable')
  testthat::expect_identical(result$frame$observed_diagnostic$message, 'Injected core evaluation failure')
  testthat::expect_false(any(result$frame$attempts$attempted))
  testthat::expect_equal(result$frame$observed_jackknife$n_attempted_unique, 0L)
})

testthat::test_that('first wrapped core-fit failure does not shift planned oracle records', {
  f <- frame_fixture(B = 3L); calls <- 0L
  fail_first_fit <- function(C1, C2, reference_points, anchors) {
    calls <<- calls + 1L
    stop('Injected initial wrapped core failure')
  }
  result <- study04_one(f$job, f$case, generated = f$generated, fit_fun = fail_first_fit)
  testthat::expect_equal(calls, 1L)
  testthat::expect_false(result$frame$observed_diagnostic$attempted)
  testthat::expect_false(result$frame$observed_diagnostic$registration_success)
  testthat::expect_identical(result$frame$observed_diagnostic$stage, 'core_observed_unavailable')
  testthat::expect_equal(nrow(result$frame$attempts), 3L)
  testthat::expect_identical(result$frame$attempts$replicate_id, 1:3)
  testthat::expect_false(any(result$frame$attempts$attempted))
  testthat::expect_false(any(result$frame$studentization$attempted))
})
