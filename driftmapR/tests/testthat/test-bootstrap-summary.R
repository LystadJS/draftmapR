bootstrap_summary_fixture <- function(periods = as.Date("2026-01-01") + 0:2) {
  observed <- data.frame(entity = c("a", "a"), time_from = periods[1:2],
                         time_to = periods[2:3], x_from = 0, y_from = 0,
                         x_to = c(2, 12), y_to = c(0.5, 3),
                         dx = c(2, 12), dy = c(0.5, 3),
                         distance = sqrt(c(2, 12)^2 + c(0.5, 3)^2))
  coordinates <- data.frame(entity = rep("a", 3), time = periods,
                            period_index = 1:3, x = c(0, 2, 14),
                            y = c(0, 0.5, 3.5))
  dx <- rbind(c(1, 3, 5), c(10, 20, 30))
  dy <- rbind(c(-1, 0, 1), c(2, 4, 6))
  movement_draws <- do.call(rbind, lapply(1:3, function(k) {
    z <- observed
    z$replicate_id <- c(1L, 3L, 5L)[k]
    z$dx <- dx[, k]
    z$dy <- dy[, k]
    z$x_to <- z$dx
    z$y_to <- z$dy
    z$distance <- sqrt(z$dx^2 + z$dy^2)
    z
  }))
  coordinate_draws <- do.call(rbind, lapply(1:3, function(k) {
    z <- coordinates
    z$replicate_id <- c(1L, 3L, 5L)[k]
    z$x <- c(1, 3, 8) * k
    z$y <- c(2, -3, 5) * k
    z
  }))
  list(observed = observed, coordinates = coordinates,
       movement_draws = movement_draws, coordinate_draws = coordinate_draws,
       B = 5L, probs = c(0.1, 0.5, 0.9), min_success = 0.5, n_valid = 3L)
}

test_that("successful bootstrap summaries use separate targets and sample moments", {
  input <- bootstrap_summary_fixture()
  out <- do.call(summarize_bootstrap, input)
  s <- out$summary
  expect_identical(s[c("entity", "time_from", "time_to")],
                   input$observed[c("entity", "time_from", "time_to")])
  expect_equal(s$observed_dx, c(2, 12))
  expect_equal(s$mean_dx, c(3, 20))
  expect_equal(s$mean_dy, c(0, 4))
  expect_equal(s$sd_dx, c(2, 10))
  expect_equal(s$sd_dy, c(1, 2))
  expect_equal(s$cov_dx_dy, c(2, 20))
  expect_equal(s$mcse_mean_dx, c(2, 10) / sqrt(3))
  expect_equal(s$mcse_mean_dy, c(1, 2) / sqrt(3))
  expect_identical(s$n_attempted, c(5L, 5L))
  expect_identical(s$n_valid, c(3L, 3L))
  expect_identical(s$n_failed, c(2L, 2L))
  expect_equal(s$success_rate, c(0.6, 0.6))
  expect_identical(s$summary_status, rep("ok", 2))
  for (i in 1:2) {
    distances <- input$movement_draws$distance[seq.int(i, 6, by = 2)]
    expect_equal(s$mean_distance[i], mean(distances))
    expect_equal(s$sd_distance[i], stats::sd(distances))
    expect_equal(s$mcse_mean_distance[i], stats::sd(distances) / sqrt(3))
  }
  # Mean of norms and norm of the mean vector are intentionally distinct.
  expect_gt(s$mean_distance[1], sqrt(s$mean_dx[1]^2 + s$mean_dy[1]^2))
})

test_that("bootstrap coordinate covariance and quantiles match independent formulas", {
  input <- bootstrap_summary_fixture()
  out <- do.call(summarize_bootstrap, input)
  c <- out$coordinate_summary
  expect_identical(c[c("entity", "time", "period_index")],
                   input$coordinates[c("entity", "time", "period_index")])
  expect_equal(c$mean_x, c(2, 6, 16))
  expect_equal(c$mean_y, c(4, -6, 10))
  expect_equal(c$var_x, c(1, 9, 64))
  expect_equal(c$var_y, c(4, 9, 25))
  expect_equal(c$cov_xy, c(2, -9, 40))
  expect_identical(c$summary_status, rep("ok", 3))
  q <- out$quantiles
  expect_equal(nrow(q), 18L)
  expect_s3_class(q$time_from, "Date")
  expect_identical(q$measure[1:9], rep(c("dx", "dy", "distance"), each = 3))
  expect_identical(q$probability[1:9], rep(c(0.1, 0.5, 0.9), 3))
  for (i in 1:2) {
    for (v in c("dx", "dy", "distance")) {
      samples <- input$movement_draws[[v]][seq.int(i, 6, by = 2)]
      actual <- q$value[q$time_from == input$observed$time_from[i] & q$measure == v]
      expect_equal(actual, unname(stats::quantile(samples, probs = input$probs,
                                                type = 7)))
    }
  }
})

test_that("zero, one, and below-threshold successes retain keys but suppress estimates", {
  for (valid in 0:3) {
    input <- bootstrap_summary_fixture()
    input$n_valid <- as.integer(valid)
    input$min_success <- 0.8
    ids <- c(1L, 3L, 5L)[seq_len(valid)]
    input$movement_draws <- input$movement_draws[
      input$movement_draws$replicate_id %in% ids, , drop = FALSE]
    input$coordinate_draws <- input$coordinate_draws[
      input$coordinate_draws$replicate_id %in% ids, , drop = FALSE]
    out <- do.call(summarize_bootstrap, input)
    status <- if (valid == 0) "no_successful_replicates" else if (valid == 1) {
      "insufficient_replicates"
    } else "below_success_threshold"
    expect_identical(out$summary$summary_status, rep(status, 2))
    expect_identical(out$coordinate_summary$summary_status, rep(status, 3))
    expect_identical(out$summary$n_valid, rep(as.integer(valid), 2))
    expect_identical(out$summary$n_failed, rep(as.integer(5 - valid), 2))
    expect_equal(out$summary$observed_dx, c(2, 12))
    expect_true(all(is.na(out$summary$mean_dx)))
    expect_true(all(is.na(out$summary$sd_distance)))
    expect_true(all(is.na(out$summary$cov_dx_dy)))
    expect_true(all(is.na(out$coordinate_summary$mean_x)))
    expect_true(all(is.na(out$coordinate_summary$cov_xy)))
    expect_true(all(is.na(out$quantiles$value)))
    expect_identical(out$summary[c("entity", "time_from", "time_to")],
                     input$observed[c("entity", "time_from", "time_to")])
  }
})

test_that("bootstrap summary success threshold is inclusive", {
  input <- bootstrap_summary_fixture()
  input$min_success <- 3 / 5
  out <- do.call(summarize_bootstrap, input)
  expect_identical(out$summary$summary_status, rep("ok", 2))
  input$min_success <- 3 / 5 + 1e-10
  out <- do.call(summarize_bootstrap, input)
  expect_identical(out$summary$summary_status, rep("below_success_threshold", 2))
})

test_that("summary keys retain time classes and near-identical numeric values", {
  periods <- list(c(1, 1 + 1e-15, 1 + 2e-15),
                   as.POSIXct("2026-01-01", tz = "UTC") + c(0, 0.01, 0.02),
                   ordered(c("early", "middle", "late"),
                           levels = c("early", "middle", "late")))
  for (p in periods) {
    input <- bootstrap_summary_fixture(p)
    out <- do.call(summarize_bootstrap, input)
    expect_identical(out$summary$time_from, p[1:2])
    expect_identical(out$summary$time_to, p[2:3])
    expect_identical(out$coordinate_summary$time, p)
    expect_identical(out$quantiles$time_from, rep(p[1:2], each = 9))
    expect_equal(out$summary$mean_dx, c(3, 20))
  }
})

test_that("draw blocks must agree with the success ledger and exact target keys", {
  input <- bootstrap_summary_fixture()
  input$n_valid <- 2L
  expect_error(do.call(summarize_bootstrap, input), "success ledger")
  input <- bootstrap_summary_fixture()
  input$movement_draws$time_from[1] <- input$movement_draws$time_from[1] + 1
  expect_error(do.call(summarize_bootstrap, input), "target keys")
  input <- bootstrap_summary_fixture(c(1, 1 + 1e-15, 1 + 2e-15))
  input$movement_draws$time_from[1] <- input$movement_draws$time_from[2]
  expect_error(do.call(summarize_bootstrap, input), "target keys")
  input <- bootstrap_summary_fixture()
  input$coordinate_draws$entity[1] <- "new"
  expect_error(do.call(summarize_bootstrap, input), "target keys")
})

test_that("empty movement targets remain typed without fabricating rows", {
  input <- bootstrap_summary_fixture()
  input$observed <- input$observed[FALSE, , drop = FALSE]
  input$movement_draws <- input$movement_draws[FALSE, , drop = FALSE]
  out <- do.call(summarize_bootstrap, input)
  expect_equal(nrow(out$summary), 0L)
  expect_equal(nrow(out$quantiles), 0L)
  expect_s3_class(out$summary$time_from, "Date")
  expect_s3_class(out$quantiles$time_to, "Date")
  expect_equal(out$coordinate_summary$mean_x, c(2, 6, 16))
})

test_that("unrepresentable summary moments are marked instead of returned as infinite", {
  input <- bootstrap_summary_fixture()
  input$movement_draws$dx <- rep(c(-1.7e308, 12, 0, 12, 1.7e308, 12), 1)
  input$coordinate_draws$x <- rep(c(-1e200, 3, 8, 0, 6, 16, 1e200, 9, 24), 1)
  out <- do.call(summarize_bootstrap, input)
  # With three replicates the movement SD is representable; its mean is zero.
  expect_equal(out$summary$mean_dx[1], 0)
  expect_true(is.finite(out$summary$sd_dx[1]))
  expect_identical(out$coordinate_summary$summary_status, c("numerical_failure", "ok", "ok"))
  expect_true(is.na(out$coordinate_summary$var_x[1]))
  expect_true(is.na(out$coordinate_summary$mean_x[1]))
  input$n_valid <- 2L
  input$movement_draws <- input$movement_draws[input$movement_draws$replicate_id != 3L, ]
  input$coordinate_draws <- input$coordinate_draws[input$coordinate_draws$replicate_id != 3L, ]
  input$min_success <- 0.4
  out <- do.call(summarize_bootstrap, input)
  expect_identical(out$summary$summary_status, c("numerical_failure", "ok"))
  expect_true(is.na(out$summary$sd_dx[1]))
  expect_true(all(is.na(out$quantiles$value[1:9])))
  expect_identical(out$summary$n_valid, rep(2L, 2))
  expect_equal(bootstrap_scaled_cov(c(-1e308, 1e308), c(-1e-308, 1e-308)), 2)
})
