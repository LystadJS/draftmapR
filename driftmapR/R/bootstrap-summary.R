# Conditional summaries of complete successful replicates. The caller supplies
# the fixed target layout: a failure must never silently change a denominator.
summarize_bootstrap <- function(observed, coordinates, movement_draws,
                                coordinate_draws, B, probs, min_success,
                                n_valid) {
  movement_keys <- c("entity", "time_from", "time_to")
  coordinate_keys <- c("entity", "time", "period_index")
  movement_values <- c("dx", "dy", "distance")
  coordinate_values <- c("x", "y")
  movement_blocks <- bootstrap_draw_blocks(movement_draws, observed,
                                           movement_keys, n_valid)
  coordinate_blocks <- bootstrap_draw_blocks(coordinate_draws, coordinates,
                                             coordinate_keys, n_valid)
  status <- if (n_valid == 0L) {
    "no_successful_replicates"
  } else if (n_valid == 1L) {
    "insufficient_replicates"
  } else if (n_valid / B < min_success) {
    "below_success_threshold"
  } else "ok"

  out <- observed[movement_keys]
  rownames(out) <- NULL
  for (v in movement_values) out[[paste0("observed_", v)]] <- observed[[v]]
  statistic_names <- c(paste0("mean_", movement_values),
                       paste0("sd_", movement_values), "cov_dx_dy",
                       paste0("mcse_mean_", movement_values))
  for (v in statistic_names) out[[v]] <- rep(NA_real_, nrow(out))
  out$n_attempted <- rep(B, nrow(out))
  out$n_valid <- rep(n_valid, nrow(out))
  out$n_failed <- rep(B - n_valid, nrow(out))
  out$success_rate <- rep(n_valid / B, nrow(out))
  out$summary_status <- rep(status, nrow(out))

  quantile_rows <- rep(seq_len(nrow(out)), each = 3L * length(probs))
  quantiles <- out[quantile_rows, movement_keys, drop = FALSE]
  rownames(quantiles) <- NULL
  quantiles$measure <- rep(rep(movement_values, each = length(probs)),
                           times = nrow(out))
  quantiles$probability <- rep(probs, times = 3L * nrow(out))
  quantiles$value <- rep(NA_real_, nrow(quantiles))
  quantiles$n_valid <- rep(n_valid, nrow(quantiles))

  coordinate_summary <- coordinates[coordinate_keys]
  rownames(coordinate_summary) <- NULL
  coordinate_statistic_names <- c("mean_x", "mean_y", "var_x", "var_y", "cov_xy")
  for (v in coordinate_statistic_names) {
    coordinate_summary[[v]] <- rep(NA_real_, nrow(coordinate_summary))
  }
  coordinate_summary$n_attempted <- rep(B, nrow(coordinate_summary))
  coordinate_summary$n_valid <- rep(n_valid, nrow(coordinate_summary))
  coordinate_summary$summary_status <- rep(status, nrow(coordinate_summary))

  if (status == "ok") {
    movement_matrices <- lapply(movement_values, function(v) {
      matrix(unlist(lapply(movement_blocks, `[[`, v), use.names = FALSE),
             nrow = nrow(observed), ncol = n_valid)
    })
    for (i in seq_len(nrow(observed))) {
      samples <- lapply(movement_matrices, function(z) z[i, ])
      moments <- lapply(samples, bootstrap_scaled_moments)
      values <- c(vapply(moments, `[[`, numeric(1), "mean"),
                  vapply(moments, `[[`, numeric(1), "sd"),
                  bootstrap_scaled_cov(samples[[1L]], samples[[2L]]),
                  vapply(moments, `[[`, numeric(1), "mcse"))
      qs <- unlist(lapply(samples, stats::quantile, probs = probs,
                          names = FALSE, type = 7), use.names = FALSE)
      if (all(is.finite(c(values, qs)))) {
        out[i, statistic_names] <- as.list(values)
        qidx <- (i - 1L) * 3L * length(probs) + seq_len(3L * length(probs))
        quantiles$value[qidx] <- qs
      } else out$summary_status[i] <- "numerical_failure"
    }
    coordinate_matrices <- lapply(coordinate_values, function(v) {
      matrix(unlist(lapply(coordinate_blocks, `[[`, v), use.names = FALSE),
             nrow = nrow(coordinates), ncol = n_valid)
    })
    for (i in seq_len(nrow(coordinates))) {
      x <- coordinate_matrices[[1L]][i, ]
      y <- coordinate_matrices[[2L]][i, ]
      values <- c(bootstrap_scaled_moments(x)[["mean"]],
                  bootstrap_scaled_moments(y)[["mean"]],
                  bootstrap_scaled_cov(x, x), bootstrap_scaled_cov(y, y),
                  bootstrap_scaled_cov(x, y))
      if (all(is.finite(values))) {
        coordinate_summary[i, coordinate_statistic_names] <- as.list(values)
      } else coordinate_summary$summary_status[i] <- "numerical_failure"
    }
  }
  list(summary = out, quantiles = quantiles,
       coordinate_summary = coordinate_summary)
}

# Entity/time columns stay in their original types. A character encoding of
# numeric dates or IDs can merge distinct target rows and is deliberately absent.
bootstrap_draw_blocks <- function(draws, template, keys, n_valid) {
  if (n_valid == 0L) return(list())
  if (!is.data.frame(draws) || !"replicate_id" %in% names(draws)) {
    stop("Bootstrap summary draws lack replicate IDs.", call. = FALSE)
  }
  # No adjacent shared entities is a valid, empty movement target. Replicate IDs
  # then cannot be recovered from the empty table, but the global ledger can.
  if (nrow(template) == 0L && nrow(draws) == 0L) {
    return(rep(list(draws), n_valid))
  }
  replicate_ids <- unique(draws$replicate_id)
  if (anyNA(replicate_ids) || length(replicate_ids) != n_valid) {
    stop("Bootstrap summary replicate count differs from the success ledger.",
         call. = FALSE)
  }
  expected <- template[keys]
  rownames(expected) <- NULL
  lapply(replicate_ids, function(id) {
    block <- draws[draws$replicate_id == id, , drop = FALSE]
    actual <- block[keys]
    rownames(actual) <- NULL
    if (!identical(actual, expected)) {
      stop("Bootstrap summary target keys differ from the observed layout.",
           call. = FALSE)
    }
    block
  })
}

bootstrap_scaled_moments <- function(x) {
  magnitude <- max(abs(x))
  if (magnitude == 0) return(c(mean = 0, sd = 0, mcse = 0))
  normalized <- x / magnitude
  normalized_sd <- stats::sd(normalized)
  c(mean = mean(normalized) * magnitude,
    sd = normalized_sd * magnitude,
    mcse = (normalized_sd / sqrt(length(x))) * magnitude)
}

bootstrap_scaled_cov <- function(x, y) {
  sx <- max(abs(x))
  sy <- max(abs(y))
  if (sx == 0 || sy == 0) return(0)
  value <- stats::cov(x / sx, y / sy)
  # Multiplying the small coefficient first avoids avoidable overflow in sx*sy.
  if (value == 0) return(0)
  if (abs(value) > 1) {
    (value * min(sx, sy)) * max(sx, sy)
  } else (value * max(sx, sy)) * min(sx, sy)
}
