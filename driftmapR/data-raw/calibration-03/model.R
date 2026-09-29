# Study03: full refits and exact occurrence jackknife; no population information
# is passed to the candidate estimator. Population objects are evaluation only.
study03_settings <- function() {
  list(B=199L, M_regular=120L, M_stress=80L, m=c(20L,40L,160L),
       data_seed=260923L, bootstrap_seed_base=3400000L,
       movement_scale=.2, targets=c('E015','E003','E006'),
       min_valid=20L,min_success=.95,level=.95,cov_tol=1e-8,
       engine_version='0.0.6.9000',workers=8L)
}
study03_cases <- function() {
  s<-study03_settings(); rows<-list()
  for(scenario in c('regular_null','regular_movement'))for(m in s$m) {
    rows[[length(rows)+1L]]<-data.frame(case_id=paste0(scenario,'_m',m),
      scenario=scenario,m=m,M=s$M_regular,B=s$B,
      movement_scale=if(scenario=='regular_null')0 else s$movement_scale,
      role='primary_grid',stringsAsFactors=FALSE)
  }
  rows[[length(rows)+1L]]<-data.frame(case_id='rare_axis_m12',scenario='rare_axis',
    m=12L,M=s$M_stress,B=s$B,movement_scale=s$movement_scale,role='failure_stress')
  ans<-do.call(rbind,rows);ans$case_index<-seq_len(nrow(ans));ans
}
study03_model <- function(case) {
  scenario<-calibration_scenarios()[match(case$scenario,calibration_scenarios()$scenario),,drop=FALSE]
  scenario$m<-as.integer(case$m)
  layout<-calibration_layout(scenario)
  change<-layout$latent[[2L]]-layout$latent[[1L]]
  layout$latent[[2L]]<-layout$latent[[1L]]+case$movement_scale*change
  ids<-rownames(layout$latent[[1L]]);n<-length(ids)
  H<-diag(n)-matrix(1/n,n,n);dimnames(H)<-list(ids,ids)
  C<-lapply(layout$latent,function(z)tcrossprod(H%*%z)+scenario$sigma^2*H)
  points<-lapply(C,study02_points);anchors<-match(layout$anchors,ids)
  population_fit<-study03_fit(C[[1L]],C[[2L]],points[[1L]],anchors)
  target_ids<-study03_settings()$targets;target_rows<-match(target_ids,ids)
  list(case=case,scenario=scenario,layout=layout,ids=ids,H=H,population_grams=C,
    population_points=points,population_fit=population_fit,anchors=anchors,
    target_ids=target_ids,target_rows=target_rows,
    truth=population_fit$displacement[target_rows,,drop=FALSE])
}
study03_generate <- function(job,case) {
  model<-study03_model(case)
  # Clone the generator environment to supply the prespecified scaled latent
  # layout; original study01 generator and global bindings remain unchanged.
  generator<-calibration_generate
  environment(generator)<-list2env(list(calibration_layout=function(scenario_row)model$layout),
                                   parent=environment(calibration_generate))
  g<-generator(model$scenario,job$data_stream)
  X<-lapply(1:2,function(t)model$H%*%as.matrix(g$data[g$data$time==t,g$features]))
  c(g,list(model=model,X=X))
}
study03_jobs <- function(cases=study03_cases()) {
  s<-study03_settings();RNGkind("L'Ecuyer-CMRG",'Inversion','Rejection');set.seed(s$data_seed)
  stream<-.Random.seed;jobs<-list()
  for(k in seq_len(nrow(cases)))for(i in seq_len(cases$M[k])) {
    jobs[[length(jobs)+1L]]<-list(case_id=cases$case_id[k],case_index=cases$case_index[k],
      dataset_id=as.integer(i),m=as.integer(cases$m[k]),data_stream=stream,
      bootstrap_seed=as.integer(s$bootstrap_seed_base+cases$case_index[k]*10000L+i),
      stage='independent_studentized_calibration')
    stream<-parallel::nextRNGStream(stream)
  }
  jobs
}
