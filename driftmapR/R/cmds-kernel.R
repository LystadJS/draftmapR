# Classical scaling kernel. All eigendecomposition and inertia calculations use
# normalized distances; physical units are restored only in returned results.
# Eigenvector signs and rotations within repeated eigenspaces are arbitrary.
fit_cmds_snapshot <- function(distance, negative_eigen = "error",
                              eigen_tol = 1e-10, context = "snapshot") {
  fail <- function(message) stop("Classical MDS ", context, ": ", message, call. = FALSE)
  if (!is.character(negative_eigen) || length(negative_eigen) != 1L ||
      is.na(negative_eigen) || !negative_eigen %in% c("error", "truncate")) {
    fail("`negative_eigen` must be 'error' or 'truncate'.")
  }
  if (!is.numeric(eigen_tol) || length(eigen_tol) != 1L ||
      !is.finite(eigen_tol) || eigen_tol <= 0 || eigen_tol >= 1) {
    fail("`eigen_tol` must be a finite number strictly between zero and one.")
  }
  if (!is.matrix(distance) || !is.numeric(distance) || is.complex(distance) ||
      nrow(distance) != ncol(distance)) {
    fail("distances must be a square numeric matrix.")
  }
  if (nrow(distance) < 3L) fail("at least 3 entities are required for a two-dimensional map.")
  if (any(!is.finite(distance))) fail("distances must be finite and nonmissing.")
  if (any(distance < 0)) fail("distances must be nonnegative.")
  if (any(diag(distance) != 0)) fail("the distance matrix must be hollow (zero diagonal).")
  unit <- max(distance)
  if (unit == 0) fail("rank-deficient geometry: at least two positive eigenvalues are required.")
  normalized <- distance / unit
  # Permit floating-point roundoff, independently of the user-selected spectral
  # tolerance, then make the numerical matrix exactly symmetric.
  if (max(abs(normalized - t(normalized))) > 100 * .Machine$double.eps) {
    fail("the distance matrix must be symmetric.")
  }
  normalized <- (normalized + t(normalized)) / 2
  squared <- normalized^2
  gram <- -0.5 * (sweep(sweep(squared, 1L, rowMeans(squared), "-"),
                        2L, colMeans(squared), "-") + mean(squared))
  gram <- (gram + t(gram)) / 2
  decomposition <- eigen(gram, symmetric = TRUE)
  eigenvalues_scaled <- decomposition$values
  largest <- max(abs(eigenvalues_scaled))
  cutoff <- eigen_tol * largest
  positive <- eigenvalues_scaled > cutoff
  negative <- eigenvalues_scaled < -cutoff
  if (any(negative)) {
    message <- paste0(sum(negative), " materially negative eigenvalue(s): ",
                      "dissimilarities are not Euclidean at the requested tolerance.")
    if (negative_eigen == "error") {
      fail(paste0(message, " Use `negative_eigen = 'truncate'` only to accept an approximate positive-eigenvalue map."))
    }
    warning("Classical MDS ", context, ": ", message,
            " Retaining the two leading positive eigenvalues; no additive correction is applied.",
            call. = FALSE)
  }
  if (sum(positive) < 2L) {
    fail("rank-deficient or nearly rank-deficient geometry: at least two positive eigenvalues above the relative tolerance are required.")
  }
  boundary_tie <- abs(eigenvalues_scaled[2L] - eigenvalues_scaled[3L]) <= cutoff
  if (boundary_tie) {
    warning("Classical MDS ", context,
            ": the second and third eigenvalues tie at the truncation boundary; the selected two-dimensional subspace is not uniquely identified at this tolerance.",
            call. = FALSE)
  }
  points_scaled <- sweep(decomposition$vectors[, 1:2, drop = FALSE],
                         2L, sqrt(eigenvalues_scaled[1:2]), "*")
  points <- points_scaled * unit
  dimnames(points) <- list(rownames(distance), c("x", "y"))
  # Multiplying in stages avoids needless overflow in unit^2 itself.
  eigenvalues <- (eigenvalues_scaled * unit) * unit
  if (any(!is.finite(points)) || any(!is.finite(eigenvalues)) ||
      any(eigenvalues[1:2] <= 0)) {
    fail("restoring coordinate/eigenvalue units exceeded numerical range; rescale input distance units.")
  }
  positive_inertia <- sum(pmax(eigenvalues_scaled, 0))
  absolute_inertia <- sum(abs(eigenvalues_scaled))
  retained_inertia <- sum(eigenvalues_scaled[1:2])
  gof <- c(retained_inertia / absolute_inertia, retained_inertia / positive_inertia)
  error_scaled <- as.vector(stats::dist(points_scaled)) -
    normalized[lower.tri(normalized)]
  distance_rmse <- sqrt(mean(error_scaled^2)) * unit
  diagnostics <- list(
    n_positive = sum(positive),
    n_negative = sum(negative),
    negative_inertia_fraction = sum(abs(eigenvalues_scaled[eigenvalues_scaled < 0])) / absolute_inertia,
    positive_inertia_2d_fraction = gof[2L],
    absolute_inertia_2d_fraction = gof[1L],
    eigengap_23 = (eigenvalues_scaled[2L] - eigenvalues_scaled[3L]) / largest,
    boundary_tie = boundary_tie,
    distance_rmse = distance_rmse
  )
  if (any(!is.finite(unlist(diagnostics)))) {
    fail("diagnostics exceeded numerical range; rescale input distance units.")
  }
  list(points = points, eigenvalues = eigenvalues,
       model = list(points = points, eig = eigenvalues, GOF = gof, ac = 0),
       diagnostics = diagnostics)
}
