# Mechanical Study 05 checkpoint validation. No fitting, resampling, covariance
# repair, outcome filtering, or tolerance adaptation occurs in this file.

study05_validate_result <- function(result, tolerance = 1e-9) {
  if (!is.list(result) || !is.list(result$frame))
    stop('Study05 validation requires both estimator frames.', call. = FALSE)
  checks <- 0L
  check <- function(ok, label) {
    checks <<- checks + 1L
    if (!isTRUE(ok)) stop('Study05 checkpoint validation: ', label, call. = FALSE)
  }
  equal <- function(a, b, label, tol = tolerance) check(isTRUE(all.equal(
    a, b, tolerance = tol, check.attributes = FALSE)), label)
  # Added study metadata must not weaken the independent inherited numerical
  # reconstruction. Validate the complete inherited numerical schema exactly.
  inherited <- result
  for (which in c('core', 'frame')) {
    x <- if (which == 'core') inherited else inherited$frame
    template <- study03_tables(x)
    for (name in names(template)) {
      check(all(names(template[[name]]) %in% names(x[[name]])),
        paste(which, name, 'inherited numerical schema'))
      x[[name]] <- x[[name]][names(template[[name]])]
    }
    if (which == 'core') inherited <- x else inherited$frame <- x
  }
  base <- study04_validate_result(inherited, tolerance = tolerance)
  m <- as.integer(result$job$m); B <- as.integer(result$B)
  ids <- result$model_metadata$target_ids
  check(identical(ids, study05_settings()$targets), 'frozen target order')
  check(identical(as.integer(result$case$m), m), 'original unit count retained')
  check(identical(as.integer(result$case$B), B), 'case bootstrap budget retained')
  full <- isTRUE(result$full_observed_success)
  evaluation <- full && isTRUE(result$evaluation_success)
  blocked <- full && !evaluation
  flags <- c(observed_core_fit_available = full,
    evaluation_registration_available = evaluation, evaluation_only_block = blocked)
  check(all(names(flags) %in% names(result$outer)), 'computational availability schema')
  for (name in names(flags)) equal(result$outer[[name]], unname(flags[name]), name, 0)
  equal(result$observed_success, full && evaluation, 'study-evaluable observed availability', 0)
  if (blocked) {
    check(!any(result$attempts$attempted), 'evaluation-only block stops later work')
    check(!any(result$regions$delivered), 'evaluation-only block has no evaluated delivery')
  }
  for (which in c('core', 'frame')) {
    x <- if (which == 'core') result else result$frame
    r <- x$regions
    check(all(c('candidate_region_delivered', 'study_evaluable_region_delivered',
      'studentized_nondelivery_reason') %in% names(r)), paste(which, 'delivery schema'))
    equal(r$study_evaluable_region_delivered, r$delivered,
      paste(which, 'study-evaluable delivery'), 0)
    if (blocked) check(all(is.na(r$candidate_region_delivered)),
      paste(which, 'evaluation-only candidate delivery is unknown')) else
      equal(r$candidate_region_delivered, r$delivered,
        paste(which, 'known computational candidate delivery'), 0)
    check(!anyDuplicated(paste(r$entity, r$method)), paste(which, 'unique region keys'))
    j <- match(r$entity, ids); student <- r$method == 'jackknife_studentized'
    n_valid <- colSums(is.finite(x$pivots))
    reason <- study05_nondelivery(x$observed_success,
      x$observed_jackknife$all_required_success,
      x$observed_jackknife$covariance_ok[j[student]], n_valid[j[student]],
      B = B, geometry_ok = r$available[student])
    equal(r$studentized_nondelivery_reason[student], reason,
      paste(which, 'exclusive frozen first-failure reason'), 0)
    equal(r$delivered[student], reason == 'delivered',
      paste(which, 'frozen studentized gate'), 0)
    for (b in 0:B) {
      jk <- if (b == 0L) x$observed_jackknife else x$inner[[b]]
      totals <- study05_validate_ledger(jk$ledger)
      equal(totals$required_occurrences, m, paste(which, b, 'occurrence denominator'), 0)
      equal(totals$attempted_unique, jk$n_attempted_unique,
        paste(which, b, 'attempted deletion count'), 0)
      equal(totals$successful_unique, jk$n_successful_unique,
        paste(which, b, 'successful deletion count'), 0)
    }
    invalid <- !x$studentization$pivot_ok
    check(all(is.na(x$studentization$pivot[invalid])),
      paste(which, 'invalid pivots remain missing'))
    equal(x$attempts$distinct_units, rowSums(result$weights > 0L),
      paste(which, 'distinct units are diagnostics only'), 0)
    check('max_multiplicity' %in% names(x$attempts), paste(which, 'maximum multiplicity schema'))
    equal(x$attempts$max_multiplicity, apply(result$weights, 1L, max),
      paste(which, 'maximum multiplicity'), 0)
  }
  check(is.list(result$clean) && all(c('attempted', 'success', 'estimate', 'truth') %in%
    names(result$clean)), 'separate clean observed-point record')
  check(isTRUE(result$clean$attempted), 'available generated Grams trigger clean point attempt')
  check(!result$clean$success || result$clean$attempted, 'clean success requires attempt')
  check(identical(dim(result$clean$estimate), c(length(ids), 2L)), 'clean target dimensions')
  check(if (result$clean$success) all(is.finite(result$clean$estimate)) else
    all(is.na(result$clean$estimate)), 'clean estimate availability')
  equal(result$clean$truth, result$truth_clean, 'clean truth retained separately', 0)
  check(is.list(result$design_metadata), 'resampling assumptions retained')
  assumptions <- paste(unlist(result$design_metadata), collapse = ' ')
  if (result$case$rho_unit > 0) {
    check(grepl('misspecif|outside.*iid|dependence.stress', assumptions, ignore.case = TRUE),
      'dependent arm honestly labels iid misspecification')
    check(!grepl('simulation generates iid', assumptions, fixed = TRUE),
      'dependent arm contains no false iid simulation claim')
  }
  check(is.list(result$geometry) && all(c('embedding', 'registration', 'matrices') %in%
    names(result$geometry)), 'geometry and matrix archives retained')
  for (kind in c('embedding', 'registration')) {
    g <- result$geometry[[kind]]
    check(is.data.frame(g) && all(c('parent_id', 'unit_index', 'stage', 'attempted',
      'success') %in% names(g)), paste(kind, 'complete stage schema'))
    check(!anyNA(g$attempted) && !anyNA(g$success), paste(kind, 'defined status flags'))
    check(!any(g$success & !g$attempted), paste(kind, 'success requires attempt'))
    check(all(g$parent_id %in% c(-1L, 0:B)), paste(kind, 'valid parent keys'))
    check(all(g$unit_index %in% 0:m), paste(kind, 'valid deletion keys'))
    key_fields <- intersect(c('parent_id', 'unit_index', 'stage', 'period'), names(g))
    keys <- if (nrow(g)) do.call(paste, c(g[key_fields], sep = '|')) else character()
    check(!anyDuplicated(keys), paste(kind, 'unique stage keys'))
    for (b in 1:B) {
      deletions <- g$unit_index[g$parent_id == b & g$unit_index > 0L & g$attempted]
      check(!length(deletions) || all(result$weights[b, deletions] > 0L),
        paste(kind, b, 'zero multiplicity never attempted'))
    }
  }
  ge <- result$geometry$embedding; gr <- result$geometry$registration
  spectral_fields <- c('lambda1','lambda2','lambda3','gap_absolute','gap_relative1',
    'gap_relative2','projector_distance','angle_min','angle_max','rank_ok','boundary_ok','negative_ok')
  register_fields <- c('source_s1','source_s2','source_ratio','target_s1','target_s2',
    'target_ratio','cross_s1','cross_s2','cross_ratio','rss','n_matched','reflection',
    'rotation_angle','rotation_determinant','reference')
  check(all(c(spectral_fields, 'role', 'diagnostic_id', 'message', 'warnings',
    'diagnostic_success', 'diagnostic_message') %in% names(ge)),
    'complete scalar embedding diagnostics')
  check(all(c(register_fields, 'role', 'diagnostic_id', 'message', 'warnings') %in% names(gr)),
    'complete scalar registration diagnostics')
  equal(ge$diagnostic_id, seq_len(nrow(ge)), 'embedding diagnostic identities', 0)
  equal(gr$diagnostic_id, seq_len(nrow(gr)), 'registration diagnostic identities', 0)
  projector_fields <- c('projector_distance', 'angle_min', 'angle_max')
  check(all(is.finite(as.matrix(ge[ge$success, setdiff(spectral_fields, projector_fields), drop = FALSE]))),
    'successful embeddings retain finite spectral diagnostics')
  check(all(is.finite(as.matrix(gr[gr$success, setdiff(register_fields, 'reference'), drop = FALSE]))),
    'successful registrations retain finite diagnostics')
  spectrum_available <- is.finite(ge$lambda1) & is.finite(ge$lambda2) & is.finite(ge$lambda3)
  check(!anyNA(ge$diagnostic_success[spectrum_available]),
    'computed spectra retain projector diagnostic status')
  diag_ok <- spectrum_available & !is.na(ge$diagnostic_success) & ge$diagnostic_success
  diag_failed <- spectrum_available & !is.na(ge$diagnostic_success) & !ge$diagnostic_success
  check(all(is.finite(as.matrix(ge[diag_ok, projector_fields, drop = FALSE]))),
    'successful projector diagnostics finite')
  check(all(is.na(as.matrix(ge[diag_failed, projector_fields, drop = FALSE]))) &&
    all(nzchar(ge$diagnostic_message[diag_failed])),
    'failed projector diagnostics explicit and isolated from fit success')
  equal(ge$gap_absolute[spectrum_available], (ge$lambda2-ge$lambda3)[spectrum_available],
    'retained finite spectral gaps')
  nonzero <- spectrum_available & ge$lambda1 != 0
  equal(ge$gap_relative1[nonzero], ((ge$lambda2-ge$lambda3)/ge$lambda1)[nonzero],
    'retained normalized spectral gaps')
  equal(ge$rank_ok[spectrum_available], as.numeric((ge$lambda1 > 0 &
    ge$lambda2 > 1e-10*ge$lambda1)[spectrum_available]), 'spectral rank status', 0)
  equal(ge$boundary_ok[spectrum_available], as.numeric((ge$lambda2-ge$lambda3 >
    1e-10*ge$lambda1)[spectrum_available]), 'spectral boundary status', 0)
  check(all(ge$rank_ok[ge$success] == 1 & ge$boundary_ok[ge$success] == 1 &
    ge$negative_ok[ge$success] == 1), 'failed spectral gates cannot identify a fit')
  for (prefix in c('source', 'target', 'cross')) {
    s1 <- gr[[paste0(prefix, '_s1')]]; s2 <- gr[[paste0(prefix, '_s2')]]
    at <- is.finite(s1) & is.finite(s2) & s1 > 0
    equal(gr[[paste0(prefix, '_ratio')]][at], (s2/s1)[at], paste(prefix, 'conditioning ratio'))
  }
  equal(gr$reflection[gr$success], as.numeric(gr$rotation_determinant[gr$success] < 0),
    'reflection diagnostic', 0)
  check(all(abs(abs(gr$rotation_determinant[gr$success])-1) <= tolerance),
    'registration determinant has orthogonal magnitude')
  # Reconstruct the complete set of fitting calls from independent dependency
  # ledgers. Every called fit allocates both spectral and all registration
  # stage slots, including later blocked stages following an earlier failure.
  reference <- ge[ge$role == 'reference' & ge$stage == 'observed_reference', , drop = FALSE]
  check(nrow(reference) == 1L && reference$parent_id == 0L && reference$unit_index == 0L &&
    reference$attempted, 'exactly one observed reference embedding')
  calls <- list()
  append_calls <- function(parent, units) if (length(units))
    calls[[length(calls)+1L]] <<- data.frame(parent_id = parent, unit_index = units)
  if (reference$success) append_calls(0L, 0L)
  append_calls(0L, which(result$observed_jackknife$ledger$attempted))
  for (b in seq_len(B)) {
    if (result$attempts$attempted[b]) append_calls(b, 0L)
    append_calls(b, which(result$inner[[b]]$ledger$attempted))
  }
  expected_calls <- if (length(calls)) do.call(rbind, calls) else
    data.frame(parent_id = integer(), unit_index = integer())
  fit_key <- function(tab) paste(tab$parent_id, tab$unit_index, sep = '|')
  expected_keys <- fit_key(expected_calls)
  for (stage in c('embedding_period1', 'embedding_period2')) {
    actual <- ge[ge$role == 'core' & ge$stage == stage, , drop = FALSE]
    check(!anyDuplicated(fit_key(actual)) && setequal(fit_key(actual), expected_keys),
      paste(stage, 'all called core fit stages retained'))
  }
  for (stage in c('registration_baseline','alignment_temporal','oracle_registration')) {
    actual <- gr[gr$role == 'core' & gr$stage == stage, , drop = FALSE]
    check(!anyDuplicated(fit_key(actual)) && setequal(fit_key(actual), expected_keys),
      paste(stage, 'all called core fit stages retained'))
  }
  take <- function(tab, stage) {
    selected <- tab[tab$role == 'core' & tab$stage == stage, , drop = FALSE]
    selected[match(expected_keys, fit_key(selected)), , drop = FALSE]
  }
  e1 <- take(ge, 'embedding_period1'); e2 <- take(ge, 'embedding_period2')
  baseline <- take(gr, 'registration_baseline'); temporal <- take(gr, 'alignment_temporal')
  oracle <- take(gr, 'oracle_registration')
  equal(e2$attempted, e1$success, 'period2 embedding depends on period1 success', 0)
  equal(baseline$attempted, e2$success, 'baseline registration depends on period2 success', 0)
  equal(temporal$attempted, baseline$success, 'temporal alignment depends on baseline success', 0)
  if (!isTRUE(result$execution_metadata$engineering_hooks))
    check(all(e1$attempted), 'ordinary called fits attempt period1 embedding')
  core_status <- frame_status <- logical(length(expected_keys))
  for (i in seq_along(expected_keys)) {
    b <- expected_calls$parent_id[i]; u <- expected_calls$unit_index[i]
    core_status[i] <- if (u == 0L) {
      if (b == 0L) full else result$attempts$success[b]
    } else if (b == 0L) result$observed_jackknife$ledger$success[u] else result$inner[[b]]$ledger$success[u]
    frame_status[i] <- if (u == 0L) {
      if (b == 0L) result$frame$observed_diagnostic$registration_success else result$frame$attempts$success[b]
    } else if (b == 0L) result$frame$observed_jackknife$ledger$success[u] else result$frame$inner[[b]]$ledger$success[u]
  }
  equal(oracle$attempted, core_status, 'oracle registration depends on core fit success', 0)
  equal(oracle$success, frame_status, 'oracle diagnostic success matches separate frame ledger', 0)
  evaluation_rows <- gr[gr$stage == 'evaluation_registration', , drop = FALSE]
  check(nrow(evaluation_rows) == as.integer(full), 'evaluation stage exists exactly when full fit available')
  if (full) equal(evaluation_rows$success, result$evaluation_success,
    'evaluation registration diagnostic status', 0)
  for (stage in c('embedding_period1','embedding_period2'))
    check(sum(ge$role == 'clean' & ge$stage == stage & ge$parent_id == -1L & ge$unit_index == 0L) == 1L,
      paste(stage, 'clean observed point stage retained'))
  for (stage in c('registration_baseline','alignment_temporal'))
    check(sum(gr$role == 'clean' & gr$stage == stage & gr$parent_id == -1L & gr$unit_index == 0L) == 1L,
      paste(stage, 'clean observed point stage retained'))
  successful_keys <- character()
  if (full) successful_keys <- c(successful_keys, '0|0')
  successful_keys <- c(successful_keys, paste(0L, which(result$observed_jackknife$ledger$success), sep = '|'))
  for (b in seq_len(B)) {
    if (result$attempts$success[b]) successful_keys <- c(successful_keys, paste(b, 0L, sep = '|'))
    successful_keys <- c(successful_keys, paste(b, which(result$inner[[b]]$ledger$success), sep = '|'))
  }
  # paste(integer(0)) is length zero only when explicitly guarded.
  successful_keys <- successful_keys[successful_keys %in% expected_keys]
  for (tab in list(ge[ge$role == 'core', ], gr[gr$role == 'core' &
      gr$stage %in% c('registration_baseline','alignment_temporal'), ])) {
    rows <- fit_key(tab) %in% successful_keys
    check(all(tab$success[rows]), 'successful fits retain successful component stages')
  }
  if (isTRUE(result$execution_metadata$keep_inner_values)) {
    for (i in which(spectrum_available)) {
      matrix_record <- result$geometry$matrices$embedding[[as.character(ge$diagnostic_id[i])]]
      check(is.list(matrix_record) && all(c('values','vectors','projector') %in% names(matrix_record)),
        paste('audit embedding full matrix', i))
      equal(matrix_record$values[1:3], as.numeric(ge[i, c('lambda1','lambda2','lambda3')]),
        paste('audit spectrum', i))
      equal(matrix_record$projector, tcrossprod(matrix_record$vectors[, 1:2, drop = FALSE]),
        paste('audit projector', i))
    }
    for (i in which(gr$success)) {
      matrix_record <- result$geometry$matrices$registration[[as.character(gr$diagnostic_id[i])]]
      check(is.list(matrix_record) && all(c('rotation','translation','points') %in% names(matrix_record)),
        paste('audit registration full matrix', i))
      equal(crossprod(matrix_record$rotation), diag(2L), paste('audit registration orthogonality', i))
      equal(det(matrix_record$rotation), gr$rotation_determinant[i], paste('audit registration determinant', i))
    }
  }
  if (!is.null(result$audit)) check(all(result$audit$passed), 'public audits passed or prescribed boundary discrepancy classified')
  base$study05_checks <- checks
  base$checks <- base$checks + checks
  base$observed_core_fit_available <- full
  base$evaluation_only_block <- blocked
  base$clean_point_available <- result$clean$success
  base
}

study05_deletion_accounting <- function(result) {
  # The inherited function preserves all failed/warning events and separates
  # eigenfit work from diagnostic registration work. The frozen helper checks
  # every unique/occurrence conservation identity before aggregation.
  for (x in list(result, result$frame)) for (jk in c(list(x$observed_jackknife), x$inner))
    study05_validate_ledger(jk$ledger)
  study04_deletion_accounting(result)
}

study05_validate_checkpoint_set <- function(results, jobs) {
  if (!is.list(results) || !is.list(jobs) || length(results) != length(jobs))
    stop('Study05 checkpoint set must retain every planned job.', call. = FALSE)
  key <- function(x) paste(x$case_id, x$dataset_id, sep = '|')
  expected <- vapply(jobs, key, character(1L))
  actual <- vapply(results, function(x) key(x$job), character(1L))
  if (anyDuplicated(expected) || anyDuplicated(actual) || !setequal(actual, expected))
    stop('Study05 checkpoint set has duplicate, missing, or unplanned job keys.', call. = FALSE)
  for (i in seq_along(results)) if (!identical(results[[i]]$job, jobs[[match(actual[i], expected)]]))
    stop('Study05 checkpoint job or seed identity mismatch.', call. = FALSE)
  invisible(TRUE)
}
