#!/usr/bin/env Rscript
study03_capture <- function(expr) {
  warnings<-character()
  value<-tryCatch(withCallingHandlers(expr,warning=function(w) {
    warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')
  }),error=function(e)e)
  list(ok=!inherits(value,'error'),value=value,
    stage=if(inherits(value,'error'))if(is.null(value$stage))'fit' else value$stage else 'complete',
    message=if(inherits(value,'error'))conditionMessage(value) else '',warnings=paste(warnings,collapse=' | '))
}
study03_bind <- function(rows) {
  rows<-Filter(Negate(is.null),rows);if(!length(rows))return(NULL)
  columns<-unique(unlist(lapply(rows,names)))
  do.call(rbind,lapply(rows,function(x){for(n in setdiff(columns,names(x)))x[[n]]<-NA;x[columns]}))
}
study03_empty_jackknife <- function(counts,target_rows,stage,message) {
  m<-sum(counts);na<-matrix(NA_real_,2L,2L)
  list(covariance=rep(list(na),length(target_rows)),covariance_ok=rep(FALSE,length(target_rows)),
    reason=rep(stage,length(target_rows)),values=NULL,weighted_mean=matrix(NA_real_,length(target_rows),2L),
    weighted_scatter=rep(list(na),length(target_rows)),
    ledger=data.frame(unit_index=seq_along(counts),multiplicity=counts,attempted=FALSE,success=FALSE,
      stage=ifelse(counts>0,stage,'not_selected'),
      message=ifelse(counts>0,message,'Unit has zero multiplicity; deletion is not required.'),warnings=''),
    counts=counts,positive_units=which(counts>0),n_planned_unique=sum(counts>0),
    n_attempted_unique=0L,n_successful_unique=0L,n_required_occurrences=m,
    n_successful_occurrences=0L,all_required_success=FALSE,target_rows=target_rows)
}
study03_one <- function(job,case,B=case$B,generated=study03_generate(job,case),
                        keep_inner_values=job$dataset_id<=2L,
                        fit_fun=study03_fit,jackknife_fun=study03_jackknife) {
  started<-proc.time()[3L];g<-generated;model<-g$model;m<-job$m
  targets<-model$target_rows;ids<-model$target_ids;k<-length(ids)
  design<-driftmapR::paired_unit_design(g$unit_map,
    assumptions='The simulation generates iid paired measurement units across entities and periods; all columns are sampled together across time.')
  plan<-getFromNamespace('bootstrap_draw_plan','driftmapR')(design,g$features,as.integer(B),job$bootstrap_seed)
  weights<-do.call(rbind,lapply(plan$draws,function(d)d$feature_weights[g$features]))
  streams<-do.call(rbind,lapply(plan$draws,`[[`,'rng_stream'))
  C<-lapply(g$X,function(x)tcrossprod(x)/m)
  observed<-study03_capture({
    reference<-study03_stage(study02_points(C[[1L]]),'embedding_period1')
    fit<-fit_fun(C[[1L]],C[[2L]],reference,model$anchors)
    list(reference=reference,fit=fit)
  })
  evaluation<-if(observed$ok)study03_capture(study03_stage(study02_register(
    observed$value$reference,model$population_points[[1L]],model$anchors),'evaluation_registration')) else observed
  observed_ok<-observed$ok&&evaluation$ok
  reference<-if(observed$ok)observed$value$reference else NULL
  Q<-if(evaluation$ok)evaluation$value$rotation else matrix(NA_real_,2L,2L)
  point<-if(observed_ok)observed$value$fit$displacement[targets,,drop=FALSE] else matrix(NA_real_,k,2L)
  estimate<-if(observed_ok)point%*%Q else point
  obs_jk<-if(observed_ok)jackknife_fun(g$X,rep(1L,m),reference,model$anchors,targets,grams=C,fit_fun=fit_fun) else
    study03_empty_jackknife(rep(1L,m),targets,'observed_unavailable',evaluation$message)
  values<-array(NA_real_,c(B,k,2L));eval_values<-values
  inner<-vector('list',B);attempt_rows<-student_rows<-vector('list',B)
  pivots<-matrix(NA_real_,B,k)
  for(b in seq_len(B)) {
    counts<-as.integer(weights[b,]);rare_multiplicity<-if(case$scenario=='rare_axis')sum(counts[g$rare]) else NA_integer_
    if(observed_ok) {
      grams<-lapply(g$X,function(x)tcrossprod(sweep(x,2L,sqrt(counts),'*'))/m)
      fitted<-study03_capture(fit_fun(grams[[1L]],grams[[2L]],reference,model$anchors))
    } else fitted<-list(ok=FALSE,stage='observed_unavailable',message=evaluation$message,warnings='')
    attempt_rows[[b]]<-data.frame(case_id=case$case_id,scenario=case$scenario,m=m,
      dataset_id=job$dataset_id,replicate_id=b,attempted=observed_ok,success=fitted$ok,
      stage=fitted$stage,message=fitted$message,warnings=fitted$warnings,
      distinct_units=sum(counts>0),rare_multiplicity=rare_multiplicity)
    if(fitted$ok) {
      values[b,,]<-fitted$value$displacement[targets,,drop=FALSE]
      eval_values[b,,]<-matrix(values[b,,],ncol=2L)%*%Q
      jk<-jackknife_fun(g$X,counts,reference,model$anchors,targets,grams=grams,fit_fun=fit_fun)
    } else jk<-study03_empty_jackknife(counts,targets,
       if(observed_ok)'full_fit_unavailable' else 'observed_unavailable',fitted$message)
    rows<-vector('list',k)
    for(j in seq_len(k)) {
      cov_ok<-fitted$ok&&jk$covariance_ok[j]
      pivot_result<-if(cov_ok)study03_capture(study03_quadratic(as.numeric(values[b,j,]-point[j,]),jk$covariance[[j]])) else NULL
      if(!is.null(pivot_result)&&pivot_result$ok&&!is.finite(pivot_result$value))
        pivot_result$message<-'Studentized quadratic is nonfinite.'
      pivot_ok<-cov_ok&&!is.null(pivot_result)&&pivot_result$ok&&is.finite(pivot_result$value)
      if(pivot_ok)pivots[b,j]<-pivot_result$value
      stage<-if(!fitted$ok)if(observed_ok)'full_fit_unavailable' else 'observed_unavailable' else
        if(!jk$all_required_success)'inner_leaveout_fit' else if(!cov_ok)'inner_covariance' else
          if(!pivot_ok)'pivot' else 'complete'
      message<-if(!fitted$ok)fitted$message else if(!jk$all_required_success)
        'At least one required leave-one-occurrence fit failed; covariance is unavailable.' else
          if(!cov_ok)jk$reason[j] else if(!pivot_ok)pivot_result$message else ''
      S<-if(cov_ok)t(Q)%*%jk$covariance[[j]]%*%Q else matrix(NA_real_,2L,2L)
      rows[[j]]<-data.frame(case_id=case$case_id,scenario=case$scenario,m=m,dataset_id=job$dataset_id,
        replicate_id=b,entity=ids[j],attempted=fitted$ok,covariance_ok=cov_ok,pivot_ok=pivot_ok,
        pivot=pivots[b,j],inner_required_unique=jk$n_planned_unique,
        inner_attempted_unique=jk$n_attempted_unique,inner_successful_unique=jk$n_successful_unique,
        inner_required_occurrences=jk$n_required_occurrences,inner_successful_occurrences=jk$n_successful_occurrences,
        stage=stage,message=message,dx=eval_values[b,j,1L],dy=eval_values[b,j,2L],
        distinct_units=sum(counts>0),rare_multiplicity=rare_multiplicity,
        var_dx=S[1L,1L],var_dy=S[2L,2L],cov_dx_dy=S[1L,2L])
    }
    student_rows[[b]]<-do.call(rbind,rows)
    if(!keep_inner_values)jk$values<-NULL
    inner[[b]]<-jk
  }
  result<-list(job=job,case=case,B=B,weights=weights,streams=streams,
    observed_success=observed_ok,full_observed_success=observed$ok,evaluation_success=evaluation$ok,
    observed=if(observed$ok)observed$value else NULL,Q=Q,point=point,estimate=estimate,
    truth=model$truth,observed_jackknife=obs_jk,values=values,eval_values=eval_values,
    inner=inner,pivots=pivots,attempts=do.call(rbind,attempt_rows),
    studentization=do.call(rbind,student_rows),warnings=list(observed=observed$warnings,evaluation=evaluation$warnings),
    model_metadata=list(anchors=model$ids[model$anchors],target_ids=ids,rare=g$rare,
      rare_count=g$rare_count,movement_scale=case$movement_scale))
  tables<-study03_tables(result);result[names(tables)]<-tables
  result$outer<-data.frame(case_id=case$case_id,scenario=case$scenario,m=m,dataset_id=job$dataset_id,
    B=B,observed_success=observed_ok,full_observed_success=observed$ok,evaluation_success=evaluation$ok,
    observed_stage=if(observed_ok)'complete' else evaluation$stage,
    observed_message=if(observed_ok)'' else evaluation$message,rare_count=g$rare_count,
    n_full_attempted=sum(result$attempts$attempted),n_full_success=sum(result$attempts$success),
    observed_jackknife_required=obs_jk$n_planned_unique,observed_jackknife_attempted=obs_jk$n_attempted_unique,
    observed_jackknife_success=obs_jk$n_successful_unique,
    inner_jackknife_required=sum(vapply(inner,`[[`,numeric(1),'n_planned_unique')),
    inner_jackknife_attempted=sum(vapply(inner,`[[`,numeric(1),'n_attempted_unique')),
    inner_jackknife_success=sum(vapply(inner,`[[`,numeric(1),'n_successful_unique')),
    elapsed_seconds=unname(proc.time()[3L]-started))
  result
}
study03_tables <- function(result) {
  job<-result$job;case<-result$case;B<-result$B;ids<-study03_settings()$targets
  observed_ok<-result$observed_success;full_ok<-result$attempts$success
  regions<-estimates<-list()
  for(j in seq_along(ids)) {
    S<-if(observed_ok)t(result$Q)%*%result$observed_jackknife$covariance[[j]]%*%result$Q else matrix(NA_real_,2L,2L)
    point<-if(observed_ok)as.numeric(result$estimate[j,])else c(0,0)
    draws<-matrix(result$eval_values[full_ok,j,],ncol=2L)
    base<-calibration_regions(point,draws,as.numeric(result$truth[j,]))
    base$gate<-observed_ok&&sum(full_ok)>=20L&&mean(full_ok)>=.95
    base$relaxed_covered<-base$covered;base$relaxed_rejects_zero<-base$rejects_zero
    base$delivered<-base$available&base$gate
    base$covered[!base$delivered]<-NA;base$rejects_zero[!base$delivered]<-NA
    base$cutoff<-ifelse(base$method=='bootstrap_ball',base$radius,base$radius^2)
    student<-study03_studentized_region(point,S,result$pivots[is.finite(result$pivots[,j]),j],
      as.numeric(result$truth[j,]),B=as.integer(B))
    candidate<-study03_bind(list(base,student))
    if(!observed_ok) {
      candidate$available<-candidate$gate<-candidate$delivered<-FALSE
      candidate$covered<-candidate$rejects_zero<-candidate$relaxed_covered<-candidate$relaxed_rejects_zero<-NA
      candidate$reason<-'observed_unavailable';candidate$center_dx<-candidate$center_dy<-NA_real_
    }
    regions[[j]]<-cbind(data.frame(case_id=case$case_id,scenario=case$scenario,m=job$m,dataset_id=job$dataset_id,
      entity=ids[j],target_role=if(j==1L)'primary'else'secondary',truth_dx=result$truth[j,1L],truth_dy=result$truth[j,2L]),candidate)
    estimates[[j]]<-data.frame(case_id=case$case_id,scenario=case$scenario,m=job$m,dataset_id=job$dataset_id,
      entity=ids[j],observed_success=observed_ok,dx=result$estimate[j,1L],dy=result$estimate[j,2L],
      truth_dx=result$truth[j,1L],truth_dy=result$truth[j,2L],
      observed_jackknife_ok=observed_ok&&result$observed_jackknife$covariance_ok[j],
      var_dx=S[1L,1L],var_dy=S[2L,2L],cov_dx_dy=S[1L,2L])
  }
  list(regions=do.call(rbind,regions),estimates=do.call(rbind,estimates))
}
study03_load <- function(source_dir) {
  for(relative in c('../calibration-01/model.R','../calibration-01/regions.R',
                     '../calibration-02/kernel.R','jackknife.R','regions.R','model.R','audit.R')) {
    if(file.exists(file.path(source_dir,relative)))source(file.path(source_dir,relative),local=.GlobalEnv)
  }
}
study03_collect <- function(paths,output_dir) {
  for(name in c('outer','estimates','regions','attempts','studentization','audit')) {
    table<-study03_bind(lapply(paths,function(path)readRDS(path)[[name]]))
    if(!is.null(table))write.csv(table,file.path(output_dir,paste0(name,'.csv')),row.names=FALSE)
  }
}
study03_main <- function(args=commandArgs(trailingOnly=TRUE)) {
  if(!length(args))stop('Usage: Rscript run.R /absolute/output [workers=frozen_default]')
  script<-sub('^--file=','',commandArgs(FALSE)[grepl('^--file=',commandArgs(FALSE))][1L])
  source_dir<-dirname(normalizePath(script));study03_load(source_dir);settings<-study03_settings()
  stopifnot(as.character(utils::packageVersion('driftmapR'))==settings$engine_version)
  freeze<-readRDS(file.path(source_dir,'freeze.rds'))
  if(!identical(unname(tools::md5sum(file.path(source_dir,freeze$files))),freeze$md5))stop('Frozen source changed.')
  output_dir<-normalizePath(args[1L],mustWork=FALSE)
  dir.create(file.path(output_dir,'checkpoints'),recursive=TRUE,showWarnings=FALSE)
  cases<-study03_cases();jobs<-study03_jobs(cases)
  if(file.exists(file.path(output_dir,'seed-plan.rds'))&&!identical(readRDS(file.path(output_dir,'seed-plan.rds')),jobs))stop('Seed plan mismatch.')
  saveRDS(jobs,file.path(output_dir,'seed-plan.rds'));saveRDS(freeze,file.path(output_dir,'frozen-design.rds'))
  write.csv(cases,file.path(output_dir,'caseplan.csv'),row.names=FALSE)
  write.csv(do.call(rbind,lapply(jobs,function(j)data.frame(case_id=j$case_id,dataset_id=j$dataset_id,
    m=j$m,bootstrap_seed=j$bootstrap_seed,data_stream=paste(j$data_stream,collapse=';')))),file.path(output_dir,'seed-plan.csv'),row.names=FALSE)
  saveRDS(lapply(seq_len(nrow(cases)),function(k)study03_model(cases[k,,drop=FALSE])),file.path(output_dir,'population-targets.rds'))
  for(relative in freeze$files) {
    target<-file.path(output_dir,'source','calibration-03',relative)
    dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    if(!file.copy(file.path(source_dir,relative),target,overwrite=TRUE))stop('Frozen source copy failed.')
  }
  write.csv(data.frame(file=freeze$files,md5=freeze$md5),file.path(output_dir,'source-hashes-before-run.csv'),row.names=FALSE)
  writeLines(capture.output(sessionInfo()),file.path(output_dir,'session-info.txt'))
  started<-Sys.time();workers<-if(length(args)>1L)as.integer(args[2L])else settings$workers
  work<-function(job) {
    path<-file.path(output_dir,'checkpoints',sprintf('%s-%03d.rds',job$case_id,job$dataset_id))
    if(file.exists(path)) {
      old<-readRDS(path)
      if(!identical(old$job,job)||!identical(old$freeze,freeze))stop('Checkpoint signature mismatch.')
      return(path)
    }
    case<-cases[match(job$case_id,cases$case_id),,drop=FALSE];g<-study03_generate(job,case)
    result<-study03_one(job,case,generated=g)
    if(job$dataset_id<=2L)result$audit<-study03_public_audit(result,g)
    result$freeze<-freeze;saveRDS(result,paste0(path,'.tmp'),compress='gzip')
    if(!file.rename(paste0(path,'.tmp'),path))stop('Cannot finalize checkpoint.')
    path
  }
  paths<-parallel::mclapply(jobs,work,mc.cores=workers,mc.set.seed=FALSE,mc.preschedule=FALSE)
  if(any(vapply(paths,inherits,logical(1),'try-error')))stop('Worker error; inspect and resume exact checkpoints without replacement.')
  study03_collect(paths,output_dir)
  writeLines(c(paste('start',started),paste('end',Sys.time()),paste('workers',workers),paste('outer_panels',length(jobs))),file.path(output_dir,'execution.txt'))
}
if(sys.nframe()==0L)study03_main()
