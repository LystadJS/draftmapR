testthat::test_that('independent design fixes all budgets and the two replication endpoints', {
  cases<-study04_cases();s<-study04_settings()
  testthat::expect_equal(sum(cases$M),1120L)
  testthat::expect_equal(sum(cases$M*cases$B),222880L)
  testthat::expect_identical(cases$M,c(400L,400L,100L,100L,120L))
  testthat::expect_identical(s$primary_entities,c('E006','E003'))
  testthat::expect_identical(s$primary_cases,c('regular_null_m40','regular_null_m160'))
  testthat::expect_equal(s$primary_test_alpha,.025)
  testthat::expect_identical(s$targets,study03_settings()$targets)
  testthat::expect_false(s$data_seed==study03_settings()$data_seed)
  testthat::expect_false(s$bootstrap_seed_base==study03_settings()$bootstrap_seed_base)
  testthat::expect_identical(s$min_success,study03_settings()$min_success)
})

testthat::test_that('reserved stream planner is reproducible and restores caller RNG', {
  # Clone only the settings binding. Never construct fresh study04 streams here.
  planner<-study04_jobs
  environment(planner)<-list2env(list(study04_settings=function(){
    s<-study04_settings();s$data_seed<-778L;s$bootstrap_seed_base<-778000L;s
  }),parent=environment(study04_jobs))
  # The cloned settings closure resolves its own body in this test environment.
  cases<-study04_cases()[1:2,];cases$M<-c(2L,2L)
  set.seed(778L);before<-.Random.seed;kind<-RNGkind()
  first<-planner(cases);second<-planner(cases)
  testthat::expect_identical(first,second)
  testthat::expect_identical(.Random.seed,before)
  testthat::expect_identical(RNGkind(),kind)
  testthat::expect_length(first,4L)
  testthat::expect_equal(length(unique(vapply(first,function(x)paste(x$data_stream,collapse=';'),character(1)))),4L)
  testthat::expect_equal(length(unique(vapply(first,`[[`,integer(1),'bootstrap_seed'))),4L)
})
