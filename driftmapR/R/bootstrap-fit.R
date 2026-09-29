# Fit one paired measurement-unit draw. The public driver validates the observed
# object and owns sampling/RNG. This function never draws random numbers and
# never returns an incomplete movement replicate as a successful observation.
fit_bootstrap_replicate <- function(object, feature_weights,
                                    preprocess = c("refit", "fixed")) {
  preprocess <- match.arg(preprocess)
  periods <- object$settings$periods
  embedding <- object$settings$embedding
  stage <- "preprocessing"
  period_index <- NA_integer_
  n_shared <- n_matched <- NA_integer_
  diagnostics <- list(embedding = vector("list", length(periods)),
                      alignment = vector("list", length(periods)), baseline = NULL)
  warnings <- data.frame(stage = character(), period_index = integer(),
                         message = character())
  fail <- function(e) {
    list(success = FALSE, movement = NULL, coordinates = NULL,
         diagnostics = diagnostics,
         failure = list(stage = stage, period_index = period_index,
                        n_shared = n_shared, n_matched = n_matched,
                        message = conditionMessage(e)), warnings = warnings)
  }
  capture_warning <- function(w) {
    warnings[nrow(warnings) + 1L, ] <<- list(stage, period_index,
                                            conditionMessage(w))
    invokeRestart("muffleWarning")
  }
  tryCatch(withCallingHandlers({
    # The ordinary adapter provides all key/schema validation and canonical row
    # order. Fixed preprocessing applies the observed scales to raw inputs,
    # avoiding a concealed refit of those nuisance estimates.
    prepared <- prepare_embedding_features(
      object$original_data, embedding$features, periods,
      if (preprocess == "refit") embedding$standardize else "none",
      if (preprocess == "refit") feature_weights else NULL
    )
    z <- prepared$object$coordinates
    keys <- c("entity", "time", "period_index")
    if (!identical(z[keys], object$coordinates[keys])) {
      stop("Refitted entity-period keys differ from the observed analysis.", call. = FALSE)
    }
    if (preprocess == "fixed") {
      weights <- check_feature_weights(feature_weights, embedding$features)
      scales <- object$embedding_metadata$preprocessing$scales
      if (!is.list(scales) || length(scales) != length(periods)) {
        stop("Observed per-period preprocessing scales are unavailable.", call. = FALSE)
      }
      for (i in seq_along(periods)) {
        period_index <- as.integer(i)
        denominator <- scales[[i]]
        if (!is.numeric(denominator) ||
            length(denominator) != length(embedding$features) ||
            !identical(names(denominator), embedding$features) ||
            any(!is.finite(denominator)) || any(denominator <= 0)) {
          stop("Observed preprocessing scales must be positive, finite, and follow feature order.",
               call. = FALSE)
        }
        prepared$inputs[[i]][, weights == 0] <- 0
        prepared$inputs[[i]] <- sweep(
          sweep(prepared$inputs[[i]], 2L, denominator, "/"),
          2L, sqrt(weights), "*"
        )
        if (any(!is.finite(prepared$inputs[[i]]))) {
          stop("Fixed preprocessing exceeded numerical range; rescale input units.", call. = FALSE)
        }
      }
    }
    stage <- "embedding"
    for (i in seq_along(periods)) {
      period_index <- as.integer(i)
      context <- paste0("bootstrap period ", as.character(periods[i]))
      input <- prepared$inputs[[i]]
      fit <- if (embedding$method == "pca") {
        fit_pca_snapshot(input, embedding$eigen_tol, context)
      } else {
        fit_cmds_snapshot(as.matrix(stats::dist(input)), embedding$negative_eigen,
                           embedding$eigen_tol, context)
      }
      diagnostics$embedding[[i]] <- list(
        time = periods[i], period_index = as.integer(i),
        eigenvalues = fit$eigenvalues, diagnostics = fit$diagnostics
      )
      if (isTRUE(fit$diagnostics$boundary_tie)) {
        stop("A second/third eigenvalue boundary tie makes the bootstrap plane unidentified.",
             call. = FALSE)
      }
      z[z$period_index == i, c("x", "y")] <- fit$points
    }
    aligned <- z
    # Replicate baseline orientation must share the observed baseline frame.
    # A scale fit here would erase genuine bootstrap variation in map size.
    stage <- "baseline_alignment"
    period_index <- 1L
    source <- z[z$period_index == 1L, , drop = FALSE]
    target <- object$aligned[object$aligned$period_index == 1L, , drop = FALSE]
    pair <- alignment_pair(source, target, object$settings$anchors)
    n_shared <- as.integer(pair$n_shared)
    n_matched <- as.integer(length(pair$entities))
    fit <- fit_procrustes(pair$source, pair$target, FALSE,
                          object$settings$rank_tol, "bootstrap baseline to observed baseline")
    diagnostics$baseline <- c(fit, list(n_shared = n_shared, n_matched = n_matched,
                                       entities = pair$entities))
    aligned[aligned$period_index == 1L, c("x", "y")] <-
      apply_bootstrap_transform(source, fit)
    diagnostics$alignment[[1L]] <- transform_row(
      periods[1L], periods[1L], n_shared, n_matched, fit, pair$entities
    )
    stage <- "temporal_alignment"
    for (i in seq.int(2L, length(periods))) {
      period_index <- as.integer(i)
      reference <- if (object$settings$reference == "first") 1L else i - 1L
      source <- z[z$period_index == i, , drop = FALSE]
      target <- aligned[aligned$period_index == reference, , drop = FALSE]
      pair <- alignment_pair(source, target, object$settings$anchors)
      n_shared <- as.integer(pair$n_shared)
      n_matched <- as.integer(length(pair$entities))
      fit <- fit_procrustes(
        pair$source, pair$target, object$settings$scale, object$settings$rank_tol,
        paste0("bootstrap period ", as.character(periods[i]), " vs ",
               as.character(periods[reference]))
      )
      aligned[aligned$period_index == i, c("x", "y")] <-
        apply_bootstrap_transform(source, fit)
      diagnostics$alignment[[i]] <- transform_row(
        periods[i], periods[reference], n_shared, n_matched, fit, pair$entities
      )
    }
    stage <- "movement"
    period_index <- n_shared <- n_matched <- NA_integer_
    movement <- movement_table(aligned, length(periods))
    list(success = TRUE, movement = movement, coordinates = aligned,
         diagnostics = diagnostics, failure = NULL, warnings = warnings)
  }, warning = capture_warning), error = fail)
}

apply_bootstrap_transform <- function(source, fit) {
  centered <- sweep(as.matrix(source[c("x", "y")]), 2L, fit$source_center, "-")
  points <- sweep(fit$scale * (centered %*% fit$rotation),
                  2L, fit$target_center, "+")
  if (any(!is.finite(points))) {
    stop("Nonfinite bootstrap coordinates after alignment; rescale input units.", call. = FALSE)
  }
  points
}
