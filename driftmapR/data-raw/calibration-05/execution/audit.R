# Independent public-adapter and physically expanded occurrence audits.
# Audit panels are predetermined dataset 1 of each cell. This module never
# generates panels, changes a scientific gate, or substitutes a failed draw.

study05_audit_assumptions <- function(case) {
  if (case$rho_unit > 0)
    'Dependence stress outside the iid contract: stationary AR(1) measurement units; iid paired-unit resampling is intentionally misspecified.' else
    'The stipulated simulation independently generates paired measurement units; each unit contains all entities and periods.'
}

study05_audit_boundary <- function(g, counts) {
  m <- sum(counts)
  any(vapply(g$X, function(X) {
    C <- tcrossprod(sweep(X, 2L, sqrt(counts), '*')) / m
    e <- eigen((C + t(C)) / 2, symmetric = TRUE, only.values = TRUE)$values
    all(is.finite(e)) && e[1L] > 0 && e[2L] > 1e-10 * e[1L] &&
      min(e) >= -1e-10 * e[1L] && e[2L] - e[3L] <= 1e-10 * e[1L]
  }, logical(1L)))
}

study05_audit_status <- function(public_ok, research_ok, boundary, attempted = TRUE) {
  if (!attempted) return('dependency_blocked')
  if (identical(isTRUE(public_ok), isTRUE(research_ok))) return('identical')
  if (public_ok && !research_ok && boundary)
    return('expected_boundary_rule_difference')
  'implementation_discrepancy'
}

study05_public_expanded_fit <- function(g, counts, reference = NULL, method = 'pca') {
  expanded <- rep(seq_along(counts), counts)
  features <- sprintf('occurrence%04d', seq_along(expanded))
  study03_capture({
    panel <- do.call(rbind, lapply(1:2, function(t) {
      X <- g$X[[t]][, expanded, drop = FALSE]; colnames(X) <- features
      data.frame(entity = g$model$ids, time = t, X, check.names = FALSE)
    }))
    object <- driftmapR::embed_snapshots(panel, features, method = method,
      periods = 1:2, standardize = 'none') |>
      driftmapR::align_snapshots(reference = 'previous', scale = FALSE,
        anchors = g$model$ids[g$model$anchors])
    vector <- if (is.null(reference)) NULL else
      study03_public_vectors(object, sqrt(sum(counts)), reference, g$model)
    list(object = object, vector = vector)
  })
}

study05_public_expanded_jackknife <- function(g, counts, reference) {
  m <- sum(counts); positive <- which(counts > 0L); k <- length(g$model$target_ids)
  values <- array(NA_real_, c(length(positive), k, 2L))
  ledger <- data.frame(unit_index = seq_along(counts), multiplicity = counts,
    attempted = counts > 0L, success = FALSE, boundary = FALSE,
    message = ifelse(counts > 0L, '', 'not_selected'), warnings = '')
  for (z in seq_along(positive)) {
    j <- positive[z]; deleted <- counts; deleted[j] <- deleted[j] - 1L
    fit <- study05_public_expanded_fit(g, deleted, reference)
    ledger$success[j] <- fit$ok; ledger$message[j] <- fit$message
    ledger$warnings[j] <- fit$warnings
    ledger$boundary[j] <- study05_audit_boundary(g, deleted)
    if (fit$ok) values[z, , ] <- fit$value$vector
  }
  complete <- all(ledger$success[positive])
  covariance <- if (complete) lapply(seq_len(k), function(j) {
    expanded <- matrix(values[, j, ], ncol = 2L)[
      rep(seq_along(positive), counts[positive]), , drop = FALSE]
    residual <- sweep(expanded, 2L, colMeans(expanded), '-')
    (m - 1) / m * crossprod(residual)
  }) else rep(list(matrix(NA_real_, 2L, 2L)), k)
  list(values = values, ledger = ledger, covariance = covariance,
    covariance_ok = vapply(covariance, function(S) study03_covariance_geometry(S)$ok, logical(1L)),
    all_required_success = complete)
}

study05_public_audit <- function(result, generated, tolerance = 1e-9) {
  g <- generated; model <- g$model; B <- result$B; m <- result$job$m
  if (!is.list(result) || !is.list(g) || !is.list(model) ||
      !identical(dim(result$weights), c(as.integer(B), as.integer(m))) ||
      any(!is.finite(result$weights)) || any(result$weights < 0 | result$weights != floor(result$weights)) ||
      any(rowSums(result$weights) != m) ||
      !identical(dim(result$streams), c(as.integer(B), 7L)) || anyNA(result$streams))
    stop('Study05 audit requires valid counts and streams for every planned draw.', call. = FALSE)
  rows <- list(); public_records <- list(); ids <- model$target_ids
  add <- function(type, b = NA_integer_, frame = 'observed_reference', unit = 0L,
      attempted = FALSE, public_ok = FALSE, research_ok = FALSE,
      classification = 'identical', vector = NULL, expected = NULL,
      covariance_diff = NA_real_, ledger_ok = TRUE, covariance_ok = NA,
      count_diff = NA_real_, streams_ok = NA, passed = TRUE, message = '', warnings = '') {
    vector_diff <- if (!is.null(vector) && !is.null(expected))
      study03_audit_difference(vector, expected) else NA_real_
    numerical_ok <- (is.na(vector_diff) || vector_diff <= tolerance) &&
      (is.na(covariance_diff) || covariance_diff <= tolerance)
    row <- data.frame(case_id = result$case$case_id, scenario = result$case$scenario,
      m = m, dataset_id = result$job$dataset_id, audit_type = type,
      estimator_frame = frame, replicate_id = b, unit_index = unit, B = B,
      n_attempted = as.integer(attempted), n_successful = as.integer(public_ok),
      public_success = public_ok, research_success = research_ok,
      classification = classification, max_vector_abs_diff = vector_diff,
      max_covariance_abs_diff = covariance_diff, max_feature_count_diff = count_diff,
      streams_identical = streams_ok, failure_ledger_identical = ledger_ok,
      covariance_status_identical = covariance_ok, tolerance = tolerance,
      passed = passed && numerical_ok && classification != 'implementation_discrepancy',
      message = message, warnings = warnings, stringsAsFactors = FALSE)
    for (j in seq_along(ids)) for (d in 1:2)
      row[[paste0('public_', c('dx_', 'dy_')[d], ids[j])]] <-
        if (is.null(vector)) NA_real_ else vector[j, d]
    rows[[length(rows) + 1L]] <<- row
  }
  design <- driftmapR::paired_unit_design(g$unit_map,
    assumptions = study05_audit_assumptions(result$case))
  plan <- getFromNamespace('bootstrap_draw_plan', 'driftmapR')(
    design, g$features, as.integer(B), result$job$bootstrap_seed)
  public_weights <- do.call(rbind, lapply(plan$draws, function(d) as.integer(d$feature_weights[g$features])))
  public_streams <- do.call(rbind, lapply(plan$draws, `[[`, 'rng_stream'))
  count_diff <- study03_audit_difference(public_weights, result$weights)
  streams_ok <- identical(unname(public_streams), unname(result$streams))
  add('all_planned_weights_streams', attempted = TRUE, public_ok = TRUE,
    research_ok = TRUE, count_diff = count_diff, streams_ok = streams_ok,
    passed = count_diff == 0 && streams_ok)
  public_records$design <- design; public_records$weights <- public_weights
  public_records$streams <- public_streams
  public <- study03_capture(list(object = driftmapR::embed_snapshots(g$data,
    g$features, method = 'pca', periods = 1:2, standardize = 'none') |>
      driftmapR::align_snapshots(reference = 'previous', scale = FALSE,
        anchors = model$ids[model$anchors])))
  boundary <- study05_audit_boundary(g, rep(1L, m))
  observed_class <- study05_audit_status(public$ok, result$full_observed_success, boundary)
  public_vector <- if (public$ok && result$observed_success)
    study03_public_vectors(public$value$object, sqrt(m), result$observed$reference, model) else NULL
  add('observed_pca', 0L, attempted = TRUE, public_ok = public$ok,
    research_ok = result$full_observed_success, classification = observed_class,
    vector = public_vector, expected = if (result$observed_success) result$point else NULL,
    ledger_ok = identical(public$ok, result$full_observed_success),
    message = public$message, warnings = public$warnings)
  mds <- study05_public_expanded_fit(g, rep(1L, m), reference = NULL, method = 'cmds')
  mds_vector <- if (mds$ok && result$observed_success)
    study03_public_vectors(mds$value$object, sqrt(m), result$observed$reference, model) else NULL
  add('observed_classical_mds', 0L, attempted = TRUE, public_ok = mds$ok,
    research_ok = result$full_observed_success,
    classification = study05_audit_status(mds$ok, result$full_observed_success, boundary),
    vector = mds_vector, expected = if (result$observed_success) result$point else NULL,
    ledger_ok = identical(mds$ok, result$full_observed_success), message = mds$message, warnings = mds$warnings)
  direct_observed <- if (public$ok) study03_capture(study03_public_vectors(
    public$value$object, sqrt(m), model$population_points[[1L]], model)) else public
  add('observed_direct_A', 0L, frame = 'population_reference', attempted = public$ok,
    public_ok = direct_observed$ok, research_ok = result$frame$observed_success,
    classification = if (result$evaluation_only_block ||
        (!result$observed_success && result$frame$observed_diagnostic$registration_success))
      'dependency_blocked' else study05_audit_status(direct_observed$ok,
        result$frame$observed_success, boundary),
    vector = if (direct_observed$ok) direct_observed$value else NULL,
    expected = if (result$frame$observed_success) result$frame$point else NULL,
    ledger_ok = identical(direct_observed$ok, result$frame$observed_success),
    message = direct_observed$message, warnings = direct_observed$warnings)
  clean_g <- g; clean_g$model$anchors <- model$clean_anchors
  clean_public <- study05_public_expanded_fit(clean_g, rep(1L, m),
    reference = model$population_points[[1L]])
  add('clean_observed_point_only', 0L, frame = 'clean_population_reference', attempted = TRUE,
    public_ok = clean_public$ok, research_ok = result$clean$success,
    classification = study05_audit_status(clean_public$ok, result$clean$success, boundary),
    vector = if (clean_public$ok) clean_public$value$vector else NULL,
    expected = if (result$clean$success) result$clean$estimate else NULL,
    ledger_ok = identical(clean_public$ok, result$clean$success),
    message = clean_public$message, warnings = clean_public$warnings)
  boot <- NULL; boot_capture <- NULL
  if (result$observed_success && public$ok) {
    boot_capture <- study03_capture(driftmapR::bootstrap_drift(public$value$object,
      design, B = as.integer(B), seed = result$job$bootstrap_seed,
      keep = 'replicates', min_success = .95)$bootstrap)
    if (!boot_capture$ok) stop('Study05 public bootstrap audit could not execute: ',
      boot_capture$message, call. = FALSE)
    boot <- boot_capture$value
    weights2 <- do.call(rbind, lapply(boot$draws, function(d) as.integer(d$feature_weights[g$features])))
    streams2 <- do.call(rbind, lapply(boot$draws, `[[`, 'rng_stream'))
    if (!identical(unname(weights2), unname(public_weights)) ||
        !identical(unname(streams2), unname(public_streams)))
      stop('Study05 public bootstrap differs from its independent draw plan.', call. = FALSE)
    baseline <- public$value$object$aligned[public$value$object$aligned$period_index == 1L, ]
    baseline <- baseline[match(model$ids, baseline$entity), ]
    rotation <- study02_register(as.matrix(baseline[c('x', 'y')]) / sqrt(m),
      result$observed$reference, model$anchors)$rotation
    public_records$attempts <- boot$attempts; public_records$warnings <- boot$warnings
    public_records$diagnostics <- boot$diagnostics
    public_records$replicates <- boot$replicates
  } else public_records$attempts <- data.frame(replicate_id = seq_len(B),
    success = FALSE, stage = 'dependency_blocked', message = 'Observed research evaluation unavailable.')
  for (b in seq_len(B)) {
    attempted <- !is.null(boot)
    public_ok <- attempted && boot$attempts$success[b]
    research_ok <- result$attempts$success[b]
    vector <- if (public_ok) {
      movement <- boot$replicates[boot$replicates$replicate_id == b, ]
      movement <- movement[match(ids, movement$entity), ]
      (as.matrix(movement[c('dx', 'dy')]) / sqrt(m)) %*% rotation
    } else NULL
    class <- study05_audit_status(public_ok, research_ok,
      study05_audit_boundary(g, result$weights[b, ]), attempted)
    add('full_bootstrap', b, attempted = attempted, public_ok = public_ok,
      research_ok = research_ok, classification = class, vector = vector,
      expected = if (research_ok) matrix(result$values[b, , ], ncol = 2L) else NULL,
      ledger_ok = identical(public_ok, research_ok),
      passed = attempted == result$attempts$attempted[b],
      message = if (attempted) boot$attempts$message[b] else 'Observed core fit or evaluation unavailable; planned slot retained.')
    # Public retained replicate coordinates allow an independent direct-A
    # registration for EVERY successful public draw, using the same features.
    direct <- if (public_ok) study03_capture({
      baseline <- boot$coordinates[boot$coordinates$replicate_id == b & boot$coordinates$period_index == 1L, ]
      baseline <- baseline[match(model$ids, baseline$entity), ]
      Q <- study02_register(as.matrix(baseline[c('x', 'y')]) / sqrt(m),
        model$population_points[[1L]], model$anchors)$rotation
      (as.matrix(movement[c('dx', 'dy')]) / sqrt(m)) %*% Q
    }) else NULL
    direct_ok <- !is.null(direct) && direct$ok
    expected_ok <- result$frame$attempts$success[b]
    parent_boundary <- class == 'expected_boundary_rule_difference'
    add('full_bootstrap_direct_A', b, frame = 'population_reference', attempted = public_ok,
      public_ok = direct_ok, research_ok = expected_ok,
      classification = if (parent_boundary && !expected_ok) 'expected_boundary_rule_difference' else
        study05_audit_status(direct_ok, expected_ok, FALSE, public_ok),
      vector = if (direct_ok) direct$value else NULL,
      expected = if (expected_ok) matrix(result$frame$values[b, , ], ncol = 2L) else NULL,
      ledger_ok = identical(direct_ok, expected_ok),
      passed = public_ok == result$frame$attempts$attempted[b] || parent_boundary,
      message = if (!is.null(direct)) direct$message else 'Core parent unavailable.')
  }
  physical_archive <- list()
  for (frame in c('observed_reference', 'population_reference')) for (b in c(0L, seq_len(min(B, 2L)))) {
    x <- if (frame == 'observed_reference') result else result$frame
    counts <- if (b == 0L) rep(1L, m) else as.integer(result$weights[b, ])
    jk <- if (b == 0L) x$observed_jackknife else x$inner[[b]]
    core_available <- if (b == 0L) result$observed_success else result$attempts$success[b]
    if (!core_available) {
      add('expanded_jackknife_parent_unavailable', b, frame,
        classification = 'dependency_blocked', ledger_ok = !any(jk$ledger$attempted),
        passed = !any(jk$ledger$attempted), message = 'Required parent unavailable; no physical deletion fits attempted.')
      next
    }
    reference <- if (frame == 'observed_reference') result$observed$reference else model$population_points[[1L]]
    expanded <- study05_public_expanded_jackknife(g, counts, reference)
    positive <- which(counts > 0L)
    classifications <- vapply(positive, function(j) study05_audit_status(
      expanded$ledger$success[j], jk$ledger$success[j], expanded$ledger$boundary[j]), character(1L))
    for (z in seq_along(positive)) {
      j <- positive[z]; common <- expanded$ledger$success[j] && jk$ledger$success[j]
      if (common && is.null(jk$values)) stop('Study05 audit deletion values were not retained.', call. = FALSE)
      add('expanded_jackknife_deletion', b, frame, j, attempted = TRUE,
        public_ok = expanded$ledger$success[j], research_ok = jk$ledger$success[j],
        classification = classifications[z],
        vector = if (expanded$ledger$success[j]) matrix(expanded$values[z, , ], ncol = 2L) else NULL,
        expected = if (common) matrix(jk$values[z, , ], ncol = 2L) else NULL,
        ledger_ok = identical(expanded$ledger$success[j], jk$ledger$success[j]),
        message = expanded$ledger$message[j], warnings = expanded$ledger$warnings[j])
    }
    ledger_ok <- identical(expanded$ledger$success, jk$ledger$success) &&
      identical(as.integer(expanded$ledger$multiplicity), as.integer(jk$ledger$multiplicity))
    cov_status <- identical(unname(expanded$covariance_ok), unname(jk$covariance_ok))
    cov_diff <- if (expanded$all_required_success && jk$all_required_success)
      max(vapply(seq_along(ids), function(j) study03_audit_difference(
        expanded$covariance[[j]], jk$covariance[[j]]), numeric(1L))) else NA_real_
    expected_difference <- any(classifications == 'expected_boundary_rule_difference') &&
      !any(classifications == 'implementation_discrepancy')
    add('expanded_jackknife_covariance', b, frame, attempted = TRUE,
      public_ok = expanded$all_required_success, research_ok = jk$all_required_success,
      classification = if (expected_difference) 'expected_boundary_rule_difference' else
        if (ledger_ok && cov_status) 'identical' else 'implementation_discrepancy',
      covariance_diff = cov_diff, ledger_ok = ledger_ok, covariance_ok = cov_status,
      passed = (ledger_ok && cov_status) || expected_difference)
    physical_archive[[paste(frame, b, sep = '|')]] <- expanded
  }
  answer <- do.call(rbind, rows); rownames(answer) <- NULL
  public_records$physical_jackknives <- physical_archive
  public_records$assumptions <- study05_audit_assumptions(result$case)
  attr(answer, 'public_records') <- public_records
  if (!all(answer$passed)) {
    failed <- answer[!answer$passed, ]
    condition <- structure(list(message = paste0('Study05 public engineering audit mismatch: ',
      paste(paste0(failed$audit_type, '[', failed$replicate_id, ':', failed$unit_index, ']'), collapse = ', ')),
      call = NULL, audit = answer), class = c('study05_audit_error', 'error', 'condition'))
    stop(condition)
  }
  answer
}
