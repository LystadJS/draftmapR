#!/usr/bin/env Rscript
# Frozen study 04 analysis. No random generation, cutoff fitting, or tuning.

study04_primary_replication <- function(coverage) {
  declarations <- data.frame(case_id = c("regular_null_m40", "regular_null_m160"),
    entity = c("E006", "E003"), historical_covered = c(109L, 110L),
    historical_delivered = 120L, stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(declarations)), function(i) {
    d <- declarations[i, ]
    x <- coverage[coverage$case_id == d$case_id & coverage$entity == d$entity &
      coverage$method == "jackknife_studentized" & coverage$policy == "production", ]
    if (nrow(x) != 1L) stop("Each frozen primary replication needs exactly one summary row.")
    p <- if (x$n_delivered) stats::pbinom(x$n_covered, x$n_delivered, .95) else NA_real_
    data.frame(x, historical_covered = d$historical_covered,
      historical_delivered = d$historical_delivered, nominal = .95,
      alternative = "conditional coverage less than 0.95", p_one_sided = p,
      bonferroni_alpha = .025, p_bonferroni = if (is.finite(p)) min(1, 2 * p) else NA_real_,
      rejects_nominal_after_multiplicity = if (is.finite(p)) p <= .025 else NA,
      scope = "Fresh panels only; historical counts are not pooled; nonrejection is not evidence of equivalence",
      selection_caution = if (x$n_delivered == x$n_outer) "All planned panels delivered" else
        "Conditional test is selected by delivery; inspect operational yield and failure accounting", row.names = NULL)
  })
  do.call(rbind, rows)
}

study04_match <- function(a, b, columns, label) {
  ka <- study03_key(a, columns); kb <- study03_key(b, columns)
  if (anyDuplicated(ka) || anyDuplicated(kb) || !setequal(ka, kb)) {
    stop(label, " require identical unique planned keys.", call. = FALSE)
  }
  b[match(ka, kb), , drop = FALSE]
}

study04_frame_agreement <- function(core, frame, tolerance = 1e-9) {
  keys <- c("case_id", "scenario", "m", "dataset_id", "entity")
  frame <- study04_match(core, frame, keys, "Frame point comparisons")
  both <- core$observed_success & frame$observed_success
  if (any(frame$observed_success & !core$observed_success) ||
      any(core$truth_dx != frame$truth_dx | core$truth_dy != frame$truth_dy)) {
    stop("Frame observation status or population truth disagrees with core.")
  }
  difference <- rep(NA_real_, nrow(core))
  difference[both] <- pmax(abs(core$dx[both] - frame$dx[both]), abs(core$dy[both] - frame$dy[both]))
  if (any(!is.finite(difference[both])) || any(difference[both] > tolerance)) {
    stop("Observed population-frame points differ beyond the frozen tolerance.")
  }
  out <- data.frame(core[keys], core_observed_success = core$observed_success,
    frame_observed_success = frame$observed_success, jointly_observed = both,
    max_absolute_point_difference = difference, tolerance = tolerance)
  summary <- lapply(study03_groups(out, c("case_id", "scenario", "m", "entity")), function(x) {
    data.frame(x[1L, c("case_id", "scenario", "m", "entity")], n_outer = nrow(x),
      n_core_observed = sum(x$core_observed_success), n_frame_observed = sum(x$frame_observed_success),
      n_jointly_observed = sum(x$jointly_observed), n_oracle_only_failure = sum(x$core_observed_success & !x$frame_observed_success),
      max_absolute_point_difference = if (any(x$jointly_observed)) max(x$max_absolute_point_difference[x$jointly_observed]) else NA_real_)
  })
  list(by_panel = out, summary = do.call(rbind, summary))
}

study04_frame_comparisons <- function(core, frame) {
  keys <- c("case_id", "scenario", "m", "dataset_id", "entity", "method")
  frame <- study04_match(core, frame, keys, "Frame region comparisons")
  rows <- list()
  for (index in split(seq_len(nrow(core)), study03_key(core, setdiff(keys, "dataset_id")))) {
    a <- core[index, ]; b <- frame[index, ]; both <- a$delivered & b$delivered
    finite_cov <- is.finite(a$var_dx) & is.finite(a$var_dy) & is.finite(a$cov_dx_dy) &
      is.finite(b$var_dx) & is.finite(b$var_dy) & is.finite(b$cov_dx_dy)
    positive_trace <- finite_cov & (a$var_dx + a$var_dy > 0) & (b$var_dx + b$var_dy > 0)
    outcomes <- list(
      conditional_coverage_joint_delivery = list(a$covered[both], b$covered[both]),
      conditional_zero_exclusion_joint_delivery = list(a$rejects_zero[both], b$rejects_zero[both]),
      delivery = list(a$delivered, b$delivered),
      operational_yield = list(a$delivered & !is.na(a$covered) & a$covered,
        b$delivered & !is.na(b$covered) & b$covered),
      area_joint_delivery = list(a$area[both], b$area[both]),
      log_area_ratio_joint_delivery = list(log(a$area[both]), log(b$area[both])),
      log_cutoff_ratio_joint_delivery = list(log(a$cutoff[both]), log(b$cutoff[both])),
      covariance_trace_joint_finite = list((a$var_dx + a$var_dy)[finite_cov], (b$var_dx + b$var_dy)[finite_cov]),
      log_covariance_trace_ratio_joint_positive = list(log((a$var_dx + a$var_dy)[positive_trace]),
        log((b$var_dx + b$var_dy)[positive_trace])),
      covariance_dx_joint_finite = list(a$var_dx[finite_cov], b$var_dx[finite_cov]),
      covariance_dy_joint_finite = list(a$var_dy[finite_cov], b$var_dy[finite_cov]),
      covariance_cross_joint_finite = list(a$cov_dx_dy[finite_cov], b$cov_dx_dy[finite_cov]))
    for (metric in names(outcomes)) {
      bounded <- metric %in% c("conditional_coverage_joint_delivery", "conditional_zero_exclusion_joint_delivery", "delivery", "operational_yield")
      difference <- study03_paired_difference(outcomes[[metric]][[1L]], outcomes[[metric]][[2L]], bounded)
      rows[[length(rows) + 1L]] <- data.frame(a[1L, setdiff(keys, "dataset_id")],
        baseline = "fixed_observed_reference", candidate = "fixed_population_reference_oracle",
        metric = metric, n_outer = nrow(a), n_joint_delivered = sum(both), as.list(difference),
        interpretation = "Diagnostic oracle minus core, paired by outer panel; unavailable population frame is not a production procedure", row.names = NULL)
    }
  }
  do.call(rbind, rows)
}

study04_nondelivery_reasons <- function(outer, estimates, regions, frame_name) {
  r <- regions[regions$scenario == "rare_axis" & regions$method == "jackknife_studentized", ]
  if (!nrow(r)) stop("Sparse-unit panels must be retained for non-delivery accounting.")
  ekey <- c("case_id", "dataset_id", "entity"); okey <- c("case_id", "dataset_id")
  ei <- match(study03_key(r, ekey), study03_key(estimates, ekey))
  oi <- match(study03_key(r, okey), study03_key(outer, okey))
  if (anyNA(ei) || anyNA(oi) || anyDuplicated(study03_key(r, ekey))) stop("Sparse accounting has missing or duplicate panel keys.")
  e <- estimates[ei, ]; o <- outer[oi, ]
  rare <- o$rare_count
  if (anyNA(rare) || any(rare < 0 | rare != floor(rare))) stop("Sparse accounting requires every observed rare-unit count.")
  reason <- rep("final_geometry_unavailable", nrow(r))
  reason[r$delivered] <- "delivered"
  pending <- !r$delivered
  assign_reason <- function(condition, label) {
    use <- pending & condition
    reason[use] <<- label; pending[use] <<- FALSE
  }
  assign_reason(!o$observed_success, "observed_fit_unavailable")
  assign_reason(o$observed_jackknife_success < o$observed_jackknife_required,
    "required_observed_deletion_failed")
  assign_reason(!e$observed_jackknife_ok, "observed_covariance_invalid")
  assign_reason(r$n_valid < 20L, "fewer_than_20_valid_pivots")
  assign_reason(r$n_valid / o$B < .95, "valid_pivot_fraction_below_0.95")
  if (anyNA(reason) || any((reason == "delivered") != r$delivered)) stop("Non-delivery precedence failed.")
  data.frame(r[c("case_id", "scenario", "m", "dataset_id", "entity")], frame = frame_name,
    rare_count = rare, rare_bin = ifelse(rare >= 4L, "4+", as.character(rare)),
    reason = reason, observed_success = o$observed_success,
    observed_jackknife_required = o$observed_jackknife_required,
    observed_jackknife_success = o$observed_jackknife_success,
    observed_covariance_ok = e$observed_jackknife_ok, B = o$B, n_valid = r$n_valid,
    available = r$available, gate = r$gate, delivered = r$delivered, covered = r$covered,
    relaxed_covered = r$relaxed_covered, area = r$area, cutoff = r$cutoff, row.names = NULL)
}

study04_nondelivery_summary <- function(panels) {
  reasons <- c("observed_fit_unavailable", "required_observed_deletion_failed", "observed_covariance_invalid",
    "fewer_than_20_valid_pivots", "valid_pivot_fraction_below_0.95", "final_geometry_unavailable", "delivered")
  keys <- c("case_id", "scenario", "m", "entity", "frame")
  rows <- list()
  for (x in study03_groups(panels, keys)) for (bin in c("all", "0", "1", "2", "3", "4+")) {
    z <- if (bin == "all") x else x[x$rare_bin == bin, ]
    for (reason in reasons) {
      count <- sum(z$reason == reason); share <- study03_wilson(count, nrow(z))
      nd <- sum(z$delivered); nc <- sum(z$covered[z$delivered])
      coverage <- study03_wilson(nc, nd); yield <- study03_wilson(nc, nrow(z))
      rows[[length(rows) + 1L]] <- data.frame(x[1L, keys], rare_bin = bin, reason = reason,
        n_planned = nrow(z), n_in_reason = count, reason_fraction = share["estimate"],
        reason_mcse = share["mcse"], reason_wilson_lower = share["lower"], reason_wilson_upper = share["upper"],
        n_delivered = nd, n_covered = nc, conditional_coverage = coverage["estimate"],
        coverage_mcse = coverage["mcse"], coverage_wilson_lower = coverage["lower"], coverage_wilson_upper = coverage["upper"],
        operational_coverage_and_delivery = yield["estimate"], yield_mcse = yield["mcse"],
        yield_wilson_lower = yield["lower"], yield_wilson_upper = yield["upper"], row.names = NULL)
    }
  }
  do.call(rbind, rows)
}

# The opposite half supplies an unavailable repeated-experiment covariance.
# Shared donor covariances induce dependence: no iid binomial MCSE or CI is
# attached to crossfit coverage. These diagnostics never replace the candidate.
study04_crossfit_covariance <- function(caseplan, estimates) {
  null_cases <- c("regular_null_m40", "regular_null_m160")
  plan <- caseplan[match(null_cases, caseplan$case_id), ]
  if (anyNA(plan$case_id) || any(plan$M != 400L)) stop("Crossfit diagnostics require the two frozen 400-panel null cases.")
  rows <- donors <- list()
  for (case_id in null_cases) for (entity in c("E015", "E003", "E006")) {
    x <- estimates[estimates$case_id == case_id & estimates$entity == entity, ]
    if (nrow(x) != 400L || anyDuplicated(x$dataset_id) || !setequal(x$dataset_id, seq_len(400L))) {
      stop("Crossfit diagnostics must retain every planned null panel exactly once.")
    }
    x <- x[order(x$dataset_id), ]; half <- ifelse(x$dataset_id <= 200L, 1L, 2L)
    finite <- x$observed_success & is.finite(x$dx) & is.finite(x$dy)
    if (any(!is.finite(x$truth_dx) | !is.finite(x$truth_dy))) stop("Crossfit population truths must remain defined.")
    for (evaluation_half in seq_len(2L)) {
      donor_half <- 3L - evaluation_half; use <- half == donor_half & finite; n <- sum(use)
      S <- if (n >= 2L) stats::cov(cbind(x$dx[use], x$dy[use])) else matrix(NA_real_, 2L, 2L)
      geometry <- study03_covariance_status(S, tol = 1e-8)
      donor_ok <- n >= 190L; covariance_ok <- donor_ok && geometry$valid
      reason <- if (!donor_ok) "fewer_than_190_of_200_finite_donors" else if (!geometry$valid) geometry$reason else "ok"
      donors[[length(donors) + 1L]] <- data.frame(case_id = case_id, entity = entity,
        evaluation_half = evaluation_half, donor_half = donor_half, donor_first_dataset = if (donor_half == 1L) 1L else 201L,
        donor_last_dataset = if (donor_half == 1L) 200L else 400L, n_donor_planned = 200L,
        n_donor_finite = n, n_donor_unavailable = 200L - n, minimum_donors = 190L,
        covariance_ok = covariance_ok, reason = reason, var_dx = S[1L, 1L], var_dy = S[2L, 2L], cov_dx_dy = S[1L, 2L],
        covariance_trace = sum(diag(S)), eigenvalue_max = geometry$eigenvalues[1L], eigenvalue_min = geometry$eigenvalues[2L],
        eigen_ratio = geometry$eigen_ratio, cutoff = stats::qchisq(.95, 2L), row.names = NULL)
      for (i in which(half == evaluation_half)) {
        delivered <- finite[i] && covariance_ok
        cutoff <- stats::qchisq(.95, 2L); statistic <- area <- NA_real_; covered <- NA
        panel_reason <- if (!finite[i]) "observed_fit_unavailable" else reason
        if (delivered) {
          statistic <- study03_quadratic(c(x$truth_dx[i] - x$dx[i], x$truth_dy[i] - x$dy[i]), S)
          area <- pi * cutoff * geometry$determinant_root
          delivered <- is.finite(statistic) && is.finite(area) && area > 0
          if (delivered) covered <- statistic <= cutoff * (1 + 1e-12) else panel_reason <- "final_geometry_unavailable"
        }
        rows[[length(rows) + 1L]] <- data.frame(x[i, c("case_id", "scenario", "m", "dataset_id", "entity")],
          evaluation_half = evaluation_half, donor_half = donor_half, n_donor_planned = 200L, n_donor_finite = n,
          observed_success = finite[i], covariance_ok = covariance_ok, delivered = delivered, covered = covered,
          reason = panel_reason, truth_statistic = statistic, cutoff = cutoff, area = area,
          var_dx = S[1L, 1L], var_dy = S[2L, 2L], cov_dx_dy = S[1L, 2L], row.names = NULL)
      }
    }
  }
  panels <- do.call(rbind, rows); donor_table <- do.call(rbind, donors)
  summaries <- list()
  for (x in study03_groups(panels, c("case_id", "scenario", "m", "entity"))) for (cohort in c("all", "1", "2")) {
    z <- if (cohort == "all") x else x[x$evaluation_half == as.integer(cohort), ]
    nd <- sum(z$delivered); nc <- sum(z$covered[z$delivered])
    summaries[[length(summaries) + 1L]] <- data.frame(x[1L, c("case_id", "scenario", "m", "entity")],
      evaluation_half = cohort, n_outer = nrow(z), n_observed_valid = sum(z$observed_success),
      n_delivered = nd, n_covered = nc, conditional_coverage = if (nd) nc / nd else NA_real_,
      delivery_fraction = nd / nrow(z), operational_coverage_and_delivery = nc / nrow(z),
      mean_area_delivered = study03_mean(z$area[z$delivered]),
      uncertainty = "Descriptive only: shared donor covariance invalidates an iid binomial MCSE across evaluation panels",
      interpretation = "Unavailable opposite-half sampling covariance with chi-square(2) cutoff; no tuning or production substitution", row.names = NULL)
  }
  list(panels = panels, donors = donor_table, summary = do.call(rbind, summaries))
}

study04_read_tables <- function(directory) {
  setNames(lapply(c("caseplan", "outer", "estimates", "regions", "attempts", "studentization"), function(name) {
    path <- file.path(directory, paste0(name, ".csv"))
    if (!file.exists(path)) stop("Missing completed-study table: ", path)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  }), c("caseplan", "outer", "estimates", "regions", "attempts", "studentization"))
}

study04_frame_variation <- function(attempts) {
  required <- c("rotation_distance_from_observed", "rotation_determinant")
  if (!all(required %in% names(attempts))) stop("Frame diagnostics require per-draw registration rotations.")
  keys <- c("case_id", "scenario", "m", "dataset_id")
  panels <- lapply(study03_groups(attempts, keys), function(x) {
    use <- x$success & is.finite(x$rotation_distance_from_observed)
    d <- x$rotation_distance_from_observed[use]
    data.frame(x[1L, keys], n_planned = nrow(x), n_attempted = sum(x$attempted), n_defined = length(d),
      mean_rotation_distance = study03_mean(d),
      q95_rotation_distance = if (length(d)) as.numeric(stats::quantile(d, .95, type = 7L)) else NA_real_,
      max_rotation_distance = if (length(d)) max(d) else NA_real_,
      fraction_negative_determinant = study03_mean(x$rotation_determinant[use] < 0), row.names = NULL)
  })
  panels <- do.call(rbind, panels)
  summaries <- lapply(study03_groups(panels, c("case_id", "scenario", "m")), function(x) {
    use <- is.finite(x$mean_rotation_distance)
    data.frame(x[1L, c("case_id", "scenario", "m")], n_outer = nrow(x), n_outer_defined = sum(use),
      mean_rotation_distance = study03_mean(x$mean_rotation_distance[use]),
      rotation_distance_outer_mcse = study03_mcse(x$mean_rotation_distance[use]),
      mean_outer_q95_rotation_distance = study03_mean(x$q95_rotation_distance[use]),
      maximum_rotation_distance = if (any(use)) max(x$max_rotation_distance[use]) else NA_real_,
      interpretation = "Frobenius distance between each perturbed direct-population registration and the observed registration; summarize within outer panel before MCSE", row.names = NULL)
  })
  list(panels = panels, summary = do.call(rbind, summaries))
}

study04_sparse_rank_benchmark <- function() {
  r <- 0:12; q <- r / 12
  full <- stats::pbinom(0L, 12L, q, lower.tail = FALSE)
  pivot <- stats::pbinom(1L, 12L, q, lower.tail = FALSE)
  delivery <- ifelse(r >= 2L, stats::pbinom(189L, 199L, pivot, lower.tail = FALSE), 0)
  probability <- stats::dbinom(r, 12L, .15)
  data.frame(rare_count = r, observed_count_probability = probability,
    expected_panels_of_120 = 120 * probability, observed_fit_rank_eligible = r >= 1L,
    observed_jackknife_rank_eligible = r >= 2L,
    bootstrap_full_rank_probability = full, bootstrap_complete_jackknife_rank_probability = pivot,
    rank_only_delivery_probability_given_count = delivery,
    expected_rank_only_deliveries_of_120 = 120 * probability * delivery,
    interpretation = "Analytic rare-axis rank mechanism only; excludes covariance, alignment and other geometry failures; no gate modification")
}

study04_summarize_tables <- function(x, directory) {
  answer <- c(list(coverage = study03_coverage_summary(x$caseplan, x$estimates, x$regions),
    errors = study03_error_summary(x$estimates, x$regions), contrasts = study03_paired_contrasts(x$regions),
    covariance = study03_covariance_summary(x$estimates, x$regions)),
    study03_failure_summaries(x$caseplan, x$outer, x$attempts, x$studentization),
    study03_selection_summary(x$estimates, x$studentization))
  for (name in names(answer)) utils::write.csv(answer[[name]], file.path(directory, paste0(name, "-summary.csv")), row.names = FALSE, na = "")
  answer
}

study04_validate_frame_tables <- function(core, frame) {
  if (!identical(core$caseplan, frame$caseplan)) stop("Frame and core case plans differ.")
  for (name in c("outer", "estimates", "regions", "attempts", "studentization")) {
    extra <- switch(name, outer = character(), estimates = "entity", regions = c("entity", "method"),
      attempts = "replicate_id", studentization = c("entity", "replicate_id"))
    f <- study04_match(core[[name]], frame[[name]], c("case_id", "scenario", "m", "dataset_id", extra), paste("Frame", name))
    if (name == "attempts" && (any(f$attempted & !core[[name]]$success) || any(f$success & !f$attempted))) {
      stop("Oracle frame registrations require successful core full fits.")
    }
    if (name == "regions" && (any(f$delivered != (f$available & f$gate)) ||
        anyNA(f$covered[f$delivered]) || any(!is.na(f$covered[!f$delivered])))) {
      stop("Oracle frame region delivery and coverage disagree.")
    }
  }
  invisible(TRUE)
}

study04_write_figures <- function(core_coverage, frame_coverage, sparse_summary, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is required for figures.")
  labels <- c(wald = "Bootstrap Wald", bootstrap_mahalanobis = "Bootstrap Mahalanobis", bootstrap_ball = "Bootstrap ball",
    jackknife_wald = "Jackknife Wald", jackknife_studentized = "Studentized jackknife")
  colors <- c(wald = "#737B83", bootstrap_mahalanobis = "#B97943", bootstrap_ball = "#63866E",
    jackknife_wald = "#86709A", jackknife_studentized = "#176B87")
  theme <- ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(legend.position = "bottom",
    legend.title = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold"), plot.caption = ggplot2::element_text(hjust = 0, size = 9))
  save <- function(plot, name, width = 11.5, height = 6) {
    ggplot2::ggsave(file.path(output_dir, paste0(name, ".pdf")), plot, device = grDevices::cairo_pdf,
      width = width, height = height, units = "in", bg = "white")
  }
  primary <- function(x) x[x$policy == "production" & ((x$case_id == "regular_null_m40" & x$entity == "E006") |
    (x$case_id == "regular_null_m160" & x$entity == "E003")), ]
  z <- rbind(transform(primary(core_coverage), frame = "Observed reference (core)"),
    transform(primary(frame_coverage), frame = "Population reference (diagnostic)"))
  z$case_label <- paste0(z$entity, ", null m = ", z$m)
  z$method <- factor(z$method, rev(names(labels)), rev(labels))
  p <- ggplot2::ggplot(z, ggplot2::aes(conditional_coverage, method, color = frame)) +
    ggplot2::geom_vline(xintercept = .95, linetype = "dashed", color = "#89939C") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = coverage_wilson_lower, xmax = coverage_wilson_upper),
      orientation = "y", width = .15, position = ggplot2::position_dodge(.4), na.rm = TRUE) +
    ggplot2::geom_point(position = ggplot2::position_dodge(.4), size = 2, na.rm = TRUE) +
    ggplot2::facet_wrap(~case_label) + ggplot2::scale_x_continuous(limits = c(0, 1), labels = function(x) paste0(round(100*x), "%")) +
    ggplot2::coord_cartesian(xlim = c(.80, 1)) +
    ggplot2::scale_color_manual(values = c("Observed reference (core)" = "#176B87", "Population reference (diagnostic)" = "#B97943")) +
    ggplot2::labs(title = "Independent replication of the two secondary null deficits",
      subtitle = "400 fresh panels per null case; each population-frame deletion is refitted directly",
      x = "Coverage among delivered joint regions", y = NULL,
      caption = "Bars: pointwise 95% Wilson Monte Carlo intervals. The two frozen primary tests use Bonferroni alpha = 0.025.\nThe population reference is an unavailable diagnostic. Non-deliveries remain in the all-planned yield tables.") + theme
  save(p, "calibration04-null-replication", height = 5.8)
  moving <- core_coverage[core_coverage$policy == "production" & core_coverage$scenario == "regular_movement", ]
  moving$target <- paste(moving$entity, paste0("m = ", moving$m), sep = "\n")
  p <- ggplot2::ggplot(moving, ggplot2::aes(conditional_coverage, target, color = method)) +
    ggplot2::geom_vline(xintercept = .95, linetype = "dashed", color = "#89939C") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = coverage_wilson_lower, xmax = coverage_wilson_upper),
      orientation = "y", width = .2, position = ggplot2::position_dodge(.65), na.rm = TRUE) +
    ggplot2::geom_point(position = ggplot2::position_dodge(.65), size = 1.8, na.rm = TRUE) +
    ggplot2::scale_x_continuous(limits = c(0, 1), labels = function(x) paste0(round(100*x), "%")) +
    ggplot2::coord_cartesian(xlim = c(.65, 1)) +
    ggplot2::scale_color_manual(values = colors, labels = labels) +
    ggplot2::labs(title = "Movement controls retain the full population embedding target",
      subtitle = "100 independent panels per movement case; all three fixed targets",
      x = "Coverage among delivered joint regions", y = NULL,
      caption = "Bars: pointwise 95% Wilson Monte Carlo intervals; methods share panels.\nCoverage is distinct from zero exclusion. Stable latent entities can have nonzero embedding displacement targets.") + theme
  save(p, "calibration04-movement-controls", height = 6.5)
  sparse <- sparse_summary[sparse_summary$frame == "core" & sparse_summary$entity == "E015" & sparse_summary$rare_bin != "all", ]
  sparse$rare_bin <- factor(sparse$rare_bin, c("0", "1", "2", "3", "4+"))
  sparse$reason <- factor(sparse$reason,
    c("observed_fit_unavailable", "required_observed_deletion_failed", "observed_covariance_invalid", "fewer_than_20_valid_pivots",
      "valid_pivot_fraction_below_0.95", "final_geometry_unavailable", "delivered"),
    c("Observed fit unavailable", "Required deletion failed", "Observed covariance invalid", "Fewer than 20 pivots",
      "Valid fraction below 95%", "Final geometry unavailable", "Delivered"))
  p <- ggplot2::ggplot(sparse, ggplot2::aes(rare_bin, n_in_reason, fill = reason)) +
    ggplot2::geom_col(width = .65) + ggplot2::scale_fill_brewer(palette = "Set2", drop = FALSE) +
    ggplot2::labs(title = "Every sparse-unit panel has one delivery outcome",
      subtitle = "Studentized joint region for E015; 120 planned panels; frozen precedence for failure reasons",
      x = "Observed rare measurement units", y = "Planned outer panels",
      caption = "Zero-count reasons are retained in the table. Other targets and the diagnostic frame have separate complete ledgers.\nNo failed deletion or sparse panel is silently removed, and no gate is relaxed for this replication.") + theme
  save(p, "calibration04-sparse-accounting", height = 6.2)
  invisible(NULL)
}

study04_analyze <- function(output_dir, figures = TRUE) {
  core <- study04_read_tables(file.path(output_dir, "core")); frame <- study04_read_tables(file.path(output_dir, "frame"))
  do.call(study03_validate_analysis, core)
  study04_validate_frame_tables(core, frame)
  point <- study04_frame_agreement(core$estimates, frame$estimates)
  summaries <- list(core = study04_summarize_tables(core, file.path(output_dir, "core")),
    frame = study04_summarize_tables(frame, file.path(output_dir, "frame")))
  sparse <- rbind(study04_nondelivery_reasons(core$outer, core$estimates, core$regions, "core"),
    study04_nondelivery_reasons(frame$outer, frame$estimates, frame$regions, "population_frame_oracle"))
  crossfit <- study04_crossfit_covariance(core$caseplan, core$estimates)
  variation <- study04_frame_variation(frame$attempts)
  extras <- list(primary_replication = study04_primary_replication(summaries$core$coverage),
    frame_paired = study04_frame_comparisons(core$regions, frame$regions),
    frame_observed_agreement = point$summary, frame_observed_by_panel = point$by_panel,
    frame_variation = variation$summary, frame_variation_by_panel = variation$panels,
    sparse_nondelivery_by_panel = sparse, sparse_nondelivery = study04_nondelivery_summary(sparse),
    sparse_rank_benchmark = study04_sparse_rank_benchmark(),
    crossfit_covariance_panels = crossfit$panels, crossfit_covariance_donors = crossfit$donors,
    crossfit_covariance = crossfit$summary)
  for (name in names(extras)) utils::write.csv(extras[[name]],
    file.path(output_dir, paste0(gsub("_", "-", name), ".csv")), row.names = FALSE, na = "")
  if (figures) study04_write_figures(summaries$core$coverage, summaries$frame$coverage, extras$sparse_nondelivery, output_dir)
  writeLines(c(
    "Study 04 uses new independent random streams and frozen case-specific M and B; earlier results are historical only.",
    "Primary replications are E006 under regular_null_m40 and E003 under regular_null_m160, using the unchanged studentized region.",
    "Each primary one-sided exact binomial test tests conditional delivered coverage below 0.95 with Bonferroni alpha 0.025. Nonrejection does not establish equivalence or calibrated coverage.",
    "Core maps and every nested deletion use a fixed observed reference. The diagnostic frame registers every individual fit directly to the fixed population baseline; it is unavailable in practice.",
    "Observed core and diagnostic estimates are compared in the population frame and must agree within 1e-9. Covariance and pivot differences therefore isolate how individual perturbed fits are registered, not a mere global rotation.",
    "Coverage conditions on delivery; operational coverage-and-delivery includes all planned panels. Undefined observed fits, failed required deletions, invalid covariances and failed gates retain explicit rows.",
    "Sparse failure reasons use a fixed mutually exclusive precedence: observed fit, required observed deletion, observed covariance, fewer than 20 valid pivots, valid fraction below 0.95, final geometry, delivered.",
    "Every sparse panel is retained by exact rare-unit count and fixed bins 0, 1, 2, 3, 4+. Counts repeat across targets; targets must not be treated as independent panel replications.",
    "The analytic sparse rank benchmark uses R~Binomial(12,0.15), K|R=r~Binomial(12,r/12), full-rank eligibility K>=1, complete-deletion eligibility K>=2, and at least 190/199 eligible draws. It excludes other geometry failures and does not modify the estimator or gate.",
    "Frame and method comparisons are paired within outer panels. MCSEs use independent outer panels, not bootstrap draws or target rows. Population-frame-only failures never suppress the core result.",
    "Opposite-half covariance diagnostics use null panels 1:200 versus 201:400, at least 190/200 finite donors, SPD eigenratio greater than 1e-8, and a fixed chi-square(2) 0.95 cutoff. They are unavailable repeated-experiment diagnostics, never substituted into production.",
    "Shared opposite-half covariances induce dependence across crossfit evaluation panels; their coverage counts and rates are descriptive, with no iid binomial MCSE or interval. Donor covariance entries, spectrum and half-specific results are retained.",
    "Covariance summaries compare mean estimated covariance with the repeated-panel error covariance on the disclosed finite paired cohort. Mean covariance agreement alone cannot prove that studentized pivots are calibrated.",
    "Movement zero exclusion is power only for the declared nonzero population embedding target; latent stability does not imply zero embedding displacement.",
    "Relaxed geometry-only summaries are selection diagnostics. The candidate's 20-pivot and 95% valid-fraction gates are unchanged.",
    "No inflation factors, cutoffs, target selection, stopping rule, or production method are fitted to the replication outcomes."), file.path(output_dir, "analysis-notes.txt"))
  invisible(c(summaries, extras))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript analyze.R /absolute/completed-output")
  script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  source(file.path(source_dir, "run.R")); study04_load(source_dir)
  study04_analyze(args[1L])
}
