# Independent, study-only centered-Gram kernel for calibration study 02.
# These helpers do not alter or extend the public driftmapR inference API.
# Coordinates use C = X_centered %*% t(X_centered) / m, so displacement is in
# the same units as the public unstandardized PCA displacement divided by sqrt(m).

study02_matrix <- function(x, columns = NULL, label = "matrix") {
  if (!is.matrix(x) || !is.numeric(x) || any(!is.finite(x)) ||
      nrow(x) < 3L || (!is.null(columns) && ncol(x) != columns)) {
    stop(label, " must be a finite numeric matrix with at least three rows",
         if (!is.null(columns)) paste0(" and ", columns, " columns"), ".",
         call. = FALSE)
  }
  invisible(x)
}

study02_spectrum <- function(C, tol = 1e-10) {
  study02_matrix(C, label = "Gram matrix")
  if (nrow(C) != ncol(C) || !is.numeric(tol) || length(tol) != 1L ||
      !is.finite(tol) || tol <= 0 || tol >= 1) {
    stop("A square Gram matrix and tolerance in (0,1) are required.", call. = FALSE)
  }
  magnitude <- max(abs(C))
  if (magnitude == 0) stop("Gram matrix has zero rank.", call. = FALSE)
  if (max(abs(C - t(C))) > 1e-12 * magnitude) {
    stop("Gram matrix must be symmetric.", call. = FALSE)
  }
  if (max(abs(rowSums(C))) > 1e-9 * nrow(C) * magnitude) {
    stop("Gram matrix must be centered across entities.", call. = FALSE)
  }
  spectrum <- eigen((C + t(C)) / 2, symmetric = TRUE)
  values <- spectrum$values
  if (values[1L] <= 0 || values[2L] <= tol * values[1L]) {
    stop("Gram matrix must identify two positive coordinate dimensions.", call. = FALSE)
  }
  if (min(values) < -tol * values[1L]) {
    stop("Gram matrix has a materially negative eigenvalue.", call. = FALSE)
  }
  if (values[2L] - values[3L] <= tol * values[1L]) {
    stop("Second/third eigenvalue boundary tie makes the plane unidentified.", call. = FALSE)
  }
  spectrum$points <- sweep(spectrum$vectors[, 1:2, drop = FALSE], 2L,
                            sqrt(values[1:2]), "*")
  rownames(spectrum$points) <- rownames(C)
  colnames(spectrum$points) <- c("x", "y")
  spectrum
}

study02_points <- function(C) study02_spectrum(C)$points

study02_anchors <- function(anchors, n) {
  if (!is.numeric(anchors) || !length(anchors) || any(!is.finite(anchors)) ||
      length(anchors) < 3L || any(anchors != floor(anchors)) ||
      any(anchors < 1L | anchors > n) || anyDuplicated(anchors)) {
    stop("Anchors must specify at least three unique valid entity row indices.",
         call. = FALSE)
  }
  as.integer(anchors)
}

study02_register <- function(source, target, anchors, tol = 1e-10) {
  study02_matrix(source, 2L, "Source coordinates")
  study02_matrix(target, 2L, "Target coordinates")
  if (!identical(dim(source), dim(target))) {
    stop("Source and target must have identical dimensions and entity order.", call. = FALSE)
  }
  if (!is.numeric(tol) || length(tol) != 1L || !is.finite(tol) || tol <= 0 || tol >= 1) {
    stop("Tolerance must be in (0,1).", call. = FALSE)
  }
  anchors <- study02_anchors(anchors, nrow(source))
  source_center <- colMeans(source[anchors, , drop = FALSE])
  target_center <- colMeans(target[anchors, , drop = FALSE])
  a <- sweep(source[anchors, , drop = FALSE], 2L, source_center, "-")
  b <- sweep(target[anchors, , drop = FALSE], 2L, target_center, "-")
  aa <- max(abs(a)); bb <- max(abs(b))
  if (!is.finite(aa) || !is.finite(bb) || aa == 0 || bb == 0) {
    stop("Anchor coordinates have zero or nonfinite spread.", call. = FALSE)
  }
  a <- a / aa; b <- b / bb
  sa <- svd(a, nu = 0L, nv = 0L)$d
  sb <- svd(b, nu = 0L, nv = 0L)$d
  if (sa[2L] <= tol * sa[1L] || sb[2L] <= tol * sb[1L]) {
    stop("Rank-deficient anchor geometry.", call. = FALSE)
  }
  decomposition <- svd(crossprod(a, b))
  if (decomposition$d[1L] <= 0 || decomposition$d[2L] <= tol * decomposition$d[1L]) {
    stop("Rank-deficient anchor cross-covariance.", call. = FALSE)
  }
  rotation <- decomposition$u %*% t(decomposition$v)
  points <- sweep(sweep(source, 2L, source_center, "-") %*% rotation,
                  2L, target_center, "+")
  if (any(!is.finite(points))) stop("Registered coordinates are nonfinite.", call. = FALSE)
  colnames(points) <- c("x", "y")
  list(points = points, rotation = unname(rotation), source_center = source_center,
       target_center = target_center,
       translation = as.numeric(target_center - source_center %*% rotation),
       determinant = det(rotation), singular_values = decomposition$d)
}

study02_align_points <- function(points1, points2, pop_points, anchors) {
  baseline <- study02_register(points1, pop_points, anchors)
  temporal <- study02_register(points2, baseline$points, anchors)
  list(raw = list(points1, points2), aligned1 = baseline$points,
       aligned2 = temporal$points, displacement = temporal$points - baseline$points,
       baseline = baseline, temporal = temporal)
}

study02_estimate <- function(C1, C2, pop_points, anchors) {
  study02_align_points(study02_points(C1), study02_points(C2), pop_points, anchors)
}

study02_boot_points <- function(points1, points2, observed, pop_points, anchors) {
  if (!is.list(observed) || is.null(observed$aligned1)) {
    stop("Observed fit must retain aligned1 in the fixed population gauge.", call. = FALSE)
  }
  plugin <- study02_align_points(points1, points2, observed$aligned1, anchors)
  # Orthogonal Procrustes is equivariant: registering the plugin baseline to
  # population and rotating its ENTIRE displacement exactly reproduces a full
  # oracle baseline + temporal refit, provided the unique fits are identifiable.
  # Reuse this identity to avoid a redundant temporal SVD; tests verify it.
  # A diagnostic-only oracle failure must not invalidate a successful plugin
  # draw. Keep its result and account for the oracle attempt independently.
  oracle_registration <- tryCatch(
    study02_register(plugin$aligned1, pop_points, anchors),
    error = function(e) e)
  oracle_success <- !inherits(oracle_registration, "error")
  oracle_rotation <- if (oracle_success) oracle_registration$rotation else
    matrix(NA_real_, 2L, 2L)
  oracle <- if (oracle_success) plugin$displacement %*% oracle_rotation else
    matrix(NA_real_, nrow(plugin$displacement), 2L,
           dimnames = dimnames(plugin$displacement))
  colnames(oracle) <- c("x", "y")
  list(plugin = plugin$displacement, oracle = oracle,
       baseline = plugin$baseline, temporal = plugin$temporal,
       oracle_rotation = oracle_rotation, oracle_success = oracle_success,
       oracle_error = if (oracle_success) "" else conditionMessage(oracle_registration))
}

study02_boot_draw <- function(C1b, C2b, observed, pop_points, anchors) {
  study02_boot_points(study02_points(C1b), study02_points(C2b), observed,
                      pop_points, anchors)
}

study02_differential <- function(E, pop_spectrum, tol = 1e-10) {
  study02_matrix(E, label = "Gram perturbation")
  values <- pop_spectrum$values
  vectors <- pop_spectrum$vectors
  n <- nrow(E)
  if (ncol(E) != n || !is.numeric(values) || length(values) != n ||
      any(!is.finite(values)) || !is.matrix(vectors) ||
      !identical(dim(vectors), c(n, n)) || any(!is.finite(vectors))) {
    stop("Gram perturbation and complete population spectrum must agree.", call. = FALSE)
  }
  magnitude <- max(abs(E))
  if (magnitude > 0 && max(abs(E - t(E))) > 1e-12 * magnitude) {
    stop("Gram perturbation must be symmetric.", call. = FALSE)
  }
  if (values[2L] <= tol * values[1L] ||
      values[1L] - values[2L] <= tol * values[1L] ||
      values[2L] - values[3L] <= tol * values[1L]) {
    stop("The differential requires distinct leading eigenvalues and an identified plane.",
         call. = FALSE)
  }
  if (max(abs(crossprod(vectors) - diag(n))) > 1e-8) {
    stop("Population eigenvectors must be orthonormal.", call. = FALSE)
  }
  # Only the leading eigenvectors require differentiability. Ties among the
  # discarded eigenvalues are allowed; summing over their complete eigenspaces
  # is invariant to the arbitrary basis inside each tied subspace.
  coefficients <- crossprod(vectors, E %*% vectors[, 1:2, drop = FALSE])
  differential <- matrix(0, n, 2L)
  for (j in 1:2) {
    other <- setdiff(seq_len(n), j)
    dv <- vectors[, other, drop = FALSE] %*%
      (coefficients[other, j] / (values[j] - values[other]))
    differential[, j] <- sqrt(values[j]) * dv +
      vectors[, j] * coefficients[j, j] / (2 * sqrt(values[j]))
  }
  dimnames(differential) <- list(rownames(pop_spectrum$points), c("x", "y"))
  differential
}

study02_alignment_tangent <- function(A, D, anchors) {
  study02_matrix(A, 2L, "Population coordinates")
  study02_matrix(D, 2L, "Coordinate perturbation")
  if (!identical(dim(A), dim(D))) stop("Coordinate dimensions must agree.", call. = FALSE)
  anchors <- study02_anchors(anchors, nrow(A))
  center_A <- colMeans(A[anchors, , drop = FALSE])
  center_D <- colMeans(D[anchors, , drop = FALSE])
  A_centered <- sweep(A[anchors, , drop = FALSE], 2L, center_A, "-")
  D_centered <- sweep(D[anchors, , drop = FALSE], 2L, center_D, "-")
  # The complete orthogonal fit must be locally identifiable, including the
  # discrete reflection alternative, before using its identity-branch tangent.
  singular <- svd(A_centered, nu = 0L, nv = 0L)$d
  if (singular[1L] <= 0 || singular[2L] <= 1e-10 * singular[1L]) {
    stop("Rank-deficient population anchor geometry.", call. = FALSE)
  }
  J <- matrix(c(0, 1, -1, 0), nrow = 2L)
  direction <- A_centered %*% J
  omega <- -sum(direction * D_centered) / sum(direction^2)
  alignment <- sweep(sweep(A, 2L, center_A, "-") %*% (omega * J),
                       2L, center_D, "-")
  colnames(alignment) <- c("x", "y")
  list(full = D + alignment, embedding = D, alignment = alignment, omega = omega)
}

study02_tangent <- function(E, pop_spectrum, anchors) {
  A <- pop_spectrum$points
  if (is.null(A)) {
    A <- sweep(pop_spectrum$vectors[, 1:2, drop = FALSE], 2L,
                sqrt(pop_spectrum$values[1:2]), "*")
  }
  study02_alignment_tangent(A, study02_differential(E, pop_spectrum), anchors)
}
