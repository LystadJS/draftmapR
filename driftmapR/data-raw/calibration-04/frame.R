# Study-only oracle-frame diagnostic. Source the frozen study 03 helpers first.
# The candidate remains the unchanged fixed observed-reference estimator.
# Each oracle fit is equivalent to registering the complete baseline directly
# to the population baseline, then refitting the temporal alignment there.
# Orthogonal equivariance permits reuse of the already-computed eigensystems.

study04_oracle_fit <- function(fit, population_points, anchors,
                                oracle_register = study02_register) {
  registered <- oracle_register(fit$aligned1, population_points, anchors)
  Q <- registered$rotation
  if (!is.matrix(Q) || !identical(dim(Q), c(2L, 2L)) ||
      any(!is.finite(Q)) || max(abs(crossprod(Q) - diag(2L))) > 1e-8) {
    stop('Oracle registration did not return a finite orthogonal 2 by 2 rotation.')
  }
  list(displacement = fit$displacement %*% Q, rotation = Q)
}

study04_oracle_jackknife <- function(core, values, records, keep_values = TRUE) {
  positive <- core$positive_units
  ledger <- core$ledger
  ledger$core_success <- ledger$success
  ledger$attempted <- ledger$success <- FALSE
  for (i in seq_along(positive)) {
    unit <- positive[i]
    record <- records[[i]]
    if (!is.null(record)) {
      ledger$attempted[unit] <- TRUE
      ledger$success[unit] <- record$ok
      ledger$stage[unit] <- if (record$ok) 'complete' else 'oracle_registration'
      ledger$message[unit] <- record$message
      ledger$warnings[unit] <- record$warnings
    } else {
      ledger$stage[unit] <- 'core_leaveout_unavailable'
      ledger$message[unit] <- paste('Oracle registration was not attempted:', core$ledger$message[unit])
      ledger$warnings[unit] <- ''
    }
  }
  all_required <- all(ledger$success[positive])
  m <- sum(core$counts); targets <- core$target_rows
  covariance <- if (all_required) study03_jackknife_covariance(values, core$counts) else
    lapply(targets, function(x) matrix(NA_real_, 2L, 2L))
  weighted_mean <- matrix(NA_real_, length(targets), 2L)
  if (all_required) for (j in seq_along(targets)) {
    weighted_mean[j, ] <- colSums(matrix(values[, j, ], ncol = 2L) * core$counts[positive]) / m
  }
  geometry <- lapply(covariance, study03_covariance_geometry)
  covariance_ok <- vapply(geometry, `[[`, logical(1L), 'ok')
  reason <- if (all_required) vapply(geometry, `[[`, character(1L), 'reason') else
    rep('required_oracle_leaveout_failed', length(targets))
  list(covariance = covariance, covariance_ok = covariance_ok, reason = reason,
    covariance_reason = reason, geometry = geometry,
    values = if (keep_values) values else NULL,
    weighted_mean = weighted_mean, weighted_scatter = lapply(covariance, function(S) S * m / (m - 1)),
    ledger = ledger, counts = core$counts, positive_units = positive,
    n_planned_unique = length(positive), n_attempted_unique = sum(ledger$attempted),
    n_successful_unique = sum(ledger$success), n_required_occurrences = m,
    n_successful_occurrences = sum(core$counts[ledger$success]),
    all_required_success = all_required, target_rows = targets)
}

study04_one <- function(job, case, generated, B = case$B,
                        keep_inner_values = job$dataset_id <= 2L,
                        fit_fun = study03_fit, oracle_register = study02_register) {
  if (!is.function(fit_fun) || !is.function(oracle_register)) stop('Fit and oracle registration must be functions.')
  g <- generated; population <- g$model$population_points[[1L]]
  targets <- g$model$target_rows; ids <- g$model$target_ids; k <- length(targets)
  main_index <- 0L; main_records <- vector('list', B + 1L)
  jackknife_records <- vector('list', B + 1L)
  wrapped_fit <- function(C1, C2, reference_points, anchors) {
    main_index <<- main_index + 1L
    fit <- fit_fun(C1, C2, reference_points, anchors)
    main_records[[main_index]] <<- study03_capture(study04_oracle_fit(
      fit, population, anchors, oracle_register))
    fit
  }
  wrapped_jackknife <- function(X, counts, reference_points, anchors, target_rows,
                                grams = NULL, fit_fun = NULL) {
    # Deliberately call the original fit closure below, not the main wrapper:
    # a jackknife deletion must not advance the main-fit index.
    positive <- which(counts > 0L); deletion_index <- 0L
    target_names <- rownames(reference_points)[target_rows]
    if (is.null(target_names)) target_names <- as.character(target_rows)
    values <- array(NA_real_, c(length(positive), length(target_rows), 2L),
      dimnames = list(as.character(positive), target_names, c('dx', 'dy')))
    records <- vector('list', length(positive))
    deletion_fit <- function(C1, C2, reference_points, anchors) {
      deletion_index <<- deletion_index + 1L
      fit <- original_fit(C1, C2, reference_points, anchors)
      record <- study03_capture(study04_oracle_fit(fit, population, anchors, oracle_register))
      records[[deletion_index]] <<- record
      if (record$ok) values[deletion_index, , ] <<- record$value$displacement[target_rows, , drop = FALSE]
      fit
    }
    core <- study03_jackknife(X, counts, reference_points, anchors, target_rows,
                             grams = grams, fit_fun = deletion_fit)
    jackknife_records[[main_index]] <<- study04_oracle_jackknife(core, values, records,
      keep_values = main_index == 1L || keep_inner_values)
    core
  }
  original_fit <- fit_fun
  core <- study03_one(job, case, B = B, generated = g, keep_inner_values = keep_inner_values,
                       fit_fun = wrapped_fit, jackknife_fun = wrapped_jackknife)
  observed_record <- main_records[[1L]]
  observed_ok <- core$observed_success && !is.null(observed_record) && observed_record$ok
  point <- if (observed_ok) observed_record$value$displacement[targets, , drop = FALSE] else
    matrix(NA_real_, k, 2L)
  observed_jk <- jackknife_records[[1L]]
  if (is.null(observed_jk)) observed_jk <- study03_empty_jackknife(rep(1L, job$m), targets,
    'observed_unavailable', 'The core observed estimate is unavailable; oracle deletions were not attempted.')
  if (is.null(observed_jk$ledger$core_success)) observed_jk$ledger$core_success <- core$observed_jackknife$ledger$success
  values <- array(NA_real_, c(B, k, 2L)); rotations <- array(NA_real_, c(B, 2L, 2L))
  pivots <- matrix(NA_real_, B, k); inner <- vector('list', B)
  attempt_rows <- student_rows <- vector('list', B)
  for (b in seq_len(B)) {
    counts <- as.integer(core$weights[b, ]); record <- main_records[[b + 1L]]
    core_ok <- core$attempts$success[b]
    oracle_attempted <- core_ok && !is.null(record)
    oracle_ok <- oracle_attempted && record$ok
    if (oracle_ok) {
      values[b, , ] <- record$value$displacement[targets, , drop = FALSE]
      rotations[b, , ] <- record$value$rotation
    }
    message <- if (oracle_attempted) record$message else core$attempts$message[b]
    stage <- if (oracle_ok) 'complete' else if (oracle_attempted) 'oracle_registration' else
      if (core$observed_success) 'core_fit_unavailable' else 'observed_unavailable'
    Qb <- if (oracle_ok) record$value$rotation else matrix(NA_real_, 2L, 2L)
    attempt_rows[[b]] <- data.frame(case_id = case$case_id, scenario = case$scenario,
      m = job$m, dataset_id = job$dataset_id, replicate_id = b,
      attempted = oracle_attempted, success = oracle_ok, core_success = core_ok,
      stage = stage, message = message, warnings = if (oracle_attempted) record$warnings else '',
      distinct_units = sum(counts > 0L), rare_multiplicity = core$attempts$rare_multiplicity[b],
      rotation_angle = if (oracle_ok) atan2(Qb[2L, 1L], Qb[1L, 1L]) else NA_real_,
      rotation_determinant = if (oracle_ok) det(Qb) else NA_real_,
      rotation_distance_from_observed = if (oracle_ok) sqrt(sum((Qb - core$Q)^2)) else NA_real_)
    jk <- jackknife_records[[b + 1L]]
    if (is.null(jk)) jk <- study03_empty_jackknife(counts, targets, stage, message)
    if (is.null(jk$ledger$core_success)) jk$ledger$core_success <- core$inner[[b]]$ledger$success
    inner[[b]] <- jk
    rows <- vector('list', k)
    for (j in seq_len(k)) {
      cov_ok <- oracle_ok && jk$covariance_ok[j]
      pivot_record <- if (observed_ok && cov_ok) study03_capture(study03_quadratic(
        as.numeric(values[b, j, ] - point[j, ]), jk$covariance[[j]])) else NULL
      pivot_ok <- !is.null(pivot_record) && pivot_record$ok && is.finite(pivot_record$value)
      if (pivot_ok) pivots[b, j] <- pivot_record$value
      target_stage <- if (!oracle_ok) stage else if (!jk$all_required_success) 'inner_oracle_leaveout_fit' else
        if (!cov_ok) 'inner_oracle_covariance' else if (!observed_ok) 'observed_oracle_unavailable' else
          if (!pivot_ok) 'oracle_pivot' else 'complete'
      target_message <- if (!oracle_ok) message else if (!jk$all_required_success)
        'At least one required oracle deletion is unavailable; no partial jackknife covariance is formed.' else
          if (!cov_ok) jk$reason[j] else if (!observed_ok) 'Observed oracle estimate unavailable.' else
            if (!pivot_ok) if (pivot_record$ok) 'Oracle pivot is nonfinite.' else pivot_record$message else ''
      S <- if (cov_ok) jk$covariance[[j]] else matrix(NA_real_, 2L, 2L)
      rows[[j]] <- data.frame(case_id = case$case_id, scenario = case$scenario, m = job$m,
        dataset_id = job$dataset_id, replicate_id = b, entity = ids[j], attempted = oracle_ok,
        covariance_ok = cov_ok, pivot_ok = pivot_ok, pivot = pivots[b, j],
        inner_required_unique = jk$n_planned_unique, inner_attempted_unique = jk$n_attempted_unique,
        inner_successful_unique = jk$n_successful_unique,
        inner_required_occurrences = jk$n_required_occurrences,
        inner_successful_occurrences = jk$n_successful_occurrences,
        stage = target_stage, message = target_message,
        dx = values[b, j, 1L], dy = values[b, j, 2L],
        distinct_units = sum(counts > 0L), rare_multiplicity = core$attempts$rare_multiplicity[b],
        var_dx = S[1L, 1L], var_dy = S[2L, 2L], cov_dx_dy = S[1L, 2L])
    }
    student_rows[[b]] <- do.call(rbind, rows)
  }
  frame <- list(job = job, case = case, B = B, observed_success = observed_ok,
    weights = core$weights, streams = core$streams, model_metadata = core$model_metadata,
    full_observed_success = observed_ok, evaluation_success = observed_ok,
    point = point, estimate = point, truth = core$truth, Q = diag(2L),
    observed_jackknife = observed_jk, values = values, eval_values = values,
    inner = inner, pivots = pivots, attempts = do.call(rbind, attempt_rows),
    studentization = do.call(rbind, student_rows), rotations = rotations,
    observed_rotation = if (!is.null(observed_record) && observed_record$ok) observed_record$value$rotation else matrix(NA_real_, 2L, 2L),
    observed_diagnostic = list(attempted = !is.null(observed_record), success = observed_ok,
      registration_success = !is.null(observed_record) && observed_record$ok,
      core_observed_success = core$observed_success,
      stage = if (observed_ok) 'complete' else if (is.null(observed_record)) 'core_observed_unavailable' else
        if (observed_record$ok && !core$observed_success) 'core_evaluation_unavailable' else 'oracle_registration',
      message = if (is.null(observed_record) || (observed_record$ok && !core$observed_success))
        core$outer$observed_message else observed_record$message,
      warnings = if (is.null(observed_record)) '' else observed_record$warnings))
  tables <- study03_tables(frame); frame[names(tables)] <- tables
  frame$outer <- data.frame(case_id = case$case_id, scenario = case$scenario, m = job$m,
    dataset_id = job$dataset_id, B = B, observed_success = observed_ok,
    core_observed_success = core$observed_success,
    observed_registration_attempted = frame$observed_diagnostic$attempted,
    observed_registration_success = frame$observed_diagnostic$registration_success,
    observed_stage = frame$observed_diagnostic$stage, observed_message = frame$observed_diagnostic$message,
    rare_count = g$rare_count, n_full_attempted = sum(frame$attempts$attempted),
    n_full_success = sum(frame$attempts$success),
    observed_jackknife_required = observed_jk$n_planned_unique,
    observed_jackknife_attempted = observed_jk$n_attempted_unique,
    observed_jackknife_success = observed_jk$n_successful_unique,
    inner_jackknife_required = sum(vapply(inner, `[[`, numeric(1L), 'n_planned_unique')),
    inner_jackknife_attempted = sum(vapply(inner, `[[`, numeric(1L), 'n_attempted_unique')),
    inner_jackknife_success = sum(vapply(inner, `[[`, numeric(1L), 'n_successful_unique')))
  core$frame <- frame
  core
}
