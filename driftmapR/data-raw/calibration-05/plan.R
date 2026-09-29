#!/usr/bin/env Rscript
# Reserve states and export analytic population quantities only. No measurements.
study05_write_plan <- function(output_dir, source_dir) {
  if (!exists('study05_cases', mode = 'function')) {
    source(file.path(source_dir, 'load.R')); study05_load(source_dir)
  }
  cases <- study05_cases(); jobs <- study05_jobs(cases)
  models <- lapply(seq_len(nrow(cases)), function(k) study05_model(cases[k, , drop = FALSE]))
  names(models) <- cases$case_id
  stopifnot(nrow(cases) == 31L, length(jobs) == 1640L,
            sum(cases$M * cases$B) == 326360L,
            all(vapply(models, `[[`, logical(1L), 'population_target_identified')))
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (length(list.files(output_dir, all.files = TRUE, no.. = TRUE)))
    stop('Plan output must be a new or empty directory; never overwrite a saved plan.')
  saveRDS(jobs, file.path(output_dir, 'seed-plan.rds'))
  saveRDS(models, file.path(output_dir, 'population-models.rds'))
  write.csv(cases, file.path(output_dir, 'case-plan.csv'), row.names = FALSE)
  seed_table <- do.call(rbind, lapply(jobs, function(j) data.frame(
    case_id = j$case_id, case_index = j$case_index, dataset_id = j$dataset_id,
    m = j$m, bootstrap_seed = j$bootstrap_seed, stage = j$stage,
    data_stream = paste(j$data_stream, collapse = ';'))))
  write.csv(seed_table, file.path(output_dir, 'seed-plan.csv'), row.names = FALSE)
  gaps <- targets <- anchors <- registrations <- list()
  for (k in seq_along(models)) {
    model <- models[[k]]; metadata <- cases[k, , drop = FALSE]
    attach_metadata <- function(z) {
      expanded <- metadata[rep(1L, nrow(z)), , drop = FALSE]
      rownames(expanded) <- rownames(z) <- NULL
      cbind(expanded, z)
    }
    gaps[[k]] <- attach_metadata(model$population_gaps)
    anchors[[k]] <- attach_metadata(model$anchor_diagnostics)
    registrations[[k]] <- attach_metadata(model$anchor_registration_diagnostics)
    targets[[k]] <- attach_metadata(data.frame(entity = model$target_ids,
      theta_D_dx = model$truth[, 1L], theta_D_dy = model$truth[, 2L],
      theta_C_dx = model$truth_clean[, 1L], theta_C_dy = model$truth_clean[, 2L],
      sensitivity_dx = model$truth_declared_minus_clean[, 1L],
      sensitivity_dy = model$truth_declared_minus_clean[, 2L],
      target_identified = model$population_target_identified))
  }
  write.csv(do.call(rbind, gaps), file.path(output_dir, 'population-spectra.csv'), row.names = FALSE)
  write.csv(do.call(rbind, anchors), file.path(output_dir, 'population-anchor-geometry.csv'), row.names = FALSE)
  write.csv(do.call(rbind, registrations), file.path(output_dir, 'population-anchor-registration.csv'), row.names = FALSE)
  write.csv(do.call(rbind, targets), file.path(output_dir, 'population-targets.csv'), row.names = FALSE)
  bounds <- data.frame(planned_cells = nrow(cases), planned_panels = sum(cases$M),
    planned_bootstrap_draws = sum(cases$M * cases$B),
    required_observed_occurrences = sum(cases$M * cases$m),
    required_inner_occurrences_upper_bound = sum(cases$M * cases$m * cases$B),
    reserved_measurement_panels_generated = 0L, reserved_bootstrap_draws_generated = 0L,
    runner_implemented = FALSE, freeze_scope = 'design_generator_seed_plan_analysis_contract')
  write.csv(bounds, file.path(output_dir, 'bounds.csv'), row.names = FALSE)
  vif <- do.call(rbind, lapply(c(40L, 160L), function(m) study05_gaussian_gram_vif(m, .5)))
  write.csv(vif, file.path(output_dir, 'dependence-gram-diagnostic.csv'), row.names = FALSE)
  writeLines(c('DESIGN ONLY: states reserved, analytic population quantities computed.',
    'No reserved measurement panel or bootstrap weight vector generated.',
    'A separate implementation/execution code freeze is required before evaluation.'),
    file.path(output_dir, 'STATUS.txt'))
  invisible(bounds)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop('Usage: Rscript plan.R NEW_OUTPUT_DIRECTORY')
  script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  print(study05_write_plan(args[1L], source_dir))
}
