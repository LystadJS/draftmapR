# Independent checkpoint reconstruction for the frozen study 04.
# Core checks reuse the unchanged study 03 validator. Oracle registration
# attempts have their own dependency graph: a failed oracle parent does not
# erase successfully attempted oracle registrations of core leaveouts.

study04_validate_result <- function(result, tolerance = 1e-8) {
  core_summary <- study03_validate_result(result, tolerance)
  frame <- result$frame
  checks <- 0L; retained <- 0L; reconstructed <- 0L
  check <- function(ok, label) {
    checks <<- checks + 1L
    if (!isTRUE(ok)) stop('Study04 oracle checkpoint validation: ', label, call. = FALSE)
  }
  equal <- function(a, b, label, tol = tolerance) check(isTRUE(all.equal(
    a, b, tolerance = tol, check.attributes = FALSE)), label)
  quadratic <- function(error, S) drop(crossprod(error, solve(S, error)))
  check(is.list(frame), 'oracle record retained')
  m <- result$job$m; B <- result$B; ids <- result$model_metadata$target_ids; k <- length(ids)
  equal(frame$job, result$job, 'same outer job', 0)
  equal(frame$case, result$case, 'same case', 0)
  equal(frame$B, B, 'same bootstrap budget', 0)
  equal(frame$truth, result$truth, 'same population truth', 0)
  equal(frame$Q, diag(2L), 'known population coordinates', 0)
  check(length(frame$inner) == B && nrow(frame$attempts) == B, 'all planned draw records retained')
  equal(frame$attempts$replicate_id, seq_len(B), 'draw order', 0)
  equal(frame$attempts$attempted, result$attempts$success, 'oracle attempts depend on core full success', 0)
  equal(frame$attempts$core_success, result$attempts$success, 'core parent statuses retained', 0)
  check(!any(frame$attempts$success & !frame$attempts$attempted), 'unattempted registrations cannot succeed')
  equal(frame$attempts$distinct_units, rowSums(result$weights > 0L), 'distinct selected unit counts', 0)
  equal(frame$attempts$rare_multiplicity, result$attempts$rare_multiplicity, 'rare selected unit counts', 0)
  equal(frame$observed_diagnostic$attempted, result$full_observed_success, 'observed oracle dependency', 0)
  check(!frame$observed_diagnostic$registration_success || frame$observed_diagnostic$attempted,
    'observed registration success requires an attempt')
  equal(frame$observed_diagnostic$core_observed_success, result$observed_success,
    'observed core availability recorded separately', 0)
  equal(frame$observed_success, result$observed_success && frame$observed_diagnostic$registration_success,
    'observed oracle availability requires both core evaluation and registration', 0)
  equal(frame$outer$observed_registration_attempted, frame$observed_diagnostic$attempted,
    'outer observed registration attempt flag', 0)
  equal(frame$outer$observed_registration_success, frame$observed_diagnostic$registration_success,
    'outer observed registration success flag', 0)
  check(!frame$observed_success || result$observed_success, 'oracle observed fit requires core observed fit')
  equal(frame$observed_diagnostic$success, frame$observed_success, 'observed registration status', 0)
  if (frame$observed_success) {
    equal(frame$point, result$estimate, 'observed estimates agree in population coordinates')
    equal(frame$estimate, frame$point, 'oracle estimate already in population coordinates')
    equal(frame$observed_rotation, result$Q, 'observed frame registration agrees')
  } else {
    check(all(is.na(frame$point)) && all(is.na(frame$estimate)), 'unavailable oracle point remains missing')
    check(!any(frame$regions$available | frame$regions$delivered), 'unavailable oracle point delivers no region')
  }
  for (name in c('values', 'eval_values')) check(identical(dim(frame[[name]]),
    c(as.integer(B), as.integer(k), 2L)), paste(name, 'dimensions'))
  equal(frame$eval_values, frame$values, 'oracle bootstrap vectors already in population coordinates', 0)
  check(identical(dim(frame$rotations), c(as.integer(B), 2L, 2L)), 'per-fit rotations retained')
  check(identical(dim(frame$pivots), c(as.integer(B), as.integer(k))), 'pivot dimensions')
  check(nrow(frame$studentization) == B * k, 'every target/pivot row retained')
  equal(paste(frame$studentization$replicate_id, frame$studentization$entity, sep = '|'),
    paste(rep(seq_len(B), each = k), rep(ids, B), sep = '|'), 'target/pivot order', 0)
  geometry <- function(S) {
    if (any(!is.finite(S))) return(FALSE)
    e <- eigen((S + t(S)) / 2, symmetric = TRUE, only.values = TRUE)$values
    all(is.finite(e)) && e[2L] > 0 && e[2L] / e[1L] > 1e-8
  }
  validate_jackknife <- function(jk, core, counts, label) {
    positive <- counts > 0L; ledger <- jk$ledger
    check(nrow(ledger) == m, paste(label, 'all original units retained'))
    equal(ledger$unit_index, seq_len(m), paste(label, 'unit ordering'), 0)
    equal(ledger$multiplicity, counts, paste(label, 'multiplicities'), 0)
    equal(jk$counts, counts, paste(label, 'counts'), 0)
    equal(jk$positive_units, which(positive), paste(label, 'positive units'), 0)
    equal(ledger$attempted, core$ledger$success, paste(label, 'registration attempts require successful core deletions'), 0)
    if (!is.null(ledger$core_success)) equal(ledger$core_success, core$ledger$success,
      paste(label, 'core deletion statuses'), 0)
    check(!any(ledger$success & !ledger$attempted), paste(label, 'unattempted registration success'))
    equal(jk$n_planned_unique, sum(positive), paste(label, 'required distinct deletions'), 0)
    equal(jk$n_attempted_unique, sum(ledger$attempted), paste(label, 'attempted distinct registrations'), 0)
    equal(jk$n_successful_unique, sum(ledger$success), paste(label, 'successful distinct registrations'), 0)
    equal(jk$n_required_occurrences, m, paste(label, 'required occurrences'), 0)
    equal(jk$n_successful_occurrences, sum(counts[ledger$success]), paste(label, 'successful occurrences'), 0)
    equal(jk$all_required_success, all(ledger$success[positive]), paste(label, 'no partial jackknife'), 0)
    check(length(jk$covariance) == k && length(jk$weighted_scatter) == k, paste(label, 'target covariance count'))
    if (!jk$all_required_success) {
      check(!any(jk$covariance_ok), paste(label, 'required failures invalidate covariance'))
      check(all(vapply(jk$covariance, function(S) all(is.na(S)), logical(1))), paste(label, 'no successful-only covariance'))
    }
    for (j in seq_len(k)) {
      equal(jk$covariance[[j]], (m - 1) / m * jk$weighted_scatter[[j]], paste(label, j, 'scatter normalization'))
      equal(jk$covariance_ok[j], jk$all_required_success && geometry(jk$covariance[[j]]),
        paste(label, j, 'independent covariance geometry'), 0)
    }
    if (!is.null(jk$values)) {
      retained <<- retained + 1L
      check(identical(dim(jk$values), c(sum(positive), as.integer(k), 2L)), paste(label, 'retained deletion dimensions'))
      for (z in seq_along(which(positive))) {
        success <- ledger$success[which(positive)[z]]
        check(if (success) all(is.finite(jk$values[z, , ])) else all(is.na(jk$values[z, , ])),
          paste(label, z, 'deletion values agree with availability'))
      }
      if (jk$all_required_success) for (j in seq_len(k)) {
        values <- matrix(jk$values[, j, ], ncol = 2L)
        expanded <- values[rep(seq_len(nrow(values)), counts[positive]), , drop = FALSE]
        center <- colMeans(expanded); residual <- sweep(expanded, 2L, center, '-')
        equal(jk$weighted_mean[j, ], center, paste(label, j, 'expanded occurrence mean'))
        equal(jk$weighted_scatter[[j]], crossprod(residual), paste(label, j, 'expanded occurrence scatter'))
        equal(jk$covariance[[j]], (m - 1) / m * crossprod(residual), paste(label, j, 'expanded occurrence covariance'))
        reconstructed <<- reconstructed + nrow(expanded)
      }
    }
  }
  validate_jackknife(frame$observed_jackknife, result$observed_jackknife, rep(1L, m), 'observed')
  for (b in seq_len(B)) {
    full_ok <- frame$attempts$success[b]; jk <- frame$inner[[b]]
    validate_jackknife(jk, result$inner[[b]], as.integer(result$weights[b, ]), paste('draw', b))
    rows <- frame$studentization[((b - 1L) * k + 1L):(b * k), , drop = FALSE]
    equal(rows$attempted, rep(full_ok, k), paste('draw', b, 'studentization attempt flags'), 0)
    fields <- c(inner_required_unique = 'n_planned_unique', inner_attempted_unique = 'n_attempted_unique',
      inner_successful_unique = 'n_successful_unique', inner_required_occurrences = 'n_required_occurrences',
      inner_successful_occurrences = 'n_successful_occurrences')
    for (name in names(fields)) equal(rows[[name]], rep(jk[[fields[[name]]]], k), paste('draw', b, name), 0)
    if (full_ok) {
      Qb <- matrix(frame$rotations[b, , ], ncol = 2L)
      equal(crossprod(Qb), diag(2L), paste('draw', b, 'orthogonal per-fit registration'))
      equal(frame$values[b, , ], matrix(result$values[b, , ], ncol = 2L) %*% Qb,
        paste('draw', b, 'per-fit oracle displacement'))
      equal(frame$attempts$rotation_distance_from_observed[b], sqrt(sum((Qb - result$Q)^2)),
        paste('draw', b, 'frame distance'))
      equal(as.matrix(rows[c('dx', 'dy')]), frame$values[b, , ], paste('draw', b, 'tidy vectors'))
    } else check(all(is.na(frame$values[b, , ])) && all(is.na(frame$rotations[b, , ])),
      paste('draw', b, 'unavailable oracle vectors and rotations remain missing'))
    for (j in seq_len(k)) {
      cov_ok <- full_ok && jk$covariance_ok[j]
      equal(rows$covariance_ok[j], cov_ok, paste('draw', b, j, 'covariance availability'), 0)
      S <- if (cov_ok) jk$covariance[[j]] else matrix(NA_real_, 2L, 2L)
      equal(c(rows$var_dx[j], rows$var_dy[j], rows$cov_dx_dy[j]), c(S[1L, 1L], S[2L, 2L], S[1L, 2L]),
        paste('draw', b, j, 'tidy population covariance'))
      if (cov_ok && frame$observed_success) {
        pivot <- quadratic(frame$values[b, j, ] - frame$point[j, ], S)
        equal(rows$pivot_ok[j], is.finite(pivot), paste('draw', b, j, 'pivot validity'), 0)
        equal(c(frame$pivots[b, j], rows$pivot[j]), rep(pivot, 2L), paste('draw', b, j, 'independently reconstructed pivot'))
      } else check(!rows$pivot_ok[j] && is.na(rows$pivot[j]) && is.na(frame$pivots[b, j]),
        paste('draw', b, j, 'unavailable pivot remains missing'))
    }
  }
  rebuilt <- study03_tables(frame)
  equal(frame$regions, rebuilt$regions, 'complete oracle region reconstruction')
  equal(frame$estimates, rebuilt$estimates, 'complete oracle estimate reconstruction')
  check(nrow(frame$regions) == 5L * k && nrow(frame$estimates) == k, 'all methods and targets retained')
  for (i in which(frame$regions$available)) {
    row <- frame$regions[i, ]; j <- match(row$entity, ids)
    d <- frame$estimate[j, ]; truth <- frame$truth[j, ]
    draws <- matrix(frame$values[frame$attempts$success, j, ], ncol = 2L)
    errors <- sweep(draws, 2L, d, '-')
    if (row$method == 'bootstrap_ball') {
      cutoff <- unname(stats::quantile(sqrt(rowSums(errors^2)), .95, type = 7L))
      truth_stat <- sqrt(sum((truth - d)^2)); null_stat <- sqrt(sum(d^2))
      area <- pi * cutoff^2; radius <- cutoff
    } else {
      S <- if (grepl('^jackknife_', row$method)) frame$observed_jackknife$covariance[[j]] else stats::cov(draws)
      cutoff <- if (row$method %in% c('wald', 'jackknife_wald')) stats::qchisq(.95, 2L) else
        if (row$method == 'jackknife_studentized') unname(stats::quantile(
          frame$pivots[is.finite(frame$pivots[, j]), j], .95, type = 7L)) else
            unname(stats::quantile(vapply(seq_len(nrow(errors)), function(z) quadratic(errors[z, ], S), numeric(1)), .95, type = 7L))
      truth_stat <- quadratic(truth - d, S); null_stat <- quadratic(-d, S)
      area <- pi * cutoff * sqrt(det(S)); radius <- sqrt(cutoff)
    }
    equal(c(row$cutoff, row$radius, row$area, row$truth_statistic, row$null_statistic),
      c(cutoff, radius, area, truth_stat, null_stat), paste('region', i, 'independent oracle geometry'))
    equal(row$relaxed_covered, truth_stat <= cutoff * (1 + 1e-12), paste('region', i, 'coverage'), 0)
    equal(row$relaxed_rejects_zero, !(null_stat <= cutoff * (1 + 1e-12)), paste('region', i, 'zero exclusion'), 0)
  }
  equal(frame$outer$n_full_attempted, sum(frame$attempts$attempted), 'outer oracle registration attempt total', 0)
  equal(frame$outer$n_full_success, sum(frame$attempts$success), 'outer oracle registration success total', 0)
  for (prefix in c('required', 'attempted', 'success')) {
    field <- switch(prefix, required = 'n_planned_unique', attempted = 'n_attempted_unique', success = 'n_successful_unique')
    equal(frame$outer[[paste0('observed_jackknife_', prefix)]], frame$observed_jackknife[[field]], paste('outer observed', prefix), 0)
    equal(frame$outer[[paste0('inner_jackknife_', prefix)]], sum(vapply(frame$inner, `[[`, numeric(1), field)),
      paste('outer inner', prefix), 0)
  }
  data.frame(case_id = result$job$case_id, dataset_id = result$job$dataset_id, m = m, B = B,
    core_checks = core_summary$checks, frame_checks = checks, checks = core_summary$checks + checks,
    core_retained_jackknives = core_summary$retained_jackknives, frame_retained_jackknives = retained,
    retained_jackknives = core_summary$retained_jackknives + retained,
    expanded_occurrence_vectors_reconstructed = core_summary$expanded_occurrence_vectors_reconstructed + reconstructed,
    core_pivot_rows_checked = B * k, frame_pivot_rows_checked = B * k,
    pivot_rows_checked = 2L * B * k, status = 'passed')
}

study04_deletion_accounting <- function(result) {
  core <- study03_deletion_accounting(result)
  oracle <- study03_deletion_accounting(result$frame)
  core$events$core_success <- core$events$success
  add <- function(x, label) {
    x$summary$estimator_frame <- label
    x$events$estimator_frame <- rep(label, nrow(x$events))
    x
  }
  core <- add(core, 'observed_reference'); oracle <- add(oracle, 'population_reference')
  list(summary = study03_bind(list(core$summary, oracle$summary)),
       events = study03_bind(list(core$events, oracle$events)))
}

study04_validate_directory <- function(output_dir, workers = 8L, analysis_schema = TRUE) {
  if (length(workers) != 1L || !is.numeric(workers) || !is.finite(workers) || workers < 1L || workers != floor(workers))
    stop('workers must be a positive integer.', call. = FALSE)
  if (!file.exists(file.path(output_dir, 'execution.txt'))) stop('A completed study execution marker is required.', call. = FALSE)
  paths <- list.files(file.path(output_dir, 'checkpoints'), pattern = '\\.rds$', full.names = TRUE)
  if (!length(paths)) stop('No study04 checkpoints were found.', call. = FALSE)
  plan <- readRDS(file.path(output_dir, 'seed-plan.rds')); frozen <- readRDS(file.path(output_dir, 'frozen-design.rds'))
  key <- function(job) paste(job$case_id, job$dataset_id, sep = '|')
  plan_keys <- vapply(plan, key, character(1))
  if (anyDuplicated(plan_keys) || length(paths) != length(plan)) stop('Checkpoint count or seed-plan uniqueness failed.', call. = FALSE)
  started <- Sys.time()
  work <- function(path) {
    result <- readRDS(path); result_key <- key(result$job); index <- match(result_key, plan_keys)
    if (is.na(index) || !identical(result$job, plan[[index]]) || !identical(result$freeze, frozen))
      stop('Checkpoint job/freeze signature mismatch: ', path, call. = FALSE)
    list(key = result_key, summary = study04_validate_result(result), accounting = study04_deletion_accounting(result))
  }
  results <- if (workers == 1L) lapply(paths, work) else parallel::mclapply(paths, work,
    mc.cores = as.integer(workers), mc.set.seed = FALSE, mc.preschedule = TRUE)
  failed <- vapply(results, inherits, logical(1), 'try-error')
  if (any(failed)) stop('Checkpoint validation failed: ', paste(paths[failed], collapse = '; '), '\n',
    paste(vapply(results[failed], as.character, character(1)), collapse = '\n'), call. = FALSE)
  seen <- vapply(results, `[[`, character(1), 'key')
  if (anyDuplicated(seen) || !setequal(seen, plan_keys)) stop('Planned jobs are missing or duplicated.', call. = FALSE)
  if (analysis_schema) {
    read <- function(name) read.csv(file.path(output_dir, paste0(name, '.csv')), stringsAsFactors = FALSE)
    study03_validate_analysis(read('caseplan'), read('core/outer'), read('core/estimates'),
      read('core/regions'), read('core/attempts'), read('core/studentization'))
  }
  summary <- study03_bind(lapply(results, `[[`, 'summary'))
  write.csv(summary, file.path(output_dir, 'mechanical-validation.csv'), row.names = FALSE)
  for (kind in c('summary', 'events')) {
    table <- study03_bind(lapply(results, function(x) x$accounting[[kind]]))
    filename <- if (kind == 'summary') 'deletion-accounting.csv' else 'deletion-failures-warnings.csv'
    write.csv(table, file.path(output_dir, filename), row.names = FALSE)
  }
  writeLines(c(paste('Checkpoints:', nrow(summary)), paste('Core checks:', sum(summary$core_checks)),
    paste('Oracle checks:', sum(summary$frame_checks)), paste('Mechanical checks:', sum(summary$checks)),
    paste('Retained jackknives reconstructed:', sum(summary$retained_jackknives)),
    paste('Expanded occurrence vectors reconstructed:', sum(summary$expanded_occurrence_vectors_reconstructed)),
    paste('Pivot rows checked:', sum(summary$pivot_rows_checked)), 'Status: passed'),
    file.path(output_dir, 'mechanical-validation.txt'))
  writeLines(c(paste('workers:', workers), paste('started:', format(started, tz = 'UTC', usetz = TRUE)),
    paste('completed:', format(Sys.time(), tz = 'UTC', usetz = TRUE)), paste('checkpoints:', length(paths)),
    'Core estimator and oracle registrations are separate ledgers; their counts are not distinct eigensystem fits.'),
    file.path(output_dir, 'parallel-validation-execution.txt'))
  summary
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args)) stop('Usage: Rscript validate.R /absolute/study04-output [workers=8]')
  script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  frozen <- readRDS(file.path(source_dir, 'freeze.rds'))
  if (!identical(unname(tools::md5sum(file.path(source_dir, frozen$files))), frozen$md5))
    stop('Frozen study source changed.', call. = FALSE)
  source(file.path(source_dir, 'run.R')); study04_load(source_dir)
  study04_validate_directory(normalizePath(args[1L]),
    workers = if (length(args) >= 2L) as.integer(args[2L]) else 8L)
}
