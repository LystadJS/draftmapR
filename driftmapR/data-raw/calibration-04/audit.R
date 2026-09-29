# Independently expanded public PCA audits. These prescribed audits are
# engineering comparisons, never extra calibration panels or region inputs.

study04_public_expanded_fit <- function(g, counts, reference) {
  expanded <- rep(seq_along(counts), counts)
  features <- sprintf('occurrence%04d', seq_along(expanded))
  study03_capture({
    panel <- do.call(rbind, lapply(1:2, function(t) {
      X <- g$X[[t]][, expanded, drop = FALSE]; colnames(X) <- features
      data.frame(entity = g$model$ids, time = t, X, check.names = FALSE)
    }))
    object <- driftmapR::embed_snapshots(panel, features, method = 'pca',
      periods = 1:2, standardize = 'none') |>
      driftmapR::align_snapshots(reference = 'previous', scale = FALSE,
        anchors = g$model$ids[g$model$anchors])
    study03_public_vectors(object, sqrt(sum(counts)), reference, g$model)
  })
}

study04_public_audit <- function(result, g, tolerance = 1e-9) {
  core <- study03_public_audit(result, g)
  core$estimator_frame <- 'observed_reference'
  frame <- result$frame; rows <- list(); m <- result$job$m; B <- result$B
  add <- function(audit_type, replicate_id, attempted = 0L, successful = 0L,
                  vector_diff = NA_real_, covariance_diff = NA_real_,
                  ledger_ok = TRUE, covariance_ok = NA, passed = TRUE,
                  message = '', warnings = '') {
    rows[[length(rows) + 1L]] <<- data.frame(case_id = result$case$case_id,
      scenario = result$case$scenario, m = m, dataset_id = result$job$dataset_id,
      audit_type = audit_type, replicate_id = replicate_id, B = B,
      n_attempted = attempted, n_successful = successful,
      max_vector_abs_diff = vector_diff, max_covariance_abs_diff = covariance_diff,
      max_feature_count_diff = NA_real_, streams_identical = NA,
      failure_ledger_identical = ledger_ok, covariance_status_identical = covariance_ok,
      tolerance = tolerance, passed = passed, message = message, warnings = warnings,
      estimator_frame = 'population_reference', stringsAsFactors = FALSE)
  }
  population <- g$model$population_points[[1L]]
  for (b in c(0L, seq_len(min(B, 3L)))) {
    counts <- if (b == 0L) rep(1L, m) else as.integer(result$weights[b, ])
    expected <- if (b == 0L) frame$observed_jackknife else frame$inner[[b]]
    core_available <- if (b == 0L) result$observed_success else result$attempts$success[b]
    oracle_available <- if (b == 0L) frame$observed_success else frame$attempts$success[b]
    if (b > 0L && !result$observed_success) {
      # The public workflow also does not initiate bootstrap fits without its
      # observed estimate. Retain explicit rows for each prescribed audit.
      add('oracle_full_skipped', b, ledger_ok = !frame$attempts$attempted[b],
        passed = !frame$attempts$attempted[b], message = 'Observed core estimate unavailable.')
      add('oracle_expanded_jackknife_skipped', b, ledger_ok = !any(expected$ledger$attempted),
        passed = !any(expected$ledger$attempted), message = 'Core parent unavailable.')
      next
    }
    physical <- study04_public_expanded_fit(g, counts, population)
    # A direct-A public route is evaluated independently. For the frozen DGP,
    # any disagreement with the production dependency route is an audit
    # failure requiring explanation; it is not repaired by filtering draws.
    status_ok <- identical(physical$ok, oracle_available)
    vector_diff <- if (physical$ok && oracle_available) study03_audit_difference(
      physical$value, if (b == 0L) frame$point else matrix(frame$values[b, , ], ncol = 2L)) else NA_real_
    add('oracle_expanded_full', b, attempted = 1L, successful = as.integer(physical$ok),
      vector_diff = vector_diff, ledger_ok = status_ok,
      passed = status_ok && (is.na(vector_diff) || vector_diff <= tolerance),
      message = physical$message, warnings = physical$warnings)
    if (!core_available) {
      add('oracle_expanded_jackknife_skipped', b,
        ledger_ok = !any(expected$ledger$attempted), passed = !any(expected$ledger$attempted),
        message = 'Core parent unavailable; deletion registrations were not attempted.')
      next
    }
    # The direct population reference is fixed for EVERY physical leaveout.
    expanded <- study03_expanded_leaveouts(g, counts, population)
    # Public leaveout fitting includes the eigensystem and registration. The
    # oracle registration ledger counts only successful core eigensystems;
    # compare required-deletion outcomes and multiplicities, not those two
    # different meanings of attempted work.
    ledger_ok <- identical(expanded$ledger$success, expected$ledger$success) &&
      identical(expanded$ledger$multiplicity, expected$ledger$multiplicity)
    covariance_ok <- identical(unname(expanded$covariance_ok), unname(expected$covariance_ok))
    success <- expected$ledger$success[counts > 0L]
    value_diff <- if (!is.null(expected$values) && any(success)) study03_audit_difference(
      expanded$values[success, , , drop = FALSE], expected$values[success, , , drop = FALSE]) else NA_real_
    covariance_diff <- if (expanded$all_required_success && expected$all_required_success)
      max(vapply(seq_along(g$model$target_ids), function(j) study03_audit_difference(
        expanded$covariance[[j]], expected$covariance[[j]]), numeric(1))) else NA_real_
    add('oracle_expanded_jackknife', b, attempted = sum(expanded$ledger$attempted),
      successful = sum(expanded$ledger$success), vector_diff = value_diff,
      covariance_diff = covariance_diff, ledger_ok = ledger_ok, covariance_ok = covariance_ok,
      passed = ledger_ok && covariance_ok && (is.na(value_diff) || value_diff <= tolerance) &&
        (is.na(covariance_diff) || covariance_diff <= tolerance),
      message = paste(unique(expanded$ledger$message[expanded$ledger$attempted & !expanded$ledger$success]), collapse = ' | '),
      warnings = paste(unique(expanded$ledger$warnings[nzchar(expanded$ledger$warnings)]), collapse = ' | '))
  }
  answer <- study03_bind(c(list(core), rows))
  if (!all(answer$passed)) {
    failed <- answer[!answer$passed, ]
    stop('Study04 public oracle audit mismatch: ', paste(paste0(failed$audit_type, '[',
      failed$replicate_id, ']'), collapse = ', '), call. = FALSE)
  }
  answer
}
