# Study02 model. The source generator is unchanged from study01.
study02_settings <- function() {
  list(m = c(20L, 40L, 160L, 640L), M = 240L, B = 399L,
       budgets = c(199L, 399L), data_seed = 260920L,
       bootstrap_seed_base = 2400000L, targets = c("E015", "E003", "E006"),
       estimators = c("refit_plugin", "refit_oracle", "tangent_oracle"),
       engine_version = "0.0.5.9000", min_success = .95, min_valid = 20L)
}

study02_model <- function(m) {
  scenario <- calibration_scenarios()[1L, , drop = FALSE]
  scenario$m <- as.integer(m)
  layout <- calibration_layout(scenario)
  n <- nrow(layout$latent[[1L]])
  H <- diag(n) - matrix(1/n, n, n)
  Z <- H %*% layout$latent[[1L]]
  C <- tcrossprod(Z) + scenario$sigma^2 * H
  spectrum <- study02_spectrum(C)
  ids <- rownames(layout$latent[[1L]])
  anchors <- list(original = match(layout$anchors, ids),
    spread = match(c("E001", "E002", "E003", "E007", "E008", "E009", "E010",
                     "E013", "E014", "E016", "E017"), ids))
  list(scenario = scenario, layout = layout, ids = ids, H = H, population_gram = C,
       spectrum = spectrum, population_points = spectrum$points,
       anchors = anchors, target_ids = study02_settings()$targets,
       target_rows = match(study02_settings()$targets, ids))
}

study02_generate <- function(job) {
  model <- study02_model(job$m)
  generated <- calibration_generate(model$scenario, job$data_stream)
  X <- lapply(1:2, function(t) model$H %*%
    as.matrix(generated$data[generated$data$time == t, generated$features]))
  list(model = model, data = generated$data, features = generated$features,
       unit_map = generated$unit_map, X = X)
}

study02_jobs <- function() {
  settings <- study02_settings()
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(settings$data_seed)
  stream <- .Random.seed
  jobs <- list()
  for (k in seq_along(settings$m)) for (i in seq_len(settings$M)) {
    jobs[[length(jobs) + 1L]] <- list(m = settings$m[k], dataset_id = as.integer(i),
      data_stream = stream, bootstrap_seed = as.integer(settings$bootstrap_seed_base + k * 10000L + i),
      stage = "independent_followup")
    stream <- parallel::nextRNGStream(stream)
  }
  jobs
}
