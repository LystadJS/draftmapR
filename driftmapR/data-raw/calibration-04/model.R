# Study04 changes the independent evaluation design, never the candidate.
study04_settings <- function() {
  list(B=199L, data_seed=260929L, bootstrap_seed_base=4400000L,
       movement_scale=.2, targets=c('E015','E003','E006'),
       min_valid=20L, min_success=.95, level=.95, cov_tol=1e-8,
       engine_version='0.0.7.9000', workers=8L,
       primary_entities=c('E006','E003'),
       primary_cases=c('regular_null_m40','regular_null_m160'),
       primary_test_alpha=.025, crossfit_half=200L,
       crossfit_min_donors=190L, audit_datasets=1:2,
       fixture_seed=778L, fixture_dataset=999L)
}
study04_cases <- function() {
  data.frame(case_id=c('regular_null_m40','regular_null_m160',
    'regular_movement_m40','regular_movement_m160','rare_axis_m12'),
    scenario=c('regular_null','regular_null','regular_movement','regular_movement','rare_axis'),
    m=c(40L,160L,40L,160L,12L), M=c(400L,400L,100L,100L,120L), B=199L,
    movement_scale=c(0,0,.2,.2,.2),
    role=c('primary_replication','primary_replication','movement_control',
      'movement_control','failure_stress'), case_index=1:5,
    stringsAsFactors=FALSE)
}
study04_jobs <- function(cases=study04_cases()) {
  previous_kind<-RNGkind(); had_seed<-exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had_seed)previous_seed<-get('.Random.seed',envir=.GlobalEnv)
  on.exit({do.call(RNGkind,as.list(previous_kind));if(had_seed)assign('.Random.seed',previous_seed,envir=.GlobalEnv)
    else if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE))rm('.Random.seed',envir=.GlobalEnv)},add=TRUE)
  s<-study04_settings();RNGkind("L'Ecuyer-CMRG",'Inversion','Rejection');set.seed(s$data_seed)
  stream<-.Random.seed;jobs<-list()
  for(k in seq_len(nrow(cases)))for(i in seq_len(cases$M[k])) {
    jobs[[length(jobs)+1L]]<-list(case_id=cases$case_id[k],case_index=cases$case_index[k],
      dataset_id=as.integer(i),m=as.integer(cases$m[k]),data_stream=stream,
      bootstrap_seed=as.integer(s$bootstrap_seed_base+cases$case_index[k]*10000L+i),
      stage='independent_secondary_replication')
    stream<-parallel::nextRNGStream(stream)
  }
  jobs
}
study04_fixture <- function(case_index=3L, B=21L) {
  old_kind<-RNGkind();had<-exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had)old_seed<-get('.Random.seed',envir=.GlobalEnv)
  on.exit({do.call(RNGkind,as.list(old_kind));if(had)assign('.Random.seed',old_seed,envir=.GlobalEnv)
    else if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE))rm('.Random.seed',envir=.GlobalEnv)},add=TRUE)
  RNGkind("L'Ecuyer-CMRG",'Inversion','Rejection');set.seed(778L)
  case<-study04_cases()[case_index,,drop=FALSE];case$B<-as.integer(B)
  job<-list(case_id=case$case_id,case_index=case$case_index,dataset_id=999L,
    m=case$m,data_stream=.Random.seed,bootstrap_seed=778L,stage='reserved_engineering_fixture')
  list(job=job,case=case,generated=study03_generate(job,case))
}
