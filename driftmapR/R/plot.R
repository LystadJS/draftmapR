#' Plot repeated positions and adjacent-period trajectories
#'
#' Display supplied or aligned two-dimensional coordinates. Lines and arrows
#' connect observations only when an entity is present in both immediately
#' adjacent scheduled periods. They never bridge an unobserved period.
#'
#' @param object A `driftmap` object from [drift_data()].
#' @param aligned Logical; use aligned coordinates. The object must first have
#'   been processed by [align_snapshots()] when `TRUE`.
#' @param trajectories Logical; draw arrows between adjacent observations.
#' @param labels Logical; label entities at their latest observed positions.
#'   Overlapping text may be omitted. Dense plots may require a larger plotting
#'   device or selective annotation.
#'
#' @details Colors and point shapes distinguish periods. Equal coordinate-axis
#'   scaling preserves angles and relative Euclidean distances. The plot does
#'   not fit transformations or estimate uncertainty. Arrows show geometric
#'   displacement and are not evidence of statistically significant movement.
#'
#'   With `aligned = FALSE`, raw arrows remain available to diagnose coordinate
#'   artifacts and are labeled as unaligned. Set `trajectories = FALSE` to show
#'   positions alone.
#'
#' @return A `ggplot` object that can be customized with ggplot2.
#' @export
#' @examples
#' first <- data.frame(entity = letters[1:4], time = 1,
#'                     x = c(0, 2, 0, 2), y = c(0, 0, 1, 1))
#' second <- transform(first, time = 2, x = -y + 3, y = x - 2)
#' map <- drift_data(rbind(first, second))
#' map <- align_snapshots(map)
#' plot_drift_map(map)
#' plot_drift_map(map, aligned = FALSE, trajectories = FALSE)
plot_drift_map <- function(object, aligned = TRUE, trajectories = TRUE,
                           labels = FALSE) {
  validate_drift_data(object)
  for (argument in c("aligned", "trajectories", "labels")) {
    value <- get(argument, inherits = FALSE)
    if (!is.logical(value) || length(value) != 1L || is.na(value)) {
      stop(sprintf("`%s` must be one non-missing logical value.", argument),
           call. = FALSE)
    }
  }
  if (aligned) require_aligned(object)
  positions <- if (aligned) object$aligned else object$coordinates
  required <- c("entity", "time", "x", "y", "period_index")
  if (!is.data.frame(positions) || !all(required %in% names(positions))) {
    stop("The object does not contain valid two-dimensional coordinates.",
         call. = FALSE)
  }
  periods <- object$settings$periods
  n_periods <- length(periods)
  display_labels <- as.character(periods)
  duplicate_labels <- duplicated(display_labels) |
    duplicated(display_labels, fromLast = TRUE)
  if (any(duplicate_labels)) {
    display_labels[duplicate_labels] <- paste0(
      display_labels[duplicate_labels], " (period ",
      seq_len(n_periods)[duplicate_labels], ")"
    )
  }
  positions$period_label <- factor(positions$period_index,
                                   levels = seq_len(n_periods),
                                   labels = display_labels, ordered = TRUE)
  palette <- grDevices::hcl.colors(n_periods, palette = "Dark 3")
  if (n_periods <= 3L) {
    palette <- c("#536A7B", "#B87925", "#685791")[seq_len(n_periods)]
  }
  names(palette) <- display_labels
  shapes <- rep(c(16, 17, 15, 18, 0, 1, 2, 5), length.out = n_periods)
  names(shapes) <- display_labels

  # Local bindings keep static package checks compatible with ggplot2's
  # data-masked aesthetics without importing an additional dependency.
  x <- y <- entity <- period_label <- x_from <- y_from <- x_to <- y_to <- NULL
  graph <- ggplot2::ggplot(positions, ggplot2::aes(x = x, y = y))
  if (trajectories) {
    pieces <- lapply(seq_len(max(0L, n_periods - 1L)), function(index) {
      previous <- positions[positions$period_index == index, , drop = FALSE]
      current <- positions[positions$period_index == index + 1L, , drop = FALSE]
      matched <- match(current$entity, previous$entity)
      keep <- !is.na(matched)
      data.frame(x_from = previous$x[matched[keep]],
                 y_from = previous$y[matched[keep]],
                 x_to = current$x[keep], y_to = current$y[keep],
                 period_label = current$period_label[keep])
    })
    segments <- do.call(rbind, pieces)
    if (!is.null(segments) && nrow(segments) > 0L) {
      graph <- graph + ggplot2::geom_segment(
        data = segments,
        mapping = ggplot2::aes(x = x_from, y = y_from, xend = x_to, yend = y_to,
                               color = period_label),
        inherit.aes = FALSE, linewidth = 0.4, alpha = 0.55,
        arrow = grid::arrow(length = grid::unit(0.075, "inches"), type = "closed"),
        show.legend = FALSE
      )
    }
  }
  graph <- graph + ggplot2::geom_point(
    ggplot2::aes(color = period_label, shape = period_label),
    size = 2.2, alpha = 0.85
  )
  if (labels) {
    latest <- positions[order(positions$period_index, decreasing = TRUE), ,
                        drop = FALSE]
    latest <- latest[!duplicated(latest$entity), , drop = FALSE]
    graph <- graph + ggplot2::geom_text(
      data = latest, mapping = ggplot2::aes(label = entity),
      size = 3, vjust = -0.7, check_overlap = TRUE, color = "#333333"
    )
  }
  graph +
    ggplot2::scale_color_manual(values = palette, drop = FALSE) +
    ggplot2::scale_shape_manual(values = shapes, drop = FALSE) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = if (aligned) "Aligned positions and observed movement" else
        "Unaligned positions in separate coordinate systems",
      subtitle = if (aligned) "Movement is relative to the fitted reference frame" else
        "Differences include arbitrary coordinate transformations",
      x = "Coordinate 1", y = "Coordinate 2", color = "Period", shape = "Period"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "#EBECEF", linewidth = 0.3),
      legend.position = "top", plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.background = ggplot2::element_rect(fill = "white", color = NA)
    )
}

#' @rdname plot_drift_map
#' @param x A `driftmap` object.
#' @param ... Arguments passed to [plot_drift_map()].
#' @export
plot.driftmap <- function(x, ...) {
  plot_drift_map(x, ...)
}
