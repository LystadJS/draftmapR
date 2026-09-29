# Research-only, full-refit occurrence jackknife for study 03.
# Source calibration-02/kernel.R first. Every baseline is registered DIRECTLY
# to reference_points, which stays fixed for the entire observed dataset.

study03_stage <- function(expression, stage) {
  tryCatch(expression, error = function(e) {
    if (is.null(e$stage)) e$stage <- stage
    stop(e)
  })
}

study03_fit <- function(C1, C2, reference_points, anchors) {
  points1 <- study03_stage(study02_points(C1), "embedding_period1")
  points2 <- study03_stage(study02_points(C2), "embedding_period2")
  baseline <- study03_stage(study02_register(points1, reference_points, anchors),
                             "registration_baseline")
  temporal <- study03_stage(study02_register(points2, baseline$points, anchors),
                             "alignment_temporal")
  list(raw = list(points1, points2), aligned1 = baseline$points,
       aligned2 = temporal$points,
       displacement = temporal$points - baseline$points,
       baseline = baseline, temporal = temporal)
}

study03_counts <- function(counts, length_required = NULL) {
  if (!is.numeric(counts) || !length(counts) || any(!is.finite(counts)) ||
      any(counts < 0 | counts != floor(counts)) ||
      sum(counts) < 2 || sum(counts) > .Machine$integer.max ||
      (!is.null(length_required) && length(counts) != length_required)) {
    stop("Counts must be finite nonnegative integers with total at least two and the required length.",
         call. = FALSE)
  }
  as.integer(counts)
}

study03_jackknife_covariance <- function(values, counts) {
  counts <- study03_counts(counts)
  counts <- counts[counts > 0L]
  dims <- dim(values)
  if (!is.numeric(values) || length(dims) != 3L || dims[1L] != length(counts) ||
      dims[2L] < 1L || dims[3L] != 2L || any(!is.finite(values))) {
    stop("Values must be a finite positive-unit by target by 2 array matching positive counts.",
         call. = FALSE)
  }
  m <- sum(counts)
  covariance <- lapply(seq_len(dims[2L]), function(k) {
    v <- matrix(values[, k, ], ncol = 2L)
    center <- colSums(v * counts) / m
    residual <- sweep(v, 2L, center, "-")
    answer <- (m - 1) / m * crossprod(residual, residual * counts)
    dimnames(answer) <- list(c("dx", "dy"), c("dx", "dy"))
    answer
  })
  names(covariance) <- dimnames(values)[[2L]]
  covariance
}

study03_covariance_geometry <- function(S, tolerance = 1e-8) {
  if (!is.matrix(S) || !identical(dim(S), c(2L, 2L)) || any(!is.finite(S))) {
    return(list(ok = FALSE, reason = "nonfinite_covariance", eigenvalues = c(NA_real_, NA_real_),
                eigen_ratio = NA_real_))
  }
  eigenvalues <- eigen((S + t(S)) / 2, symmetric = TRUE, only.values = TRUE)$values
  ratio <- if (eigenvalues[1L] > 0) eigenvalues[2L] / eigenvalues[1L] else NA_real_
  ok <- is.finite(ratio) && eigenvalues[2L] > 0 && ratio > tolerance
  list(ok = ok, reason = if (ok) "" else "singular_covariance",
       eigenvalues = eigenvalues, eigen_ratio = ratio)
}

study03_jackknife <- function(X, counts, reference_points, anchors, target_rows,
                              grams = NULL, fit_fun = study03_fit) {
  if (!is.list(X) || length(X) != 2L) {
    stop("X must contain two centered entity by unit matrices.", call. = FALSE)
  }
  for (t in 1:2) study02_matrix(X[[t]], label = paste("Period", t, "features"))
  if (!identical(dim(X[[1L]]), dim(X[[2L]])) || ncol(X[[1L]]) < 2L) {
    stop("Both period matrices must have identical dimensions and at least two units.", call. = FALSE)
  }
  n <- nrow(X[[1L]]); m <- ncol(X[[1L]])
  counts <- study03_counts(counts, m)
  if (sum(counts) != m) stop("Counts must sum to the original number of units m.", call. = FALSE)
  for (t in 1:2) {
    magnitude <- max(abs(X[[t]]))
    if (max(abs(colSums(X[[t]]))) > 1e-9 * n * max(magnitude, .Machine$double.eps)) {
      stop("X must be centered across entities within each period.", call. = FALSE)
    }
  }
  study02_matrix(reference_points, 2L, "Fixed reference coordinates")
  if (nrow(reference_points) != n) stop("Reference and features must have the same entity order and count.", call. = FALSE)
  anchors <- study02_anchors(anchors, n)
  if (!is.numeric(target_rows) || !length(target_rows) || any(!is.finite(target_rows)) ||
      any(target_rows != floor(target_rows)) || any(target_rows < 1L | target_rows > n) ||
      anyDuplicated(target_rows)) {
    stop("Target rows must be unique valid entity row indices.", call. = FALSE)
  }
  target_rows <- as.integer(target_rows)
  if (!is.function(fit_fun)) stop("fit_fun must be a function.", call. = FALSE)
  if (is.null(grams)) {
    grams <- lapply(X, function(x) tcrossprod(sweep(x, 2L, sqrt(counts), "*")) / m)
  } else {
    if (!is.list(grams) || length(grams) != 2L) stop("grams must contain two parent normalized Gram matrices.", call. = FALSE)
    for (t in 1:2) {
      study02_matrix(grams[[t]], label = "Parent normalized Gram matrix")
      if (!identical(dim(grams[[t]]), c(n, n))) stop("Parent Gram dimensions must agree with X.", call. = FALSE)
    }
  }
  positive <- which(counts > 0L)
  target_names <- rownames(reference_points)[target_rows]
  if (is.null(target_names)) target_names <- as.character(target_rows)
  values <- array(NA_real_, c(length(positive), length(target_rows), 2L),
                  dimnames = list(as.character(positive), target_names, c("dx", "dy")))
  ledger <- data.frame(unit_index = seq_len(m), multiplicity = counts,
    attempted = counts > 0L, success = FALSE,
    stage = ifelse(counts > 0L, "not_attempted", "not_selected"),
    message = ifelse(counts > 0L, "", "Unit has zero multiplicity; deletion is not required."),
    warnings = rep("", m), stringsAsFactors = FALSE)
  for (k in seq_along(positive)) {
    j <- positive[k]
    deleted <- lapply(1:2, function(t)
      (m * grams[[t]] - tcrossprod(X[[t]][, j])) / (m - 1))
    captured_warnings <- character()
    fit <- tryCatch(withCallingHandlers(
      fit_fun(deleted[[1L]], deleted[[2L]], reference_points, anchors),
      warning = function(w) {
        captured_warnings <<- c(captured_warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }), error = function(e) e)
    ledger$warnings[j] <- paste(unique(captured_warnings), collapse = " | ")
    if (inherits(fit, "error")) {
      ledger$stage[j] <- if (is.null(fit$stage)) "leaveout_fit" else as.character(fit$stage)[1L]
      ledger$message[j] <- conditionMessage(fit)
      next
    }
    if (!is.list(fit) || !is.matrix(fit$displacement) ||
        !identical(dim(fit$displacement), c(n, 2L)) ||
        any(!is.finite(fit$displacement))) {
      ledger$stage[j] <- "leaveout_displacement"
      ledger$message[j] <- "Leaveout fit did not return a finite entity by 2 displacement matrix."
      next
    }
    values[k, , ] <- fit$displacement[target_rows, , drop = FALSE]
    ledger$success[j] <- TRUE
    ledger$stage[j] <- "complete"
  }
  all_required <- all(ledger$success[positive])
  covariance <- if (all_required) study03_jackknife_covariance(values, counts) else
    stats::setNames(lapply(target_rows, function(k)
      matrix(NA_real_, 2L, 2L, dimnames = list(c("dx", "dy"), c("dx", "dy")))), target_names)
  weighted_mean <- matrix(NA_real_, length(target_rows), 2L,
                          dimnames = list(target_names, c("dx", "dy")))
  if (all_required) for (k in seq_along(target_rows)) {
    weighted_mean[k, ] <- colSums(matrix(values[, k, ], ncol = 2L) * counts[positive]) / m
  }
  weighted_scatter <- lapply(covariance, function(S) S * m / (m - 1))
  geometry <- lapply(covariance, study03_covariance_geometry)
  covariance_ok <- vapply(geometry, `[[`, logical(1L), "ok")
  reason <- if (all_required) vapply(geometry, `[[`, character(1L), "reason") else
    stats::setNames(rep("required_leaveout_failed", length(target_rows)), target_names)
  list(covariance = covariance, covariance_ok = covariance_ok, reason = reason,
       covariance_reason = reason, geometry = geometry, values = values,
       weighted_mean = weighted_mean, weighted_scatter = weighted_scatter,
       ledger = ledger, counts = counts, positive_units = positive,
       n_planned_unique = length(positive), n_attempted_unique = sum(ledger$attempted),
       n_successful_unique = sum(ledger$success), n_required_occurrences = m,
       n_successful_occurrences = sum(counts[ledger$success]), all_required_success = all_required,
       target_rows = target_rows)
}
