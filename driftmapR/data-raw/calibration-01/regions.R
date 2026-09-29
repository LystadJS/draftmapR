# Candidate joint displacement-vector regions for calibration study 01.
# These are study helpers, not exported driftmapR inference APIs. Every region
# is centered at the observed displacement. All inputs must already share one
# common population gauge; a new orientation is never fitted to each draw.
#
# `wald` uses a chi-square(2) cutoff and the sample covariance of bootstrap
# vectors (not the covariance divided by the number of bootstrap draws).
# `bootstrap_mahalanobis` uses the empirical quantile of UNCENTERED bootstrap
# errors in the same fixed covariance metric. It is not bootstrap-t.
# `bootstrap_ball` uses the empirical quantile of Euclidean bootstrap errors.
# Neither empirical construction removes the observed bootstrap bias.
# Singular ellipses and zero-radius balls are unavailable: we do not interpret
# a collapsed bootstrap distribution as certain population coverage.

calibration_regions <- function(observed, draws, truth, level = 0.95,
                                cov_tol = 1e-8, min_valid = 20L) {
  check_vector <- function(x, label) {
    if (!is.numeric(x) || !is.null(dim(x)) || length(x) != 2L ||
        any(!is.finite(x))) {
      stop(label, " must be a finite numeric displacement vector of length 2.",
           call. = FALSE)
    }
  }
  check_vector(observed, "observed")
  check_vector(truth, "truth")
  if (!is.matrix(draws) || !is.numeric(draws) || ncol(draws) != 2L ||
      any(!is.finite(draws))) {
    stop("draws must be a finite numeric matrix with two columns; failures must be accounted for before constructing regions.",
         call. = FALSE)
  }
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
      level <= 0 || level >= 1) {
    stop("level must be a finite number strictly between zero and one.", call. = FALSE)
  }
  if (!is.numeric(cov_tol) || length(cov_tol) != 1L || !is.finite(cov_tol) ||
      cov_tol <= 0 || cov_tol >= 1) {
    stop("cov_tol must be a finite number strictly between zero and one.", call. = FALSE)
  }
  if (!is.numeric(min_valid) || length(min_valid) != 1L || !is.finite(min_valid) ||
      min_valid < 3 || min_valid != floor(min_valid)) {
    stop("min_valid must be an integer of at least 3.", call. = FALSE)
  }
  n <- nrow(draws)
  covariance <- if (n >= 2L) stats::cov(draws) else matrix(NA_real_, 2L, 2L)
  out <- data.frame(
    method = c("wald", "bootstrap_mahalanobis", "bootstrap_ball"),
    available = FALSE, reason = "insufficient_valid", covered = NA,
    rejects_zero = NA, radius = NA_real_, area = NA_real_,
    center_dx = observed[1L], center_dy = observed[2L],
    truth_statistic = NA_real_, null_statistic = NA_real_, n_valid = n,
    var_dx = covariance[1L, 1L], var_dy = covariance[2L, 2L],
    cov_dx_dy = covariance[1L, 2L], stringsAsFactors = FALSE,
    row.names = NULL)
  if (n < min_valid) return(out)

  errors <- sweep(draws, 2L, observed, "-")
  truth_error <- truth - observed
  null_error <- -observed
  # Scaling each row prevents avoidable overflow when taking vector norms.
  row_norm <- function(x) {
    a <- apply(abs(x), 1L, max)
    answer <- numeric(nrow(x))
    use <- a > 0 & is.finite(a)
    answer[use] <- a[use] * sqrt(rowSums((x[use, , drop = FALSE] / a[use])^2))
    answer[!is.finite(a)] <- Inf
    answer
  }
  compare <- function(statistic, cutoff) {
    # A relative allowance only addresses floating-point boundary roundoff.
    statistic <= cutoff * (1 + 1e-12)
  }
  error_norms <- row_norm(errors)
  ball_radius <- as.numeric(stats::quantile(error_norms, level, type = 7L,
                                            names = FALSE))
  out$reason[3L] <- if (!is.finite(ball_radius)) "nonfinite_radius" else if (
    ball_radius == 0) "zero_radius" else "ok"
  if (out$reason[3L] == "ok") {
    area <- pi * ball_radius^2
    if (!is.finite(area)) {
      out$reason[3L] <- "nonfinite_area"
    } else {
      out$available[3L] <- TRUE
      out$radius[3L] <- ball_radius
      out$area[3L] <- area
      out$truth_statistic[3L] <- row_norm(matrix(truth_error, nrow = 1L))
      out$null_statistic[3L] <- row_norm(matrix(null_error, nrow = 1L))
      out$covered[3L] <- compare(out$truth_statistic[3L], ball_radius)
      out$rejects_zero[3L] <- !compare(out$null_statistic[3L], ball_radius)
    }
  }

  if (any(!is.finite(covariance))) {
    out$reason[1:2] <- "nonfinite_covariance"
    return(out)
  }
  spectrum <- eigen(covariance, symmetric = TRUE)
  eigenvalues <- spectrum$values
  if (eigenvalues[1L] <= 0 || eigenvalues[2L] <= cov_tol * eigenvalues[1L]) {
    out$reason[1:2] <- "singular_covariance"
    return(out)
  }
  # Whitening gives the same quadratic form as solve(S), without explicitly
  # constructing an inverse. A single S is used for all three comparisons.
  quadratic <- function(x) {
    projected <- sweep(x %*% spectrum$vectors, 2L, sqrt(eigenvalues), "/")
    rowSums(projected^2)
  }
  truth_stat <- quadratic(matrix(truth_error, nrow = 1L))
  null_stat <- quadratic(matrix(null_error, nrow = 1L))
  bootstrap_stat <- quadratic(errors)
  cutoffs <- c(stats::qchisq(level, df = 2L),
               as.numeric(stats::quantile(bootstrap_stat, level, type = 7L,
                                          names = FALSE)))
  determinant_root <- sqrt(eigenvalues[1L]) * sqrt(eigenvalues[2L])
  for (j in 1:2) {
    area <- pi * cutoffs[j] * determinant_root
    if (!is.finite(cutoffs[j]) || cutoffs[j] <= 0) {
      out$reason[j] <- "nonfinite_or_zero_radius"
    } else if (!is.finite(area)) {
      out$reason[j] <- "nonfinite_area"
    } else {
      out$available[j] <- TRUE
      out$reason[j] <- "ok"
      out$radius[j] <- sqrt(cutoffs[j])
      out$area[j] <- area
      out$truth_statistic[j] <- truth_stat
      out$null_statistic[j] <- null_stat
      out$covered[j] <- compare(truth_stat, cutoffs[j])
      out$rejects_zero[j] <- !compare(null_stat, cutoffs[j])
    }
  }
  out
}

# Orient each observed data set ONCE using its baseline and the population
# baseline. Apply the returned rotation to both observed and bootstrap vectors.
# Translation vanishes for displacement vectors; scaling is never estimated.
# This helper intentionally uses no internal driftmapR Procrustes function.
calibration_gauge_rotation <- function(observed_fit, population_fit, anchors = NULL) {
  baseline <- function(fit, label) {
    z <- if (!is.null(fit$aligned)) fit$aligned else fit$coordinates
    required <- c("entity", "period_index", "x", "y")
    if (!is.data.frame(z) || !all(required %in% names(z))) {
      stop(label, " must contain aligned or original entity/period_index/x/y coordinates.",
           call. = FALSE)
    }
    z <- z[z$period_index == 1L & !is.na(z$period_index), required, drop = FALSE]
    if (!nrow(z) || anyNA(z$entity) || any(!nzchar(trimws(as.character(z$entity)))) ||
        anyDuplicated(z$entity) || !is.numeric(z$x) || !is.numeric(z$y) ||
        any(!is.finite(as.matrix(z[c("x", "y")])))) {
      stop(label, " baseline must have unique nonmissing entities and finite numeric coordinates.",
           call. = FALSE)
    }
    z$entity <- as.character(z$entity)
    z
  }
  observed <- baseline(observed_fit, "observed_fit")
  population <- baseline(population_fit, "population_fit")
  if (!is.null(anchors) && (!is.character(anchors) || !length(anchors) ||
      anyNA(anchors) || any(!nzchar(trimws(anchors))) || anyDuplicated(anchors))) {
    stop("anchors must be unique, nonmissing character entity IDs.", call. = FALSE)
  }
  ids <- intersect(observed$entity, population$entity)
  if (!is.null(anchors)) ids <- intersect(anchors, ids)
  if (length(ids) < 3L) {
    stop("Population gauge requires at least 3 shared noncollinear baseline anchors.",
         call. = FALSE)
  }
  source <- as.matrix(observed[match(ids, observed$entity), c("x", "y")])
  target <- as.matrix(population[match(ids, population$entity), c("x", "y")])
  source <- sweep(source, 2L, colMeans(source), "-")
  target <- sweep(target, 2L, colMeans(target), "-")
  source_scale <- max(abs(source))
  target_scale <- max(abs(target))
  if (!is.finite(source_scale) || !is.finite(target_scale) ||
      source_scale == 0 || target_scale == 0) {
    stop("Population gauge has degenerate or nonfinite centered geometry.", call. = FALSE)
  }
  source <- source / source_scale
  target <- target / target_scale
  s_source <- svd(source, nu = 0L, nv = 0L)$d
  s_target <- svd(target, nu = 0L, nv = 0L)$d
  fit <- svd(crossprod(source, target))
  relative_tol <- 1e-10
  if (s_source[2L] <= relative_tol * s_source[1L] ||
      s_target[2L] <= relative_tol * s_target[1L] || fit$d[1L] == 0 ||
      fit$d[2L] <= relative_tol * fit$d[1L]) {
    stop("Population gauge has rank-deficient baseline geometry or cross-covariance.",
         call. = FALSE)
  }
  unname(fit$u %*% t(fit$v))
}
