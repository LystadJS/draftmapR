source(file.path("..", "kernel.R"), local = TRUE)
source(file.path("..", "..", "calibration-01", "model.R"), local = TRUE)

kernel_fixture <- function(m = 40L) {
  scenario <- calibration_scenarios()[1L, , drop = FALSE]
  scenario$m <- as.integer(m)
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(777L) # Reserved implementation fixture, not a study-02 dataset.
  generated <- calibration_generate(scenario, .Random.seed)
  X <- lapply(1:2, function(t) {
    x <- as.matrix(generated$data[generated$data$time == t, generated$features])
    sweep(x, 2L, colMeans(x), "-")
  })
  C <- lapply(X, function(x) tcrossprod(x) / m)
  population <- calibration_population(scenario)
  Cpop <- population$gram[[1L]] / m
  spec <- study02_spectrum(Cpop)
  anchors <- match(generated$layout$anchors, generated$layout$entitygroups$entity)
  list(generated = generated, X = X, C = C, Cpop = Cpop, spec = spec,
       anchors = anchors, m = m)
}

testthat::test_that("Gram kernel rejects invalid dimensions, rank, and plane ties", {
  f <- kernel_fixture()
  testthat::expect_equal(dim(study02_points(f$C[[1L]])), c(18L, 2L))
  testthat::expect_error(study02_points(matrix(0, 18, 18)), "zero rank")
  testthat::expect_error(study02_points(tcrossprod(f$X[[1L]][, 1L])), "two positive")
  testthat::expect_error(study02_points(diag(18)), "centered")
  H <- diag(18) - matrix(1 / 18, 18, 18)
  testthat::expect_error(study02_points(H), "boundary tie")
  bad <- f$C[[1L]]; bad[1L, 2L] <- bad[1L, 2L] + 0.01
  testthat::expect_error(study02_points(bad), "symmetric")
  bad <- f$C[[1L]]; bad[1L, 1L] <- NA_real_
  testthat::expect_error(study02_points(bad), "finite numeric")
  testthat::expect_error(study02_register(f$spec$points, f$spec$points, c(1, 2)), "three unique")
  testthat::expect_error(study02_register(f$spec$points, f$spec$points, c(1, 2, 2)), "three unique")
  testthat::expect_error(study02_register(cbind(1:18, 1:18), f$spec$points, f$anchors), "Rank-deficient")
})

testthat::test_that("Procrustes handles reflection, rotation, and translation independently", {
  f <- kernel_fixture()
  A <- f$spec$points
  Q <- matrix(c(0, 1, 1, 0), 2L)
  source <- sweep(A %*% Q, 2L, c(3, -9), "+")
  fit <- study02_register(source, A, f$anchors)
  testthat::expect_equal(unname(fit$points), unname(A), tolerance = 1e-12)
  testthat::expect_equal(fit$determinant, -1, tolerance = 1e-12)
  testthat::expect_equal(fit$rotation, Q, tolerance = 1e-12)
  testthat::expect_equal(unname(study02_estimate(f$Cpop, f$Cpop, A, f$anchors)$displacement),
                         matrix(0, 18, 2), tolerance = 1e-12)
})

testthat::test_that("estimates and paired oracle draws respect frame equivariance", {
  f <- kernel_fixture()
  A <- f$spec$points
  p1 <- study02_points(f$C[[1L]]); p2 <- study02_points(f$C[[2L]])
  Q1 <- matrix(c(cos(0.3), sin(0.3), -sin(0.3), cos(0.3)), 2L)
  Q2 <- matrix(c(0, 1, 1, 0), 2L)
  original <- study02_align_points(p1, p2, A, f$anchors)
  reframed <- study02_align_points(sweep(p1 %*% Q1, 2L, c(1, 3), "+"),
    sweep(p2 %*% Q2, 2L, c(-2, 5), "+"), A, f$anchors)
  testthat::expect_equal(unname(original$displacement), unname(reframed$displacement), tolerance = 1e-12)
  rotated <- study02_align_points(p1, p2, A %*% Q2, f$anchors)
  testthat::expect_equal(unname(rotated$displacement), unname(original$displacement %*% Q2), tolerance = 1e-12)
  weights <- rep(c(0, 1, 2, 1), length.out = f$m)
  Cb <- lapply(f$X, function(x) sweep(x, 2L, weights, "*") %*% t(x) / f$m)
  b1 <- study02_points(Cb[[1L]]); b2 <- study02_points(Cb[[2L]])
  draws <- study02_boot_points(b1, b2, original, A, f$anchors)
  testthat::expect_true(draws$oracle_success)
  testthat::expect_identical(draws$oracle_error, "")
  oracle_direct <- study02_align_points(b1, b2, A, f$anchors)
  testthat::expect_equal(unname(draws$oracle), unname(oracle_direct$displacement), tolerance = 1e-12)
  transformed <- study02_boot_points(b1 %*% Q1, b2 %*% Q2, original, A, f$anchors)
  testthat::expect_equal(unname(transformed$plugin), unname(draws$plugin), tolerance = 1e-12)
  testthat::expect_equal(unname(transformed$oracle), unname(draws$oracle), tolerance = 1e-12)
})

testthat::test_that("an oracle-only registration failure preserves the valid plugin draw", {
  f <- kernel_fixture()
  A <- f$spec$points
  p1 <- study02_points(f$C[[1L]]); p2 <- study02_points(f$C[[2L]])
  observed <- study02_align_points(p1, p2, A, f$anchors)
  reference <- study02_boot_points(p1, p2, observed, A, f$anchors)
  baseline <- study02_register(p1, observed$aligned1, f$anchors)$points
  design <- cbind(1, baseline)
  anchor_design <- design[f$anchors, , drop = FALSE]
  nuisance <- sin(seq_len(nrow(baseline)))
  residual <- nuisance - as.numeric(design %*% solve(crossprod(anchor_design),
    crossprod(anchor_design, nuisance[f$anchors])))
  # Both coordinate sets are full rank, but their anchor cross-covariance has
  # rank one: the oracle second coordinate is orthogonal to the source span.
  oracle_target <- cbind(baseline[, 1L], residual)
  testthat::expect_gt(svd(scale(oracle_target[f$anchors, ], scale = FALSE))$d[2L], 0.1)
  captured <- study02_boot_points(p1, p2, observed, oracle_target, f$anchors)
  testthat::expect_equal(captured$plugin, reference$plugin, tolerance = 1e-12)
  testthat::expect_false(captured$oracle_success)
  testthat::expect_match(captured$oracle_error, "Rank-deficient anchor cross-covariance")
  testthat::expect_true(all(is.na(captured$oracle)))
  testthat::expect_true(all(is.na(captured$oracle_rotation)))
  testthat::expect_equal(dim(captured$oracle), c(18L, 2L))
})

testthat::test_that("full spectral derivative matches finite differences including discarded eigenspaces", {
  f <- kernel_fixture()
  E <- f$C[[2L]] - f$C[[1L]]
  exact <- study02_differential(E, f$spec)
  signed_points <- function(C) {
    s <- study02_spectrum(C)
    signs <- sign(colSums(s$vectors[, 1:2] * f$spec$vectors[, 1:2]))
    sweep(s$points, 2L, signs, "*")
  }
  for (h in c(1e-4, 5e-5)) {
    numerical <- (signed_points(f$Cpop + h * E) - signed_points(f$Cpop - h * E)) / (2 * h)
    testthat::expect_equal(unname(exact), unname(numerical), tolerance = 1e-7)
  }
  changed <- f$spec
  Q <- matrix(c(cos(0.4), sin(0.4), -sin(0.4), cos(0.4)), 2L)
  changed$vectors[, 3:4] <- changed$vectors[, 3:4] %*% Q
  testthat::expect_equal(unname(study02_differential(E, changed)), unname(exact), tolerance = 1e-12)
  leading_only <- f$spec$vectors[, 1:2] %*% crossprod(f$spec$vectors[, 1:2], exact)
  testthat::expect_gt(max(abs(exact - leading_only)), 1e-4)
  bad <- f$spec; bad$values[2L] <- bad$values[1L]
  testthat::expect_error(study02_differential(E, bad), "distinct leading")
})

testthat::test_that("complete null tangent matches a refitted embedding and alignment derivative", {
  f <- kernel_fixture()
  E <- f$C[[2L]] - f$C[[1L]]
  exact <- study02_tangent(E, f$spec, f$anchors)
  errors <- numeric(2L)
  for (k in 1:2) {
    h <- c(1e-4, 5e-5)[k]
    plus <- study02_estimate(f$Cpop - h * E / 2, f$Cpop + h * E / 2,
                             f$spec$points, f$anchors)$displacement
    minus <- study02_estimate(f$Cpop + h * E / 2, f$Cpop - h * E / 2,
                              f$spec$points, f$anchors)$displacement
    numerical <- (plus - minus) / (2 * h)
    errors[k] <- max(abs(exact$full - numerical))
    testthat::expect_equal(unname(exact$full), unname(numerical), tolerance = 1e-7)
  }
  testthat::expect_lt(max(errors), 1e-7)
  testthat::expect_equal(exact$full, exact$embedding + exact$alignment, tolerance = 1e-14)
  testthat::expect_equal(study02_tangent(-2 * E, f$spec, f$anchors)$full,
                         -2 * exact$full, tolerance = 1e-12)
  Q <- matrix(c(0, 1, 1, 0), 2L)
  rotated <- study02_alignment_tangent(f$spec$points %*% Q, exact$embedding %*% Q, f$anchors)
  testthat::expect_equal(unname(rotated$full), unname(exact$full %*% Q), tolerance = 1e-12)
})

testthat::test_that("paired per-unit influences reproduce observed and weighted Gram tangents", {
  f <- kernel_fixture(12L)
  unit_E <- lapply(seq_len(f$m), function(j)
    tcrossprod(f$X[[2L]][, j]) - tcrossprod(f$X[[1L]][, j]))
  influences <- lapply(unit_E, function(E) study02_tangent(E, f$spec, f$anchors)$full)
  average <- Reduce(`+`, influences) / f$m
  testthat::expect_equal(unname(average), unname(study02_tangent(
    f$C[[2L]] - f$C[[1L]], f$spec, f$anchors)$full), tolerance = 1e-12)
  weights <- rep(c(0, 1, 2), 4L)
  weighted <- Reduce(`+`, Map(function(x, w) w * x, influences, weights)) / f$m
  weighted_E <- Reduce(`+`, Map(function(x, w) w * x, unit_E, weights)) / f$m
  testthat::expect_equal(unname(weighted), unname(study02_tangent(
    weighted_E, f$spec, f$anchors)$full), tolerance = 1e-12)
})

testthat::test_that("kernel plugin agrees with public PCA and identical public bootstrap draws at each unit count", {
  for (m in c(12L, 40L, 120L)) {
    f <- kernel_fixture(m)
    g <- f$generated
    fitted <- driftmapR::embed_snapshots(g$data, g$features, method = "pca")
    fitted <- driftmapR::align_snapshots(fitted, anchors = g$layout$anchors)
    observed <- study02_estimate(f$C[[1L]], f$C[[2L]], f$spec$points, f$anchors)
    public_baseline <- as.matrix(fitted$aligned[fitted$aligned$period_index == 1L, c("x", "y")]) / sqrt(m)
    registration <- study02_register(public_baseline, f$spec$points, f$anchors)
    public_movement <- (as.matrix(driftmapR::measure_drift(fitted)[c("dx", "dy")]) /
      sqrt(m)) %*% registration$rotation
    testthat::expect_equal(unname(observed$displacement), unname(public_movement), tolerance = 1e-10)
    design <- driftmapR::paired_unit_design(g$unit_map, assumptions = "Independent paired Gaussian units in reserved seed-777 test fixture.")
    bootstrap <- driftmapR::bootstrap_drift(fitted, design, B = 9L, seed = 777L,
                                            keep = "replicates")$bootstrap
    testthat::expect_true(all(bootstrap$attempts$success))
    for (b in 1:9) {
      weights <- bootstrap$draws[[b]]$feature_weights[g$features]
      Cb <- lapply(f$X, function(x) sweep(x, 2L, weights, "*") %*% t(x) / m)
      ours <- study02_boot_draw(Cb[[1L]], Cb[[2L]], observed, f$spec$points, f$anchors)$plugin
      rows <- bootstrap$replicates[bootstrap$replicates$replicate_id == b, ]
      theirs <- (as.matrix(rows[c("dx", "dy")]) / sqrt(m)) %*% registration$rotation
      testthat::expect_equal(unname(ours), unname(theirs), tolerance = 1e-10)
    }
  }
})
