# R's Box-Muller generator caches a normal value outside .Random.seed. Changing
# RNGkind destroys that cache, so ordinary save/restore cannot preserve the
# caller's entire RNG sequence. Plan all draws in one isolated base-R process;
# embedding and alignment still run serially in the calling process.
bootstrap_draw_plan <- function(design, features, B, seed) {
  directory <- tempfile("driftmapR-rng-")
  if (!dir.create(directory)) stop("Could not create bootstrap RNG planning directory.", call. = FALSE)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  input <- file.path(directory, "input.rds")
  output <- file.path(directory, "draws.rds")
  script <- file.path(directory, "plan.R")
  log <- file.path(directory, "process.log")
  generator <- bootstrap_generate_draws
  # The child needs only base/recommended R, including when the source package
  # is loaded for development but an earlier version remains installed.
  environment(generator) <- baseenv()
  saveRDS(list(generator = generator, design = design, features = features,
               B = B, seed = seed), input, version = 2)
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "job <- readRDS(args[[1L]])",
    "result <- job$generator(job$design, job$features, job$B, job$seed)",
    "saveRDS(result, args[[2L]], version = 2)"), script)
  status <- system2(file.path(R.home("bin"), "Rscript"),
                     args = c("--vanilla", shQuote(script), shQuote(input), shQuote(output)),
                     stdout = log, stderr = log)
  if (!identical(status, 0L) || !file.exists(output)) {
    details <- if (file.exists(log)) paste(readLines(log, warn = FALSE), collapse = "\n") else "No process log."
    stop("Bootstrap RNG planning failed in the isolated R process: ", details, call. = FALSE)
  }
  readRDS(output)
}

# Self-contained function serialized with baseenv() into the planning process.
bootstrap_generate_draws <- function(design, features, B, seed) {
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(seed)
  stream <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  draws <- vector("list", B)
  unit_ids <- names(design$strata)
  strata <- sort(unique(design$strata), method = "radix")
  for (i in seq_len(B)) {
    assign(".Random.seed", stream, envir = .GlobalEnv)
    counts <- stats::setNames(integer(length(unit_ids)), unit_ids)
    for (stratum in strata) {
      indices <- which(design$strata == stratum)
      sampled <- indices[sample.int(length(indices), length(indices), replace = TRUE)]
      counts <- counts + tabulate(sampled, nbins = length(unit_ids))
    }
    weights <- stats::setNames(as.integer(counts[design$units[features]]), features)
    draws[[i]] <- list(unit_counts = counts, feature_weights = weights, rng_stream = stream)
    stream <- parallel::nextRNGStream(stream)
  }
  list(draws = draws, rng = list(seed = seed, kind = RNGkind()))
}
