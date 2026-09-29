# Study 05 prespecified descriptive analyses. No simulation, tuning, or inference
# gate modification occurs here. Summaries use independent OUTER panels.

study05_analysis_key <- function(x, keys) {
  if (!all(keys %in% names(x))) stop('Missing analysis keys: ', paste(setdiff(keys, names(x)), collapse=', '))
  if (!length(keys)) return(rep('all', nrow(x)))
  do.call(paste, c(lapply(x[keys], function(z) ifelse(is.na(z), '<NA>', as.character(z))), sep='\034'))
}
study05_analysis_groups <- function(x, keys) {
  if (!nrow(x)) return(list())
  split(x, factor(study05_analysis_key(x, keys), levels=unique(study05_analysis_key(x, keys))))
}
study05_analysis_bind <- function(x) {
  x <- Filter(function(z) is.data.frame(z) && nrow(z)>0L, x)
  if (!length(x)) return(data.frame())
  cols <- unique(unlist(lapply(x, names)))
  do.call(rbind, lapply(x, function(z) { for (v in setdiff(cols,names(z))) z[[v]] <- NA; z[cols] }))
}
study05_analysis_match <- function(x, y, keys, complete=TRUE) {
  a <- study05_analysis_key(x, keys); b <- study05_analysis_key(y, keys)
  if (anyDuplicated(a) || anyDuplicated(b) || (complete && !setequal(a,b))) stop('Analysis requires unique matching planned keys.')
  i <- match(a,b); if (anyNA(i)) stop('Analysis has unmatched planned rows.')
  y[i,,drop=FALSE]
}
study05_analysis_mean <- function(x) { x<-x[is.finite(x)]; if(length(x))mean(x) else NA_real_ }
study05_analysis_se <- function(x) { x<-x[is.finite(x)]; if(length(x)>1L)stats::sd(x)/sqrt(length(x)) else NA_real_ }
study05_analysis_stats <- function(x) {
  finite<-x[is.finite(x)]; n<-length(finite)
  q<-if(n)as.numeric(stats::quantile(finite,c(.1,.5,.9,.95),type=7L)) else rep(NA_real_,4L)
  c(n_total=length(x),n_finite=n,n_nonfinite=length(x)-n,
    mean=if(n)mean(finite) else NA_real_,median=q[2L],sd=if(n>1L)stats::sd(finite) else NA_real_,
    q10=q[1L],q90=q[3L],q95=q[4L],maximum=if(n)max(finite) else NA_real_)
}
study05_analysis_prop <- function(k,n) {
  if(length(k)!=1L||length(n)!=1L||!is.finite(k)||!is.finite(n)||k<0||n<k||k!=floor(k)||n!=floor(n))stop('Invalid proportion counts.')
  if(n==0L)return(c(numerator=k,denominator=n,estimate=NA_real_,mcse=NA_real_,wilson_lower=NA_real_,wilson_upper=NA_real_))
  p<-k/n; z<-stats::qnorm(.975); center<-(p+z^2/(2*n))/(1+z^2/n)
  half<-z*sqrt(p*(1-p)/n+z^2/(4*n^2))/(1+z^2/n)
  c(numerator=k,denominator=n,estimate=p,mcse=sqrt(p*(1-p)/n),wilson_lower=max(0,center-half),wilson_upper=min(1,center+half))
}
study05_analysis_methods <- function() c('jackknife_studentized','wald','bootstrap_mahalanobis','bootstrap_ball','jackknife_wald')
study05_analysis_reasons <- function() c('observed_unavailable','observed_deletion_unavailable','observed_covariance_invalid','insufficient_pivots','valid_fraction_below_095','region_geometry_unavailable','delivered')
study05_gap_bin <- function(x) {
  out<-rep('unavailable',length(x)); ok<-is.finite(x)
  out[ok]<-as.character(cut(x[ok],c(-Inf,1e-10,.01,.05,.2,Inf),right=TRUE,
    labels=c('<=1e-10','(1e-10,.01]','(.01,.05]','(.05,.2]','>.2'))); out
}
study05_anchor_bin <- function(x) {
  out<-rep('unavailable',length(x)); ok<-is.finite(x)
  out[ok]<-as.character(cut(x[ok],c(-Inf,1e-10,.01,.1,Inf),right=TRUE,
    labels=c('<=1e-10','(1e-10,.01]','(.01,.1]','>.1'))); out
}

# Extract compact products from one full checkpoint; the collector can discard
# that checkpoint before reading the next. Full scalar fit ledgers remain in the
# checkpoint/collector products, while geometry is summarized WITHIN panel here.
study05_analysis_extract <- function(result) {
  case<-result$case; job<-result$job
  meta<-case[rep(1L,1L),intersect(c('case_id','scenario','g','a','m','M','B','focal_motion','rho_unit','role','target_regime','contract','case_index'),names(case)),drop=FALSE]
  decorate<-function(z,frame) {
    if(!is.data.frame(z))return(data.frame())
    z$frame<-frame
    for(v in setdiff(names(meta),names(z)))z[[v]]<-rep(meta[[v]][1L],nrow(z))
    z
  }
  tables<-lapply(c('outer','estimates','regions'),function(name)study05_analysis_bind(list(decorate(result[[name]],'core'),decorate(result$frame[[name]],'population_frame_oracle'))))
  names(tables)<-c('outer','estimates','regions')
  r<-tables$regions;e<-tables$estimates;o<-tables$outer
  if(is.null(result$truth_clean))stop('Study05 analysis requires the frozen clean target.')
  ids<-rownames(result$truth_clean);if(is.null(ids))ids<-result$model_metadata$target_ids
  ci<-match(e$entity,ids); if(anyNA(ci))stop('Clean target IDs do not match estimates.')
  e$truth_clean_dx<-result$truth_clean[ci,1L];e$truth_clean_dy<-result$truth_clean[ci,2L]
  e$target_distance_declared_clean<-sqrt((e$truth_dx-e$truth_clean_dx)^2+(e$truth_dy-e$truth_clean_dy)^2)
  e$target_norm_declared<-sqrt(e$truth_dx^2+e$truth_dy^2);e$target_norm_clean<-sqrt(e$truth_clean_dx^2+e$truth_clean_dy^2)
  # Propagate operational/candidate availability independently of frame outcomes.
  core_available<-isTRUE(result$full_observed_success)
  eval_available<-isTRUE(result$evaluation_success)&&core_available
  eval_only<-core_available&&!eval_available
  for(v in c('observed_core_fit_available','evaluation_registration_available','evaluation_only_block')) {
    value<-switch(v,observed_core_fit_available=core_available,evaluation_registration_available=eval_available,evaluation_only_block=eval_only)
    if(!v%in%names(o))o[[v]]<-value
    if(!v%in%names(r))r[[v]]<-value
  }
  r$study_evaluable_region_delivered<-r$delivered
  if(!'candidate_region_delivered'%in%names(r))r$candidate_region_delivered<-ifelse(eval_only,NA,r$delivered)
  # The diagnostic frame is not a deployable candidate. Its delivery flag records
  # this diagnostic's computation, with the same evaluation-only unknown state.
  ei<-match(study05_analysis_key(r,c('frame','entity')),study05_analysis_key(e,c('frame','entity')))
  oi<-match(r$frame,o$frame)
  r$truth_clean_dx<-e$truth_clean_dx[ei];r$truth_clean_dy<-e$truth_clean_dy[ei]
  r$target_distance_declared_clean<-e$target_distance_declared_clean[ei]
  r$target_norm_declared<-e$target_norm_declared[ei];r$target_norm_clean<-e$target_norm_clean[ei]
  r$observed_success<-e$observed_success[ei]
  r$clean_target_included<-NA; r$clean_target_statistic<-NA_real_
  for(i in which(r$delivered)) {
    err<-c(r$truth_clean_dx[i]-r$center_dx[i],r$truth_clean_dy[i]-r$center_dy[i])
    if(r$method[i]=='bootstrap_ball')stat<-sqrt(sum(err^2)) else {
      S<-matrix(c(r$var_dx[i],r$cov_dx_dy[i],r$cov_dx_dy[i],r$var_dy[i]),2L)
      stat<-study03_quadratic(err,S)
    }
    if(!is.finite(stat))stop('Delivered region has unavailable clean-target comparison.')
    r$clean_target_statistic[i]<-stat;r$clean_target_included[i]<-stat<=r$cutoff[i]*(1+1e-12)
  }
  r$inclusion_interpretation<-'Declared-anchor region contains clean target; not calibration of a clean-anchor interval'
  r$nondelivery_reason<-NA_character_
  for(i in seq_len(nrow(r))) {
    observed_ok<-isTRUE(r$observed_success[i]); del_ok<-o$observed_jackknife_success[oi[i]]==o$observed_jackknife_required[oi[i]]
    cov_ok<-isTRUE(e$observed_jackknife_ok[ei[i]])
    if(r$method[i]=='jackknife_studentized') {
      reason<-study05_nondelivery(observed_ok,del_ok,cov_ok,as.integer(r$n_valid[i]),as.integer(result$B),isTRUE(r$available[i]))
    } else if(!observed_ok)reason<-'observed_unavailable' else if(r$method[i]=='jackknife_wald') {
      reason<-if(!del_ok)'observed_deletion_unavailable' else if(!cov_ok)'observed_covariance_invalid' else if(!r$available[i])'region_geometry_unavailable' else 'delivered'
    } else {
      reason<-if(r$n_valid[i]<20L)'insufficient_pivots' else if(r$n_valid[i]<.95*result$B)'valid_fraction_below_095' else if(!r$available[i])'region_geometry_unavailable' else 'delivered'
    }
    if((reason=='delivered')!=r$delivered[i])stop('Final non-delivery reason disagrees with delivered flag.')
    r$nondelivery_reason[i]<-reason
  }
  r$observed_unavailable_subreason<-ifelse(r$nondelivery_reason!='observed_unavailable','not_applicable',
    ifelse(r$evaluation_only_block,'evaluation_only_block',ifelse(!r$observed_core_fit_available,'actual_observed_core_fit_failure','diagnostic_frame_observed_registration_failure')))
  r$covariance_eigenvalue_max<-r$covariance_eigenvalue_min<-NA_real_
  for(i in seq_len(nrow(r))) {
    S<-matrix(c(r$var_dx[i],r$cov_dx_dy[i],r$cov_dx_dy[i],r$var_dy[i]),2L)
    if(all(is.finite(S))) {
      ev<-eigen(S,symmetric=TRUE,only.values=TRUE)$values;r$covariance_eigenvalue_max[i]<-ev[1L];r$covariance_eigenvalue_min[i]<-ev[2L]
    }
  }
  geometry<-result$geometry
  if(is.null(geometry)||!is.data.frame(geometry$embedding)||!is.data.frame(geometry$registration))stop('Missing geometry diagnostics.')
  eg<-geometry$embedding;rg<-geometry$registration
  observed_eg<-eg[eg$parent_id==0L&eg$unit_index==0L&eg$role%in%c('core','reference'),,drop=FALSE]
  gap_by_period<-vapply(1:2,function(period) {
    v<-observed_eg$gap_relative1[observed_eg$period==period&is.finite(observed_eg$gap_relative1)]
    if(length(v))min(v) else NA_real_
  },numeric(1L))
  core_stages<-c('baseline','temporal','registration_baseline','alignment_temporal')
  candidate_rg<-rg[rg$parent_id>=0L&rg$role=='core'&rg$attempted&rg$stage%in%core_stages,,drop=FALSE]
  observed_rg<-candidate_rg[candidate_rg$parent_id==0L&candidate_rg$unit_index==0L,,drop=FALSE]
  minimum_ratio<-function(z) {
    v<-unlist(z[intersect(c('source_ratio','target_ratio','cross_ratio'),names(z))]);v<-v[is.finite(v)]
    if(length(v))min(v) else NA_real_
  }
  panel<-data.frame(case_id=case$case_id,dataset_id=job$dataset_id,
    observed_gap_periods_finite=sum(is.finite(gap_by_period)),
    observed_gap_min=if(all(is.finite(gap_by_period)))min(gap_by_period) else NA_real_,
    anchor_ratio_min=minimum_ratio(candidate_rg),n_attempted_core_anchor_stages=nrow(candidate_rg),
    observed_anchor_ratio_min=minimum_ratio(observed_rg),n_attempted_observed_anchor_stages=nrow(observed_rg),
    rare_count=result$model_metadata$rare_count)
  panel$gap_bin<-study05_gap_bin(panel$observed_gap_min)
  panel$anchor_bin<-study05_anchor_bin(panel$anchor_ratio_min)
  panel$observed_anchor_bin<-study05_anchor_bin(panel$observed_anchor_ratio_min)
  panel$rare_bin<-ifelse(is.na(panel$rare_count),'not_sparse',ifelse(panel$rare_count>=4,'4+',as.character(panel$rare_count)))
  r$gap_bin<-panel$gap_bin;r$anchor_bin<-panel$anchor_bin;r$observed_anchor_bin<-panel$observed_anchor_bin;r$rare_count<-panel$rare_count;r$rare_bin<-panel$rare_bin
  metrics<-list(embedding=c('lambda1','lambda2','lambda3','gap_absolute','gap_relative1','gap_relative2','projector_distance','angle_min','angle_max'),
    registration=c('source_s1','source_s2','source_ratio','target_s1','target_s2','target_ratio','cross_s1','cross_s2','cross_ratio','rss','n_matched','reflection'))
  geom_rows<-list()
  for(kind in names(metrics)) {
    z<-geometry[[kind]];z$parent_kind<-ifelse(z$parent_id<0L,'clean_observed',ifelse(z$unit_index>0L,ifelse(z$parent_id==0L,'observed_deletion','bootstrap_deletion'),ifelse(z$parent_id==0L,'observed','bootstrap_full')))
    keys<-intersect(c('role','stage','period','parent_kind'),names(z))
    for(group in study05_analysis_groups(z,keys))for(metric in metrics[[kind]])if(metric%in%names(group)) {
      geom_rows[[length(geom_rows)+1L]]<-data.frame(case_id=case$case_id,dataset_id=job$dataset_id,kind=kind,group[1L,keys,drop=FALSE],metric=metric,
        n_planned=nrow(group),n_attempted=sum(group$attempted),n_successful=sum(group$success),
        n_failed_after_attempt=sum(group$attempted&!group$success),n_unattempted=sum(!group$attempted),as.list(study05_analysis_stats(as.numeric(group[[metric]]))),row.names=NULL)
    }
  }
  selection<-list();variation<-list()
  for(frame in c('core','population_frame_oracle')) {
    z<-if(frame=='core')result else result$frame
    s<-z$studentization;a<-z$attempts
    s$max_multiplicity<-apply(result$weights,1L,max)[match(s$replicate_id,a$replicate_id)]
    s$full_success<-a$success[match(s$replicate_id,a$replicate_id)]
    s$observed_rare_count<-result$model_metadata$rare_count
    for(id in unique(s$entity)) {
      d<-s[s$entity==id,,drop=FALSE];ee<-e[e$frame==frame&e$entity==id,,drop=FALSE]
      d$error_norm<-sqrt((d$dx-ee$dx)^2+(d$dy-ee$dy)^2)
      for(metric in c('distinct_units','max_multiplicity','rare_multiplicity','observed_rare_count','error_norm'))for(contrast in c('full_minus_planned','pivot_minus_planned','pivot_minus_full')) {
        base<-if(contrast=='pivot_minus_full')d$full_success else rep(TRUE,nrow(d))
        select<-if(contrast=='full_minus_planned')d$full_success else d$pivot_ok
        finite<-is.finite(d[[metric]]);bv<-d[[metric]][base&finite];sv<-d[[metric]][select&finite]
        fv<-d[[metric]][base&!select&finite]
        selection[[length(selection)+1L]]<-data.frame(case_id=case$case_id,dataset_id=job$dataset_id,frame=frame,entity=id,metric=metric,contrast=contrast,
          n_planned=nrow(d),n_baseline=sum(base),n_selected=sum(select),n_baseline_finite=length(bv),n_selected_finite=length(sv),n_failed_finite=length(fv),
          baseline_mean=study05_analysis_mean(bv),selected_mean=study05_analysis_mean(sv),failed_mean=study05_analysis_mean(fv),
          difference=study05_analysis_mean(sv)-study05_analysis_mean(bv),selected_minus_failed=study05_analysis_mean(sv)-study05_analysis_mean(fv))
      }
    }
    if(frame!='core')for(metric in intersect(c('rotation_distance_from_observed','rotation_determinant'),names(a)))variation[[length(variation)+1L]]<-
      data.frame(case_id=case$case_id,dataset_id=job$dataset_id,metric=metric,n_planned=nrow(a),n_attempted=sum(a$attempted),n_successful=sum(a$success),
        as.list(study05_analysis_stats(a[[metric]])),row.names=NULL)
  }
  clean<-result$clean
  cleanrows<-data.frame(case_id=case$case_id,dataset_id=job$dataset_id,entity=ids,attempted=clean$attempted,success=clean$success,
    stage=clean$stage,message=clean$message,warnings=clean$warnings,dx=clean$estimate[,1L],dy=clean$estimate[,2L],
    truth_dx=result$truth_clean[,1L],truth_dy=result$truth_clean[,2L],frame='clean_observed_point',observed_success=clean$success)
  list(outer=o,estimates=e,regions=r,selection_panel=study05_analysis_bind(selection),geometry_panel=study05_analysis_bind(geom_rows),
    observed_geometry=panel,frame_variation_panel=study05_analysis_bind(variation),clean_points=cleanrows)
}

study05_analysis_validate <- function(tables, allow_fixture=FALSE) {
  required<-c('caseplan','outer','estimates','regions','selection_panel','geometry_panel','observed_geometry','frame_variation_panel','clean_points')
  if(!all(required%in%names(tables)))stop('Analysis compact products are incomplete.')
  keys<-list(outer=c('case_id','dataset_id','frame'),estimates=c('case_id','dataset_id','frame','entity'),
    regions=c('case_id','dataset_id','frame','entity','method'),observed_geometry=c('case_id','dataset_id'),
    clean_points=c('case_id','dataset_id','entity'),selection_panel=c('case_id','dataset_id','frame','entity','metric','contrast'),
    geometry_panel=c('case_id','dataset_id','kind','role','stage','period','parent_kind','metric'),frame_variation_panel=c('case_id','dataset_id','metric'))
  for(name in names(keys)) {
    k<-intersect(keys[[name]],names(tables[[name]]))
    if(anyDuplicated(study05_analysis_key(tables[[name]],k)))stop('Duplicate analysis rows in ',name)
  }
  cp<-tables$caseplan
  if(!allow_fixture&&!identical(cp,study05_cases()))
    stop('Analysis requires the exact frozen case plan: all 31 cells in frozen order with unchanged fields and budgets.')
  if(anyDuplicated(cp$case_id))stop('Duplicate case plan.')
  for(name in setdiff(required,'caseplan'))if(any(!tables[[name]]$case_id%in%cp$case_id))stop('Unplanned case in analysis product: ',name)
  npanels<-nrow(tables$outer)/2L
  expected_rows<-c(estimates=6L,regions=30L,observed_geometry=1L,clean_points=3L,selection_panel=90L,frame_variation_panel=2L)*npanels
  for(name in names(expected_rows))if(nrow(tables[[name]])!=expected_rows[[name]])stop('Incomplete compact product: ',name)
  expected<-sum(cp$M)
  if(!allow_fixture&&nrow(tables$outer)!=2L*expected)stop('Analysis refuses an incomplete frozen outer sample.')
  for(case_id in cp$case_id) {
    o<-tables$outer[tables$outer$case_id==case_id,,drop=FALSE]
    if(!nrow(o))stop('Missing planned case in analysis.')
    ids<-unique(o$dataset_id)
    if(!allow_fixture&&!setequal(ids,seq_len(cp$M[match(case_id,cp$case_id)])))stop('Missing reserved panel IDs in analysis.')
    for(d in ids) {
      oo<-o[o$dataset_id==d,,drop=FALSE]
      ee<-tables$estimates[tables$estimates$case_id==case_id&tables$estimates$dataset_id==d,,drop=FALSE]
      rr<-tables$regions[tables$regions$case_id==case_id&tables$regions$dataset_id==d,,drop=FALSE]
      if(nrow(oo)!=2L||nrow(ee)!=6L||nrow(rr)!=30L||!setequal(oo$frame,c('core','population_frame_oracle')))stop('Incomplete panel/frame/target/method grid.')
      for(f in oo$frame) {
        if(!setequal(ee$entity[ee$frame==f],c('E015','E003','E006')))stop('Incomplete target grid.')
        for(id in c('E015','E003','E006'))if(!setequal(rr$method[rr$frame==f&rr$entity==id],study05_analysis_methods()))stop('Incomplete method grid.')
      }
    }
  }
  r<-tables$regions
  if(anyNA(r$delivered)||any(r$delivered!=(r$available&r$gate))||anyNA(r$covered[r$delivered])||any(!is.na(r$covered[!r$delivered]))||
    anyNA(r$clean_target_included[r$delivered])||any(!is.na(r$clean_target_included[!r$delivered])))stop('Region availability or target-inclusion status is inconsistent.')
  if(any(!r$nondelivery_reason%in%study05_analysis_reasons())||any((r$nondelivery_reason=='delivered')!=r$delivered))stop('Invalid exclusive non-delivery reason.')
  if(any(r$evaluation_only_block&(!is.na(r$candidate_region_delivered)|r$study_evaluable_region_delivered)))stop('Evaluation-only blocks must retain unknown candidate delivery.')
  invisible(TRUE)
}

study05_coverage_analysis <- function(regions, strata=FALSE) {
  regions<-regions[order(match(regions$case_id,unique(regions$case_id)),
    match(regions$frame,c('core','population_frame_oracle')),
    match(regions$entity,c('E015','E003','E006')),
    match(regions$method,study05_analysis_methods()),regions$dataset_id),,drop=FALSE]
  keys<-c('case_id','frame','entity','method');rows<-list();nondelivery<-list();geometry<-list()
  for(x in study05_analysis_groups(regions,keys)) {
    definitions<-list(all='all')
    if(strata)definitions<-list(gap=c('unavailable','<=1e-10','(1e-10,.01]','(.01,.05]','(.05,.2]','>.2'),
      anchor=c('unavailable','<=1e-10','(1e-10,.01]','(.01,.1]','>.1'),
      observed_anchor=c('unavailable','<=1e-10','(1e-10,.01]','(.01,.1]','>.1'))
    if(strata&&x$scenario[1L]=='rare_axis')definitions$rare<-c('0','1','2','3','4+')
    for(kind in names(definitions))for(bin in definitions[[kind]]) {
      z<-if(kind=='all')x else x[x[[paste0(kind,'_bin')]]==bin,,drop=FALSE]
      n<-nrow(z);nd<-sum(z$delivered);nc<-sum(z$covered[z$delivered]);nz<-sum(z$rejects_zero[z$delivered]);nclean<-sum(z$clean_target_included[z$delivered])
      base<-data.frame(x[1L,intersect(c(keys,'scenario','g','a','m','rho_unit','focal_motion','role','target_regime','contract'),names(x)),drop=FALSE],
        stratum=kind,stratum_bin=bin,n_planned_unstratified=nrow(x),n_planned=n,n_observed_available=sum(z$observed_success),
        n_observed_core_fit_available=sum(z$observed_core_fit_available),n_evaluation_registration_available=sum(z$evaluation_registration_available),
        n_evaluation_only_block=sum(z$evaluation_only_block),n_candidate_delivery_unknown=sum(is.na(z$candidate_region_delivered)),
        n_candidate_delivery_known=sum(!is.na(z$candidate_region_delivered)),n_candidate_delivered=sum(z$candidate_region_delivered,na.rm=TRUE),
        n_candidate_demonstrated_nondelivery=sum(!z$candidate_region_delivered,na.rm=TRUE),
        n_delivered=nd,n_covered=nc,n_zero_excluded=nz,n_clean_target_included=nclean,
        target_norm_declared=x$target_norm_declared[1L],target_norm_clean=x$target_norm_clean[1L],
        target_distance_declared_clean=x$target_distance_declared_clean[1L],row.names=NULL)
      outcomes<-list(delivery=c(nd,n),conditional_coverage=c(nc,nd),covered_delivery_yield=c(nc,n),
        conditional_zero_exclusion=c(nz,nd),detected_delivery_yield=c(nz,n),clean_target_inclusion=c(nclean,nd),clean_included_delivery_yield=c(nclean,n))
      for(metric in names(outcomes)) {
        stats<-study05_analysis_prop(outcomes[[metric]][1L],outcomes[[metric]][2L]);names(stats)<-paste0(metric,'_',names(stats))
        for(v in names(stats))base[[v]]<-unname(stats[v])
      }
      base$interpretation<-if(kind=='all')'Descriptive independent outer-panel proportions; coverage conditional on study-evaluable delivery' else
        'Post-data conditional diagnostic cohort; small selected strata do not establish conditional calibration'
      rows[[length(rows)+1L]]<-base
      for(reason in study05_analysis_reasons()) {
        nreason<-sum(z$nondelivery_reason==reason)
        nondelivery[[length(nondelivery)+1L]]<-data.frame(base[keys],stratum=kind,stratum_bin=bin,n_planned=n,reason=reason,n_in_reason=nreason,
          actual_observed_core_fit_failure=sum(z$nondelivery_reason==reason&z$observed_unavailable_subreason=='actual_observed_core_fit_failure'),
          evaluation_only_block=sum(z$nondelivery_reason==reason&z$observed_unavailable_subreason=='evaluation_only_block'),
          diagnostic_frame_observed_registration_failure=sum(z$nondelivery_reason==reason&z$observed_unavailable_subreason=='diagnostic_frame_observed_registration_failure'),
          as.list(study05_analysis_prop(nreason,n)),row.names=NULL)
      }
      if(!strata)for(cohort in c('available','delivered'))for(metric in c('area','cutoff','covariance_eigenvalue_max','covariance_eigenvalue_min')) {
        use<-z[[cohort]]
        geometry[[length(geometry)+1L]]<-data.frame(base[keys],cohort=cohort,metric=metric,n_planned=n,n_in_cohort=sum(use),
          as.list(study05_analysis_stats(z[[metric]][use])),row.names=NULL)
      }
    }
  }
  list(coverage=study05_analysis_bind(rows),nondelivery=study05_analysis_bind(nondelivery),region_geometry=study05_analysis_bind(geometry))
}

study05_error_analysis <- function(estimates, clean_points) {
  rows<-list()
  for(type in c('declared_point_vs_declared_target','declared_point_vs_clean_target','clean_point_vs_clean_target')) {
    e<-if(type=='clean_point_vs_clean_target')clean_points else estimates
    tx<-if(type=='declared_point_vs_clean_target')'truth_clean_dx' else 'truth_dx';ty<-if(type=='declared_point_vs_clean_target')'truth_clean_dy' else 'truth_dy'
    for(z in study05_analysis_groups(e,c('case_id','frame','entity'))) {
      finite<-z$observed_success&is.finite(z$dx)&is.finite(z$dy)&is.finite(z[[tx]])&is.finite(z[[ty]])
      d<-cbind(z$dx[finite]-z[[tx]][finite],z$dy[finite]-z[[ty]][finite]);n<-nrow(d)
      S<-if(n>=2L)stats::cov(d) else matrix(NA_real_,2L,2L)
      rows[[length(rows)+1L]]<-data.frame(z[1L,c('case_id','frame','entity'),drop=FALSE],comparison=type,n_planned=nrow(z),n_finite=n,
        bias_dx=if(n)mean(d[,1L]) else NA_real_,bias_dy=if(n)mean(d[,2L]) else NA_real_,
        bias_dx_mcse=study05_analysis_se(d[,1L]),bias_dy_mcse=study05_analysis_se(d[,2L]),
        rmse_dx=if(n)sqrt(mean(d[,1L]^2)) else NA_real_,rmse_dy=if(n)sqrt(mean(d[,2L]^2)) else NA_real_,
        euclidean_rmse=if(n)sqrt(mean(rowSums(d^2))) else NA_real_,
        error_var_dx=S[1L,1L],error_var_dy=S[2L,2L],error_cov_dx_dy=S[1L,2L],
        cohort='Finite successful observed estimates; independent outer panels',row.names=NULL)
    }
  }
  study05_analysis_bind(rows)
}

study05_paired_comparison <- function(a,b,kind,baseline,candidate) {
  keys<-c('case_id','dataset_id','entity')
  if(kind=='frame')keys<-c(keys,'method') else keys<-c(keys,'frame')
  b<-study05_analysis_match(a,b,keys)
  both<-a$delivered&b$delivered
  finite_cov<-is.finite(a$var_dx)&is.finite(a$var_dy)&is.finite(b$var_dx)&is.finite(b$var_dy)
  tracea<-a$var_dx+a$var_dy;traceb<-b$var_dx+b$var_dy;positive_trace<-finite_cov&tracea>0&traceb>0
  by<-setdiff(keys,'dataset_id')
  counts<-data.frame(a[1L,by,drop=FALSE],comparison=kind,baseline=baseline,candidate=candidate,n_planned=nrow(a),
    n_neither_delivered=sum(!a$delivered&!b$delivered),n_baseline_only_delivered=sum(a$delivered&!b$delivered),
    n_candidate_only_delivered=sum(!a$delivered&b$delivered),n_both_delivered=sum(both),
    n_both_covered=sum(a$covered[both]&b$covered[both]),n_baseline_only_covered=sum(a$covered[both]&!b$covered[both]),
    n_candidate_only_covered=sum(!a$covered[both]&b$covered[both]),n_neither_covered=sum(!a$covered[both]&!b$covered[both]),row.names=NULL)
  outcomes<-list(delivery=list(a$delivered,b$delivered),covered_delivery_yield=list(a$delivered&!is.na(a$covered)&a$covered,b$delivered&!is.na(b$covered)&b$covered),
    detected_delivery_yield=list(a$delivered&!is.na(a$rejects_zero)&a$rejects_zero,b$delivered&!is.na(b$rejects_zero)&b$rejects_zero),
    conditional_coverage_joint_delivery=list(a$covered[both],b$covered[both]),
    conditional_zero_exclusion_joint_delivery=list(a$rejects_zero[both],b$rejects_zero[both]),
    clean_target_inclusion_joint_delivery=list(a$clean_target_included[both],b$clean_target_included[both]),
    log_area_joint_delivery=list(log(a$area[both]),log(b$area[both])),log_cutoff_joint_delivery=list(log(a$cutoff[both]),log(b$cutoff[both])),
    covariance_trace_joint_finite=list(tracea[finite_cov],traceb[finite_cov]),log_covariance_trace_joint_positive=list(log(tracea[positive_trace]),log(traceb[positive_trace])))
  rows<-list()
  for(metric in names(outcomes)) {
    aa<-as.numeric(outcomes[[metric]][[1L]]);bb<-as.numeric(outcomes[[metric]][[2L]]);finite<-is.finite(aa)&is.finite(bb);d<-bb[finite]-aa[finite]
    rows[[length(rows)+1L]]<-data.frame(counts,metric=metric,n_paired=length(d),baseline_mean=study05_analysis_mean(aa[finite]),candidate_mean=study05_analysis_mean(bb[finite]),
      difference=study05_analysis_mean(d),paired_outer_mcse=study05_analysis_se(d),
      interpretation='Candidate minus baseline, paired within outer panel; common-delivery ratios condition on both deliveries; zero discordance is not equivalence',row.names=NULL)
  }
  study05_analysis_bind(rows)
}
study05_paired_analysis <- function(regions,estimates) {
  rows<-list()
  for(x in study05_analysis_groups(regions,c('case_id','frame','entity'))) {
    pairs<-utils::combn(study05_analysis_methods(),2L,simplify=FALSE)
    for(p in pairs)rows[[length(rows)+1L]]<-study05_paired_comparison(x[x$method==p[2L],,drop=FALSE],x[x$method==p[1L],,drop=FALSE],'method',p[2L],p[1L])
  }
  for(x in study05_analysis_groups(regions,c('case_id','entity','method')))rows[[length(rows)+1L]]<-study05_paired_comparison(
    x[x$frame=='core',,drop=FALSE],x[x$frame=='population_frame_oracle',,drop=FALSE],'frame','core','population_frame_oracle')
  points<-list()
  for(x in study05_analysis_groups(estimates,c('case_id','entity'))) {
    a<-x[x$frame=='core',,drop=FALSE];b<-study05_analysis_match(a,x[x$frame=='population_frame_oracle',,drop=FALSE],c('case_id','dataset_id','entity'))
    both<-a$observed_success&b$observed_success&is.finite(a$dx)&is.finite(a$dy)&is.finite(b$dx)&is.finite(b$dy)
    for(metric in c('dx','dy','euclidean')) {
      d<-if(metric=='euclidean')sqrt((b$dx[both]-a$dx[both])^2+(b$dy[both]-a$dy[both])^2) else b[[metric]][both]-a[[metric]][both]
      points[[length(points)+1L]]<-data.frame(a[1L,c('case_id','entity'),drop=FALSE],metric=metric,n_planned=nrow(a),n_joint_observed=sum(both),
        mean_difference=study05_analysis_mean(d),paired_outer_mcse=study05_analysis_se(d),max_absolute_difference=if(length(d))max(abs(d)) else NA_real_,
        tolerance=1e-9,within_tolerance=if(length(d))all(abs(d)<=1e-9) else NA,row.names=NULL)
    }
  }
  list(paired_comparisons=study05_analysis_bind(rows),frame_point_agreement=study05_analysis_bind(points))
}

# Compare all pairs differing in exactly one frozen Gaussian design factor.
# Even when dataset IDs match across cases, these panels are INDEPENDENT.
study05_crosscell_analysis <- function(coverage,caseplan) {
  cp<-caseplan[caseplan$scenario=='gapped_gaussian',,drop=FALSE];factors<-c('g','a','m','focal_motion','rho_unit');rows<-list()
  if(nrow(cp)<2L)return(data.frame())
  for(pair in utils::combn(seq_len(nrow(cp)),2L,simplify=FALSE)) {
    a<-cp[pair[1L],,drop=FALSE];b<-cp[pair[2L],,drop=FALSE]
    changed<-factors[vapply(factors,function(v)!identical(a[[v]],b[[v]]),logical(1L))]
    if(length(changed)!=1L)next
    aa<-coverage[coverage$case_id==a$case_id,,drop=FALSE];bb<-coverage[coverage$case_id==b$case_id,,drop=FALSE]
    bb<-study05_analysis_match(aa,bb,c('frame','entity','method','stratum','stratum_bin'))
    for(i in seq_len(nrow(aa)))for(metric in c('delivery','conditional_coverage','covered_delivery_yield','conditional_zero_exclusion','detected_delivery_yield','clean_target_inclusion')) {
      p1<-aa[[paste0(metric,'_estimate')]][i];p2<-bb[[paste0(metric,'_estimate')]][i]
      s1<-aa[[paste0(metric,'_mcse')]][i];s2<-bb[[paste0(metric,'_mcse')]][i]
      rows[[length(rows)+1L]]<-data.frame(aa[i,c('frame','entity','method'),drop=FALSE],factor=changed,baseline_case=a$case_id,candidate_case=b$case_id,
        baseline_level=as.character(a[[changed]]),candidate_level=as.character(b[[changed]]),metric=metric,
        baseline_numerator=aa[[paste0(metric,'_numerator')]][i],baseline_denominator=aa[[paste0(metric,'_denominator')]][i],
        candidate_numerator=bb[[paste0(metric,'_numerator')]][i],candidate_denominator=bb[[paste0(metric,'_denominator')]][i],
        baseline_estimate=p1,candidate_estimate=p2,difference=p2-p1,independent_outer_mcse=sqrt(s1^2+s2^2),
        interpretation='Candidate minus baseline; independent outer-panel MCSE, never paired by dataset ID; descriptive only',row.names=NULL)
    }
  }
  study05_analysis_bind(rows)
}

study05_panel_diagnostic_summary <- function(panel, keys, metrics) {
  rows<-list()
  for(x in study05_analysis_groups(panel,keys))for(metric in metrics)if(metric%in%names(x)) {
    z<-x[[metric]];finite<-is.finite(z)
    rows[[length(rows)+1L]]<-data.frame(x[1L,keys,drop=FALSE],outer_metric=metric,n_outer=nrow(x),n_outer_finite=sum(finite),
      as.list(study05_analysis_stats(z)),outer_panel_mcse=study05_analysis_se(z),
      interpretation='Within-panel diagnostic first; MCSE across independent outer panels, not individual resampled draws or deletions',row.names=NULL)
  }
  study05_analysis_bind(rows)
}

study05_sparse_benchmark <- function(M=80L) {
  r<-0:12;q<-r/12;full<-stats::pbinom(0L,12L,q,lower.tail=FALSE);pivot<-stats::pbinom(1L,12L,q,lower.tail=FALSE)
  delivery<-ifelse(r>=2L,stats::pbinom(189L,199L,pivot,lower.tail=FALSE),0);p<-stats::dbinom(r,12L,.15)
  data.frame(rare_count=r,rare_bin=ifelse(r>=4L,'4+',as.character(r)),observed_count_probability=p,n_planned=M,
    expected_panels=M*p,observed_fit_rank_eligible=r>=1L,observed_jackknife_rank_eligible=r>=2L,
    bootstrap_full_rank_probability=full,bootstrap_complete_jackknife_rank_probability=pivot,
    rank_only_delivery_probability_given_count=delivery,expected_rank_only_deliveries=M*p*delivery,
    interpretation='Analytic rare-axis rank mechanism only; excludes covariance/alignment/geometry failures; production gate unchanged')
}

study05_write_figures <- function(answer,out) {
  if(!requireNamespace('ggplot2',quietly=TRUE))stop('ggplot2 is required for frozen figures.')
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  save<-function(p,name,width=12,height=11) {
    path<-file.path(out,paste0(name,'.pdf'))
    ggplot2::ggsave(path,p,device=grDevices::cairo_pdf,width=width,height=height,units='in',bg='white')
    if(!file.exists(path)||file.info(path)$size<=1000L||!identical(rawToChar(readBin(path,'raw',5L)),'%PDF-'))
      stop('Figure serialization failed: ',path)
    invisible(path)
  }
  theme<-ggplot2::theme_minimal(base_size=10)+ggplot2::theme(legend.position='bottom',panel.grid.minor=ggplot2::element_blank(),
    plot.caption=ggplot2::element_text(hjust=0,size=8),plot.title=ggplot2::element_text(face='bold'))
  c<-answer$coverage;z<-c[c$frame=='core'&c$method=='jackknife_studentized',,drop=FALSE]
  case_order<-unique(c$case_id);z$case_id<-factor(z$case_id,rev(case_order));z$entity<-factor(z$entity,c('E015','E003','E006'))
  plotrows<-study05_analysis_bind(lapply(c('conditional_coverage','delivery','covered_delivery_yield'),function(metric) {
    data.frame(z[c('case_id','entity','contract')],metric=metric,estimate=z[[paste0(metric,'_estimate')]],
      lower=z[[paste0(metric,'_wilson_lower')]],upper=z[[paste0(metric,'_wilson_upper')]])
  }))
  p<-ggplot2::ggplot(plotrows,ggplot2::aes(estimate,case_id,color=metric))+
    ggplot2::geom_vline(xintercept=.95,linetype='dashed',color='#909090')+
    ggplot2::geom_errorbar(ggplot2::aes(xmin=lower,xmax=upper),orientation='y',width=.15,position=ggplot2::position_dodge(.55),na.rm=TRUE)+
    ggplot2::geom_point(position=ggplot2::position_dodge(.55),size=1.4,na.rm=TRUE)+
    ggplot2::facet_wrap(~entity,nrow=1L)+ggplot2::scale_x_continuous(limits=c(0,1),breaks=c(0,.25,.5,.75,1))+
    ggplot2::scale_color_manual(values=c(conditional_coverage='#146B87',delivery='#BA7030',covered_delivery_yield='#568260'),
      labels=c(conditional_coverage='Coverage given delivery',delivery='Study-evaluable delivery',covered_delivery_yield='Covered-delivery yield'))+
    ggplot2::labs(title='Study 05: studentized joint regions across every frozen cell',x='Proportion',y=NULL,color=NULL,
      subtitle='E015 first; every target and planned cell retained',
      caption='Bars are pointwise 95% Wilson Monte Carlo intervals. The dashed line is 0.95 for coverage, not a delivery threshold.\nCoverage is conditional on delivery. AR(1) cells deliberately violate the iid-unit contract; nonzero anchor shifts are not whole-map nulls.')+theme
  save(p,'study05-studentized-coverage-delivery',height=max(7,2+.32*length(case_order)))
  all<-c[c$frame=='core',,drop=FALSE];all$case_id<-factor(all$case_id,rev(case_order));all$entity<-factor(all$entity,c('E015','E003','E006'))
  all$method<-factor(all$method,study05_analysis_methods())
  p<-ggplot2::ggplot(all,ggplot2::aes(conditional_coverage_estimate,case_id,color=method))+
    ggplot2::geom_vline(xintercept=.95,linetype='dashed',color='#909090')+
    ggplot2::geom_point(position=ggplot2::position_dodge(.65),size=1.25,na.rm=TRUE)+ggplot2::facet_wrap(~entity,nrow=1L)+
    ggplot2::scale_x_continuous(limits=c(0,1))+ggplot2::labs(title='All five joint-region methods: conditional coverage',
      x='Coverage among study-evaluable deliveries',y=NULL,color=NULL,
      caption='Methods share outer panels and draw weights. Points are descriptive; all numerators, denominators and Wilson intervals are in coverage.csv.\nUndefined conditional coverage remains unavailable, with delivery and exclusive non-delivery reasons retained separately.')+theme
  save(p,'study05-all-methods-coverage',height=max(7,2+.32*length(case_order)))
  sparse<-answer$nondelivery_strata
  sparse<-sparse[sparse$stratum=='rare'&sparse$frame=='core'&sparse$method=='jackknife_studentized',,drop=FALSE]
  if(nrow(sparse)) {
    sparse$stratum_bin<-factor(sparse$stratum_bin,c('0','1','2','3','4+'));sparse$entity<-factor(sparse$entity,c('E015','E003','E006'))
    sparse$reason<-factor(sparse$reason,study05_analysis_reasons())
    p<-ggplot2::ggplot(sparse,ggplot2::aes(stratum_bin,n_in_reason,fill=reason))+ggplot2::geom_col()+ggplot2::facet_wrap(~entity,nrow=1L)+
      ggplot2::scale_fill_brewer(palette='Set2',drop=FALSE)+ggplot2::labs(title='Sparse-unit sentinel: every planned panel has one delivery outcome',
        x='Observed rare-unit count',y='Outer panels',fill=NULL,
        caption='Target columns repeat the same panels; they are not independent replications. Zero-count bins/reasons remain in the exported table.\nThe original 20-pivot and 95% valid-fraction gates remain unchanged.')+theme
    save(p,'study05-sparse-nondelivery',height=6.5)
  }
  errors<-answer$errors;errors<-errors[errors$frame=='core',,drop=FALSE]
  if(nrow(errors)) {
    errors$case_id<-factor(errors$case_id,rev(case_order));errors$entity<-factor(errors$entity,c('E015','E003','E006'))
    p<-ggplot2::ggplot(errors,ggplot2::aes(euclidean_rmse,case_id,color=comparison))+ggplot2::geom_point(position=ggplot2::position_dodge(.45),na.rm=TRUE,size=1.6)+
      ggplot2::facet_wrap(~entity,nrow=1L)+ggplot2::labs(title='Observed-point error and anchor-target sensitivity',x='Euclidean RMSE',y=NULL,color=NULL,
        caption='Finite observed-estimate cohorts are explicitly counted. Declared-point error against the clean target is target sensitivity,\nnot calibration of a clean-anchor interval. The clean-anchor observed estimator is a separate diagnostic in errors.csv.')+theme
    save(p,'study05-target-sensitivity',height=max(7,2+.30*length(case_order)))
  }
  invisible(NULL)
}

study05_analyze <- function(tables,out,figures=TRUE,allow_fixture=FALSE) {
  study05_analysis_validate(tables,allow_fixture=allow_fixture)
  dir.create(out,recursive=TRUE,showWarnings=FALSE)
  coverage<-study05_coverage_analysis(tables$regions)
  strata<-study05_coverage_analysis(tables$regions,strata=TRUE)
  covariances<-study05_covariance_analysis(tables$estimates,tables$regions)
  paired<-study05_paired_analysis(tables$regions,tables$estimates)
  clean_status<-list()
  for(z in study05_analysis_groups(tables$clean_points,c('case_id','entity')))clean_status[[length(clean_status)+1L]]<-
    data.frame(z[1L,c('case_id','entity'),drop=FALSE],n_planned=nrow(z),n_attempted=sum(z$attempted),n_successful=sum(z$success),
      n_failed_after_attempt=sum(z$attempted&!z$success),n_unattempted=sum(!z$attempted),
      interpretation='Clean-anchor observed point only; no clean bootstrap or clean studentized region',row.names=NULL)
  answer<-c(coverage,list(coverage_strata=strata$coverage,nondelivery_strata=strata$nondelivery,
    errors=study05_error_analysis(tables$estimates,tables$clean_points),clean_point_accounting=study05_analysis_bind(clean_status),
    covariance=covariances$summary,covariance_outer_deletions=covariances$outer_deletions,
    covariance_all_observed=covariances$all_observed,covariance_variability=covariances$variability),paired,
    list(crosscell_contrasts=study05_crosscell_analysis(coverage$coverage,tables$caseplan),
      selection=study05_panel_diagnostic_summary(tables$selection_panel,c('case_id','frame','entity','metric','contrast'),
        c('baseline_mean','selected_mean','failed_mean','difference','selected_minus_failed','n_baseline_finite','n_selected_finite','n_failed_finite')),
      geometry=study05_panel_diagnostic_summary(tables$geometry_panel,intersect(c('case_id','kind','role','stage','period','parent_kind','metric'),names(tables$geometry_panel)),
        c('mean','median','q95','maximum','n_finite','n_attempted','n_successful','n_failed_after_attempt','n_unattempted')),
      frame_variation=study05_panel_diagnostic_summary(tables$frame_variation_panel,c('case_id','metric'),c('mean','q95','maximum','n_finite')),
      population_target_sensitivity=unique(tables$estimates[c('case_id','entity','truth_dx','truth_dy','truth_clean_dx','truth_clean_dy','target_norm_declared','target_norm_clean','target_distance_declared_clean')]),
      sparse_rank_benchmark=study05_sparse_benchmark(if(any(tables$caseplan$scenario=='rare_axis'))tables$caseplan$M[tables$caseplan$scenario=='rare_axis'][1L] else 80L)))
  for(name in names(answer))utils::write.csv(answer[[name]],file.path(out,paste0(gsub('_','-',name),'.csv')),row.names=FALSE,na='')
  # Preserve compact tables as a reproducible entry point to all summaries.
  saveRDS(tables,file.path(out,'analysis-inputs.rds'),compress='gzip')
  writeLines(c(
    'Study 05 analyses are prespecified descriptive comparisons; no hypothesis-test family, equivalence decision, or release gate is introduced.',
    'All reserved panels are analyzed only after complete implementation freeze. These panels are never pooled with earlier studies.',
    'The principal target is theta_D, the full declared-anchor population functional. A nonzero anchor dose changes this target even without focal movement.',
    'Clean-target inclusion by a theta_D region is target sensitivity, not coverage of a clean-anchor interval. A separate clean-anchor observed point is fit against theta_C; no clean bootstrap or clean studentized region is implemented.',
    'The reported delivery/yield denominator is the full planned STUDY-EVALUABLE sample. An evaluation-only registration block records candidate delivery as unknown, never demonstrated computational non-delivery.',
    'Coverage and conditional zero exclusion use delivered regions; covered/detected-delivery yields use all planned panels. All counts, zero-denominator NA results, Wilson95% intervals and binomial outer-panel MCSE are retained.',
    'E015 is reported first, followed by E003 and E006. Targets/methods/frames share each panel and are not independent replications.',
    'Method and frame comparisons use paired panel differences. All pairs of Gaussian cells differing in exactly one fixed factor use independent-panel MCSE, never pairing common dataset IDs across cases.',
    'Covariance ratios match finite observed errors with the particular available covariance. The all-observed error covariance is separate. Outer-delete-one uncertainty recomputes numerator and denominator; fewer than20 eligible panels or any required deletion failure leaves SE unavailable.',
    'Generalized covariance ratios require denominator SPD eigenratio>1e-8, with actual spectra retained and no ridge. Descriptive covariance agreement does not establish pivot calibration.',
    'Observed gap strata require finite gaps for BOTH periods and use min_t (lambda2-lambda3)/lambda1. Partial finite spectra remain in fit ledgers and the finite-period count.',
    'Principal anchor strata use the minimum finite source/target/cross-product singular-value ratio over ALL attempted core baseline/temporal stages, including full fits and required deletions. Oracle, evaluation and clean stages are excluded. A separately labeled observed-only auxiliary anchor stratum is retained with attempted-stage counts.',
    'Conditioning bins include every fixed bin, including empty bins, alongside unstratified totals. These post-data strata add no scientific gate and do not establish conditional calibration.',
    'Geometry and selection diagnostics summarize within each panel before outer-panel MCSE. Draw-selection error_norm is the Euclidean distance from the bootstrap displacement to its observed point in the same frame, not its error against the population target. Error norms for unavailable fits are missing, not zero. All required scalar geometry remains in checkpoints and collector products.',
    'AR(1) cells are explicitly outside the iid-unit contract: iid draws and iid occurrence studentization are intentionally misspecified. The Gaussian Gram VIF does not alter m, covariance, cutoffs, or delivery gates.',
    'Sparse rare-count bins0,1,2,3,4+ and the unchanged rank-only mechanism benchmark retain all planned panels. No successful-fit redraws, gate relaxation, covariance inflation, or outcome-dependent selection is applied.'),file.path(out,'analysis-notes.txt'))
  if(figures)study05_write_figures(answer,out)
  invisible(answer)
}
