#!/usr/bin/env Rscript
# Study 03: analysis only. No simulation, cutoff fitting, or method selection.

study03_key <- function(x, columns) do.call(paste, c(x[columns], sep = "\r"))
study03_groups <- function(x, columns) split(x, study03_key(x, columns))
study03_mcse <- function(x) if (length(x) > 1L) stats::sd(x) / sqrt(length(x)) else NA_real_
study03_mean <- function(x) if (length(x)) mean(x) else NA_real_
study03_methods <- function() c("wald", "bootstrap_mahalanobis", "bootstrap_ball",
                                "jackknife_wald", "jackknife_studentized")

study03_wilson <- function(successes, total, level = .95) {
  if (length(successes) != 1L || length(total) != 1L ||
      any(!is.finite(c(successes, total))) || total < 0 || successes < 0 ||
      successes > total || any(c(successes, total) != floor(c(successes, total))) ||
      length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    stop("Wilson inputs must be valid counts and a probability level.", call. = FALSE)
  }
  if (!total) return(c(estimate = NA_real_, mcse = NA_real_, lower = NA_real_, upper = NA_real_))
  p <- unname(successes / total)
  total <- unname(total)
  z <- stats::qnorm((1 + level) / 2)
  den <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / den
  half <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / den
  c(estimate = p, mcse = sqrt(p * (1 - p) / total),
    lower = max(0, center - half), upper = min(1, center + half))
}

study03_validate_analysis <- function(caseplan, outer, estimates, regions,
                                      attempts, studentization,
                                      entities = c("E015", "E003", "E006")) {
  need <- function(x, columns, name) {
    if (!is.data.frame(x) || !all(columns %in% names(x))) {
      stop(name, " is missing required columns.", call. = FALSE)
    }
  }
  flags <- function(x, columns, name, missing = FALSE) {
    for (column in columns) if (!is.logical(x[[column]]) || (!missing && anyNA(x[[column]]))) {
      stop(name, " requires logical ", column, if (!missing) " without missing values" else "", ".", call. = FALSE)
    }
  }
  need(caseplan, c("case_id", "scenario", "m", "M", "B"), "caseplan")
  if (!nrow(caseplan) || anyNA(caseplan[c("case_id", "scenario", "m", "M", "B")]) ||
      anyDuplicated(caseplan$case_id) || any(!nzchar(caseplan$case_id)) ||
      any(!is.finite(as.matrix(caseplan[c("m", "M", "B")]))) ||
      any(as.matrix(caseplan[c("m", "M", "B")]) != floor(as.matrix(caseplan[c("m", "M", "B")]))) ||
      any(caseplan$m < 3L | caseplan$M < 2L | caseplan$B < 20L)) {
    stop("Case plan requires unique cases and valid finite integer dimensions.", call. = FALSE)
  }
  base <- c("case_id", "scenario", "m", "dataset_id")
  need(outer, c(base, "observed_success"), "outer")
  need(estimates, c(base, "entity", "observed_success", "dx", "dy", "truth_dx", "truth_dy", "observed_jackknife_ok"), "estimates")
  need(regions, c(base, "entity", "method", "available", "gate", "delivered", "covered", "rejects_zero",
                 "relaxed_covered", "relaxed_rejects_zero", "area", "n_valid", "cutoff",
                 "var_dx", "var_dy", "cov_dx_dy", "truth_dx", "truth_dy"), "regions")
  need(attempts, c(base, "replicate_id", "attempted", "success", "stage", "message"), "attempts")
  need(studentization, c(base, "entity", "replicate_id", "attempted", "covariance_ok", "pivot_ok", "pivot",
                        "inner_required_unique", "inner_successful_unique", "stage", "message"), "studentization")
  check_metadata <- function(x, name) {
    index <- match(x$case_id, caseplan$case_id)
    if (anyNA(x[base]) || anyNA(index) || any(x$scenario != caseplan$scenario[index]) ||
        any(x$m != caseplan$m[index]) || any(x$dataset_id < 1L | x$dataset_id > caseplan$M[index]) ||
        any(x$dataset_id != floor(x$dataset_id))) {
      stop(name, " has unknown case metadata or out-of-plan dataset identifiers.", call. = FALSE)
    }
    invisible(index)
  }
  oi <- check_metadata(outer, "outer")
  outer_key <- study03_key(outer, c("case_id", "dataset_id"))
  if (anyDuplicated(outer_key) || nrow(outer) != sum(caseplan$M) ||
      any(tabulate(oi, nbins = nrow(caseplan)) != caseplan$M)) {
    stop("Outer ledger must contain every planned dataset exactly once.", call. = FALSE)
  }
  flags(outer, "observed_success", "outer")
  check_product <- function(x, extra, levels, name, draws = FALSE) {
    ci <- check_metadata(x, name)
    keys <- c("case_id", "dataset_id", extra)
    expected <- sum(caseplan$M * if (draws) caseplan$B else 1L) * prod(lengths(levels))
    if (anyNA(x[keys]) || anyDuplicated(study03_key(x, keys)) || nrow(x) != expected ||
        any(!study03_key(x, c("case_id", "dataset_id")) %in% outer_key)) {
      stop(name, " must retain every planned combination exactly once.", call. = FALSE)
    }
    categorical <- setdiff(extra, "replicate_id")
    if (any(!vapply(seq_along(categorical), function(i) all(x[[categorical[i]]] %in% levels[[i]]), logical(1))) ||
        (draws && any(x$replicate_id < 1L | x$replicate_id > caseplan$B[ci] | x$replicate_id != floor(x$replicate_id)))) {
      stop(name, " contains unplanned levels or draw identifiers.", call. = FALSE)
    }
    # Per-case completeness matters when cases have unequal M or B.
    counts <- tabulate(ci, nbins = nrow(caseplan))
    required <- caseplan$M * if (draws) caseplan$B else 1L
    if (any(counts != required * prod(lengths(levels)))) {
      stop(name, " case-specific denominators disagree with the plan.", call. = FALSE)
    }
    invisible(ci)
  }
  check_product(estimates, "entity", list(entities), "estimates")
  ri <- check_product(regions, c("entity", "method"), list(entities, study03_methods()), "regions")
  check_product(attempts, "replicate_id", list(), "attempts", draws = TRUE)
  check_product(studentization, c("entity", "replicate_id"), list(entities), "studentization", draws = TRUE)
  flags(estimates, c("observed_success", "observed_jackknife_ok"), "estimates")
  flags(regions, c("available", "gate", "delivered"), "regions")
  flags(regions, c("covered", "rejects_zero", "relaxed_covered", "relaxed_rejects_zero"), "regions", TRUE)
  flags(attempts, c("attempted", "success"), "attempts")
  flags(studentization, c("attempted", "covariance_ok", "pivot_ok"), "studentization")
  ei <- match(study03_key(estimates, c("case_id", "dataset_id")), outer_key)
  good <- estimates$observed_success
  if (any(good != outer$observed_success[ei]) ||
      any(!is.finite(as.matrix(estimates[good, c("dx", "dy")]))) ||
      any(is.finite(as.matrix(estimates[!good, c("dx", "dy")])) ) ||
      any(!is.finite(as.matrix(estimates[c("truth_dx", "truth_dy")]))) ||
      any(estimates$observed_jackknife_ok & !good)) {
    stop("Observed states, estimates, truth, or jackknife validity disagree.", call. = FALSE)
  }
  ekey <- c("case_id", "dataset_id", "entity")
  er <- match(study03_key(regions, ekey), study03_key(estimates, ekey))
  jack_wald <- regions$method == "jackknife_wald"
  if (any(regions$truth_dx != estimates$truth_dx[er] | regions$truth_dy != estimates$truth_dy[er])) {
    stop("Region and estimate population targets disagree.", call. = FALSE)
  }
  if (any(regions$delivered != (regions$available & regions$gate)) ||
      any(regions$available & !estimates$observed_success[er]) ||
      anyNA(regions$covered[regions$delivered]) || anyNA(regions$rejects_zero[regions$delivered]) ||
      any(!is.na(regions$covered[!regions$delivered])) || any(!is.na(regions$rejects_zero[!regions$delivered])) ||
      anyNA(regions$relaxed_covered[regions$available]) || anyNA(regions$relaxed_rejects_zero[regions$available]) ||
      any(!is.na(regions$relaxed_covered[!regions$available])) || any(!is.na(regions$relaxed_rejects_zero[!regions$available])) ||
      any(regions$covered[regions$delivered] != regions$relaxed_covered[regions$delivered]) ||
      any(regions$rejects_zero[regions$delivered] != regions$relaxed_rejects_zero[regions$delivered]) ||
      any(!is.finite(regions$area[regions$available]) | regions$area[regions$available] <= 0) ||
      any(!is.finite(regions$cutoff[regions$available]) | regions$cutoff[regions$available] <= 0) ||
      anyNA(regions$n_valid[!jack_wald]) || any(!is.na(regions$n_valid[jack_wald])) ||
      any(regions$n_valid[!jack_wald] < 0 | regions$n_valid[!jack_wald] > caseplan$B[ri[!jack_wald]]) ||
      any(regions$n_valid[!jack_wald] != floor(regions$n_valid[!jack_wald])) ||
      any(regions$gate[jack_wald] != estimates$observed_success[er[jack_wald]]) ||
      any(regions$delivered[jack_wald] != estimates$observed_jackknife_ok[er[jack_wald]])) {
    stop("Region delivery, availability, outcomes, geometry, or valid counts disagree.", call. = FALSE)
  }
  zero <- sqrt(regions$truth_dx^2 + regions$truth_dy^2) <= 1e-10
  use <- zero & regions$available
  if (any(regions$relaxed_covered[use] == regions$relaxed_rejects_zero[use])) {
    stop("Zero-target coverage and zero exclusion must be complements.", call. = FALSE)
  }
  ai <- match(study03_key(attempts, c("case_id", "dataset_id")), outer_key)
  if (any(attempts$attempted != outer$observed_success[ai]) || any(attempts$success & !attempts$attempted)) {
    stop("Full-fit attempts must follow observed-fit validity and preserve unattempted draws.", call. = FALSE)
  }
  sa <- match(study03_key(studentization, c("case_id", "dataset_id", "replicate_id")),
              study03_key(attempts, c("case_id", "dataset_id", "replicate_id")))
  if (any(studentization$attempted & !attempts$success[sa]) ||
      any(studentization$covariance_ok & !studentization$attempted) ||
      any(studentization$pivot_ok & !studentization$covariance_ok) ||
      any(!is.finite(studentization$pivot[studentization$pivot_ok]) | studentization$pivot[studentization$pivot_ok] < 0) ||
      any(is.finite(studentization$pivot[!studentization$pivot_ok])) ||
      anyNA(studentization[c("inner_required_unique", "inner_successful_unique")]) ||
      any(studentization$inner_required_unique < 0 | studentization$inner_successful_unique < 0 |
          studentization$inner_successful_unique > studentization$inner_required_unique) ||
      any(studentization$covariance_ok & studentization$inner_successful_unique != studentization$inner_required_unique)) {
    stop("Studentization attempts, covariance states, pivots, or inner counts disagree.", call. = FALSE)
  }
  success_counts <- tabulate(ai[attempts$success], nbins = nrow(outer))
  re <- match(study03_key(regions, c("case_id", "dataset_id")), outer_key)
  bootstrap <- regions$method %in% c("wald", "bootstrap_mahalanobis", "bootstrap_ball")
  se <- match(study03_key(studentization, ekey), study03_key(estimates, ekey))
  pivot_counts <- tabulate(se[studentization$pivot_ok], nbins = nrow(estimates))
  student <- regions$method == "jackknife_studentized"
  if (any(regions$n_valid[bootstrap] != success_counts[re[bootstrap]]) ||
      any(regions$n_valid[student] != pivot_counts[er[student]]) ||
      any(regions$gate[bootstrap | student] !=
          (regions$n_valid[bootstrap | student] >= 20L &
           regions$n_valid[bootstrap | student] / caseplan$B[ri[bootstrap | student]] >= .95))) {
    stop("Region valid-draw counts or success-fraction gates fail ledger reconciliation.", call. = FALSE)
  }
  invisible(TRUE)
}

study03_coverage_summary <- function(caseplan, estimates, regions) {
  keys <- c("case_id", "scenario", "m", "entity", "method")
  rows <- list()
  for (x in study03_groups(regions, keys)) for (policy in c("production", "relaxed")) {
    delivered <- if (policy == "production") x$delivered else x$available
    covered <- if (policy == "production") x$covered else x$relaxed_covered
    rejects <- if (policy == "production") x$rejects_zero else x$relaxed_rejects_zero
    n <- caseplan$M[match(x$case_id[1], caseplan$case_id)]
    e <- estimates[estimates$case_id == x$case_id[1] & estimates$entity == x$entity[1], ]
    nc <- sum(covered[delivered]); nd <- sum(delivered); nr <- sum(rejects[delivered])
    coverage <- study03_wilson(nc, nd); delivery <- study03_wilson(nd, n)
    yield <- study03_wilson(nc, n); exclusion <- study03_wilson(nr, nd)
    truth_norm <- sqrt(x$truth_dx^2 + x$truth_dy^2)
    zero <- truth_norm <= 1e-10
    if (length(unique(zero)) != 1L) stop("A case/target mixes zero and nonzero truths.")
    rows[[length(rows) + 1L]] <- data.frame(x[1, keys], policy = policy,
      target_status = if (zero[1]) "null_target" else "nonzero_population_embedding_target",
      zero_exclusion_interpretation = if (x$scenario[1] == "regular_null" && zero[1]) "type_I_error" else
        if (!zero[1]) "power_for_declared_nonzero_target" else "zero_exclusion_for_zero_target_in_movement_scenario",
      truth_dx = x$truth_dx[1], truth_dy = x$truth_dy[1], truth_distance = truth_norm[1],
      n_outer = n, n_observed_valid = sum(e$observed_success), n_observed_jackknife_ok = sum(e$observed_jackknife_ok),
      n_available = sum(x$available), n_gate_passed = sum(x$gate),
      n_delivered = nd, n_covered = nc, n_zero_excluded = nr,
      conditional_coverage = unname(coverage["estimate"]), coverage_mcse = unname(coverage["mcse"]),
      coverage_wilson_lower = unname(coverage["lower"]), coverage_wilson_upper = unname(coverage["upper"]),
      conditional_zero_exclusion = unname(exclusion["estimate"]), zero_exclusion_mcse = unname(exclusion["mcse"]),
      zero_exclusion_wilson_lower = unname(exclusion["lower"]), zero_exclusion_wilson_upper = unname(exclusion["upper"]),
      delivery_fraction = unname(delivery["estimate"]), delivery_mcse = unname(delivery["mcse"]),
      delivery_wilson_lower = unname(delivery["lower"]), delivery_wilson_upper = unname(delivery["upper"]),
      operational_coverage_and_delivery = unname(yield["estimate"]), yield_mcse = unname(yield["mcse"]),
      yield_wilson_lower = unname(yield["lower"]), yield_wilson_upper = unname(yield["upper"]),
      operational_zero_exclusion_and_delivery = nr / n,
      mean_area_delivered = study03_mean(x$area[delivered]), area_mcse = study03_mcse(x$area[delivered]),
      median_area_delivered = if (nd) stats::median(x$area[delivered]) else NA_real_,
      cutoff_scale = if (x$method[1] == "bootstrap_ball") "Euclidean radius" else "Squared Mahalanobis radius",
      mean_cutoff_delivered = study03_mean(x$cutoff[delivered]),
      cutoff_mcse = study03_mcse(x$cutoff[delivered]),
      median_cutoff_delivered = if (nd) stats::median(x$cutoff[delivered]) else NA_real_,
      q90_cutoff_delivered = if (nd) unname(stats::quantile(x$cutoff[delivered], .90, type = 7L)) else NA_real_,
      q95_cutoff_delivered = if (nd) unname(stats::quantile(x$cutoff[delivered], .95, type = 7L)) else NA_real_,
      min_cutoff_delivered = if (nd) min(x$cutoff[delivered]) else NA_real_,
      max_cutoff_delivered = if (nd) max(x$cutoff[delivered]) else NA_real_,
      mean_valid_draws = if (all(is.na(x$n_valid))) NA_real_ else mean(x$n_valid), row.names = NULL)
  }
  do.call(rbind, rows)
}

study03_error_summary <- function(estimates, regions) {
  keys <- c("case_id", "scenario", "m", "entity")
  rows <- list()
  for (x in study03_groups(estimates, keys)) {
    r <- regions[regions$case_id == x$case_id[1] & regions$entity == x$entity[1], ]
    cohorts <- list(observed_valid = x$observed_success,
                    observed_jackknife_valid = x$observed_jackknife_ok)
    for (method in study03_methods()) {
      z <- r[r$method == method, ]; z <- z[match(x$dataset_id, z$dataset_id), ]
      cohorts[[paste0("delivered_", method)]] <- x$observed_success & z$delivered
    }
    for (cohort in names(cohorts)) {
      use <- cohorts[[cohort]]
      dx <- x$dx[use] - x$truth_dx[use]; dy <- x$dy[use] - x$truth_dy[use]
      sq <- dx^2 + dy^2; rmse <- sqrt(study03_mean(sq)); n <- length(sq)
      rows[[length(rows) + 1L]] <- data.frame(x[1, keys], cohort = cohort,
        n_outer = nrow(x), n_selected = n, bias_dx = study03_mean(dx), bias_dy = study03_mean(dy),
        bias_dx_mcse = study03_mcse(dx), bias_dy_mcse = study03_mcse(dy),
        vector_rmse = rmse, rmse_mcse_delta = if (n > 1L && rmse > 0) study03_mcse(sq) / (2 * rmse) else if (n > 1L && rmse == 0) 0 else NA_real_,
        mean_squared_error = study03_mean(sq), mean_squared_error_mcse = study03_mcse(sq), row.names = NULL)
    }
  }
  do.call(rbind, rows)
}

study03_paired_difference <- function(a, b, bounded = TRUE) {
  if (length(a) != length(b) || anyNA(a) || anyNA(b) || any(!is.finite(a)) || any(!is.finite(b))) {
    stop("Paired differences require equally sized complete finite vectors.", call. = FALSE)
  }
  delta <- as.numeric(b) - as.numeric(a)
  n <- length(delta); estimate <- study03_mean(delta); se <- study03_mcse(delta)
  lower <- estimate - 1.96 * se; upper <- estimate + 1.96 * se
  if (bounded) { lower <- max(-1, lower); upper <- min(1, upper) }
  c(n_pairs = n, difference = estimate, mcse = se, lower = lower, upper = upper,
    increased = sum(delta > 0), decreased = sum(delta < 0))
}

study03_paired_contrasts <- function(regions) {
  keys <- c("case_id", "scenario", "m", "entity")
  rows <- list()
  for (x in study03_groups(regions, keys)) for (baseline in setdiff(study03_methods(), "jackknife_studentized")) {
    a <- x[x$method == baseline, ]; b <- x[x$method == "jackknife_studentized", ]
    if (anyDuplicated(a$dataset_id) || anyDuplicated(b$dataset_id) || !setequal(a$dataset_id, b$dataset_id)) {
      stop("Method contrasts require identical paired dataset keys.", call. = FALSE)
    }
    b <- b[match(a$dataset_id, b$dataset_id), ]; both <- a$delivered & b$delivered
    outcomes <- list(
      conditional_coverage_joint_delivery = list(a$covered[both], b$covered[both]),
      conditional_zero_exclusion_joint_delivery = list(a$rejects_zero[both], b$rejects_zero[both]),
      delivery = list(a$delivered, b$delivered),
      operational_yield = list(a$delivered & !is.na(a$covered) & a$covered,
                               b$delivered & !is.na(b$covered) & b$covered),
      area_joint_delivery = list(a$area[both], b$area[both]),
      log_area_ratio_joint_delivery = list(log(a$area[both]), log(b$area[both])))
    for (metric in names(outcomes)) {
      stats <- study03_paired_difference(outcomes[[metric]][[1]], outcomes[[metric]][[2]],
                                         bounded = !grepl("area", metric))
      rows[[length(rows) + 1L]] <- data.frame(x[1, keys], baseline = baseline,
        candidate = "jackknife_studentized", metric = metric, n_outer = nrow(a),
        n_joint_delivered = sum(both), as.list(stats), row.names = NULL)
    }
  }
  do.call(rbind, rows)
}

study03_covariance_summary <- function(estimates, regions) {
  keys <- c("case_id", "scenario", "m", "entity", "method")
  rows <- lapply(study03_groups(regions[regions$method %in% c("wald", "jackknife_wald"), ], keys), function(x) {
    e <- estimates[estimates$case_id == x$case_id[1] & estimates$entity == x$entity[1], ]
    e <- e[match(x$dataset_id, e$dataset_id), ]
    use <- e$observed_success & is.finite(x$var_dx) & is.finite(x$var_dy) & is.finite(x$cov_dx_dy)
    d <- cbind(e$dx[use] - e$truth_dx[use], e$dy[use] - e$truth_dy[use]); r <- x[use, ]; n <- nrow(d)
    outer <- average <- matrix(NA_real_, 2L, 2L)
    ratio <- ratio_se <- rmin <- rmax <- NA_real_
    traces <- r$var_dx + r$var_dy
    if (n >= 2L) {
      outer <- stats::cov(d)
      average <- matrix(c(mean(r$var_dx), mean(r$cov_dx_dy), mean(r$cov_dx_dy), mean(r$var_dy)), 2L)
      trace <- sum(diag(outer))
      if (is.finite(trace) && trace > 0) {
        ratio <- mean(traces) / trace
        if (n >= 4L) {
          centered_sq <- rowSums(sweep(d, 2L, colMeans(d), "-")^2)
          loo_outer <- ((n - 1) * trace - n / (n - 1) * centered_sq) / (n - 2)
          loo_estimated <- (sum(traces) - traces) / (n - 1)
          if (all(loo_outer > 0)) {
            jack <- loo_estimated / loo_outer
            ratio_se <- sqrt((n - 1) / n * sum((jack - mean(jack))^2))
          }
        }
      }
      vals <- eigen(outer, symmetric = TRUE)$values
      if (all(is.finite(vals)) && vals[2] > 1e-12 * vals[1]) {
        inverse <- solve(chol(outer))
        ratios <- eigen(t(inverse) %*% average %*% inverse, symmetric = TRUE)$values
        rmin <- min(ratios); rmax <- max(ratios)
      }
    }
    data.frame(x[1, keys], n_outer = nrow(x), n_covariance_pairs = n,
      outer_variance_trace = sum(diag(outer)), mean_estimated_variance_trace = sum(diag(average)),
      covariance_trace_ratio = ratio, trace_ratio_jackknife_mcse = ratio_se,
      generalized_ratio_min = rmin, generalized_ratio_max = rmax,
      estimated_trace_cv = if (n >= 2L && mean(traces) > 0) stats::sd(traces) / mean(traces) else NA_real_,
      covariance_cohort = "Observed-valid panels with finite method covariance; selected count disclosed", row.names = NULL)
  })
  do.call(rbind, rows)
}

study03_failure_summaries <- function(caseplan, outer, attempts, studentization) {
  keys <- c("case_id", "scenario", "m")
  attempt_rows <- lapply(study03_groups(attempts, keys), function(x) {
    rates <- vapply(study03_groups(x, "dataset_id"), function(z)
      if (any(z$attempted)) mean(!z$success[z$attempted]) else NA_real_, numeric(1))
    finite <- rates[is.finite(rates)]
    data.frame(x[1, keys], n_outer = length(rates), n_planned = nrow(x), n_attempted = sum(x$attempted),
      n_unattempted = sum(!x$attempted), n_successful = sum(x$success), n_failed_after_attempt = sum(x$attempted & !x$success),
      failure_fraction_of_attempted = if (any(x$attempted)) mean(!x$success[x$attempted]) else NA_real_,
      n_outer_with_attempts = length(finite), mean_outer_failure_fraction = study03_mean(finite),
      outer_failure_fraction_mcse = study03_mcse(finite), row.names = NULL)
  })
  student_rows <- lapply(study03_groups(studentization, c(keys, "entity")), function(x) {
    per <- study03_groups(x, "dataset_id")
    failure <- vapply(per, function(z) if (any(z$attempted)) mean(!z$pivot_ok[z$attempted]) else NA_real_, numeric(1))
    finite <- failure[is.finite(failure)]
    data.frame(x[1, c(keys, "entity")], n_outer = length(per), n_planned = nrow(x),
      n_attempted = sum(x$attempted), n_unattempted = sum(!x$attempted),
      n_covariance_ok = sum(x$covariance_ok), n_pivot_ok = sum(x$pivot_ok),
      n_covariance_failed_after_attempt = sum(x$attempted & !x$covariance_ok),
      n_pivot_failed_with_valid_covariance = sum(x$covariance_ok & !x$pivot_ok),
      covariance_valid_fraction_of_attempted = if (any(x$attempted)) mean(x$covariance_ok[x$attempted]) else NA_real_,
      pivot_valid_fraction_of_planned = mean(x$pivot_ok),
      n_outer_with_attempts = length(finite), mean_outer_pivot_failure_fraction = study03_mean(finite),
      outer_pivot_failure_fraction_mcse = study03_mcse(finite),
      inner_required_unique_total = sum(x$inner_required_unique), inner_successful_unique_total = sum(x$inner_successful_unique),
      inner_count_scope = "Target ledger totals; shared inner fits repeat across targets and must not be summed over entities",
      mean_successful_pivot = study03_mean(x$pivot[x$pivot_ok]),
      successful_pivot_scope = "Descriptive conditional draw distribution; no draw-level Monte Carlo SE", row.names = NULL)
  })
  stages <- list()
  for (kind in c("full_fit", "studentization")) {
    x <- if (kind == "full_fit") attempts else studentization
    if (kind == "full_fit") x$entity <- "all_targets"
    x$success <- if (kind == "full_fit") x$success else x$pivot_ok
    failed <- x[!x$success, ]
    failed$stage[is.na(failed$stage) | !nzchar(failed$stage)] <- "unspecified_failure"
    for (z in study03_groups(failed, c(keys, "entity", "stage"))) {
      stages[[length(stages) + 1L]] <- data.frame(z[1, c(keys, "entity", "stage")], ledger = kind,
        n_rows = nrow(z), n_outer_affected = length(unique(z$dataset_id)),
        n_attempted = sum(z$attempted), n_unattempted = sum(!z$attempted), row.names = NULL)
    }
  }
  stage_table <- if (length(stages)) do.call(rbind, stages) else
    data.frame(case_id = character(), scenario = character(), m = integer(), entity = character(), stage = character(),
               ledger = character(), n_rows = integer(), n_outer_affected = integer(), n_attempted = integer(), n_unattempted = integer())
  list(attempts = do.call(rbind, attempt_rows), studentization = do.call(rbind, student_rows), failure_stages = stage_table)
}

study03_selection_summary <- function(estimates, studentization) {
  required <- c("dx", "dy", "distinct_units", "rare_multiplicity")
  if (!all(required %in% names(studentization))) {
    stop("Studentization ledger needs full-fit displacement and planned draw-composition columns for selection diagnostics.", call. = FALSE)
  }
  keys <- c("case_id", "scenario", "m", "entity")
  ek <- match(study03_key(studentization, c("case_id", "dataset_id", "entity")),
              study03_key(estimates, c("case_id", "dataset_id", "entity")))
  x <- studentization
  x$error_norm <- sqrt((x$dx - estimates$dx[ek])^2 + (x$dy - estimates$dy[ek])^2)
  x$observed_success <- estimates$observed_success[ek]
  rows <- list(); panel_rows <- list()
  stages <- c("full_fit", "studentized_pivot", "studentized_pivot_given_full_fit")
  for (g in study03_groups(x, keys)) for (selection_stage in stages) for (metric in c("distinct_units", "rare_multiplicity", "error_norm")) {
    for (d in study03_groups(g, "dataset_id")) {
      finite <- is.finite(d[[metric]])
      reference <- finite & (selection_stage != "studentized_pivot_given_full_fit" | d$attempted)
      selected <- if (selection_stage == "full_fit") d$attempted else d$pivot_ok
      all <- d[[metric]][reference]; valid <- d[[metric]][reference & selected]
      failed <- d[[metric]][reference & !selected]
      covvalid <- d[[metric]][finite & d$covariance_ok]
      panel_rows[[length(panel_rows) + 1L]] <- data.frame(d[1, c(keys, "dataset_id")], selection_stage = selection_stage, metric = metric,
        observed_success = d$observed_success[1L],
        n_reference_finite = length(all), n_selected_finite = length(valid), n_failed_finite = length(failed),
        reference_mean = study03_mean(all), selected_mean = study03_mean(valid), failed_mean = study03_mean(failed),
        covariance_valid_mean = study03_mean(covvalid),
        valid_minus_planned = study03_mean(valid) - study03_mean(all),
        valid_minus_failed = study03_mean(valid) - study03_mean(failed), row.names = NULL)
    }
  }
  panel <- do.call(rbind, panel_rows)
  for (g in study03_groups(panel, c(keys, "selection_stage", "metric"))) {
    paired <- is.finite(g$valid_minus_planned); mixed <- is.finite(g$valid_minus_failed)
    rows[[length(rows) + 1L]] <- data.frame(g[1, c(keys, "selection_stage", "metric")], n_outer = nrow(g),
      n_outer_observed_valid = sum(g$observed_success),
      n_outer_with_valid_and_planned = sum(paired), n_outer_with_valid_and_failed = sum(mixed),
      mean_reference = study03_mean(g$reference_mean[is.finite(g$reference_mean)]),
      mean_selected = study03_mean(g$selected_mean[is.finite(g$selected_mean)]),
      paired_valid_minus_planned = study03_mean(g$valid_minus_planned[paired]),
      paired_valid_minus_planned_mcse = study03_mcse(g$valid_minus_planned[paired]),
      paired_valid_minus_failed = study03_mean(g$valid_minus_failed[mixed]),
      paired_valid_minus_failed_mcse = study03_mcse(g$valid_minus_failed[mixed]),
      reference_cohort = if (g$selection_stage[1] == "studentized_pivot_given_full_fit")
        "Successful full-fit draws only" else "All planned weights, including unattempted observed-invalid panels",
      metric_scope = if (g$metric[1] == "error_norm") "Full-fit draws with finite displacement; failed full fits have no defined error norm" else
        "Composition is known for every planned draw; means average within outer panel first",
      contrast_cohort = "Paired differences require defined selected and reference means, hence condition on observed validity and at least one selected draw", row.names = NULL)
  }
  list(selection = do.call(rbind, rows), selection_by_panel = panel)
}

study03_write_figures <- function(coverage, contrasts, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required for study figures.")
  palette <- c(wald = "#737B83", bootstrap_mahalanobis = "#B97943", bootstrap_ball = "#63866E",
               jackknife_wald = "#86709A", jackknife_studentized = "#176B87")
  labels <- c(wald = "Bootstrap Wald", bootstrap_mahalanobis = "Bootstrap Mahalanobis", bootstrap_ball = "Bootstrap ball",
              jackknife_wald = "Jackknife Wald", jackknife_studentized = "Studentized jackknife")
  percent <- function(x) paste0(round(100 * x), "%")
  theme <- ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = "bottom",
      legend.title = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, size = 9), plot.margin = ggplot2::margin(12, 16, 12, 12))
  save <- function(plot, filename, width, height) for (ext in c("png", "pdf")) {
    ggplot2::ggsave(file.path(output_dir, paste0(filename, ".", ext)), plot,
      width = width, height = height, units = "in", dpi = 300, bg = "white")
  }
  primary <- coverage[coverage$entity == "E015" & coverage$policy == "production", ]
  regular <- primary[grepl("^regular_", primary$scenario), ]
  p <- ggplot2::ggplot(regular, ggplot2::aes(m, conditional_coverage, color = method, group = method)) +
    ggplot2::geom_hline(yintercept = .95, linetype = "dashed", color = "#89939C") +
    ggplot2::geom_line(na.rm = TRUE, position = ggplot2::position_dodge(.07)) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = coverage_wilson_lower, ymax = coverage_wilson_upper),
      width = .025, position = ggplot2::position_dodge(.07), na.rm = TRUE) +
    ggplot2::geom_point(size = 2, position = ggplot2::position_dodge(.07), na.rm = TRUE) +
    ggplot2::facet_wrap(~scenario) + ggplot2::scale_x_log10(breaks = sort(unique(regular$m))) +
    ggplot2::scale_y_continuous(limits = c(0, 1), labels = percent) +
    ggplot2::scale_color_manual(values = palette, breaks = names(labels), labels = labels) +
    ggplot2::labs(title = "Joint-region coverage is evaluated separately under null and movement",
      subtitle = "Primary target E015 | Nominal 95% | Full embedding and alignment estimator",
      x = "Independent measurement units", y = "Coverage among delivered regions",
      caption = "Bars: 95% Wilson Monte Carlo intervals across independent outer panels. Methods share panels and draws.\nCoverage conditions on delivery; undelivered regions remain in operational-yield denominators.") + theme
  save(p, "calibration03-coverage", 11.8, 6.1)
  stress <- coverage[coverage$entity == "E015" & !grepl("^regular_", coverage$scenario), ]
  if (nrow(stress)) {
    display <- rbind(transform(stress, metric = "Region delivery", value = delivery_fraction,
      lower = delivery_wilson_lower, upper = delivery_wilson_upper),
      transform(stress, metric = "Coverage among delivered", value = conditional_coverage,
        lower = coverage_wilson_lower, upper = coverage_wilson_upper),
      transform(stress, metric = "Coverage and delivery / all panels", value = operational_coverage_and_delivery,
        lower = yield_wilson_lower, upper = yield_wilson_upper))
    display$method <- factor(display$method, rev(names(labels)), rev(labels))
    p <- ggplot2::ggplot(display, ggplot2::aes(value, method, color = policy)) +
      ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper), orientation = "y", width = .2,
        position = ggplot2::position_dodge(.45), na.rm = TRUE) +
      ggplot2::geom_point(size = 2.2, position = ggplot2::position_dodge(.45), na.rm = TRUE) +
      ggplot2::facet_wrap(~metric, nrow = 1L) +
      ggplot2::scale_x_continuous(limits = c(0, 1), labels = percent) +
      ggplot2::scale_color_manual(values = c(production = "#176B87", relaxed = "#B97943")) +
      ggplot2::labs(title = "Rare-axis failures separate conditional coverage from usable results",
        subtitle = "Primary target E015 | Production success gate and relaxed geometry-only diagnostic",
        x = NULL, y = NULL, caption = "Bars: 95% Wilson Monte Carlo intervals. Relaxed results are selection diagnostics, not an alternative deployment rule.\nAll planned outer panels enter delivery and operational yield, including undefined observed fits.") + theme
    save(p, "calibration03-failure-delivery", 13.2, 5.6)
  }
  z <- contrasts[contrasts$entity == "E015" & contrasts$baseline %in% c("wald", "jackknife_wald") &
                   contrasts$metric %in% c("conditional_coverage_joint_delivery", "log_area_ratio_joint_delivery"), ]
  z$metric_label <- ifelse(z$metric == "conditional_coverage_joint_delivery", "Coverage difference", "Log area ratio")
  z$case_label <- paste(z$scenario, paste0("m = ", z$m), sep = "\n")
  p <- ggplot2::ggplot(z, ggplot2::aes(difference, case_label, color = baseline)) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "#89939C") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper), orientation = "y", width = .2,
      position = ggplot2::position_dodge(.45), na.rm = TRUE) +
    ggplot2::geom_point(size = 2.1, position = ggplot2::position_dodge(.45), na.rm = TRUE) +
    ggplot2::facet_wrap(~metric_label, scales = "free_x") +
    ggplot2::scale_color_manual(values = palette, breaks = c("wald", "jackknife_wald"), labels = labels[c("wald", "jackknife_wald")]) +
    ggplot2::labs(title = "Studentization changes coverage and region size on the same panels",
      subtitle = "Primary target E015 | Studentized candidate minus each reference method",
      x = "Paired difference", y = NULL,
      caption = "Bars: paired outer-panel estimate ± 1.96 MCSE; only jointly delivered pairs enter both metrics.\nCoverage differences are proportions. Positive log area ratios mean larger studentized regions.") + theme
  save(p, "calibration03-paired-contrasts", 11.8, max(5.8, .65 * length(unique(z$case_label)) + 2))
  invisible(NULL)
}

study03_analyze <- function(output_dir, figures = TRUE) {
  read <- function(filename) {
    path <- file.path(output_dir, filename)
    if (!file.exists(path)) stop("Missing completed-study file: ", filename, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  caseplan <- read("caseplan.csv"); outer <- read("outer.csv"); estimates <- read("estimates.csv")
  regions <- read("regions.csv"); attempts <- read("attempts.csv"); studentization <- read("studentization.csv")
  study03_validate_analysis(caseplan, outer, estimates, regions, attempts, studentization)
  answer <- c(list(coverage = study03_coverage_summary(caseplan, estimates, regions),
    errors = study03_error_summary(estimates, regions), contrasts = study03_paired_contrasts(regions),
    covariance = study03_covariance_summary(estimates, regions)),
    study03_failure_summaries(caseplan, outer, attempts, studentization),
    study03_selection_summary(estimates, studentization))
  for (name in names(answer)) utils::write.csv(answer[[name]],
    file.path(output_dir, paste0(name, "-summary.csv")), row.names = FALSE, na = "")
  if (figures) study03_write_figures(answer$coverage, answer$contrasts, output_dir)
  writeLines(c(
    "Study 03 uses the frozen case-specific M and B values in caseplan.csv; cases need not have equal denominators.",
    "The primary target is E015. E003 and E006 are separate secondary targets; entities and bootstrap draws are never independent outer replications.",
    "Coverage is conditional on delivery. Delivery and operational coverage yield divide by every planned outer panel, including undefined fits.",
    "Zero exclusion is reported as type-I error only under the regular whole-map null, and power only for a declared nonzero population-embedding target. Stable latent entities in movement scenarios can have nonzero embedding targets.",
    "Relaxed regions omit the success-fraction gate only; they are failure-selection diagnostics, not a recommended alternative rule.",
    "Paired method comparisons use within-panel differences on joint-delivery panels; area contrasts do not compare unpaired selected cohorts.",
    "Covariance summaries disclose the matched finite-covariance cohort. Error summaries separately disclose all observed-valid and each method-delivered cohort.",
    "Failure ledgers retain all planned outer and bootstrap entries. Studentization's inner counts repeat shared fit work across targets and must not be summed over entities.",
    "Selection stages distinguish successful full fits versus all planned weights, successful student pivots versus all planned weights, and successful pivots conditional on full-fit success. Selection MCSEs use per-outer-panel contrasts, which require observed validity and at least one selected draw.",
    "Coordinates use the normalized Gram XX'/m convention. Error regions are in normalized full-estimator displacement units; areas are not rescaled a second time.",
    "No cutoffs, inflation factors, rejection thresholds, or preferred methods are fitted from calibration outcomes."),
    file.path(output_dir, "analysis-notes.txt"))
  invisible(answer)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript analyze.R output_dir")
  study03_analyze(args[1L])
}
