study05_analysis_fixture <- local({
  cache<-NULL
  function() {
    if(is.null(cache)) {
      f<-study05_fixture(1L,2L);r<-study05_one(f$job,f$case,f$generated)
      cache<-study05_analysis_extract(r);cache$caseplan<-f$case
    }
    cache
  }
})

testthat::test_that('proportions retain numerator denominator Wilson and zero-cohort NA', {
  zero<-study05_analysis_prop(0,0)
  testthat::expect_equal(zero[1:2],c(numerator=0,denominator=0))
  testthat::expect_true(all(is.na(zero[-(1:2)])))
  p<-study05_analysis_prop(95,100)
  testthat::expect_equal(unname(p['estimate']),.95)
  testthat::expect_equal(unname(p['mcse']),sqrt(.95*.05/100))
  testthat::expect_lt(p['wilson_lower'],.95);testthat::expect_gt(p['wilson_upper'],.95)
  testthat::expect_error(study05_analysis_prop(1,0),'Invalid')
  testthat::expect_error(study05_analysis_prop(.5,1),'Invalid')
  stats<-study05_analysis_stats(c(1,2,3,Inf,NA))
  testthat::expect_equal(unname(stats[c('n_total','n_finite','n_nonfinite')]),c(5,3,2))
  testthat::expect_equal(unname(stats[c('q10','median','q90','q95')]),c(1.2,2,2.8,2.9))
})

testthat::test_that('analysis validates complete unique grids and target sensitivity', {
  x<-study05_analysis_fixture()
  testthat::expect_true(study05_analysis_validate(x,allow_fixture=TRUE))
  testthat::expect_error(study05_analysis_validate(x),'exact frozen case plan')
  y<-x;y$regions<-rbind(y$regions,y$regions[1L,])
  testthat::expect_error(study05_analysis_validate(y,TRUE),'Duplicate')
  y<-x;y$regions<-y$regions[-1L,]
  testthat::expect_error(study05_analysis_validate(y,TRUE),'Incomplete')
  testthat::expect_identical(unique(x$regions$inclusion_interpretation),
    'Declared-anchor region contains clean target; not calibration of a clean-anchor interval')
  testthat::expect_true(all(is.na(x$regions$clean_target_included[!x$regions$delivered])))
  testthat::expect_equal(nrow(x$clean_points),3L)
})

testthat::test_that('all strata retain empty bins and exclusive planned counts', {
  x<-study05_analysis_fixture();s<-study05_coverage_analysis(x$regions,TRUE)
  testthat::expect_equal(nrow(s$coverage),30L*(6L+5L+5L))
  testthat::expect_true(any(s$coverage$n_planned==0L))
  testthat::expect_true(all(is.na(s$coverage$conditional_coverage_estimate[s$coverage$n_delivered==0L])))
  keys<-c('case_id','frame','entity','method','stratum','stratum_bin')
  for(z in study05_analysis_groups(s$nondelivery,keys)) {
    testthat::expect_equal(sum(z$n_in_reason),z$n_planned[1L])
    testthat::expect_setequal(z$reason,study05_analysis_reasons())
  }
  testthat::expect_identical(study05_gap_bin(c(NA,1e-10,.01,.05,.2,.3)),
    c('unavailable','<=1e-10','(1e-10,.01]','(.01,.05]','(.05,.2]','>.2'))
  testthat::expect_identical(study05_anchor_bin(c(NA,1e-10,.01,.1,.2)),
    c('unavailable','<=1e-10','(1e-10,.01]','(.01,.1]','>.1'))
})

testthat::test_that('evaluation-only blocks are unknown candidate delivery not demonstrated failure', {
  f<-study05_fixture(1L,2L)
  r<-study05_one(f$job,f$case,f$generated,evaluation_register=function(...)stop('fixture evaluation block'))
  x<-study05_analysis_extract(r);s<-study05_coverage_analysis(x$regions)
  testthat::expect_true(all(s$coverage$n_candidate_delivery_unknown==1L))
  testthat::expect_true(all(s$coverage$n_candidate_demonstrated_nondelivery==0L))
  testthat::expect_true(all(s$coverage$n_delivered==0L))
  z<-s$nondelivery[s$nondelivery$reason=='observed_unavailable',]
  testthat::expect_true(all(z$evaluation_only_block==1L))
  testthat::expect_true(all(z$actual_observed_core_fit_failure==0L))
  testthat::expect_true(all(x$clean_points$success))
})

testthat::test_that('observed gap needs both periods and principal anchor strata include deletions', {
  f<-study05_fixture(1L,2L);r<-study05_one(f$job,f$case,f$generated)
  eg<-r$geometry$embedding;ii<-eg$parent_id==0L&eg$unit_index==0L&eg$period==2L
  r$geometry$embedding$gap_relative1[ii]<-NA_real_
  rg<-r$geometry$registration;j<-which(rg$parent_id>0L&rg$unit_index>0L&rg$stage=='alignment_temporal')[1L]
  r$geometry$registration$cross_ratio[j]<-1e-11
  x<-study05_analysis_extract(r)
  testthat::expect_equal(x$observed_geometry$observed_gap_periods_finite,1L)
  testthat::expect_identical(x$observed_geometry$gap_bin,'unavailable')
  testthat::expect_identical(x$observed_geometry$anchor_bin,'<=1e-10')
  testthat::expect_false(x$observed_geometry$observed_anchor_bin=='<=1e-10')
})

testthat::test_that('selection is paired within outer panel and undefined errors are never zeroed', {
  x<-study05_analysis_fixture();z<-x$selection_panel
  testthat::expect_true(all(c('max_multiplicity','error_norm','observed_rare_count')%in%z$metric))
  testthat::expect_equal(z$difference,z$selected_mean-z$baseline_mean)
  f<-study05_fixture(1L,2L)
  r<-study05_one(f$job,f$case,f$generated,hooks=list(fit=function(context)
    if(context$role=='core'&&context$parent_id==0L&&context$unit_index==0L)stop('fixture full failure')))
  z<-study05_analysis_extract(r)$selection_panel
  z<-z[z$metric=='error_norm',]
  testthat::expect_true(all(z$n_baseline_finite==0L))
  testthat::expect_true(all(is.na(z$baseline_mean)))
})

testthat::test_that('paired and cross-cell contrasts use distinct uncertainty contracts', {
  x<-study05_analysis_fixture();r<-x$regions
  a<-r[r$frame=='core'&r$entity=='E015'&r$method=='wald',]
  b<-r[r$frame=='core'&r$entity=='E015'&r$method=='jackknife_studentized',]
  aa<-a[rep(1L,4L),];bb<-b[rep(1L,4L),];aa$dataset_id<-bb$dataset_id<-1:4
  aa$delivered<-c(TRUE,TRUE,FALSE,FALSE);bb$delivered<-c(TRUE,FALSE,TRUE,FALSE)
  aa$covered<-c(TRUE,FALSE,NA,NA);bb$covered<-c(FALSE,NA,TRUE,NA)
  aa$rejects_zero<-aa$covered;bb$rejects_zero<-bb$covered
  aa$clean_target_included<-aa$covered;bb$clean_target_included<-bb$covered
  p<-study05_paired_comparison(aa,bb,'method','wald','jackknife_studentized')
  testthat::expect_true(all(p$n_neither_delivered==1L&p$n_baseline_only_delivered==1L&p$n_candidate_only_delivered==1L&p$n_both_delivered==1L))
  d<-p[p$metric=='delivery',]
  testthat::expect_equal(d$difference,0)
  testthat::expect_equal(d$paired_outer_mcse,stats::sd(c(0,-1,1,0))/2)
  c<-study05_coverage_analysis(r)$coverage;cp<-x$caseplan
  cp2<-cp;cp2$case_id<-'synthetic_second_case';cp2$m<-160L
  c2<-c;c2$case_id<-cp2$case_id;c2$delivery_estimate<-.7;c2$delivery_mcse<-.03
  c$delivery_estimate<-.8;c$delivery_mcse<-.04
  z<-study05_crosscell_analysis(rbind(c,c2),rbind(cp,cp2));z<-z[z$metric=='delivery',]
  testthat::expect_equal(z$difference,rep(-.1,nrow(z)))
  testthat::expect_equal(z$independent_outer_mcse,rep(.05,nrow(z)))
  testthat::expect_true(all(z$factor=='m'))
})

testthat::test_that('full analysis and figure pipeline is executable on engineering data only', {
  x<-study05_analysis_fixture();out<-tempfile('study05-analysis-fixture-')
  ans<-study05_analyze(x,out,figures=TRUE,allow_fixture=TRUE)
  testthat::expect_equal(nrow(ans$coverage),30L)
  testthat::expect_identical(ans$coverage$method[1L],'jackknife_studentized')
  testthat::expect_identical(unique(ans$coverage$entity),c('E015','E003','E006'))
  testthat::expect_true(all(c('covariance_outer_deletions','population_target_sensitivity','clean_point_accounting')%in%names(ans)))
  pdfs<-list.files(out,pattern='[.]pdf$',full.names=TRUE)
  testthat::expect_true(length(pdfs)>=3L)
  testthat::expect_true(all(file.info(pdfs)$size>1000L))
  testthat::expect_true(all(vapply(pdfs,function(path)identical(rawToChar(readBin(path,'raw',5L)),'%PDF-'),logical(1L))))
  testthat::expect_true(file.exists(file.path(out,'analysis-inputs.rds')))
  testthat::expect_equal(sum(ans$sparse_rank_benchmark$expected_panels),80,tolerance=1e-12)
  testthat::expect_true(all(ans$sparse_rank_benchmark$n_planned==80L))
})


testthat::test_that('standalone evaluation analysis cannot narrow or mutate the frozen plan', {
  x<-study05_analysis_fixture()
  testthat::expect_error(study05_analysis_validate(x),'exact frozen case plan')
  x$caseplan<-study05_cases()
  testthat::expect_error(study05_analysis_validate(x),'incomplete frozen outer sample')
  x$caseplan<-study05_cases()[-31L,,drop=FALSE]
  testthat::expect_error(study05_analysis_validate(x),'exact frozen case plan')
  x$caseplan<-study05_cases();x$caseplan$M[1L]<-59L
  testthat::expect_error(study05_analysis_validate(x),'exact frozen case plan')
  x$caseplan<-study05_cases()[31:1,,drop=FALSE]
  testthat::expect_error(study05_analysis_validate(x),'exact frozen case plan')
})
