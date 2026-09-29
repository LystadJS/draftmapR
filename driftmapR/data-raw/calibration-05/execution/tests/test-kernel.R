testthat::test_that('instrumented full estimator is numerically identical to inherited Study04', {
  f<-study05_fixture(1L,3L)
  set.seed(779)
  before<-get('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  r<-study05_one(f$job,f$case,f$generated,keep_inner_values=TRUE)
  old<-study04_one(f$job,f$case,f$generated,keep_inner_values=TRUE)
  testthat::expect_identical(get('.Random.seed',envir=.GlobalEnv,inherits=FALSE),before)
  for(frame in c('core','frame')) {
    a<-if(frame=='core')r else r$frame;b<-if(frame=='core')old else old$frame
    for(name in c('weights','streams','point','estimate','values','eval_values','pivots',
                  'observed_jackknife','inner'))testthat::expect_identical(a[[name]],b[[name]])
  }
  testthat::expect_true(r$clean$success)
  C<-lapply(f$generated$X,function(x)tcrossprod(x)/f$job$m)
  clean<-study03_fit(C[[1L]],C[[2L]],f$generated$model$population_points[[1L]],
    f$generated$model$clean_anchors)
  testthat::expect_identical(r$clean$estimate,
    clean$displacement[f$generated$model$target_rows,,drop=FALSE])
  testthat::expect_true(length(r$geometry$matrices$embedding)>0L)
  testthat::expect_true(all(r$geometry$embedding$success))
  testthat::expect_true(all(r$geometry$registration$success))
  e<-subset(r$geometry$embedding,role=='core')
  testthat::expect_equal(nrow(e),2L*(1L+f$case$B+f$case$m+
    sum(apply(r$weights,1L,function(w)sum(w>0)))))
  testthat::expect_equal(sum(e$unit_index>0L),
    2L*(f$case$m+sum(apply(r$weights,1L,function(w)sum(w>0)))))
})

testthat::test_that('dependence assumptions are honest without changing iid draw plans', {
  f<-study05_fixture(27L,2L)
  r<-study05_one(f$job,f$case,f$generated)
  testthat::expect_match(study05_assumptions(f$case),'Unsupported misspecification stress')
  testthat::expect_match(paste(unlist(r$design_metadata),collapse=' '),'AR\\(1\\)')
  testthat::expect_identical(r$model_metadata$contract,'dependence_stress_outside_iid_contract')
  old<-study04_one(f$job,f$case,f$generated,keep_inner_values=FALSE)
  testthat::expect_identical(r$weights,old$weights)
  testthat::expect_identical(r$pivots,old$pivots)
})

testthat::test_that('observed failure preserves all planned slots and independent clean diagnostic', {
  f<-study05_fixture(1L,3L)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(fit=function(context)
    if(context$role=='core'&&context$parent_id==0L&&context$unit_index==0L)
      stop('injected observed fitting failure')))
  testthat::expect_false(r$full_observed_success)
  testthat::expect_false(r$evaluation_only_block)
  testthat::expect_true(r$clean$attempted&&r$clean$success)
  testthat::expect_equal(dim(r$weights),c(3L,40L))
  testthat::expect_equal(nrow(r$attempts),3L)
  testthat::expect_equal(nrow(r$studentization),9L)
  testthat::expect_false(any(r$attempts$attempted))
  testthat::expect_true(all(!r$regions$candidate_region_delivered))
  testthat::expect_true(all(r$regions$studentized_nondelivery_reason[
    r$regions$method=='jackknife_studentized']=='observed_unavailable'))
  for(jk in c(list(r$observed_jackknife),r$inner)) {
    count<-study05_validate_ledger(jk$ledger)
    testthat::expect_equal(count$attempted_unique,0L)
    testthat::expect_equal(count$required_occurrences,40L)
  }
})

testthat::test_that('evaluation-only blocks retain unknown computational candidate delivery', {
  f<-study05_fixture(1L,3L)
  r<-study05_one(f$job,f$case,f$generated,evaluation_register=function(...)
    stop('injected evaluation-only registration failure'))
  testthat::expect_true(r$full_observed_success)
  testthat::expect_true(r$evaluation_only_block)
  testthat::expect_false(r$evaluation_registration_available)
  testthat::expect_true(all(is.finite(r$candidate_point_R0)))
  testthat::expect_true(all(is.na(r$regions$candidate_region_delivered)))
  testthat::expect_false(any(r$regions$study_evaluable_region_delivered))
  testthat::expect_false(any(r$attempts$attempted))
  testthat::expect_true(r$clean$success)
  z<-subset(r$geometry$registration,stage=='evaluation_registration')
  testthat::expect_true(z$attempted&&!z$success)
  testthat::expect_match(z$message,'evaluation-only')
})

testthat::test_that('a failed deletion does not stop remaining required unique computations', {
  f<-study05_fixture(1L,3L)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(fit=function(context)
    if(context$role=='core'&&context$parent_id==0L&&context$unit_index==1L)
      stop('injected first deletion failure')))
  ledger<-r$observed_jackknife$ledger
  testthat::expect_true(all(ledger$attempted))
  testthat::expect_false(ledger$success[1L])
  testthat::expect_true(all(ledger$success[-1L]))
  testthat::expect_true(all(r$attempts$attempted))
  testthat::expect_false(any(r$observed_jackknife$covariance_ok))
  testthat::expect_equal(study05_validate_ledger(ledger)$failed_occurrences,1L)
  testthat::expect_true(all(r$regions$studentized_nondelivery_reason[
    r$regions$method=='jackknife_studentized']=='observed_deletion_unavailable'))
})

testthat::test_that('singular observed and inner covariances retain all deletion accounting', {
  f<-study05_fixture(1L,2L)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(covariance=function(values,counts)
    rep(list(matrix(0,2L,2L)),dim(values)[2L])))
  testthat::expect_true(r$observed_jackknife$all_required_success)
  testthat::expect_false(any(r$observed_jackknife$covariance_ok))
  testthat::expect_false(any(r$studentization$covariance_ok))
  testthat::expect_true(all(r$regions$studentized_nondelivery_reason[
    r$regions$method=='jackknife_studentized']=='observed_covariance_invalid'))
  testthat::expect_true(all(vapply(r$inner,`[[`,logical(1L),'all_required_success')))
})

testthat::test_that('nonfinite pivots are failures with original planned denominator', {
  f<-study05_fixture(1L,2L)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(quadratic=function(error,S)Inf))
  testthat::expect_true(all(r$studentization$covariance_ok))
  testthat::expect_false(any(r$studentization$pivot_ok))
  testthat::expect_true(all(r$studentization$stage=='pivot'))
  testthat::expect_true(all(is.na(r$pivots)))
  testthat::expect_equal(nrow(r$studentization),6L)
  testthat::expect_true(all(r$regions$studentized_nondelivery_reason[
    r$regions$method=='jackknife_studentized']=='insufficient_pivots'))
})

testthat::test_that('oracle failures and warnings remain isolated from the core estimator', {
  f<-study05_fixture(1L,2L)
  old<-study05_one(f$job,f$case,f$generated)
  r<-study05_one(f$job,f$case,f$generated,keep_inner_values=TRUE,
    oracle_register=function(...)stop('injected oracle failure'))
  testthat::expect_identical(r$pivots,old$pivots)
  testthat::expect_true(all(r$attempts$success))
  testthat::expect_false(any(r$frame$attempts$success))
  testthat::expect_true(all(r$frame$attempts$attempted))
  testthat::expect_true(all(r$frame$observed_jackknife$ledger$attempted))
  testthat::expect_false(any(r$frame$observed_jackknife$ledger$success))
  z<-subset(r$geometry$registration,stage=='oracle_registration')
  testthat::expect_true(all(z$attempted&!z$success))
  testthat::expect_true(all(is.finite(z$cross_ratio)))
  testthat::expect_true(!is.null(r$geometry$matrices$registration[[as.character(z$diagnostic_id[1L])]]$cross_decomposition))
  w<-study05_one(f$job,f$case,f$generated,oracle_register=function(source,target,anchors){
    warning('injected diagnostic warning');study02_register(source,target,anchors)})
  z<-subset(w$geometry$registration,stage=='oracle_registration')
  testthat::expect_true(all(grepl('injected diagnostic warning',z$warnings)))
  testthat::expect_identical(w$pivots,old$pivots)
})

testthat::test_that('projector diagnostic failure cannot create a new fitting gate', {
  f<-study05_fixture(1L,2L)
  old<-study05_one(f$job,f$case,f$generated)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(projector=function(U,V)
    stop('injected projector diagnostic failure')))
  testthat::expect_identical(r$pivots,old$pivots)
  testthat::expect_identical(r$values,old$values)
  testthat::expect_true(all(r$geometry$embedding$success))
  testthat::expect_false(any(r$geometry$embedding$diagnostic_success))
  testthat::expect_true(all(grepl('projector diagnostic failure',r$geometry$embedding$diagnostic_message)))
})

testthat::test_that('boundary rejection preserves finite spectra and stage-specific error', {
  f<-study05_fixture(1L,1L)
  e<-study05_geometry_state(f$generated$model,40L,1L,TRUE)
  C<-f$generated$model$population_grams[[1L]]
  d<-eigen(C,symmetric=TRUE);d$values[3L]<-d$values[2L]
  tied<-d$vectors%*%diag(d$values)%*%t(d$vectors)
  row<-study05_geometry_row(e,'embedding',1L,1L)
  testthat::expect_error(study05_geometry_points(tied,e,row),'boundary tie')
  out<-study05_geometry_finish(e)
  testthat::expect_true(is.finite(out$embedding$lambda1))
  testthat::expect_true(is.finite(out$embedding$lambda3))
  testthat::expect_false(out$embedding$success)
  testthat::expect_false(as.logical(out$embedding$boundary_ok))
  testthat::expect_true(!is.null(out$matrices$embedding[['1']]$vectors))
})

testthat::test_that('serial and parallel full estimators preserve identical jobs and streams', {
  fixtures<-lapply(c(1L,27L),study05_fixture,B=2L)
  work<-function(f) {
    r<-study05_one(f$job,f$case,f$generated)
    r$outer$elapsed_seconds<-NULL
    r
  }
  serial<-lapply(fixtures,work)
  parallel<-parallel::mclapply(fixtures,work,mc.cores=2L,mc.set.seed=FALSE)
  testthat::expect_identical(parallel,serial)
  testthat::expect_true(all(vapply(serial,function(r)
    identical(r$job$dataset_id,999L)&&identical(r$job$bootstrap_seed,779L),logical(1L))))
})
