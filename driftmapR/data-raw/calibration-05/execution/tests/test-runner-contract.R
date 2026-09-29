# Engineering infrastructure fixtures only: no reserved measurement generation.
# These tests independently exercise the runner's storage and scheduling boundary.

study05_runner_test_dir <- function() {
  path <- tempfile('study05-runner-fixture-')
  dir.create(path, recursive = TRUE)
  path
}

study05_runner_test_payload <- function() {
  fixture <- study05_fixture(1L, B = 2L, generate = FALSE)
  list(job = fixture$job, case = fixture$case,
       engineering_only = TRUE, content = matrix(seq_len(6L), 3L, 2L))
}

study05_runner_test_identity <- function() {
  list(study = 'Study05 engineering checkpoint fixture',
       implementation = 'engineering-hash-A', design = 'immutable-design-A',
       engine = study05_settings()$engine_version)
}

testthat::test_that('atomic checkpoints round-trip and retain complete fixture identity', {
  directory <- study05_runner_test_dir()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, 'checkpoint.rds')
  payload <- study05_runner_test_payload()
  identity <- study05_runner_test_identity()
  study05_checkpoint_save(payload, path, identity)
  testthat::expect_true(file.exists(path))
  testthat::expect_identical(study05_checkpoint_read(path, identity, payload$job), payload)
  # A completed checkpoint is reused by verification, never silently overwritten.
  testthat::expect_error(study05_checkpoint_save(payload, path, identity))
  testthat::expect_identical(study05_checkpoint_read(path, identity, payload$job), payload)
})

testthat::test_that('resume rejects changed source, plan, job and complete RNG state', {
  directory <- study05_runner_test_dir()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, 'checkpoint.rds')
  payload <- study05_runner_test_payload()
  identity <- study05_runner_test_identity()
  study05_checkpoint_save(payload, path, identity)
  for (field in c('implementation', 'design', 'engine')) {
    changed <- identity
    changed[[field]] <- paste0(changed[[field]], '-different')
    testthat::expect_error(study05_checkpoint_read(path, changed, payload$job))
  }
  for (field in c('case_id', 'dataset_id', 'm', 'bootstrap_seed')) {
    job <- payload$job
    job[[field]] <- if (is.character(job[[field]])) paste0(job[[field]], '-different') else job[[field]] + 1L
    testthat::expect_error(study05_checkpoint_read(path, identity, job))
  }
  # Preserve the RNG-kind word and mutate a later state word; matching only the
  # scalar bootstrap seed or the first data-stream word is insufficient.
  changed_job <- payload$job
  changed_job$data_stream[3L] <- changed_job$data_stream[3L] + 1L
  testthat::expect_error(study05_checkpoint_read(path, identity, changed_job))
  testthat::expect_identical(study05_checkpoint_read(path, identity, payload$job), payload)
})

testthat::test_that('content corruption is rejected before a checkpoint can be reused', {
  directory <- study05_runner_test_dir()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, 'checkpoint.rds')
  payload <- study05_runner_test_payload()
  identity <- study05_runner_test_identity()
  study05_checkpoint_save(payload, path, identity)
  # A readable RDS with unchanged job metadata must still fail the content hash.
  tampered <- readRDS(path)
  tampered$unapproved_change <- 'readable but changed bytes'
  saveRDS(tampered, path)
  testthat::expect_error(study05_checkpoint_read(path, identity, payload$job))
  # Entirely invalid serialization is also infrastructure failure, never a
  # synthetic observed-fit failure row or an automatically replaced panel.
  writeBin(charToRaw('interrupted RDS write'), path)
  testthat::expect_error(study05_checkpoint_read(path, identity, payload$job))
})

testthat::test_that('stale partial payloads are preserved with their bytes intact', {
  directory <- study05_runner_test_dir()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  path <- file.path(directory, 'checkpoint.rds')
  partial <- paste0(path, '.tmp')
  bytes <- charToRaw('incomplete engineering-only payload: do not erase')
  writeBin(bytes, partial)
  partial_hash <- unname(tools::md5sum(partial))
  study05_preserve_incident(partial, 'stale_partial',
    'Engineering interruption fixture; lost CPU work is unknown.')
  candidates <- list.files(directory, full.names = TRUE, recursive = TRUE, all.files = TRUE)
  candidates <- candidates[!file.info(candidates)$isdir]
  hashes <- unname(tools::md5sum(candidates))
  testthat::expect_true(partial_hash %in% hashes)
  # A preserved partial is not itself a completed, reusable checkpoint.
  testthat::expect_false(file.exists(path))
  payload <- study05_runner_test_payload()
  identity <- study05_runner_test_identity()
  study05_checkpoint_save(payload, path, identity)
  testthat::expect_identical(study05_checkpoint_read(path, identity, payload$job), payload)
  candidates <- list.files(directory, full.names = TRUE, recursive = TRUE, all.files = TRUE)
  candidates <- candidates[!file.info(candidates)$isdir]
  testthat::expect_true(partial_hash %in% unname(tools::md5sum(candidates)))
})

testthat::test_that('execution requires a complete implementation freeze', {
  directory <- study05_runner_test_dir()
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  testthat::expect_error(study05_verify_freezes(directory))
})

testthat::test_that('outer schedules preserve explicit engineering stream results', {
  # All jobs use the allowed seed779/dataset999 fixture. They are lightweight
  # scheduling probes, not altered scientific panels or evaluation replicates.
  fixture <- study05_fixture(1L, B = 2L, generate = FALSE)
  jobs <- lapply(seq_len(4L), function(i) list(index = i, fixture = fixture$job))
  work <- function(job) study05_preserve_rng({
    RNGkind("L'Ecuyer-CMRG", 'Inversion', 'Rejection')
    assign('.Random.seed', job$fixture$data_stream, envir = .GlobalEnv)
    list(index = job$index, stream = job$fixture$data_stream,
         value = stats::rnorm(7L) * job$index)
  })
  serial <- study05_execute_jobs(jobs, work, workers = 1L)
  parallel <- study05_execute_jobs(jobs, work, workers = 2L)
  testthat::expect_identical(parallel, serial)
  testthat::expect_identical(vapply(serial, `[[`, integer(1), 'index'), seq_len(4L))
  testthat::expect_error(study05_execute_jobs(jobs, work, workers = 0L))
  testthat::expect_error(study05_execute_jobs(jobs, work, workers = 9L))
})

testthat::test_that('worker exceptions remain infrastructure errors', {
  work <- function(job) {
    if (job == 2L) stop('engineering injected storage interruption')
    list(job = job, status = 'completed')
  }
  testthat::expect_error(study05_execute_jobs(as.list(1:3), work, workers = 1L))
  # mclapply may emit a platform warning when a worker raises an error. The
  # wrapper must still reject the batch and cannot convert that error to a fit.
  testthat::expect_error(suppressWarnings(study05_execute_jobs(as.list(1:3), work, workers = 2L)))
})

testthat::test_that('pre-materialized fixture draws match generated feature and unit designs', {
  for (index in c(1L, 27L, 31L)) {
    fixture <- study05_fixture(index, B = 3L)
    planned <- study05_materialize_draws(fixture$job, fixture$case)
    g <- fixture$generated
    design <- driftmapR::paired_unit_design(g$unit_map,
      assumptions = planned$assumptions)
    independently <- getFromNamespace('bootstrap_draw_plan', 'driftmapR')(
      design, g$features, 3L, fixture$job$bootstrap_seed)
    weights <- do.call(rbind, lapply(independently$draws,
      function(d) d$feature_weights[g$features]))
    streams <- do.call(rbind, lapply(independently$draws, `[[`, 'rng_stream'))
    testthat::expect_identical(planned$job, fixture$job)
    testthat::expect_identical(planned$weights, weights)
    testthat::expect_identical(planned$streams, streams)
    testthat::expect_equal(rowSums(planned$weights), rep(fixture$case$m, 3L))
    testthat::expect_true(all(planned$weights >= 0 & planned$weights == floor(planned$weights)))
    if (fixture$case$rho_unit > 0) {
      testthat::expect_match(planned$assumptions, 'misspecified|misspecification')
      testthat::expect_false(grepl('simulation generates iid', planned$assumptions, fixed = TRUE))
    }
  }
})
