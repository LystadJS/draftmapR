#!/usr/bin/env Rscript
# Mechanical reconstruction from saved checkpoint quantities. This validator
# does not generate evaluation panels, retry failed fits, or tune a cutoff.
# Leave-one vectors are retained only in declared audit checkpoints. For other
# checkpoints, scatter-to-covariance checks are accounting identities; all
# pivot and common-frame covariance reconstructions are still checked.

study03_validate_result <- function(result, tolerance = 1e-8) {
  checks <- 0L
  fail <- function(label) stop("Study03 checkpoint validation: ", label, call. = FALSE)
  check <- function(ok, label) {
    checks <<- checks + 1L
    if (!isTRUE(ok)) fail(label)
    invisible(TRUE)
  }
  equal <- function(actual, expected, label, tol = tolerance) {
    check(isTRUE(all.equal(actual, expected, tolerance = tol,
                           check.attributes = FALSE)), label)
  }
  quadratic <- function(error, covariance) {
    drop(crossprod(error, solve(covariance, error)))
  }
  job <- result$job; m <- job$m; B <- result$B
  ids <- result$model_metadata$target_ids; k <- length(ids)
  check(is.numeric(m) && length(m) == 1L && m >= 3L && m == floor(m), "unit count")
  check(is.numeric(B) && length(B) == 1L && B >= 1L && B == floor(B), "bootstrap budget")
  check(length(ids) > 0L && !anyNA(ids) && !anyDuplicated(ids), "target identifiers")
  check(identical(dim(result$weights), c(as.integer(B), as.integer(m))), "weight dimensions")
  check(all(is.finite(result$weights) & result$weights >= 0 &
              result$weights == floor(result$weights)), "nonnegative integer multiplicities")
  equal(rowSums(result$weights), rep(m, B), "planned multiplicity totals", 0)
  check(identical(dim(result$streams), c(as.integer(B), 7L)), "RNG stream dimensions")
  check(!anyNA(result$streams), "RNG streams retained")
  check(length(result$inner) == B, "all planned inner records retained")
  check(nrow(result$attempts) == B, "all full-fit attempts retained")
  equal(result$attempts$replicate_id, seq_len(B), "replicate order", 0)
  equal(result$attempts$distinct_units, rowSums(result$weights > 0), "distinct counts", 0)
  equal(result$attempts$attempted, rep(result$observed_success, B), "observed-failure attempt status", 0)
  check(!any(result$attempts$success & !result$attempts$attempted), "unattempted full fits cannot succeed")
  check(nrow(result$studentization) == B * k, "all target/pivot rows retained")
  expected_keys <- paste(rep(seq_len(B), each = k), rep(ids, B), sep = "|")
  equal(paste(result$studentization$replicate_id, result$studentization$entity, sep = "|"),
        expected_keys, "target/pivot row order", 0)
  for (name in c("values", "eval_values")) {
    check(identical(dim(result[[name]]), c(as.integer(B), as.integer(k), 2L)),
          paste(name, "dimensions"))
  }
  check(identical(dim(result$pivots), c(as.integer(B), as.integer(k))), "pivot matrix dimensions")
  if (result$observed_success) {
    equal(crossprod(result$Q), diag(2L), "evaluation rotation orthogonal")
    equal(result$point %*% result$Q, result$estimate, "point evaluation-frame rotation")
  } else {
    check(all(is.na(result$estimate)) && all(is.na(result$Q)), "undefined observed estimates remain missing")
    check(!any(result$regions$delivered | result$regions$available), "undefined observed fit delivers no regions")
  }
  retained_jackknives <- 0L; reconstructed_vectors <- 0L
  validate_jackknife <- function(jk, counts, parent_ok, label) {
    ledger <- jk$ledger; positive <- counts > 0L
    check(nrow(ledger) == m, paste(label, "complete deletion ledger"))
    equal(ledger$unit_index, seq_len(m), paste(label, "unit indices"), 0)
    equal(ledger$multiplicity, counts, paste(label, "multiplicities"), 0)
    equal(jk$counts, counts, paste(label, "stored counts"), 0)
    equal(jk$positive_units, which(positive), paste(label, "positive units"), 0)
    equal(ledger$attempted, positive & parent_ok, paste(label, "attempted flags"), 0)
    check(!any(ledger$success & !ledger$attempted), paste(label, "unattempted deletion success"))
    equal(jk$n_planned_unique, sum(positive), paste(label, "required distinct deletions"), 0)
    equal(jk$n_attempted_unique, sum(ledger$attempted), paste(label, "attempted distinct deletions"), 0)
    equal(jk$n_successful_unique, sum(ledger$success), paste(label, "successful distinct deletions"), 0)
    equal(jk$n_required_occurrences, sum(counts), paste(label, "required occurrences"), 0)
    equal(jk$n_successful_occurrences, sum(counts[ledger$success]), paste(label, "successful occurrences"), 0)
    equal(jk$all_required_success, all(ledger$success[positive]), paste(label, "complete-case jackknife condition"), 0)
    check(length(jk$covariance) == k && length(jk$weighted_scatter) == k,
          paste(label, "covariance target count"))
    if (!jk$all_required_success) {
      check(!any(jk$covariance_ok), paste(label, "failed deletion invalidates every covariance"))
      check(all(vapply(jk$covariance, function(S) all(is.na(S)), logical(1))),
            paste(label, "no covariance from successful deletions only"))
    }
    for (j in seq_len(k)) {
      equal(jk$covariance[[j]], (m - 1) / m * jk$weighted_scatter[[j]],
            paste(label, j, "scatter normalization"))
      if (jk$all_required_success) {
        S <- jk$covariance[[j]]
        eigenvalues <- eigen((S + t(S)) / 2, symmetric = TRUE, only.values = TRUE)$values
        valid <- all(is.finite(eigenvalues)) && eigenvalues[2L] > 0 &&
          eigenvalues[2L] / eigenvalues[1L] > 1e-8
        equal(jk$covariance_ok[j], valid, paste(label, j, "covariance geometry"), 0)
      }
    }
    if (!is.null(jk$values)) {
      retained_jackknives <<- retained_jackknives + 1L
      check(identical(dim(jk$values), c(sum(positive), as.integer(k), 2L)),
            paste(label, "retained deletion dimensions"))
      for (z in seq_along(which(positive))) {
        if (ledger$success[which(positive)[z]]) {
          check(all(is.finite(jk$values[z, , ])), paste(label, z, "successful deletion vectors finite"))
        } else {
          check(all(is.na(jk$values[z, , ])), paste(label, z, "failed deletion vectors missing"))
        }
      }
      if (jk$all_required_success) for (j in seq_len(k)) {
        x <- matrix(jk$values[, j, ], ncol = 2L)
        # Explicitly expand the occurrences: independent of compressed code.
        expanded <- x[rep(seq_len(nrow(x)), counts[positive]), , drop = FALSE]
        center <- colMeans(expanded)
        deviations <- sweep(expanded, 2L, center, "-")
        scatter <- crossprod(deviations)
        equal(jk$weighted_mean[j, ], center, paste(label, j, "occurrence mean"))
        equal(jk$weighted_scatter[[j]], scatter, paste(label, j, "occurrence scatter"))
        equal(jk$covariance[[j]], (m - 1) / m * scatter,
              paste(label, j, "expanded occurrence covariance"))
        reconstructed_vectors <<- reconstructed_vectors + nrow(expanded)
      }
    }
  }
  validate_jackknife(result$observed_jackknife, rep(1L, m), result$observed_success,
                      "observed")
  for (b in seq_len(B)) {
    full_ok <- result$attempts$success[b]
    jk <- result$inner[[b]]
    validate_jackknife(jk, as.integer(result$weights[b, ]), full_ok, paste("draw", b))
    rows <- result$studentization[((b - 1L) * k + 1L):(b * k), , drop = FALSE]
    equal(rows$attempted, rep(full_ok, k), paste("draw", b, "studentization attempt"), 0)
    for (field in c(required_unique = "n_planned_unique", attempted_unique = "n_attempted_unique",
                    successful_unique = "n_successful_unique", required_occurrences = "n_required_occurrences",
                    successful_occurrences = "n_successful_occurrences")) {
      prefix <- names(c(required_unique = "n_planned_unique", attempted_unique = "n_attempted_unique",
                        successful_unique = "n_successful_unique", required_occurrences = "n_required_occurrences",
                        successful_occurrences = "n_successful_occurrences"))[
                          match(field, c("n_planned_unique", "n_attempted_unique", "n_successful_unique",
                                         "n_required_occurrences", "n_successful_occurrences"))]
      equal(rows[[paste0("inner_", prefix)]], rep(jk[[field]], k),
            paste("draw", b, field, "studentization ledger"), 0)
    }
    if (full_ok) {
      raw <- matrix(result$values[b, , ], ncol = 2L)
      rotated <- raw %*% result$Q
      equal(result$eval_values[b, , ], rotated, paste("draw", b, "vector rotation"))
      equal(as.matrix(rows[c("dx", "dy")]), rotated, paste("draw", b, "tidy vectors"))
    } else {
      check(all(is.na(result$values[b, , ])) && all(is.na(result$eval_values[b, , ])),
            paste("draw", b, "failed full vectors missing"))
    }
    for (j in seq_len(k)) {
      cov_ok <- full_ok && jk$covariance_ok[j]
      equal(rows$covariance_ok[j], cov_ok, paste("draw", b, j, "covariance availability"), 0)
      if (cov_ok) {
        S <- jk$covariance[[j]]
        S_eval <- t(result$Q) %*% S %*% result$Q
        equal(c(rows$var_dx[j], rows$var_dy[j], rows$cov_dx_dy[j]),
              c(S_eval[1L, 1L], S_eval[2L, 2L], S_eval[1L, 2L]),
              paste("draw", b, j, "covariance rotation"))
        pivot <- quadratic(result$values[b, j, ] - result$point[j, ], S)
        valid <- is.finite(pivot)
        equal(rows$pivot_ok[j], valid, paste("draw", b, j, "pivot availability"), 0)
        if (valid) {
          equal(result$pivots[b, j], pivot, paste("draw", b, j, "independent pivot"))
          equal(rows$pivot[j], pivot, paste("draw", b, j, "tidy pivot"))
          equal(quadratic(result$eval_values[b, j, ] - result$estimate[j, ], S_eval),
                pivot, paste("draw", b, j, "pivot rotation invariance"))
        }
      } else {
        check(!rows$pivot_ok[j] && is.na(rows$pivot[j]) && is.na(result$pivots[b, j]),
              paste("draw", b, j, "failed studentization remains missing"))
      }
    }
  }
  rebuilt <- study03_tables(result)
  equal(result$regions, rebuilt$regions, "entire saved region table reconstruction")
  equal(result$estimates, rebuilt$estimates, "entire saved estimate table reconstruction")
  check(nrow(result$regions) == 5L * k, "all five methods retained for every target")
  check(nrow(result$estimates) == k, "all observed targets retained")
  # Independently verify geometry for every constructible candidate region.
  for (i in which(result$regions$available)) {
    row <- result$regions[i, ]; j <- match(row$entity, ids)
    d <- result$estimate[j, ]; truth <- result$truth[j, ]
    draws <- matrix(result$eval_values[result$attempts$success, j, ], ncol = 2L)
    errors <- sweep(draws, 2L, d, "-")
    if (row$method == "bootstrap_ball") {
      cutoff <- unname(stats::quantile(sqrt(rowSums(errors^2)), .95, type = 7L))
      truth_stat <- sqrt(sum((truth - d)^2)); null_stat <- sqrt(sum(d^2))
      area <- pi * cutoff^2; radius <- cutoff
    } else {
      S <- if (grepl("^jackknife_", row$method))
        t(result$Q) %*% result$observed_jackknife$covariance[[j]] %*% result$Q else stats::cov(draws)
      cutoff <- if (row$method %in% c("wald", "jackknife_wald")) stats::qchisq(.95, 2L) else
        if (row$method == "jackknife_studentized") unname(stats::quantile(
          result$pivots[is.finite(result$pivots[, j]), j], .95, type = 7L)) else
            unname(stats::quantile(vapply(seq_len(nrow(errors)), function(z)
              quadratic(errors[z, ], S), numeric(1)), .95, type = 7L))
      truth_stat <- quadratic(truth - d, S); null_stat <- quadratic(-d, S)
      area <- pi * cutoff * sqrt(det(S)); radius <- sqrt(cutoff)
    }
    equal(c(row$cutoff, row$radius, row$area, row$truth_statistic, row$null_statistic),
          c(cutoff, radius, area, truth_stat, null_stat), paste("region", i, "independent geometry"))
    equal(row$relaxed_covered, truth_stat <= cutoff * (1 + 1e-12), paste("region", i, "truth coverage"), 0)
    equal(row$relaxed_rejects_zero, !(null_stat <= cutoff * (1 + 1e-12)),
          paste("region", i, "zero exclusion"), 0)
    if (!row$delivered) check(is.na(row$covered) && is.na(row$rejects_zero),
                              paste("region", i, "gated primary outcomes missing"))
  }
  outer <- result$outer
  equal(outer$n_full_attempted, sum(result$attempts$attempted), "outer attempted total", 0)
  equal(outer$n_full_success, sum(result$attempts$success), "outer successful total", 0)
  for (prefix in c("required", "attempted", "success")) {
    field <- switch(prefix, required = "n_planned_unique", attempted = "n_attempted_unique",
                    success = "n_successful_unique")
    equal(outer[[paste0("observed_jackknife_", prefix)]], result$observed_jackknife[[field]],
          paste("outer observed", prefix), 0)
    equal(outer[[paste0("inner_jackknife_", prefix)]],
          sum(vapply(result$inner, `[[`, numeric(1), field)), paste("outer inner", prefix), 0)
  }
  data.frame(case_id = job$case_id, dataset_id = job$dataset_id, m = m, B = B,
             checks = checks, retained_jackknives = retained_jackknives,
             expanded_occurrence_vectors_reconstructed = reconstructed_vectors,
             pivot_rows_checked = B * k, status = "passed")
}

study03_deletion_accounting <- function(result) {
  metadata <- data.frame(case_id = result$job$case_id, scenario = result$case$scenario,
                         m = result$job$m, dataset_id = result$job$dataset_id)
  ledger_metrics <- function(ledger) {
    required <- ledger$multiplicity > 0L
    attempted <- ledger$attempted
    succeeded <- ledger$success
    failed <- attempted & !succeeded
    unattempted <- required & !attempted
    c(required_unique = sum(required), attempted_unique = sum(attempted),
      successful_unique = sum(succeeded), failed_unique = sum(failed),
      unattempted_required_unique = sum(unattempted), unselected_unique = sum(!required),
      required_occurrences = sum(ledger$multiplicity[required]),
      attempted_occurrences = sum(ledger$multiplicity[attempted]),
      successful_occurrences = sum(ledger$multiplicity[succeeded]),
      failed_occurrences = sum(ledger$multiplicity[failed]),
      unattempted_required_occurrences = sum(ledger$multiplicity[unattempted]),
      warning_unique = sum(nzchar(ledger$warnings)))
  }
  observed_counts <- ledger_metrics(result$observed_jackknife$ledger)
  inner_counts <- Reduce(`+`, lapply(result$inner, function(jk) ledger_metrics(jk$ledger)))
  summary <- cbind(metadata[rep(1L, 2L), , drop = FALSE], phase = c("observed", "inner"),
                   as.data.frame(rbind(observed_counts, inner_counts)))
  rownames(summary) <- NULL
  events <- list()
  for (b in 0:result$B) {
    ledger <- if (b == 0L) result$observed_jackknife$ledger else result$inner[[b]]$ledger
    failed <- ledger$attempted & !ledger$success
    warning <- nzchar(ledger$warnings)
    keep <- failed | warning
    if (!any(keep)) next
    rows <- ledger[keep, , drop = FALSE]
    event_kind <- ifelse(failed[keep] & warning[keep], "failure_and_warning",
                         ifelse(failed[keep], "failure", "warning"))
    events[[length(events) + 1L]] <- cbind(metadata[rep(1L, nrow(rows)), , drop = FALSE],
      phase = if (b == 0L) "observed" else "inner", replicate_id = b,
      event_kind = event_kind, rows)
  }
  prototype <- cbind(metadata[FALSE, , drop = FALSE], phase = character(),
    replicate_id = integer(), event_kind = character(), result$observed_jackknife$ledger[FALSE, , drop = FALSE])
  events <- if (length(events)) do.call(rbind, events) else prototype
  rownames(events) <- NULL
  list(summary = summary, events = events)
}

study03_validate_directory <- function(output_dir, analysis_schema = TRUE) {
  paths <- list.files(file.path(output_dir, "checkpoints"), pattern = "\\.rds$", full.names = TRUE)
  if (!length(paths)) stop("No study03 checkpoints were found.", call. = FALSE)
  plan <- readRDS(file.path(output_dir, "seed-plan.rds"))
  key <- function(job) paste(job$case_id, job$dataset_id, sep = "|")
  plan_keys <- vapply(plan, key, character(1))
  if (anyDuplicated(plan_keys) || length(paths) != length(plan)) {
    stop("Checkpoint count or seed-plan uniqueness failed.", call. = FALSE)
  }
  seen <- character(); summaries <- vector("list", length(paths))
  deletion_summaries <- deletion_events <- vector("list", length(paths))
  frozen <- readRDS(file.path(output_dir, "frozen-design.rds"))
  for (i in seq_along(paths)) {
    result <- readRDS(paths[i]); result_key <- key(result$job)
    match_id <- match(result_key, plan_keys)
    if (is.na(match_id) || result_key %in% seen || !identical(result$job, plan[[match_id]]) ||
        !identical(result$freeze, frozen)) {
      stop("Checkpoint job/freeze signature mismatch: ", paths[i], call. = FALSE)
    }
    seen <- c(seen, result_key)
    summaries[[i]] <- study03_validate_result(result)
    accounting <- study03_deletion_accounting(result)
    deletion_summaries[[i]] <- accounting$summary
    deletion_events[[i]] <- accounting$events
  }
  if (!setequal(seen, plan_keys)) stop("Planned jobs are missing.", call. = FALSE)
  if (analysis_schema) {
    if (!exists("study03_validate_analysis", mode = "function")) {
      stop("Source analyze.R before requesting its schema validation.", call. = FALSE)
    }
    read <- function(name) read.csv(file.path(output_dir, paste0(name, ".csv")),
                                    stringsAsFactors = FALSE)
    study03_validate_analysis(read("caseplan"), read("outer"), read("estimates"),
                              read("regions"), read("attempts"), read("studentization"))
  }
  summary <- do.call(rbind, summaries)
  write.csv(summary, file.path(output_dir, "mechanical-validation.csv"), row.names = FALSE)
  write.csv(do.call(rbind, deletion_summaries), file.path(output_dir, "deletion-accounting.csv"), row.names = FALSE)
  write.csv(do.call(rbind, deletion_events), file.path(output_dir, "deletion-failures-warnings.csv"), row.names = FALSE)
  writeLines(c(paste("Checkpoints:", nrow(summary)), paste("Mechanical checks:", sum(summary$checks)),
               paste("Retained jackknives reconstructed from leave-one vectors:", sum(summary$retained_jackknives)),
               paste("Expanded occurrence vectors reconstructed:", sum(summary$expanded_occurrence_vectors_reconstructed)),
               paste("Pivot rows checked:", sum(summary$pivot_rows_checked)), "Status: passed"),
             file.path(output_dir, "mechanical-validation.txt"))
  summary
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript validate.R /absolute/study03-output")
  script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  source(file.path(source_dir, "run.R")); study03_load(source_dir)
  source(file.path(source_dir, "analyze.R"))
  study03_validate_directory(normalizePath(args[1L]))
}
