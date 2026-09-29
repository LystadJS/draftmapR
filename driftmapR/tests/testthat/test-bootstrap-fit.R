bootstrap_fit_fixture <- function(method = "pca", reference = "previous",
                                  scale = FALSE, standardize = "none", churn = FALSE) {
  a <- c(-2, 0, 3, -1, 2, 1, -3, 0.5)
  b <- c(-1, 2, 0, 3, -2, 2, 1, -0.5)
  rows <- lapply(1:3, function(i) {
    aa <- a
    bb <- b
    aa[7:8] <- aa[7:8] + (i - 1) * 0.4
    bb[7:8] <- bb[7:8] - (i - 1) * 0.3
    data.frame(entity = letters[1:8], time = i,
               a = aa, b = bb, c = aa + bb, d = 2 * aa - bb,
               cluster = rep(c("left", "right"), each = 4))
  })
  if (churn) {
    rows[[2]] <- rows[[2]][rows[[2]]$entity != "h", ]
    rows[[3]]$entity[rows[[3]]$entity == "g"] <- "new"
  }
  embed_snapshots(do.call(rbind, rows), c("a", "b", "c", "d"),
                  method = method, standardize = standardize) |>
    align_snapshots(reference = reference, scale = scale, anchors = letters[1:6])
}

test_that("unit-weight refits reproduce observed coordinates and movement", {
  for (method in c("pca", "cmds")) for (reference in c("previous", "first")) {
    object <- bootstrap_fit_fixture(method, reference, churn = TRUE)
    fit <- fit_bootstrap_replicate(object, c(a = 1, b = 1, c = 1, d = 1))
    expect_true(fit$success)
    expect_null(fit$failure)
    expect_equal(fit$coordinates, object$aligned, tolerance = 1e-9)
    expect_equal(fit$movement, measure_drift(object), tolerance = 1e-9)
    expect_identical(fit$coordinates[c("entity", "time", "period_index")],
                     object$coordinates[c("entity", "time", "period_index")])
    expect_false(any(fit$movement$entity == "h"))
    expect_false(any(fit$movement$entity == "new"))
    expect_equal(length(fit$diagnostics$embedding), 3L)
    expect_true(all(vapply(fit$diagnostics$embedding,
                           function(x) length(x$eigenvalues) >= 3L, logical(1))))
    expect_equal(fit$diagnostics$baseline$n_matched, 6L)
    expect_equal(nrow(fit$warnings), 0L)
  }
})

test_that("baseline gauge orientation propagates to vectors in the observed frame", {
  object <- bootstrap_fit_fixture()
  angle <- 0.73
  reflection <- matrix(c(cos(angle), sin(angle), sin(angle), -cos(angle)), 2L)
  object$aligned[c("x", "y")] <- sweep(
    as.matrix(object$aligned[c("x", "y")]) %*% reflection, 2L, c(9, -4), "+")
  fit <- fit_bootstrap_replicate(object, rep(1, 4))
  expect_true(fit$success)
  expect_equal(fit$coordinates, object$aligned, tolerance = 1e-9)
  expect_equal(fit$movement, measure_drift(object), tolerance = 1e-9)
  expect_equal(fit$diagnostics$baseline$determinant, -1, tolerance = 1e-10)
})

test_that("baseline gauge never rescales even when temporal fitting allows scaling", {
  for (reference in c("previous", "first")) {
    object <- bootstrap_fit_fixture(reference = reference, scale = TRUE)
    fit <- fit_bootstrap_replicate(object, rep(4, 4))
    expect_true(fit$success)
    expect_identical(fit$diagnostics$baseline$scale, 1)
    baseline <- fit$coordinates[fit$coordinates$period_index == 1, c("x", "y")]
    observed <- object$aligned[object$aligned$period_index == 1, c("x", "y")]
    expect_equal(as.numeric(stats::dist(baseline)),
                 2 * as.numeric(stats::dist(observed)), tolerance = 1e-9)
    expect_equal(fit$movement$distance, 2 * measure_drift(object)$distance,
                 tolerance = 1e-9)
    expect_equal(vapply(fit$diagnostics$alignment[-1L], function(x) x$scale,
                        numeric(1)), object$transformations$scale[-1L], tolerance = 1e-9)
    expected_ref <- if (reference == "first") c(1, 1, 1) else c(1, 1, 2)
    expect_equal(vapply(fit$diagnostics$alignment,
                        function(x) x$reference_time, numeric(1)), expected_ref)
  }
})

test_that("fixed scales are applied and coincide with refits for fixed raw measurements", {
  weights <- c(a = 2, b = 0, c = 1, d = 1)
  for (method in c("pca", "cmds")) {
    for (policy in c("none", "first", "pooled", "period")) {
      object <- bootstrap_fit_fixture(method = method, standardize = policy)
      refit <- fit_bootstrap_replicate(object, weights, "refit")
      fixed <- fit_bootstrap_replicate(object, weights, "fixed")
      expect_true(refit$success)
      expect_true(fixed$success)
      expect_equal(fixed$coordinates, refit$coordinates, tolerance = 1e-9)
      expect_equal(fixed$movement, refit$movement, tolerance = 1e-9)
    }
  }
  object <- bootstrap_fit_fixture(standardize = "first")
  ordinary <- fit_bootstrap_replicate(object, rep(1, 4), "fixed")
  object$embedding_metadata$preprocessing$scales <-
    lapply(object$embedding_metadata$preprocessing$scales, function(x) 2 * x)
  modified <- fit_bootstrap_replicate(object, rep(1, 4), "fixed")
  expect_true(modified$success)
  expect_equal(as.numeric(stats::dist(modified$coordinates[1:8, c("x", "y")])),
               as.numeric(stats::dist(ordinary$coordinates[1:8, c("x", "y")])) / 2,
               tolerance = 1e-9)
})

test_that("rank failures invalidate the entire draw and retain prior period diagnostics", {
  data <- bootstrap_fit_fixture()$original_data
  data$b[data$time == 2] <- data$a[data$time == 2]
  for (method in c("pca", "cmds")) {
    object <- embed_snapshots(data, c("a", "b", "c", "d"), method = method) |>
      align_snapshots()
    fit <- fit_bootstrap_replicate(object, c(a = 2, b = 2, c = 0, d = 0))
    expect_false(fit$success)
    expect_null(fit$coordinates)
    expect_null(fit$movement)
    expect_identical(fit$failure$stage, "embedding")
    expect_identical(fit$failure$period_index, 2L)
    expect_match(fit$failure$message, "rank-deficient")
    expect_true(length(fit$diagnostics$embedding[[1]]$eigenvalues) >= 3L)
    expect_null(fit$diagnostics$embedding[[2]])
    expect_null(fit$diagnostics$baseline)
  }
})

test_that("a boundary tie is captured as a failed replicate without emitted warnings", {
  vertices <- rbind(diag(3), -diag(3))
  data <- data.frame(entity = rep(letters[1:6], 2), time = rep(1:2, each = 6),
                     a = rep(3 * vertices[, 1], 2),
                     b = rep(sqrt(2) * vertices[, 2], 2),
                     c = rep(vertices[, 3], 2))
  for (method in c("pca", "cmds")) {
    object <- embed_snapshots(data, c("a", "b", "c"), method = method) |>
      align_snapshots()
    fit <- NULL
    expect_no_warning(fit <- fit_bootstrap_replicate(object, c(a = 1, b = 1, c = 2)))
    expect_false(fit$success)
    expect_identical(fit$failure$stage, "embedding")
    expect_identical(fit$failure$period_index, 1L)
    expect_match(fit$failure$message, "boundary tie")
    expect_equal(nrow(fit$warnings), 1L)
    expect_match(fit$warnings$message, "second and third")
    expect_identical(fit$warnings$period_index, 1L)
    expect_true(fit$diagnostics$embedding[[1]]$diagnostics$boundary_tie)
    expect_equal(fit$diagnostics$embedding[[1]]$eigenvalues[2:3], c(4, 4),
                 tolerance = 1e-9)
  }
})

test_that("preprocessing errors identify the affected period and expose no partial output", {
  object <- bootstrap_fit_fixture()
  object$embedding_metadata$preprocessing$scales[[2]][1] <- 0
  fit <- fit_bootstrap_replicate(object, rep(1, 4), "fixed")
  expect_false(fit$success)
  expect_identical(fit$failure$stage, "preprocessing")
  expect_identical(fit$failure$period_index, 2L)
  expect_null(fit$coordinates)
  expect_null(fit$movement)
  expect_match(fit$failure$message, "scales must be positive")
})

test_that("baseline and temporal geometry failures record shared and fitting counts", {
  data <- bootstrap_fit_fixture()$original_data
  anchors <- letters[1:3]
  # The third/fourth features retain the observed plane, while a bootstrap that
  # omits them makes the fitting anchors collinear in a selected period.
  for (bad_period in 1:2) {
    altered <- data
    altered$b[altered$entity %in% anchors & altered$time == bad_period] <- 0
    object <- embed_snapshots(altered, c("a", "b", "c", "d")) |>
      align_snapshots(anchors = anchors)
    fit <- fit_bootstrap_replicate(object, c(a = 2, b = 2, c = 0, d = 0))
    expect_false(fit$success)
    expect_identical(fit$failure$stage,
                     if (bad_period == 1) "baseline_alignment" else "temporal_alignment")
    expect_identical(fit$failure$period_index, as.integer(bad_period))
    expect_identical(fit$failure$n_shared, 8L)
    expect_identical(fit$failure$n_matched, 3L)
    expect_match(fit$failure$message, "collinear")
    expect_true(all(vapply(fit$diagnostics$embedding, Negate(is.null), logical(1))))
    expect_null(fit$coordinates)
    expect_null(fit$movement)
    if (bad_period == 2) expect_equal(fit$diagnostics$baseline$scale, 1)
  }
})
