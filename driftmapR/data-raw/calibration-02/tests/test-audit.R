source(file.path("..", "kernel.R"), local = TRUE)
source(file.path("..", "..", "calibration-01", "model.R"), local = TRUE)
source(file.path("..", "model.R"), local = TRUE)
source(file.path("..", "audit.R"), local = TRUE)

audit_fixture <- function(B = 9L) {
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(777L)
  job <- list(m = 40L, dataset_id = 999L, bootstrap_seed = 777L,
               data_stream = .Random.seed, stage = "implementation_fixture")
  generated <- study02_generate(job)
  model <- generated$model
  set.seed(job$bootstrap_seed)
  stream <- .Random.seed
  weights <- matrix(0L, B, job$m)
  streams <- matrix(0L, B, 7L)
  for (b in seq_len(B)) {
    assign(".Random.seed", stream, envir = .GlobalEnv)
    streams[b, ] <- stream
    weights[b, ] <- tabulate(sample.int(job$m, job$m, replace = TRUE), nbins = job$m)
    stream <- parallel::nextRNGStream(stream)
  }
  C <- lapply(generated$X, function(x) tcrossprod(x) / job$m)
  panels <- lapply(model$anchors, function(anchors) {
    observed <- study02_estimate(C[[1L]], C[[2L]], model$population_points, anchors)
    values <- list(refit_plugin = array(NA_real_, c(B, 3L, 2L)),
                   refit_oracle = array(NA_real_, c(B, 3L, 2L)),
                   tangent_oracle = array(NA_real_, c(B, 3L, 2L)))
    for (b in seq_len(B)) {
      Cb <- lapply(generated$X, function(x)
        sweep(x, 2L, weights[b, ], "*") %*% t(x) / job$m)
      draw <- study02_boot_draw(Cb[[1L]], Cb[[2L]], observed,
                                 model$population_points, anchors)
      values$refit_plugin[b, , ] <- draw$plugin[model$target_rows, ]
      values$refit_oracle[b, , ] <- draw$oracle[model$target_rows, ]
      values$tangent_oracle[b, , ] <- study02_tangent(Cb[[2L]] - Cb[[1L]],
        model$spectrum, anchors)$full[model$target_rows, ]
    }
    list(observed = observed, values = values,
      estimates = list(refit_plugin = observed$displacement[model$target_rows, ],
                        refit_oracle = observed$displacement[model$target_rows, ],
                        tangent_oracle = study02_tangent(C[[2L]] - C[[1L]],
                          model$spectrum, anchors)$full[model$target_rows, ]),
      success = list(refit_plugin = rep(TRUE, B), refit_oracle = rep(TRUE, B),
                       tangent_oracle = rep(TRUE, B)))
  })
  list(result = list(job = job, panels = panels, weights = weights, streams = streams),
       generated = generated)
}

testthat::test_that("the audit reproduces every saved target, draw, stream, and status for both anchor sets", {
  f <- audit_fixture()
  audited <- study02_public_audit(f$result, f$generated, B = 9L)
  testthat::expect_equal(nrow(audited), 2L)
  testthat::expect_identical(audited$anchors, c("original", "spread"))
  testthat::expect_true(all(audited$passed))
  testthat::expect_true(all(audited$streams_identical))
  testthat::expect_true(all(audited$failure_ledger_identical))
  testthat::expect_true(all(audited$oracle_ledger_identical))
  testthat::expect_equal(audited$max_feature_count_diff, c(0, 0))
  testthat::expect_true(all(audited$n_attempted == 9L & audited$n_valid == 9L))
  testthat::expect_lt(max(audited$max_estimate_abs_diff), 1e-10)
  testthat::expect_lt(max(audited$max_plugin_vector_abs_diff), 1e-10)
  testthat::expect_lt(max(audited$max_oracle_vector_abs_diff), 1e-10)
})

testthat::test_that("the audit rejects corrupted vectors, failed-status claims, and malformed plans", {
  f <- audit_fixture()
  wrong <- f$result
  wrong$panels$original$values$refit_plugin[1L, 1L, 1L] <-
    wrong$panels$original$values$refit_plugin[1L, 1L, 1L] + 0.01
  testthat::expect_error(study02_public_audit(wrong, f$generated, 9L), "audit discrepancy")
  wrong <- f$result
  wrong$panels$original$success$refit_plugin[1L] <- FALSE
  testthat::expect_error(study02_public_audit(wrong, f$generated, 9L), "failures=FALSE")
  wrong <- f$result
  wrong$weights[1L, 1L] <- wrong$weights[1L, 1L] + 1L
  testthat::expect_error(study02_public_audit(wrong, f$generated, 9L), "weights or RNG")
  wrong <- f$result
  wrong$streams[1L, 2L] <- wrong$streams[1L, 2L] + 1L
  testthat::expect_error(study02_public_audit(wrong, f$generated, 9L), "streams=FALSE")
})
