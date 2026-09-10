#' driftmapR: align repeated maps and measure relative movement
#'
#' Ingest user-supplied two-dimensional coordinates with [drift_data()], align
#' them with [align_snapshots()], compute descriptive movement with
#' [measure_drift()], and display the result with [plot_drift_map()]. Match
#' supplied hard cluster labels with [match_clusters()] using entity overlap.
#' Alternatively start from repeated numeric features or labeled distances
#' using [embed_snapshots()] for PCA or classical multidimensional scaling.
#'
#' The development prototype provides no bootstrap intervals, significance
#' tests, or cluster fitting. A bootstrap specification accompanies the
#' executable embedding adapters; it is not an uncertainty estimator. Movement
#' is relative to the selected alignment entities and coordinate reference.
#'
#' @keywords internal
"_PACKAGE"
