# Small, independent jobs only: dataset 999 and scalar seed 42 are outside the
# frozen 480-dataset study plan. This file never invokes calibration_main().
runner_candidates <- c(
  ".", "..", "data-raw/calibration-01", "driftmapR/data-raw/calibration-01",
  "/workspace/scratch/837e4400dd1d/driftmapR/data-raw/calibration-01"
)
runner_source_dir <- runner_candidates[file.exists(file.path(runner_candidates, "run.R"))][1L]
if (is.na(runner_source_dir)) stop("Cannot locate calibration-01/run.R.")
for (runner_file in c("model.R", "regions.R", "run.R")) {
  source(file.path(runner_source_dir, runner_file), local = TRUE)
}

runner_stream <- function(seed) {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(seed)
  get(".Random.seed", envir = .GlobalEnv)
}

runner_scenario <- calibration_scenarios()[2L, , drop = FALSE]
runner_job <- list(scenario_id = 2L, scenario = "regular_movement",
                   dataset_id = 999L, data_stream = runner_stream(42L),
                   bootstrap_seed = 1499999L)
runner_population <- calibration_population(runner_scenario)
runner_result <- calibration_one(runner_job, runner_scenario, runner_population, B = 7L)

testthat::test_that("runner sources safely without launching the study", {
  isolated <- new.env(parent = globalenv())
  testthat::expect_no_error(source(file.path(runner_source_dir, "run.R"), local = isolated))
  testthat::expect_true(is.function(isolated$calibration_one))
  testthat::expect_true(is.function(isolated$calibration_main))
  testthat::expect_false(exists("jobs", envir = isolated, inherits = FALSE))
})

testthat::test_that("the seven-attempt audit preserves all attempted IDs and failure accounting", {
  x <- runner_result
  testthat::expect_true(x$outer$observed_success)
  testthat::expect_true(x$outer$bootstrap_started)
  testthat::expect_false(x$outer$bootstrap_error)
  testthat::expect_identical(x$outer$n_attempted, 7L)
  testthat::expect_identical(x$outer$n_valid + x$outer$n_failed, 7L)
  testthat::expect_identical(nrow(x$attempts), 7L)
  testthat::expect_identical(x$attempts$replicate_id, seq_len(7L))
  testthat::expect_identical(anyDuplicated(x$attempts$replicate_id), 0L)
  testthat::expect_equal(sum(x$attempts$success), x$outer$n_valid)
  testthat::expect_equal(sum(!x$attempts$success), x$outer$n_failed)
  testthat::expect_equal(x$outer$success_rate, mean(x$attempts$success))
  testthat::expect_equal(dim(x$unit_counts), c(7L, 40L))
  testthat::expect_equal(unname(rowSums(x$unit_counts)), rep(40, 7L))
  testthat::expect_equal(dim(x$draw_streams), c(7L, 7L))
  testthat::expect_identical(anyDuplicated(as.data.frame(x$draw_streams)), 0L)
})

testthat::test_that("small B retains eighteen explicit unavailable region records", {
  x <- runner_result
  testthat::expect_false(x$outer$passes_gate)
  testthat::expect_false(any(x$estimates$passes_gate))
  testthat::expect_identical(nrow(x$regions), 18L)
  testthat::expect_setequal(x$regions$entity, c("E015", "E003", "E006"))
  testthat::expect_setequal(x$regions$method,
                           c("wald", "bootstrap_mahalanobis", "bootstrap_ball"))
  testthat::expect_setequal(x$regions$policy, c("relaxed", "production"))
  keys <- paste(x$regions$entity, x$regions$method, x$regions$policy)
  testthat::expect_identical(anyDuplicated(keys), 0L)
  testthat::expect_false(any(x$regions$region_computable))
  testthat::expect_false(any(x$regions$gate_passed))
  testthat::expect_false(any(x$regions$delivered))
  testthat::expect_identical(x$regions$reason, rep("insufficient_valid", 18L))
  testthat::expect_true(all(is.na(x$regions$covered)))
  testthat::expect_true(all(is.na(x$regions$rejects_zero)))
  testthat::expect_equal(x$regions$n_valid, rep(x$outer$n_valid, 18L))
})

testthat::test_that("selected draws have exactly the three prespecified target entities per success", {
  x <- runner_result
  success_ids <- x$attempts$replicate_id[x$attempts$success]
  testthat::expect_equal(nrow(x$selected_draws), 3L * length(success_ids))
  testthat::expect_setequal(x$selected_draws$replicate_id, success_ids)
  testthat::expect_setequal(x$selected_draws$entity, c("E015", "E003", "E006"))
  testthat::expect_identical(anyDuplicated(paste(x$selected_draws$replicate_id,
                                                x$selected_draws$entity)), 0L)
  for (id in success_ids) {
    testthat::expect_setequal(x$selected_draws$entity[x$selected_draws$replicate_id == id],
                             c("E015", "E003", "E006"))
  }
})

testthat::test_that("one independent observed-baseline gauge rotates estimates and every bootstrap vector", {
  generated <- calibration_generate(runner_scenario, runner_job$data_stream)
  fit <- driftmapR::embed_snapshots(generated$data, generated$features,
    method = "pca", periods = 1:2, standardize = "none")
  fit <- driftmapR::align_snapshots(fit, reference = "previous", scale = FALSE,
                                  anchors = generated$layout$anchors)
  design <- driftmapR::paired_unit_design(generated$unit_map,
    assumptions = "Independent simulation units paired across entities and periods.")
  direct <- suppressWarnings(driftmapR::bootstrap_drift(fit, design, B = 7L,
    seed = runner_job$bootstrap_seed, min_success = 0.95, keep = "replicates"))
  # This calculation deliberately does not call calibration_gauge_rotation().
  # It fits only the observed baseline once; each bootstrap vector uses that R.
  source <- fit$aligned[fit$aligned$period_index == 1L, ]
  target <- runner_population$object$aligned[
    runner_population$object$aligned$period_index == 1L, ]
  ids <- generated$layout$anchors
  source_xy <- as.matrix(source[match(ids, source$entity), c("x", "y")])
  target_xy <- as.matrix(target[match(ids, target$entity), c("x", "y")])
  source_centered <- sweep(source_xy, 2L, colMeans(source_xy), "-")
  target_centered <- sweep(target_xy, 2L, colMeans(target_xy), "-")
  decomposition <- svd(crossprod(source_centered, target_centered))
  rotation <- decomposition$u %*% t(decomposition$v)
  testthat::expect_equal(unname(runner_result$gauge_rotation), unname(rotation),
                        tolerance = 1e-12)
  movement <- driftmapR::measure_drift(fit)
  movement <- movement[match(runner_result$estimates$entity, movement$entity), ]
  expected_estimates <- as.matrix(movement[c("dx", "dy")]) %*% rotation
  testthat::expect_equal(unname(as.matrix(runner_result$estimates[c("estimate_dx", "estimate_dy")])),
                        unname(expected_estimates), tolerance = 1e-12)
  direct_draws <- direct$bootstrap$replicates
  direct_key <- paste(direct_draws$replicate_id, direct_draws$entity)
  selected_key <- paste(runner_result$selected_draws$replicate_id,
                         runner_result$selected_draws$entity)
  direct_draws <- direct_draws[match(selected_key, direct_key), ]
  expected_vectors <- as.matrix(direct_draws[c("dx", "dy")]) %*% rotation
  testthat::expect_equal(unname(as.matrix(runner_result$selected_draws[c("dx", "dy")])),
                        unname(expected_vectors), tolerance = 1e-12)
  # Candidate covariance is retained even though seven draws cannot pass gates.
  for (entity in generated$layout$target_ids) {
    covariance <- stats::cov(expected_vectors[direct_draws$entity == entity, , drop = FALSE])
    rows <- runner_result$regions[runner_result$regions$entity == entity, ]
    testthat::expect_equal(rows$var_dx, rep(covariance[1L, 1L], 6L), tolerance = 1e-12)
    testthat::expect_equal(rows$var_dy, rep(covariance[2L, 2L], 6L), tolerance = 1e-12)
    testthat::expect_equal(rows$cov_dx_dy, rep(covariance[1L, 2L], 6L), tolerance = 1e-12)
  }
  expected_counts <- do.call(rbind, lapply(direct$bootstrap$draws, `[[`, "unit_counts"))
  expected_streams <- do.call(rbind, lapply(direct$bootstrap$draws, `[[`, "rng_stream"))
  testthat::expect_identical(unname(runner_result$unit_counts), unname(expected_counts))
  testthat::expect_identical(unname(runner_result$draw_streams), unname(expected_streams))
  testthat::expect_identical(runner_result$attempts$success, direct$bootstrap$attempts$success)
  testthat::expect_identical(runner_result$attempts$replicate_id,
                            direct$bootstrap$attempts$replicate_id)
})

testthat::test_that("repeated audit jobs reproduce all statistical outputs and recorded streams", {
  repeated <- calibration_one(runner_job, runner_scenario, runner_population, B = 7L)
  for (name in c("job", "estimates", "regions", "selected_draws", "attempts",
                  "unit_counts", "draw_streams", "gauge_rotation")) {
    testthat::expect_identical(repeated[[name]], runner_result[[name]], info = name)
  }
  fields <- setdiff(names(repeated$outer), c("elapsed_seconds", "retained_bytes"))
  testthat::expect_identical(repeated$outer[fields], runner_result$outer[fields])
})

testthat::test_that("a rare-axis dataset with no rare units retains observed-fit failure records", {
  scenario <- calibration_scenarios()[5L, , drop = FALSE]
  chosen_stream <- NULL
  # Bounded deterministic search, separate from master seed 260915 and all study
  # dataset IDs. No study outcomes are used to choose this failure-path fixture.
  for (seed in seq_len(200L)) {
    stream <- runner_stream(seed)
    generated <- calibration_generate(scenario, stream)
    if (generated$rare_count == 0L) {
      chosen_stream <- stream
      break
    }
  }
  testthat::expect_false(is.null(chosen_stream))
  job <- list(scenario_id = 5L, scenario = "rare_axis", dataset_id = 999L,
              data_stream = chosen_stream, bootstrap_seed = 1499999L)
  failed <- calibration_one(job, scenario, calibration_population(scenario), B = 7L)
  testthat::expect_equal(failed$outer$rare_count, 0L)
  testthat::expect_false(failed$outer$observed_success)
  testthat::expect_identical(failed$outer$failure_stage, "observed_fit")
  testthat::expect_gt(nchar(failed$outer$message), 0L)
  testthat::expect_false(failed$outer$bootstrap_started)
  testthat::expect_false(failed$outer$bootstrap_error)
  testthat::expect_identical(failed$outer$n_attempted, 0L)
  testthat::expect_identical(failed$outer$n_valid, 0L)
  testthat::expect_identical(failed$outer$n_failed, 0L)
  testthat::expect_null(failed$attempts)
  testthat::expect_null(failed$selected_draws)
  testthat::expect_null(failed$estimates)
  testthat::expect_null(failed$unit_counts)
  testthat::expect_identical(nrow(failed$regions), 18L)
  testthat::expect_identical(failed$regions$reason, rep("observed_fit_failed", 18L))
  testthat::expect_false(any(failed$regions$region_computable))
  testthat::expect_false(any(failed$regions$gate_passed))
  testthat::expect_false(any(failed$regions$delivered))
  testthat::expect_true(all(is.na(failed$regions$covered)))
  testthat::expect_true(all(is.na(failed$regions$rejects_zero)))
})
