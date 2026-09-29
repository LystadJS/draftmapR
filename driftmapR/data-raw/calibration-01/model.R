# Frozen generators for the first bounded bootstrap calibration study.
# These are study helpers, not exported driftmapR functions.

calibration_scenarios <- function() {
  data.frame(
    id = seq_len(6L),
    scenario = c("regular_null", "regular_movement", "few_units", "high_noise",
                 "rare_axis", "dependent_units"),
    m = c(40L, 40L, 12L, 40L, 12L, 40L),
    sigma = c(0.25, 0.25, 0.25, 1, 0.25, 0.25),
    q = c(1, 1, 1, 1, 0.15, 1),
    rho_unit = c(0, 0, 0, 0, 0, 0.5),
    motion = c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    rho_time = rep(0.6, 6L),
    stringsAsFactors = FALSE
  )
}

calibration_validate_scenario <- function(scenario_row) {
  required <- names(calibration_scenarios())
  if (!is.data.frame(scenario_row) || nrow(scenario_row) != 1L ||
      !all(required %in% names(scenario_row))) {
    stop("Supply one complete row from calibration_scenarios().", call. = FALSE)
  }
  if (!is.character(scenario_row$scenario) || is.na(scenario_row$scenario) ||
      !scenario_row$scenario %in% calibration_scenarios()$scenario ||
      !is.logical(scenario_row$motion) || is.na(scenario_row$motion)) {
    stop("Scenario name and motion indicator are invalid.", call. = FALSE)
  }
  values <- unlist(scenario_row[c("m", "sigma", "q", "rho_unit", "rho_time")],
                   use.names = FALSE)
  if (!is.numeric(values) || any(!is.finite(values)) ||
      scenario_row$m < 2 || scenario_row$m != floor(scenario_row$m) ||
      scenario_row$sigma < 0 || scenario_row$q <= 0 || scenario_row$q > 1 ||
      scenario_row$rho_unit < 0 || scenario_row$rho_unit >= 1 ||
      abs(scenario_row$rho_time) >= 1) {
    stop("Scenario numeric parameters are outside their permitted ranges.",
         call. = FALSE)
  }
  invisible(scenario_row)
}

calibration_layout <- function(scenario_row) {
  calibration_validate_scenario(scenario_row)
  entity <- sprintf("E%03d", seq_len(18L))
  cluster <- rep(c("A", "B", "C"), each = 6L)
  centers <- rbind(A = c(-1.4, 0), B = c(1.3, 0), C = c(0, 1.6))
  k <- seq_along(entity)
  first <- centers[cluster, , drop = FALSE] +
    0.3 * cbind(sin(k * 1.7), cos(k * 2.3))
  dimnames(first) <- list(entity, c("x", "y"))
  second <- first
  movement_group <- rep("stable", length(entity))
  if (scenario_row$motion) {
    second["E006", ] <- second["E006", ] + c(0.45, -0.30)
    second[13:18, ] <- sweep(second[13:18, , drop = FALSE], 2L,
                            c(-0.55, 0.40), "+")
    movement_group[6L] <- "individual_mover"
    movement_group[13:18] <- "moving_cluster"
  }
  list(
    latent = list(first, second),
    anchors = entity[c(1:5, 7:12)],
    target_ids = c("E015", "E003", "E006"),
    entitygroups = data.frame(entity = entity, cluster = cluster,
                              movement_group = movement_group,
                              stringsAsFactors = FALSE)
  )
}

calibration_generate <- function(scenario_row, data_stream) {
  layout <- calibration_layout(scenario_row)
  if (!is.integer(data_stream) || length(data_stream) != 7L ||
      anyNA(data_stream) || data_stream[1L] %% 100L != 7L) {
    stop("data_stream must be a complete integer L'Ecuyer-CMRG RNG state.",
         call. = FALSE)
  }
  # This helper can be called from tests or analysis without consuming the
  # caller's random stream. Stream states, rather than scalar reseeding, define
  # independent study datasets.
  previous_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(previous_kind))
    if (had_seed) assign(".Random.seed", previous_seed, envir = .GlobalEnv) else {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }
  }, add = TRUE)
  assign(".Random.seed", data_stream, envir = .GlobalEnv)

  n <- nrow(layout$latent[[1L]])
  m <- scenario_row$m
  rho <- scenario_row$rho_unit
  rho_time <- scenario_row$rho_time
  features <- sprintf("f%03d", seq_len(m))
  rare_axis <- identical(scenario_row$scenario, "rare_axis")
  rare <- if (rare_axis) stats::rbinom(m, 1L, scenario_row$q) == 1L else rep(FALSE, m)

  # Columns are complete measurement units. Shared components introduce
  # cross-unit dependence without changing any one unit's marginal law.
  gaussian_units <- function(dimension) {
    individual <- matrix(stats::rnorm(dimension * m), nrow = dimension, ncol = m)
    if (rho == 0) return(individual)
    sqrt(1 - rho) * individual +
      sqrt(rho) * matrix(stats::rnorm(dimension), nrow = dimension, ncol = m)
  }
  loadings <- gaussian_units(2L)
  noise_first <- gaussian_units(n)
  noise_second <- rho_time * noise_first +
    sqrt(1 - rho_time^2) * gaussian_units(n)
  noise <- list(noise_first, noise_second)
  panel <- do.call(rbind, lapply(seq_len(2L), function(period) {
    z <- layout$latent[[period]]
    if (rare_axis) {
      measured <- tcrossprod(z[, 1L], loadings[1L, ]) +
        sweep(tcrossprod(z[, 2L], loadings[2L, ]) + scenario_row$sigma * noise[[period]],
              2L, as.numeric(rare) / sqrt(scenario_row$q), "*")
    } else {
      measured <- z %*% loadings + scenario_row$sigma * noise[[period]]
    }
    colnames(measured) <- features
    data.frame(entity = rownames(z), time = period, measured,
               check.names = FALSE, stringsAsFactors = FALSE)
  }))
  rownames(panel) <- NULL
  list(
    data = panel,
    features = features,
    unit_map = stats::setNames(sprintf("unit%03d", seq_len(m)), features),
    rare = stats::setNames(rare, features),
    rare_count = if (rare_axis) sum(rare) else NA_integer_,
    layout = layout
  )
}

calibration_population <- function(scenario_row) {
  layout <- calibration_layout(scenario_row)
  n <- nrow(layout$latent[[1L]])
  h <- diag(n) - matrix(1 / n, n, n)
  dimnames(h) <- list(rownames(layout$latent[[1L]]), rownames(layout$latent[[1L]]))
  gram <- eigenvalues <- points <- vector("list", 2L)
  for (period in seq_len(2L)) {
    z_centered <- h %*% layout$latent[[period]]
    # E[H X X' H] = m * (Z_centered Z_centered' + sigma^2 H).
    # The Bernoulli q correction preserves this moment in rare_axis. Unit
    # dependence affects its sampling variance, but not this expectation.
    gram[[period]] <- scenario_row$m *
      (tcrossprod(z_centered) + scenario_row$sigma^2 * h)
    dimnames(gram[[period]]) <- list(rownames(z_centered), rownames(z_centered))
    eig <- eigen(gram[[period]], symmetric = TRUE)
    eigenvalues[[period]] <- eig$values
    score <- sweep(eig$vectors[, 1:2, drop = FALSE], 2L,
                   sqrt(eig$values[1:2]), "*")
    points[[period]] <- data.frame(entity = rownames(layout$latent[[period]]),
                                   time = period, x = score[, 1L], y = score[, 2L])
  }
  object <- driftmapR::drift_data(do.call(rbind, points), periods = 1:2)
  object <- driftmapR::align_snapshots(object, reference = "previous", scale = FALSE,
                                      anchors = layout$anchors)
  list(object = object, gram = gram, eigenvalues = eigenvalues,
       layout = layout, movement = driftmapR::measure_drift(object))
}
