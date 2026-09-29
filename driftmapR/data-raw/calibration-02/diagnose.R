#!/usr/bin/env Rscript
# Retrospective prefix diagnostics: ONLY old study01 regular_null panels.
study02_diagnose <- function(args=commandArgs(trailingOnly=TRUE)) {
  if(length(args)<2L)stop('Usage: Rscript diagnose.R study01_output diagnostic_output [workers=4]')
  script<-sub('^--file=','',commandArgs(FALSE)[grepl('^--file=',commandArgs(FALSE))][1L])
  source_dir<-dirname(normalizePath(script))
  source(file.path(source_dir,'run.R'),local=.GlobalEnv);study02_load(source_dir)
  old_dir<-normalizePath(args[1L]);out<-normalizePath(args[2L],mustWork=FALSE)
  dir.create(file.path(out,'checkpoints'),recursive=TRUE,showWarnings=FALSE)
  old_jobs<-Filter(function(x)x$scenario=='regular_null',readRDS(file.path(old_dir,'seed-plan.rds')))
  jobs<-unlist(lapply(c(10L,20L,40L),function(m)lapply(old_jobs,function(old) {
    list(m=m,dataset_id=old$dataset_id,data_stream=old$data_stream,
      bootstrap_seed=if(m==40L)old$bootstrap_seed else as.integer(2300000L+m*1000L+old$dataset_id),
      stage='retrospective_study01_prefix')
  })),recursive=FALSE)
  saveRDS(jobs,file.path(out,'seed-plan.rds'))
  work<-function(job) {
    path<-file.path(out,'checkpoints',sprintf('m%04d-%03d.rds',job$m,job$dataset_id))
    if(file.exists(path))return(path)
    oldjob<-job;oldjob$m<-40L;g<-study02_generate(oldjob)
    g$model<-study02_model(job$m);g$features<-g$features[seq_len(job$m)]
    g$unit_map<-g$unit_map[g$features];g$data<-g$data[c('entity','time',g$features)]
    g$X<-lapply(g$X,function(x)x[,seq_len(job$m),drop=FALSE])
    result<-study02_one(job,g,B=199L,budgets=199L)
    if(job$m==40L) {
      old<-readRDS(file.path(old_dir,'checkpoints','pca',sprintf('regular_null-%03d.rds',job$dataset_id)))
      oldregion<-old$regions[old$regions$policy=='production',]
      newregion<-result$regions[result$regions$anchor=='original'&result$regions$estimator=='refit_plugin',]
      key<-function(x)paste(x$entity,x$method)
      oldregion<-oldregion[match(key(newregion),key(oldregion)),]
      stopifnot(identical(oldregion$covered,newregion$covered),
        max(abs(oldregion$normalized_area-newregion$area))<1e-9,
        identical(unname(old$unit_counts),unname(result$weights)))
      result$retrospective_agreement<-TRUE
    }
    saveRDS(result,path,compress='gzip');path
  }
  paths<-parallel::mclapply(jobs,work,mc.cores=if(length(args)>2L)as.integer(args[3L])else 4L,
    mc.set.seed=FALSE,mc.preschedule=FALSE)
  if(any(vapply(paths,inherits,logical(1),'try-error')))stop('Diagnostic worker failure')
  study02_collect(paths,out)
  writeLines('Retrospective correlated prefixes of the same 80 study01 panels. Not independent confirmation.',file.path(out,'RETROSPECTIVE.txt'))
}
if(sys.nframe()==0L)study02_diagnose()
