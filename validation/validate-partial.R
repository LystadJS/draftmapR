root <- '/workspace/scratch/837e4400dd1d'
ops <- file.path(root, 'study07-r1-operations')
source(file.path(root, 'study07-recovery/R/load.R'))
s07r1_load(file.path(root, 'study07-recovery'))
source(file.path(ops, 'resumable-collect-prefix-005.R'))
state <- file.path(ops, 'resumable-collection-state')
b <- readRDS(file.path(state, 'binding.rds'))
identity <- s07r1_identity(FALSE)
jobs <- s07i_jobs()
stopifnot(identical(b$identity, identity), identical(b$jobs, jobs))
cat('Frozen identity and job grid verified; validating original input catalog\n'); flush.console()
s07r1_catalog_check(file.path(root, 'study07-results/S07-D1'))
before <- s07ops_records(file.path(state, 'panel-journal.jsonl'))
stopifnot(length(before) == 3915L)
cat('Original catalog verified; checking raw prefix and partial panel\n'); flush.console()
result <- tryCatch({
  s07ops_collect(b$paths, jobs, identity, b$out, state,
    chunk_dir=b$chunk_dir, published_catalogs=b$published_catalogs,
    stop_after_panel=3916L)
  stop('Expected bounded interruption was not reached')
}, error=function(e) {
  if (!identical(conditionMessage(e), 'ENGINEERING_INTERRUPT_AFTER_PANEL')) stop(e)
  'passed'
}, finally=s07ops_worker(close=TRUE))
after <- s07ops_records(file.path(state, 'panel-journal.jsonl'))
stopifnot(length(after)==3916L, identical(after[seq_along(before)], before),
          tail(after,1)[[1]]$key=='s07_normal_mean_m160-1436')
s07i_json(list(status=result, committed_panels=length(after),
  partial_panel=tail(after,1)[[1]], no_fits_generated=TRUE,
  scientific_completion_claimed=FALSE), file.path(ops,'partial-validation-20261021.json'))
cat('Partial checkpoint validated and panel 3916 committed\n')
