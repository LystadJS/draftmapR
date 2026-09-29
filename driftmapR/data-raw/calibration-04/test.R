#!/usr/bin/env Rscript
script<-sub('^--file=','',commandArgs(FALSE)[grepl('^--file=',commandArgs(FALSE))][1L])
source_dir<-dirname(normalizePath(script))
source(file.path(source_dir,'run.R'));study04_load(source_dir)
results<-testthat::test_dir(file.path(source_dir,'tests'),reporter='summary',stop_on_failure=TRUE)
counts<-as.data.frame(results)
cat('\nStudy04 test blocks:',nrow(counts),'\n')
print(colSums(counts[intersect(c('nb','failed','skipped','error','warning','passed'),names(counts))]))
