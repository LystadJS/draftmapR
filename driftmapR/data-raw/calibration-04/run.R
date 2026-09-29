#!/usr/bin/env Rscript
study04_load <- function(source_dir) {
  source(file.path(source_dir,'../calibration-03/run.R'),local=.GlobalEnv)
  study03_load(file.path(source_dir,'../calibration-03'))
  for(name in c('../calibration-03/analyze.R','../calibration-03/validate.R',
    'model.R','frame.R','audit.R','validate.R','analyze.R')) {
    if(file.exists(file.path(source_dir,name)))source(file.path(source_dir,name),local=.GlobalEnv)
  }
}
study04_collect <- function(paths,output_dir) {
  for(chart in c('core','frame')) {
    destination<-file.path(output_dir,chart);dir.create(destination,showWarnings=FALSE)
    write.csv(study04_cases(),file.path(destination,'caseplan.csv'),row.names=FALSE)
    for(name in c('outer','estimates','regions','attempts','studentization')) {
      table<-study03_bind(lapply(paths,function(path) {
        result<-readRDS(path);if(chart=='frame')result<-result$frame
        result[[name]]
      }))
      if(is.null(table))stop('Missing planned table: ',chart,'/',name)
      if('entity' %in% names(table)) {
        table$study04_target_role<-ifelse(
          (table$case_id=='regular_null_m40'&table$entity=='E006') |
          (table$case_id=='regular_null_m160'&table$entity=='E003'),
          'primary_replication','descriptive_control')
      }
      write.csv(table,file.path(destination,paste0(name,'.csv')),row.names=FALSE)
    }
  }
  audit<-study03_bind(lapply(paths,function(path)readRDS(path)$audit))
  if(!is.null(audit))write.csv(audit,file.path(output_dir,'audit.csv'),row.names=FALSE)
}
study04_main <- function(args=commandArgs(trailingOnly=TRUE)) {
  if(!length(args))stop('Usage: Rscript run.R /absolute/output [workers=frozen_default]')
  script<-sub('^--file=','',commandArgs(FALSE)[grepl('^--file=',commandArgs(FALSE))][1L])
  source_dir<-dirname(normalizePath(script));study04_load(source_dir);s<-study04_settings()
  stopifnot(as.character(utils::packageVersion('driftmapR'))==s$engine_version)
  freeze<-readRDS(file.path(source_dir,'freeze.rds'))
  if(!identical(unname(tools::md5sum(file.path(source_dir,freeze$files))),freeze$md5))stop('Frozen source changed.')
  output_dir<-normalizePath(args[1L],mustWork=FALSE)
  dir.create(file.path(output_dir,'checkpoints'),recursive=TRUE,showWarnings=FALSE)
  cases<-study04_cases();jobs<-study04_jobs(cases)
  if(file.exists(file.path(output_dir,'seed-plan.rds'))&&!identical(readRDS(file.path(output_dir,'seed-plan.rds')),jobs))stop('Seed plan mismatch.')
  saveRDS(jobs,file.path(output_dir,'seed-plan.rds'));saveRDS(freeze,file.path(output_dir,'frozen-design.rds'))
  write.csv(cases,file.path(output_dir,'caseplan.csv'),row.names=FALSE)
  write.csv(do.call(rbind,lapply(jobs,function(j)data.frame(case_id=j$case_id,dataset_id=j$dataset_id,
    m=j$m,bootstrap_seed=j$bootstrap_seed,data_stream=paste(j$data_stream,collapse=';')))),file.path(output_dir,'seed-plan.csv'),row.names=FALSE)
  saveRDS(lapply(seq_len(nrow(cases)),function(k)study03_model(cases[k,,drop=FALSE])),file.path(output_dir,'population-targets.rds'))
  for(relative in freeze$files) {
    target<-file.path(output_dir,'source','calibration-04',relative)
    dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    if(!file.copy(file.path(source_dir,relative),target,overwrite=TRUE))stop('Frozen source copy failed.')
  }
  write.csv(data.frame(file=freeze$files,md5=freeze$md5),file.path(output_dir,'source-hashes-before-run.csv'),row.names=FALSE)
  writeLines(capture.output(sessionInfo()),file.path(output_dir,'session-info.txt'))
  started<-Sys.time();workers<-if(length(args)>1L)as.integer(args[2L])else s$workers
  if(!is.finite(workers)||workers<1L||workers>8L)stop('Use 1 to 8 outer workers.')
  writeLines(c(paste('start_utc',format(started,'%Y-%m-%dT%H:%M:%OS6Z',tz='UTC')),
    paste('workers',workers),paste('outer_panels',length(jobs))),file.path(output_dir,'execution-start.txt'))
  work<-function(job) {
    path<-file.path(output_dir,'checkpoints',sprintf('%s-%03d.rds',job$case_id,job$dataset_id))
    if(file.exists(path)) {
      old<-readRDS(path)
      if(!identical(old$job,job)||!identical(old$freeze,freeze))stop('Checkpoint signature mismatch.')
      return(path)
    }
    case<-cases[match(job$case_id,cases$case_id),,drop=FALSE];g<-study03_generate(job,case)
    result<-study04_one(job,case,generated=g)
    if(job$dataset_id %in% s$audit_datasets)result$audit<-study04_public_audit(result,g)
    result$freeze<-freeze;saveRDS(result,paste0(path,'.tmp'),compress='gzip')
    if(!file.rename(paste0(path,'.tmp'),path))stop('Cannot finalize checkpoint.')
    path
  }
  paths<-parallel::mclapply(jobs,work,mc.cores=workers,mc.set.seed=FALSE,mc.preschedule=FALSE)
  if(any(vapply(paths,inherits,logical(1),'try-error')))stop('Worker error; inspect and resume exact checkpoints without replacement.')
  study04_collect(paths,output_dir)
  writeLines(c(paste('start_utc',format(started,'%Y-%m-%dT%H:%M:%OS6Z',tz='UTC')),
    paste('end_utc',format(Sys.time(),'%Y-%m-%dT%H:%M:%OS6Z',tz='UTC')),
    paste('elapsed_seconds',as.numeric(difftime(Sys.time(),started,units='secs'))),
    paste('workers',workers),paste('outer_panels',length(jobs))),file.path(output_dir,'execution.txt'))
}
if(sys.nframe()==0L)study04_main()
