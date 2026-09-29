# Compact full-stage accounting reconstructed from retained operational ledgers.
# Target covariance/pivot/region rows are views, not additional eigensystem fits.
# A diagnostic-frame covariance can be computed even when its full oracle parent
# is unavailable: it is counted here and remains ineligible for that parent's pivot.

study05_stage_accounting <- function(result) {
  rows <- list(); ids <- result$model_metadata$target_ids; B <- result$B
  add <- function(frame, stage, attempted, successful, required = rep(TRUE, length(attempted)),
                  weights = NULL, entity = NA_character_, method = NA_character_,
                  count_kind = 'operational_stage', definition, warning_slots = 0L) {
    if (!is.logical(attempted) || !is.logical(successful) || !is.logical(required) ||
        length(attempted) != length(successful) || length(attempted) != length(required) ||
        anyNA(attempted) || anyNA(successful) || anyNA(required) ||
        any(attempted & !required) || any(successful & !attempted))
      stop('Invalid stage accounting dependency flags: ', frame, '/', stage)
    failed <- attempted & !successful; unattempted <- required & !attempted
    out <- data.frame(case_id = result$job$case_id, dataset_id = result$job$dataset_id,
      frame = frame, stage = stage, entity = entity, method = method,
      count_kind = count_kind, planned = length(required), required = sum(required),
      not_required = sum(!required), attempted = sum(attempted), successful = sum(successful),
      failed_after_attempt = sum(failed), unattempted_required = sum(unattempted),
      required_occurrences = NA_real_, attempted_occurrences = NA_real_,
      successful_occurrences = NA_real_, failed_occurrences = NA_real_,
      unattempted_required_occurrences = NA_real_, warning_slots = warning_slots,
      definition = definition, stringsAsFactors = FALSE)
    if (!is.null(weights)) {
      if (length(weights) != length(required) || anyNA(weights) ||
          any(!is.finite(weights)) || any(weights < 0 | weights != floor(weights)) ||
          !identical(weights > 0, required)) stop('Invalid deletion multiplicities.')
      out$required_occurrences <- sum(weights[required])
      out$attempted_occurrences <- sum(weights[attempted])
      out$successful_occurrences <- sum(weights[successful])
      out$failed_occurrences <- sum(weights[failed])
      out$unattempted_required_occurrences <- sum(weights[unattempted])
    }
    rows[[length(rows) + 1L]] <<- out
  }
  warning_count <- function(x) sum(!is.na(x) & nzchar(x))
  add('core', 'observed_estimator', TRUE, isTRUE(result$full_observed_success),
    count_kind = 'full_estimator_fit', definition =
      'One observed functional attempt, including construction of the observed baseline reference; success precedes evaluation registration.',
    warning_slots = warning_count(result$warnings$observed))
  add('core', 'evaluation_registration', isTRUE(result$full_observed_success),
    isTRUE(result$full_observed_success) && isTRUE(result$evaluation_success),
    count_kind = 'registration', definition =
      'Observed R0 to population A registration; attempted only after an available core observed fit.',
    warning_slots = if (isTRUE(result$full_observed_success))
      warning_count(result$warnings$evaluation) else 0L)
  add('population_frame_oracle', 'observed_registration',
    isTRUE(result$frame$observed_diagnostic$attempted),
    isTRUE(result$frame$observed_diagnostic$registration_success),
    count_kind = 'diagnostic_registration', definition =
      'Direct-A registration of the core observed fit; independent of evaluation-only blocking and never changes core status.',
    warning_slots = warning_count(result$frame$observed_diagnostic$warnings))
  add('clean_observed_point', 'observed_estimator', isTRUE(result$clean$attempted),
    isTRUE(result$clean$success), count_kind = 'diagnostic_full_estimator_fit', definition =
      'One clean-anchor observed functional attempt from generated Grams, including panels with unavailable declared-anchor fits; no clean bootstrap or jackknife.',
    warning_slots = warning_count(result$clean$warnings))
  for (frame in c('core', 'population_frame_oracle')) {
    x <- if (frame == 'core') result else result$frame
    add(frame, 'bootstrap_full', x$attempts$attempted, x$attempts$success,
      count_kind = if (frame == 'core') 'full_estimator_fit' else 'diagnostic_registration',
      definition = if (frame == 'core')
        'All B full bootstrap slots; attempted only when the observed core estimator is study-evaluable.' else
        'All B direct-A full-fit registration slots; attempted only after the corresponding core full-fit success.',
      warning_slots = warning_count(x$attempts$warnings))
    for (stage in c('observed_deletion', 'inner_deletion')) {
      jks <- if (stage == 'observed_deletion') list(x$observed_jackknife) else x$inner
      for (jk in jks) study05_validate_ledger(jk$ledger)
      ledger <- do.call(rbind, lapply(jks, `[[`, 'ledger'))
      add(frame, stage, ledger$attempted, ledger$success,
        required = ledger$multiplicity > 0L, weights = ledger$multiplicity,
        count_kind = if (frame == 'core') 'unique_deletion_fit' else 'diagnostic_deletion_registration',
        definition = paste('Original-unit ledger slots; positive multiplicity defines a required unique operation.',
          'Occurrence columns expand that multiplicity without treating target views as additional fits.',
          'Every required deletion of an available parent continues after another deletion fails.'),
        warning_slots = warning_count(ledger$warnings))
    }
    for (j in seq_along(ids)) {
      observed_cov_attempted <- isTRUE(x$observed_jackknife$all_required_success)
      add(frame, 'observed_covariance', observed_cov_attempted,
        observed_cov_attempted && isTRUE(x$observed_jackknife$covariance_ok[j]),
        entity = ids[j], count_kind = 'target_covariance_view', definition =
          'Occurrence covariance constructed after all required observed deletions succeed; success means its unchanged SPD gate passes. Frame covariance computation is separate from full-parent availability.')
      inner_cov_attempted <- vapply(x$inner, function(jk) isTRUE(jk$all_required_success), logical(1L))
      inner_cov_success <- inner_cov_attempted & vapply(x$inner,
        function(jk) isTRUE(jk$covariance_ok[j]), logical(1L))
      add(frame, 'inner_covariance', inner_cov_attempted, inner_cov_success,
        entity = ids[j], count_kind = 'target_covariance_view', definition =
          'All B target covariance slots; attempt requires every required inner deletion. A valid direct-A deletion covariance can exist despite an unavailable direct-A full parent; it does not rescue that pivot.')
      s <- x$studentization[x$studentization$entity == ids[j], , drop = FALSE]
      if (nrow(s) != B || !identical(as.integer(s$replicate_id), seq_len(B)))
        stop('Incomplete target pivot order for accounting.')
      pivot_attempted <- s$covariance_ok & isTRUE(x$observed_success)
      add(frame, 'pivot', pivot_attempted, s$pivot_ok,
        entity = ids[j], count_kind = 'target_pivot_view', definition =
          'Quadratic attempted only with an available observed estimate, successful full parent and valid inner covariance; nonfinite or errored quadratics fail after attempt.')
      r <- x$regions[x$regions$entity == ids[j], , drop = FALSE]
      bootstrap_covariance <- r[r$method == 'wald', c('var_dx', 'var_dy', 'cov_dx_dy'), drop = FALSE]
      if (nrow(bootstrap_covariance) != 1L) stop('Missing bootstrap covariance view.')
      bootstrap_cov_attempted <- sum(x$attempts$success) >= 2L
      bootstrap_cov_success <- bootstrap_cov_attempted && all(is.finite(as.matrix(bootstrap_covariance)))
      add(frame, 'bootstrap_covariance', bootstrap_cov_attempted, bootstrap_cov_success,
        entity = ids[j], count_kind = 'target_covariance_view', definition =
          'Empirical bootstrap covariance is computed with at least two successful full-fit vectors; success here means finite components, not region delivery or SPD certification.')
      for (i in seq_len(nrow(r))) {
        method <- r$method[i]
        covariance_ready <- if (grepl('^jackknife_', method))
          observed_cov_attempted && isTRUE(x$observed_jackknife$covariance_ok[j]) else
          if (method == 'bootstrap_ball') TRUE else {
            S <- matrix(c(bootstrap_covariance$var_dx, bootstrap_covariance$cov_dx_dy,
              bootstrap_covariance$cov_dx_dy, bootstrap_covariance$var_dy), 2L)
            isTRUE(study03_covariance_geometry(S)$ok)
          }
        enough <- if (method == 'jackknife_wald') TRUE else
          if (method == 'jackknife_studentized') sum(s$pivot_ok) >= 20L else sum(x$attempts$success) >= 20L
        geometry_attempted <- isTRUE(x$observed_success) && covariance_ready && enough
        add(frame, 'region_geometry', geometry_attempted, isTRUE(r$available[i]),
          entity = ids[j], method = method, count_kind = 'target_region_view', definition =
            'Operational geometry evaluation with available observed estimate, required covariance and minimum-20 draws/pivots where applicable; the 95% fraction gate is a separate delivery decision.')
        add(frame, 'study_evaluable_delivery', TRUE, isTRUE(r$delivered[i]),
          entity = ids[j], method = method, count_kind = 'operational_decision_view', definition =
            'One delivery decision for every planned panel/target/method; unsuccessful decisions are study-operational non-deliveries, not additional failed fits.')
        known <- !is.na(r$candidate_region_delivered[i])
        add(frame, 'candidate_delivery_known', known,
          known && isTRUE(r$candidate_region_delivered[i]), entity = ids[j], method = method,
          count_kind = 'computational_availability_view', definition =
            'Attempted means candidate delivery is known; unattempted means unknown due to evaluation-only blocking. Failed-after-attempt means demonstrated non-delivery, never an unknown candidate.')
      }
    }
  }
  out <- do.call(rbind, rows); rownames(out) <- NULL
  stopifnot(all(out$planned == out$required + out$not_required),
    all(out$required == out$attempted + out$unattempted_required),
    all(out$attempted == out$successful + out$failed_after_attempt))
  occurrence <- !is.na(out$required_occurrences)
  stopifnot(all(out$required_occurrences[occurrence] ==
    out$attempted_occurrences[occurrence] + out$unattempted_required_occurrences[occurrence]),
    all(out$attempted_occurrences[occurrence] ==
    out$successful_occurrences[occurrence] + out$failed_occurrences[occurrence]))
  out
}
