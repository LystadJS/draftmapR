cmds_fixture <- function() {
  z <- matrix(c(-2, -1, 0, 3, 1, -2, 4, 1, -1, 2, 2, 2), ncol = 2, byrow = TRUE)
  rownames(z) <- paste0("e", seq_len(nrow(z)))
  as.matrix(stats::dist(z))
}

test_that("classical MDS agrees with independent cmdscale geometry and inertia", {
  d <- cmds_fixture()
  original <- d
  fit <- fit_cmds_snapshot(d)
  reference <- stats::cmdscale(d, k = 2, eig = TRUE)
  expect_equal(as.matrix(stats::dist(fit$points)), d, tolerance = 1e-10)
  expect_equal(unname(tcrossprod(fit$points)),
               unname(tcrossprod(reference$points)), tolerance = 1e-10)
  expect_equal(fit$eigenvalues, reference$eig, tolerance = 1e-10)
  expect_equal(fit$model$GOF, reference$GOF, tolerance = 1e-10)
  expect_identical(fit$model$points, fit$points)
  expect_identical(fit$model$eig, fit$eigenvalues)
  expect_equal(fit$model$ac, 0)
  expect_identical(rownames(fit$points), rownames(d))
  expect_identical(colnames(fit$points), c("x", "y"))
  expect_identical(d, original)
  expect_equal(fit$diagnostics$n_positive, 2)
  expect_equal(fit$diagnostics$n_negative, 0)
  expect_lt(fit$diagnostics$negative_inertia_fraction, 1e-12)
  expect_equal(fit$diagnostics$positive_inertia_2d_fraction, 1, tolerance = 1e-10)
  expect_equal(fit$diagnostics$absolute_inertia_2d_fraction, 1, tolerance = 1e-10)
  expect_lt(fit$diagnostics$distance_rmse, 1e-12)
})

test_that("higher-dimensional Euclidean inputs expose actual truncation error", {
  z <- cbind(c(-3, -2, -1, 0, 2, 5), c(1, 3, -2, 0, 1, -4),
             c(0.2, -0.1, 0.8, -0.4, 0.1, -0.2))
  d <- as.matrix(stats::dist(z))
  fit <- fit_cmds_snapshot(d)
  reference <- stats::cmdscale(d, eig = TRUE)
  expect_equal(unname(tcrossprod(fit$points)), unname(tcrossprod(reference$points)),
               tolerance = 1e-10)
  expect_equal(fit$diagnostics$n_positive, 3)
  expect_lt(fit$diagnostics$positive_inertia_2d_fraction, 1)
  expect_gt(fit$diagnostics$distance_rmse, 0)
  oracle_rmse <- sqrt(mean((as.vector(stats::dist(fit$points)) -
                            as.vector(stats::as.dist(d)))^2))
  expect_equal(fit$diagnostics$distance_rmse, oracle_rmse, tolerance = 1e-12)
  expect_false(fit$diagnostics$boundary_tie)
})

test_that("non-Euclidean distances require explicit warned truncation", {
  d <- matrix(c(0, 1, 2, 1, 1, 0, 1, 2,
                2, 1, 0, 1, 1, 2, 1, 0), nrow = 4)
  expect_error(fit_cmds_snapshot(d, context = "period B"),
               "period B.*materially negative")
  expect_warning(fit <- fit_cmds_snapshot(d, negative_eigen = "truncate",
                                         context = "period B"),
                 "period B.*materially negative")
  reference <- stats::cmdscale(d, eig = TRUE, add = FALSE)
  expect_equal(unname(tcrossprod(fit$points)), unname(tcrossprod(reference$points)),
               tolerance = 1e-10)
  expect_equal(fit$eigenvalues, reference$eig, tolerance = 1e-10)
  expect_equal(fit$diagnostics$n_negative, 1)
  expect_equal(fit$diagnostics$negative_inertia_fraction, 0.2, tolerance = 1e-10)
  expect_equal(fit$model$GOF, c(0.8, 1), tolerance = 1e-10)
  expect_equal(fit$model$ac, 0)
  expect_gt(fit$diagnostics$distance_rmse, 0)
  expect_false(fit$diagnostics$boundary_tie)
})

test_that("rank-deficient and nearly rank-deficient maps are rejected", {
  d <- as.matrix(stats::dist(matrix(1:5, ncol = 1)))
  expect_error(fit_cmds_snapshot(d), "at least two positive eigenvalues")
  expect_error(fit_cmds_snapshot(matrix(0, 4, 4)), "rank-deficient")
  z <- cbind(1:5, c(0, 1, 0, -1, 0) * 1e-7)
  expect_error(fit_cmds_snapshot(as.matrix(stats::dist(z))), "rank-deficient")
})

test_that("spectral roundoff is retained without materially negative warnings", {
  fit <- expect_no_warning(fit_cmds_snapshot(cmds_fixture()))
  expect_equal(length(fit$eigenvalues), 6)
  expect_equal(fit$diagnostics$n_negative, 0)
  expect_lt(max(abs(fit$eigenvalues[3:6])) / max(abs(fit$eigenvalues)), 1e-10)
})

test_that("normalization supports large and small finite distance units", {
  d <- cmds_fixture()
  reference <- fit_cmds_snapshot(d)
  for (factor in c(1e-150, 1e-75, 1e75, 1e150)) {
    fit <- fit_cmds_snapshot(d * factor)
    expect_equal(unname(tcrossprod(fit$points / factor)),
                 unname(tcrossprod(reference$points)), tolerance = 1e-10)
    expect_equal((fit$eigenvalues / factor) / factor,
                 reference$eigenvalues, tolerance = 1e-8)
    expect_true(all(is.finite(fit$points)))
    expect_true(all(is.finite(fit$eigenvalues)))
    expect_equal(fit$model$GOF, reference$model$GOF, tolerance = 1e-10)
  }
  expect_error(fit_cmds_snapshot(d * 1e200), "rescale input distance units")
  expect_error(fit_cmds_snapshot(d * 1e-200), "rescale input distance units")
})

test_that("only eigenspace ties crossing the retained boundary warn", {
  tetrahedron <- matrix(1, 4, 4)
  diag(tetrahedron) <- 0
  expect_warning(fit <- fit_cmds_snapshot(tetrahedron, context = "period C"),
                 "period C.*second and third eigenvalues tie")
  expect_true(fit$diagnostics$boundary_tie)
  expect_equal(fit$diagnostics$eigengap_23, 0, tolerance = 1e-10)
  expect_equal(fit$diagnostics$positive_inertia_2d_fraction, 2 / 3, tolerance = 1e-10)
  square <- as.matrix(stats::dist(rbind(c(-1, -1), c(-1, 1), c(1, 1), c(1, -1))))
  fit_square <- expect_no_warning(fit_cmds_snapshot(square))
  expect_equal(fit_square$eigenvalues[1], fit_square$eigenvalues[2], tolerance = 1e-10)
  expect_false(fit_square$diagnostics$boundary_tie)
})

test_that("invalid matrix shape and dissimilarity values fail contextually", {
  expect_error(fit_cmds_snapshot(1:4), "square numeric matrix")
  expect_error(fit_cmds_snapshot(matrix(1, 3, 4)), "square numeric matrix")
  expect_error(fit_cmds_snapshot(matrix("a", 3, 3)), "square numeric matrix")
  expect_error(fit_cmds_snapshot(matrix(0 + 0i, 3, 3)), "square numeric matrix")
  expect_error(fit_cmds_snapshot(matrix(0, 2, 2)), "at least 3 entities")
  for (value in c(NA_real_, Inf, NaN)) {
    d <- cmds_fixture()
    d[1, 2] <- value
    expect_error(fit_cmds_snapshot(d), "finite and nonmissing")
  }
  d <- cmds_fixture()
  d[1, 2] <- -1
  expect_error(fit_cmds_snapshot(d), "nonnegative")
  d <- cmds_fixture()
  d[1, 1] <- 0.01
  expect_error(fit_cmds_snapshot(d), "zero diagonal")
  d <- cmds_fixture()
  d[1, 2] <- d[1, 2] * 1.001
  expect_error(fit_cmds_snapshot(d, context = "bad period"), "bad period.*symmetric")
  expect_error(fit_cmds_snapshot(d, eigen_tol = 0.1), "symmetric")
})

test_that("tiny symmetry roundoff is reconciled without modifying input", {
  d <- cmds_fixture()
  d[1, 2] <- d[1, 2] + .Machine$double.eps
  original <- d
  fit <- fit_cmds_snapshot(d)
  expect_equal(fit$diagnostics$n_negative, 0)
  expect_identical(d, original)
})

test_that("kernel spectral and negative-eigenvalue controls are validated", {
  d <- cmds_fixture()
  for (tol in list(NA_real_, Inf, 0, -1, 1, c(1e-10, 1e-8), "small")) {
    expect_error(fit_cmds_snapshot(d, eigen_tol = tol), "eigen_tol")
  }
  for (choice in list(NA_character_, "add", c("error", "truncate"), TRUE)) {
    expect_error(fit_cmds_snapshot(d, negative_eigen = choice), "negative_eigen")
  }
})
