#!/usr/bin/env Rscript
# Mechanical accounting checks for calibration study 01. No check requires
# favorable coverage, small bias, or a low failure rate. This file can be
# sourced; the command-line entrypoint runs only when invoked directly.

calibration_validate_outputs <- function(output_dir, expected_M = 80L,
                                         expected_B = 199L,
                                         stop_on_failure = TRUE) {
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  checks <- list()
  add <- function(name, passed, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = name, passed = isTRUE(passed), detail = as.character(detail),
      stringsAsFactors = FALSE)
    invisible(isTRUE(passed))
  }
  finish <- function() {
    answer <- do.call(rbind, checks)
    write.csv(answer, file.path(output_dir, "mechanical-validation.csv"),
              row.names = FALSE)
    if (stop_on_failure && any(!answer$passed)) {
      failed <- answer$check[!answer$passed]
      stop(length(failed), " mechanical validation checks failed: ",
           paste(utils::head(failed, 8L), collapse = "; "), call. = FALSE)
    }
    answer
  }
  required <- c("frozen-design.rds", "seed-plan.rds", "seed-plan.csv",
    "source-hashes-before-run.csv", "population-targets.rds", "outer-results.csv",
    "estimates.csv", "regions.csv", "bootstrap-attempts.csv",
    "bootstrap-vectors.csv", "pca-mds-audit.csv", "model.R", "regions.R", "run.R",
    "protocol.md")
  present <- file.exists(file.path(output_dir, required))
  add("required_output_files", all(present), paste(required[!present], collapse = "; "))
  if (!all(present)) return(finish())
  read_csv <- function(name) {
    path <- file.path(output_dir, name)
    columns <- names(utils::read.csv(path, nrows = 0L, check.names = FALSE))
    classes <- stats::setNames(rep(NA_character_, length(columns)), columns)
    text_columns <- c("scenario", "message", "failure_stage", "reason", "engine",
      "entity", "target_role", "method", "policy", "stage", "file", "md5", "data_stream")
    classes[intersect(columns, text_columns)] <- "character"
    # In particular, an all-success message column contains empty strings,
    # which automatic type conversion would incorrectly turn into logical NA.
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
      na.strings = "NA", colClasses = classes)
  }
  canonical_missing <- function(x) {
    # CSV has no type information for an all-NA column. This coercion changes
    # only wholly missing logical columns, not observed logical decisions.
    if (is.data.frame(x)) {
      x[] <- lapply(x, canonical_missing)
      return(x)
    }
    if (is.list(x)) return(lapply(x, canonical_missing))
    if (is.logical(x) && length(x) && all(is.na(x))) return(as.numeric(x))
    x
  }
  equal <- function(x, y, tolerance = 1e-10) isTRUE(all.equal(
    canonical_missing(x), canonical_missing(y), tolerance = tolerance,
    check.attributes = FALSE))
  key <- function(x, columns) if (nrow(x)) do.call(paste,
    c(x[columns], sep = "\r")) else character()
  order_table <- function(x, columns) {
    if (is.null(x) || !nrow(x)) return(NULL)
    x <- x[order(key(x, columns), method = "radix"), , drop = FALSE]
    rownames(x) <- NULL
    x
  }
  same_table <- function(a, b, columns) {
    if (is.null(a) || !nrow(a)) return(is.null(b) || !nrow(b))
    if (is.null(b) || !nrow(b) || !setequal(names(a), names(b))) return(FALSE)
    equal(order_table(a, columns), order_table(b[names(a)], columns))
  }
  freeze <- readRDS(file.path(output_dir, "frozen-design.rds"))
  jobs <- readRDS(file.path(output_dir, "seed-plan.rds"))
  populations <- readRDS(file.path(output_dir, "population-targets.rds"))
  env <- new.env(parent = globalenv())
  source(file.path(output_dir, "model.R"), local = env)
  source(file.path(output_dir, "regions.R"), local = env)
  scenarios <- env$calibration_scenarios()
  add("population_scenario_keys", setequal(names(populations), scenarios$scenario))
  for (s in seq_len(nrow(scenarios))) {
    population <- populations[[scenarios$scenario[s]]]
    reconstructed <- env$calibration_population(scenarios[s, , drop = FALSE])
    add(paste0("population_target_reconstruction:", scenarios$scenario[s]),
      equal(population$gram, reconstructed$gram) &&
      equal(population$eigenvalues, reconstructed$eigenvalues) &&
      equal(population$movement, reconstructed$movement) &&
      identical(population$layout$anchors, reconstructed$layout$anchors))
  }
  add("frozen_budget", identical(freeze$M, as.integer(expected_M)) &&
    identical(freeze$B, as.integer(expected_B)))
  hashes <- tools::md5sum(file.path(output_dir, names(freeze$source_md5)))
  add("frozen_source_copies_match_hashes", identical(unname(hashes),
    unname(freeze$source_md5)))
  hash_csv <- read_csv("source-hashes-before-run.csv")
  add("source_hash_manifest_matches_freeze", identical(hash_csv$file,
    names(freeze$source_md5)) && identical(hash_csv$md5, unname(freeze$source_md5)))
  add("package_version_matches_freeze", identical(freeze$package,
    as.character(utils::packageVersion("driftmapR"))))
  outer <- read_csv("outer-results.csv")
  estimates <- read_csv("estimates.csv")
  regions <- read_csv("regions.csv")
  attempts <- read_csv("bootstrap-attempts.csv")
  vectors <- read_csv("bootstrap-vectors.csv")
  audits <- read_csv("pca-mds-audit.csv")
  complete_flags <- function(x, names) all(vapply(x[names], function(z)
    is.logical(z) && !anyNA(z), logical(1L)))
  flags_ok <- add("critical_logical_flags_complete",
    complete_flags(outer, c("observed_success", "bootstrap_started", "bootstrap_error", "passes_gate")) &&
    complete_flags(regions, c("region_computable", "gate_passed", "delivered")) &&
    complete_flags(attempts, "success"))
  if (!flags_ok) return(finish())
  ids <- c("scenario", "dataset_id")
  region_ids <- c(ids, "entity", "method", "policy")
  expected <- expand.grid(dataset_id = seq_len(expected_M),
    scenario = scenarios$scenario, stringsAsFactors = FALSE)
  expected_keys <- key(expected, ids)
  add("outer_attempt_keys_complete_once", nrow(outer) == nrow(expected) &&
    !anyDuplicated(key(outer, ids)) && setequal(key(outer, ids), expected_keys),
    paste("outer rows", nrow(outer)))
  add("seed_plan_complete_once", length(jobs) == nrow(expected) &&
    !anyDuplicated(vapply(jobs, function(j) paste(j$scenario, j$dataset_id, sep = "\r"),
                         character(1L))))
  plan_table <- do.call(rbind, lapply(jobs, function(j) data.frame(
    scenario = j$scenario, dataset_id = j$dataset_id, bootstrap_seed = j$bootstrap_seed,
    data_stream = paste(j$data_stream, collapse = ";"))))
  add("seed_plan_csv_matches_rds", same_table(plan_table, read_csv("seed-plan.csv"), ids))
  add("dataset_rng_states_unique", !anyDuplicated(plan_table$data_stream))
  add("dataset_rng_stream_sequence", length(jobs) >= 1L &&
    all(vapply(seq_len(max(length(jobs) - 1L, 0L)), function(i)
      identical(parallel::nextRNGStream(jobs[[i]]$data_stream), jobs[[i + 1L]]$data_stream),
      logical(1L))))
  add("bootstrap_seeds_unique", !anyDuplicated(plan_table$bootstrap_seed))
  add("bootstrap_seed_formula", all(vapply(jobs, function(j)
    j$bootstrap_seed == 1400000L + j$scenario_id * 1000L + j$dataset_id,
    logical(1L))))
  add("success_failure_conservation", all(outer$n_attempted == outer$n_valid + outer$n_failed))
  add("unexpected_bootstrap_call_errors_absent", !any(outer$bootstrap_error),
    paste("setup errors", sum(outer$bootstrap_error)))
  add("exact_B_for_completed_bootstrap_calls", all(
    outer$n_attempted[outer$bootstrap_started & !outer$bootstrap_error] == expected_B))
  add("observed_failures_do_not_claim_bootstrap_attempts", all(
    !outer$bootstrap_started[!outer$observed_success] & outer$n_attempted[!outer$observed_success] == 0L))
  expected_gate <- outer$n_valid >= 20L & outer$n_valid / expected_B >= 0.95 &
    outer$observed_success & !outer$bootstrap_error
  add("outer_production_gate_exact", identical(outer$passes_gate, expected_gate))
  add("complete_region_grid", nrow(regions) == nrow(expected) * 18L &&
    !anyDuplicated(key(regions, region_ids)) && all(table(key(regions, ids)) == 18L),
    paste("region rows", nrow(regions)))
  add("region_levels", setequal(regions$entity, c("E015", "E003", "E006")) &&
    setequal(regions$method, c("wald", "bootstrap_mahalanobis", "bootstrap_ball")) &&
    setequal(regions$policy, c("relaxed", "production")))
  add("undelivered_coverage_is_missing", all(is.na(regions$covered[!regions$delivered])) &&
    all(is.na(regions$rejects_zero[!regions$delivered])))
  add("delivered_coverage_is_recorded", !anyNA(regions$covered[regions$delivered]) &&
    !anyNA(regions$rejects_zero[regions$delivered]))
  add("delivery_requires_geometry_and_gate", identical(regions$delivered,
    regions$region_computable & regions$gate_passed))
  add("selected_vector_keys_unique", !anyDuplicated(key(vectors, c(ids, "replicate_id", "entity"))))
  add("bootstrap_attempt_keys_unique", !anyDuplicated(key(attempts, c(ids, "replicate_id"))))
  add("bootstrap_attempt_total", nrow(attempts) == sum(outer$n_attempted))
  add("selected_vector_total", nrow(vectors) == 3L * sum(outer$n_valid))

  # Each checkpoint is a complete audit unit, including unsuccessful attempts.
  for (job in jobs) {
    label <- sprintf("%s-%03d", job$scenario, job$dataset_id)
    path <- file.path(output_dir, "checkpoints", "pca", paste0(label, ".rds"))
    if (!add(paste0(label, ":checkpoint_exists"), file.exists(path))) next
    item <- readRDS(path)
    select <- function(x) x[x$scenario == job$scenario & x$dataset_id == job$dataset_id, , drop = FALSE]
    o <- select(outer)
    e <- select(estimates)
    r <- select(regions)
    a <- select(attempts)
    v <- select(vectors)
    add(paste0(label, ":checkpoint_identity"), identical(item$job, job) &&
      identical(item$signature, freeze))
    add(paste0(label, ":csv_checkpoint_reconciliation"),
      same_table(item$outer, o, ids) && same_table(item$estimates, e, c(ids, "entity")) &&
      same_table(item$regions, r, region_ids) &&
      same_table(item$attempts, a, c(ids, "replicate_id")) &&
      same_table(item$selected_draws, v, c(ids, "replicate_id", "entity")))
    scenario <- scenarios[job$scenario_id, , drop = FALSE]
    generated <- env$calibration_generate(scenario, job$data_stream)
    add(paste0(label, ":rare_count_replays"), equal(generated$rare_count, o$rare_count))
    if (!o$observed_success) {
      add(paste0(label, ":observed_failure_preserved"), nrow(e) == 0L && nrow(a) == 0L &&
        nrow(v) == 0L && all(!r$delivered) && nzchar(o$failure_stage) && nzchar(o$message))
      next
    }
    add(paste0(label, ":observed_targets_complete"), nrow(e) == 3L &&
      setequal(e$entity, c("E015", "E003", "E006")))
    population <- populations[[job$scenario]]
    population_movement <- population$movement[match(e$entity, population$movement$entity), ]
    add(paste0(label, ":fixed_population_truth"),
      equal(e$theta_dx, population_movement$dx) && equal(e$theta_dy, population_movement$dy))
    add(paste0(label, ":observed_error_arithmetic"),
      equal(e$error_dx, e$estimate_dx - e$theta_dx) &&
      equal(e$error_dy, e$estimate_dy - e$theta_dy) &&
      equal(e$error_norm, sqrt(e$error_dx^2 + e$error_dy^2)) &&
      equal(e$squared_error, e$error_dx^2 + e$error_dy^2) &&
      equal(e$normalized_error_dx, e$error_dx / sqrt(scenario$m)) &&
      equal(e$normalized_error_dy, e$error_dy / sqrt(scenario$m)))
    rotation <- item$gauge_rotation
    add(paste0(label, ":orthogonal_common_gauge"), is.matrix(rotation) &&
      equal(crossprod(rotation), diag(2L)))
    # One cheap observed refit verifies the saved orientation and point estimate.
    # The bootstrap is not rerun here; the independent runner tests verify that
    # its vectors receive this exact same rotation.
    replay <- tryCatch({
      fit <- suppressWarnings(driftmapR::embed_snapshots(generated$data,
        generated$features, method = "pca", periods = 1:2, standardize = "none"))
      fit <- driftmapR::align_snapshots(fit, reference = "previous", scale = FALSE,
        anchors = generated$layout$anchors)
      registered <- env$calibration_gauge_rotation(fit, population$object,
        generated$layout$anchors)
      movement <- driftmapR::measure_drift(fit)
      movement <- movement[match(e$entity, movement$entity), ]
      list(rotation = registered, vectors = as.matrix(movement[c("dx", "dy")]) %*% registered)
    }, error = function(e) NULL)
    add(paste0(label, ":observed_gauge_and_estimate_replay"), !is.null(replay) &&
      equal(rotation, replay$rotation) &&
      equal(e$estimate_dx, replay$vectors[, 1L]) && equal(e$estimate_dy, replay$vectors[, 2L]))
    if (o$bootstrap_error) next
    add(paste0(label, ":exact_attempt_ids"), nrow(a) == expected_B &&
      identical(sort(a$replicate_id), seq_len(expected_B)))
    successful <- a$replicate_id[a$success]
    add(paste0(label, ":ledger_conservation"), sum(a$success) == o$n_valid &&
      sum(!a$success) == o$n_failed && equal(mean(a$success), o$success_rate) &&
      all(a$stage[a$success] == "complete") && all(nzchar(a$message[!a$success])))
    add(paste0(label, ":no_failed_vector_imputation"), nrow(v) == 3L * length(successful) &&
      setequal(v$replicate_id, successful) &&
      all(table(v$replicate_id) == 3L) && all(is.finite(as.matrix(v[c("dx", "dy")]))))
    counts <- item$unit_counts
    streams <- item$draw_streams
    add(paste0(label, ":unit_multiplicities"), is.matrix(counts) &&
      nrow(counts) == expected_B && ncol(counts) == scenario$m &&
      all(is.finite(counts)) && all(counts >= 0 & counts == floor(counts)) &&
      all(rowSums(counts) == scenario$m))
    add(paste0(label, ":complete_replicate_streams"), is.matrix(streams) &&
      nrow(streams) == expected_B && ncol(streams) == 7L && !anyNA(streams) &&
      all(streams[, 1L] %% 100L == 7L) && !anyDuplicated(data.frame(streams)))
    add(paste0(label, ":replicate_stream_sequence"), all(vapply(
      seq_len(max(nrow(streams) - 1L, 0L)), function(i)
        identical(parallel::nextRNGStream(streams[i, ]), streams[i + 1L, ]),
      logical(1L))))
    if (job$scenario == "rare_axis") {
      rare_units <- unname(generated$unit_map[names(generated$rare)[generated$rare]])
      rare_counts <- if (length(rare_units)) rowSums(counts[, rare_units, drop = FALSE]) else rep(0, expected_B)
      add(paste0(label, ":rare_selection_weights"), equal(rare_counts, a$rare_weight) &&
        equal(mean(rare_counts), o$rare_weight_mean_all) &&
        equal(if (any(a$success)) mean(rare_counts[a$success]) else NA_real_,
              o$rare_weight_mean_success) && !any(a$success & rare_counts == 0L))
    }
    for (entity in c("E015", "E003", "E006")) {
      ei <- e[e$entity == entity, ]
      vi <- v[v$entity == entity, ]
      candidate <- env$calibration_regions(c(ei$estimate_dx, ei$estimate_dy),
        as.matrix(vi[c("dx", "dy")]), c(ei$theta_dx, ei$theta_dy))
      for (policy in c("relaxed", "production")) {
        ri <- r[r$entity == entity & r$policy == policy, ]
        ri <- ri[match(candidate$method, ri$method), ]
        gate <- o$n_valid >= 20L && (policy == "relaxed" || o$passes_gate)
        delivery <- candidate$available & gate
        fields <- c("area", "center_dx", "center_dy", "radius", "truth_statistic",
                    "null_statistic", "var_dx", "var_dy", "cov_dx_dy")
        add(paste0(label, ":region_reconstruction:", entity, ":", policy),
          all(ri$gate_passed == gate) && identical(ri$delivered, delivery) &&
          identical(ri$region_computable, candidate$available) &&
          identical(ri$covered, ifelse(delivery, candidate$covered, NA)) &&
          identical(ri$rejects_zero, ifelse(delivery, candidate$rejects_zero, NA)) &&
          equal(ri[fields], candidate[fields]) &&
          equal(ri$normalized_area, candidate$area / scenario$m) &&
          all(ri$n_valid == nrow(vi)))
      }
    }
  }
  expected_paths <- vapply(jobs, function(j) sprintf("%s-%03d.rds", j$scenario,
    j$dataset_id), character(1L))
  add("no_extra_or_missing_pca_checkpoints", setequal(expected_paths,
    list.files(file.path(output_dir, "checkpoints", "pca"), pattern = "[.]rds$")))
  audit_expected <- expected[expected$dataset_id <= 3L, ]
  add("prespecified_mds_audit_keys", nrow(audits) == nrow(audit_expected) &&
    !anyDuplicated(key(audits, ids)) && setequal(key(audits, ids), key(audit_expected, ids)))
  add("mds_audit_agreement", all(audits$observed_agree) &&
    all(audits$success_ledger_agree) && all(audits$unit_draws_identical) &&
    all(audits$region_decisions_agree))
  add("mds_audit_numerical_tolerance", all(
    is.na(audits$observed_max_abs_diff) | audits$observed_max_abs_diff < 1e-8) && all(
    is.na(audits$bootstrap_max_abs_diff) | audits$bootstrap_max_abs_diff < 1e-8))
  max_difference <- function(x, y) {
    if (is.null(x) && is.null(y)) return(NA_real_)
    if (is.null(x) || is.null(y) || !identical(dim(x), dim(y))) return(Inf)
    max(abs(as.matrix(x) - as.matrix(y)), 0)
  }
  for (job in Filter(function(j) j$dataset_id <= 3L, jobs)) {
    label <- sprintf("%s-%03d", job$scenario, job$dataset_id)
    pca_file <- file.path(output_dir, "checkpoints", "pca", paste0(label, ".rds"))
    mds_file <- file.path(output_dir, "checkpoints", "cmds", paste0(label, ".rds"))
    if (!add(paste0(label, ":mds_checkpoint_exists"), file.exists(mds_file))) next
    pca <- readRDS(pca_file)
    mds <- readRDS(mds_file)
    audit <- audits[audits$scenario == job$scenario & audits$dataset_id == job$dataset_id, ]
    estimate_diff <- max_difference(pca$estimates[c("estimate_dx", "estimate_dy")],
      mds$estimates[c("estimate_dx", "estimate_dy")])
    bootstrap_diff <- max_difference(pca$selected_draws[c("dx", "dy")],
      mds$selected_draws[c("dx", "dy")])
    add(paste0(label, ":mds_checkpoint_audit_reconstruction"),
      identical(mds$job, job) && identical(mds$signature, freeze) &&
      identical(pca$outer$observed_success, mds$outer$observed_success) &&
      identical(pca$attempts$success, mds$attempts$success) &&
      identical(pca$unit_counts, mds$unit_counts) &&
      identical(pca$draw_streams, mds$draw_streams) &&
      equal(pca$regions[c("delivered", "covered", "rejects_zero")],
            mds$regions[c("delivered", "covered", "rejects_zero")]) &&
      equal(audit$observed_max_abs_diff, estimate_diff) &&
      equal(audit$bootstrap_max_abs_diff, bootstrap_diff))
  }

  # Independent, explicit denominators for downstream table reconciliation.
  groups <- split(regions, key(regions, c("scenario", "entity", "method", "policy")))
  denominators <- do.call(rbind, lapply(groups, function(r) {
    o <- outer[outer$scenario == r$scenario[1L], ]
    n_delivery <- sum(r$delivered)
    n_covered <- sum(r$covered %in% TRUE)
    n_excluded <- sum(r$rejects_zero %in% TRUE)
    data.frame(r[1L, c("scenario", "entity", "target_role", "method", "policy")],
      n_outer = nrow(o), n_observed = sum(o$observed_success),
      n_computable = sum(r$region_computable), n_delivered = n_delivery,
      n_covered = n_covered, n_zero_excluded = n_excluded,
      conditional_coverage = if (n_delivery) n_covered / n_delivery else NA_real_,
      conditional_zero_exclusion = if (n_delivery) n_excluded / n_delivery else NA_real_,
      coverage_delivery_yield = n_covered / nrow(o),
      delivery_fraction = n_delivery / nrow(o), row.names = NULL)
  }))
  rownames(denominators) <- NULL
  write.csv(denominators, file.path(output_dir, "denominator-audit.csv"), row.names = FALSE)
  add("independent_denominator_grid", nrow(denominators) == nrow(scenarios) * 18L &&
    all(denominators$n_outer == expected_M) &&
    all(denominators$n_covered <= denominators$n_delivered) &&
    all(denominators$n_delivered <= denominators$n_observed))
  if (file.exists(file.path(output_dir, "coverage-summary.csv"))) {
    summary <- read_csv("coverage-summary.csv")
    summary_ids <- c("scenario", "entity", "method", "policy")
    add("coverage_summary_keys", nrow(summary) == nrow(denominators) &&
      !anyDuplicated(key(summary, summary_ids)) &&
      setequal(key(summary, summary_ids), key(denominators, summary_ids)))
    binomial <- function(k, n) {
      if (!n) return(c(probability = NA_real_, mcse = NA_real_, low = NA_real_, high = NA_real_))
      p <- k / n
      z <- stats::qnorm(0.975)
      denominator <- 1 + z^2 / n
      middle <- (p + z^2 / (2 * n)) / denominator
      half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denominator
      c(probability = p, mcse = sqrt(p * (1 - p) / n),
        low = middle - half, high = middle + half)
    }
    for (i in seq_len(nrow(denominators))) {
      d <- denominators[i, ]
      s <- summary[match(key(d, summary_ids), key(summary, summary_ids)), ]
      r <- groups[[key(d, summary_ids)]]
      o <- outer[outer$scenario == d$scenario, ]
      cover <- binomial(d$n_covered, d$n_delivered)
      zero <- binomial(d$n_zero_excluded, d$n_delivered)
      add(paste0("coverage_summary_reconstruction:", gsub("\r", ":", key(d, summary_ids))),
        s$n_outer == d$n_outer && s$n_observed_valid == d$n_observed &&
        s$n_bootstrap_started == sum(o$bootstrap_started) &&
        s$n_gate_passed == sum(o$passes_gate) && s$n_computable == d$n_computable &&
        s$n_delivered == d$n_delivered && s$n_covered == d$n_covered &&
        equal(s$conditional_coverage, cover["probability"]) &&
        equal(s$coverage_mcse, cover["mcse"]) &&
        equal(s$coverage_wilson_lower, cover["low"]) &&
        equal(s$coverage_wilson_upper, cover["high"]) &&
        equal(s$delivery_fraction, d$delivery_fraction) &&
        equal(s$operational_coverage_and_delivery, d$coverage_delivery_yield) &&
        equal(s$conditional_zero_exclusion, zero["probability"]) &&
        equal(s$zero_exclusion_mcse, zero["mcse"]) &&
        equal(s$zero_exclusion_wilson_lower, zero["low"]) &&
        equal(s$zero_exclusion_wilson_upper, zero["high"]) &&
        s$zero_exclusion_interpretation == if (d$scenario == "regular_null")
          "null_rejection" else "descriptive_zero_exclusion")
    }
  }
  if (file.exists(file.path(output_dir, "selection-summary.csv"))) {
    selection <- read_csv("selection-summary.csv")
    selection_ids <- c("scenario", "entity", "cohort")
    add("selection_summary_keys", nrow(selection) == nrow(scenarios) * 6L &&
      !anyDuplicated(key(selection, selection_ids)) &&
      setequal(selection$cohort, c("all_observed_valid", "production_gate")))
    for (i in seq_len(nrow(selection))) {
      s <- selection[i, ]
      all_estimates <- estimates[estimates$scenario == s$scenario & estimates$entity == s$entity, ]
      e <- if (s$cohort == "production_gate") all_estimates[all_estimates$passes_gate, ] else all_estimates
      n <- nrow(e)
      mean_x <- if (n) mean(e$normalized_error_dx) else NA_real_
      mean_y <- if (n) mean(e$normalized_error_dy) else NA_real_
      square <- e$normalized_error_dx^2 + e$normalized_error_dy^2
      rmse <- if (n) sqrt(mean(square)) else NA_real_
      rmse_mcse <- if (n > 1L && rmse > 0) stats::sd(square) / (2 * rmse * sqrt(n)) else
        if (n > 1L && rmse == 0) 0 else NA_real_
      add(paste0("selection_summary_reconstruction:", gsub("\r", ":", key(s, selection_ids))),
        s$n_outer == sum(outer$scenario == s$scenario) &&
        s$n_observed_valid == nrow(all_estimates) && s$n_selected == n &&
        equal(s$fraction_of_outer, n / s$n_outer) &&
        equal(s$normalized_bias_dx, mean_x) && equal(s$normalized_bias_dy, mean_y) &&
        equal(s$bias_dx_mcse, if (n > 1L) stats::sd(e$normalized_error_dx) / sqrt(n) else NA_real_) &&
        equal(s$bias_dy_mcse, if (n > 1L) stats::sd(e$normalized_error_dy) / sqrt(n) else NA_real_) &&
        equal(s$normalized_vector_bias_norm, sqrt(mean_x^2 + mean_y^2)) &&
        equal(s$normalized_vector_rmse, rmse) && equal(s$rmse_mcse_delta, rmse_mcse))
    }
  }
  finish()
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args)) stop("Usage: Rscript validate.R /absolute/study-output/directory")
  answer <- calibration_validate_outputs(args[1L])
  cat(sum(answer$passed), "of", nrow(answer), "mechanical validation checks passed.\n")
}
