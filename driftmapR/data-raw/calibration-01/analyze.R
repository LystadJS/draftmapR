#!/usr/bin/env Rscript
# Analyze the frozen calibration-01 experiment; no simulation is run here.
# Rscript data-raw/calibration-01/analyze.R /path/to/completed-study-output
# The CLI always requires 80 independent datasets in each frozen scenario.

calibration_wilson <- function(successes, total, level = 0.95) {
  if (!is.numeric(successes) || !is.numeric(total) || length(successes) != 1L ||
      length(total) != 1L || any(!is.finite(c(successes, total))) ||
      total < 0 || successes < 0 || successes > total ||
      successes != floor(successes) || total != floor(total)) {
    stop("Wilson counts must be valid integer counts.", call. = FALSE)
  }
  if (total == 0) return(c(estimate = NA_real_, mcse = NA_real_,
                         lower = NA_real_, upper = NA_real_))
  p <- successes / total
  z <- stats::qnorm((1 + level) / 2)
  denominator <- 1 + z^2 / total
  center <- (p + z^2 / (2 * total)) / denominator
  half <- z * sqrt(p * (1 - p) / total + z^2 / (4 * total^2)) / denominator
  c(estimate = p, mcse = sqrt(p * (1 - p) / total),
    lower = max(0, center - half), upper = min(1, center + half))
}

calibration_analysis_keys <- function(x, columns) {
  do.call(paste, c(x[columns], sep = "\r"))
}

calibration_validate_analysis <- function(outer, estimates, regions, attempts,
                                         expected_outer = 80L) {
  require_columns <- function(x, required, label) {
    if (!is.data.frame(x) || !all(required %in% names(x))) {
      stop(label, " is missing required columns.", call. = FALSE)
    }
  }
  require_columns(outer, c("scenario", "dataset_id", "m", "rare_count",
                           "observed_success", "bootstrap_started", "n_attempted",
                           "n_valid", "n_failed", "passes_gate",
                           "rare_weight_mean_all", "rare_weight_mean_success"), "outer-results")
  require_columns(estimates, c("scenario", "dataset_id", "entity", "target_role",
                               "error_dx", "error_dy", "normalized_error_dx",
                               "normalized_error_dy", "passes_gate"), "estimates")
  require_columns(regions, c("scenario", "dataset_id", "entity", "target_role",
                             "method", "policy", "region_computable", "gate_passed",
                             "delivered", "covered", "rejects_zero", "area",
                             "normalized_area"), "regions")
  require_columns(attempts, c("scenario", "dataset_id", "replicate_id", "success",
                              "rare_weight"), "bootstrap-attempts")
  scenarios <- c("regular_null", "regular_movement", "few_units", "high_noise",
                 "rare_axis", "dependent_units")
  methods <- c("wald", "bootstrap_mahalanobis", "bootstrap_ball")
  entities <- c("E015", "E003", "E006")
  policies <- c("production", "relaxed")
  if (!setequal(unique(outer$scenario), scenarios) ||
      any(table(factor(outer$scenario, levels = scenarios)) != expected_outer) ||
      anyDuplicated(calibration_analysis_keys(outer, c("scenario", "dataset_id")))) {
    stop("Outer results must contain exactly ", expected_outer,
         " unique datasets in every frozen scenario.", call. = FALSE)
  }
  if (anyNA(outer[c("scenario", "dataset_id", "m", "observed_success", "passes_gate",
                    "bootstrap_started", "n_attempted", "n_valid", "n_failed")]) ||
      any(outer$passes_gate & !outer$observed_success) ||
      any(outer$n_valid + outer$n_failed != outer$n_attempted)) {
    stop("Outer success/gate/attempt accounting is inconsistent.", call. = FALSE)
  }
  outer_key <- calibration_analysis_keys(outer, c("scenario", "dataset_id"))
  for (table_name in c("estimates", "regions", "attempts")) {
    x <- get(table_name)
    if (any(!calibration_analysis_keys(x, c("scenario", "dataset_id")) %in% outer_key)) {
      stop(table_name, " contains unknown outer datasets.", call. = FALSE)
    }
  }
  region_key <- c("scenario", "dataset_id", "entity", "method", "policy")
  if (nrow(regions) != nrow(outer) * length(entities) * length(methods) * length(policies) ||
      anyDuplicated(calibration_analysis_keys(regions, region_key)) ||
      !setequal(unique(regions$entity), entities) ||
      !setequal(unique(regions$method), methods) ||
      !setequal(unique(regions$policy), policies)) {
    stop("Regions must include every dataset, target, candidate, and policy exactly once.",
         call. = FALSE)
  }
  if (anyNA(regions[c("region_computable", "gate_passed", "delivered")]) ||
      any(regions$delivered & !regions$region_computable) ||
      any(regions$delivered & regions$policy == "production" & !regions$gate_passed) ||
      anyNA(regions$covered[regions$delivered]) ||
      anyNA(regions$rejects_zero[regions$delivered])) {
    stop("Delivered-region geometry, gate, or outcome accounting is inconsistent.", call. = FALSE)
  }
  estimate_key <- calibration_analysis_keys(estimates, c("scenario", "dataset_id", "entity"))
  if (anyDuplicated(estimate_key) || nrow(estimates) != sum(outer$observed_success) * 3L ||
      any(!estimates$entity %in% entities) ||
      any(!calibration_analysis_keys(estimates, c("scenario", "dataset_id")) %in%
          outer_key[outer$observed_success]) ||
      any(!is.finite(as.matrix(estimates[c("error_dx", "error_dy",
                                           "normalized_error_dx", "normalized_error_dy")])))) {
    stop("Estimates must contain three finite target errors per observed-valid dataset.",
         call. = FALSE)
  }
  index <- match(calibration_analysis_keys(estimates, c("scenario", "dataset_id")), outer_key)
  if (any(estimates$passes_gate != outer$passes_gate[index]) ||
      any(abs(estimates$normalized_error_dx - estimates$error_dx / sqrt(outer$m[index])) > 1e-8) ||
      any(abs(estimates$normalized_error_dy - estimates$error_dy / sqrt(outer$m[index])) > 1e-8)) {
    stop("Estimate normalization or gate labels disagree with outer records.", call. = FALSE)
  }
  if (anyNA(attempts$success) ||
      anyDuplicated(calibration_analysis_keys(attempts,
                                             c("scenario", "dataset_id", "replicate_id")))) {
    stop("Bootstrap attempt ledger contains missing success states or duplicate attempts.", call. = FALSE)
  }
  attempt_index <- match(calibration_analysis_keys(attempts, c("scenario", "dataset_id")), outer_key)
  if (any(tabulate(attempt_index, nbins = nrow(outer)) != outer$n_attempted) ||
      any(tabulate(attempt_index[attempts$success], nbins = nrow(outer)) != outer$n_valid)) {
    stop("Bootstrap attempt ledger does not reconcile with outer counts.", call. = FALSE)
  }
  invisible(TRUE)
}

calibration_coverage_summary <- function(outer, regions) {
  groups <- split(regions, calibration_analysis_keys(
    regions, c("scenario", "entity", "method", "policy")))
  rows <- lapply(groups, function(x) {
    dataset <- outer[outer$scenario == x$scenario[1L], , drop = FALSE]
    delivered <- x$delivered
    n_delivered <- sum(delivered)
    n_covered <- sum(x$covered[delivered])
    coverage <- calibration_wilson(n_covered, n_delivered)
    zero <- calibration_wilson(sum(x$rejects_zero[delivered]), n_delivered)
    data.frame(
      scenario = x$scenario[1L], entity = x$entity[1L], target_role = x$target_role[1L],
      method = x$method[1L], policy = x$policy[1L], n_outer = nrow(dataset),
      n_observed_valid = sum(dataset$observed_success),
      n_bootstrap_started = sum(dataset$bootstrap_started),
      n_gate_passed = sum(dataset$passes_gate), n_computable = sum(x$region_computable),
      n_delivered = n_delivered, n_covered = n_covered,
      conditional_coverage = unname(coverage["estimate"]),
      coverage_mcse = unname(coverage["mcse"]),
      coverage_wilson_lower = unname(coverage["lower"]),
      coverage_wilson_upper = unname(coverage["upper"]),
      delivery_fraction = n_delivered / nrow(dataset),
      operational_coverage_and_delivery = n_covered / nrow(dataset),
      conditional_zero_exclusion = unname(zero["estimate"]),
      zero_exclusion_mcse = unname(zero["mcse"]),
      zero_exclusion_wilson_lower = unname(zero["lower"]),
      zero_exclusion_wilson_upper = unname(zero["upper"]),
      zero_exclusion_interpretation = if (x$scenario[1L] == "regular_null")
        "null_rejection" else "descriptive_zero_exclusion",
      mean_area_delivered = if (n_delivered) mean(x$area[delivered]) else NA_real_,
      mean_normalized_area_delivered = if (n_delivered)
        mean(x$normalized_area[delivered]) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

calibration_selection_summary <- function(outer, estimates) {
  rows <- list()
  for (scenario in unique(outer$scenario)) {
    for (entity in c("E015", "E003", "E006")) {
      x <- estimates[estimates$scenario == scenario & estimates$entity == entity, , drop = FALSE]
      for (cohort in c("all_observed_valid", "production_gate")) {
        selected <- if (cohort == "production_gate") x[x$passes_gate, , drop = FALSE] else x
        n <- nrow(selected)
        dx <- selected$normalized_error_dx
        dy <- selected$normalized_error_dy
        squared <- dx^2 + dy^2
        rmse <- if (n) sqrt(mean(squared)) else NA_real_
        rows[[length(rows) + 1L]] <- data.frame(
          scenario = scenario, entity = entity,
          target_role = if (entity == "E015") "primary" else "secondary",
          cohort = cohort, n_outer = sum(outer$scenario == scenario),
          n_observed_valid = nrow(x), n_selected = n,
          fraction_of_outer = n / sum(outer$scenario == scenario),
          normalized_bias_dx = if (n) mean(dx) else NA_real_,
          normalized_bias_dy = if (n) mean(dy) else NA_real_,
          bias_dx_mcse = if (n > 1L) stats::sd(dx) / sqrt(n) else NA_real_,
          bias_dy_mcse = if (n > 1L) stats::sd(dy) / sqrt(n) else NA_real_,
          normalized_vector_bias_norm = if (n) sqrt(mean(dx)^2 + mean(dy)^2) else NA_real_,
          normalized_vector_rmse = rmse,
          rmse_mcse_delta = if (n > 1L && is.finite(rmse) && rmse > 0)
            stats::sd(squared) / (2 * rmse * sqrt(n)) else if (n > 1L && rmse == 0)
              0 else NA_real_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

calibration_rare_summary <- function(outer, attempts) {
  rare <- outer[outer$scenario == "rare_axis", , drop = FALSE]
  ledger <- attempts[attempts$scenario == "rare_axis", , drop = FALSE]
  record <- function(type, cohort, rare_count = NA_integer_, n_datasets = NA_integer_,
                     denominator = NA_integer_, proportion = NA_real_, mean = NA_real_,
                     mcse = NA_real_, lower = NA_real_, upper = NA_real_,
                     n_attempted = NA_integer_, n_failed = NA_integer_,
                     zero_rare_attempts = NA_integer_, zero_rare_failed = NA_integer_,
                     positive_rare_failed = NA_integer_,
                     theoretical_zero_rare_probability = NA_real_,
                     n_observed_valid = NA_integer_, n_gate_passed = NA_integer_,
                     actual_failure_fraction = NA_real_) {
    data.frame(type, cohort, rare_count, n_datasets, denominator, proportion,
               mean, mcse, lower, upper, n_attempted, n_failed, zero_rare_attempts,
               zero_rare_failed, positive_rare_failed,
               theoretical_zero_rare_probability, n_observed_valid, n_gate_passed,
               actual_failure_fraction, stringsAsFactors = FALSE)
  }
  rows <- list()
  cohorts <- list(all_outer = rep(TRUE, nrow(rare)),
                  observed_valid = rare$observed_success,
                  production_gate = rare$passes_gate)
  for (cohort in names(cohorts)) {
    select <- cohorts[[cohort]]
    for (k in 0:max(rare$m)) {
      count <- sum(rare$rare_count[select] == k)
      rows[[length(rows) + 1L]] <- record("K_composition", cohort, k, count, sum(select),
                                        if (sum(select)) count / sum(select) else NA_real_)
    }
  }
  paired <- is.finite(rare$rare_weight_mean_all) & is.finite(rare$rare_weight_mean_success)
  multiplicities <- list(
    all_planned_available = rare$rare_weight_mean_all[is.finite(rare$rare_weight_mean_all)],
    all_planned_paired = rare$rare_weight_mean_all[paired],
    successful_paired = rare$rare_weight_mean_success[paired],
    success_minus_planned_paired = rare$rare_weight_mean_success[paired] - rare$rare_weight_mean_all[paired]
  )
  for (cohort in names(multiplicities)) {
    x <- multiplicities[[cohort]]
    mcse <- if (length(x) > 1L) stats::sd(x) / sqrt(length(x)) else NA_real_
    value <- if (length(x)) mean(x) else NA_real_
    rows[[length(rows) + 1L]] <- record("draw_multiplicity", cohort,
                                      n_datasets = length(x), mean = value, mcse = mcse,
                                      lower = value - 1.96 * mcse, upper = value + 1.96 * mcse)
  }
  for (k in 0:max(rare$m)) {
    subset <- rare[rare$rare_count == k, , drop = FALSE]
    draws <- ledger[ledger$dataset_id %in% subset$dataset_id, , drop = FALSE]
    rows[[length(rows) + 1L]] <- record(
      "bootstrap_failure_by_K", "all_planned", k, nrow(subset),
      n_attempted = nrow(draws), n_failed = sum(!draws$success),
      zero_rare_attempts = sum(draws$rare_weight == 0),
      zero_rare_failed = sum(draws$rare_weight == 0 & !draws$success),
      positive_rare_failed = sum(draws$rare_weight > 0 & !draws$success),
      theoretical_zero_rare_probability = (1 - k / unique(rare$m))^unique(rare$m),
      n_observed_valid = sum(subset$observed_success),
      n_gate_passed = sum(subset$passes_gate),
      actual_failure_fraction = if (nrow(draws)) mean(!draws$success) else NA_real_
    )
  }
  do.call(rbind, rows)
}

calibration_analysis_theme <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 3,
                                        color = "#162B3B", margin = ggplot2::margin(b = 8)),
      plot.subtitle = ggplot2::element_text(color = "#455A64", margin = ggplot2::margin(b = 12)),
      strip.text = ggplot2::element_text(face = "bold", color = "#162B3B"),
      legend.position = "bottom", legend.title = ggplot2::element_blank(),
      plot.caption = ggplot2::element_text(size = base_size - 1, color = "#455A64", hjust = 0),
      plot.margin = ggplot2::margin(12, 18, 10, 12)
    )
}

calibration_write_figures <- function(outer, coverage, selection, rare_summary, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required for figures.")
  scenarios <- c("regular_null", "regular_movement", "few_units", "high_noise",
                 "rare_axis", "dependent_units")
  labels <- c("Whole-map null", "Regular movement", "Few units", "High noise",
              "Rare second axis", "Dependent units")
  scenario_factor <- function(x) factor(x, levels = rev(scenarios), labels = rev(labels))
  method_factor <- function(x) factor(x, c("wald", "bootstrap_mahalanobis", "bootstrap_ball"),
                                     c("Wald ellipse", "Empirical Mahalanobis ellipse", "Euclidean error ball"))
  percent <- function(x) paste0(round(100 * x), "%")
  save <- function(plot, filename, width, height) {
    for (extension in c("png", "pdf")) {
      ggplot2::ggsave(file.path(output_dir, paste0(filename, ".", extension)), plot,
                     width = width, height = height, units = "in", dpi = 300,
                     bg = "white", limitsize = FALSE)
    }
  }
  primary <- coverage[coverage$entity == "E015", , drop = FALSE]
  coverage_panel <- data.frame(primary[c("scenario", "method", "policy")],
                               metric = "Conditional coverage",
                               estimate = primary$conditional_coverage,
                               lower = primary$coverage_wilson_lower,
                               upper = primary$coverage_wilson_upper)
  delivery_panel <- data.frame(primary[c("scenario", "method", "policy")],
                               metric = "Region delivery / 80 datasets",
                               estimate = primary$delivery_fraction,
                               lower = primary$delivery_fraction,
                               upper = primary$delivery_fraction)
  chart <- rbind(coverage_panel, delivery_panel)
  chart$scenario <- scenario_factor(chart$scenario)
  chart$method <- method_factor(chart$method)
  chart$policy <- factor(chart$policy, c("production", "relaxed"),
                         c("Production gate", "Relaxed gate"))
  chart$metric <- factor(chart$metric, c("Conditional coverage", "Region delivery / 80 datasets"))
  target <- unique(chart[chart$metric == "Conditional coverage", c("metric", "method")])
  target$threshold <- .95
  dodge <- ggplot2::position_dodge(width = .48)
  figure1 <- ggplot2::ggplot(chart, ggplot2::aes(estimate, scenario, color = policy)) +
    ggplot2::geom_vline(data = target, ggplot2::aes(xintercept = threshold), linetype = "dashed",
                       color = "#85939C", linewidth = .5, inherit.aes = FALSE) +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper),
                           orientation = "y", position = dodge, width = .12,
                           linewidth = .65, na.rm = TRUE) +
    ggplot2::geom_point(position = dodge, size = 2.4, na.rm = TRUE) +
    ggplot2::facet_grid(metric ~ method) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = c(0, .25, .5, .75, 1), labels = percent) +
    ggplot2::scale_color_manual(values = c("Production gate" = "#166B86", "Relaxed gate" = "#B06E30")) +
    ggplot2::labs(title = "Coverage and delivery answer different questions",
                  subtitle = "Primary target E015 | Three nominal 95% joint displacement-vector regions",
                  x = NULL, y = NULL,
                  caption = paste("Coverage conditions on delivery; bars are 95% Wilson Monte Carlo intervals.",
                                  "Delivery uses all 80 outer attempts. Missing coverage points mean no region was delivered.")) +
    calibration_analysis_theme(10)
  save(figure1, "calibration-coverage-delivery", 12.4, 7.6)

  selected <- selection[selection$entity == "E015", , drop = FALSE]
  metrics <- c("normalized_bias_dx", "normalized_bias_dy", "normalized_vector_rmse")
  standard_errors <- c("bias_dx_mcse", "bias_dy_mcse", "rmse_mcse_delta")
  metric_labels <- c("Bias in dx / sqrt(m)", "Bias in dy / sqrt(m)", "Vector RMSE / sqrt(m)")
  parts <- lapply(seq_along(metrics), function(i) {
    value <- selected[[metrics[i]]]
    se <- selected[[standard_errors[i]]]
    data.frame(selected[c("scenario", "cohort")], metric = metric_labels[i],
               estimate = value, lower = if (i == 3L) pmax(0, value - 1.96 * se) else value - 1.96 * se,
               upper = value + 1.96 * se)
  })
  chart2 <- do.call(rbind, parts)
  chart2$scenario <- scenario_factor(chart2$scenario)
  chart2$cohort <- factor(chart2$cohort, c("all_observed_valid", "production_gate"),
                          c("All observed-valid datasets", "Production-gate subset"))
  chart2$metric <- factor(chart2$metric, metric_labels)
  figure2 <- ggplot2::ggplot(chart2, ggplot2::aes(estimate, scenario, color = cohort)) +
    ggplot2::geom_vline(xintercept = 0, color = "#A3ADB4", linewidth = .4) +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper), orientation = "y",
                           position = dodge, width = .12, linewidth = .65, na.rm = TRUE) +
    ggplot2::geom_point(position = dodge, size = 2.6, na.rm = TRUE) +
    ggplot2::facet_wrap(~metric, scales = "free_x", nrow = 1) +
    ggplot2::scale_color_manual(values = c("All observed-valid datasets" = "#667786",
                                          "Production-gate subset" = "#166B86")) +
    ggplot2::labs(title = "The success gate changes which estimation errors are retained",
                  subtitle = "Primary target E015 | Errors use the population embedding target and a common evaluation frame",
                  x = NULL, y = NULL,
                  caption = paste("Bars show approximate 95% Monte Carlo intervals; RMSE uses the delta method.",
                                  "Subsets overlap. These are selection contrasts, not causal effects.")) +
    calibration_analysis_theme(10)
  save(figure2, "calibration-selection-bias", 12.2, 4.9)

  composition <- rare_summary[rare_summary$type == "K_composition", , drop = FALSE]
  composition <- composition[composition$rare_count <= max(outer$rare_count, na.rm = TRUE), ]
  composition$cohort <- factor(composition$cohort,
                               c("all_outer", "observed_valid", "production_gate"),
                               c("All outer attempts", "Observed-valid", "Production gate"))
  left <- ggplot2::ggplot(composition, ggplot2::aes(factor(rare_count), proportion, fill = cohort)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = .8), width = .72, na.rm = TRUE) +
    ggplot2::scale_y_continuous(labels = percent, expand = ggplot2::expansion(mult = c(0, .06))) +
    ggplot2::scale_fill_manual(values = c("All outer attempts" = "#B1BEC6", "Observed-valid" = "#6B839C",
                                         "Production gate" = "#166B86")) +
    ggplot2::labs(title = "Dataset selection changes rare-unit composition",
                  subtitle = "Proportions use each retained cohort as their denominator",
                  x = "Observed rare units K (out of 12)", y = "Fraction of cohort",
                  caption = "K = 0 has no identifiable second axis. Failed observed fits remain in the outer denominator.") +
    calibration_analysis_theme(10) + ggplot2::theme(legend.position = "bottom")
  rare <- outer[outer$scenario == "rare_axis" &
                  is.finite(outer$rare_weight_mean_all) & is.finite(outer$rare_weight_mean_success), ]
  rare$gate <- factor(rare$passes_gate, c(FALSE, TRUE), c("Below production gate", "Passes production gate"))
  right <- ggplot2::ggplot(rare, ggplot2::aes(rare_weight_mean_all, rare_weight_mean_success, color = gate)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#85939C", linewidth = .5) +
    ggplot2::geom_point(size = 2.5, alpha = .8) +
    ggplot2::scale_color_manual(values = c("Below production gate" = "#B06E30", "Passes production gate" = "#166B86"),
                                drop = FALSE) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = "Successful draws retain a selected unit mix",
                  subtitle = "One point per observed-valid outer dataset",
                  x = "Mean rare-unit multiplicity: all planned draws",
                  y = "Mean rare-unit multiplicity: successful draws",
                  caption = "Dashed line: equal means. Failed vectors are never imputed.") +
    calibration_analysis_theme(10)
  draw_rare <- function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(layout = grid::grid.layout(1L, 2L)))
    print(left, vp = grid::viewport(layout.pos.row = 1L, layout.pos.col = 1L), newpage = FALSE)
    print(right, vp = grid::viewport(layout.pos.row = 1L, layout.pos.col = 2L), newpage = FALSE)
    grid::popViewport()
  }
  for (extension in c("png", "pdf")) {
    file <- file.path(output_dir, paste0("calibration-rare-unit-selection.", extension))
    if (extension == "png") grDevices::png(file, width = 13.2, height = 5.1,
                                            units = "in", res = 300, bg = "white") else {
      grDevices::pdf(file, width = 13.2, height = 5.1, bg = "white")
    }
    tryCatch(draw_rare(), finally = grDevices::dev.off())
  }
  invisible(NULL)
}

calibration_analyze <- function(output_dir, expected_outer = 80L, figures = TRUE) {
  if (!dir.exists(output_dir)) stop("The completed-study output directory does not exist.")
  read <- function(filename) {
    path <- file.path(output_dir, filename)
    if (!file.exists(path)) stop("Missing completed-study file: ", filename, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  outer <- read("outer-results.csv")
  estimates <- read("estimates.csv")
  regions <- read("regions.csv")
  attempts <- read("bootstrap-attempts.csv")
  calibration_validate_analysis(outer, estimates, regions, attempts, expected_outer)
  coverage <- calibration_coverage_summary(outer, regions)
  selection <- calibration_selection_summary(outer, estimates)
  rare <- calibration_rare_summary(outer, attempts)
  write <- function(x, filename) utils::write.csv(x, file.path(output_dir, filename),
                                                row.names = FALSE, na = "")
  write(coverage, "coverage-summary.csv")
  write(selection, "selection-summary.csv")
  write(rare, "rare-selection-summary.csv")
  if (figures) calibration_write_figures(outer, coverage, selection, rare, output_dir)
  invisible(list(coverage = coverage, selection = selection, rare = rare))
}

if (sys.nframe() == 0L) {
  arguments <- commandArgs(trailingOnly = TRUE)
  if (length(arguments) != 1L) {
    stop("Usage: Rscript data-raw/calibration-01/analyze.R completed-study-output", call. = FALSE)
  }
  calibration_analyze(arguments[[1L]], expected_outer = 80L, figures = TRUE)
}
