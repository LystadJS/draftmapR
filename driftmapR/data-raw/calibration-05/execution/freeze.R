#!/usr/bin/env Rscript
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
execution_dir <- dirname(normalizePath(script))
source(file.path(execution_dir, 'load.R')); study05_execution_load(execution_dir)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop('Usage: Rscript freeze.R PASSING_TEST_EVIDENCE.rds')
destination <- file.path(execution_dir, 'implementation-freeze.rds')
if (file.exists(destination) || file.exists(file.path(execution_dir, 'implementation-manifest.csv')))
  stop('Implementation freeze exists; never overwrite it.')
study05_verify_design(execution_dir)
evidence <- readRDS(args[1L]); files <- study05_execution_files(execution_dir)
if (!identical(evidence$files, files) ||
    !identical(evidence$md5, study05_md5(file.path(execution_dir, files))))
  stop('Implementation differs from passing test evidence; rerun tests.')
if (!all(evidence$totals[c('failed', 'skipped', 'error', 'warning')] == 0) ||
    evidence$totals[['passed']] < 1L || evidence$reserved_panels_generated != 0L)
  stop('Clean engineering-only validation evidence is required.')
required <- c('core.R', 'geometry.R', 'accounting.R', 'runner.R', 'run.R', 'analyze.R', 'audit.R',
              'validate.R', 'load.R', 'test.R', 'freeze.R', 'README.md')
if (!all(required %in% files)) stop('Execution implementation is incomplete.')
engine_dir <- find.package('driftmapR')
engine_files <- sort(list.files(engine_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE))
freeze <- list(study = 'driftmapR calibration 05',
  scope = 'COMPLETE EXECUTION: numerical instrumentation, runner, collector, analyses, figures, validator, audits and tests',
  frozen_at_utc = study05_utc(), reserved_panels_generated = 0L,
  reserved_bootstrap_draws_generated = 0L, evaluation_authorized_after_this_lock = TRUE,
  design_freeze_md5 = study05_md5(file.path(execution_dir, '../freeze.rds')),
  files = files, md5 = study05_md5(file.path(execution_dir, files)),
  engine_version = as.character(utils::packageVersion('driftmapR')),
  engine_files = engine_files, engine_md5 = study05_md5(file.path(engine_dir, engine_files)),
  tests = evidence, session_info = capture.output(sessionInfo()))
saveRDS(freeze, destination)
write.csv(data.frame(file = files, md5 = freeze$md5),
  file.path(execution_dir, 'implementation-manifest.csv'), row.names = FALSE)
study05_verify_freezes(execution_dir)
cat('COMPLETE IMPLEMENTATION FROZEN:', freeze$frozen_at_utc, '\n', length(files),
    'execution dependencies; zero reserved outcomes; immutable design intact.\n')
