source("../contract.R", local = TRUE)

testthat::test_that("candidate gates retain the exact 20-pivot and 95 percent thresholds", {
  reason <- study05_nondelivery(TRUE, TRUE, TRUE,
    c(0L, 19L, 20L, 189L, 190L, 199L), geometry_ok = TRUE)
  testthat::expect_identical(reason, c("insufficient_pivots", "insufficient_pivots",
    "valid_fraction_below_095", "valid_fraction_below_095", "delivered", "delivered"))
  testthat::expect_identical(study05_nondelivery(TRUE, TRUE, TRUE, 19L,
    B = 19L, geometry_ok = TRUE), "insufficient_pivots")
  testthat::expect_identical(study05_nondelivery(TRUE, TRUE, TRUE, 20L,
    B = 20L, geometry_ok = TRUE), "delivered")
})

testthat::test_that("each upstream non-delivery reason has fixed precedence", {
  reason <- study05_nondelivery(
    c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE),
    c(FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE),
    c(0L, 0L, 0L, 19L, 189L, 190L, 190L),
    geometry_ok = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  testthat::expect_identical(reason, c("observed_unavailable",
    "observed_deletion_unavailable", "observed_covariance_invalid",
    "insufficient_pivots", "valid_fraction_below_095",
    "region_geometry_unavailable", "delivered"))
  # These are computational statuses only. Scientific null, movement, and
  # population-unidentified cases must never be inferred from these flags.
  testthat::expect_false(any(reason %in% c("null", "movement", "unidentified")))
  testthat::expect_identical(names(formals(study05_nondelivery)),
    c("observed_ok", "observed_deletions_ok", "observed_covariance_ok",
      "n_valid", "B", "geometry_ok"))
})

testthat::test_that("non-delivery inputs reject missingness and accidental recycling", {
  check <- function(observed_ok = TRUE, observed_deletions_ok = TRUE,
                    observed_covariance_ok = TRUE, n_valid = 199L,
                    B = 199L, geometry_ok = TRUE) {
    study05_nondelivery(observed_ok, observed_deletions_ok,
      observed_covariance_ok, n_valid, B, geometry_ok)
  }
  for (bad in list(NA, 1, "TRUE", matrix(TRUE))) {
    testthat::expect_error(check(observed_ok = bad), "logical values")
    testthat::expect_error(check(observed_deletions_ok = bad), "logical values")
    testthat::expect_error(check(observed_covariance_ok = bad), "logical values")
    testthat::expect_error(check(geometry_ok = bad), "logical values")
  }
  for (bad in list(NA_integer_, -1, 3.5, Inf, "199", TRUE, matrix(199))) {
    testthat::expect_error(check(n_valid = bad), "whole numbers")
  }
  for (bad in list(0L, -1L, NA_integer_, Inf, 2.5, c(199L, 199L))) {
    testthat::expect_error(check(B = bad), "whole numbers")
  }
  testthat::expect_error(check(n_valid = 200L), "cannot exceed B")
  testthat::expect_error(check(n_valid = integer()), "common length")
  testthat::expect_error(check(observed_ok = logical()), "common length")
  testthat::expect_error(check(observed_ok = rep(TRUE, 2L),
    n_valid = rep(199L, 4L)), "common length")
})

testthat::test_that("deletion accounting distinguishes failed and blocked occurrences", {
  ledger <- data.frame(unit_index = 1:5, multiplicity = c(3L, 0L, 2L, 1L, 4L),
    attempted = c(TRUE, FALSE, TRUE, FALSE, TRUE),
    success = c(TRUE, FALSE, FALSE, FALSE, TRUE))
  counts <- study05_validate_ledger(ledger)
  testthat::expect_equal(unname(unlist(counts)), c(4, 3, 2, 1, 1, 10, 9, 7, 2, 1))
  testthat::expect_equal(counts$required_unique,
    counts$attempted_unique + counts$unattempted_required_unique)
  testthat::expect_equal(counts$attempted_unique,
    counts$successful_unique + counts$failed_unique)
  testthat::expect_equal(counts$required_occurrences,
    counts$attempted_occurrences + counts$unattempted_required_occurrences)
  testthat::expect_equal(counts$attempted_occurrences,
    counts$successful_occurrences + counts$failed_occurrences)
  testthat::expect_equal(study05_validate_ledger(ledger[c(5L, 3L, 1L, 4L, 2L), ]), counts)
  # Physically expand weighted occurrences to check counts independently.
  expanded <- ledger[rep(seq_len(nrow(ledger)), ledger$multiplicity), ]
  testthat::expect_equal(counts$failed_occurrences,
    sum(expanded$attempted & !expanded$success))
  testthat::expect_equal(counts$unattempted_required_occurrences,
    sum(!expanded$attempted))
})

testthat::test_that("all-blocked, zero-weight and empty ledgers preserve identities", {
  ledger <- data.frame(unit_index = 1:3, multiplicity = c(2L, 0L, 1L),
    attempted = FALSE, success = FALSE)
  counts <- study05_validate_ledger(ledger)
  testthat::expect_equal(counts$required_unique, 2L)
  testthat::expect_equal(counts$failed_unique, 0L)
  testthat::expect_equal(counts$unattempted_required_unique, 2L)
  testthat::expect_equal(counts$unattempted_required_occurrences, 3L)
  zero <- ledger; zero$multiplicity <- 0L
  testthat::expect_true(all(study05_validate_ledger(zero) == 0))
  testthat::expect_true(all(study05_validate_ledger(ledger[FALSE, ]) == 0))
})

testthat::test_that("ledger validation rejects impossible flags and invalid multiplicities", {
  ledger <- data.frame(unit_index = 1:3, multiplicity = c(2L, 0L, 1L),
    attempted = c(TRUE, FALSE, FALSE), success = c(TRUE, FALSE, FALSE))
  altered <- ledger; altered$attempted[2L] <- TRUE
  testthat::expect_error(study05_validate_ledger(altered), "zero-multiplicity")
  altered <- ledger; altered$success[3L] <- TRUE
  testthat::expect_error(study05_validate_ledger(altered), "unattempted")
  altered <- ledger; altered$unit_index[3L] <- 1L
  testthat::expect_error(study05_validate_ledger(altered), "duplicate unit indices")
  for (bad in list(-1, 1.5, NA_real_, Inf, "1", TRUE)) {
    altered <- ledger; altered$multiplicity <- rep(bad, 3L)
    testthat::expect_error(study05_validate_ledger(altered), "whole numbers")
  }
  for (bad in list(0L, NA_integer_, 1.5)) {
    altered <- ledger; altered$unit_index[1L] <- bad
    testthat::expect_error(study05_validate_ledger(altered), "whole numbers")
  }
  for (field in c("attempted", "success")) {
    altered <- ledger; altered[[field]] <- c(1, 0, 0)
    testthat::expect_error(study05_validate_ledger(altered), "logical values")
    altered <- ledger; altered[[field]][1L] <- NA
    testthat::expect_error(study05_validate_ledger(altered), "logical values")
  }
  testthat::expect_error(study05_validate_ledger(ledger[-1L]), "data frame")
  testthat::expect_error(study05_validate_ledger(as.list(ledger)), "data frame")
  altered <- ledger; names(altered)[2L] <- "unit_index"
  testthat::expect_error(study05_validate_ledger(altered), "unique column names")
})

testthat::test_that("Gaussian Gram variance inflation agrees with the exact double sum", {
  for (m in c(1L, 2L, 12L, 40L, 160L)) for (rho in c(0, 0.4, 0.8, -0.4)) {
    diagnostic <- study05_gaussian_gram_vif(m, rho)
    unit_covariance <- rho^abs(outer(seq_len(m), seq_len(m), "-"))
    exact_vif <- sum(unit_covariance^2) / m
    testthat::expect_equal(diagnostic$gram_vif, exact_vif, tolerance = 1e-13)
    testthat::expect_equal(diagnostic$diagnostic_effective_m, m / exact_vif,
      tolerance = 1e-13)
    testthat::expect_equal(diagnostic$m, m)
    testthat::expect_gte(diagnostic$gram_vif, 1)
  }
  testthat::expect_equal(study05_gaussian_gram_vif(40L, 0)$diagnostic_effective_m, 40)
  testthat::expect_lt(study05_gaussian_gram_vif(40L, 0.8)$diagnostic_effective_m, 40)
  testthat::expect_equal(study05_gaussian_gram_vif(12L, -0.8)$gram_vif,
    study05_gaussian_gram_vif(12L, 0.8)$gram_vif)
})

testthat::test_that("Gaussian Gram diagnostics require a stationary finite scalar contract", {
  for (bad in list(0L, -1L, 1.5, NA_integer_, Inf, c(12L, 40L), TRUE)) {
    testthat::expect_error(study05_gaussian_gram_vif(bad, 0.4), "whole numbers")
  }
  for (bad in list(-1, 1, 1.1, NA_real_, Inf, c(0, 0.4), "0.4", TRUE)) {
    testthat::expect_error(study05_gaussian_gram_vif(40L, bad), "strictly between")
  }
})
