#' Declare a paired measurement-unit resampling design
#'
#' @param units Named character vector mapping every input feature to its
#'   measurement-unit ID. Features in the same unit form one block. All units
#'   must contain the same number of features; at least two units are required.
#' @param assumptions A nonblank statement explaining why units are exchangeable
#'   and independent, or independent/exchangeable within the supplied strata.
#'   This declaration is retained, not statistically verified by the package.
#' @param strata Optional named character vector mapping each unit ID to one
#'   stratum. Each stratum retains its original number of sampled units.
#' @return A `driftmap_bootstrap_design` list recording units, strata, the
#'   fixed-entity target, temporal pairing, and availability conditioning.
#' @details Units contain measurements across all observed entities and periods.
#'   A draw samples units once and applies their multiplicities to every period;
#'   within-unit dependence remains intact. Ordinary named covariates are not
#'   automatically exchangeable. Without a sampling model this procedure is
#'   feature-choice sensitivity analysis. Strata containing one unit are fixed.
#' @export
#' @examples
#' paired_unit_design(c(f1 = "unit1", f2 = "unit1", f3 = "unit2", f4 = "unit2"),
#'   assumptions = "Units are independently sampled repeated measurement blocks.")
paired_unit_design <- function(units, assumptions, strata = NULL) {
  valid_labels <- function(x) is.character(x) && is.null(dim(x)) &&
    length(x) > 0L && !anyNA(x) && all(nzchar(trimws(x)))
  if (!valid_labels(units) || !valid_labels(names(units)) || anyDuplicated(names(units))) {
    stop("`units` must map unique, nonblank feature names to nonblank character unit IDs.", call. = FALSE)
  }
  if (missing(assumptions) || !valid_labels(assumptions) || length(assumptions) != 1L) {
    stop("Supply an explicit, nonblank `assumptions` statement for the sampling design.", call. = FALSE)
  }
  ids <- sort(unique(units), method = "radix")
  widths <- tabulate(match(units, ids), nbins = length(ids))
  if (length(ids) < 2L || length(unique(widths)) != 1L) {
    stop("At least two equal-width measurement units are required.", call. = FALSE)
  }
  if (is.null(strata)) strata <- stats::setNames(rep("all", length(ids)), ids)
  if (!valid_labels(strata) || !valid_labels(names(strata)) ||
      anyDuplicated(names(strata)) || !setequal(names(strata), ids)) {
    stop("`strata` must map every unit ID exactly once to a nonblank stratum label.", call. = FALSE)
  }
  units <- units[order(names(units), method = "radix")]
  strata <- strata[ids]
  structure(list(type = "paired_units", units = units, strata = strata,
                 unit_width = widths[1L], n_units = length(ids),
                 assumptions = assumptions,
                 target = "fixed-entity movement over sampled measurement units",
                 dependence = "same unit multiplicities across all entities and periods",
                 conditioning = "observed entity-time availability and declared alignment anchors"),
            class = "driftmap_bootstrap_design")
}

#' Bootstrap paired measurement units through embedding and alignment
#'
#' @param object An aligned `driftmap` created by [embed_snapshots()] from
#'   original feature data using PCA or classical MDS. Observed feature weights
#'   must all be one. Coordinate-only and distance-only input are unsupported.
#' @param design A declaration created by [paired_unit_design()], covering
#'   exactly the object's original embedding features.
#' @param B Number of attempted replicates, a positive integer. Failed draws
#'   count toward `B` and are never replaced. Use a small pilot before large runs.
#' @param seed Nonnegative integer seed. Independent L'Ecuyer-CMRG streams are
#'   assigned in replicate order. Draw planning runs in one isolated R process,
#'   leaving the caller's RNG state, including cached normal values, untouched.
#' @param preprocess `"refit"` recomputes the declared preprocessing recipe;
#'   `"fixed"` uses observed scale vectors. Both refit the embedding. For this
#'   design original values and entity rows remain fixed, so these modes have
#'   equivalent centering/scaling, apart from inactive columns.
#' @param keep `"summary"` omits replicate coordinates/movement from the result;
#'   `"replicates"` retains them. Draws, streams, diagnostics, and failures are
#'   always retained. Exact quantiles currently require temporary storage of
#'   successful coordinates/movement in both modes.
#' @param probs Unique increasing probabilities in `[0, 1]` for sample quantiles.
#'   These are descriptive resampling quantiles, not confidence limits.
#' @param min_success Minimum successful fraction required for summaries, in
#'   `[0, 1]`. At least two successes are also required. Failed gates retain
#'   keys/counts with `NA` estimates and leave retained raw replicates accessible.
#' @return The input `driftmap` with its `bootstrap` slot replaced by a list:
#'   `observed`, movement `summary`, long `quantiles`, `coordinate_summary`,
#'   `attempts`, `warnings`, `draws`, per-attempt `diagnostics`, optional
#'   `replicates` and `coordinates`, `design`, `settings`, `rng`, and `provenance`.
#'   Summaries are conditional on computational success. Movement summaries
#'   include displacement covariance, SDs, and Monte Carlo SEs of replicate
#'   means (SD divided by square root of valid draws). This is not an inferential
#'   SE for the observed estimator. Coordinate summaries contain 2-D covariance.
#' @details The complete embedding is refitted separately at every period.
#'   Each replicate baseline is oriented to the observed aligned baseline using
#'   the declared anchors (or all baseline entities), without scaling. All later
#'   raw replicate maps are then aligned to that replicate's previous/first map
#'   using the observed temporal settings, including optional temporal scaling.
#'   This gives displacement vectors a common coordinate convention while
#'   retaining replicate size variation. No later map is fitted directly to its
#'   observed counterpart.
#'
#'   Rank failures, an ambiguous second/third eigenvalue boundary, or alignment
#'   failures invalidate the entire replicate, including earlier boundaries.
#'   Structured records retain the failing stage, period, available overlap and
#'   spectral diagnostics, and warning/error messages. A low failure rate alone
#'   does not prove that conditioning on successful draws is harmless.
#'
#'   The observed recipe is re-evaluated before sampling to reject incompatible
#'   retained data/settings/alignment. Coherent orthogonal changes of the
#'   observed comparison frame are permitted. Strata and unit labels have
#'   canonical sorted order. Replicate streams are independent of success/failure
#'   and a larger `B` preserves earlier draws. Seeds, streams, R/package versions,
#'   and an MD5 fingerprint of the serialized recipe are recorded; the fingerprint
#'   is a provenance aid, not a security guarantee. Numerical reproducibility
#'   across different R/BLAS versions is not guaranteed.
#'
#'   This first serial engine implements equal-width paired units from unweighted
#'   feature inputs. General data-resampler callbacks, entity-row bootstrap,
#'   cluster refitting/stability, confidence regions, significance tests, and
#'   angular inference are not implemented. A positive lower quantile of a
#'   displacement norm is not evidence of movement. See the packaged bootstrap
#'   specification for assumptions and future calibration gates.
#' @export
#' @examples
#' a <- c(-2, -1, 0, 1, 3)
#' b <- c(0, 2, -1, 1, 0)
#' d <- data.frame(entity = rep(letters[1:5], 2), time = rep(1:2, each = 5),
#'                 f1 = rep(a, 2), f2 = rep(b, 2),
#'                 f3 = rep(2 * a, 2), f4 = rep(2 * b, 2))
#' fit <- embed_snapshots(d, paste0("f", 1:4)) |> align_snapshots()
#' design <- paired_unit_design(c(f1 = "A", f2 = "A", f3 = "B", f4 = "B"),
#'   assumptions = "Illustrative independent measurement blocks; not an empirical sampling claim.")
#' result <- bootstrap_drift(fit, design, B = 4, seed = 1)
#' result$bootstrap$attempts
#' result$bootstrap$summary
bootstrap_drift <- function(object, design, B = 999L, seed = 1L,
                            preprocess = c("refit", "fixed"),
                            keep = c("summary", "replicates"),
                            probs = c(0.025, 0.5, 0.975), min_success = 0.95) {
  preprocess <- match.arg(preprocess)
  keep <- match.arg(keep)
  B <- bootstrap_integer(B, "B", minimum = 1)
  seed <- bootstrap_integer(seed, "seed", minimum = 0)
  if (!is.numeric(probs) || is.object(probs) || !is.null(dim(probs)) ||
      !length(probs) || any(!is.finite(probs)) || any(probs < 0 | probs > 1) ||
      any(diff(probs) <= 0)) {
    stop("`probs` must be unique increasing finite probabilities in [0, 1].", call. = FALSE)
  }
  if (!is.numeric(min_success) || length(min_success) != 1L ||
      !is.finite(min_success) || min_success < 0 || min_success > 1) {
    stop("`min_success` must be a finite fraction in [0, 1].", call. = FALSE)
  }
  design <- validate_bootstrap_input(object, design, preprocess)
  features <- object$embedding_metadata$feature_names
  periods <- object$settings$periods
  observed <- measure_drift(object)
  recipe_hash <- bootstrap_recipe_hash(list(
    original_features = object$original_data[c("entity", "time", features)],
    embedding = object$settings$embedding,
    preprocessing = object$embedding_metadata$preprocessing,
    alignment = object$settings[c("periods", "reference", "scale", "anchors", "rank_tol")],
    observed_frame = object$aligned[c("entity", "time", "period_index", "x", "y")],
    design = design, preprocess = preprocess))

  plan <- bootstrap_draw_plan(design, features, B, seed)
  draws <- plan$draws
  attempts <- diagnostics <- warning_rows <- vector("list", B)
  movement_rows <- coordinate_rows <- vector("list", B)
  for (i in seq_len(B)) {
    weights <- draws[[i]]$feature_weights
    fit <- tryCatch(fit_bootstrap_replicate(object, weights, preprocess),
                    error = function(e) bootstrap_internal_failure(conditionMessage(e)))
    diagnostics[[i]] <- fit$diagnostics
    warnings <- fit$warnings
    if (nrow(warnings)) {
      warnings$replicate_id <- rep.int(i, nrow(warnings))
      warning_rows[[i]] <- warnings[c("replicate_id", "stage", "period_index", "message")]
    }
    failed <- fit$failure
    index <- if (fit$success) NA_integer_ else failed$period_index
    attempts[[i]] <- data.frame(
      replicate_id = i, success = fit$success,
      stage = if (fit$success) "complete" else failed$stage,
      period_index = index, time = periods[index],
      n_shared = if (fit$success) NA_integer_ else failed$n_shared,
      n_matched = if (fit$success) NA_integer_ else failed$n_matched,
      message = if (fit$success) "" else failed$message, n_warnings = nrow(warnings))
    if (fit$success) {
      movement_rows[[i]] <- cbind(replicate_id = rep.int(i, nrow(fit$movement)), fit$movement)
      coordinate_rows[[i]] <- cbind(replicate_id = rep.int(i, nrow(fit$coordinates)),
                                    fit$coordinates[c("entity", "time", "period_index", "x", "y")])
    }
  }
  attempts <- do.call(rbind, attempts)
  rownames(attempts) <- NULL
  n_valid <- sum(attempts$success)
  movement_draws <- if (n_valid) do.call(rbind, movement_rows) else
    cbind(replicate_id = integer(), observed[FALSE, , drop = FALSE])
  coordinate_draws <- if (n_valid) do.call(rbind, coordinate_rows) else
    cbind(replicate_id = integer(), object$aligned[FALSE, c("entity", "time", "period_index", "x", "y")])
  rownames(movement_draws) <- rownames(coordinate_draws) <- NULL
  summaries <- summarize_bootstrap(observed, object$aligned, movement_draws,
                                    coordinate_draws, B, probs, min_success, n_valid)
  warning_table <- if (any(lengths(warning_rows))) do.call(rbind, warning_rows) else
    data.frame(replicate_id = integer(), stage = character(), period_index = integer(), message = character())
  rownames(warning_table) <- NULL
  object$bootstrap <- c(list(
    design = design,
    settings = list(B = B, seed = seed, preprocess = preprocess, keep = keep,
                    probs = probs, min_success = min_success, n_valid = n_valid,
                    n_failed = B - n_valid, success_rate = n_valid / B,
                    summaries_conditional_on_success = TRUE,
                    baseline_scale = FALSE, inference_calibrated = FALSE,
                    cluster_stability = FALSE),
    observed = observed), summaries,
    list(attempts = attempts, draws = draws, diagnostics = diagnostics,
         warnings = warning_table,
         replicates = if (keep == "replicates") movement_draws else NULL,
         coordinates = if (keep == "replicates") coordinate_draws else NULL,
         rng = plan$rng,
         provenance = list(recipe_hash = recipe_hash, hash_method = "MD5 of R serialization version 2",
                           R_version = R.version.string,
                           package_version = as.character(utils::packageVersion("driftmapR")))))
  if (n_valid < B) warning(B - n_valid, " of ", B,
    " bootstrap attempts failed; no draws were replaced. Inspect object$bootstrap$attempts.", call. = FALSE)
  if (n_valid < 2L || n_valid / B < min_success) warning(
    "Bootstrap summary gate failed; estimates are NA. Counts and retained replicates remain available.", call. = FALSE)
  object
}

bootstrap_integer <- function(x, name, minimum) {
  if (!is.numeric(x) || is.object(x) || !is.null(dim(x)) || length(x) != 1L ||
      !is.finite(x) || x < minimum || x > .Machine$integer.max || x != floor(x)) {
    stop("`", name, "` must be an integer between ", minimum,
         " and .Machine$integer.max.", call. = FALSE)
  }
  as.integer(x)
}

validate_bootstrap_input <- function(object, design, preprocess) {
  require_aligned(object)
  metadata <- object$embedding_metadata
  recipe <- object$settings$embedding
  if (!is.list(metadata) || !identical(metadata$input_type, "features") ||
      !is.list(recipe) || !identical(recipe$input_type, "features") ||
      !is.character(recipe$method) || length(recipe$method) != 1L ||
      !recipe$method %in% c("pca", "cmds") || !is.data.frame(object$original_data)) {
    stop("Paired-unit bootstrap requires retained original feature data from PCA/classical-MDS embed_snapshots().",
         call. = FALSE)
  }
  if (!identical(object$settings$alignment_method, "orthogonal_procrustes") ||
      !is.character(object$settings$reference) || length(object$settings$reference) != 1L ||
      !object$settings$reference %in% c("first", "previous")) {
    stop("Retain a valid align_snapshots() recipe before bootstrapping.", call. = FALSE)
  }
  check_flag(object$settings$scale, "stored alignment scale")
  check_alignment_args(object, object$settings$anchors, object$settings$rank_tol)
  if (!inherits(design, "driftmap_bootstrap_design") || !is.list(design) ||
      !identical(design$type, "paired_units")) {
    stop("`design` must be created by paired_unit_design().", call. = FALSE)
  }
  design <- paired_unit_design(design$units, design$assumptions, design$strata)
  features <- metadata$feature_names
  if (!is.character(features) || length(features) < 2L || anyNA(features) ||
      anyDuplicated(features) || !setequal(names(design$units), features) ||
      !identical(features, recipe$features) || !identical(metadata$method, recipe$method)) {
    stop("The unit mapping and retained embedding recipe must cover the same original features exactly.", call. = FALSE)
  }
  weights <- check_feature_weights(metadata$feature_weights, features)
  recipe_weights <- check_feature_weights(recipe$feature_weights, features)
  if (!identical(metadata$preprocessing$standardize, recipe$standardize)) {
    stop("Stored preprocessing policy conflicts with the embedding recipe; refit the analysis.", call. = FALSE)
  }
  if (any(weights != 1) || any(recipe_weights != 1)) {
    stop("This paired-unit engine requires observed feature weights all equal to one; weighted base estimators are deferred.",
         call. = FALSE)
  }
  # Recompute input validation and calibration before beginning any RNG scope.
  prepared <- prepare_embedding_features(object$original_data, features,
                                          object$settings$periods, recipe$standardize, weights)
  if (!identical(prepared$object$coordinates[c("entity", "time", "period_index")],
                 object$coordinates[c("entity", "time", "period_index")]) ||
      !isTRUE(all.equal(prepared$scales, metadata$preprocessing$scales, tolerance = 1e-12)) ||
      !isTRUE(all.equal(prepared$centers, metadata$preprocessing$centers, tolerance = 1e-12))) {
    stop("Original inputs or stored preprocessing no longer match the observed embedding; refit the analysis.", call. = FALSE)
  }
  baseline <- fit_bootstrap_replicate(object, weights, preprocess)
  if (!baseline$success) {
    stop("Observed recipe cannot define a valid bootstrap frame: ", baseline$failure$message, call. = FALSE)
  }
  x <- as.matrix(object$aligned[c("x", "y")])
  y <- as.matrix(baseline$coordinates[c("x", "y")])
  magnitude <- max(abs(sweep(x, 2L, colMeans(x), "-")))
  tolerance <- 1e-8 * max(magnitude, .Machine$double.xmin) +
    100 * .Machine$double.eps * max(abs(x))
  if (!identical(baseline$coordinates[c("entity", "time", "period_index")],
                 object$aligned[c("entity", "time", "period_index")]) ||
      any(abs(x - y) > tolerance)) {
    stop("The retained data/recipe do not reproduce the observed aligned coordinates; refit the analysis.", call. = FALSE)
  }
  design
}

bootstrap_internal_failure <- function(message) {
  list(success = FALSE, movement = NULL, coordinates = NULL, diagnostics = list(),
       failure = list(stage = "internal", period_index = NA_integer_,
                       n_shared = NA_integer_, n_matched = NA_integer_, message = message),
       warnings = data.frame(stage = character(), period_index = integer(), message = character()))
}

bootstrap_recipe_hash <- function(recipe) {
  path <- tempfile("driftmapR-recipe-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(recipe, path, version = 2, compress = FALSE)
  unname(tools::md5sum(path))
}
