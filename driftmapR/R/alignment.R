#' Align coordinate snapshots by orthogonal Procrustes fitting
#'
#' @param object A `driftmap` created by [drift_data()].
#' @param reference `"previous"` aligns each raw snapshot to the already aligned
#'   previous snapshot; `"first"` aligns each raw snapshot to the first snapshot.
#' @param scale Estimate an isotropic nonnegative scale factor? Default `FALSE`
#'   preserves coordinate units. Scaling may absorb real expansion/contraction.
#' @param anchors Optional character vector of stable entity IDs used to fit each
#'   transformation. Only anchors present in both compared periods are fitted.
#'   The transformation is applied to all entities, including new entities.
#' @param rank_tol Relative singular-value tolerance in `(0, 1)` for rejecting
#'   degenerate or nearly degenerate geometry. Default `1e-10`.
#' @return An updated `driftmap`. `aligned` contains all transformed rows;
#'   `transformations` has one row per time (including an identity first row),
#'   with list columns `rotation`, `translation`, `matched_entities`, and
#'   `singular_values`, and scalar fit diagnostics. `n_shared` counts all shared
#'   entities; `n_matched` counts fitting entities. `rss` is the fitting residual
#'   sum of squares; `rmse = sqrt(rss / n_matched)` is a per-entity radial RMSE;
#'   `disparity` divides RSS by centered target sum of squares. The first row
#'   has zero fitting entities and `NA` RMSE/disparity. Raw coordinates are kept.
#' @details For row-vector coordinates, let centered fitting maps be \eqn{X}
#'   (source) and \eqn{Y} (reference). With
#'   \eqn{X^T Y = U D V^T}, the minimizer is \eqn{R = U V^T}.
#'   Reflections are allowed: no determinant correction is applied.
#'   If enabled, \eqn{s = tr(D) / ||X||_F^2}; otherwise \eqn{s = 1}.
#'   Translation is \eqn{b = \bar y - s\bar x R}. Every source point is
#'   transformed as \eqn{z^* = szR + b}.
#'
#'   At least three noncollinear fitting entities in both maps, and full-rank
#'   cross-covariance, are required for identifiable two-dimensional fitting.
#'   Scaling intermediate matrices improves numerical range; singular-value
#'   ratios, not a fixed absolute cutoff, define rank. Nonfinite fitted results
#'   are rejected. This is pairwise sequential/reference alignment, not generalized
#'   consensus Procrustes. Previous-period alignment may accumulate reference drift.
#'
#'   Movement is relative to the fitted reference configuration. Fitting moving
#'   entities can absorb genuine shared movement. An entirely coherent global
#'   translation/rotation cannot be identified separately from coordinate artifact
#'   without external constraints. Anchors encode a substantive stability assumption;
#'   they are not discovered or certified by this function.
#' @export
#' @examples
#' p <- data.frame(entity = letters[1:4], time = 1, x = c(0, 2, 0, 1),
#'                 y = c(0, 0, 2, 1))
#' q <- transform(p, time = 2, x = -y + 5, y = x - 3)
#' fit <- drift_data(rbind(p, q)) |> align_snapshots()
#' fit$transformations[c("time", "reference_time", "n_matched", "rss")]
#' measure_drift(fit)
align_snapshots <- function(object, reference = c("previous", "first"),
                            scale = FALSE, anchors = NULL, rank_tol = 1e-10) {
  validate_drift_data(object)
  reference <- match.arg(reference)
  check_flag(scale, "scale")
  check_alignment_args(object, anchors, rank_tol)
  z <- object$coordinates
  aligned <- z
  periods <- object$settings$periods
  rows <- vector("list", length(periods))
  rows[[1L]] <- transform_row(periods[1L], periods[1L], 0L, 0L,
                              list(rotation = diag(2), translation = c(0, 0),
                                   scale = 1, rss = 0, rmse = NA_real_, disparity = NA_real_,
                                   determinant = 1, singular_values = c(NA_real_, NA_real_),
                                   condition_number = NA_real_), character())
  for (j in seq.int(2L, length(periods))) {
    ref <- if (reference == "first") 1L else j - 1L
    source <- z[z$period_index == j, , drop = FALSE]
    target <- aligned[aligned$period_index == ref, , drop = FALSE]
    pair <- alignment_pair(source, target, anchors)
    fit <- fit_procrustes(pair$source, pair$target, scale, rank_tol,
                          paste0("period ", as.character(periods[j]), " vs ", as.character(periods[ref])))
    # Apply with centered arithmetic to reduce cancellation from large offsets.
    all_xy <- sweep(as.matrix(source[c("x", "y")]), 2L, fit$source_center, "-")
    transformed <- sweep(fit$scale * (all_xy %*% fit$rotation), 2L, fit$target_center, "+")
    if (any(!is.finite(transformed))) {
      stop("Nonfinite transformed coordinates; rescale the input units.", call. = FALSE)
    }
    aligned[aligned$period_index == j, c("x", "y")] <- transformed
    rows[[j]] <- transform_row(periods[j], periods[ref], pair$n_shared,
                                length(pair$entities), fit, pair$entities)
  }
  object$aligned <- aligned
  object$transformations <- do.call(rbind, rows)
  rownames(object$transformations) <- NULL
  object$settings$reference <- reference
  object$settings$scale <- scale
  object$settings$anchors <- anchors
  object$settings$rank_tol <- rank_tol
  object$settings$alignment_method <- "orthogonal_procrustes"
  # A new coordinate fit invalidates any caller-stored downstream results.
  object$movement <- NULL
  object$bootstrap <- NULL
  object$diagnostics$alignment <- list(
    estimand = "movement relative to fitting entities and selected reference",
    reflection_allowed = TRUE,
    reference_fixed = periods[1L],
    n_transitions = length(periods) - 1L)
  object
}

check_alignment_args <- function(object, anchors, rank_tol) {
  if (!is.numeric(rank_tol) || length(rank_tol) != 1L || !is.finite(rank_tol) ||
      rank_tol <= 0 || rank_tol >= 1) {
    stop("`rank_tol` must be a finite number strictly between zero and one.", call. = FALSE)
  }
  if (!is.null(anchors)) {
    if (!is.character(anchors) || !length(anchors) || anyNA(anchors) ||
        any(!nzchar(trimws(anchors))) || anyDuplicated(anchors)) {
      stop("`anchors` must be unique, nonmissing character entity IDs.", call. = FALSE)
    }
    if (!all(anchors %in% object$coordinates$entity)) {
      stop("Unknown alignment anchor IDs: ", paste(setdiff(anchors, object$coordinates$entity), collapse = ", "),
           call. = FALSE)
    }
  }
}

alignment_pair <- function(source, target, anchors) {
  shared <- intersect(source$entity, target$entity)
  entities <- if (is.null(anchors)) shared else intersect(shared, anchors)
  list(source = as.matrix(source[match(entities, source$entity), c("x", "y"), drop = FALSE]),
       target = as.matrix(target[match(entities, target$entity), c("x", "y"), drop = FALSE]),
       entities = entities, n_shared = length(shared))
}

fit_procrustes <- function(source, target, scale, rank_tol, context) {
  fail <- function(message) stop("Alignment ", context, ": ", message, call. = FALSE)
  if (nrow(source) < 3L) {
    fail(paste0("insufficient shared fitting entities (", nrow(source),
                "); at least 3 noncollinear entities are required."))
  }
  source_center <- colMeans(source)
  target_center <- colMeans(target)
  x <- sweep(source, 2L, source_center, "-")
  y <- sweep(target, 2L, target_center, "-")
  ax <- max(abs(x))
  ay <- max(abs(y))
  if (!is.finite(ax) || !is.finite(ay)) fail("centering overflowed; rescale input units.")
  if (ax == 0 || ay == 0) fail("degenerate geometry: fitting coordinates have zero spread.")
  xn <- x / ax
  yn <- y / ay
  sx <- svd(xn, nu = 0, nv = 0)$d
  sy <- svd(yn, nu = 0, nv = 0)$d
  if (sx[2L] <= rank_tol * sx[1L] || sy[2L] <= rank_tol * sy[1L]) {
    fail("rank-deficient or nearly collinear geometry; two coordinate dimensions must be identifiable.")
  }
  cross <- svd(crossprod(xn, yn))
  if (cross$d[1L] == 0 || cross$d[2L] <= rank_tol * cross$d[1L]) {
    fail("rank-deficient cross-covariance: the optimal transformation is not stably identifiable.")
  }
  rotation <- cross$u %*% t(cross$v)
  scaling <- if (scale) (ay / ax) * sum(cross$d) / sum(xn^2) else 1
  translation <- as.numeric(target_center - scaling * (source_center %*% rotation))
  residual <- scaling * (x %*% rotation) - y
  rss <- sum(residual^2)
  tss <- sum(y^2)
  if (!is.finite(scaling) || scaling <= 0 || any(!is.finite(translation)) ||
      !is.finite(rss) || !is.finite(tss) || tss == 0) {
    fail("fitting exceeded numerical range; rescale coordinate units.")
  }
  list(rotation = unname(rotation), translation = translation, scale = scaling,
       rss = rss, rmse = sqrt(rss / nrow(source)), disparity = rss / tss,
       determinant = det(rotation), singular_values = cross$d,
       condition_number = cross$d[1L] / cross$d[2L],
       source_center = source_center, target_center = target_center)
}

transform_row <- function(time, reference_time, n_shared, n_matched, fit, entities) {
  out <- data.frame(time = time, reference_time = reference_time,
                    n_shared = n_shared, n_matched = n_matched,
                    scale = fit$scale, rss = fit$rss, rmse = fit$rmse,
                    disparity = fit$disparity, determinant = fit$determinant,
                    condition_number = fit$condition_number)
  out$rotation <- list(fit$rotation)
  out$translation <- list(fit$translation)
  out$matched_entities <- list(entities)
  # Singular values of normalized cross-covariance, for rank diagnostics only.
  out$singular_values <- list(fit$singular_values)
  out
}
