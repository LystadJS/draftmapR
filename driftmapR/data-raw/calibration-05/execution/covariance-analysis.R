# Study 05 repeated-panel covariance diagnostics. These diagnostics never alter
# a fitted covariance, pivot, delivery gate, or candidate region.

study05_cov_require <- function(x, columns, label) {
  if (!is.data.frame(x) || !all(columns %in% names(x)))
    stop(label, " must be a data frame containing: ", paste(columns, collapse = ", "), call. = FALSE)
  invisible(x)
}

study05_cov_key <- function(x, columns) {
  if (anyNA(x[, columns, drop = FALSE])) stop("Covariance keys cannot be missing.", call. = FALSE)
  if (!nrow(x)) return(character())
  # Length-prefix fields so user-facing identifiers cannot collide at separators.
  apply(x[, columns, drop = FALSE], 1L, function(z)
    paste(paste0(nchar(as.character(z)), ":", z), collapse = "|"))
}

study05_cov_matrix <- function(x) {
  matrix(c(x[1L], x[3L], x[3L], x[2L]), 2L, 2L)
}

study05_cov_axis <- function(v) {
  v <- v / sqrt(sum(v^2))
  if (v[which.max(abs(v))] < 0) v <- -v
  v
}

study05_cov_spectrum <- function(S, prefix) {
  out <- c(eigen_max = NA_real_, eigen_min = NA_real_, eigen_ratio = NA_real_,
    principal_dx = NA_real_, principal_dy = NA_real_, orientation_identified = 0)
  if (all(is.finite(S))) {
    eig <- eigen((S + t(S)) / 2, symmetric = TRUE)
    out[c("eigen_max", "eigen_min")] <- eig$values
    if (eig$values[1L] != 0) out["eigen_ratio"] <- eig$values[2L] / eig$values[1L]
    identified <- diff(rev(eig$values)) > 1e-8 * max(abs(eig$values))
    if (isTRUE(identified)) {
      out[c("principal_dx", "principal_dy")] <- study05_cov_axis(eig$vectors[, 1L])
      out["orientation_identified"] <- 1
    }
  }
  stats::setNames(out, paste0(prefix, names(out)))
}

study05_cov_ratio <- function(errors, covariance_components) {
  n <- nrow(errors)
  outer <- if (n >= 2L) stats::cov(errors) else matrix(NA_real_, 2L, 2L)
  average <- if (n) study05_cov_matrix(colMeans(covariance_components)) else matrix(NA_real_, 2L, 2L)
  out <- c(outer_var_dx = outer[1L, 1L], outer_var_dy = outer[2L, 2L], outer_cov_dx_dy = outer[1L, 2L],
    mean_var_dx = average[1L, 1L], mean_var_dy = average[2L, 2L], mean_cov_dx_dy = average[1L, 2L],
    outer_variance_trace = sum(diag(outer)), mean_estimated_variance_trace = sum(diag(average)),
    covariance_trace_ratio = NA_real_, generalized_ratio_min = NA_real_, generalized_ratio_max = NA_real_,
    generalized_min_dx = NA_real_, generalized_min_dy = NA_real_,
    generalized_max_dx = NA_real_, generalized_max_dy = NA_real_, generalized_orientation_identified = 0,
    principal_axis_angle_degrees = NA_real_,
    study05_cov_spectrum(outer, "outer_"), study05_cov_spectrum(average, "mean_"))
  if (is.finite(out["outer_variance_trace"]) && out["outer_variance_trace"] > 0 &&
      is.finite(out["mean_estimated_variance_trace"]))
    out["covariance_trace_ratio"] <- out["mean_estimated_variance_trace"] / out["outer_variance_trace"]
  status <- if (n < 2L) "insufficient_matched_errors" else if (!all(is.finite(outer)))
    "outer_covariance_nonfinite" else if (!isTRUE(out["outer_eigen_max"] > 0 &&
      out["outer_eigen_ratio"] > 1e-8)) "outer_covariance_not_spd" else if (!all(is.finite(average)))
    "mean_covariance_nonfinite" else "available"
  if (status == "available") {
    e <- eigen(outer, symmetric = TRUE)
    inverse_root <- e$vectors %*% diag(1 / sqrt(e$values)) %*% t(e$vectors)
    whitened <- inverse_root %*% average %*% inverse_root
    if (!all(is.finite(whitened))) status <- "generalized_matrix_nonfinite" else {
      g <- eigen(whitened / 2 + t(whitened) / 2, symmetric = TRUE)
      out[c("generalized_ratio_max", "generalized_ratio_min")] <- g$values
      identified <- diff(rev(g$values)) > 1e-8 * max(abs(g$values))
      if (isTRUE(identified)) {
        out[c("generalized_max_dx", "generalized_max_dy")] <- study05_cov_axis(inverse_root %*% g$vectors[, 1L])
        out[c("generalized_min_dx", "generalized_min_dy")] <- study05_cov_axis(inverse_root %*% g$vectors[, 2L])
        out["generalized_orientation_identified"] <- 1
      }
    }
  }
  if (all(out[c("outer_orientation_identified", "mean_orientation_identified")] == 1)) {
    cosine <- abs(sum(out[c("outer_principal_dx", "outer_principal_dy")] *
      out[c("mean_principal_dx", "mean_principal_dy")]))
    out["principal_axis_angle_degrees"] <- acos(min(1, max(0, cosine))) * 180 / pi
  }
  list(values = out, status = status, outer = outer, average = average)
}

study05_cov_describe <- function(values) {
  values <- values[is.finite(values)]
  n <- length(values)
  if (!n) return(c(n_finite = 0, mean = NA_real_, median = NA_real_, sd = NA_real_,
    q10 = NA_real_, q90 = NA_real_, q95 = NA_real_, maximum = NA_real_))
  c(n_finite = n, mean = mean(values), median = stats::median(values),
    sd = if (n > 1L) stats::sd(values) else NA_real_,
    stats::setNames(as.numeric(stats::quantile(values, c(.1, .9, .95), type = 7L)), c("q10", "q90", "q95")),
    maximum = max(values))
}

study05_covariance_analysis <- function(estimates, regions) {
  keys <- c("case_id", "frame", "entity")
  panel_keys <- c(keys, "dataset_id")
  components <- c("var_dx", "var_dy", "cov_dx_dy")
  study05_cov_require(estimates, c(panel_keys, "observed_success", "dx", "dy", "truth_dx", "truth_dy",
    "observed_jackknife_ok"), "estimates")
  study05_cov_require(regions, c(panel_keys, "method", "delivered", components), "regions")
  ekey <- study05_cov_key(estimates, panel_keys)
  rkey <- study05_cov_key(regions, c(panel_keys, "method"))
  if (anyDuplicated(ekey)) stop("Duplicate observed panel keys in covariance analysis.", call. = FALSE)
  if (anyDuplicated(rkey)) stop("Duplicate method panel keys in covariance analysis.", call. = FALSE)
  if (nrow(regions) && any(!study05_cov_key(regions, panel_keys) %in% ekey))
    stop("A covariance region has no matching observed panel.", call. = FALSE)
  summary <- deletions <- all_observed <- variability <- list()
  group <- study05_cov_key(estimates, keys)
  for (group_key in unique(group)) {
    e <- estimates[group == group_key, , drop = FALSE]
    e <- e[order(e$dataset_id), , drop = FALSE]
    meta <- e[1L, keys, drop = FALSE]
    errors <- cbind(e$dx - e$truth_dx, e$dy - e$truth_dy)
    finite_error <- !is.na(e$observed_success) & e$observed_success & apply(is.finite(errors), 1L, all)
    all_cov <- if (sum(finite_error) >= 2L) stats::cov(errors[finite_error, , drop = FALSE]) else matrix(NA_real_, 2L, 2L)
    all_observed[[length(all_observed) + 1L]] <- cbind(meta, data.frame(
      n_planned = nrow(e), n_observed_available = sum(!is.na(e$observed_success) & e$observed_success),
      n_finite_observed_error = sum(finite_error), covariance_cohort = "all successful finite observed errors",
      var_dx = all_cov[1L, 1L], var_dy = all_cov[2L, 2L], cov_dx_dy = all_cov[1L, 2L],
      as.list(study05_cov_spectrum(all_cov, "outer_")), row.names = NULL))
    for (method in c("wald", "jackknife_wald")) {
      method_regions <- regions[regions$method == method, , drop = FALSE]
      ri <- match(study05_cov_key(e, panel_keys), study05_cov_key(method_regions, panel_keys))
      r <- method_regions[ri, , drop = FALSE]
      cm <- as.matrix(r[, components, drop = FALSE])
      cov_available <- !is.na(ri) & apply(is.finite(cm), 1L, all)
      if (method == "jackknife_wald")
        cov_available <- cov_available & !is.na(e$observed_jackknife_ok) & e$observed_jackknife_ok
      matched <- finite_error & cov_available
      n <- sum(matched)
      fit <- study05_cov_ratio(errors[matched, , drop = FALSE], cm[matched, , drop = FALSE])
      cohort_ids <- e$dataset_id[matched]
      required <- seq_len(n)
      ratios <- c("covariance_trace_ratio", "generalized_ratio_min", "generalized_ratio_max")
      loo <- matrix(NA_real_, n, length(ratios), dimnames = list(NULL, ratios))
      loo_diagnostics <- matrix(NA_real_, n, length(fit$values), dimnames = list(NULL, names(fit$values)))
      attempted <- rep(n >= 20L, n)
      success <- rep(FALSE, n)
      status <- rep("fewer_than_20_matched_panels", n)
      if (n >= 20L) for (j in required) {
        z <- study05_cov_ratio(errors[matched, , drop = FALSE][-j, , drop = FALSE],
          cm[matched, , drop = FALSE][-j, , drop = FALSE])
        loo[j, ] <- z$values[ratios]
        loo_diagnostics[j, ] <- z$values
        status[j] <- z$status
        success[j] <- z$status == "available" && all(is.finite(loo[j, ]))
        if (z$status == "available" && !success[j]) status[j] <- "nonfinite_ratio"
      }
      if (n) deletions[[length(deletions) + 1L]] <- cbind(meta[rep(1L, n), , drop = FALSE],
        data.frame(method = method, excluded_dataset_id = cohort_ids,
          n_matched_before = n, n_matched_after = n - 1L, required = TRUE,
          attempted = attempted, success = success, failed_after_attempt = attempted & !success,
          unattempted_required = !attempted, status = status, loo_diagnostics, row.names = NULL))
      se_available <- n >= 20L && all(success) && fit$status == "available"
      ratio_se <- stats::setNames(rep(NA_real_, 3L), paste0(ratios, "_jackknife_mcse"))
      if (se_available) ratio_se[] <- sqrt((n - 1) / n * colSums(sweep(loo, 2L, colMeans(loo), "-")^2))
      se_status <- if (n < 20L) "fewer_than_20_matched_panels" else if (!all(success))
        "required_outer_deletion_failed" else if (fit$status != "available") "full_ratio_unavailable" else "available"
      delivered <- !is.na(r$delivered) & r$delivered
      traces <- rowSums(cm[matched, 1:2, drop = FALSE])
      summary[[length(summary) + 1L]] <- cbind(meta, data.frame(method = method,
        covariance_source = if (method == "wald") "bootstrap" else "observed_occurrence_jackknife",
        n_planned = nrow(e), n_observed_available = sum(!is.na(e$observed_success) & e$observed_success),
        n_finite_observed_error = sum(finite_error), n_covariance_available = sum(cov_available),
        n_covariance_pairs = n, n_region_delivered = sum(delivered),
        n_matched_region_delivered = sum(matched & delivered),
        covariance_cohort = "successful finite observed error AND available method covariance; delivery not required",
        covariance_availability = if (method == "wald") "finite bootstrap covariance components" else
          "finite observed jackknife covariance components AND observed_jackknife_ok",
        generalized_ratio_status = fit$status, ratio_se_status = se_status,
        n_outer_deletions_required = n, n_outer_deletions_attempted = sum(attempted),
        n_outer_deletions_successful = sum(success), n_outer_deletions_failed = sum(attempted & !success),
        n_outer_deletions_unattempted = sum(!attempted),
        as.list(fit$values), as.list(ratio_se),
        estimated_trace_cv = if (n >= 2L && mean(traces) > 0) stats::sd(traces) / mean(traces) else NA_real_,
        row.names = NULL))
      for (cohort in c("covariance_available", "matched_error_and_covariance")) {
        use <- if (cohort == "covariance_available") cov_available else matched
        selected <- cm[use, , drop = FALSE]
        eigenvalues <- if (nrow(selected)) t(vapply(seq_len(nrow(selected)), function(i)
          eigen(study05_cov_matrix(selected[i, ]), symmetric = TRUE, only.values = TRUE)$values,
          numeric(2L))) else matrix(numeric(), 0L, 2L)
        metrics <- cbind(selected, trace = rowSums(selected[, 1:2, drop = FALSE]),
          eigen_max = eigenvalues[, 1L], eigen_min = eigenvalues[, 2L])
        for (metric in colnames(metrics)) variability[[length(variability) + 1L]] <- cbind(meta,
          data.frame(method = method, cohort = cohort, metric = metric,
            as.list(study05_cov_describe(metrics[, metric])), row.names = NULL))
      }
    }
  }
  bind <- function(x) if (length(x)) { out <- do.call(rbind, x); rownames(out) <- NULL; out } else data.frame()
  list(summary = bind(summary), outer_deletions = bind(deletions),
    all_observed = bind(all_observed), variability = bind(variability))
}
