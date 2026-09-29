# Run independently with testthat::test_file(), or source after model.R.
if (!exists("calibration_generate", mode = "function")) {
  candidates <- c("driftmapR/data-raw/calibration-01/model.R",
                  "data-raw/calibration-01/model.R", "../model.R", "model.R")
  model_file <- candidates[file.exists(candidates)][1L]
  if (is.na(model_file)) stop("Cannot locate calibration model.R.")
  source(model_file, local = TRUE)
}

model_test_stream <- function(seed) {
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  })
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(seed)
  .Random.seed
}

testthat::test_that("the scenario registry and fixed layout match the frozen design", {
  scenarios <- calibration_scenarios()
  testthat::expect_identical(scenarios$id, 1:6)
  testthat::expect_identical(scenarios$m, c(40L, 40L, 12L, 40L, 12L, 40L))
  testthat::expect_equal(scenarios$sigma, c(.25, .25, .25, 1, .25, .25))
  testthat::expect_equal(scenarios$q, c(1, 1, 1, 1, .15, 1))
  testthat::expect_equal(scenarios$rho_unit, c(0, 0, 0, 0, 0, .5))
  testthat::expect_identical(scenarios$motion, c(FALSE, rep(TRUE, 5L)))
  testthat::expect_equal(scenarios$rho_time, rep(.6, 6L))
  layout <- calibration_layout(scenarios[2L, ])
  testthat::expect_length(layout$anchors, 11L)
  testthat::expect_identical(layout$target_ids, c("E015", "E003", "E006"))
  delta <- layout$latent[[2L]] - layout$latent[[1L]]
  testthat::expect_equal(unname(delta["E006", ]), c(.45, -.30))
  testthat::expect_equal(unname(delta[13:18, ]),
                        matrix(rep(c(-.55, .40), each = 6L), 6L))
  testthat::expect_equal(unname(delta[layout$anchors, ]), matrix(0, 11L, 2L))
  null <- calibration_layout(scenarios[1L, ])
  testthat::expect_identical(null$latent[[1L]], null$latent[[2L]])
})

testthat::test_that("the supplied stream reproduces complete paired data and preserves caller RNG", {
  scenario <- calibration_scenarios()[2L, ]
  stream <- model_test_stream(891L)
  set.seed(675L)
  before <- .Random.seed
  kind <- RNGkind()
  first <- calibration_generate(scenario, stream)
  testthat::expect_identical(.Random.seed, before)
  testthat::expect_identical(RNGkind(), kind)
  second <- calibration_generate(scenario, stream)
  testthat::expect_identical(first, second)
  third <- calibration_generate(scenario, parallel::nextRNGStream(stream))
  testthat::expect_false(identical(first$data, third$data))
  testthat::expect_equal(dim(first$data), c(36L, 42L))
  testthat::expect_identical(first$data$entity[1:18], sprintf("E%03d", 1:18))
  testthat::expect_identical(first$data$entity[1:18], first$data$entity[19:36])
  testthat::expect_identical(first$data$time, rep(1:2, each = 18L))
  testthat::expect_identical(names(first$unit_map), first$features)
  testthat::expect_equal(length(unique(first$unit_map)), scenario$m)
  testthat::expect_true(all(is.finite(as.matrix(first$data[first$features]))))
  testthat::expect_true(is.na(first$rare_count))
  testthat::expect_false(any(first$rare))
})

testthat::test_that("invalid scenarios and streams fail informatively", {
  scenario <- calibration_scenarios()[1L, ]
  testthat::expect_error(calibration_layout(calibration_scenarios()), "one complete row")
  bad <- scenario
  bad$q <- 0
  testthat::expect_error(calibration_layout(bad), "numeric parameters")
  bad <- scenario
  bad$scenario <- "misspelled"
  testthat::expect_error(calibration_layout(bad), "Scenario name")
  testthat::expect_error(calibration_generate(scenario, 1L), "L'Ecuyer")
  testthat::expect_error(calibration_generate(scenario, as.numeric(model_test_stream(1L))),
                        "integer L'Ecuyer")
})

testthat::test_that("population truth is the leading plane of expected Gram, not latent positions", {
  scenario <- calibration_scenarios()[2L, ]
  population <- calibration_population(scenario)
  z <- population$layout$latent[[1L]]
  centered <- scale(z, center = TRUE, scale = FALSE)
  h <- diag(18L) - matrix(1 / 18, 18L, 18L)
  independent_gram <- scenario$m *
    (tcrossprod(centered) + scenario$sigma^2 * h)
  testthat::expect_equal(unname(population$gram[[1L]]), unname(independent_gram),
                        tolerance = 1e-12)
  expected_top <- scenario$m * (svd(centered, nu = 0L, nv = 0L)$d^2 + scenario$sigma^2)
  testthat::expect_equal(population$eigenvalues[[1L]][1:2], expected_top,
                        tolerance = 1e-12)
  testthat::expect_equal(population$eigenvalues[[1L]][3:17],
                        rep(scenario$m * scenario$sigma^2, 15L), tolerance = 1e-12)
  points <- population$object$coordinates
  points <- as.matrix(points[points$time == 1L, c("x", "y")])
  testthat::expect_gt(max(abs(as.numeric(stats::dist(points)) -
                               sqrt(scenario$m) * as.numeric(stats::dist(z)))), 1e-3)
  testthat::expect_identical(rownames(population$gram[[1L]]), rownames(z))
  testthat::expect_s3_class(population$object, "driftmap")
  testthat::expect_equal(nrow(population$movement), 18L)
  null <- calibration_population(calibration_scenarios()[1L, ])
  testthat::expect_lt(max(null$movement$distance), 1e-10)
  mover <- population$movement[population$movement$entity == "E015", ]
  testthat::expect_gt(mover$distance, 1)
})

testthat::test_that("empirical Gram means agree with analytic moments in regular, rare and dependent designs", {
  # A Monte Carlo validation with an explicit six-standard-error allowance
  # for every Gram entry. This checks the moment construction, not coverage.
  repetitions <- 500L
  scenarios <- calibration_scenarios()
  for (scenario_id in c(2L, 5L, 6L)) {
    scenario <- scenarios[scenario_id, ]
    truth <- calibration_population(scenario)$gram
    sum_gram <- sum_square <- lapply(1:2, function(i) matrix(0, 18L, 18L))
    stream <- model_test_stream(701L + scenario_id)
    for (i in seq_len(repetitions)) {
      generated <- calibration_generate(scenario, stream)
      stream <- parallel::nextRNGStream(stream)
      for (period in 1:2) {
        x <- as.matrix(generated$data[generated$data$time == period,
                                     generated$features])
        x <- scale(x, center = TRUE, scale = FALSE)
        gram <- tcrossprod(x)
        sum_gram[[period]] <- sum_gram[[period]] + gram
        sum_square[[period]] <- sum_square[[period]] + gram^2
      }
    }
    for (period in 1:2) {
      average <- sum_gram[[period]] / repetitions
      variance <- (sum_square[[period]] - sum_gram[[period]]^2 / repetitions) /
        (repetitions - 1L)
      se <- sqrt(pmax(variance, 0) / repetitions)
      testthat::expect_true(all(abs(average - truth[[period]]) <= 6 * se + 1e-9),
                            info = paste(scenario$scenario, "period", period))
    }
  }
})

testthat::test_that("projected measurement noise preserves temporal pairing and the declared unit dependence", {
  scenarios <- calibration_scenarios()
  layout <- calibration_layout(scenarios[2L, ])
  span <- cbind(1, layout$latent[[1L]], layout$latent[[2L]])
  decomposition <- qr(span)
  v <- qr.Q(decomposition, complete = TRUE)[, decomposition$rank + 1L]
  testthat::expect_lt(max(abs(crossprod(v, span))), 1e-12)
  for (scenario_id in c(2L, 6L)) {
    scenario <- scenarios[scenario_id, ]
    repetitions <- 300L
    first <- second <- matrix(NA_real_, repetitions, scenario$m)
    stream <- model_test_stream(451L + scenario_id)
    for (i in seq_len(repetitions)) {
      generated <- calibration_generate(scenario, stream)
      stream <- parallel::nextRNGStream(stream)
      x <- as.matrix(generated$data[generated$features])
      first[i, ] <- drop(crossprod(v, x[1:18, , drop = FALSE])) / scenario$sigma
      second[i, ] <- drop(crossprod(v, x[19:36, , drop = FALSE])) / scenario$sigma
    }
    testthat::expect_equal(stats::cor(c(first), c(second)), scenario$rho_time,
                          tolerance = .08)
    testthat::expect_equal(stats::cor(first[, 1L], first[, 2L]), scenario$rho_unit,
                          tolerance = .15)
  }
})

testthat::test_that("rare-axis generation records structural rank-one observations without concealment", {
  scenario <- calibration_scenarios()[5L, ]
  stream <- model_test_stream(145L)
  found <- NULL
  for (i in seq_len(100L)) {
    candidate <- calibration_generate(scenario, stream)
    if (candidate$rare_count == 0L) {
      found <- candidate
      break
    }
    stream <- parallel::nextRNGStream(stream)
  }
  testthat::expect_false(is.null(found))
  testthat::expect_identical(names(found$rare), found$features)
  testthat::expect_equal(found$rare_count, sum(found$rare))
  for (period in 1:2) {
    x <- as.matrix(found$data[found$data$time == period, found$features])
    singular <- svd(scale(x, center = TRUE, scale = FALSE), nu = 0L, nv = 0L)$d
    testthat::expect_lt(singular[2L] / singular[1L], 1e-12)
  }
  testthat::expect_error(driftmapR::embed_snapshots(found$data, found$features),
                        "rank|two|Two")
})
