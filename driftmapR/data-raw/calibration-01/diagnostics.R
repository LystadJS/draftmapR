#!/usr/bin/env Rscript
# POST HOC auxiliary diagnostics, specified after study 01 outcomes.
# These never alter the frozen regions, thresholds, draws, or coverage analysis.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript diagnostics.R completed-study-output")
p <- args[1L]
outer <- read.csv(file.path(p, "outer-results.csv"))
estimates <- read.csv(file.path(p, "estimates.csv"))
regions <- read.csv(file.path(p, "regions.csv"))
ratios <- do.call(rbind, lapply(unique(outer$scenario), function(s) {
  x <- estimates[estimates$scenario == s & estimates$entity == "E015", ]
  z <- regions[regions$scenario == s & regions$entity == "E015" &
    regions$method == "wald" & regions$policy == "relaxed" &
    regions$dataset_id %in% x$dataset_id, ]
  outer_trace <- sum(diag(cov(x[c("error_dx", "error_dy")])))
  boot_trace <- mean(z$var_dx + z$var_dy)
  data.frame(scenario = s, entity = "E015", n_outer_valid = nrow(x),
    outer_error_covariance_trace = outer_trace,
    mean_bootstrap_covariance_trace = boot_trace,
    trace_ratio = boot_trace / outer_trace,
    mean_squared_mahalanobis_error = mean(z$truth_statistic),
    q95_squared_mahalanobis_error = unname(quantile(z$truth_statistic, 0.95, type = 7)),
    frozen_wald_cutoff = qchisq(0.95, 2), post_hoc = TRUE)
}))
write.csv(ratios, file.path(p, "posthoc-covariance-diagnostics.csv"), row.names = FALSE)
k <- 0:12
omit <- (1 - k / 12)^12
benchmarks <- data.frame(rare_count = k, outer_probability = dbinom(k, 12, .15),
  omission_probability = omit,
  planned_mean_rare_multiplicity = k,
  successful_mean_if_omission_only = ifelse(k > 0, k / (1 - omit), NA),
  probability_production_gate_if_omission_only = pbinom(9, 199, omit))
write.csv(benchmarks, file.path(p, "analytic-rare-selection-benchmarks.csv"), row.names = FALSE)
writeLines(c(
  "Analytic context derived after the main study; no analysis was changed.",
  paste("Probability observed K=0:", benchmarks$outer_probability[1L]),
  paste("Expected production delivery if omission is the only failure:",
    sum(benchmarks$outer_probability * benchmarks$probability_production_gate_if_omission_only)),
  "Increasing B refines the draw approximation; it cannot restore absent axes or repair between-unit dependence."),
  file.path(p, "analytic-rare-selection-benchmarks.txt"))
computing <- do.call(rbind, lapply(unique(outer$scenario), function(s) {
  all <- outer[outer$scenario == s, ]
  x <- all[all$observed_success, ]
  data.frame(scenario = s, n_outer = nrow(all), n_observed_valid = nrow(x),
    attempted_refits = sum(x$n_attempted), failed_refits = sum(x$n_failed),
    median_elapsed_seconds_valid = median(x$elapsed_seconds),
    median_retained_bytes_valid = median(x$retained_bytes),
    maximum_retained_bytes = max(all$retained_bytes),
    min_observed_gap = min(x$obs_eigengap_min),
    median_observed_gap = median(x$obs_eigengap_min),
    population_gap = unique(all$pop_eigengap_min))
}))
write.csv(computing, file.path(p, "computational-summary.csv"), row.names = FALSE)
