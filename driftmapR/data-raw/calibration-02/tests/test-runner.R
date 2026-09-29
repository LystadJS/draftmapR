source(file.path("..", "..", "calibration-01", "model.R"), local = TRUE)
source(file.path("..", "..", "calibration-01", "regions.R"), local = TRUE)
for (file in c("kernel.R", "model.R", "run.R", "validate.R")) source(file.path("..", file), local = TRUE)

runner_fixture <- function(B = 21L, budgets = c(9L, 21L)) {
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection"); set.seed(777L)
  job <- list(m = 20L, dataset_id = 999L, data_stream = .Random.seed,
              bootstrap_seed = 777L, stage = "reserved_implementation_test")
  study02_one(job, B = B, budgets = budgets)
}

runner_update_tables <- function(result) {
  tables <- study02_tables(result); result[names(tables)] <- tables; result
}

testthat::test_that("complete runner is reproducible and preserves the shorter budget prefix", {
  a <- runner_fixture(); b <- runner_fixture(); short <- runner_fixture(9L, 9L)
  testthat::expect_identical(a$weights, b$weights)
  testthat::expect_identical(a$streams, b$streams)
  testthat::expect_identical(a$panels, b$panels)
  testthat::expect_identical(a$regions, b$regions)
  testthat::expect_identical(a$failures, b$failures)
  testthat::expect_identical(a$tangent_covariance, b$tangent_covariance)
  testthat::expect_identical(a$weights[1:9, ], short$weights)
  testthat::expect_identical(a$streams[1:9, ], short$streams)
  for (anchor in names(a$panels)) for (estimator in names(a$panels[[anchor]]$values)) {
    # BLAS may use a different summation order for 9-row versus 21-row
    # tangent matrix multiplication. RNG weights remain bitwise identical.
    testthat::expect_equal(a$panels[[anchor]]$values[[estimator]][1:9, , ],
                          short$panels[[anchor]]$values[[estimator]], tolerance = 1e-14)
  }
  testthat::expect_true(study02_same_table(a$regions[a$regions$budget == 9L, ], short$regions,
    c("m", "dataset_id", "anchor", "estimator", "entity", "budget", "method")))
  testthat::expect_false(any(short$regions$gate))
  testthat::expect_true(all(study02_validate_result(a)$passed))
})

testthat::test_that("injected draw failures preserve attempts and the exact production gate", {
  a <- runner_fixture(41L, c(21L, 41L))
  p <- a$panels$original
  p$success$refit_plugin[c(1L, 2L)] <- FALSE
  p$values$refit_plugin[c(1L, 2L), , ] <- NA_real_
  p$stages$refit_plugin[c(1L, 2L)] <- "embedding"
  p$messages$refit_plugin[c(1L, 2L)] <- "Injected rank failure"
  a$panels$original <- p; a <- runner_update_tables(a)
  use <- a$regions$anchor == "original" & a$regions$estimator == "refit_plugin"
  testthat::expect_equal(unique(a$regions$n_valid[use & a$regions$budget == 41L]), 39L)
  testthat::expect_true(all(a$regions$gate[use & a$regions$budget == 41L]))
  testthat::expect_false(any(a$regions$gate[use & a$regions$budget == 21L]))
  testthat::expect_equal(nrow(a$failures), 2L * 3L * 41L)
  testthat::expect_equal(sum(!a$failures$success), 2L)
  testthat::expect_true(all(study02_validate_result(a, regenerate_tangent = FALSE)$passed))
  # Three failures retain 38 valid draws, but fail the .95 fraction gate.
  a$panels$original$success$refit_plugin[3L] <- FALSE
  a$panels$original$values$refit_plugin[3L, , ] <- NA_real_
  a$panels$original$stages$refit_plugin[3L] <- "alignment"
  a$panels$original$messages$refit_plugin[3L] <- "Injected alignment failure"
  a <- runner_update_tables(a)
  r <- a$regions[use & a$regions$budget == 41L, ]
  testthat::expect_true(all(r$available))
  testthat::expect_false(any(r$gate | r$delivered))
  testthat::expect_true(all(is.na(r$covered)))
  testthat::expect_equal(unique(r$n_valid), 38L)
  testthat::expect_equal(nrow(a$failures), 246L)
  testthat::expect_true(all(study02_validate_result(a, regenerate_tangent = FALSE)$passed))
})

testthat::test_that("undefined observed fits retain planned ledger and region placeholders", {
  a <- runner_fixture()
  for (estimator in c("refit_plugin", "refit_oracle")) {
    a$panels$original$observed_ok[[estimator]] <- FALSE
    a$panels$original$estimates[[estimator]][, ] <- NA_real_
    a$panels$original$success[[estimator]][] <- FALSE
    a$panels$original$values[[estimator]][, , ] <- NA_real_
    a$panels$original$stages[[estimator]][] <- "observed_fit"
    a$panels$original$messages[[estimator]][] <- "Injected observed rank failure"
  }
  a <- runner_update_tables(a)
  f <- a$failures[a$failures$anchor == "original" & a$failures$estimator == "refit_plugin", ]
  testthat::expect_equal(nrow(f), 21L)
  testthat::expect_false(any(f$attempted | f$success))
  r <- a$regions[a$regions$anchor == "original" & a$regions$estimator == "refit_plugin", ]
  testthat::expect_equal(nrow(r), 18L)
  testthat::expect_true(all(r$reason == "observed_fit_failed"))
  testthat::expect_true(all(r$n_valid == 0L))
  testthat::expect_false(any(r$gate | r$delivered | r$available))
  testthat::expect_true(all(is.na(r$covered)))
  testthat::expect_true(all(study02_validate_result(a, regenerate_tangent = FALSE)$passed))
})

testthat::test_that("mechanical validation detects corrupted counts, vectors, and accounting", {
  a <- runner_fixture()
  bad <- a; bad$weights[1L, 1L] <- bad$weights[1L, 1L] + 1L
  testthat::expect_error(study02_validate_result(bad), "unit multiplicities")
  bad <- a; bad$streams[1L, 2L] <- bad$streams[1L, 2L] + 1L
  testthat::expect_error(study02_validate_result(bad), "stream replay")
  bad <- a; bad$panels$original$values$refit_plugin[1L, 1L, 1L] <- NA_real_
  testthat::expect_error(study02_validate_result(bad), "success and failure vectors")
  bad <- a; bad$regions$n_valid[1L] <- bad$regions$n_valid[1L] - 1L
  testthat::expect_error(study02_validate_result(bad), "region reconstruction")
  bad <- a; bad$tangent_covariance$total_trace[1L] <- 0
  testthat::expect_error(study02_validate_result(bad), "additive decomposition")
})
