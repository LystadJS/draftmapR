# Independent fixtures and oracles for the paired-unit bootstrap contract.
# Exact rank-two feature blocks keep the successful-case tests away from
# accidental spectral degeneracies. A separate two-singleton design gives
# known, unavoidable rank failures when one feature is drawn twice.
bootstrap_fixture <- function(method = "pca", standardize = "none",
                              reference = "previous", churn = FALSE,
                              dates = FALSE, singleton = FALSE, scale = FALSE) {
  cloud <- fixture_cloud()
  loading <- matrix(c(1, 0, 0, 1, 2, .2, -.4, 1.1,
                      .8, -.3, .5, 1.7, 1.4, .4, -.2, .9), nrow = 2L)
  if (singleton) loading <- diag(2L)
  features <- paste0("f", seq_len(ncol(loading)))
  times <- if (dates) as.Date("2024-01-01") + c(0, 31, 60) else 1:3
  data <- do.call(rbind, lapply(seq_along(times), function(i) {
    z <- as.matrix(cloud[c("x", "y")])
    z[6:8, ] <- z[6:8, ] + (i - 1) * matrix(c(.4, -.1, .2, .1, .3, -.2), ncol = 2L)
    values <- as.data.frame(z %*% loading)
    names(values) <- features
    out <- cbind(data.frame(entity = cloud$entity, time = times[i],
                           cluster = rep(c("a", "b"), each = 4L)), values)
    if (churn && i == 2L) out <- out[out$entity != "H", , drop = FALSE]
    if (churn && i == 3L) out$entity[out$entity == "H"] <- "I"
    out
  }))
  fit <- embed_snapshots(data, features = features, method = method,
                         standardize = standardize) |>
    align_snapshots(reference = reference, anchors = LETTERS[1:5], scale = scale)
  units <- stats::setNames(if (singleton) c("u1", "u2") else
                            rep(paste0("u", 1:4), each = 2L), features)
  list(object = fit, units = units, data = data, features = features,
       design = paired_unit_design(units,
         assumptions = "Independent exchangeable measurement blocks; all entities and periods remain paired."))
}

bootstrap_with_saved_rng <- function(code) {
  kind <- RNGkind()
  existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old <- if (existed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    do.call(RNGkind, as.list(kind))
    if (existed) assign(".Random.seed", old, envir = .GlobalEnv) else
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
        rm(".Random.seed", envir = .GlobalEnv)
  })
  eval(substitute(code), envir = parent.frame())
}

bootstrap_oracle_draws <- function(units, B, seed, strata = NULL) {
  bootstrap_with_saved_rng({
    RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
    set.seed(seed)
    stream <- get(".Random.seed", envir = .GlobalEnv)
    ids <- sort(unique(unname(units)), method = "radix")
    if (is.null(strata)) strata <- stats::setNames(rep("all", length(ids)), ids)
    out <- vector("list", B)
    for (b in seq_len(B)) {
      assign(".Random.seed", stream, envir = .GlobalEnv)
      counts <- stats::setNames(integer(length(ids)), ids)
      for (stratum in sort(unique(unname(strata)), method = "radix")) {
        group <- ids[strata[ids] == stratum]
        sampled <- sample.int(length(group), length(group), replace = TRUE)
        counts[group] <- tabulate(sampled, nbins = length(group))
      }
      out[[b]] <- list(unit_counts = counts,
                       feature_weights = stats::setNames(unname(counts[units]), names(units)),
                       rng_stream = stream)
      stream <- parallel::nextRNGStream(stream)
    }
    out
  })
}

# Oracle: independently refit and first align temporal maps, then apply one
# no-scale rigid change of frame to every row. Orthogonal equivariance makes
# this algebraically equivalent to orienting the baseline before chaining.
bootstrap_oracle_fit <- function(fixture, weights) {
  settings <- fixture$object$settings
  fit <- embed_snapshots(fixture$data, fixture$features,
                          method = settings$embedding$method,
                          standardize = settings$embedding$standardize,
                          feature_weights = weights) |>
    align_snapshots(reference = settings$reference, scale = settings$scale,
                    anchors = settings$anchors, rank_tol = settings$rank_tol)
  ids <- settings$anchors
  first <- fit$aligned[fit$aligned$period_index == 1L, ]
  target <- fixture$object$aligned[fixture$object$aligned$period_index == 1L, ]
  source_xy <- as.matrix(first[match(ids, first$entity), c("x", "y")])
  target_xy <- as.matrix(target[match(ids, target$entity), c("x", "y")])
  source_center <- colMeans(source_xy)
  target_center <- colMeans(target_xy)
  cross <- svd(crossprod(sweep(source_xy, 2L, source_center),
                        sweep(target_xy, 2L, target_center)))
  rotation <- cross$u %*% t(cross$v)
  fit$aligned[c("x", "y")] <- sweep(
    sweep(as.matrix(fit$aligned[c("x", "y")]), 2L, source_center) %*% rotation,
    2L, target_center, "+")
  list(movement = measure_drift(fit), coordinates = fit$aligned)
}

test_that("paired-unit design requires an explicit complete scientific declaration", {
  good <- c(a = "one", b = "one", c = "two", d = "two")
  expect_no_error(paired_unit_design(good, assumptions = "IID paired two-column measurements."))
  expect_error(paired_unit_design(good), "assum")
  expect_error(paired_unit_design(good, assumptions = "  "), "assum")
  expect_error(paired_unit_design(good, assumptions = NA_character_), "assum")
  expect_error(paired_unit_design(unname(good), assumptions = "IID"), "name|feature")
  bad <- good; names(bad)[2L] <- names(bad)[1L]
  expect_error(paired_unit_design(bad, assumptions = "IID"), "unique|duplicat|name")
  bad <- good; bad[2L] <- NA_character_
  expect_error(paired_unit_design(bad, assumptions = "IID"), "unit|missing")
  expect_error(paired_unit_design(c(a = "one", b = "one", c = "two"), assumptions = "IID"),
               "equal|width")
  expect_error(paired_unit_design(c(a = "one", b = "one"), assumptions = "IID"),
               "two|2|unit")
  expect_error(paired_unit_design(good, assumptions = "IID", strata = c(one = "A")),
               "strat|unit")
  expect_error(paired_unit_design(good, assumptions = "IID", strata = c(one = "A", two = NA)),
               "strat|missing")
})

test_that("bootstrap draws independently match L'Ecuyer streams and multinomial blocks", {
  f <- bootstrap_fixture()
  fit <- bootstrap_drift(f$object, f$design, B = 12L, seed = 230L, keep = "replicates")
  expected <- bootstrap_oracle_draws(f$units, 12L, 230L)
  expect_length(fit$bootstrap$draws, 12L)
  for (b in 1:12) {
    actual <- fit$bootstrap$draws[[b]]
    expect_identical(actual$rng_stream, expected[[b]]$rng_stream)
    expect_equal(actual$unit_counts[names(expected[[b]]$unit_counts)], expected[[b]]$unit_counts)
    expect_equal(actual$feature_weights[f$features], expected[[b]]$feature_weights)
    expect_equal(sum(actual$unit_counts), 4L)
    expect_equal(sum(actual$feature_weights), 8L)
    expect_equal(unname(actual$feature_weights[c(1L, 3L, 5L, 7L)]),
                 unname(actual$feature_weights[c(2L, 4L, 6L, 8L)]))
  }
  expect_true(all(fit$bootstrap$attempts$success))
  expect_identical(fit$bootstrap$observed, measure_drift(f$object))
  expect_identical(fit[names(fit) != "bootstrap"], f$object[names(f$object) != "bootstrap"])
})

test_that("strata preserve fixed unit counts and do not depend on declaration ordering", {
  f <- bootstrap_fixture()
  strata <- c(u1 = "left", u2 = "left", u3 = "right", u4 = "right")
  d <- paired_unit_design(f$units, assumptions = "Independent blocks within strata.", strata = strata)
  a <- bootstrap_drift(f$object, d, B = 10L, seed = 82L)
  reverse <- paired_unit_design(rev(f$units), assumptions = "Independent blocks within strata.",
                                strata = rev(strata))
  b <- bootstrap_drift(f$object, reverse, B = 10L, seed = 82L)
  expected <- bootstrap_oracle_draws(f$units, 10L, 82L, strata)
  for (i in 1:10) {
    counts <- a$bootstrap$draws[[i]]$unit_counts
    expect_equal(sum(counts[c("u1", "u2")]), 2L)
    expect_equal(sum(counts[c("u3", "u4")]), 2L)
    expect_equal(counts[names(expected[[i]]$unit_counts)], expected[[i]]$unit_counts)
    expect_equal(counts, b$bootstrap$draws[[i]]$unit_counts)
  }
  expect_equal(a$bootstrap$summary, b$bootstrap$summary, tolerance = 1e-11)
})

test_that("seed and prefix reproducibility hold across budgets and storage modes", {
  f <- bootstrap_fixture()
  a <- bootstrap_drift(f$object, f$design, B = 5L, seed = 89L, keep = "replicates")
  b <- bootstrap_drift(f$object, f$design, B = 5L, seed = 89L, keep = "replicates")
  expect_identical(a$bootstrap, b$bootstrap)
  extended <- bootstrap_drift(f$object, f$design, B = 9L, seed = 89L, keep = "replicates")
  expect_identical(a$bootstrap$draws, extended$bootstrap$draws[1:5])
  r <- extended$bootstrap$replicates
  r <- r[r$replicate_id <= 5L, ]; rownames(r) <- NULL
  expect_equal(a$bootstrap$replicates, r)
  different <- bootstrap_drift(f$object, f$design, B = 5L, seed = 90L)
  expect_false(identical(a$bootstrap$draws, different$bootstrap$draws))
  brief <- bootstrap_drift(f$object, f$design, B = 5L, seed = 89L, keep = "summary")
  expect_null(brief$bootstrap$replicates)
  expect_null(brief$bootstrap$coordinates)
  expect_equal(brief$bootstrap$summary, a$bootstrap$summary)
  expect_equal(brief$bootstrap$coordinate_summary, a$bootstrap$coordinate_summary)
  expect_equal(brief$bootstrap$quantiles, a$bootstrap$quantiles)
  expect_length(brief$bootstrap$diagnostics, 5L)
  expect_true(all(c("recipe_hash", "R_version", "package_version") %in% names(brief$bootstrap$provenance)))
  expect_true(nzchar(brief$bootstrap$provenance$recipe_hash))
})

test_that("caller RNG kind, existing state, absent state, and error paths are preserved", {
  f <- bootstrap_fixture()
  bootstrap_with_saved_rng({
    RNGkind("Mersenne-Twister", "Inversion", "Rejection")
    set.seed(910)
    before <- get(".Random.seed", envir = .GlobalEnv)
    kinds <- RNGkind()
    invisible(bootstrap_drift(f$object, f$design, B = 3L, seed = 91L))
    expect_identical(RNGkind(), kinds)
    expect_identical(get(".Random.seed", envir = .GlobalEnv), before)
    expect_error(bootstrap_drift(f$object, f$design, B = 0L))
    expect_identical(RNGkind(), kinds)
    expect_identical(get(".Random.seed", envir = .GlobalEnv), before)
    rank <- bootstrap_fixture(singleton = TRUE)
    suppressWarnings(bootstrap_drift(rank$object, rank$design, B = 1L, seed = 1L))
    expect_identical(RNGkind(), kinds)
    expect_identical(get(".Random.seed", envir = .GlobalEnv), before)
    rm(".Random.seed", envir = .GlobalEnv)
    invisible(bootstrap_drift(f$object, f$design, B = 2L, seed = 2L))
    expect_identical(RNGkind(), kinds)
    expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
    expect_error(bootstrap_drift(f$object, f$design, seed = -1))
    expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  })
})

test_that("every replicate performs a full refit in the common baseline frame without rescaling", {
  f <- bootstrap_fixture()
  result <- bootstrap_drift(f$object, f$design, B = 5L, seed = 17L, keep = "replicates")$bootstrap
  for (i in 1:5) {
    truth <- bootstrap_oracle_fit(f, result$draws[[i]]$feature_weights)
    actual <- result$replicates[result$replicates$replicate_id == i, names(truth$movement)]
    rownames(actual) <- NULL
    expect_equal(actual, truth$movement, tolerance = 1e-10)
    actual_xy <- result$coordinates[result$coordinates$replicate_id == i, c("x", "y")]
    expect_equal(unname(as.matrix(actual_xy)), unname(as.matrix(truth$coordinates[c("x", "y")])),
                 tolerance = 1e-10)
  }
})

test_that("a coherent observed rotation, reflection, and translation changes only vector convention", {
  f <- bootstrap_fixture()
  original <- bootstrap_drift(f$object, f$design, B = 5L, seed = 17L, keep = "replicates")$bootstrap
  transform <- matrix(c(0, 1, 1, 0), nrow = 2L)
  changed <- f$object
  changed$aligned[c("x", "y")] <- sweep(as.matrix(changed$aligned[c("x", "y")]) %*% transform,
                                          2L, c(4, -8), "+")
  rotated <- bootstrap_drift(changed, f$design, B = 5L, seed = 17L, keep = "replicates")$bootstrap
  expect_equal(rotated$replicates$distance, original$replicates$distance, tolerance = 1e-10)
  expect_equal(unname(as.matrix(rotated$replicates[c("dx", "dy")])),
               unname(as.matrix(original$replicates[c("dx", "dy")]) %*% transform), tolerance = 1e-10)
  expect_equal(unname(as.matrix(rotated$coordinates[c("x", "y")])),
               unname(sweep(as.matrix(original$coordinates[c("x", "y")]) %*% transform,
                            2L, c(4, -8), "+")), tolerance = 1e-10)
})

test_that("summary means, covariance, MCSE and quantiles equal independent replicate calculations", {
  f <- bootstrap_fixture()
  result <- bootstrap_drift(f$object, f$design, B = 13L, seed = 117L,
                            keep = "replicates", probs = c(.1, .5, .9))$bootstrap
  s <- result$summary
  expect_true(all(c("observed_dx", "observed_dy", "observed_distance", "mean_dx", "mean_dy",
                    "mean_distance", "sd_dx", "sd_dy", "sd_distance", "cov_dx_dy",
                    "mcse_mean_dx", "mcse_mean_dy", "mcse_mean_distance", "n_attempted",
                    "n_valid", "n_failed", "success_rate", "summary_status") %in% names(s)))
  for (j in seq_len(nrow(s))) {
    r <- result$replicates[result$replicates$entity == s$entity[j] &
                          result$replicates$time_from == s$time_from[j] &
                          result$replicates$time_to == s$time_to[j], ]
    expect_equal(s$n_valid[j], 13L)
    expect_equal(s$n_attempted[j], 13L)
    expect_equal(s$n_failed[j], 0L)
    expect_equal(s$cov_dx_dy[j], stats::cov(r$dx, r$dy), tolerance = 1e-12)
    for (metric in c("dx", "dy", "distance")) {
      expect_equal(s[[paste0("mean_", metric)]][j], mean(r[[metric]]), tolerance = 1e-12)
      expect_equal(s[[paste0("sd_", metric)]][j], stats::sd(r[[metric]]), tolerance = 1e-12)
      expect_equal(s[[paste0("mcse_mean_", metric)]][j], stats::sd(r[[metric]]) / sqrt(13), tolerance = 1e-12)
      q <- result$quantiles[result$quantiles$entity == s$entity[j] &
                            result$quantiles$time_from == s$time_from[j] &
                            result$quantiles$time_to == s$time_to[j] &
                            result$quantiles$measure == metric, ]
      expect_equal(q$value, as.numeric(stats::quantile(r[[metric]], q$probability, type = 7)),
                   tolerance = 1e-12)
    }
  }
  cs <- result$coordinate_summary
  for (j in seq_len(nrow(cs))) {
    z <- result$coordinates[result$coordinates$entity == cs$entity[j] &
                            result$coordinates$time == cs$time[j], ]
    expect_equal(cs$mean_x[j], mean(z$x), tolerance = 1e-12)
    expect_equal(cs$mean_y[j], mean(z$y), tolerance = 1e-12)
    expect_equal(cs$var_x[j], stats::var(z$x), tolerance = 1e-12)
    expect_equal(cs$var_y[j], stats::var(z$y), tolerance = 1e-12)
    expect_equal(cs$cov_xy[j], stats::cov(z$x, z$y), tolerance = 1e-12)
  }
  expect_false(any(grepl("p_value|significan|conf_low|conf_high", names(s))))
})

test_that("known rank failures are counted exactly with no replacement attempts", {
  f <- bootstrap_fixture(singleton = TRUE)
  result <- suppressWarnings(bootstrap_drift(f$object, f$design, B = 40L, seed = 2L,
                                            keep = "replicates", min_success = 0))$bootstrap
  expected <- bootstrap_oracle_draws(f$units, 40L, 2L)
  success <- vapply(expected, function(draw) all(draw$unit_counts == 1L), logical(1))
  expect_true(any(success) && any(!success))
  expect_identical(result$attempts$success, success)
  expect_identical(result$attempts$replicate_id, seq_len(40L))
  expect_length(result$draws, 40L)
  expect_length(result$diagnostics, 40L)
  expect_equal(sort(unique(result$replicates$replicate_id)), which(success))
  expect_equal(nrow(result$replicates), sum(success) * nrow(result$observed))
  expect_equal(nrow(result$coordinates), sum(success) * nrow(f$object$aligned))
  expect_true(all(result$summary$n_attempted == 40L))
  expect_true(all(result$summary$n_valid == sum(success)))
  expect_true(all(result$summary$n_failed == sum(!success)))
  expect_true(all(result$summary$success_rate == mean(success)))
  failures <- result$attempts[!success, ]
  expect_true(all(nzchar(failures$message)))
  expect_true(all(nzchar(failures$stage)))
  expect_true(all(failures$period_index == 1L))
  expect_true(all(c("n_shared", "n_matched", "n_warnings") %in% names(failures)))
  expect_true(all(is.finite(result$summary$mean_distance)))
})

test_that("success gates suppress summaries without deleting successful draws", {
  f <- bootstrap_fixture(singleton = TRUE)
  fit <- suppressWarnings(bootstrap_drift(f$object, f$design, B = 30L, seed = 2L,
                                         keep = "replicates", min_success = .95))$bootstrap
  expect_true(sum(fit$attempts$success) > 0L)
  expect_true(mean(fit$attempts$success) < .95)
  s <- fit$summary
  values <- c("mean_dx", "mean_dy", "mean_distance", "sd_dx", "sd_dy", "sd_distance",
              "cov_dx_dy", "mcse_mean_dx", "mcse_mean_dy", "mcse_mean_distance")
  expect_true(all(is.na(as.matrix(s[values]))))
  expect_true(all(is.na(fit$quantiles$value)))
  expect_true(all(is.na(as.matrix(fit$coordinate_summary[c("mean_x", "mean_y", "var_x", "var_y", "cov_xy")]))))
  expect_true(all(is.finite(fit$replicates$distance)))
  expect_true(all(is.finite(s$observed_distance)))
})

test_that("all-failed and one-valid budgets return explicit defined accounting", {
  f <- bootstrap_fixture(singleton = TRUE)
  recorded <- character()
  failed <- withCallingHandlers(
    bootstrap_drift(f$object, f$design, B = 1L, seed = 1L, keep = "replicates"),
    warning = function(w) {
      recorded <<- c(recorded, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_true(any(grepl("attempts failed", recorded)))
  expect_true(any(grepl("summary gate", recorded)))
  b <- failed$bootstrap
  expect_false(b$attempts$success)
  expect_equal(b$summary$n_valid, rep(0L, nrow(b$summary)))
  expect_true(all(is.na(b$summary$mean_distance)))
  expect_equal(nrow(b$replicates), 0L)
  expect_equal(nrow(b$coordinates), 0L)
  expect_warning(one_fit <- bootstrap_drift(f$object, f$design, B = 1L, seed = 2L,
                                            keep = "replicates"), "summary gate")
  one <- one_fit$bootstrap
  expect_true(one$attempts$success)
  expect_true(all(is.na(one$summary$mean_distance)))
  expect_true(all(one$summary$summary_status == "insufficient_replicates"))
  expect_true(all(is.finite(one$replicates$distance)))
  expect_true(all(is.na(one$summary$sd_distance)))
  expect_true(all(is.na(one$summary$cov_dx_dy)))
  expect_true(all(is.na(one$coordinate_summary$cov_xy)))
})

test_that("paired weights retain fixed availability and typed times under both references", {
  for (reference in c("previous", "first")) {
    f <- bootstrap_fixture(reference = reference, churn = TRUE, dates = TRUE)
    b <- bootstrap_drift(f$object, f$design, B = 3L, seed = 92L, keep = "replicates")$bootstrap
    expect_s3_class(b$summary$time_from, "Date")
    expect_s3_class(b$quantiles$time_to, "Date")
    expect_s3_class(b$coordinates$time, "Date")
    expect_s3_class(b$coordinate_summary$time, "Date")
    expect_false(any(b$replicates$entity %in% c("H", "I")))
    expect_equal(nrow(b$coordinates), 3L * nrow(f$object$aligned))
    expected <- bootstrap_oracle_fit(f, b$draws[[1L]]$feature_weights)$movement
    actual <- b$replicates[b$replicates$replicate_id == 1L, names(expected)]
    rownames(actual) <- NULL
    expect_equal(actual, expected, tolerance = 1e-10)
  }
})

test_that("fixed and refit preprocessing coincide for unchanged paired measurements", {
  for (standardize in c("none", "first", "pooled", "period")) {
    f <- bootstrap_fixture(standardize = standardize)
    refit <- bootstrap_drift(f$object, f$design, B = 4L, seed = 92L, preprocess = "refit", keep = "replicates")
    fixed <- bootstrap_drift(f$object, f$design, B = 4L, seed = 92L, preprocess = "fixed", keep = "replicates")
    expect_equal(fixed$bootstrap$replicates, refit$bootstrap$replicates, tolerance = 1e-10)
    expect_equal(fixed$bootstrap$coordinate_summary, refit$bootstrap$coordinate_summary, tolerance = 1e-10)
  }
})

test_that("PCA and Euclidean classical MDS bootstrap distances agree", {
  pca <- bootstrap_fixture(method = "pca", scale = TRUE)
  cmds <- bootstrap_fixture(method = "cmds", scale = TRUE)
  a <- bootstrap_drift(pca$object, pca$design, B = 5L, seed = 211L, keep = "replicates")$bootstrap
  b <- bootstrap_drift(cmds$object, cmds$design, B = 5L, seed = 211L, keep = "replicates")$bootstrap
  expect_equal(a$replicates$distance, b$replicates$distance, tolerance = 1e-9)
  expect_equal(a$summary$mean_distance, b$summary$mean_distance, tolerance = 1e-9)
  expect_equal(a$summary$sd_distance, b$summary$sd_distance, tolerance = 1e-9)
  expect_identical(a$attempts$success, b$attempts$success)
})

test_that("engine rejects absent recipes, incompatible mappings and malformed controls", {
  f <- bootstrap_fixture()
  unaligned <- embed_snapshots(f$data, f$features)
  expect_error(bootstrap_drift(unaligned, f$design, B = 2L), "align")
  coordinates <- drift_data(f$object$coordinates[c("entity", "time", "x", "y")]) |>
    align_snapshots()
  expect_error(bootstrap_drift(coordinates, f$design, B = 2L), "feature|adapter|recipe|embedding")
  distances <- lapply(1:3, function(i) {
    x <- as.matrix(f$data[f$data$time == i, f$features]); rownames(x) <- LETTERS[1:8]
    stats::dist(x)
  })
  distance_object <- embed_snapshots(distances, method = "cmds", periods = 1:3) |>
    align_snapshots()
  expect_error(bootstrap_drift(distance_object, f$design, B = 2L), "feature|distance")
  weighted <- embed_snapshots(f$data, f$features, feature_weights = rep(2, 8L)) |>
    align_snapshots()
  expect_error(bootstrap_drift(weighted, f$design, B = 2L), "weight")
  bad <- f$units; names(bad)[1L] <- "absent"
  expect_error(bootstrap_drift(f$object, paired_unit_design(bad, assumptions = "IID"), B = 2L),
               "feature|match|mapping")
  for (bad_B in list(0, -1, 1.5, NA_real_, Inf, c(1, 2), "2"))
    expect_error(bootstrap_drift(f$object, f$design, B = bad_B), "B")
  for (bad_seed in list(-1, 1.5, NA_real_, Inf, .Machine$integer.max + 1, c(1, 2), "2"))
    expect_error(bootstrap_drift(f$object, f$design, B = 2L, seed = bad_seed), "seed")
  for (bad_p in list(numeric(), -0.1, 1.1, NA_real_, c(.1, .1), "median"))
    expect_error(bootstrap_drift(f$object, f$design, B = 2L, probs = bad_p), "prob")
  for (bad_gate in list(-.1, 1.1, NA_real_, c(.5, .9), "high"))
    expect_error(bootstrap_drift(f$object, f$design, B = 2L, min_success = bad_gate), "min_success")
  expect_error(bootstrap_drift(f$object, f$design, B = 2L, preprocess = "unknown"))
  expect_error(bootstrap_drift(f$object, f$design, B = 2L, keep = "unknown"))
})

test_that("changed fitted geometry and known boundary ties fail before drawing", {
  f <- bootstrap_fixture()
  changed <- f$object
  changed$aligned$x[changed$aligned$entity == "G" & changed$aligned$period_index == 2L] <- 100
  expect_error(bootstrap_drift(changed, f$design, B = 2L), "recipe|reconstruct|align|geometry|fit")
  tied <- data.frame(entity = letters[1:6], time = 1L,
                     a = c(1, -1, 0, 0, 0, 0), b = c(0, 0, 1, -1, 0, 0),
                     c = c(0, 0, 0, 0, 1, -1))
  tied <- rbind(tied, transform(tied, time = 2L))
  changed <- suppressWarnings(embed_snapshots(tied, c("a", "b", "c"))) |>
    align_snapshots()
  tied_design <- paired_unit_design(c(a = "a", b = "b", c = "c"), assumptions = "IID measurements.")
  expect_error(bootstrap_drift(changed, tied_design, B = 2L), "tie|spectr|boundar")
})


test_that("bootstrap preserves the hidden Box-Muller normal-generator cache", {
  f <- bootstrap_fixture()
  bootstrap_with_saved_rng({
    RNGkind("Mersenne-Twister", "Box-Muller", "Rejection")
    set.seed(871L)
    first <- stats::rnorm(1L)
    expected <- stats::rnorm(3L)
    set.seed(871L)
    expect_identical(stats::rnorm(1L), first)
    invisible(bootstrap_drift(f$object, f$design, B = 2L, seed = 32L))
    expect_identical(stats::rnorm(3L), expected)
    expect_identical(RNGkind()[2L], "Box-Muller")
  })
})

test_that("replicate spectral ties retain warnings, diagnostics and whole-draw failures", {
  base <- data.frame(entity = letters[1:6], time = 1L,
                     f1 = c(3, -3, 0, 0, 0, 0),
                     f2 = c(0, 0, 1, -1, 0, 0),
                     f3 = c(0, 0, 0, 0, 1, -1),
                     f4 = c(0, 0, 0, 0, 2, -2))
  data <- rbind(base, transform(base, time = 2L))
  fit <- embed_snapshots(data, paste0("f", 1:4)) |> align_snapshots()
  units <- stats::setNames(paste0("u", 1:4), paste0("f", 1:4))
  design <- paired_unit_design(units, assumptions = "IID hypothetical measurements; exact diagnostic fixture.")
  b <- suppressWarnings(bootstrap_drift(fit, design, B = 40L, seed = 13L,
                                         keep = "replicates", min_success = 0))$bootstrap
  tied <- vapply(b$draws, function(draw) {
    w <- draw$feature_weights
    eigenvalues <- sort(c(9 * w[1L], w[2L], w[3L] + 4 * w[4L]), decreasing = TRUE)
    eigenvalues[2L] > 0 && eigenvalues[2L] == eigenvalues[3L]
  }, logical(1))
  expect_true(any(tied))
  expect_true(all(!b$attempts$success[tied]))
  expect_true(all(b$attempts$n_warnings[tied] > 0L))
  expect_true(all(b$attempts$period_index[tied] == 1L))
  expect_true(all(which(tied) %in% b$warnings$replicate_id))
  expect_true(all(nzchar(b$warnings$message)))
  expect_true(all(vapply(b$diagnostics[tied], length, integer(1)) > 0L))
  expect_false(any(b$replicates$replicate_id %in% which(tied)))
  warning_counts <- tabulate(b$warnings$replicate_id, nbins = nrow(b$attempts))
  expect_equal(b$attempts$n_warnings, warning_counts)
})

test_that("unit and stratum ordering is canonical across supported collation locales", {
  f <- bootstrap_fixture()
  mixed_ids <- c(u1 = "a", u2 = "Z", u3 = "A", u4 = "z")
  units <- stats::setNames(unname(mixed_ids[f$units]), names(f$units))
  strata <- c(a = "alpha", Z = "Zulu", A = "alpha", z = "Zulu")
  # Feature-name order is part of the design contract independently of whether
  # the optional alternate locale exists on the platform running this test.
  declaration <- paired_unit_design(stats::setNames(unname(units),
    c("fa", "fZ", "fA", "fz", "fb", "fY", "fB", "fy")),
    assumptions = "Independent paired blocks within declared strata.", strata = strata)
  expect_identical(names(declaration$units), sort(names(declaration$units), method = "radix"))
  expect_identical(names(declaration$strata), sort(unique(unname(units)), method = "radix"))
  run <- function() {
    previous <- Sys.getlocale("LC_COLLATE")
    on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", previous)), add = TRUE)
    expect_true(nzchar(Sys.setlocale("LC_COLLATE", "C")))
    design_c <- paired_unit_design(units,
      assumptions = "Independent paired blocks within declared strata.", strata = strata)
    result_c <- bootstrap_drift(f$object, design_c, B = 4L, seed = 104L)$bootstrap
    expected <- bootstrap_oracle_draws(units, 4L, 104L, strata)
    for (i in 1:4) {
      expect_identical(result_c$draws[[i]]$unit_counts, expected[[i]]$unit_counts)
      expect_identical(result_c$draws[[i]]$rng_stream, expected[[i]]$rng_stream)
    }
    available <- suppressWarnings(Sys.setlocale("LC_COLLATE", "C.UTF-8"))
    if (nzchar(available)) {
      design_utf8 <- paired_unit_design(units,
        assumptions = "Independent paired blocks within declared strata.", strata = strata)
      result_utf8 <- bootstrap_drift(f$object, design_utf8, B = 4L, seed = 104L)$bootstrap
      expect_identical(design_c, design_utf8)
      expect_identical(result_c$draws, result_utf8$draws)
      expect_equal(result_c$summary, result_utf8$summary, tolerance = 1e-12)
    }
  }
  run()
})

test_that("inconsistent preprocessing declarations are rejected before resampling", {
  f <- bootstrap_fixture(standardize = "first")
  changed <- f$object
  changed$embedding_metadata$preprocessing$standardize <- "pooled"
  expect_error(bootstrap_drift(changed, f$design, B = 2L),
               "preprocessing|standardiz|recipe|metadata|match")
})
