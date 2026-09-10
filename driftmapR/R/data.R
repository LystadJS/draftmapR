#' Construct a longitudinal coordinate-map object
#'
#' @param data A data frame with `entity`, `time`, and two coordinate columns.
#'   Additional columns (for example, supplied cluster labels) are retained.
#' @param periods Optional complete, ordered vector of expected time values.
#'   Every declared period must be observed. Numeric, Date, and POSIXct times
#'   are sorted by default; ordered factors use their full level order.
#'   Character times and unordered factors require explicit `periods`.
#' @param coords Character vector of exactly two coordinate column names.
#' @param original_data Optional original data retained without interpretation.
#' @param embedding_metadata List of caller-supplied embedding metadata.
#' @return An S3 `driftmap` list. `coordinates` holds canonical `entity`, `time`,
#'   `x`, `y`, and `period_index` columns. `aligned` and `transformations` are
#'   populated by [align_snapshots()]. [match_clusters()] populates `clusters`.
#'   `movement` and `bootstrap` are reserved slots, initially `NULL`; movement
#'   functions return tables without mutating the object. `diagnostics` and
#'   `settings` record the run.
#' @details Only two-dimensional maps are supported in this prototype. Missing
#'   entity observations are allowed, but missing/nonfinite coordinates are not.
#'   Without an explicit schedule, numeric gaps cannot identify a missing period:
#'   times 1 and 3 are simply two observed snapshots. Supply `periods = 1:3` to
#'   detect an entirely missing period 2. No times or coordinates are imputed.
#' @export
#' @examples
#' d <- data.frame(entity = rep(letters[1:4], 2), time = rep(1:2, each = 4),
#'                 x = rep(c(0, 2, 0, 1), 2), y = rep(c(0, 0, 2, 1), 2))
#' object <- drift_data(d)
#' print(object)
drift_data <- function(data, periods = NULL, coords = c("x", "y"),
                       original_data = NULL, embedding_metadata = list()) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    stop("`data` must be a nonempty data frame.", call. = FALSE)
  }
  if (anyDuplicated(names(data))) stop("Column names must be unique.", call. = FALSE)
  if (!is.character(coords) || length(coords) != 2L || anyNA(coords) ||
      anyDuplicated(coords) || any(coords %in% c("entity", "time", "period_index"))) {
    stop("`coords` must name exactly two distinct coordinate dimensions.", call. = FALSE)
  }
  required <- c("entity", "time", coords)
  if (!all(required %in% names(data))) {
    stop("Missing required columns: ", paste(setdiff(required, names(data)), collapse = ", "),
         ". All periods must have both coordinate dimensions.", call. = FALSE)
  }
  if ("period_index" %in% names(data) ||
      any(setdiff(c("x", "y"), coords) %in% names(data))) {
    stop("Input columns conflict with reserved canonical coordinate names.", call. = FALSE)
  }
  if (!is.list(embedding_metadata)) stop("`embedding_metadata` must be a list.", call. = FALSE)
  ids <- data$entity
  if (!(is.character(ids) || is.factor(ids) || is.numeric(ids)) || is.object(ids) && !is.factor(ids) ||
      !is.null(dim(ids)) ||
      anyNA(ids) || any(!nzchar(trimws(as.character(ids)))) ||
      (is.numeric(ids) && any(!is.finite(ids)))) {
    stop("Entity IDs must be nonmissing, nonblank character, factor, or finite numeric values.", call. = FALSE)
  }
  if (is.numeric(ids) && anyDuplicated(as.character(unique(ids)))) {
    stop("Distinct numeric entity IDs lose precision when converted to labels; supply explicit character IDs.",
         call. = FALSE)
  }
  time <- data$time
  check_time(time)
  for (nm in coords) {
    if (!is.numeric(data[[nm]]) || is.object(data[[nm]]) || !is.null(dim(data[[nm]]))) {
      stop("Coordinate columns must be numeric vectors: `", nm, "`.", call. = FALSE)
    }
    if (any(!is.finite(data[[nm]]))) {
      stop("Coordinate dimensions must contain finite values in every period: `", nm, "`.", call. = FALSE)
    }
  }
  if (is.null(periods)) {
    if (is.ordered(time)) {
      periods <- factor(levels(time), levels = levels(time), ordered = TRUE)
    } else if (is.character(time) || is.factor(time)) {
      stop("Character times and unordered factors require explicit ordered `periods`.", call. = FALSE)
    } else periods <- sort(unique(time))
  }
  check_time(periods, "periods")
  # Accept labels for factor schedules, but never silently equate dates and numbers.
  compatible <- (is.numeric(time) && !is.object(time) && is.numeric(periods) && !is.object(periods)) ||
    ((is.factor(time) || is.character(time)) && (is.factor(periods) || is.character(periods))) ||
    (inherits(time, "Date") && inherits(periods, "Date")) ||
    (inherits(time, "POSIXct") && inherits(periods, "POSIXct"))
  if (!compatible) stop("`periods` and `time` must have compatible types.", call. = FALSE)
  if (length(periods) < 2L || anyDuplicated(periods)) {
    stop("At least two unique, ordered periods are required.", call. = FALSE)
  }
  idx <- match(time, periods)
  if (anyNA(idx)) stop("Observed time values are absent from `periods`.", call. = FALSE)
  if (anyNA(match(periods, time))) {
    stop("Missing periods: every declared period must have observations.", call. = FALSE)
  }
  out <- as.data.frame(data)
  out$entity <- as.character(ids)
  names(out)[match(coords, names(out))] <- c("x", "y")
  out$period_index <- idx
  if (anyDuplicated(out[c("entity", "period_index")])) {
    stop("Duplicate entity-time observations are not allowed.", call. = FALSE)
  }
  out <- out[order(out$period_index, out$entity),
             c("entity", "time", "x", "y", "period_index",
               setdiff(names(out), c("entity", "time", "x", "y", "period_index"))), drop = FALSE]
  rownames(out) <- NULL
  object <- structure(list(coordinates = out, original_data = original_data,
                           embedding_metadata = embedding_metadata,
                           aligned = NULL, transformations = NULL, clusters = NULL,
                           movement = NULL, bootstrap = NULL,
                           diagnostics = list(),
                           settings = list(periods = periods, dimensions = 2L,
                                           input_coords = coords, schema_version = 1L)),
                      class = "driftmap")
  validate_drift_data(object)
  object
}

check_time <- function(x, name = "time") {
  supported <- (is.numeric(x) && !is.object(x)) || is.character(x) || is.factor(x) ||
    inherits(x, "Date") || inherits(x, "POSIXct")
  if (!supported || !is.null(dim(x)) || length(x) == 0L || anyNA(x) ||
      any(!nzchar(trimws(as.character(x)))) ||
      ((is.numeric(x) || inherits(x, "POSIXct") || inherits(x, "Date")) && any(!is.finite(x)))) {
    stop("`", name, "` must contain nonmissing, finite time values or nonblank labels.", call. = FALSE)
  }
}

#' Validate a driftmap object and optional alignment geometry
#'
#' @param object A `driftmap` object.
#' @param check_overlap Check matched-entity counts and identifiable two-dimensional
#'   geometry for the requested alignment. Construction alone permits sparse maps.
#' @param reference Either `"previous"` or `"first"`.
#' @param anchors Optional character vector of entity IDs used to fit alignment.
#' @param rank_tol Relative singular-value tolerance, strictly between zero and one.
#' @return The validated object, invisibly; invalid inputs raise informative errors.
#' @details Alignment requires at least three shared, noncollinear fitting entities
#'   and a full-rank cross-covariance. A sufficient count alone is not enough.
#' @export
validate_drift_data <- function(object, check_overlap = FALSE,
                                reference = c("previous", "first"),
                                anchors = NULL, rank_tol = 1e-10) {
  if (!inherits(object, "driftmap") || !is.list(object)) {
    stop("`object` must be a driftmap created by drift_data().", call. = FALSE)
  }
  z <- object$coordinates
  if (!is.data.frame(z) || nrow(z) == 0L ||
      !all(c("entity", "time", "x", "y", "period_index") %in% names(z)) ||
      !identical(object$settings$dimensions, 2L)) {
    stop("Malformed driftmap: expected a two-dimensional coordinate table.", call. = FALSE)
  }
  if (!is.character(z$entity) || anyNA(z$entity) || any(!nzchar(trimws(z$entity)))) {
    stop("Entity IDs must be nonmissing and nonblank.", call. = FALSE)
  }
  check_time(z$time)
  periods <- object$settings$periods
  check_time(periods, "periods")
  if (length(periods) < 2L || anyDuplicated(periods) || anyNA(match(periods, z$time)) ||
      anyNA(match(z$time, periods)) || !is.numeric(z$period_index) ||
      anyNA(z$period_index) || !is.null(dim(z$period_index)) ||
      !isTRUE(all.equal(z$period_index, match(z$time, periods), tolerance = 0, check.attributes = FALSE))) {
    stop("Missing periods or inconsistent period indices in driftmap.", call. = FALSE)
  }
  if (anyDuplicated(z[c("entity", "period_index")])) {
    stop("Duplicate entity-time observations are not allowed.", call. = FALSE)
  }
  if (!all(vapply(z[c("x", "y")], function(v) is.numeric(v) && !is.object(v) &&
                  is.null(dim(v)) && all(is.finite(v)), logical(1)))) {
    stop("Coordinate dimensions must be numeric and finite in every period.", call. = FALSE)
  }
  check_flag(check_overlap, "check_overlap")
  if (check_overlap) {
    reference <- match.arg(reference)
    check_alignment_args(object, anchors, rank_tol)
    for (j in seq.int(2L, length(periods))) {
      ref <- if (reference == "first") 1L else j - 1L
      pair <- alignment_pair(z[z$period_index == j, ], z[z$period_index == ref, ], anchors)
      fit_procrustes(pair$source, pair$target, FALSE, rank_tol,
                     paste0("period ", as.character(periods[j]), " vs ", as.character(periods[ref])))
    }
  }
  invisible(object)
}

check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop("`", name, "` must be TRUE or FALSE.", call. = FALSE)
  }
}

#' @export
print.driftmap <- function(x, ...) {
  validate_drift_data(x)
  cat("<driftmap> ", length(unique(x$coordinates$entity)), " entities; ",
      length(x$settings$periods), " periods; 2 dimensions\n", sep = "")
  cat(if (is.null(x$aligned)) "Status: unaligned\n" else
    paste0("Status: aligned (", x$settings$reference, "; scale = ", x$settings$scale, ")\n"))
  if (!is.null(x$clusters)) {
    cat("Cluster correspondence: ", length(unique(x$clusters$cluster_id[!is.na(x$clusters$cluster_id)])),
        " identities across periods\n", sep = "")
  }
  invisible(x)
}

#' @export
summary.driftmap <- function(object, ...) {
  validate_drift_data(object)
  list(n_entities = length(unique(object$coordinates$entity)),
       n_observations = nrow(object$coordinates), periods = object$settings$periods,
       aligned = !is.null(object$aligned), settings = object$settings,
       alignment = if (is.null(object$transformations)) NULL else
         object$transformations[c("time", "reference_time", "n_shared", "n_matched", "rss", "rmse")],
       cluster_matching = object$diagnostics$cluster_matching$periods)
}
