#' Measure movement between adjacent aligned snapshots
#'
#' @param object An aligned `driftmap`.
#' @return A tidy data frame with `entity`, `time_from`, `time_to`, `x_from`,
#'   `y_from`, `x_to`, `y_to`, `dx`, `dy`, and `distance`. There is one row per
#'   entity observed in both immediately adjacent periods of the stored schedule.
#'   Extra input columns are not joined into the movement table.
#' @details Computes \eqn{\Delta_{it}=Z^*_{it}-Z^*_{i,t-1}} and its Euclidean norm.
#'   Gaps are never bridged; entrants/exits have no movement estimate across their
#'   unobserved endpoint. Distances use the first map's coordinate units and are
#'   not divided by elapsed time. They are descriptive, reference-relative
#'   estimates, not statistical evidence of movement. Returned tables do not
#'   mutate the input object; callers may assign one to `object$movement`.
#' @export
#' @examples
#' d <- data.frame(entity = rep(letters[1:4], 2), time = rep(1:2, each = 4),
#'                 x = rep(c(0, 2, 0, 1), 2), y = rep(c(0, 0, 2, 1), 2))
#' fit <- drift_data(d) |> align_snapshots()
#' measure_drift(fit)
measure_drift <- function(object) {
  require_aligned(object)
  z <- object$aligned
  movement_table(z, length(object$settings$periods))
}

movement_table <- function(z, n_periods) {
  rows <- vector("list", n_periods - 1L)
  for (j in seq.int(2L, n_periods)) {
    previous <- z[z$period_index == j - 1L, , drop = FALSE]
    current <- z[z$period_index == j, , drop = FALSE]
    entities <- intersect(previous$entity, current$entity)
    a <- previous[match(entities, previous$entity), , drop = FALSE]
    b <- current[match(entities, current$entity), , drop = FALSE]
    dx <- b$x - a$x
    dy <- b$y - a$y
    distance <- norm2(dx, dy)
    if (any(!is.finite(distance))) stop("Movement exceeded numerical range; rescale coordinates.", call. = FALSE)
    rows[[j - 1L]] <- data.frame(entity = entities, time_from = a$time, time_to = b$time,
                                 x_from = a$x, y_from = a$y, x_to = b$x, y_to = b$y,
                                 dx = dx, dy = dy, distance = distance)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

norm2 <- function(x, y) {
  a <- pmax(abs(x), abs(y))
  out <- numeric(length(a))
  nonzero <- a > 0
  out[nonzero] <- a[nonzero] * sqrt((x[nonzero] / a[nonzero])^2 + (y[nonzero] / a[nonzero])^2)
  out
}

require_aligned <- function(object) {
  validate_drift_data(object)
  z <- object$aligned
  if (is.null(z)) stop("Object is unaligned; call align_snapshots() first.", call. = FALSE)
  if (!is.data.frame(z) || !all(c("entity", "time", "period_index", "x", "y") %in% names(z)) ||
      !identical(z[c("entity", "time", "period_index")],
                                    object$coordinates[c("entity", "time", "period_index")]) ||
      !all(vapply(z[c("x", "y")], function(v) is.numeric(v) && !is.object(v) &&
                  is.null(dim(v)) && all(is.finite(v)), logical(1)))) {
    stop("Malformed aligned coordinates; recompute using align_snapshots().", call. = FALSE)
  }
  invisible(object)
}

#' Measure aligned distance to an entity or fixed coordinate anchor
#'
#' @param object An aligned `driftmap`.
#' @param anchor A character entity ID present in every period, or a finite numeric
#'   vector `c(x, y)` in the aligned reference coordinate system.
#' @return A tidy data frame with `entity`, `time`, `x`, `y`, `anchor_x`, `anchor_y`,
#'   and `distance`. The entity anchor's own distance is zero in every period.
#' @details This is a distance metric, distinct from the `anchors` used for
#'   alignment. An entity anchor may itself move. No distance change or uncertainty
#'   is inferred automatically; compare adjacent periods for the same entity.
#' @export
#' @examples
#' d <- data.frame(entity = rep(letters[1:4], 2), time = rep(1:2, each = 4),
#'                 x = rep(c(0, 2, 0, 1), 2), y = rep(c(0, 0, 2, 1), 2))
#' fit <- drift_data(d) |> align_snapshots()
#' distance_to_anchor(fit, "a")
distance_to_anchor <- function(object, anchor) {
  require_aligned(object)
  z <- object$aligned
  if (is.character(anchor) && length(anchor) == 1L && !is.na(anchor) && nzchar(trimws(anchor))) {
    a <- z[z$entity == anchor, , drop = FALSE]
    if (nrow(a) == 0L) stop("Unknown distance anchor entity: ", anchor, call. = FALSE)
    if (nrow(a) != length(object$settings$periods)) {
      stop("Distance anchor must be present in every period; use a fixed coordinate if appropriate.", call. = FALSE)
    }
    idx <- match(z$period_index, a$period_index)
    ax <- a$x[idx]
    ay <- a$y[idx]
  } else if (is.numeric(anchor) && !is.object(anchor) && is.null(dim(anchor)) &&
             length(anchor) == 2L && all(is.finite(anchor))) {
    ax <- rep(anchor[1L], nrow(z))
    ay <- rep(anchor[2L], nrow(z))
  } else stop("`anchor` must be one entity ID or a finite numeric vector c(x, y).", call. = FALSE)
  distance <- norm2(z$x - ax, z$y - ay)
  if (any(!is.finite(distance))) stop("Anchor distances exceeded numerical range; rescale coordinates.", call. = FALSE)
  data.frame(entity = z$entity, time = z$time, x = z$x, y = z$y,
             anchor_x = ax, anchor_y = ay, distance = distance)
}
