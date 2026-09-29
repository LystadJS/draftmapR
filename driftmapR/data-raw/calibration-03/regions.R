# Research-only joint regions for the full-estimator studentization study.
# Covariances are exact paired-unit delete-one jackknife covariances supplied
# by the study runner. This file neither refits frames nor deletes failures.
# All vectors and covariance matrices must already use one common frame.

study03_covariance_status <- function(S, tol = 1e-8) {
  if (!is.numeric(tol) || length(tol) != 1L || !is.finite(tol) ||
      tol <= 0 || tol >= 1) {
    stop("tol must be a finite number strictly between zero and one.",
         call. = FALSE)
  }
  if (!is.matrix(S) || !is.numeric(S) || !identical(dim(S), c(2L, 2L))) {
    stop("S must be a numeric 2 by 2 covariance matrix.", call. = FALSE)
  }
  result <- list(valid = FALSE, reason = "nonfinite_covariance",
                 covariance = S, eigenvalues = rep(NA_real_, 2L),
                 eigenvectors = matrix(NA_real_, 2L, 2L),
                 eigen_ratio = NA_real_, determinant_root = NA_real_)
  if (any(!is.finite(S))) return(result)
  magnitude <- max(abs(S))
  if (magnitude == 0) {
    result$reason <- "nonpositive_covariance"
    return(result)
  }
  # Permit only floating-point asymmetry, measured relative to matrix scale.
  if (max(abs(S / magnitude - t(S / magnitude))) > 1e-12) {
    result$reason <- "asymmetric_covariance"
    return(result)
  }
  symmetric <- S / 2 + t(S) / 2
  spectrum <- eigen(symmetric / magnitude, symmetric = TRUE)
  result$covariance <- symmetric
  result$eigenvalues <- spectrum$values * magnitude
  result$eigenvectors <- spectrum$vectors
  if (spectrum$values[1L] <= 0 || spectrum$values[2L] <= 0) {
    result$reason <- "nonpositive_covariance"
    return(result)
  }
  result$eigen_ratio <- spectrum$values[2L] / spectrum$values[1L]
  if (result$eigen_ratio <= tol) {
    result$reason <- "singular_covariance"
    return(result)
  }
  if (any(!is.finite(result$eigenvalues)) || any(result$eigenvalues <= 0)) {
    result$reason <- "nonfinite_covariance_spectrum"
    return(result)
  }
  result$determinant_root <- sqrt(result$eigenvalues[1L]) *
    sqrt(result$eigenvalues[2L])
  if (!is.finite(result$determinant_root) || result$determinant_root <= 0) {
    result$reason <- "nonfinite_covariance_determinant"
    return(result)
  }
  result$valid <- TRUE
  result$reason <- "ok"
  result
}

study03_check_vector <- function(x, label) {
  if (!is.numeric(x) || !is.null(dim(x)) || length(x) != 2L ||
      any(!is.finite(x))) {
    stop(label, " must be a finite numeric displacement vector of length 2.",
         call. = FALSE)
  }
  invisible(TRUE)
}

# Whitening avoids forming an inverse. The initial scaling avoids overflow
# during an otherwise harmless rotation of a very large finite error vector.
study03_quadratic_spectrum <- function(error, status) {
  magnitude <- max(abs(error))
  if (magnitude == 0) return(0)
  projected <- drop((error / magnitude) %*% status$eigenvectors)
  whitened <- projected * (magnitude / sqrt(status$eigenvalues))
  sum(whitened^2)
}

study03_quadratic <- function(error, S, tol = 1e-8) {
  study03_check_vector(error, "error")
  status <- study03_covariance_status(S, tol)
  if (!status$valid) {
    stop("Cannot form a quadratic: ", status$reason, ".", call. = FALSE)
  }
  study03_quadratic_spectrum(error, status)
}

study03_studentized_region <- function(observed, observed_cov, pivots, truth,
                                      B, min_valid = 20L, min_success = 0.95,
                                      level = 0.95, cov_tol = 1e-8) {
  study03_check_vector(observed, "observed")
  study03_check_vector(truth, "truth")
  integer_scalar <- function(x, label, lower) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) ||
        x < lower || x != floor(x) || x > .Machine$integer.max) {
      stop(label, " must be an integer of at least ", lower, ".", call. = FALSE)
    }
  }
  integer_scalar(B, "B", 1L)
  integer_scalar(min_valid, "min_valid", 3L)
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
      level <= 0 || level >= 1) {
    stop("level must be a finite number strictly between zero and one.",
         call. = FALSE)
  }
  if (!is.numeric(min_success) || length(min_success) != 1L ||
      !is.finite(min_success) || min_success <= 0 || min_success > 1) {
    stop("min_success must be a finite number in (0, 1].", call. = FALSE)
  }
  if (!is.numeric(pivots) || !is.null(dim(pivots)) ||
      any(!is.finite(pivots)) || any(pivots < 0) || length(pivots) > B) {
    stop("pivots must contain only finite nonnegative successful pivots, with length no greater than planned B; failures must be accounted for by the caller.",
         call. = FALSE)
  }
  status <- study03_covariance_status(observed_cov, cov_tol)
  n <- length(pivots)
  out <- data.frame(
    method = c("jackknife_wald", "jackknife_studentized"),
    available = FALSE, reason = "insufficient_valid", covered = NA,
    rejects_zero = NA, relaxed_covered = NA, relaxed_rejects_zero = NA,
    radius = NA_real_, area = NA_real_,
    center_dx = observed[1L], center_dy = observed[2L],
    truth_statistic = NA_real_, null_statistic = NA_real_,
    n_valid = c(NA_integer_, n), var_dx = observed_cov[1L, 1L],
    var_dy = observed_cov[2L, 2L], cov_dx_dy = observed_cov[1L, 2L],
    B = as.integer(B), cutoff = NA_real_, pivot_n = n,
    gate = c(TRUE, n >= min_valid && n / B >= min_success),
    delivered = FALSE, level = level, stringsAsFactors = FALSE,
    row.names = NULL)
  if (!status$valid) {
    out$reason <- status$reason
    return(out)
  }
  out$cov_dx_dy <- status$covariance[1L, 2L]
  truth_error <- truth - observed
  if (any(!is.finite(truth_error))) {
    out$reason <- "nonfinite_error"
    return(out)
  }
  truth_statistic <- study03_quadratic_spectrum(truth_error, status)
  null_statistic <- study03_quadratic_spectrum(-observed, status)
  if (!is.finite(truth_statistic) || !is.finite(null_statistic)) {
    out$reason <- "nonfinite_statistic"
    return(out)
  }
  cutoffs <- c(stats::qchisq(level, df = 2L),
               if (n >= min_valid) as.numeric(stats::quantile(
                 pivots, level, type = 7L, names = FALSE)) else NA_real_)
  for (i in seq_len(2L)) {
    if (i == 2L && n < min_valid) next
    if (!is.finite(cutoffs[i]) || cutoffs[i] <= 0) {
      out$reason[i] <- "nonfinite_or_zero_cutoff"
      next
    }
    area <- pi * cutoffs[i] * status$determinant_root
    if (!is.finite(area) || area <= 0) {
      out$reason[i] <- "nonfinite_or_zero_area"
      next
    }
    out$available[i] <- TRUE
    out$reason[i] <- if (out$gate[i]) "ok" else "below_success_fraction"
    out$cutoff[i] <- cutoffs[i]
    out$radius[i] <- sqrt(cutoffs[i])
    out$area[i] <- area
    out$truth_statistic[i] <- truth_statistic
    out$null_statistic[i] <- null_statistic
    # The tolerance only addresses floating-point roundoff at the boundary.
    out$relaxed_covered[i] <- truth_statistic <= cutoffs[i] * (1 + 1e-12)
    out$relaxed_rejects_zero[i] <- !(null_statistic <= cutoffs[i] * (1 + 1e-12))
    out$delivered[i] <- out$gate[i]
    if (out$delivered[i]) {
      out$covered[i] <- out$relaxed_covered[i]
      out$rejects_zero[i] <- out$relaxed_rejects_zero[i]
    }
  }
  out
}
