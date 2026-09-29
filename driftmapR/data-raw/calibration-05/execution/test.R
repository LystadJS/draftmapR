#!/usr/bin/env Rscript
# All generated measurements here are seed779/dataset999 engineering fixtures.
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
execution_dir <- dirname(normalizePath(script))
source_dir <- normalizePath(file.path(execution_dir, '..'))
source(file.path(execution_dir, 'load.R')); study05_execution_load(execution_dir)
study05_verify_design(execution_dir)
files_before_tests <- study05_execution_files(execution_dir)
md5_before_tests <- study05_md5(file.path(execution_dir, files_before_tests))
design_tests <- testthat::test_dir(file.path(source_dir, 'tests'),
  reporter = 'summary', stop_on_failure = TRUE)
execution_tests <- testthat::test_dir(file.path(execution_dir, 'tests'),
  reporter = 'summary', stop_on_failure = TRUE)
counts <- rbind(as.data.frame(design_tests), as.data.frame(execution_tests))
totals <- colSums(counts[intersect(c('nb', 'failed', 'skipped', 'error', 'warning', 'passed'), names(counts))])
cat('\nStudy05 design and execution test blocks:', nrow(counts), '\n'); print(totals)
stopifnot(all(totals[c('failed', 'skipped', 'error', 'warning')] == 0), totals[['passed']] > 0)
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 1L) {
  files <- study05_execution_files(execution_dir)
  if (!identical(files, files_before_tests) ||
      !identical(study05_md5(file.path(execution_dir, files)), md5_before_tests))
    stop('Implementation changed during testing; rerun the entire engineering suite.')
  evidence <- list(tested_at_utc = study05_utc(), blocks = nrow(counts), totals = totals,
    files = files, md5 = study05_md5(file.path(execution_dir, files)),
    design_freeze_md5 = study05_md5(file.path(source_dir, 'freeze.rds')),
    scope = 'Complete engineering tests; only seed779/dataset999 measurement fixtures.',
    reserved_panels_generated = 0L, reserved_draws_generated = 0L,
    session_info = capture.output(sessionInfo()))
  saveRDS(evidence, args[1L])
} else if (length(args)) stop('Supply at most one evidence RDS output path.')
