# Engineering equivalence audits selected before the independent study.
# Public PCA vectors and physically expanded delete-one datasets are compared
# with the research Gram kernel. No audit contributes extra calibration panels.

study03_audit_difference <- function(a, b) {
  if (!identical(dim(a), dim(b)) || any(!is.finite(a)) || any(!is.finite(b))) return(Inf)
  max(abs(a - b), 0)
}

study03_public_vectors <- function(object, normalization, reference, model) {
  baseline <- object$aligned[object$aligned$period_index == 1L, ]
  baseline <- baseline[match(model$ids, baseline$entity), ]
  rotation <- study02_register(as.matrix(baseline[c("x", "y")]) / normalization,
                               reference, model$anchors)$rotation
  movement <- driftmapR::measure_drift(object)
  movement <- movement[match(model$target_ids, movement$entity), ]
  (as.matrix(movement[c("dx", "dy")]) / normalization) %*% rotation
}

study03_expanded_leaveouts <- function(g, counts, reference) {
  m <- sum(counts); model <- g$model
  positive <- which(counts > 0L)
  values <- array(NA_real_, c(length(positive), length(model$target_ids), 2L))
  ledger <- data.frame(unit_index = seq_along(counts), multiplicity = counts,
    attempted = counts > 0L, success = FALSE,
    message = ifelse(counts > 0L, "", "not_selected"), warnings = "")
  for (k in seq_along(positive)) {
    j <- positive[k]
    deleted <- counts; deleted[j] <- deleted[j] - 1L
    expanded <- rep(seq_along(counts), deleted)
    features <- sprintf("occurrence%04d", seq_along(expanded))
    fit <- study03_capture({
      panel <- do.call(rbind, lapply(1:2, function(t) {
        # Physical duplicated columns, with fresh distinct names. No feature
        # weights or research Gram fitting are used in this independent route.
        X <- g$X[[t]][, expanded, drop = FALSE]
        colnames(X) <- features
        data.frame(entity = model$ids, time = t, X, check.names = FALSE)
      }))
      object <- driftmapR::embed_snapshots(panel, features, method = "pca",
        periods = 1:2, standardize = "none") |>
        driftmapR::align_snapshots(reference = "previous", scale = FALSE,
                                   anchors = model$ids[model$anchors])
      study03_public_vectors(object, sqrt(m - 1), reference, model)
    })
    ledger$success[j] <- fit$ok
    ledger$message[j] <- fit$message
    ledger$warnings[j] <- fit$warnings
    if (fit$ok) values[k, , ] <- fit$value
  }
  all_required <- all(ledger$success[positive])
  covariance <- if (all_required) lapply(seq_along(model$target_ids), function(j) {
    # Expand the delete-one results to m OCCURRENCES and calculate the ordinary
    # unweighted jackknife, independently of the compressed covariance helper.
    expanded_values <- matrix(values[, j, ], ncol = 2L)[
      rep(seq_along(positive), counts[positive]), , drop = FALSE]
    residual <- sweep(expanded_values, 2L, colMeans(expanded_values), "-")
    (m - 1) / m * crossprod(residual)
  }) else rep(list(matrix(NA_real_, 2L, 2L)), length(model$target_ids))
  list(values = values, ledger = ledger, covariance = covariance,
       covariance_ok = vapply(covariance, function(S) study03_covariance_geometry(S)$ok, logical(1L)),
       all_required_success = all_required)
}

study03_public_audit <- function(result, g) {
  tolerance <- 1e-9
  if (!is.list(result) || !is.list(g) || !is.list(g$model)) {
    stop("Audit requires a study result and its generated panel.", call. = FALSE)
  }
  B <- result$B; m <- result$job$m; model <- g$model
  if (!is.numeric(B) || length(B) != 1L || !is.finite(B) || B < 1L || B != floor(B) ||
      !is.matrix(result$weights) || !identical(dim(result$weights), c(as.integer(B), as.integer(m))) ||
      any(!is.finite(result$weights)) || any(result$weights < 0 | result$weights != floor(result$weights)) ||
      any(rowSums(result$weights) != m) || !is.matrix(result$streams) ||
      !identical(dim(result$streams), c(as.integer(B), 7L)) || anyNA(result$streams)) {
    stop("Audit requires valid counts and complete RNG streams for every planned draw.", call. = FALSE)
  }
  rows <- list()
  add <- function(audit_type, replicate_id = NA_integer_, attempted = 0L,
                  successful = 0L, max_vector_abs_diff = NA_real_,
                  max_covariance_abs_diff = NA_real_, max_feature_count_diff = NA_real_,
                  streams_identical = NA, failure_ledger_identical = NA,
                  covariance_status_identical = NA, passed = TRUE, message = "",
                  warnings = "") {
    rows[[length(rows) + 1L]] <<- data.frame(case_id = result$case$case_id,
      scenario = result$case$scenario, m = m, dataset_id = result$job$dataset_id,
      audit_type = audit_type, replicate_id = replicate_id, B = B,
      n_attempted = attempted, n_successful = successful,
      max_vector_abs_diff = max_vector_abs_diff,
      max_covariance_abs_diff = max_covariance_abs_diff,
      max_feature_count_diff = max_feature_count_diff,
      streams_identical = streams_identical, failure_ledger_identical = failure_ledger_identical,
      covariance_status_identical = covariance_status_identical,
      tolerance = tolerance, passed = passed, message = message, warnings = warnings,
      stringsAsFactors = FALSE)
  }
  public <- study03_capture(driftmapR::embed_snapshots(g$data, g$features,
    method = "pca", periods = 1:2, standardize = "none") |>
    driftmapR::align_snapshots(reference = "previous", scale = FALSE,
                               anchors = model$ids[model$anchors]))
  status_ok <- identical(public$ok, result$full_observed_success)
  observed_diff <- if (public$ok && result$observed_success) study03_audit_difference(
    study03_public_vectors(public$value, sqrt(m), result$observed$reference, model),
    result$point) else NA_real_
  add("observed", 0L, attempted = 1L, successful = as.integer(public$ok),
      max_vector_abs_diff = observed_diff, failure_ledger_identical = status_ok,
      passed = status_ok && (is.na(observed_diff) || observed_diff <= tolerance),
      message = public$message, warnings = public$warnings)
  if (!status_ok) stop("Public observed-fit status differs from the study kernel.", call. = FALSE)
  if (!result$observed_success) {
    add("bootstrap_skipped", attempted = 0L, successful = 0L,
      failure_ledger_identical = !any(result$attempts$attempted),
      passed = !any(result$attempts$attempted),
      message = "Observed fit or evaluation registration unavailable; public bootstrap was not attempted.")
    answer <- do.call(rbind, rows)
    if (!all(answer$passed)) stop("Unavailable observed fit has inconsistent attempted-draw accounting.", call. = FALSE)
    return(answer)
  }
  design <- driftmapR::paired_unit_design(g$unit_map,
    assumptions = "Prespecified simulation audit of iid paired measurement units.")
  captured <- study03_capture(driftmapR::bootstrap_drift(public$value, design,
    B = as.integer(B), seed = result$job$bootstrap_seed,
    keep = "replicates", min_success = .95)$bootstrap)
  if (!captured$ok) stop("Public bootstrap audit could not execute: ", captured$message, call. = FALSE)
  boot <- captured$value
  public_weights <- do.call(rbind, lapply(boot$draws,
    function(d) as.integer(d$feature_weights[g$features])))
  public_streams <- do.call(rbind, lapply(boot$draws, `[[`, "rng_stream"))
  count_diff <- study03_audit_difference(public_weights, result$weights)
  streams_ok <- identical(unname(public_streams), unname(result$streams))
  ledger_ok <- identical(as.logical(boot$attempts$success), as.logical(result$attempts$success)) &&
    all(result$attempts$attempted) && nrow(boot$attempts) == B
  baseline <- public$value$aligned[public$value$aligned$period_index == 1L, ]
  baseline <- baseline[match(model$ids, baseline$entity), ]
  rotation <- study02_register(as.matrix(baseline[c("x", "y")]) / sqrt(m),
                               result$observed$reference, model$anchors)$rotation
  vector_diff <- 0
  for (b in which(boot$attempts$success)) {
    movement <- boot$replicates[boot$replicates$replicate_id == b, ]
    movement <- movement[match(model$target_ids, movement$entity), ]
    public_vector <- (as.matrix(movement[c("dx", "dy")]) / sqrt(m)) %*% rotation
    vector_diff <- max(vector_diff, study03_audit_difference(public_vector,
      matrix(result$values[b, , ], ncol = 2L)))
  }
  add("full_bootstrap", attempted = nrow(boot$attempts), successful = sum(boot$attempts$success),
    max_vector_abs_diff = vector_diff, max_feature_count_diff = count_diff,
    streams_identical = streams_ok, failure_ledger_identical = ledger_ok,
    passed = vector_diff <= tolerance && count_diff == 0 && streams_ok && ledger_ok,
    warnings = captured$warnings)
  for (b in c(0L, seq_len(min(B, 3L)))) {
    if (b > 0L && !result$attempts$success[b]) {
      add("jackknife_skipped", b, message = "Full bootstrap fit unavailable; public leaveouts were not attempted.",
        failure_ledger_identical = !any(result$inner[[b]]$ledger$attempted),
        passed = !any(result$inner[[b]]$ledger$attempted))
      next
    }
    counts <- if (b == 0L) rep(1L, m) else as.integer(result$weights[b, ])
    expected <- if (b == 0L) result$observed_jackknife else result$inner[[b]]
    expanded <- study03_expanded_leaveouts(g, counts, result$observed$reference)
    ledger_ok <- identical(expanded$ledger$attempted, expected$ledger$attempted) &&
      identical(expanded$ledger$success, expected$ledger$success) &&
      identical(expanded$ledger$multiplicity, expected$ledger$multiplicity)
    covariance_ok <- identical(unname(expanded$covariance_ok), unname(expected$covariance_ok))
    value_diff <- if (is.null(expected$values)) NA_real_ else {
      success <- expected$ledger$success[counts > 0L]
      if (any(success)) study03_audit_difference(expanded$values[success, , , drop = FALSE],
        expected$values[success, , , drop = FALSE]) else NA_real_
    }
    covariance_diff <- if (expanded$all_required_success && expected$all_required_success)
      max(vapply(seq_along(model$target_ids), function(j)
        study03_audit_difference(expanded$covariance[[j]], expected$covariance[[j]]), numeric(1L))) else NA_real_
    add("expanded_jackknife", b, attempted = sum(expanded$ledger$attempted),
      successful = sum(expanded$ledger$success), max_vector_abs_diff = value_diff,
      max_covariance_abs_diff = covariance_diff, failure_ledger_identical = ledger_ok,
      covariance_status_identical = covariance_ok,
      passed = ledger_ok && covariance_ok && (is.na(value_diff) || value_diff <= tolerance) &&
        (is.na(covariance_diff) || covariance_diff <= tolerance),
      message = paste(unique(expanded$ledger$message[expanded$ledger$attempted & !expanded$ledger$success]), collapse = " | "),
      warnings = paste(unique(expanded$ledger$warnings[nzchar(expanded$ledger$warnings)]), collapse = " | "))
  }
  answer <- do.call(rbind, rows)
  if (!all(answer$passed)) {
    failed <- answer[!answer$passed, ]
    stop("Public engineering audit mismatch: ", paste(paste0(failed$audit_type, "[", failed$replicate_id, "]"), collapse = ", "),
         ". Inspect vector, covariance, draw, and status comparisons.", call. = FALSE)
  }
  answer
}
