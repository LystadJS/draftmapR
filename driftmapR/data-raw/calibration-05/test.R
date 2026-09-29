#!/usr/bin/env Rscript
# Engineering only: never authorize reserved evaluation draws here.
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
source_dir <- dirname(normalizePath(script))
source(file.path(source_dir, 'load.R'))
study05_load(source_dir)
stopifnot(as.character(utils::packageVersion('driftmapR')) == study05_settings()$engine_version)
results <- testthat::test_dir(file.path(source_dir, 'tests'), reporter = 'summary', stop_on_failure = TRUE)
counts <- as.data.frame(results)
cat('\nStudy05 test blocks:', nrow(counts), '\n')
print(colSums(counts[intersect(c('nb', 'failed', 'skipped', 'error', 'warning', 'passed'), names(counts))]))
totals <- colSums(counts[intersect(c('nb', 'failed', 'skipped', 'error', 'warning', 'passed'), names(counts))])
stopifnot(all(totals[c('failed', 'skipped', 'error', 'warning')] == 0))
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) {
  if (length(args) != 1L) stop('Supply at most one output evidence RDS path.')
  files <- study05_r_files(source_dir)
  saveRDS(list(tested_at_utc = format(Sys.time(), '%Y-%m-%dT%H:%M:%OS6Z', tz = 'UTC'),
    blocks = nrow(counts), totals = totals, files = files,
    md5 = unname(tools::md5sum(file.path(source_dir, files))),
    scope = 'Engineering fixtures and analytic plans only; no reserved evaluation measurements.'), args[1L])
}
