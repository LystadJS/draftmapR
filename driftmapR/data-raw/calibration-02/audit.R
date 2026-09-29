# Compare preselected study-02 jobs with the public R-package implementation.
# This is an engineering equivalence audit, not additional coverage evidence.

study02_public_audit <- function(result, generated, B) {
  tolerance <- 1e-9
  if (!is.numeric(B) || length(B) != 1L || !is.finite(B) || B < 1L ||
      B != floor(B) || !is.list(result) || !is.list(generated)) {
    stop("Audit requires a result, generated data, and a positive integer B.", call. = FALSE)
  }
  B <- as.integer(B)
  m <- result$job$m
  if (!is.numeric(m) || length(m) != 1L || !is.finite(m) || m < 2L ||
      m != floor(m) || !is.matrix(result$weights) || nrow(result$weights) < B ||
      ncol(result$weights) != m || any(!is.finite(result$weights)) ||
      any(result$weights < 0) || any(result$weights != floor(result$weights)) ||
      any(rowSums(result$weights) != m) || !is.matrix(result$streams) ||
      nrow(result$streams) < B || ncol(result$streams) != 7L ||
      anyNA(result$streams)) {
    stop("Audit weights or RNG streams are malformed.", call. = FALSE)
  }
  model <- generated$model
  target_ids <- model$target_ids
  n_targets <- length(target_ids)
  if (length(generated$features) != m || !is.list(result$panels) ||
      !all(names(model$anchors) %in% names(result$panels))) {
    stop("Audit model, features, and anchor panels disagree.", call. = FALSE)
  }
  maximum_difference <- function(a, b) {
    if (!identical(dim(a), dim(b)) || any(!is.finite(a)) || any(!is.finite(b))) return(Inf)
    max(abs(a - b), 0)
  }
  rows <- lapply(names(model$anchors), function(anchor_name) {
    anchor_rows <- model$anchors[[anchor_name]]
    panel <- result$panels[[anchor_name]]
    if (!is.list(panel) || !is.matrix(panel$estimates$refit_plugin) ||
        !identical(dim(panel$estimates$refit_plugin), c(n_targets, 2L)) ||
        length(dim(panel$values$refit_plugin)) != 3L ||
        !identical(dim(panel$values$refit_plugin)[2:3], c(n_targets, 2L)) ||
        dim(panel$values$refit_plugin)[1L] < B ||
        length(panel$success$refit_plugin) < B || anyNA(panel$success$refit_plugin)) {
      stop("Audit panel has malformed target vectors or success ledger: ", anchor_name,
           call. = FALSE)
    }
    observed <- driftmapR::embed_snapshots(generated$data, generated$features,
      method = "pca", periods = 1:2, standardize = "none")
    observed <- driftmapR::align_snapshots(observed, reference = "previous",
      scale = FALSE, anchors = model$ids[anchor_rows])
    baseline <- observed$aligned[observed$aligned$period_index == 1L, ]
    baseline <- baseline[match(model$ids, baseline$entity), ]
    public_to_population <- study02_register(
      as.matrix(baseline[c("x", "y")]) / sqrt(m), model$population_points,
      anchor_rows)$rotation
    movement <- driftmapR::measure_drift(observed)
    movement <- movement[match(target_ids, movement$entity), ]
    observed_vectors <- (as.matrix(movement[c("dx", "dy")]) / sqrt(m)) %*%
      public_to_population
    estimate_difference <- maximum_difference(observed_vectors,
                                               panel$estimates$refit_plugin)
    design <- driftmapR::paired_unit_design(generated$unit_map,
      assumptions = "Independently generated paired Gaussian measurement units in a prespecified simulation audit.")
    boot <- suppressWarnings(driftmapR::bootstrap_drift(observed, design,
      B = B, seed = result$job$bootstrap_seed, keep = "replicates",
      min_success = 0.95))$bootstrap
    public_weights <- do.call(rbind, lapply(boot$draws,
      function(x) as.integer(x$feature_weights[generated$features])))
    public_streams <- do.call(rbind, lapply(boot$draws, `[[`, "rng_stream"))
    count_difference <- maximum_difference(public_weights,
                                            result$weights[seq_len(B), , drop = FALSE])
    stream_agreement <- identical(unname(public_streams),
                                   unname(result$streams[seq_len(B), , drop = FALSE]))
    ledger_agreement <- identical(as.logical(boot$attempts$success),
                                   as.logical(panel$success$refit_plugin[seq_len(B)]))
    plugin_difference <- oracle_difference <- 0
    public_oracle_success <- rep(FALSE, B)
    for (b in which(boot$attempts$success)) {
      movement <- boot$replicates[boot$replicates$replicate_id == b, ]
      movement <- movement[match(target_ids, movement$entity), ]
      raw_vectors <- as.matrix(movement[c("dx", "dy")]) / sqrt(m)
      expected_plugin <- matrix(panel$values$refit_plugin[b, , ], nrow = n_targets,
                                 ncol = 2L)
      plugin_difference <- max(plugin_difference, maximum_difference(
        raw_vectors %*% public_to_population, expected_plugin))
      # Direct population registration uses the public draw's entire baseline;
      # the resulting common rotation is applied to that whole displacement.
      oracle_rotation <- tryCatch({
        baseline <- boot$coordinates[boot$coordinates$replicate_id == b &
          boot$coordinates$period_index == 1L, ]
        baseline <- baseline[match(model$ids, baseline$entity), ]
        study02_register(as.matrix(baseline[c("x", "y")]) / sqrt(m),
                           model$population_points, anchor_rows)$rotation
      }, error = function(e) NULL)
      if (!is.null(oracle_rotation)) {
        public_oracle_success[b] <- TRUE
        expected_oracle <- matrix(panel$values$refit_oracle[b, , ],
                                   nrow = n_targets, ncol = 2L)
        oracle_difference <- max(oracle_difference, maximum_difference(
          raw_vectors %*% oracle_rotation, expected_oracle))
      }
    }
    oracle_ledger_agreement <- identical(public_oracle_success,
      as.logical(panel$success$refit_oracle[seq_len(B)]))
    passed <- estimate_difference <= tolerance && plugin_difference <= tolerance &&
      oracle_difference <= tolerance && count_difference == 0 && stream_agreement &&
      ledger_agreement && oracle_ledger_agreement
    if (!passed) {
      stop(sprintf(paste0("Public PCA/bootstrap audit discrepancy for m=%s dataset=%s anchors=%s: ",
        "estimate=%g plugin=%g oracle=%g counts=%g streams=%s failures=%s oracle_failures=%s."),
        m, result$job$dataset_id, anchor_name, estimate_difference, plugin_difference,
        oracle_difference, count_difference, stream_agreement, ledger_agreement,
        oracle_ledger_agreement), call. = FALSE)
    }
    data.frame(m = m, dataset_id = result$job$dataset_id, anchors = anchor_name,
      B = B, n_attempted = nrow(boot$attempts), n_valid = sum(boot$attempts$success),
      max_estimate_abs_diff = estimate_difference,
      max_plugin_vector_abs_diff = plugin_difference,
      max_oracle_vector_abs_diff = oracle_difference,
      max_feature_count_diff = count_difference, streams_identical = stream_agreement,
      failure_ledger_identical = ledger_agreement,
      oracle_ledger_identical = oracle_ledger_agreement,
      tolerance = tolerance, passed = passed)
  })
  do.call(rbind, rows)
}
