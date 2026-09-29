# Exercise the output validator on an independent M=1, B=7 fixture. This is
# mechanical verification, not an additional calibration-study scenario.
validator_candidates <- c(
  ".", "..", "data-raw/calibration-01", "driftmapR/data-raw/calibration-01",
  "/workspace/scratch/837e4400dd1d/driftmapR/data-raw/calibration-01"
)
validator_source_dir <- validator_candidates[
  file.exists(file.path(validator_candidates, "validate.R"))][1L]
if (is.na(validator_source_dir)) stop("Cannot locate calibration-01/validate.R.")
for (validator_file in c("model.R", "regions.R", "run.R", "validate.R")) {
  source(file.path(validator_source_dir, validator_file), local = TRUE)
}

validator_seed_stream <- function(seed) {
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

validator_fixture_parent <- Sys.getenv("CALIBRATION_VALIDATOR_FIXTURE_DIR", unset = tempdir())
dir.create(validator_fixture_parent, recursive = TRUE, showWarnings = FALSE)
validator_fixture_dir <- tempfile("validator-fixture-", tmpdir = validator_fixture_parent)
dir.create(validator_fixture_dir)
for (engine in c("pca", "cmds")) {
  dir.create(file.path(validator_fixture_dir, "checkpoints", engine), recursive = TRUE)
}
validator_source_names <- c("protocol.md", "model.R", "regions.R", "run.R")
validator_hashes <- tools::md5sum(file.path(validator_source_dir, validator_source_names))
names(validator_hashes) <- validator_source_names
validator_signature <- list(source_md5 = validator_hashes, M = 1L, B = 7L,
  data_seed = 80341L,
  bootstrap_seed_formula = "1400000 + scenario_id * 1000 + dataset_id",
  R = R.version.string, package = as.character(utils::packageVersion("driftmapR")))
saveRDS(validator_signature, file.path(validator_fixture_dir, "frozen-design.rds"))
utils::write.csv(data.frame(file = names(validator_hashes), md5 = unname(validator_hashes)),
  file.path(validator_fixture_dir, "source-hashes-before-run.csv"), row.names = FALSE)
invisible(file.copy(file.path(validator_source_dir, validator_source_names),
                    validator_fixture_dir))

validator_scenarios <- calibration_scenarios()
validator_stream <- validator_seed_stream(80341L)
validator_jobs <- vector("list", nrow(validator_scenarios))
validator_populations <- vector("list", nrow(validator_scenarios))
validator_pca <- validator_mds <- vector("list", nrow(validator_scenarios))
for (s in seq_len(nrow(validator_scenarios))) {
  scenario <- validator_scenarios[s, , drop = FALSE]
  job <- list(scenario_id = s, scenario = scenario$scenario, dataset_id = 1L,
    data_stream = validator_stream, bootstrap_seed = as.integer(1400000L + s * 1000L + 1L))
  validator_jobs[[s]] <- job
  validator_stream <- parallel::nextRNGStream(validator_stream)
  population <- calibration_population(scenario)
  validator_populations[[s]] <- population
  for (engine in c("pca", "cmds")) {
    result <- calibration_one(job, scenario, population, B = 7L, method = engine)
    result$signature <- validator_signature
    saveRDS(result, calibration_job_file(job, validator_fixture_dir, engine))
    if (engine == "pca") validator_pca[[s]] <- result else validator_mds[[s]] <- result
  }
}
names(validator_populations) <- validator_scenarios$scenario
saveRDS(validator_populations, file.path(validator_fixture_dir, "population-targets.rds"))
saveRDS(validator_jobs, file.path(validator_fixture_dir, "seed-plan.rds"))
utils::write.csv(do.call(rbind, lapply(validator_jobs, function(j) data.frame(
  scenario = j$scenario, dataset_id = j$dataset_id, bootstrap_seed = j$bootstrap_seed,
  data_stream = paste(j$data_stream, collapse = ";")))),
  file.path(validator_fixture_dir, "seed-plan.csv"), row.names = FALSE)
validator_exports <- c(outer = "outer-results.csv", estimates = "estimates.csv",
  regions = "regions.csv", attempts = "bootstrap-attempts.csv",
  selected_draws = "bootstrap-vectors.csv")
for (component in names(validator_exports)) {
  utils::write.csv(do.call(rbind, lapply(validator_pca, `[[`, component)),
    file.path(validator_fixture_dir, validator_exports[[component]]),
    row.names = FALSE, na = "NA")
}
validator_maxdiff <- function(x, y) {
  if (is.null(x) && is.null(y)) return(NA_real_)
  if (is.null(x) || is.null(y)) return(Inf)
  max(abs(as.matrix(x) - as.matrix(y)), 0)
}
validator_audits <- do.call(rbind, lapply(seq_along(validator_jobs), function(i) {
  a <- validator_pca[[i]]
  b <- validator_mds[[i]]
  data.frame(scenario = a$job$scenario, dataset_id = a$job$dataset_id,
    observed_agree = identical(a$outer$observed_success, b$outer$observed_success),
    success_ledger_agree = identical(a$attempts$success, b$attempts$success),
    unit_draws_identical = identical(a$unit_counts, b$unit_counts),
    observed_max_abs_diff = validator_maxdiff(a$estimates[c("estimate_dx", "estimate_dy")],
                                              b$estimates[c("estimate_dx", "estimate_dy")]),
    bootstrap_max_abs_diff = validator_maxdiff(a$selected_draws[c("dx", "dy")],
                                               b$selected_draws[c("dx", "dy")]),
    region_decisions_agree = identical(a$regions[c("delivered", "covered", "rejects_zero")],
                                       b$regions[c("delivered", "covered", "rejects_zero")]))
}))
utils::write.csv(validator_audits, file.path(validator_fixture_dir, "pca-mds-audit.csv"),
                 row.names = FALSE, na = "NA")
message("Validator fixture preserved at: ", normalizePath(validator_fixture_dir))

validator_copy_fixture <- function() {
  path <- tempfile("validator-mutation-", tmpdir = validator_fixture_parent)
  dir.create(path)
  ok <- file.copy(list.files(validator_fixture_dir, full.names = TRUE), path,
                  recursive = TRUE)
  if (!all(ok)) stop("Could not copy validator mutation fixture.")
  path
}
validator_edit_csv <- function(path, name, edit) {
  destination <- file.path(path, name)
  input <- utils::read.csv(destination, stringsAsFactors = FALSE, check.names = FALSE)
  utils::write.csv(edit(input), destination, row.names = FALSE, na = "NA")
}
validator_run <- function(path) {
  calibration_validate_outputs(path, expected_M = 1L, expected_B = 7L,
                               stop_on_failure = FALSE)
}
validator_expect_failed <- function(result, name) {
  testthat::expect_true(name %in% result$check, info = name)
  testthat::expect_false(result$passed[match(name, result$check)], info = name)
}

testthat::test_that("the independent six-scenario bundle passes every mechanical check", {
  result <- validator_run(validator_fixture_dir)
  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_true(all(result$passed),
                        info = paste(result$check[!result$passed], collapse = "; "))
  testthat::expect_identical(anyDuplicated(result$check), 0L)
  testthat::expect_true(file.exists(file.path(validator_fixture_dir, "mechanical-validation.csv")))
  testthat::expect_true(file.exists(file.path(validator_fixture_dir, "denominator-audit.csv")))
  denominators <- utils::read.csv(file.path(validator_fixture_dir, "denominator-audit.csv"))
  testthat::expect_identical(nrow(denominators), 108L)
  testthat::expect_true(all(denominators$n_outer == 1L))
  testthat::expect_true(all(denominators$n_delivered == 0L))
  testthat::expect_true(all(is.na(denominators$conditional_coverage)))
  testthat::expect_true(all(denominators$coverage_delivery_yield == 0))
  testthat::expect_true(all(denominators$delivery_fraction == 0))
  testthat::expect_no_error(calibration_validate_outputs(validator_fixture_dir,
    expected_M = 1L, expected_B = 7L, stop_on_failure = TRUE))
})

testthat::test_that("wrong attempt budgets cannot pass accounting validation", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "outer-results.csv", function(x) {
    x$n_attempted[1L] <- x$n_attempted[1L] - 1L
    x
  })
  result <- validator_run(path)
  validator_expect_failed(result, "success_failure_conservation")
  validator_expect_failed(result, "exact_B_for_completed_bootstrap_calls")
  testthat::expect_error(calibration_validate_outputs(path, expected_M = 1L,
    expected_B = 7L, stop_on_failure = TRUE), "mechanical validation checks failed")
})

testthat::test_that("duplicate bootstrap attempt IDs are detected explicitly", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "bootstrap-attempts.csv", function(x) {
    rows <- which(x$scenario == "regular_null")
    x$replicate_id[rows[2L]] <- x$replicate_id[rows[1L]]
    x
  })
  result <- validator_run(path)
  validator_expect_failed(result, "bootstrap_attempt_keys_unique")
  validator_expect_failed(result, "regular_null-001:exact_attempt_ids")
})

testthat::test_that("vectors attached to failed attempts cannot masquerade as valid resamples", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "bootstrap-attempts.csv", function(x) {
    row <- which(x$scenario == "regular_null" & x$success)[1L]
    x$success[row] <- FALSE
    x$stage[row] <- "embedding"
    x$message[row] <- "Injected validation fixture failure."
    x
  })
  result <- validator_run(path)
  validator_expect_failed(result, "regular_null-001:no_failed_vector_imputation")
  validator_expect_failed(result, "regular_null-001:ledger_conservation")
})

testthat::test_that("delivery cannot bypass the declared count and geometry gates", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "regions.csv", function(x) {
    x$gate_passed[1L] <- TRUE
    x$delivered[1L] <- TRUE
    x$covered[1L] <- TRUE
    x$rejects_zero[1L] <- FALSE
    x
  })
  result <- validator_run(path)
  validator_expect_failed(result, "delivery_requires_geometry_and_gate")
  testthat::expect_true(any(!result$passed & grepl("region_reconstruction", result$check)))
})

testthat::test_that("undelivered records cannot contribute false coverage outcomes", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "regions.csv", function(x) {
    x$covered[1L] <- TRUE
    x$rejects_zero[1L] <- FALSE
    x
  })
  result <- validator_run(path)
  validator_expect_failed(result, "undelivered_coverage_is_missing")
  validator_expect_failed(result, "independent_denominator_grid")
})

testthat::test_that("missing delivery flags produce a failed check instead of a validator crash", {
  path <- validator_copy_fixture()
  validator_edit_csv(path, "regions.csv", function(x) {
    x$delivered[1L] <- NA
    x
  })
  result <- validator_run(path)
  testthat::expect_s3_class(result, "data.frame")
  testthat::expect_true(any(!result$passed & grepl("flag|missing|complete", result$check)))
  testthat::expect_true(file.exists(file.path(path, "mechanical-validation.csv")))
})

testthat::test_that("tampering with a frozen source copy invalidates its hash", {
  path <- validator_copy_fixture()
  cat("\n# Injected source-tampering fixture.\n", file = file.path(path, "protocol.md"), append = TRUE)
  result <- validator_run(path)
  validator_expect_failed(result, "frozen_source_copies_match_hashes")
  testthat::expect_true(result$passed[match("source_hash_manifest_matches_freeze", result$check)])
})
