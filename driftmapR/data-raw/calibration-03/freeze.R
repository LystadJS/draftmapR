#!/usr/bin/env Rscript
# Run once after all reserved-fixture tests pass, before study03_jobs/generation.
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
source_dir <- dirname(normalizePath(script))
if (file.exists(file.path(source_dir, 'freeze.rds'))) stop('Freeze already exists; do not overwrite.')
source(file.path(source_dir, 'run.R')); study03_load(source_dir)
files <- sort(c(list.files(source_dir, recursive=TRUE),
  '../calibration-01/model.R', '../calibration-01/regions.R', '../calibration-02/kernel.R'))
files <- files[!grepl('(^|/)(freeze\\.rds|freeze-manifest\\.csv)$', files)]
freeze <- list(study='driftmapR calibration 03',
  frozen_at_utc=format(Sys.time(), '%Y-%m-%dT%H:%M:%OS6Z', tz='UTC'),
  status='Frozen before independent measurement-panel generation',
  settings=study03_settings(), cases=study03_cases(), files=files,
  md5=unname(tools::md5sum(file.path(source_dir, files))))
stopifnot(!anyNA(freeze$md5))
saveRDS(freeze, file.path(source_dir, 'freeze.rds'))
write.csv(data.frame(file=files, md5=freeze$md5), file.path(source_dir, 'freeze-manifest.csv'), row.names=FALSE)
cat('Frozen', length(files), 'source files at', freeze$frozen_at_utc, '\n')
