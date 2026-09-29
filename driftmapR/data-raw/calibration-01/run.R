#!/usr/bin/env Rscript
# Reproduce study 01: Rscript run.R /absolute/output/directory [workers=4]
# Run from any directory. Resume only from checkpoints with matching frozen inputs.

calibration_capture <- function(expr) {
  warnings <- character()
  value <- tryCatch(withCallingHandlers(expr, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) e)
  list(ok = !inherits(value, "error"), value = value, warnings = warnings,
       message = if (inherits(value, "error")) conditionMessage(value) else "")
}

calibration_gap <- function(values) {
  min(vapply(values, function(x) (x[2L] - x[3L]) / x[1L], numeric(1L)))
}

calibration_empty_regions <- function(job, population, reason) {
  grid <- expand.grid(entity = population$layout$target_ids,
                      method = c("wald", "bootstrap_mahalanobis", "bootstrap_ball"),
                      policy = c("relaxed", "production"), stringsAsFactors = FALSE)
  truth <- population$movement[match(grid$entity, population$movement$entity), ]
  data.frame(scenario = job$scenario, dataset_id = job$dataset_id, grid,
    target_role = ifelse(grid$entity == "E015", "primary", "secondary"),
    region_computable = FALSE, gate_passed = FALSE, delivered = FALSE,
    reason = reason, covered = NA, rejects_zero = NA, area = NA_real_,
    normalized_area = NA_real_, n_valid = 0L,
    truth_norm = sqrt(truth$dx^2 + truth$dy^2),
    center_dx = NA_real_, center_dy = NA_real_,
    radius = NA_real_, truth_statistic = NA_real_, null_statistic = NA_real_,
    var_dx = NA_real_, var_dy = NA_real_, cov_dx_dy = NA_real_)
}

calibration_one <- function(job, scenario, population, B = 199L, method = "pca") {
  started <- proc.time()[[3L]]
  generated <- calibration_generate(scenario, job$data_stream)
  outer <- data.frame(scenario = job$scenario, dataset_id = job$dataset_id,
    m = scenario$m, sigma = scenario$sigma, rare_count = generated$rare_count,
    observed_success = FALSE, failure_stage = "", message = "",
    bootstrap_started = FALSE, bootstrap_error = FALSE,
    n_attempted = 0L, n_valid = 0L, n_failed = 0L, success_rate = NA_real_,
    passes_gate = FALSE, elapsed_seconds = NA_real_, retained_bytes = NA_real_,
    obs_eigengap_min = NA_real_, pop_eigengap_min = calibration_gap(population$eigenvalues),
    rare_weight_mean_all = NA_real_, rare_weight_mean_success = NA_real_,
    bootstrap_seed = job$bootstrap_seed, engine = method)
  result <- list(job = job, outer = outer, estimates = NULL,
    regions = calibration_empty_regions(job, population, "observed_fit_failed"),
    attempts = NULL, selected_draws = NULL, unit_counts = NULL,
    warnings = list(), diagnostics = NULL, gauge_rotation = NULL)
  finish <- function() {
    result$outer$elapsed_seconds <- proc.time()[[3L]] - started
    result$outer$retained_bytes <- as.numeric(object.size(result))
    result
  }
  observed <- calibration_capture({
    fit <- driftmapR::embed_snapshots(generated$data, generated$features,
      method = method, periods = 1:2, standardize = "none")
    driftmapR::align_snapshots(fit, reference = "previous", scale = FALSE,
      anchors = generated$layout$anchors)
  })
  result$warnings$observed <- observed$warnings
  if (!observed$ok) {
    result$outer$failure_stage <- "observed_fit"
    result$outer$message <- observed$message
    return(finish())
  }
  fit <- observed$value
  result$outer$observed_success <- TRUE
  result$observed_embedding_diagnostics <- fit$diagnostics$embedding
  # Eigenvalue spectra stored by adapters provide a common gap definition.
  spectra <- lapply(fit$embedding_metadata$fits, function(x) x$eigenvalues)
  if (length(spectra) == 2L && all(lengths(spectra) >= 3L)) {
    result$outer$obs_eigengap_min <- calibration_gap(spectra)
  }
  registration <- calibration_capture(calibration_gauge_rotation(
    fit, population$object, generated$layout$anchors))
  result$warnings$registration <- registration$warnings
  if (!registration$ok) {
    result$outer$observed_success <- FALSE
    result$outer$failure_stage <- "observed_registration"
    result$outer$message <- registration$message
    result$regions$reason <- "observed_registration_failed"
    return(finish())
  }
  rotation <- registration$value
  result$gauge_rotation <- rotation
  target_ids <- population$layout$target_ids
  movement <- driftmapR::measure_drift(fit)
  movement <- movement[match(target_ids, movement$entity), ]
  estimate <- as.matrix(movement[c("dx", "dy")]) %*% rotation
  truth_rows <- population$movement[match(target_ids, population$movement$entity), ]
  truth <- as.matrix(truth_rows[c("dx", "dy")])
  errors <- estimate - truth
  result$estimates <- data.frame(scenario = job$scenario, dataset_id = job$dataset_id,
    entity = target_ids, target_role = c("primary", "secondary", "secondary"),
    theta_dx = truth[, 1L], theta_dy = truth[, 2L],
    estimate_dx = estimate[, 1L], estimate_dy = estimate[, 2L],
    error_dx = errors[, 1L], error_dy = errors[, 2L],
    error_norm = sqrt(rowSums(errors^2)), squared_error = rowSums(errors^2),
    normalized_error_dx = errors[, 1L] / sqrt(scenario$m),
    normalized_error_dy = errors[, 2L] / sqrt(scenario$m),
    passes_gate = FALSE, n_valid = 0L)
  design <- driftmapR::paired_unit_design(generated$unit_map,
    assumptions = if (scenario$rho_unit > 0) paste(
      "Deliberately misspecified negative control: unit dependence violates ordinary",
      "resampling independence. No inferential validity is asserted.") else paste(
      "The simulation generates independent identically distributed Gaussian or",
      "mixture measurement units, paired across entities and periods."))
  result$outer$bootstrap_started <- TRUE
  boot <- calibration_capture(driftmapR::bootstrap_drift(fit, design,
    B = B, seed = job$bootstrap_seed, min_success = 0.95, keep = "replicates"))
  result$warnings$bootstrap <- boot$warnings
  if (!boot$ok) {
    result$outer$bootstrap_error <- TRUE
    result$outer$failure_stage <- "bootstrap_call"
    result$outer$message <- boot$message
    result$regions$reason <- "bootstrap_call_failed"
    return(finish())
  }
  b <- boot$value$bootstrap
  result$outer$n_attempted <- nrow(b$attempts)
  result$outer$n_valid <- sum(b$attempts$success)
  result$outer$n_failed <- sum(!b$attempts$success)
  result$outer$success_rate <- mean(b$attempts$success)
  result$outer$passes_gate <- result$outer$n_valid >= 20L && result$outer$success_rate >= 0.95
  result$estimates$passes_gate <- result$outer$passes_gate
  result$estimates$n_valid <- result$outer$n_valid
  counts <- do.call(rbind, lapply(b$draws, `[[`, "unit_counts"))
  rownames(counts) <- as.character(seq_len(B))
  result$unit_counts <- counts
  result$draw_streams <- do.call(rbind, lapply(b$draws, `[[`, "rng_stream"))
  rare_weights <- if (scenario$scenario == "rare_axis") vapply(b$draws,
    function(x) sum(x$feature_weights[names(generated$rare)[generated$rare]]), numeric(1L)) else
    rep(NA_real_, B)
  result$rare_features <- generated$rare
  result$attempts <- cbind(scenario = job$scenario, dataset_id = job$dataset_id,
                           b$attempts, rare_weight = rare_weights)
  if (scenario$scenario == "rare_axis") {
    result$outer$rare_weight_mean_all <- mean(rare_weights)
    result$outer$rare_weight_mean_success <- if (any(b$attempts$success))
      mean(rare_weights[b$attempts$success]) else NA_real_
  }
  result$diagnostics <- b$diagnostics
  result$bootstrap_warnings <- b$warnings
  result$provenance <- b$provenance
  result$bootstrap_settings <- b$settings
  selected <- b$replicates[b$replicates$entity %in% target_ids, ]
  vectors <- as.matrix(selected[c("dx", "dy")]) %*% rotation
  result$selected_draws <- data.frame(scenario = rep(job$scenario, nrow(selected)),
    dataset_id = rep(job$dataset_id, nrow(selected)), replicate_id = selected$replicate_id,
    entity = selected$entity, dx = vectors[, 1L], dy = vectors[, 2L])
  region_rows <- lapply(seq_along(target_ids), function(i) {
    rows <- result$selected_draws[result$selected_draws$entity == target_ids[i], ]
    candidate <- calibration_regions(as.numeric(estimate[i, ]),
      as.matrix(rows[c("dx", "dy")]), as.numeric(truth[i, ]))
    do.call(rbind, lapply(c("relaxed", "production"), function(policy) {
      gate <- result$outer$n_valid >= 20L && (policy == "relaxed" || result$outer$passes_gate)
      delivered <- candidate$available & gate
      data.frame(scenario = job$scenario, dataset_id = job$dataset_id,
        entity = target_ids[i], method = candidate$method, policy = policy,
        target_role = ifelse(target_ids[i] == "E015", "primary", "secondary"),
        region_computable = candidate$available, gate_passed = gate, delivered = delivered,
        reason = ifelse(!gate, ifelse(result$outer$n_valid < 20L, "insufficient_valid", "success_gate_failed"), candidate$reason),
        covered = ifelse(delivered, candidate$covered, NA),
        rejects_zero = ifelse(delivered, candidate$rejects_zero, NA),
        area = candidate$area, normalized_area = candidate$area / scenario$m,
        n_valid = candidate$n_valid, truth_norm = sqrt(sum(truth[i, ]^2)),
        center_dx = candidate$center_dx, center_dy = candidate$center_dy,
        radius = candidate$radius, truth_statistic = candidate$truth_statistic,
        null_statistic = candidate$null_statistic, var_dx = candidate$var_dx,
        var_dy = candidate$var_dy, cov_dx_dy = candidate$cov_dx_dy)
    }))
  })
  result$regions <- do.call(rbind, region_rows)
  finish()
}

calibration_job_file <- function(job, output_dir, engine = "pca") {
  file.path(output_dir, "checkpoints", engine,
    sprintf("%s-%03d.rds", job$scenario, job$dataset_id))
}

calibration_checkpoint <- function(job, output_dir, source_dir, signature, engine = "pca") {
  path <- calibration_job_file(job, output_dir, engine)
  if (file.exists(path)) {
    existing <- readRDS(path)
    if (!identical(existing$signature, signature) || !identical(existing$job, job))
      stop("Checkpoint does not match the frozen design: ", path)
    return(path)
  }
  scenario <- calibration_scenarios()[job$scenario_id, , drop = FALSE]
  population <- calibration_population(scenario)
  result <- calibration_one(job, scenario, population, B = 199L, method = engine)
  result$signature <- signature
  tmp <- paste0(path, ".tmp")
  saveRDS(result, tmp, compress = "gzip")
  if (!file.rename(tmp, path)) stop("Could not finalize checkpoint: ", path)
  path
}

calibration_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (!length(args)) stop("Usage: Rscript run.R /absolute/output/directory [workers=4]")
  script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  for (name in c("model.R", "regions.R")) source(file.path(source_dir, name), local = .GlobalEnv)
  output_dir <- args[1L]
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir)
  workers <- if (length(args) > 1L) as.integer(args[2L]) else 4L
  stopifnot(workers >= 1L, workers <= 8L)
  for (engine in c("pca", "cmds")) dir.create(file.path(output_dir, "checkpoints", engine), recursive = TRUE, showWarnings = FALSE)
  source_files <- file.path(source_dir, c("protocol.md", "model.R", "regions.R", "run.R"))
  hashes <- tools::md5sum(source_files)
  names(hashes) <- basename(names(hashes))
  signature <- list(source_md5 = hashes, M = 80L, B = 199L, data_seed = 260915L,
    bootstrap_seed_formula = "1400000 + scenario_id * 1000 + dataset_id",
    R = R.version.string, package = as.character(utils::packageVersion("driftmapR")))
  freeze <- file.path(output_dir, "frozen-design.rds")
  if (file.exists(freeze)) {
    if (!identical(readRDS(freeze), signature)) stop("Frozen design mismatch; use a fresh output directory.")
  } else {
    saveRDS(signature, freeze)
    write.csv(data.frame(file = names(hashes), md5 = unname(hashes)), file.path(output_dir, "source-hashes-before-run.csv"), row.names = FALSE)
    file.copy(source_files, output_dir, overwrite = FALSE)
    capture.output(sessionInfo(), file = file.path(output_dir, "session-info.txt"))
  }
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(260915L)
  stream <- .Random.seed
  scenarios <- calibration_scenarios()
  population_targets <- lapply(seq_len(nrow(scenarios)), function(i)
    calibration_population(scenarios[i, , drop = FALSE]))
  names(population_targets) <- scenarios$scenario
  saveRDS(population_targets, file.path(output_dir, "population-targets.rds"))
  jobs <- list()
  for (s in seq_len(nrow(scenarios))) for (d in seq_len(80L)) {
    jobs[[length(jobs) + 1L]] <- list(scenario_id = s, scenario = scenarios$scenario[s],
      dataset_id = d, data_stream = stream, bootstrap_seed = as.integer(1400000L + s * 1000L + d))
    stream <- parallel::nextRNGStream(stream)
  }
  saveRDS(jobs, file.path(output_dir, "seed-plan.rds"))
  write.csv(do.call(rbind, lapply(jobs, function(j) data.frame(
    scenario = j$scenario, dataset_id = j$dataset_id, bootstrap_seed = j$bootstrap_seed,
    data_stream = paste(j$data_stream, collapse = ";")))), file.path(output_dir, "seed-plan.csv"), row.names = FALSE)
  started <- Sys.time()
  cl <- parallel::makePSOCKcluster(workers, outfile = file.path(output_dir, "workers.log"))
  on.exit(parallel::stopCluster(cl), add = TRUE)
  parallel::clusterCall(cl, function(source_dir) {
    Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
    for (name in c("model.R", "regions.R", "run.R")) source(file.path(source_dir, name), local = .GlobalEnv)
    NULL
  }, source_dir)
  cat("Frozen inputs saved. Starting/resuming 480 outer PCA datasets with", workers, "workers.\n")
  flush.console()
  # Four small scheduling batches allow progress updates without changing seeds.
  paths <- character()
  for (batch in split(seq_along(jobs), ceiling(seq_along(jobs) / 40L))) {
    batch_paths <- parallel::parLapplyLB(cl, jobs[batch], calibration_checkpoint,
      output_dir = output_dir, source_dir = source_dir, signature = signature, engine = "pca")
    paths <- c(paths, unlist(batch_paths))
    cat(length(paths), "/480 outer datasets checkpointed\n"); flush.console()
  }
  results <- lapply(paths, readRDS)
  bind_component <- function(name) do.call(rbind, lapply(results, `[[`, name))
  exports <- c(outer = "outer-results.csv", estimates = "estimates.csv", regions = "regions.csv",
    attempts = "bootstrap-attempts.csv", selected_draws = "bootstrap-vectors.csv")
  for (component in names(exports)) {
    write.csv(bind_component(component), file.path(output_dir, exports[[component]]), row.names = FALSE, na = "NA")
  }
  audit_jobs <- Filter(function(j) j$dataset_id <= 3L, jobs)
  audit_paths <- parallel::parLapplyLB(cl, audit_jobs, calibration_checkpoint,
      output_dir = output_dir, source_dir = source_dir, signature = signature, engine = "cmds")
  maxdiff <- function(x, y) if (is.null(x) && is.null(y)) NA_real_ else if (is.null(x) || is.null(y)) Inf else max(abs(x - y), 0)
  audits <- lapply(seq_along(audit_jobs), function(i) {
    a <- readRDS(calibration_job_file(audit_jobs[[i]], output_dir, "pca"))
    b <- readRDS(audit_paths[[i]])
    data.frame(scenario = a$job$scenario, dataset_id = a$job$dataset_id,
      observed_agree = identical(a$outer$observed_success, b$outer$observed_success),
      success_ledger_agree = identical(a$attempts$success, b$attempts$success),
      unit_draws_identical = identical(a$unit_counts, b$unit_counts),
      observed_max_abs_diff = maxdiff(a$estimates[c("estimate_dx", "estimate_dy")], b$estimates[c("estimate_dx", "estimate_dy")]),
      bootstrap_max_abs_diff = maxdiff(a$selected_draws[c("dx", "dy")], b$selected_draws[c("dx", "dy")]),
      region_decisions_agree = identical(a$regions[c("delivered", "covered", "rejects_zero")], b$regions[c("delivered", "covered", "rejects_zero")]))
  })
  write.csv(do.call(rbind, audits), file.path(output_dir, "pca-mds-audit.csv"), row.names = FALSE)
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  writeLines(c(paste("Started:", started), paste("Finished:", Sys.time()), paste("Wall seconds:", elapsed),
    paste("Workers:", workers), "Parallelism is across independent outer datasets; bootstrap attempts are serial per dataset."),
    file.path(output_dir, "execution.txt"))
  cat("Complete. PCA attempts:", sum(bind_component("outer")$n_attempted), "Wall seconds:", elapsed, "\n")
  invisible(results)
}

if (sys.nframe() == 0L) calibration_main()
