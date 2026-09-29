#' driftmapR: align repeated maps and measure relative movement
#'
#' Ingest user-supplied two-dimensional coordinates with [drift_data()], align
#' them with [align_snapshots()], compute descriptive movement with
#' [measure_drift()], and display the result with [plot_drift_map()]. Match
#' supplied hard cluster labels with [match_clusters()] using entity overlap.
#' Alternatively start from repeated numeric features or labeled distances
#' using [embed_snapshots()] for PCA or classical multidimensional scaling.
#'
#' Declare paired measurement units with [paired_unit_design()] and run serial
#' full-pipeline resampling with [bootstrap_drift()]. Results are conditional
#' resampling summaries; calibrated confidence regions, significance tests,
#' and cluster fitting/stability are not implemented. Movement
#' is relative to the selected alignment entities and coordinate reference.
#'
#' @keywords internal
"_PACKAGE"
