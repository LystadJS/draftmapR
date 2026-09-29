for (relative in c("../../calibration-01/model.R", "../../calibration-01/regions.R",
                    "../../calibration-02/kernel.R", "../jackknife.R", "../regions.R",
                    "../model.R", "../run.R", "../audit.R")) source(relative, local = TRUE)

audit03_fixture <- function(rare_unavailable = FALSE) {
  cases <- study03_cases()
  case <- cases[if (rare_unavailable) nrow(cases) else 4L, , drop = FALSE]
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(777L)
  job <- list(case_id = case$case_id, case_index = case$case_index,
    dataset_id = 999L, m = as.integer(case$m), data_stream = .Random.seed,
    bootstrap_seed = 777L, stage = "reserved_audit_fixture")
  g <- study03_generate(job, case)
  if (rare_unavailable) {
    # Deliberately unavailable rank-one panel, not a newly sampled holdout.
    g$X <- lapply(1:2, function(t)
      tcrossprod(g$model$H %*% g$model$layout$latent[[t]][, 1L], seq_len(job$m)))
    for (t in 1:2) g$data[g$data$time == t, g$features] <- g$X[[t]]
    g$rare[] <- FALSE; g$rare_count <- 0L
  }
  result <- study03_one(job, case, B = 4L, generated = g, keep_inner_values = TRUE)
  list(result = result, g = g)
}

testthat::test_that("public outer vectors, streams, and expanded non-null jackknives agree", {
  f <- audit03_fixture()
  audit <- study03_public_audit(f$result, f$g)
  testthat::expect_equal(nrow(audit), 6L)
  testthat::expect_true(all(audit$passed))
  testthat::expect_identical(audit$audit_type,
    c("observed", "full_bootstrap", rep("expanded_jackknife", 4L)))
  testthat::expect_identical(audit$replicate_id[3:6], 0:3)
  testthat::expect_equal(audit$n_attempted[2L], 4L)
  testthat::expect_true(audit$streams_identical[2L])
  testthat::expect_equal(audit$max_feature_count_diff[2L], 0)
  testthat::expect_true(all(audit$failure_ledger_identical))
  testthat::expect_lt(max(audit$max_vector_abs_diff, na.rm = TRUE), 1e-9)
  testthat::expect_lt(max(audit$max_covariance_abs_diff, na.rm = TRUE), 1e-9)
  testthat::expect_true(all(audit$covariance_status_identical[3:6]))
  testthat::expect_equal(audit$n_attempted[3L], f$result$job$m)
  testthat::expect_equal(audit$n_attempted[4:6], rowSums(f$result$weights[1:3, ] > 0L))
})

testthat::test_that("an unavailable rare observed fit is audited without artificial bootstrap attempts", {
  f <- audit03_fixture(TRUE)
  testthat::expect_false(f$result$observed_success)
  audit <- study03_public_audit(f$result, f$g)
  testthat::expect_identical(audit$audit_type, c("observed", "bootstrap_skipped"))
  testthat::expect_true(all(audit$passed))
  testthat::expect_equal(audit$n_attempted, c(1L, 0L))
  testthat::expect_equal(audit$n_successful, c(0L, 0L))
  testthat::expect_true(all(is.na(audit$max_vector_abs_diff)))
  testthat::expect_false(any(f$result$attempts$attempted))
})

testthat::test_that("audit catches altered RNG streams and covariance results", {
  f <- audit03_fixture()
  changed <- f$result
  changed$streams[1L, 2L] <- changed$streams[1L, 2L] + 1L
  testthat::expect_error(study03_public_audit(changed, f$g), "engineering audit mismatch")
  changed <- f$result
  changed$inner[[2L]]$covariance[[1L]][1L, 1L] <-
    changed$inner[[2L]]$covariance[[1L]][1L, 1L] + 0.01
  testthat::expect_error(study03_public_audit(changed, f$g), "expanded_jackknife")
  changed <- f$result; changed$weights[1L, 1L] <- -1L
  testthat::expect_error(study03_public_audit(changed, f$g), "valid counts")
})
