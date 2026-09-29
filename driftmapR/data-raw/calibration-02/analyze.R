#!/usr/bin/env Rscript
# Frozen study 02 summaries. No simulation, fitted correction, or method tuning.

study02_key <- function(x, columns) do.call(paste, c(x[columns], sep = "\r"))
study02_groups <- function(x, columns) split(x, study02_key(x, columns))
study02_mcse <- function(x) if (length(x) > 1L) stats::sd(x) / sqrt(length(x)) else NA_real_

study02_wilson <- function(successes, total, level = .95) {
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

study02_validate_analysis <- function(outer, estimates, regions, failures,
                                      expected_outer = 240L,
                                      expected_m = c(20L, 40L, 160L, 640L),
                                      budgets = c(199L, 399L)) {
  need <- function(x, columns, name) {
    if (!is.data.frame(x) || !all(columns %in% names(x))) {
      stop(name, " is missing required columns.", call. = FALSE)
    }
  }
  logical_columns <- function(x, columns, name) {
    for (column in columns) if (!is.logical(x[[column]]) || anyNA(x[[column]])) {
      stop(name, " requires nonmissing logical ", column, ".", call. = FALSE)
    }
  }
  need(outer, c("m", "dataset_id", "observed_success"), "outer")
  need(estimates, c("m", "dataset_id", "anchor", "estimator", "entity", "dx", "dy",
                    "observed_success", "passes_gate"), "estimates")
  need(regions, c("m", "dataset_id", "anchor", "estimator", "entity", "budget", "method",
                  "available", "gate", "delivered", "covered", "rejects_zero", "n_valid",
                  "area", "var_dx", "var_dy", "cov_dx_dy", "truth_statistic", "radius"), "regions")
  need(failures, c("m", "dataset_id", "anchor", "estimator", "replicate_id", "attempted", "success"), "failures")
  if (length(expected_outer) != 1L || !is.finite(expected_outer) || expected_outer < 2L ||
      expected_outer != floor(expected_outer) || anyDuplicated(expected_m) || !length(expected_m) ||
      any(!is.finite(expected_m)) || any(expected_m < 2 | expected_m != floor(expected_m)) ||
      !length(budgets) || anyDuplicated(budgets) || any(!is.finite(budgets)) ||
      any(budgets < 20 | budgets != floor(budgets))) {
    stop("Expected study dimensions are invalid.", call. = FALSE)
  }
  outer_keys <- study02_key(outer, c("m", "dataset_id"))
  if (anyNA(outer[c("m", "dataset_id")]) || anyDuplicated(outer_keys) ||
      !setequal(unique(outer$m), expected_m) ||
      any(table(factor(outer$m, levels = expected_m)) != expected_outer) ||
      any(!outer$dataset_id %in% seq_len(expected_outer))) {
    stop("Outer ledger must contain exactly ", expected_outer, " unique datasets per expected unit count.", call. = FALSE)
  }
  logical_columns(outer, "observed_success", "outer")
  anchors <- c("original", "spread")
  estimators <- c("refit_plugin", "refit_oracle", "tangent_oracle")
  entities <- c("E015", "E003", "E006")
  methods <- c("wald", "bootstrap_mahalanobis", "bootstrap_ball")
  check_product <- function(x, extra, levels, name) {
    columns <- c("m", "dataset_id", extra)
    if (anyNA(x[columns]) || anyDuplicated(study02_key(x, columns)) ||
        nrow(x) != nrow(outer) * prod(lengths(levels)) ||
        any(!study02_key(x, c("m", "dataset_id")) %in% outer_keys) ||
        any(!vapply(seq_along(extra), function(i) all(x[[extra[i]]] %in% levels[[i]]), logical(1)))) {
      stop(name, " must contain every planned combination exactly once.", call. = FALSE)
    }
  }
  check_product(estimates, c("anchor", "estimator", "entity"),
                list(anchors, estimators, entities), "estimates")
  check_product(regions, c("anchor", "estimator", "entity", "budget", "method"),
                list(anchors, estimators, entities, budgets, methods), "regions")
  logical_columns(estimates, c("observed_success", "passes_gate"), "estimates")
  logical_columns(regions, c("available", "gate", "delivered"), "regions")
  logical_columns(failures, c("attempted", "success"), "failures")
  estimate_outer_index <- match(study02_key(estimates, c("m", "dataset_id")), outer_keys)
  all_estimates_valid <- tabulate(estimate_outer_index[!estimates$observed_success], nbins = nrow(outer)) == 0L
  if (any(outer$observed_success != all_estimates_valid)) {
    stop("Outer observed-success states disagree with all estimator/anchor fit states.", call. = FALSE)
  }
  ok <- estimates$observed_success
  if (any(!is.finite(as.matrix(estimates[ok, c("dx", "dy")]))) ||
      any(is.finite(as.matrix(estimates[!ok, c("dx", "dy")])) ) ||
      any(estimates$passes_gate & !ok)) {
    stop("Estimate success states and finite displacement values disagree.", call. = FALSE)
  }
  est_key <- c("m", "dataset_id", "anchor", "estimator", "entity")
  index <- match(study02_key(regions, est_key), study02_key(estimates, est_key))
  if (any(regions$delivered != (regions$available & regions$gate)) ||
      any(regions$available & !estimates$observed_success[index]) ||
      anyNA(regions$covered[regions$delivered]) ||
      anyNA(regions$rejects_zero[regions$delivered]) ||
      any(regions$covered[regions$delivered] == regions$rejects_zero[regions$delivered]) ||
      any(!is.na(regions$covered[!regions$delivered])) ||
      any(!is.na(regions$rejects_zero[!regions$delivered])) ||
      any(!is.finite(regions$area[regions$delivered]) | regions$area[regions$delivered] <= 0) ||
      anyNA(regions$n_valid) || any(regions$n_valid < 0 | regions$n_valid > regions$budget) ||
      any(regions$n_valid != floor(regions$n_valid)) ||
      any(regions$gate != (regions$n_valid >= 20L & regions$n_valid / regions$budget >= .95))) {
    stop("Region geometry, gate, null outcomes, or count accounting is inconsistent.", call. = FALSE)
  }
  primary_rows <- regions$budget == max(budgets)
  if (any(regions$gate[primary_rows] != estimates$passes_gate[index[primary_rows]])) {
    stop("Estimate primary-budget gates disagree with regions.", call. = FALSE)
  }
  failure_keys <- c("m", "dataset_id", "anchor", "estimator", "replicate_id")
  if (anyNA(failures[failure_keys]) || anyDuplicated(study02_key(failures, failure_keys)) ||
      any(!study02_key(failures, c("m", "dataset_id")) %in% outer_keys) ||
      any(!failures$anchor %in% anchors) || any(!failures$estimator %in% estimators) ||
      any(!failures$replicate_id %in% seq_len(max(budgets)))) {
    stop("Attempt ledger contains invalid or duplicate identifiers.", call. = FALSE)
  }
  pair_columns <- c("m", "dataset_id", "anchor", "estimator")
  pairs <- estimates[estimates$entity == "E015", ]
  pair_keys <- study02_key(pairs, pair_columns)
  attempt_index <- match(study02_key(failures, pair_columns), pair_keys)
  if (any(tabulate(attempt_index, nbins = nrow(pairs)) != max(budgets))) {
    stop("Every estimator must retain every planned primary-budget attempt, including unattempted placeholders.", call. = FALSE)
  }
  if (any(failures$attempted != pairs$observed_success[attempt_index]) ||
      any(failures$success & !failures$attempted)) {
    stop("Attempted states disagree with observed estimator validity.", call. = FALSE)
  }
  region_index <- match(study02_key(regions, pair_columns), pair_keys)
  for (b in budgets) {
    counts <- tabulate(attempt_index[failures$success & failures$replicate_id <= b], nbins = nrow(pairs))
    use <- regions$budget == b
    if (any(counts[region_index[use]] != regions$n_valid[use])) {
      stop("Attempt success counts do not reconcile with prefix-budget regions.", call. = FALSE)
    }
  }
  # Covariance and valid-count rows are repeated across methods and targets only
  # where statistically appropriate: each target has its own covariance.
  covariance_keys <- study02_key(regions, c("m", "dataset_id", "anchor", "estimator", "entity", "budget"))
  first <- match(covariance_keys, covariance_keys)
  for (column in c("n_valid", "var_dx", "var_dy", "cov_dx_dy")) {
    a <- regions[[column]]
    b <- a[first]
    if (any(is.na(a) != is.na(b)) || any(a[!is.na(a)] != b[!is.na(a)])) {
      stop("Candidate methods disagree on their common draw covariance or counts.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

study02_coverage_summary <- function(outer, estimates, regions) {
  keys <- c("m", "anchor", "estimator", "entity", "budget", "method")
  result <- lapply(study02_groups(regions, keys), function(x) {
    n <- sum(outer$m == x$m[1])
    delivered <- x$delivered
    counts <- c(covered = sum(x$covered[delivered]), delivered = sum(delivered))
    coverage <- study02_wilson(counts["covered"], counts["delivered"])
    delivery <- study02_wilson(counts["delivered"], n)
    yield <- study02_wilson(counts["covered"], n)
    e <- estimates[estimates$m == x$m[1] & estimates$anchor == x$anchor[1] &
                     estimates$estimator == x$estimator[1] & estimates$entity == x$entity[1], ]
    data.frame(x[1, keys], n_outer = n, n_observed_valid = sum(e$observed_success),
      n_available = sum(x$available), n_gate_passed = sum(x$gate),
      n_delivered = unname(counts["delivered"]), n_covered = unname(counts["covered"]),
      conditional_coverage = unname(coverage["estimate"]), coverage_mcse = unname(coverage["mcse"]),
      coverage_wilson_lower = unname(coverage["lower"]), coverage_wilson_upper = unname(coverage["upper"]),
      conditional_null_rejection = 1 - unname(coverage["estimate"]),
      delivery_fraction = unname(delivery["estimate"]), delivery_mcse = unname(delivery["mcse"]),
      delivery_wilson_lower = unname(delivery["lower"]), delivery_wilson_upper = unname(delivery["upper"]),
      operational_coverage_and_delivery = unname(yield["estimate"]), yield_mcse = unname(yield["mcse"]),
      yield_wilson_lower = unname(yield["lower"]), yield_wilson_upper = unname(yield["upper"]),
      mean_area_delivered = if (any(delivered)) mean(x$area[delivered]) else NA_real_,
      mean_normalized_area_delivered = if (any(delivered)) mean(x$area[delivered]) else NA_real_,
      row.names = NULL)
  })
  do.call(rbind, result)
}

study02_covariance_summary <- function(estimates, regions) {
  keys <- c("m", "anchor", "estimator", "entity", "budget")
  results <- lapply(study02_groups(regions[regions$method == "wald", ], keys), function(x) {
    e <- estimates[estimates$m == x$m[1] & estimates$anchor == x$anchor[1] &
                     estimates$estimator == x$estimator[1] & estimates$entity == x$entity[1], ]
    e <- e[match(x$dataset_id, e$dataset_id), ]
    use <- e$observed_success & x$n_valid >= 2L &
      is.finite(x$var_dx) & is.finite(x$var_dy) & is.finite(x$cov_dx_dy)
    d <- as.matrix(e[use, c("dx", "dy")])
    r <- x[use, ]
    n <- nrow(d)
    boot_trace <- r$var_dx + r$var_dy
    outer_cov <- mean_cov <- matrix(NA_real_, 2L, 2L)
    trace_ratio <- ratio_se <- ratio_min <- ratio_max <- NA_real_
    if (n >= 2L) {
      outer_cov <- stats::cov(d)
      mean_cov <- matrix(c(mean(r$var_dx), mean(r$cov_dx_dy), mean(r$cov_dx_dy), mean(r$var_dy)), 2L)
      outer_trace <- sum(diag(outer_cov))
      if (is.finite(outer_trace) && outer_trace > 0) {
        trace_ratio <- mean(boot_trace) / outer_trace
        if (n >= 4L) {
          centered_sq <- rowSums(sweep(d, 2L, colMeans(d), "-")^2)
          loo_outer_trace <- ((n - 1) * outer_trace - n / (n - 1) * centered_sq) / (n - 2)
          loo_mean_trace <- (sum(boot_trace) - boot_trace) / (n - 1)
          if (all(loo_outer_trace > 0)) {
            ratio_jack <- loo_mean_trace / loo_outer_trace
            ratio_se <- sqrt((n - 1) / n * sum((ratio_jack - mean(ratio_jack))^2))
          }
        }
      }
      vals <- eigen(outer_cov, symmetric = TRUE)$values
      if (all(is.finite(vals)) && vals[2] > 1e-12 * vals[1]) {
        inverse_chol <- solve(chol(outer_cov))
        ratios <- eigen(t(inverse_chol) %*% mean_cov %*% inverse_chol, symmetric = TRUE)$values
        ratio_min <- min(ratios)
        ratio_max <- max(ratios)
      }
    }
    q <- r$truth_statistic[is.finite(r$truth_statistic)]
    data.frame(x[1, keys], n_outer = nrow(x), n_observed_valid = sum(e$observed_success),
      n_covariance_pairs = n, n_delivered = sum(x$delivered),
      outer_var_dx = outer_cov[1, 1], outer_var_dy = outer_cov[2, 2], outer_cov_dx_dy = outer_cov[1, 2],
      mean_bootstrap_var_dx = mean_cov[1, 1], mean_bootstrap_var_dy = mean_cov[2, 2], mean_bootstrap_cov_dx_dy = mean_cov[1, 2],
      outer_covariance_trace = sum(diag(outer_cov)), mean_bootstrap_covariance_trace = sum(diag(mean_cov)),
      covariance_trace_ratio = trace_ratio, trace_ratio_jackknife_mcse = ratio_se,
      generalized_ratio_min = ratio_min, generalized_ratio_max = ratio_max,
      bootstrap_trace_cv = if (n >= 2L && mean(boot_trace) > 0) stats::sd(boot_trace) / mean(boot_trace) else NA_real_,
      mean_actual_mahalanobis_sq = if (length(q)) mean(q) else NA_real_,
      mean_actual_mahalanobis_mcse = study02_mcse(q),
      q90_actual_mahalanobis_sq = if (length(q)) unname(stats::quantile(q, .90, type = 7L)) else NA_real_,
      q95_actual_mahalanobis_sq = if (length(q)) unname(stats::quantile(q, .95, type = 7L)) else NA_real_,
      q99_actual_mahalanobis_sq = if (length(q)) unname(stats::quantile(q, .99, type = 7L)) else NA_real_,
      n_finite_mahalanobis = length(q),
      covariance_cohort = "matched observed-valid datasets with finite bootstrap covariance", row.names = NULL)
  })
  do.call(rbind, results)
}

study02_error_summary <- function(estimates) {
  keys <- c("m", "anchor", "estimator", "entity")
  rows <- list()
  for (x in study02_groups(estimates, keys)) for (cohort in c("observed_valid", "primary_budget_gate")) {
    use <- x$observed_success & (cohort == "observed_valid" | x$passes_gate)
    dx <- x$dx[use]
    dy <- x$dy[use]
    n <- length(dx)
    squared <- dx^2 + dy^2
    rmse <- if (n) sqrt(mean(squared)) else NA_real_
    rows[[length(rows) + 1L]] <- data.frame(x[1, keys], cohort = cohort,
      n_outer = nrow(x), n_selected = n,
      bias_dx = if (n) mean(dx) else NA_real_, bias_dy = if (n) mean(dy) else NA_real_,
      bias_dx_mcse = study02_mcse(dx), bias_dy_mcse = study02_mcse(dy), vector_rmse = rmse,
      rmse_mcse_delta = if (n > 1L && rmse > 0) study02_mcse(squared) / (2 * rmse) else if (n > 1L && rmse == 0) 0 else NA_real_,
      normalized_bias_dx = if (n) mean(dx) else NA_real_,
      normalized_bias_dy = if (n) mean(dy) else NA_real_,
      normalized_vector_rmse = rmse, row.names = NULL)
  }
  do.call(rbind, rows)
}

study02_paired_difference <- function(a, b) {
  if (length(a) != length(b) || anyNA(a) || anyNA(b)) stop("Paired differences require equally sized complete vectors.")
  delta <- as.numeric(b) - as.numeric(a)
  n <- length(delta)
  estimate <- if (n) mean(delta) else NA_real_
  se <- study02_mcse(delta)
  c(n_pairs = n, difference = estimate, mcse = se,
    lower = max(-1, estimate - 1.96 * se), upper = min(1, estimate + 1.96 * se),
    improved = sum(delta > 0), worsened = sum(delta < 0))
}

study02_paired_contrasts <- function(regions) {
  definitions <- list(anchor = c("original", "spread"),
                      estimator = c("refit_plugin", "refit_oracle"),
                      budget = c("199", "399"))
  keys <- c("m", "anchor", "estimator", "entity", "budget", "method")
  rows <- list()
  for (dimension in names(definitions)) {
    levels <- definitions[[dimension]]
    if (!all(levels %in% as.character(unique(regions[[dimension]])))) next
    x <- regions[as.character(regions[[dimension]]) %in% levels, ]
    other <- setdiff(keys, dimension)
    for (g in study02_groups(x, other)) {
      a <- g[as.character(g[[dimension]]) == levels[1], ]
      b <- g[as.character(g[[dimension]]) == levels[2], ]
      if (anyDuplicated(a$dataset_id) || anyDuplicated(b$dataset_id) ||
          !setequal(a$dataset_id, b$dataset_id)) stop("Contrasts require identical paired dataset keys.", call. = FALSE)
      b <- b[match(a$dataset_id, b$dataset_id), ]
      both <- a$delivered & b$delivered
      outcomes <- list(
        conditional_coverage_joint_delivery = list(a$covered[both], b$covered[both]),
        delivery = list(a$delivered, b$delivered),
        operational_yield = list(a$delivered & !is.na(a$covered) & a$covered,
                                 b$delivered & !is.na(b$covered) & b$covered))
      for (metric in names(outcomes)) {
        summary <- study02_paired_difference(outcomes[[metric]][[1]], outcomes[[metric]][[2]])
        meta <- a[1, keys]
        meta[[dimension]] <- if (dimension == "budget") NA_integer_ else "paired"
        rows[[length(rows) + 1L]] <- data.frame(meta,
          comparison_dimension = dimension, level_from = levels[1], level_to = levels[2],
          metric = metric, n_outer = nrow(a), n_joint_delivered = sum(both),
          as.list(summary), stringsAsFactors = FALSE, row.names = NULL)
      }
    }
  }
  do.call(rbind, rows)
}

study02_attempt_summary <- function(failures, budgets = c(199L, 399L)) {
  rows <- list()
  for (x in study02_groups(failures, c("m", "anchor", "estimator"))) for (budget in budgets) {
    z <- x[x$replicate_id <= budget, ]
    per_dataset <- study02_groups(z, "dataset_id")
    rates <- vapply(per_dataset, function(d) if (any(d$attempted))
      sum(d$attempted & !d$success) / sum(d$attempted) else NA_real_, numeric(1))
    finite_rates <- rates[is.finite(rates)]
    attempted <- sum(z$attempted)
    failed <- sum(z$attempted & !z$success)
    rows[[length(rows) + 1L]] <- data.frame(x[1, c("m", "anchor", "estimator")], budget = budget,
      n_outer = length(per_dataset), n_observed_valid = length(finite_rates),
      n_planned = nrow(z), n_attempted = attempted, n_unattempted = sum(!z$attempted),
      n_successful = sum(z$success), n_failed_after_attempt = failed,
      failure_fraction_of_attempted = if (attempted) failed / attempted else NA_real_,
      mean_outer_failure_fraction = if (length(finite_rates)) mean(finite_rates) else NA_real_,
      outer_failure_fraction_mcse = study02_mcse(finite_rates), row.names = NULL)
  }
  do.call(rbind, rows)
}

study02_tangent_summary <- function(tangent, regions, outer, primary_budget) {
  required <- c("m", "dataset_id", "anchor", "entity", "exact_var_dx", "exact_var_dy",
                "exact_cov_dx_dy", "embedding_trace", "alignment_trace", "cross_trace", "total_trace")
  if (!is.data.frame(tangent) || !all(required %in% names(tangent))) {
    stop("Tangent decomposition is missing required columns.", call. = FALSE)
  }
  keys <- c("m", "dataset_id", "anchor", "entity")
  if (anyDuplicated(study02_key(tangent, keys)) || anyNA(tangent[required]) ||
      any(!is.finite(as.matrix(tangent[setdiff(required, keys)])))) {
    stop("Tangent decomposition contains duplicate, missing, or nonfinite values.", call. = FALSE)
  }
  scale <- pmax(abs(tangent$total_trace), .Machine$double.eps)
  decomposition_error <- tangent$embedding_trace + tangent$alignment_trace + tangent$cross_trace - tangent$total_trace
  covariance_error <- tangent$exact_var_dx + tangent$exact_var_dy - tangent$total_trace
  if (any(abs(decomposition_error) > 1e-9 * scale) || any(abs(covariance_error) > 1e-9 * scale)) {
    stop("Tangent embedding, alignment, cross, and covariance traces do not reconcile.", call. = FALSE)
  }
  r <- regions[regions$estimator == "tangent_oracle" & regions$method == "wald" & regions$budget == primary_budget, ]
  index <- match(study02_key(r, keys), study02_key(tangent, keys))
  if (any(!study02_key(tangent, keys) %in% study02_key(r, keys))) {
    stop("Tangent decomposition contains unknown dataset/anchor/target keys.", call. = FALSE)
  }
  # Preserve all planned rows, including absent tangent decompositions.
  joined <- r[c("m", "dataset_id", "anchor", "entity", "delivered", "var_dx", "var_dy", "cov_dx_dy")]
  joined[setdiff(required, keys)] <- tangent[index, setdiff(required, keys), drop = FALSE]
  rows <- lapply(study02_groups(joined, c("m", "anchor", "entity")), function(x) {
    use <- is.finite(x$total_trace) & x$total_trace > 0 & is.finite(x$var_dx) & is.finite(x$var_dy)
    z <- x[use, ]
    n <- nrow(z)
    empirical <- z$var_dx + z$var_dy
    ratio <- empirical / z$total_trace
    difference <- empirical - z$total_trace
    mean_safe <- function(v) if (length(v)) mean(v) else NA_real_
    data.frame(x[1, c("m", "anchor", "entity")], budget = primary_budget,
      n_outer = sum(outer$m == x$m[1]), n_exact_available = sum(is.finite(x$total_trace)),
      n_paired_covariances = n, n_delivered = sum(x$delivered),
      mean_exact_conditional_trace = mean_safe(z$total_trace),
      mean_empirical_bootstrap_trace = mean_safe(empirical),
      mean_empirical_to_exact_trace_ratio = mean_safe(ratio),
      empirical_to_exact_ratio_mcse = study02_mcse(ratio),
      mean_empirical_minus_exact_trace = mean_safe(difference),
      empirical_minus_exact_trace_mcse = study02_mcse(difference),
      mean_embedding_trace = mean_safe(z$embedding_trace),
      mean_alignment_trace = mean_safe(z$alignment_trace),
      mean_cross_trace = mean_safe(z$cross_trace), mean_total_trace = mean_safe(z$total_trace),
      mean_alignment_fraction = mean_safe(z$alignment_trace / z$total_trace),
      mean_cross_fraction = mean_safe(z$cross_trace / z$total_trace),
      multinomial_variance_factor = (x$m[1] - 1) / x$m[1],
      row.names = NULL)
  })
  do.call(rbind, rows)
}

study02_write_figures <- function(coverage, covariance, contrasts, output_dir,
                                  retrospective = FALSE) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required for study figures.")
  palette <- c(refit_plugin = "#176B87", refit_oracle = "#B66A37", tangent_oracle = "#6C568C")
  estimator_labels <- c(refit_plugin = "Refit: observed frame", refit_oracle = "Refit: population frame", tangent_oracle = "Population tangent control")
  method_labels <- c(wald = "Wald ellipse", bootstrap_mahalanobis = "Empirical Mahalanobis ellipse", bootstrap_ball = "Euclidean error ball")
  theme <- ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = "bottom",
      legend.title = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, size = 9),
      plot.margin = ggplot2::margin(12, 15, 12, 12))
  percent <- function(x) paste0(round(100 * x), "%")
  save <- function(plot, filename, width, height) for (ext in c("png", "pdf")) {
    ggplot2::ggsave(file.path(output_dir, paste0(filename, ".", ext)), plot,
      width = width, height = height, units = "in", dpi = 300, bg = "white")
  }
  primary_budget <- max(coverage$budget)
  primary <- coverage[coverage$entity == "E015" & coverage$budget == primary_budget, ]
  primary$method <- factor(primary$method, names(method_labels), method_labels)
  p <- ggplot2::ggplot(primary, ggplot2::aes(m, conditional_coverage, color = estimator)) +
    ggplot2::geom_hline(yintercept = .95, linetype = "dashed", color = "#75818C") +
    ggplot2::geom_line(na.rm = TRUE) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = coverage_wilson_lower, ymax = coverage_wilson_upper), width = .04, na.rm = TRUE) +
    ggplot2::geom_point(size = 2, na.rm = TRUE) + ggplot2::facet_grid(anchor ~ method) +
    ggplot2::scale_x_log10(breaks = sort(unique(primary$m))) +
    ggplot2::scale_y_continuous(limits = c(0, 1), labels = percent) +
    ggplot2::scale_color_manual(values = palette, breaks = names(palette), labels = estimator_labels) +
    ggplot2::labs(title = if (retrospective) "Retrospective null diagnostics across unit-count prefixes" else
      "Independent null coverage across measurement-unit counts",
      subtitle = paste0("Primary target E015 | ", primary_budget, " paired-unit draws | Nominal 95% joint displacement regions"),
      x = "Independent measurement units", y = "Coverage among delivered regions",
      caption = "Bars: 95% Wilson Monte Carlo intervals. Population-frame and tangent methods are oracle diagnostics.\nCoverage conditions on delivery; complete delivery and failure denominators are reported separately.") + theme
  save(p, "calibration02-coverage", 12.6, 7.5)
  primary <- covariance[covariance$entity == "E015" & covariance$budget == primary_budget, ]
  primary$lower <- pmax(0, primary$covariance_trace_ratio - 1.96 * primary$trace_ratio_jackknife_mcse)
  primary$upper <- primary$covariance_trace_ratio + 1.96 * primary$trace_ratio_jackknife_mcse
  p <- ggplot2::ggplot(primary, ggplot2::aes(m, covariance_trace_ratio, color = estimator)) +
    ggplot2::geom_hline(yintercept = 1, linetype = "dashed", color = "#75818C") +
    ggplot2::geom_line(na.rm = TRUE) + ggplot2::geom_point(size = 2.3, na.rm = TRUE) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = .04, na.rm = TRUE) +
    ggplot2::facet_wrap(~anchor, nrow = 1L) +
    ggplot2::scale_x_log10(breaks = sort(unique(primary$m))) +
    ggplot2::scale_color_manual(values = palette, breaks = names(palette), labels = estimator_labels) +
    ggplot2::labs(title = "Bootstrap covariance compared with independent sampling variation",
      subtitle = "Primary target E015 | Mean bootstrap covariance trace / outer error covariance trace",
      x = "Independent measurement units", y = "Covariance trace ratio",
      caption = "Bars: estimate ± 1.96 outer-dataset jackknife MCSE (lower endpoint truncated at zero).\nRatios use matched datasets with finite covariance; no fitted inflation factor is applied.") + theme
  save(p, "calibration02-covariance-ratio", 10.6, 5.3)
  primary <- contrasts[contrasts$entity == "E015" & contrasts$method == "wald" &
    contrasts$metric == "conditional_coverage_joint_delivery" &
    ((contrasts$comparison_dimension != "budget" & contrasts$budget == primary_budget) |
       (contrasts$comparison_dimension == "budget" & contrasts$estimator == "refit_plugin")), ]
  primary$comparison <- c(anchor = "Spread minus original anchors", estimator = "Population minus observed frame", budget = "399 minus 199 draws")[primary$comparison_dimension]
  primary$series <- ifelse(primary$comparison_dimension == "anchor", primary$estimator, primary$anchor)
  contrast_palette <- c(palette, original = "#4F636F", spread = "#50846D")
  p <- ggplot2::ggplot(primary, ggplot2::aes(m, difference, color = series)) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "#75818C") +
    ggplot2::geom_line(na.rm = TRUE) + ggplot2::geom_point(size = 2.2, na.rm = TRUE) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = .04, na.rm = TRUE) +
    ggplot2::facet_wrap(~comparison, nrow = 1L) +
    ggplot2::scale_x_log10(breaks = sort(unique(primary$m))) +
    ggplot2::scale_y_continuous(labels = function(x) paste0(round(100 * x), " pp")) +
    ggplot2::scale_color_manual(values = contrast_palette,
      labels = c(estimator_labels, original = "Original anchors", spread = "Spread anchors")) +
    ggplot2::labs(title = "Paired comparisons isolate anchor, frame, and draw-budget changes",
      subtitle = "Primary target E015 | Wald regions | Positive differences favor the second condition",
      x = "Independent measurement units", y = "Coverage difference",
      caption = paste0("Bars: paired-dataset estimate ± 1.96 MCSE. Only joint-delivery pairs enter coverage contrasts.\n",
        if (primary_budget == 399L) "The 199-draw analysis uses the first 199 of the same 399 draws; methods are not independent samples." else
          "Single-budget retrospective diagnostic. Anchor and frame methods use the same outer panels and draws.")) + theme
  save(p, "calibration02-paired-contrasts", 12.6, 5.3)
  invisible(NULL)
}

study02_analyze <- function(output_dir, expected_outer = 240L,
                             expected_m = c(20L, 40L, 160L, 640L),
                             expected_budgets = c(199L, 399L), figures = TRUE) {
  read <- function(filename) {
    path <- file.path(output_dir, filename)
    if (!file.exists(path)) stop("Missing completed-study file: ", filename, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  outer <- read("outer.csv")
  estimates <- read("estimates.csv")
  regions <- read("regions.csv")
  failures <- read("failures.csv")
  tangent <- read("tangent_covariance.csv")
  study02_validate_analysis(outer, estimates, regions, failures, expected_outer, expected_m, expected_budgets)
  answer <- list(coverage = study02_coverage_summary(outer, estimates, regions),
    covariance = study02_covariance_summary(estimates, regions[regions$budget == max(expected_budgets), ]),
    errors = study02_error_summary(estimates), contrasts = study02_paired_contrasts(regions),
    attempts = study02_attempt_summary(failures, expected_budgets),
    tangent = study02_tangent_summary(tangent, regions, outer, max(expected_budgets)))
  for (name in names(answer)) utils::write.csv(answer[[name]],
    file.path(output_dir, paste0(name, "-summary.csv")), row.names = FALSE, na = "")
  if (figures) study02_write_figures(answer$coverage, answer$covariance, answer$contrasts, output_dir,
    retrospective = "stage" %in% names(outer) && any(grepl("retrospective", outer$stage)))
  writeLines(c("Study 02 analysis: targets are zero under the regular null; zero exclusion is null rejection.",
    "Coverage is conditional on delivery; operational yield and delivery use every planned outer dataset.",
    "Every paired comparison uses within-dataset differences; Monte Carlo SEs never pool entities or bootstrap draws as independent outer datasets.",
    "Covariance ratios use matched observed-valid datasets with finite bootstrap covariance and disclose the selected count.",
    "Study 02 input coordinates already use XX'/m. Displacements are in public-coordinate units divided by sqrt(m); areas are already divided by m. Normalized aliases are not divided again.",
    "Oracle estimators diagnose mechanisms and are not implementable confidence-region proposals for unknown populations.",
    "No fitted covariance inflation, post-outcome method selection, or power claims are made."),
    file.path(output_dir, "analysis-notes.txt"))
  invisible(answer)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) || length(args) > 4L) stop("Usage: Rscript analyze.R output_dir [expected_outer] [comma-separated-unit-counts] [comma-separated-budgets]")
  study02_analyze(args[1], expected_outer = if (length(args) >= 2L) as.integer(args[2]) else 240L,
    expected_m = if (length(args) >= 3L) as.integer(strsplit(args[3], ",", fixed = TRUE)[[1]]) else c(20L, 40L, 160L, 640L),
    expected_budgets = if (length(args) >= 4L) as.integer(strsplit(args[4], ",", fixed = TRUE)[[1]]) else c(199L, 399L))
}
