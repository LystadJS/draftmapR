# Frozen design helpers for study 05. These helpers do not generate panels,
# fit an estimator, or classify scientific truth. Population identification is
# determined by the design before constructing the stochastic denominator.

study05_contract_whole <- function(x, name, minimum = 0, scalar = FALSE) {
  if (!is.numeric(x) || is.complex(x) || !is.null(dim(x)) ||
      (scalar && length(x) != 1L) || anyNA(x) ||
      any(!is.finite(x)) || any(x < minimum | x != floor(x)) ||
      any(x > .Machine$integer.max)) {
    stop(name, " must contain finite whole numbers >= ", minimum,
         if (scalar) " and have length one" else "", call. = FALSE)
  }
  invisible(x)
}

study05_contract_flags <- function(x, name) {
  if (!is.logical(x) || !is.null(dim(x)) || anyNA(x)) {
    stop(name, " must contain logical values without missingness", call. = FALSE)
  }
  invisible(x)
}

# Fixed study-operational first-failure precedence. observed_ok includes the
# inherited evaluator's registration into A. Evaluation-only blocks require
# a separate flag and candidate interval availability NA, not a claim of
# computational candidate failure (see analysis-contract.md).
# No additional spectral, conditioning, dependence, or
# effective-unit-count gate is permitted here. The 20-pivot and 95% gates both
# apply; with B = 199 the fraction gate requires at least 190 valid pivots.
study05_nondelivery <- function(observed_ok, observed_deletions_ok,
                               observed_covariance_ok, n_valid, B = 199L,
                               geometry_ok) {
  study05_contract_whole(B, "B", minimum = 1, scalar = TRUE)
  flags <- list(observed_ok = observed_ok,
                observed_deletions_ok = observed_deletions_ok,
                observed_covariance_ok = observed_covariance_ok,
                geometry_ok = geometry_ok)
  for (name in names(flags)) study05_contract_flags(flags[[name]], name)
  study05_contract_whole(n_valid, "n_valid")
  if (any(n_valid > B)) stop("n_valid cannot exceed B", call. = FALSE)
  arguments <- c(flags, list(n_valid = n_valid))
  sizes <- lengths(arguments)
  size <- max(sizes)
  if (size < 1L || any(!sizes %in% c(1L, size))) {
    stop("Inputs must be nonempty with a common length or length one",
         call. = FALSE)
  }
  arguments <- lapply(arguments, rep_len, length.out = size)
  reason <- rep("delivered", size)
  # Apply from last to first so earlier failures always take precedence.
  reason[!arguments$geometry_ok] <- "region_geometry_unavailable"
  reason[arguments$n_valid < 0.95 * B] <- "valid_fraction_below_095"
  reason[arguments$n_valid < 20L] <- "insufficient_pivots"
  reason[!arguments$observed_covariance_ok] <- "observed_covariance_invalid"
  reason[!arguments$observed_deletions_ok] <- "observed_deletion_unavailable"
  reason[!arguments$observed_ok] <- "observed_unavailable"
  reason
}

# Each row represents one original unit, including units with zero weight.
# A required deletion has positive multiplicity. An unsuccessful unattempted
# deletion is blocked, not a failed fit. Occurrence counts expand each row by
# its multiplicity; a failed required deletion cannot be silently discarded.
study05_validate_ledger <- function(ledger) {
  fields <- c("unit_index", "multiplicity", "attempted", "success")
  if (!is.data.frame(ledger) || anyDuplicated(names(ledger)) ||
      !all(fields %in% names(ledger))) {
    stop("ledger must be a data frame with unique column names and columns: ",
         paste(fields, collapse = ", "), call. = FALSE)
  }
  study05_contract_whole(ledger$unit_index, "unit_index", minimum = 1)
  study05_contract_whole(ledger$multiplicity, "multiplicity")
  study05_contract_flags(ledger$attempted, "attempted")
  study05_contract_flags(ledger$success, "success")
  if (anyDuplicated(ledger$unit_index)) {
    stop("ledger has duplicate unit indices", call. = FALSE)
  }
  required <- ledger$multiplicity > 0
  attempted <- ledger$attempted
  success <- ledger$success
  if (any(attempted & !required)) {
    stop("A zero-multiplicity unit cannot have an attempted deletion", call. = FALSE)
  }
  if (any(success & !attempted)) {
    stop("An unattempted deletion cannot be successful", call. = FALSE)
  }
  failed <- attempted & !success
  blocked <- required & !attempted
  occurrence_count <- function(rows) sum(as.double(ledger$multiplicity[rows]))
  counts <- data.frame(
    required_unique = sum(required),
    attempted_unique = sum(attempted),
    successful_unique = sum(success),
    failed_unique = sum(failed),
    unattempted_required_unique = sum(blocked),
    required_occurrences = occurrence_count(required),
    attempted_occurrences = occurrence_count(attempted),
    successful_occurrences = occurrence_count(success),
    failed_occurrences = occurrence_count(failed),
    unattempted_required_occurrences = occurrence_count(blocked)
  )
  stopifnot(
    counts$required_unique == counts$attempted_unique +
      counts$unattempted_required_unique,
    counts$attempted_unique == counts$successful_unique + counts$failed_unique,
    counts$required_occurrences == counts$attempted_occurrences +
      counts$unattempted_required_occurrences,
    counts$attempted_occurrences == counts$successful_occurrences +
      counts$failed_occurrences
  )
  counts
}

# Exact finite-m variance inflation for Gaussian Gram products under the
# separable stationary AR(1) unit correlation C[j,k] = rho^abs(j-k).
# Isserlis' identity makes the product covariance proportional to C[j,k]^2.
# This diagnostic assumes the stipulated zero-mean separable Gaussian model;
# it is not a general effective sample size for the nonlinear full estimator.
# Neither gram_vif nor diagnostic_effective_m alters resampling, covariance
# normalization, studentization, delivery gates, or the estimator's unit m.
study05_gaussian_gram_vif <- function(m, rho) {
  study05_contract_whole(m, "m", minimum = 1, scalar = TRUE)
  if (!is.numeric(rho) || is.complex(rho) || length(rho) != 1L ||
      !is.null(dim(rho)) || anyNA(rho) || !is.finite(rho) || abs(rho) >= 1) {
    stop("rho must be one finite number strictly between -1 and 1", call. = FALSE)
  }
  lag <- seq_len(m - 1L)
  vif <- 1 + 2 * sum((1 - lag / m) * rho^(2 * lag))
  data.frame(m = as.integer(m), rho = rho, gram_vif = vif,
             diagnostic_effective_m = m / vif)
}
