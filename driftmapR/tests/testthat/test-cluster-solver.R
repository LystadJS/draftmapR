# Independent enumeration oracle: visit columns ascending and unmatched last,
# and keep the first maximizer. This tests the optimizer, exact tie convention,
# and original-problem edge-removal margins without calling clue.
brute_cluster_assignment <- function(weights) {
  nr <- nrow(weights)
  nc <- ncol(weights)
  best_objective <- -Inf
  best_assignment <- rep(NA_integer_, nr)
  visit <- function(i, available, assignment, objective) {
    if (i > nr) {
      if (objective > best_objective) {
        best_objective <<- objective
        best_assignment <<- assignment
      }
      return(invisible(NULL))
    }
    eligible <- available[weights[i, available] > 0]
    for (j in eligible) {
      candidate <- assignment
      candidate[i] <- j
      visit(i + 1L, available[available != j], candidate,
            objective + weights[i, j])
    }
    visit(i + 1L, available, assignment, objective)
    invisible(NULL)
  }
  visit(1L, seq_len(nc), rep(NA_integer_, nr), 0)
  list(assignment = best_assignment, objective = best_objective)
}

expect_cluster_oracle <- function(weights) {
  actual <- solve_cluster_assignment(weights)
  expected <- brute_cluster_assignment(weights)
  expect_identical(actual$assignment, expected$assignment)
  expect_equal(actual$objective, expected$objective, tolerance = 0)
  expect_identical(is.na(actual$margins), is.na(actual$assignment))
  expect_identical(is.na(actual$ambiguous), is.na(actual$assignment))
  for (i in which(!is.na(expected$assignment))) {
    forbidden <- weights
    forbidden[i, expected$assignment[i]] <- 0
    margin <- expected$objective - brute_cluster_assignment(forbidden)$objective
    expect_equal(actual$margins[i], margin, tolerance = 0)
    expect_identical(actual$ambiguous[i], margin == 0)
  }
  invisible(actual)
}

test_that("integer assignment defeats rowwise greedy matching", {
  weights <- matrix(c(9, 8, 8, 0), nrow = 2, byrow = TRUE)
  actual <- expect_cluster_oracle(weights)
  expect_identical(actual$assignment, c(2L, 1L))
  expect_equal(actual$objective, 16)
  expect_equal(actual$margins, c(7, 7))
})

test_that("equal optima use rowwise lexicographic order with unmatched last", {
  equal <- expect_cluster_oracle(matrix(1, 3, 3))
  expect_identical(equal$assignment, 1:3)
  expect_equal(equal$margins, rep(0, 3))
  expect_true(all(equal$ambiguous))

  tall <- expect_cluster_oracle(matrix(1, 3, 2))
  expect_identical(tall$assignment, c(1L, 2L, NA_integer_))
  wide <- expect_cluster_oracle(matrix(1, 2, 3))
  expect_identical(wide$assignment, c(1L, 2L))
})

test_that("margins use the original optimum before lexicographic decisions", {
  # Once row 1 takes column 1, row 2 has no remaining positive alternative.
  # Nevertheless either selected edge can be absent from a GLOBAL optimum.
  actual <- expect_cluster_oracle(matrix(c(4, 4, 4, 4), 2, 2))
  expect_equal(actual$margins, c(0, 0))
  expect_true(all(actual$ambiguous))
})

test_that("zero-score links remain unmatched across rectangular problems", {
  examples <- list(
    matrix(c(0, 0, 5, 0, 0, 0), 3, 2, byrow = TRUE),
    matrix(c(0, 2, 0, 0, 0, 0, 0, 2), 2, 4, byrow = TRUE),
    matrix(c(8, 0, 6, 0), 4, 1),
    matrix(c(0, 7, 0, 7), 1, 4),
    matrix(0, 4, 3)
  )
  for (weights in examples) expect_cluster_oracle(weights)
})

test_that("empty dimensions return typed empty or unmatched diagnostics", {
  for (weights in list(matrix(numeric(), 0, 0),
                       matrix(numeric(), 0, 3),
                       matrix(numeric(), 3, 0))) {
    actual <- expect_cluster_oracle(weights)
    expect_type(actual$assignment, "integer")
    expect_type(actual$objective, "double")
    expect_type(actual$margins, "double")
    expect_type(actual$ambiguous, "logical")
    expect_length(actual$assignment, nrow(weights))
  }
})

test_that("disconnected components preserve global canonical row and column order", {
  weights <- matrix(0, 6, 7)
  weights[c(1, 4), c(2, 6)] <- 3
  weights[c(2, 5), c(1, 5)] <- matrix(c(9, 8, 8, 0), 2, byrow = TRUE)
  weights[6, 7] <- 2
  actual <- expect_cluster_oracle(weights)
  expect_identical(actual$assignment, c(2L, 5L, NA_integer_, 6L, 1L, 7L))
})

test_that("singleton groups avoid large dense assignment calls", {
  actual <- solve_cluster_assignment(diag(seq_len(1000)))
  expect_identical(actual$assignment, seq_len(1000))
  expect_equal(actual$objective, sum(seq_len(1000)))
  expect_equal(actual$margins, as.numeric(seq_len(1000)))
  expect_false(any(actual$ambiguous))
})

test_that("disabling diagnostics retains the exact canonical assignment", {
  weights <- matrix(c(3, 3, 0, 3, 3, 0, 0, 0, 0), 3, 3)
  actual <- solve_cluster_assignment(weights, diagnose_ties = FALSE)
  expected <- brute_cluster_assignment(weights)
  expect_identical(actual$assignment, expected$assignment)
  expect_equal(actual$objective, expected$objective)
  expect_true(all(is.na(actual$margins)))
  expect_true(all(is.na(actual$ambiguous)))
})

test_that("random small integer problems agree exactly with exhaustive search", {
  set.seed(6102026)
  for (nr in 1:4) {
    for (nc in 1:4) {
      for (replicate in 1:6) {
        weights <- matrix(sample(0:5, nr * nc, replace = TRUE), nr, nc)
        expect_cluster_oracle(weights)
      }
    }
  }
})

test_that("invalid score matrices and diagnostic switches fail informatively", {
  for (weights in list(1:3, matrix("1", 1, 1), matrix(TRUE, 1, 1),
                       matrix(NA_real_, 1, 1), matrix(NaN, 1, 1),
                       matrix(Inf, 1, 1), matrix(-1, 1, 1),
                       matrix(0.5, 1, 1))) {
    expect_error(solve_cluster_assignment(weights),
                 "finite nonnegative integer score matrix", fixed = TRUE)
  }
  expect_error(solve_cluster_assignment(matrix(2^53, 1, 1)),
               "exact integer assignment", fixed = TRUE)
  for (diagnose in list(NA, NULL, 1, c(TRUE, FALSE), "yes")) {
    expect_error(solve_cluster_assignment(matrix(1, 1, 1), diagnose),
                 "must be TRUE or FALSE", fixed = TRUE)
  }
})
