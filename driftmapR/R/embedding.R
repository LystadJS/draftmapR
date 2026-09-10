#' Embed repeated feature data or dissimilarities in two dimensions
#'
#' @param data A long data frame containing `entity`, `time`, and explicitly
#'   selected numeric features. For `method = "cmds"`, alternatively a list of
#'   labeled `dist` objects or square dissimilarity matrices, one per period.
#' @param features Names of at least two distinct feature columns. Required for
#'   data-frame input; never inferred from numeric metadata.
#' @param method `"pca"` for centered SVD scores or `"cmds"` for classical MDS.
#' @param periods Ordered schedule, as in [drift_data()]. For distance lists,
#'   supply one value per element, or use fully named lists whose names define
#'   the period order. If both are supplied, names must agree with the schedule.
#' @param standardize Standard-deviation reference: `"none"` (common original
#'   units), `"first"`, `"pooled"` (all entity-time rows, observation weighted),
#'   or `"period"`. All feature maps are centered within period. Period-specific
#'   scaling can remove substantive changes in feature dispersion.
#' @param feature_weights Optional finite nonnegative feature weights, applied
#'   through their square roots. Unnamed weights follow `features`; named weights
#'   must match them exactly. Weights are not normalized. Integer weights reproduce
#'   column multiplicities, including omitted columns with zero weight. These
#'   weights alone do not define a bootstrap or uncertainty estimate.
#' @param negative_eigen For classical MDS, `"error"` rejects materially negative
#'   Gram eigenvalues; `"truncate"` warns and keeps the leading two positive
#'   eigenvalues. No additive correction is implemented.
#' @param eigen_tol Relative spectral tolerance strictly between zero and one.
#'   Two retained eigenvalues must exceed this fraction of the largest absolute
#'   eigenvalue. A second/third eigenvalue tie at this tolerance warns.
#' @return A new, unaligned `driftmap`. Original input is retained in
#'   `original_data`; `embedding_metadata` holds feature order, weights,
#'   per-period centers/scales, and fits. `diagnostics$embedding` is a tidy
#'   spectrum/reconstruction table. Call [align_snapshots()] before
#'   [measure_drift()]. Supplied nonfeature metadata, such as cluster labels,
#'   remains in `coordinates` for [match_clusters()].
#' @details Each period needs at least three entities and effective rank two.
#'   Feature schemas are common across periods; missing/nonfinite measurements
#'   are rejected without imputation. Active constant features cannot be
#'   standardized. Inactive features receive scale one. Reserved coordinate
#'   names `x` and `y` may be features, but cannot be extra metadata.
#'
#'   For features, the fitted geometry is the centered matrix with column j
#'   divided by its declared sample SD and multiplied by `sqrt(weight[j])`. The
#'   PCA `prcomp` model is fitted to the scaled, weighted input, not directly to
#'   raw features. Its scores and loadings, raw centers, and scale/weight vectors
#'   are retained. `predict(model, raw_data)` is therefore not a raw-data adapter.
#'   Both methods store Gram eigenvalues (squared singular values for PCA).
#'   PCA retains the complete SVD spectrum, omitting implicit zero Gram
#'   eigenvalues when there are fewer features than entities. PCA component
#'   variances additionally remain in `model$sdev^2`.
#'
#'   Distance input needs unique, nonblank entity labels, identical row/column
#'   order, finite nonnegative symmetric entries, and an exactly zero diagonal.
#'   Feature preprocessing arguments are unavailable for this input type.
#'   MDS diagnostics report material negative eigenvalue counts, negative
#'   absolute-inertia fraction (including roundoff), two-dimensional positive
#'   and absolute inertia fractions, relative eigenvalue gap, and pairwise
#'   distance RMSE. PCA has no negative spectrum and distance RMSE is `NA`.
#'   A tie within the retained plane permits arbitrary rotation; a tie at its
#'   boundary makes the selected plane ambiguous. Alignment cannot repair
#'   truncation distortion or recover discarded dimensions.
#' @seealso [stats::prcomp()], [stats::cmdscale()], [align_snapshots()]
#' @export
#' @examples
#' first <- data.frame(entity = letters[1:5], time = 1,
#'                     a = c(0, 3, 0, 2, 1), b = c(0, 0, 3, 2, 1))
#' second <- first
#' second$time <- 2
#' second$a[5] <- second$a[5] + 0.8
#' second$b[5] <- second$b[5] + 0.6
#' fit <- embed_snapshots(rbind(first, second), features = c("a", "b")) |>
#'   align_snapshots(anchors = letters[1:4])
#' measure_drift(fit)
#' fit$diagnostics$embedding
embed_snapshots <- function(data, features = NULL, method = c("pca", "cmds"),
                            periods = NULL,
                            standardize = c("none", "first", "pooled", "period"),
                            feature_weights = NULL,
                            negative_eigen = c("error", "truncate"),
                            eigen_tol = 1e-10) {
  method <- match.arg(method)
  standardize <- match.arg(standardize)
  negative_eigen <- match.arg(negative_eigen)
  if (!is.numeric(eigen_tol) || length(eigen_tol) != 1L ||
      !is.finite(eigen_tol) || eigen_tol <= 0 || eigen_tol >= 1) {
    stop("`eigen_tol` must be finite and strictly between zero and one.", call. = FALSE)
  }
  if (is.data.frame(data)) {
    prepared <- prepare_embedding_features(data, features, periods, standardize,
                                           feature_weights)
  } else {
    if (method != "cmds" || !is.list(data) || inherits(data, "dist")) {
      stop("`data` must be a feature data frame, or a list of labeled distances for classical MDS.",
           call. = FALSE)
    }
    if (!is.null(features) || !is.null(feature_weights) || standardize != "none") {
      stop("Distance-list input cannot use features, feature weights, or standardization.", call. = FALSE)
    }
    prepared <- prepare_embedding_distances(data, periods)
  }
  object <- prepared$object
  periods <- object$settings$periods
  fits <- vector("list", length(periods))
  diagnostics <- vector("list", length(periods))
  for (i in seq_along(periods)) {
    rows <- which(object$coordinates$period_index == i)
    context <- paste0("period ", as.character(periods[i]))
    input <- prepared$inputs[[i]]
    fit <- if (method == "pca") fit_pca_snapshot(input, eigen_tol, context) else {
      distance <- if (prepared$input_type == "features") as.matrix(stats::dist(input)) else input
      fit_cmds_snapshot(distance, negative_eigen, eigen_tol, context)
    }
    object$coordinates[rows, c("x", "y")] <- fit$points
    fits[[i]] <- list(model = fit$model, eigenvalues = fit$eigenvalues)
    diagnostics[[i]] <- cbind(
      data.frame(time = periods[i], period_index = i, method = method,
                 n_entities = length(rows),
                 n_features = if (prepared$input_type == "features") length(features) else NA_integer_),
      as.data.frame(fit$diagnostics)
    )
  }
  object$embedding_metadata <- list(
    method = method, input_type = prepared$input_type, dimensions = 2L,
    feature_names = features, feature_weights = prepared$weights,
    preprocessing = list(standardize = standardize,
                         centers = prepared$centers, scales = prepared$scales),
    fits = fits
  )
  object$diagnostics$embedding <- do.call(rbind, diagnostics)
  rownames(object$diagnostics$embedding) <- NULL
  object$settings$embedding <- list(method = method, input_type = prepared$input_type,
                                    features = features, standardize = standardize,
                                    feature_weights = prepared$weights,
                                    negative_eigen = negative_eigen, eigen_tol = eigen_tol)
  validate_drift_data(object)
  object
}

prepare_embedding_features <- function(data, features, periods, standardize, weights) {
  if (!nrow(data) || anyDuplicated(names(data)) ||
      !all(c("entity", "time") %in% names(data))) {
    stop("Feature data must be nonempty with unique column names and entity/time columns.", call. = FALSE)
  }
  if (!is.character(features) || length(features) < 2L || anyNA(features) ||
      any(!nzchar(features)) || anyDuplicated(features) ||
      any(features %in% c("entity", "time", "period_index")) ||
      !all(features %in% names(data))) {
    stop("`features` must explicitly name at least two distinct measurement columns in data.", call. = FALSE)
  }
  extras <- setdiff(names(data), c("entity", "time", features))
  if (any(extras %in% c("x", "y", "period_index"))) {
    stop("Nonfeature metadata conflicts with reserved coordinate names x, y, or period_index.", call. = FALSE)
  }
  for (nm in features) {
    if (!is.numeric(data[[nm]]) || is.object(data[[nm]]) ||
        !is.null(dim(data[[nm]])) || any(!is.finite(data[[nm]]))) {
      stop("Feature `", nm, "` must be a finite numeric vector in every period.", call. = FALSE)
    }
  }
  weights <- check_feature_weights(weights, features)
  key_data <- data[c("entity", "time")]
  key_data$x <- key_data$y <- 0
  key_data$.embedding_row <- seq_len(nrow(data))
  object <- drift_data(key_data, periods = periods, original_data = data)
  row_index <- object$coordinates$.embedding_row
  object$coordinates$.embedding_row <- NULL
  if (length(extras)) object$coordinates[extras] <- data[row_index, extras, drop = FALSE]
  matrices <- lapply(seq_along(object$settings$periods), function(i) {
    rows <- row_index[object$coordinates$period_index == i]
    x <- as.matrix(data[rows, features, drop = FALSE])
    rownames(x) <- as.character(data$entity[rows])
    if (nrow(x) < 3L) stop("At least three entities are required in every embedding period.", call. = FALSE)
    x
  })
  active <- weights > 0
  get_scale <- function(x) {
    ans <- stats::setNames(rep(1, length(features)), features)
    ans[active] <- apply(x[, active, drop = FALSE], 2L, stats::sd)
    if (any(!is.finite(ans)) || any(ans <= 0)) {
      stop("Cannot standardize constant or numerically invalid active features; use common unscaled units or revise features.",
           call. = FALSE)
    }
    ans
  }
  fixed_scale <- switch(standardize, none = stats::setNames(rep(1, length(features)), features),
                        first = get_scale(matrices[[1L]]),
                        pooled = get_scale(as.matrix(data[features])), period = NULL)
  scales <- lapply(matrices, function(x) if (standardize == "period") get_scale(x) else fixed_scale)
  centers <- lapply(matrices, colMeans)
  inputs <- lapply(seq_along(matrices), function(i) {
    x <- matrices[[i]]
    # Zero inactive columns before arithmetic: omitted large features must not
    # overflow an intermediate product or influence the fitted geometry.
    x[, !active] <- 0
    x <- sweep(sweep(x, 2L, scales[[i]], "/"), 2L, sqrt(weights), "*")
    if (any(!is.finite(x))) stop("Feature preprocessing exceeded numerical range; rescale input units.", call. = FALSE)
    x
  })
  list(object = object, inputs = inputs, input_type = "features",
       weights = weights, centers = centers, scales = scales)
}

check_feature_weights <- function(weights, features) {
  if (is.null(weights)) return(stats::setNames(rep(1, length(features)), features))
  if (!is.numeric(weights) || is.object(weights) || !is.null(dim(weights)) ||
      length(weights) != length(features) || any(!is.finite(weights)) ||
      any(weights < 0) || !any(weights > 0)) {
    stop("`feature_weights` must be finite nonnegative numbers, one per feature, with positive total weight.", call. = FALSE)
  }
  if (!is.null(names(weights))) {
    if (anyNA(names(weights)) || anyDuplicated(names(weights)) ||
        !setequal(names(weights), features)) {
      stop("Named feature weights must match feature names exactly.", call. = FALSE)
    }
    weights <- weights[features]
  }
  stats::setNames(as.numeric(weights), features)
}

prepare_embedding_distances <- function(data, periods) {
  if (length(data) < 2L) stop("At least two distance snapshots are required.", call. = FALSE)
  nms <- names(data)
  if (is.null(periods)) {
    if (is.null(nms) || anyNA(nms) || any(!nzchar(trimws(nms)))) {
      stop("Distance lists require explicit periods or complete ordered list names.", call. = FALSE)
    }
    periods <- nms
  }
  check_time(periods, "periods")
  if (length(periods) != length(data) || anyDuplicated(periods)) {
    stop("Distance-list periods must be unique with one value per snapshot.", call. = FALSE)
  }
  if (!is.null(nms) && !identical(nms, as.character(periods))) {
    stop("Distance-list names must agree, in order, with the explicit periods.", call. = FALSE)
  }
  tables <- inputs <- vector("list", length(data))
  for (i in seq_along(data)) {
    d <- data[[i]]
    if (inherits(d, "dist")) {
      size <- attr(d, "Size")
      ids <- attr(d, "Labels")
      # as.matrix.dist() recycles malformed packed vectors, so validate the
      # representation before it can fabricate pairwise dissimilarities.
      if (!is.numeric(d) || is.complex(d) || !is.null(dim(d)) ||
          !is.numeric(size) || length(size) != 1L || !is.finite(size) ||
          size < 3 || size != floor(size) ||
          length(d) != size * (size - 1) / 2) {
        stop("Each dist object needs a valid integer Size of at least three and exactly Size * (Size - 1) / 2 numeric distances.",
             call. = FALSE)
      }
      if (!is.character(ids) || length(ids) != size || anyNA(ids) ||
          any(!nzchar(trimws(ids))) || anyDuplicated(ids)) {
        stop("Each dist object must retain explicit unique, nonblank entity labels matching Size.", call. = FALSE)
      }
      d <- as.matrix(d)
    } else {
      if (!is.matrix(d) || !is.numeric(d) || nrow(d) != ncol(d)) {
        stop("Each distance snapshot must be a labeled dist object or square numeric matrix.", call. = FALSE)
      }
      ids <- rownames(d)
    }
    if (is.null(ids) || length(ids) != nrow(d) || anyNA(ids) ||
        any(!nzchar(trimws(ids))) || anyDuplicated(ids) ||
        !identical(ids, colnames(d))) {
      stop("Distance matrices need unique nonblank entity labels and identical row/column order.", call. = FALSE)
    }
    ordering <- order(ids)
    inputs[[i]] <- d[ordering, ordering, drop = FALSE]
    tables[[i]] <- data.frame(entity = ids[ordering], time = periods[rep(i, length(ids))], x = 0, y = 0)
  }
  object <- drift_data(do.call(rbind, tables), periods = periods, original_data = data)
  list(object = object, inputs = inputs, input_type = "distances",
       weights = NULL, centers = NULL, scales = NULL)
}

fit_pca_snapshot <- function(input, eigen_tol, context) {
  fail <- function(message) stop("PCA ", context, ": ", message, call. = FALSE)
  model <- tryCatch(stats::prcomp(input, center = TRUE, scale. = FALSE, rank. = 2L),
                    error = function(e) fail(conditionMessage(e)))
  eigenvalues <- (model$sdev * sqrt(nrow(input) - 1))^2
  if (any(!is.finite(eigenvalues)) || any(!is.finite(model$x))) {
    fail("coordinate/eigenvalue units exceeded numerical range; rescale input units.")
  }
  largest <- max(eigenvalues)
  cutoff <- eigen_tol * largest
  if (length(eigenvalues) < 2L || eigenvalues[2L] <= cutoff) {
    fail("rank-deficient or nearly rank-deficient geometry: two positive eigenvalues above the relative tolerance are required.")
  }
  third <- if (length(eigenvalues) >= 3L) eigenvalues[3L] else 0
  boundary_tie <- abs(eigenvalues[2L] - third) <= cutoff
  if (boundary_tie) {
    warning("PCA ", context,
            ": the second and third eigenvalues tie at the truncation boundary; the selected two-dimensional subspace is not uniquely identified at this tolerance.",
            call. = FALSE)
  }
  fraction <- sum(eigenvalues[1:2] / largest) / sum(eigenvalues / largest)
  points <- model$x[, 1:2, drop = FALSE]
  colnames(points) <- c("x", "y")
  list(points = points, eigenvalues = eigenvalues, model = model,
       diagnostics = list(n_positive = sum(eigenvalues > cutoff), n_negative = 0L,
                          negative_inertia_fraction = 0,
                          positive_inertia_2d_fraction = fraction,
                          absolute_inertia_2d_fraction = fraction,
                          eigengap_23 = (eigenvalues[2L] - third) / largest,
                          boundary_tie = boundary_tie, distance_rmse = NA_real_))
}
