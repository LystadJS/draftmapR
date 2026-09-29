#!/usr/bin/env Rscript
# A design freeze, not execution authorization or an evaluation runner.
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
source_dir <- dirname(normalizePath(script))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop('Usage: Rscript freeze.R PASSING_TEST_EVIDENCE.rds')
if (file.exists(file.path(source_dir, 'freeze.rds')) ||
    file.exists(file.path(source_dir, 'freeze-manifest.csv')))
  stop('Design freeze already exists; it must never be overwritten.')
source(file.path(source_dir, 'load.R')); study05_load(source_dir)
if (as.character(utils::packageVersion('driftmapR')) != study05_settings()$engine_version)
  stop('Installed public engine version differs from the pinned design.')
evidence <- readRDS(args[1L])
files_tested <- study05_r_files(source_dir)
if (!identical(evidence$files, files_tested) ||
    !identical(evidence$md5, unname(tools::md5sum(file.path(source_dir, files_tested)))))
  stop('R source differs from passing engineering-test evidence; rerun tests.')
if (!all(evidence$totals[c('failed', 'skipped', 'error', 'warning')] == 0) ||
    evidence$totals[['passed']] < 1L) stop('Engineering tests have not passed cleanly.')
source(file.path(source_dir, 'plan.R'))
bounds <- study05_write_plan(file.path(source_dir, 'design'), source_dir)
local_files <- list.files(source_dir, recursive = TRUE, all.files = TRUE, no.. = TRUE)
files <- sort(unique(c(local_files, files_tested, '../../DESCRIPTION', '../../NAMESPACE',
  '../calibration-03/method-specification.md', '../calibration-04/README.md')))
files <- files[!files %in% c('freeze.rds', 'freeze-manifest.csv')]
md5 <- unname(tools::md5sum(file.path(source_dir, files)))
if (anyNA(md5)) stop('A frozen dependency could not be hashed.')
freeze <- list(study = 'driftmapR calibration 05',
  scope = 'DESIGN: generator, fixtures, analytic targets, reserved seeds, analysis and accounting contract',
  frozen_at_utc = format(Sys.time(), '%Y-%m-%dT%H:%M:%OS6Z', tz = 'UTC'),
  reserved_measurement_panels_generated = 0L,
  reserved_bootstrap_weight_vectors_generated = 0L,
  evaluation_runner_implemented = FALSE,
  implementation_execution_freeze_required = TRUE,
  settings = study05_settings(), bounds = bounds, tests = evidence,
  files = files, md5 = md5, session_info = capture.output(sessionInfo()))
saveRDS(freeze, file.path(source_dir, 'freeze.rds'))
write.csv(data.frame(file = files, md5 = md5), file.path(source_dir, 'freeze-manifest.csv'), row.names = FALSE)
cat('DESIGN FROZEN:', freeze$frozen_at_utc, '\n', length(files), 'hashed dependencies;',
    bounds$planned_panels, 'reserved panels;', bounds$planned_bootstrap_draws,
    'planned draws; zero reserved evaluation outcomes.\n')
