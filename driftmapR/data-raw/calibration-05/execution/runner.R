# Operational orchestration only. Numerical and reporting rules are frozen in
# the parent design and separate implementation sources.
study05_utc <- function() format(Sys.time(), '%Y-%m-%dT%H:%M:%OS6Z', tz = 'UTC')
study05_md5 <- function(path) unname(tools::md5sum(path))
study05_object_md5 <- function(x) {
  path <- tempfile('study05-identity-'); on.exit(unlink(path))
  saveRDS(x, path, compress = FALSE, version = 2L); study05_md5(path)
}
study05_job_key <- function(job) sprintf('%s-%03d', job$case_id, job$dataset_id)

study05_preserve_incident <- function(path, event, details = '') {
  directory <- file.path(dirname(path), 'infrastructure-incidents')
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  token <- paste0(gsub('[^0-9]', '', study05_utc()), '-', Sys.getpid())
  evidence <- file.path(directory, paste0(basename(path), '-', token))
  checksum <- if (file.exists(path)) study05_md5(path) else NA_character_
  if (file.exists(path) && !file.copy(path, evidence, overwrite = FALSE))
    stop('Cannot preserve infrastructure evidence: ', path)
  record <- list(at_utc = study05_utc(), path = path, event = event,
    details = details, content_md5 = checksum, preserved_path = evidence,
    classification = 'infrastructure; not a statistical fitting failure',
    lost_cpu_work = 'unknown; never added to numerical fit counts')
  saveRDS(record, paste0(evidence, '.incident.rds'))
  invisible(record)
}
study05_atomic_rds <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, '.tmp')
  if (file.exists(tmp)) {
    study05_preserve_incident(tmp, 'stale_partial', 'Preserved before original job resume.')
    unlink(tmp)
  }
  saveRDS(object, tmp, compress = 'gzip', version = 2L)
  if (!file.rename(tmp, path)) stop('Cannot finalize atomic output: ', path)
  invisible(path)
}
study05_checkpoint_save <- function(result, path, identity) {
  if (file.exists(path) || file.exists(paste0(path, '.manifest.rds')))
    stop('Refusing to overwrite a completed checkpoint: ', path)
  if (is.null(result$job)) stop('Checkpoint requires its original job.')
  payload <- list(identity = identity, job = result$job, result = result)
  study05_atomic_rds(payload, path)
  manifest <- list(content_md5 = study05_md5(path), identity = identity,
    job = result$job, completed_at_utc = study05_utc(), bytes = file.info(path)$size)
  study05_atomic_rds(manifest, paste0(path, '.manifest.rds'))
  invisible(path)
}
study05_checkpoint_read <- function(path, identity, job) {
  fail <- function(message) {
    study05_preserve_incident(path, 'checkpoint_identity_or_corruption', message)
    stop(message, ': ', path, call. = FALSE)
  }
  sidecar <- paste0(path, '.manifest.rds')
  if (!file.exists(path) || !file.exists(sidecar)) fail('Incomplete checkpoint or checksum manifest')
  manifest <- tryCatch(readRDS(sidecar), error = function(e) NULL)
  if (is.null(manifest) || !identical(study05_md5(path), manifest$content_md5))
    fail('Checkpoint checksum corruption')
  if (!identical(manifest$identity, identity)) fail('Checkpoint source/plan identity mismatch')
  if (!identical(manifest$job, job)) fail('Checkpoint job/seed identity mismatch')
  payload <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(payload) || !identical(payload$identity, identity) ||
      !identical(payload$job, job) || !identical(payload$result$job, job))
    fail('Checkpoint payload identity/job corruption')
  payload$result
}
study05_verify_design <- function(execution_dir) {
  source_dir <- normalizePath(file.path(execution_dir, '..'))
  if (!file.exists(file.path(source_dir, 'freeze.rds'))) stop('Missing immutable design freeze.')
  freeze <- readRDS(file.path(source_dir, 'freeze.rds'))
  if (!identical(study05_md5(file.path(source_dir, freeze$files)), freeze$md5))
    stop('Immutable Study05 design dependency changed.')
  if (as.character(utils::packageVersion('driftmapR')) != freeze$settings$engine_version)
    stop('Installed public engine differs from pinned version.')
  invisible(freeze)
}
study05_execution_files <- function(execution_dir) {
  files <- list.files(execution_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  sort(files[!files %in% c('implementation-freeze.rds', 'implementation-manifest.csv')])
}
study05_verify_freezes <- function(execution_dir) {
  design <- study05_verify_design(execution_dir)
  if (!file.exists(file.path(execution_dir, 'implementation-freeze.rds')))
    stop('Missing complete implementation freeze; evaluation is forbidden.')
  freeze <- readRDS(file.path(execution_dir, 'implementation-freeze.rds'))
  if (!identical(study05_md5(file.path(execution_dir, freeze$files)), freeze$md5))
    stop('Frozen Study05 execution implementation changed.')
  if (!identical(freeze$design_freeze_md5, study05_md5(file.path(execution_dir, '../freeze.rds'))))
    stop('Design freeze identity changed.')
  if (!identical(freeze$files, study05_execution_files(execution_dir)))
    stop('Execution source file set changed after freeze.')
  engine_dir <- find.package('driftmapR')
  if (!identical(study05_md5(file.path(engine_dir, freeze$engine_files)), freeze$engine_md5))
    stop('Pinned installed public engine content changed.')
  list(design_freeze_md5 = freeze$design_freeze_md5,
    implementation_freeze_md5 = study05_md5(file.path(execution_dir, 'implementation-freeze.rds')),
    plan_md5 = study05_md5(file.path(execution_dir, '../design/seed-plan.rds')),
    engine_version = design$settings$engine_version)
}
study05_execute_jobs <- function(jobs, work, workers = 1L) {
  if (length(workers) != 1L || !is.finite(workers) || workers < 1L ||
      workers > 8L || workers != floor(workers)) stop('Use 1 to 8 outer workers.')
  answers <- if (workers == 1L) lapply(jobs, work) else
    parallel::mclapply(jobs, work, mc.cores = as.integer(workers),
      mc.set.seed = FALSE, mc.preschedule = FALSE)
  failed <- vapply(answers, function(x) inherits(x, 'try-error') || is.null(x), logical(1L))
  if (any(failed)) stop('Infrastructure/worker interruption; preserve and resume original jobs: ',
    paste(which(failed), collapse = ', '))
  answers
}

# Materialize all random weights and streams before any measurement panel is
# generated. Feature and unit names match both frozen generators exactly.
study05_materialize_draws <- function(job, case) {
  features <- sprintf('f%03d', seq_len(job$m))
  units <- stats::setNames(sprintf('unit%03d', seq_len(job$m)), features)
  assumption <- if (case$rho_unit > 0) paste(
    'Intentional dependence stress: ordered paired measurement units are AR(1);',
    'iid unit resampling and iid delete-one studentization are misspecified.') else
    'The simulation generates iid paired measurement units across entities and periods.'
  design <- driftmapR::paired_unit_design(units, assumptions = assumption)
  plan <- getFromNamespace('bootstrap_draw_plan', 'driftmapR')(
    design, features, as.integer(case$B), job$bootstrap_seed)
  list(job = job, B = case$B, assumptions = assumption,
    weights = do.call(rbind, lapply(plan$draws, function(d) d$feature_weights[features])),
    streams = do.call(rbind, lapply(plan$draws, `[[`, 'rng_stream')))
}

study05_collect <- function(paths, jobs, identity, output_dir, evaluation = TRUE) {
  if (length(paths) != length(jobs) || anyDuplicated(paths)) stop('Incomplete or duplicate checkpoint set.')
  keys <- vapply(jobs, study05_job_key, character(1L))
  if (anyDuplicated(keys)) stop('Duplicate planned job keys.')
  if (evaluation) {
    if (!identical(jobs, study05_jobs())) stop('Collector requires the entire untouched evaluation plan.')
  } else {
    if (!all(vapply(jobs, function(j) identical(j$stage, study05_settings()$fixture_stage) &&
      identical(j$dataset_id, 999L) && identical(j$bootstrap_seed, 779L), logical(1L))))
      stop('Engineering collector only accepts seed779/dataset999 fixtures.')
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  summaries <- vector('list', length(paths)); accounting <- audits <- validation <- stages <- summaries
  compact <- list(); targets <- study05_settings()$targets
  # Append large mandatory tables directly; do not retain millions of strings.
  streams <- list()
  on.exit(for (connection in streams) close(connection), add = TRUE)
  write_table <- function(x, relative) {
    if (is.null(x)) return(invisible(NULL))
    if (is.null(streams[[relative]])) {
      destination <- file.path(output_dir, relative)
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      streams[[relative]] <<- gzfile(destination, 'wt')
      header <- TRUE
    } else header <- FALSE
    utils::write.table(x, streams[[relative]], sep = ',', row.names = FALSE,
      col.names = header, quote = TRUE, na = 'NA')
  }
  for (i in seq_along(paths)) {
    r <- study05_checkpoint_read(paths[i], identity, jobs[[i]])
    validation[[i]] <- r$mechanical_validation
    stages[[i]] <- study05_stage_accounting(r)
    accounting[[i]] <- study04_deletion_accounting(r)$summary
    events <- study04_deletion_accounting(r)$events
    write_table(events, 'deletion-failures-warnings.csv.gz')
    for (chart in c('core', 'frame')) {
      z <- if (chart == 'core') r else r$frame
      for (name in c('outer', 'estimates', 'regions', 'attempts', 'studentization'))
        write_table(z[[name]], paste0(chart, '/', name, '.csv.gz'))
    }
    extracted <- study05_analysis_extract(r)
    for (name in names(extracted)) compact[[name]][[i]] <- extracted[[name]]
    audits[[i]] <- r$audit
    summaries[[i]] <- data.frame(case_id = r$job$case_id, dataset_id = r$job$dataset_id,
      path = basename(paths[i]), bytes = file.info(paths[i])$size,
      content_md5 = study05_md5(paths[i]), B = r$B)
    if (i %% 100L == 0L) cat('Collected', i, 'of', length(paths), '\n')
  }
  tables <- lapply(compact, study03_bind)
  tables$caseplan <- study05_cases()
  if (!evaluation) {
    tables$caseplan <- tables$caseplan[tables$caseplan$case_id %in%
      vapply(jobs, `[[`, character(1L), 'case_id'), , drop = FALSE]
    tables$caseplan$M <- 1L
    tables$caseplan$B <- vapply(tables$caseplan$case_id, function(id)
      tables$outer$B[match(id, tables$outer$case_id)], integer(1L))
  }
  study05_atomic_rds(tables, file.path(output_dir, 'analysis-inputs.rds'))
  for (name in names(tables)) if (is.data.frame(tables[[name]]))
    write_table(tables[[name]], paste0('analysis-inputs/', name, '.csv.gz'))
  for (name in c('checkpoint-index', 'deletion-accounting', 'stage-accounting', 'audit', 'mechanical-validation')) {
    value <- switch(name, 'checkpoint-index' = study03_bind(summaries),
      'deletion-accounting' = study03_bind(accounting), 'audit' = study03_bind(audits),
      'stage-accounting' = study03_bind(stages),
      'mechanical-validation' = study03_bind(validation))
    if (!is.null(value)) write.csv(value, file.path(output_dir, paste0(name, '.csv')), row.names = FALSE)
  }
  if (evaluation && sum(vapply(jobs, function(j) study05_cases()$B[j$case_index], integer(1))) != 326360L)
    stop('Frozen draw budget mismatch.')
  tables
}

study05_main <- function(execution_dir, output_dir, workers = 8L) {
  identity <- study05_verify_freezes(execution_dir)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir)
  jobs <- readRDS(file.path(execution_dir, '../design/seed-plan.rds'))
  cases <- study05_cases()
  stopifnot(length(jobs) == 1640L, sum(cases$M * cases$B) == 326360L)
  signature <- file.path(output_dir, 'execution-identity.rds')
  if (file.exists(signature)) {
    if (!identical(readRDS(signature), identity)) stop('Output directory source/plan identity differs.')
  } else study05_atomic_rds(identity, signature)
  for (directory in c('draw-plans', 'checkpoints'))
    dir.create(file.path(output_dir, directory), showWarnings = FALSE)
  if (!file.exists(file.path(output_dir, 'execution-start.txt')))
    writeLines(c(paste('start_utc', study05_utc()), paste('workers', workers),
      'planned_panels 1640', 'planned_draws 326360', 'reserved panel generation follows complete draw-plan materialization'),
      file.path(output_dir, 'execution-start.txt'))
  saved_plan <- file.path(output_dir, 'seed-plan.rds')
  if (file.exists(saved_plan)) {
    if (!identical(readRDS(saved_plan), jobs)) {
      study05_preserve_incident(saved_plan, 'saved_seed_plan_mismatch', 'Resume rejected; immutable original plan remains authoritative.')
      stop('Saved seed plan differs from the untouched original plan.')
    }
  } else study05_atomic_rds(jobs, saved_plan)
  write.csv(cases, file.path(output_dir, 'caseplan.csv'), row.names = FALSE)
  writeLines(capture.output(sessionInfo()), file.path(output_dir, 'session-info.txt'))
  plan_work <- function(job) {
    path <- file.path(output_dir, 'draw-plans', paste0(study05_job_key(job), '.rds'))
    if (file.exists(path)) study05_checkpoint_read(path, identity, job) else {
      p <- study05_materialize_draws(job, cases[job$case_index, , drop = FALSE])
      study05_checkpoint_save(p, path, identity)
    }
    path
  }
  planned <- study05_execute_jobs(jobs, plan_work, workers)
  writeLines(c(paste('completed_at_utc', study05_utc()), 'panels 1640', 'draws 326360',
    'Every planned weight vector and RNG stream saved before measurement generation.'),
    file.path(output_dir, 'draw-plans-complete.txt'))
  identity_check <- study05_verify_freezes(execution_dir)
  stopifnot(identical(identity_check, identity))
  work <- function(job) {
    path <- file.path(output_dir, 'checkpoints', paste0(study05_job_key(job), '.rds'))
    if (file.exists(path)) {
      study05_checkpoint_read(path, identity, job)
      return(path)
    }
    case <- cases[job$case_index, , drop = FALSE]
    tryCatch({
      g <- study05_generate(job, case, allow_evaluation = TRUE)
      pending <- paste0(path, '.pending.rds')
      if (file.exists(pending)) {
        result <- study05_checkpoint_read(pending, identity, job)
      } else {
        result <- study05_one(job, case, generated = g, keep_inner_values = job$dataset_id == 1L)
        study05_checkpoint_save(result, pending, identity)
      }
      p <- study05_checkpoint_read(file.path(output_dir, 'draw-plans', paste0(study05_job_key(job), '.rds')), identity, job)
      if (!identical(unname(result$weights), unname(p$weights)) ||
          !identical(unname(result$streams), unname(p$streams))) stop('Pre-materialized draw identity mismatch.')
      result$mechanical_validation <- study05_validate_result(result)
      if (job$dataset_id == 1L) result$audit <- study05_public_audit(result, g)
      study05_checkpoint_save(result, path, identity)
      unlink(c(pending, paste0(pending, '.manifest.rds')))
      cat('Completed', study05_job_key(job), 'at', study05_utc(), '\n')
      path
    }, error = function(e) {
      study05_preserve_incident(path, 'worker_interruption', conditionMessage(e))
      evidence_path <- file.path(dirname(path), 'infrastructure-incidents',
        paste0(study05_job_key(job), '-', gsub('[^0-9]', '', study05_utc()), '-error-evidence.rds'))
      study05_atomic_rds(list(job = job, identity = identity, at_utc = study05_utc(),
        condition = e, audit = e$audit, pending_result_path = paste0(path, '.pending.rds'),
        classification = 'Uncompleted infrastructure/implementation evidence; no replacement panel'), evidence_path)
      stop(e)
    })
  }
  paths <- unlist(study05_execute_jobs(jobs, work, workers), use.names = FALSE)
  stopifnot(identical(study05_verify_freezes(execution_dir), identity))
  writeLines(c(paste('at_utc', study05_utc()), 'All planned panel checkpoints complete; collection/analysis pending.'),
    file.path(output_dir, 'panels-complete.txt'))
  tables <- study05_collect(paths, jobs, identity, output_dir)
  study05_analyze(tables, file.path(output_dir, 'analysis'), figures = TRUE)
  stopifnot(identical(study05_verify_freezes(execution_dir), identity))
  writeLines(c(paste('end_utc', study05_utc()), 'planned_panels 1640',
    'validated_checkpoints 1640', 'planned_draws 326360',
    'All planned jobs retained; no replacement panels or successful-fit redraws.'),
    file.path(output_dir, 'execution-complete.txt'))
  invisible(paths)
}
