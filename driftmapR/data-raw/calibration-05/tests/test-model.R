testthat::test_that("the bounded case-major design has exact planned counts and labels", {
  cases <- study05_cases(); s <- study05_settings()
  testthat::expect_equal(nrow(cases), 31L)
  testthat::expect_equal(sum(cases$M), 1640L)
  testthat::expect_equal(sum(cases$M * cases$B), 326360L)
  testthat::expect_identical(cases$case_index, 1:31)
  testthat::expect_false(anyDuplicated(cases$case_id) > 0)
  testthat::expect_equal(sum(cases$M[cases$role == "null_reference"]), 360L)
  testthat::expect_equal(sum(cases$M[cases$role == "anchor_change"]), 720L)
  testthat::expect_equal(sum(cases$M[cases$role == "movement_control"]), 320L)
  testthat::expect_equal(sum(cases$M[cases$role == "dependence_stress"]), 160L)
  testthat::expect_equal(sum(cases$M[cases$role == "sparse_unit_control"]), 80L)
  testthat::expect_true(all(cases$g[!is.na(cases$g)] > 0))
  testthat::expect_equal(cases$g, cases$signal_gap_fraction)
  testthat::expect_true(all(cases$target_regime[cases$a > 0 & !cases$focal_motion] == "anchor_change"))
  testthat::expect_true(all(cases$contract[cases$rho_unit > 0] == "dependence_stress_outside_iid_contract"))
  testthat::expect_true(all(cases$contract[cases$rho_unit == 0] == "iid_units_nominal_contract"))
  testthat::expect_identical(s$targets, c("E015", "E003", "E006"))
  testthat::expect_equal(s$B, 199L)
})

testthat::test_that("stream reservation restores caller RNG and preserves subset positions", {
  set.seed(108L); before <- .Random.seed; kind <- RNGkind()
  jobs <- study05_jobs()
  testthat::expect_identical(.Random.seed, before)
  testthat::expect_identical(RNGkind(), kind)
  testthat::expect_length(jobs, 1640L)
  testthat::expect_identical(jobs[[1L]]$data_stream, study05_seed_state(261003L))
  testthat::expect_identical(jobs[[2L]]$data_stream, parallel::nextRNGStream(jobs[[1L]]$data_stream))
  testthat::expect_identical(jobs[[1L]]$bootstrap_seed, 5410001L)
  testthat::expect_identical(jobs[[1640L]]$bootstrap_seed, 5710080L)
  testthat::expect_equal(length(unique(vapply(jobs, function(j) paste(j$data_stream, collapse = ","), ""))), 1640L)
  testthat::expect_equal(length(unique(vapply(jobs, `[[`, integer(1L), "bootstrap_seed"))), 1640L)
  selected <- study05_jobs(study05_cases()[c(31L, 2L), , drop = FALSE])
  testthat::expect_identical(selected, jobs[vapply(jobs, function(j) j$case_index %in% c(2L, 31L), logical(1L))])
  testthat::expect_true(all(vapply(jobs, function(j) identical(j$stage,
    study05_settings()$evaluation_stage), logical(1L))))
  testthat::expect_error(study05_generate(jobs[[1L]], study05_cases()[1L, , drop = FALSE]), "locked")
})

testthat::test_that("reservation and fixtures preserve an absent random seed", {
  kind <- RNGkind(); had <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had) old <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({do.call(RNGkind, as.list(kind)); if (had) assign(".Random.seed", old, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)}, add = TRUE)
  if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  invisible(study05_jobs(study05_cases()[1L, , drop = FALSE]))
  testthat::expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  invisible(study05_fixture())
  testthat::expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  testthat::expect_identical(RNGkind(), kind)
})

testthat::test_that("baseline eigengap construction preserves original axes and expected Gram", {
  cases <- study05_cases()
  for (g in c(1, .1, .01)) {
    case <- cases[cases$g == g & cases$a == 0 & cases$m == 40 &
      cases$role == "null_reference" & !is.na(cases$g), , drop = FALSE]
    model <- study05_model(case)
    z <- model$layout$latent[[1L]]; v <- model$population_eigenvalues[[1L]]
    signal <- model$baseline_signal_eigenvalues
    testthat::expect_equal(z[, 1:2], model$original_rank2_layout, tolerance = 1e-13)
    testthat::expect_equal(sum(model$auxiliary_direction^2), 1, tolerance = 1e-13)
    testthat::expect_equal(as.numeric(crossprod(cbind(1, z[, 1:2]), model$auxiliary_direction)), rep(0, 3L), tolerance = 1e-13)
    testthat::expect_true(model$auxiliary_direction[which.max(abs(model$auxiliary_direction))] > 0)
    testthat::expect_equal(v[1:3], c(signal[1L], signal[2L], (1 - g) * signal[2L]) + .25^2,
                           tolerance = 1e-12)
    testthat::expect_equal(v[2L] - v[3L], g * signal[2L], tolerance = 1e-12)
    testthat::expect_equal(model$population_grams[[1L]], tcrossprod(z) + .25^2 * model$H,
                           tolerance = 1e-13)
    testthat::expect_equal(model$population_grams[[1L]], model$population_grams[[2L]], tolerance = 0)
    testthat::expect_equal(unname(model$truth), matrix(0, 3L, 2L), tolerance = 1e-12)
    testthat::expect_equal(unname(model$truth_clean), matrix(0, 3L, 2L), tolerance = 1e-12)
    testthat::expect_equal(model$population_gaps$relative_gap_lambda2,
      model$population_gaps$boundary_gap / model$population_gaps$lambda2, tolerance = 0)
  }
})

testthat::test_that("all planned populations have finite declared and clean reference targets", {
  cases <- study05_cases()
  models <- lapply(seq_len(nrow(cases)), function(i) study05_model(cases[i, , drop = FALSE]))
  testthat::expect_true(all(vapply(models, `[[`, logical(1L), "population_target_identified")))
  testthat::expect_true(all(vapply(models, function(m) all(is.finite(m$truth)) &&
    all(is.finite(m$truth_clean)), logical(1L))))
  testthat::expect_true(all(vapply(models, function(m) length(m$anchors) == 11L &&
    length(m$clean_anchors) == 8L, logical(1L))))
  testthat::expect_true(all(vapply(models, function(m) all(m$anchor_diagnostics$rank == 2L), logical(1L))))
  testthat::expect_true(all(vapply(models, function(m) all(m$anchor_registration_diagnostics$cross_rank == 2L) &&
    all(is.finite(m$anchor_registration_diagnostics$cross_condition)), logical(1L))))
  testthat::expect_true(all(vapply(models, function(m) all(m$population_gaps$boundary_gap > 0), logical(1L))))
  testthat::expect_true(all(vapply(models, function(m) identical(m$clean_anchor_ids,
    c("E001", "E003", "E005", "E007", "E009", "E010", "E011", "E012")), logical(1L))))
  for (m in models) {
    testthat::expect_equal(m$truth_declared_minus_clean, m$truth - m$truth_clean, tolerance = 0)
    testthat::expect_equal(m$truth, m$population_fit$displacement[m$target_rows, , drop = FALSE], tolerance = 0)
    testthat::expect_equal(m$truth_clean, m$population_fit_clean$displacement[m$target_rows, , drop = FALSE], tolerance = 0)
  }
})

testthat::test_that("contamination strength uses a fixed rank-two RMS independent of gap", {
  cases <- study05_cases(); candidates <- cases[cases$a == .5 & !cases$focal_motion & cases$m == 40L, , drop = FALSE]
  models <- lapply(seq_len(nrow(candidates)), function(i) study05_model(candidates[i, , drop = FALSE]))
  testthat::expect_equal(length(unique(vapply(models, `[[`, numeric(1L), "contamination_rms"))), 1L)
  for (model in models) {
    raw_change <- matrix(0, length(model$ids), 3L, dimnames = list(model$ids, c("x", "y", "z")))
    raw_change[study05_settings()$contaminated_ids, ] <- matrix(
      rep(.5 * model$contamination_rms * c(.6, -.8, 0), each = 3L), 3L, 3L)
    testthat::expect_equal(model$layout$latent[[2L]] - model$layout$latent[[1L]],
      model$H %*% raw_change, tolerance = 1e-12)
    testthat::expect_true(max(abs(model$truth_declared_minus_clean)) > .01)
    testthat::expect_false(isTRUE(all.equal(model$truth, matrix(0, 3L, 2L))))
  }
})

testthat::test_that("focal motion remains fixed in original coordinate axes", {
  cases <- study05_cases()
  for (idx in which(cases$role == "movement_control")) {
    model <- study05_model(cases[idx, , drop = FALSE])
    raw <- matrix(0, 18L, 3L, dimnames = list(model$ids, c("x", "y", "z")))
    raw["E006", ] <- c(.09, -.06, 0)
    raw[13:18, ] <- matrix(rep(c(-.11, .08, 0), each = 6L), 6L, 3L)
    raw[study05_settings()$contaminated_ids, ] <- matrix(rep(
      cases$a[idx] * model$contamination_rms * c(.6, -.8, 0), each = 3L), 3L, 3L)
    testthat::expect_equal(model$layout$latent[[2L]] - model$layout$latent[[1L]],
      model$H %*% raw, tolerance = 1e-12)
    testthat::expect_true(sqrt(sum(model$truth["E015", ]^2)) > 0)
  }
})

testthat::test_that("an exact boundary tie is analytic-only and has no forced target", {
  case <- study05_cases()[1L, , drop = FALSE]
  case$g <- case$signal_gap_fraction <- 0
  testthat::expect_error(study05_model(case), "differs")
  boundary <- study05_model(case, boundary_fixture = TRUE)
  testthat::expect_false(boundary$population_target_identified)
  testthat::expect_identical(boundary$population_target_status, "boundary_plane_unidentified")
  testthat::expect_null(boundary$population_points)
  testthat::expect_null(boundary$population_fit)
  testthat::expect_true(all(is.na(boundary$truth)))
  testthat::expect_equal(boundary$population_gaps$boundary_gap, c(0, 0), tolerance = 1e-12)
  testthat::expect_error(study05_jobs(case), "differs")
})

testthat::test_that("AR1 recursion preserves the specified stationary covariance algebra", {
  eps <- matrix(c(2, -1, 3, 4, 5, 6), 2L, 3L)
  expected <- eps
  expected[, 2L] <- .5 * eps[, 1L] + sqrt(.75) * eps[, 2L]
  expected[, 3L] <- .5 * expected[, 2L] + sqrt(.75) * eps[, 3L]
  testthat::expect_equal(study05_ar1_units(eps, .5), expected, tolerance = 0)
  testthat::expect_identical(study05_ar1_units(eps, 0), eps)
  # Each row of identity innovations maps to one independent innovation's
  # contribution; crossprod therefore gives the exact, non-Monte-Carlo law.
  transform <- study05_ar1_units(diag(6L), .5)
  covariance <- crossprod(transform)
  testthat::expect_equal(covariance, outer(1:6, 1:6, function(i, j) .5^abs(i-j)), tolerance = 1e-14)
  testthat::expect_equal(.6^2 * covariance + (1 - .6^2) * covariance, covariance, tolerance = 1e-14)
  testthat::expect_error(study05_ar1_units(eps, 1), "AR")
  testthat::expect_error(study05_ar1_units(matrix(NA_real_, 1L, 1L), .5), "AR")
})

testthat::test_that("engineering fixtures reproduce their innovations without consuming caller RNG", {
  set.seed(109L); before <- .Random.seed; kind <- RNGkind()
  for (idx in c(1L, 18L, 27L)) {
    f <- study05_fixture(idx); again <- study05_fixture(idx)
    g <- f$generated; rho <- f$case$rho_unit
    testthat::expect_identical(g, again$generated)
    testthat::expect_identical(.Random.seed, before)
    testthat::expect_identical(RNGkind(), kind)
    testthat::expect_equal(g$loadings, study05_ar1_units(g$innovations$loadings, rho), tolerance = 0)
    testthat::expect_equal(g$noise[[2L]], .6 * g$noise[[1L]] + .8 *
      study05_ar1_units(g$innovations$noise_second, rho), tolerance = 1e-14)
    testthat::expect_equal(dim(g$data), c(36L, f$case$m + 2L))
    testthat::expect_equal(colSums(g$X[[1L]]), rep(0, f$case$m), tolerance = 1e-12, ignore_attr = TRUE)
    testthat::expect_equal(colSums(g$X[[2L]]), rep(0, f$case$m), tolerance = 1e-12, ignore_attr = TRUE)
    testthat::expect_equal(g$X[[2L]], g$model$H %*% (g$model$layout$latent[[2L]] %*%
      g$loadings + .25 * g$noise[[2L]]), tolerance = 1e-13, ignore_attr = TRUE)
  }
})

testthat::test_that("the legacy rare-unit fixture preserves the original generator exactly", {
  f <- study05_fixture(31L)
  original <- study03_generate(f$job, f$case)
  testthat::expect_identical(f$generated$data, original$data)
  testthat::expect_identical(f$generated$X, original$X)
  testthat::expect_identical(f$generated$rare, original$rare)
  testthat::expect_equal(f$generated$model$truth, original$model$truth, tolerance = 0)
  testthat::expect_equal(f$generated$model$population_grams, original$model$population_grams, tolerance = 0)
})

testthat::test_that("invalid cases and spoofed evaluation streams cannot use the fixture path", {
  testthat::expect_error(study05_model(NULL), "complete")
  bad <- study05_cases()[1L, , drop = FALSE]; bad$a <- -.2
  testthat::expect_error(study05_model(bad), "differs")
  testthat::expect_error(study05_fixture(32L), "index")
  testthat::expect_error(study05_fixture(B = 200L), "Fixture B")
  testthat::expect_error(study05_jobs(study05_cases()[c(1L, 1L), ]), "unique")
  f <- study05_fixture(generate = FALSE)
  testthat::expect_false("generated" %in% names(f))
  wrong <- f$job; wrong$dataset_id <- 1L
  testthat::expect_error(study05_generate(wrong, f$case), "exact fixture")
  wrong <- f$job; wrong$data_stream <- study05_jobs()[[1L]]$data_stream
  testthat::expect_error(study05_generate(wrong, f$case), "exact fixture")
  wrong <- f$job; wrong$m <- 41L
  testthat::expect_error(study05_generate(wrong, f$case), "disagree")
  wrong <- f$job; wrong$stage <- "evaluation"
  testthat::expect_error(study05_generate(wrong, f$case), "Unknown")
  wrong <- f$job; wrong$data_stream <- as.numeric(wrong$data_stream)
  testthat::expect_error(study05_generate(wrong, f$case), "stream")
})
