source(file.path("..", "..", "calibration-02", "kernel.R"), local = TRUE)
source(file.path("..", "..", "calibration-01", "model.R"), local = TRUE)
source(file.path("..", "jackknife.R"), local = TRUE)

jackknife_fixture <- function(m = 20L, motion = TRUE) {
  scenario <- calibration_scenarios()[if (motion) 2L else 1L, , drop = FALSE]
  scenario$m <- as.integer(m)
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(777L) # Reserved implementation fixture, never a holdout panel.
  generated <- calibration_generate(scenario, .Random.seed)
  X <- lapply(1:2, function(t) {
    x <- as.matrix(generated$data[generated$data$time == t, generated$features])
    sweep(x, 2L, colMeans(x), "-")
  })
  grams <- lapply(X, function(x) tcrossprod(x) / m)
  reference <- study02_points(grams[[1L]])
  anchors <- match(generated$layout$anchors, generated$layout$entitygroups$entity)
  list(generated = generated, X = X, grams = grams, reference = reference,
       anchors = anchors, targets = c(15L, 3L, 6L), m = m)
}

testthat::test_that("occurrence jackknife equals sample-mean covariance with and without duplicates", {
  unit <- cbind(c(-2, 0, 1, 3, 4, 2), c(3, -1, 2, 4, -3, 1))
  for (counts in list(rep(1L, 6L), c(0L, 3L, 1L, 0L, 2L, 0L))) {
    m <- sum(counts)
    positive <- which(counts > 0L)
    center <- colSums(unit * counts) / m
    leaveout <- (matrix(m * center, length(positive), 2L, byrow = TRUE) -
      unit[positive, , drop = FALSE]) / (m - 1)
    values <- array(leaveout, c(length(positive), 1L, 2L))
    answer <- study03_jackknife_covariance(values, counts)[[1L]]
    expanded <- unit[rep(seq_len(nrow(unit)), counts), , drop = FALSE]
    testthat::expect_equal(unname(answer), unname(stats::cov(expanded) / m), tolerance = 1e-14)
    expanded_leaveout <- leaveout[rep(seq_along(positive), counts[positive]), , drop = FALSE]
    expanded_cov <- (m - 1) * stats::cov(expanded_leaveout) * (m - 1) / m
    testthat::expect_equal(unname(answer), unname(expanded_cov), tolerance = 1e-14)
  }
})

testthat::test_that("full non-null compressed deletions equal explicitly expanded column PCA refits", {
  testthat::skip_if_not_installed("driftmapR")
  f <- jackknife_fixture(20L)
  counts <- rep(c(0L, 1L, 2L, 1L), 5L)
  result <- study03_jackknife(f$X, counts, f$reference, f$anchors, f$targets)
  testthat::expect_true(result$all_required_success)
  testthat::expect_true(all(result$covariance_ok))
  testthat::expect_equal(result$n_required_occurrences, 20L)
  testthat::expect_equal(result$n_attempted_unique, 15L)
  expected <- result$values
  for (k in seq_along(result$positive_units)) {
    unit <- result$positive_units[k]
    deleted_counts <- counts; deleted_counts[unit] <- deleted_counts[unit] - 1L
    indices <- rep(seq_len(f$m), deleted_counts)
    features <- sprintf("replicated%03d", seq_along(indices))
    panel <- do.call(rbind, lapply(1:2, function(t) {
      x <- f$X[[t]][, indices, drop = FALSE]
      colnames(x) <- features
      data.frame(entity = f$generated$layout$entitygroups$entity, time = t, x,
                 check.names = FALSE)
    }))
    public <- driftmapR::embed_snapshots(panel, features) |>
      driftmapR::align_snapshots(anchors = f$generated$layout$anchors)
    public_base <- as.matrix(public$aligned[public$aligned$period_index == 1L, c("x", "y")]) /
      sqrt(f$m - 1)
    registration <- study02_register(public_base, f$reference, f$anchors)
    public_displacement <- (as.matrix(driftmapR::measure_drift(public)[c("dx", "dy")]) /
      sqrt(f$m - 1)) %*% registration$rotation
    expected[k, , ] <- public_displacement[f$targets, , drop = FALSE]
    testthat::expect_equal(unname(result$values[k, , ]),
                           unname(expected[k, , ]), tolerance = 1e-10)
  }
  testthat::expect_equal(result$covariance,
    study03_jackknife_covariance(expected, counts), tolerance = 1e-10)
})

testthat::test_that("Gram deletion uses m minus one and the fixed reference at nonzero motion", {
  f <- jackknife_fixture()
  result <- study03_jackknife(f$X, rep(1L, f$m), f$reference, f$anchors, f$targets,
                              grams = f$grams)
  calculated <- study03_fit(tcrossprod(f$X[[1L]][, -1L]) / (f$m - 1),
    tcrossprod(f$X[[2L]][, -1L]) / (f$m - 1), f$reference, f$anchors)
  testthat::expect_equal(unname(result$values[1L, , ]),
    unname(calculated$displacement[f$targets, ]), tolerance = 1e-12)
  wrong <- study03_fit(tcrossprod(f$X[[1L]][, -1L]) / f$m,
    tcrossprod(f$X[[2L]][, -1L]) / f$m, f$reference, f$anchors)
  testthat::expect_gt(max(abs(wrong$displacement[f$targets, ] - result$values[1L, , ])), 0.001)
  testthat::expect_equal(result, study03_jackknife(f$X, rep(1L, f$m), f$reference,
    f$anchors, f$targets), tolerance = 1e-12)
  for (k in seq_along(f$targets)) {
    testthat::expect_equal(unname(result$weighted_mean[k, ]),
      unname(colMeans(result$values[, k, ])), tolerance = 1e-14)
    testthat::expect_equal(result$weighted_scatter[[k]] * (f$m - 1) / f$m,
      result$covariance[[k]], tolerance = 1e-14)
  }
})

testthat::test_that("full covariance and every deletion are rotation and reflection equivariant", {
  f <- jackknife_fixture()
  original <- study03_jackknife(f$X, rep(1L, f$m), f$reference, f$anchors, f$targets)
  for (Q in list(matrix(c(cos(.4), sin(.4), -sin(.4), cos(.4)), 2L),
                 matrix(c(0, 1, 1, 0), 2L))) {
    transformed <- study03_jackknife(f$X, rep(1L, f$m),
      sweep(f$reference %*% Q, 2L, c(9, -2), "+"), f$anchors, f$targets)
    for (k in seq_along(f$targets)) {
      testthat::expect_equal(unname(transformed$values[, k, ]),
        unname(original$values[, k, ] %*% Q), tolerance = 1e-10)
      testthat::expect_equal(unname(transformed$covariance[[k]]),
        unname(t(Q) %*% original$covariance[[k]] %*% Q), tolerance = 1e-10)
    }
    testthat::expect_identical(transformed$covariance_ok, original$covariance_ok)
  }
})

testthat::test_that("direct fixed chart is different from composition through a deformed parent", {
  f <- jackknife_fixture()
  counts <- rep(c(0L, 1L, 2L, 1L), 5L)
  grams <- lapply(f$X, function(x) tcrossprod(sweep(x, 2L, sqrt(counts), "*")) / f$m)
  parent <- study03_fit(grams[[1L]], grams[[2L]], f$reference, f$anchors)
  j <- which(counts > 0L)[1L]
  deleted <- lapply(1:2, function(t)
    (f$m * grams[[t]] - tcrossprod(f$X[[t]][, j])) / (f$m - 1))
  direct <- study03_fit(deleted[[1L]], deleted[[2L]], f$reference, f$anchors)
  nested <- study03_fit(deleted[[1L]], deleted[[2L]], parent$aligned1, f$anchors)
  testthat::expect_gt(max(abs(direct$displacement - nested$displacement)), 1e-8)
  computed <- study03_jackknife(f$X, counts, f$reference, f$anchors, f$targets)
  testthat::expect_equal(unname(computed$values[1L, , ]),
    unname(direct$displacement[f$targets, ]), tolerance = 1e-12)
})

testthat::test_that("a failed repeated-unit deletion invalidates covariance without stopping later attempts", {
  f <- jackknife_fixture()
  counts <- rep(c(0L, 1L, 2L, 1L), 5L)
  counter <- 0L
  injected <- function(C1, C2, reference_points, anchors) {
    counter <<- counter + 1L
    if (counter == 2L) stop(structure(list(message = "forced repeated-unit failure", call = NULL,
      stage = "embedding_period2"), class = c("simpleError", "error", "condition")))
    if (counter == 3L) warning("retained numerical warning")
    study03_fit(C1, C2, reference_points, anchors)
  }
  result <- study03_jackknife(f$X, counts, f$reference, f$anchors, f$targets, fit_fun = injected)
  testthat::expect_equal(nrow(result$ledger), f$m)
  testthat::expect_equal(counter, sum(counts > 0L))
  testthat::expect_equal(result$n_successful_unique, 14L)
  testthat::expect_equal(result$n_successful_occurrences, 18L)
  testthat::expect_false(result$all_required_success)
  testthat::expect_false(any(result$covariance_ok))
  testthat::expect_true(all(vapply(result$covariance, function(s) all(is.na(s)), logical(1))))
  testthat::expect_true(all(result$reason == "required_leaveout_failed"))
  testthat::expect_identical(result$ledger$stage[3L], "embedding_period2")
  testthat::expect_identical(result$ledger$message[3L], "forced repeated-unit failure")
  testthat::expect_identical(result$ledger$warnings[4L], "retained numerical warning")
  testthat::expect_true(all(result$ledger$stage[counts == 0L] == "not_selected"))
  testthat::expect_false(any(result$ledger$attempted[counts == 0L]))
  testthat::expect_true(tail(result$ledger$success, 1L))
  counter <- 0L
  observed <- study03_jackknife(f$X, rep(1L, f$m), f$reference, f$anchors,
                                 f$targets, fit_fun = injected)
  testthat::expect_equal(observed$n_attempted_unique, f$m)
  testthat::expect_equal(observed$n_successful_occurrences, f$m - 1L)
  testthat::expect_false(any(observed$covariance_ok))
  testthat::expect_true(all(observed$reason == "required_leaveout_failed"))
})

testthat::test_that("singular covariance and malformed returned displacements remain explicit failures", {
  f <- jackknife_fixture()
  zero <- function(C1, C2, reference_points, anchors)
    list(displacement = matrix(0, nrow(C1), 2L))
  result <- study03_jackknife(f$X, rep(1L, f$m), f$reference, f$anchors,
                              f$targets, fit_fun = zero)
  testthat::expect_true(result$all_required_success)
  testthat::expect_false(any(result$covariance_ok))
  testthat::expect_true(all(result$reason == "singular_covariance"))
  malformed <- function(C1, C2, reference_points, anchors) list(displacement = c(1, 2))
  failed <- study03_jackknife(f$X, rep(1L, f$m), f$reference, f$anchors,
                              f$targets, fit_fun = malformed)
  testthat::expect_equal(failed$n_attempted_unique, f$m)
  testthat::expect_equal(failed$n_successful_unique, 0L)
  testthat::expect_true(all(failed$ledger$stage == "leaveout_displacement"))
  testthat::expect_false(study03_covariance_geometry(diag(c(1, 1e-9)))$ok)
  testthat::expect_true(study03_covariance_geometry(diag(c(1, 1e-7)))$ok)
})

testthat::test_that("invalid counts, centering, dimensions, and targets are rejected", {
  f <- jackknife_fixture()
  call <- function(counts, X = f$X, targets = f$targets)
    study03_jackknife(X, counts, f$reference, f$anchors, targets)
  for (bad in list(rep(1, f$m - 1L), c(-1, rep(1, f$m - 1L)),
                   c(NA_real_, rep(1, f$m - 1L)), rep(1.5, f$m))) {
    testthat::expect_error(call(bad), "Counts")
  }
  testthat::expect_error(call(rep(2L, f$m)), "sum")
  testthat::expect_error(call(rep(1L, f$m), lapply(f$X, function(x) x + 1)), "centered")
  testthat::expect_error(call(rep(1L, f$m), targets = c(1L, 1L)), "Target rows")
  testthat::expect_error(study03_jackknife_covariance(array(0, c(3L, 1L, 2L)), rep(1L, 4L)), "matching")
})

testthat::test_that("fit failure stages and fixed-reference inverse rotations are recoverable", {
  f <- jackknife_fixture()
  e <- tryCatch(study03_fit(matrix(0, 18L, 18L), f$grams[[2L]], f$reference,
                            f$anchors), error = identity)
  testthat::expect_identical(e$stage, "embedding_period1")
  points <- study02_points(f$grams[[2L]])
  forward <- study02_register(points, f$reference, f$anchors)
  backward <- study02_register(f$reference, points, f$anchors)
  testthat::expect_equal(forward$rotation %*% backward$rotation, diag(2L), tolerance = 1e-12)
})
