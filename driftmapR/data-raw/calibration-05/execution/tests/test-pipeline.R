testthat::test_that('engineering pipeline collects validates audits and renders frozen analyses', {
  fixture <- study05_fixture(17L, B = 21L)
  result <- study05_one(fixture$job, fixture$case, generated = fixture$generated,
    keep_inner_values = TRUE)
  result$mechanical_validation <- study05_validate_result(result)
  result$audit <- study05_public_audit(result, fixture$generated)
  testthat::expect_true(all(result$audit$passed))
  directory <- tempfile('study05-complete-pipeline-'); dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  checkpoint <- file.path(directory, 'fixture.rds')
  identity <- list(scope = 'engineering-only complete pipeline', seed = 779L)
  study05_checkpoint_save(result, checkpoint, identity)
  output <- file.path(directory, 'collected')
  tables <- study05_collect(checkpoint, list(fixture$job), identity, output,
    evaluation = FALSE)
  testthat::expect_equal(nrow(tables$outer), 2L)
  testthat::expect_equal(nrow(tables$regions), 30L)
  testthat::expect_equal(tables$caseplan$M, 1L)
  testthat::expect_error(study05_collect(rep(checkpoint, 2L),
    rep(list(fixture$job), 2L), identity, output, evaluation = FALSE), 'duplicate')
  testthat::expect_error(study05_collect(checkpoint, list(fixture$job),
    identity, output, evaluation = TRUE), 'entire untouched')
  for (frame in c('core', 'frame')) {
    attempts <- read.csv(gzfile(file.path(output, frame, 'attempts.csv.gz')))
    pivots <- read.csv(gzfile(file.path(output, frame, 'studentization.csv.gz')))
    testthat::expect_equal(nrow(attempts), 21L)
    testthat::expect_equal(nrow(pivots), 63L)
  }
  analysis <- file.path(directory, 'analysis')
  study05_analyze(tables, analysis, figures = TRUE, allow_fixture = TRUE)
  files <- list.files(analysis, recursive = TRUE, full.names = TRUE)
  testthat::expect_true(any(grepl('\\.pdf$', files)))
  testthat::expect_true(all(file.info(files)$size > 0))
  testthat::expect_identical(study05_checkpoint_read(checkpoint, identity, fixture$job), result)
})
