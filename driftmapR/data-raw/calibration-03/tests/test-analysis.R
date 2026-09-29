# Pure bookkeeping fixtures: these do not generate or inspect calibration panels.
study03_analysis_fixture <- function() {
  plan <- data.frame(case_id = c("null20", "rare12"), scenario = c("regular_null", "rare_axis_movement"),
                     m = c(20L, 12L), M = c(3L, 2L), B = c(20L, 40L))
  entities <- c("E015", "E003", "E006")
  rows <- list(outer = list(), estimates = list(), regions = list(), attempts = list(), studentization = list())
  add <- function(name, x) rows[[name]][[length(rows[[name]]) + 1L]] <<- x
  for (k in seq_len(nrow(plan))) for (i in seq_len(plan$M[k])) {
    B <- plan$B[k]; good <- !(k == 2L && i == 2L)
    meta <- data.frame(case_id = plan$case_id[k], scenario = plan$scenario[k], m = plan$m[k], dataset_id = i)
    add("outer", data.frame(meta, observed_success = good))
    success <- rep(good, B)
    if (k == 2L && good) success[1L] <- FALSE
    pivot <- success
    if (k == 2L && good) pivot[2:3] <- FALSE
    truth <- if (k == 1L) c(0, 0) else c(.2, -.1)
    estimate <- if (good) truth + c(.01 * i, -.02 * i) else c(NA_real_, NA_real_)
    for (b in seq_len(B)) {
      add("attempts", data.frame(meta, replicate_id = b, attempted = good, success = success[b],
        stage = if (success[b]) "success" else if (good) "embedding" else "observed_fit_unavailable", message = ""))
    }
    for (entity in entities) {
      add("estimates", data.frame(meta, entity = entity, observed_success = good,
        dx = estimate[1], dy = estimate[2], truth_dx = truth[1], truth_dy = truth[2], observed_jackknife_ok = good))
      for (b in seq_len(B)) {
        add("studentization", data.frame(meta, entity = entity, replicate_id = b,
          attempted = success[b], covariance_ok = pivot[b], pivot_ok = pivot[b], pivot = if (pivot[b]) b / B else NA_real_,
          inner_required_unique = if (success[b]) 5L else 0L,
          inner_successful_unique = if (pivot[b]) 5L else if (success[b]) 4L else 0L,
          stage = if (pivot[b]) "success" else if (success[b]) "inner_fit" else "full_fit_unavailable", message = "",
          dx = if (success[b]) estimate[1] + b / (100 * B) else NA_real_,
          dy = if (success[b]) estimate[2] - b / (200 * B) else NA_real_,
          distinct_units = 4L + as.integer(b %% 2L == 0L),
          rare_multiplicity = if (k == 2L) as.integer(b > 1L) else NA_integer_))
      }
      for (method in study03_methods()) {
        nv <- if (method == "jackknife_studentized") sum(pivot) else if (method == "jackknife_wald") NA_integer_ else sum(success)
        gate <- if (method == "jackknife_wald") good else nv >= 20L && nv / B >= .95
        available <- good && (method == "jackknife_wald" || nv >= 20L)
        delivered <- available && gate
        covered <- i <= 2L
        excluded <- if (k == 1L) !covered else TRUE
        add("regions", data.frame(meta, entity = entity, method = method, available = available,
          gate = gate, delivered = delivered, covered = if (delivered) covered else NA,
          rejects_zero = if (delivered) excluded else NA,
          relaxed_covered = if (available) covered else NA, relaxed_rejects_zero = if (available) excluded else NA,
          area = if (available) if (method == "jackknife_studentized") 2 else 1 else NA_real_,
          n_valid = nv, cutoff = if (available) 5.99 else NA_real_,
          var_dx = if (good) .01 else NA_real_, var_dy = if (good) .02 else NA_real_, cov_dx_dy = if (good) .001 else NA_real_,
          truth_dx = truth[1], truth_dy = truth[2]))
      }
    }
  }
  c(list(caseplan = plan), lapply(rows, function(x) { z <- do.call(rbind, x); rownames(z) <- NULL; z }))
}

testthat::test_that("Wilson summaries retain empty cohorts and validate dimensions", {
  testthat::expect_equal(study03_wilson(19, 20)["estimate"], c(estimate = .95))
  testthat::expect_equal(study03_wilson(0, 20)["mcse"], c(mcse = 0))
  testthat::expect_true(all(is.na(study03_wilson(0, 0))))
  testthat::expect_error(study03_wilson(21, 20), "valid counts")
  testthat::expect_error(study03_wilson(.5, 20), "valid counts")
  testthat::expect_error(study03_wilson(1, 20, 1), "probability")
})

testthat::test_that("case-specific denominators and all planned placeholder rows validate", {
  f <- study03_analysis_fixture()
  testthat::expect_true(do.call(study03_validate_analysis, f))
  testthat::expect_equal(nrow(f$outer), 5L)
  testthat::expect_equal(nrow(f$attempts), 140L)
  testthat::expect_equal(nrow(f$studentization), 420L)
  testthat::expect_equal(sum(!f$attempts$attempted), 40L)
  testthat::expect_equal(sum(!f$studentization$attempted), 123L)
})

testthat::test_that("missing, duplicate, and unknown cases cannot disappear from the denominator", {
  f <- study03_analysis_fixture(); f$outer <- f$outer[-1L, ]
  testthat::expect_error(do.call(study03_validate_analysis, f), "every planned dataset")
  f <- study03_analysis_fixture(); f$regions <- rbind(f$regions[-1L, ], f$regions[2L, ])
  testthat::expect_error(do.call(study03_validate_analysis, f), "every planned combination")
  f <- study03_analysis_fixture(); f$caseplan$M[1L] <- 4L
  testthat::expect_error(do.call(study03_validate_analysis, f), "every planned dataset")
  f <- study03_analysis_fixture(); f$estimates$case_id[1L] <- "unplanned"
  testthat::expect_error(do.call(study03_validate_analysis, f), "unknown case")
  f <- study03_analysis_fixture(); f$studentization$replicate_id[1L] <- 999L
  testthat::expect_error(do.call(study03_validate_analysis, f), "draw identifiers")
})

testthat::test_that("attempt, studentization and region counts reconcile independently", {
  f <- study03_analysis_fixture(); f$attempts$success[1L] <- FALSE
  testthat::expect_error(do.call(study03_validate_analysis, f), "Studentization")
  f <- study03_analysis_fixture(); f$studentization$pivot[1L] <- NA_real_
  testthat::expect_error(do.call(study03_validate_analysis, f), "Studentization")
  f <- study03_analysis_fixture(); f$studentization$inner_successful_unique[1L] <- 4L
  testthat::expect_error(do.call(study03_validate_analysis, f), "Studentization")
  f <- study03_analysis_fixture(); f$regions$n_valid[1L] <- 19L
  testthat::expect_error(do.call(study03_validate_analysis, f), "ledger reconciliation")
  f <- study03_analysis_fixture(); i <- which(f$regions$method == "jackknife_wald")[1L]; f$regions$n_valid[i] <- 20L
  testthat::expect_error(do.call(study03_validate_analysis, f), "valid counts")
  f <- study03_analysis_fixture(); f$regions$covered[1L] <- NA
  testthat::expect_error(do.call(study03_validate_analysis, f), "delivery")
})

testthat::test_that("coverage, zero exclusion, delivery and all-panel yield remain distinct", {
  f <- study03_analysis_fixture()
  s <- study03_coverage_summary(f$caseplan, f$estimates, f$regions)
  z <- s[s$case_id == "null20" & s$entity == "E015" & s$method == "wald" & s$policy == "production", ]
  testthat::expect_equal(z$n_outer, 3L)
  testthat::expect_equal(z$conditional_coverage, 2 / 3)
  testthat::expect_equal(z$conditional_zero_exclusion, 1 / 3)
  testthat::expect_equal(z$median_cutoff_delivered, 5.99)
  testthat::expect_equal(z$q95_cutoff_delivered, 5.99)
  testthat::expect_identical(z$zero_exclusion_interpretation, "type_I_error")
  z <- s[s$case_id == "rare12" & s$entity == "E015" & s$method == "wald" & s$policy == "production", ]
  testthat::expect_equal(z$n_outer, 2L)
  testthat::expect_equal(z$n_delivered, 1L)
  testthat::expect_equal(z$conditional_coverage, 1)
  testthat::expect_equal(z$delivery_fraction, .5)
  testthat::expect_equal(z$operational_coverage_and_delivery, .5)
  testthat::expect_equal(z$conditional_zero_exclusion, 1)
  testthat::expect_identical(z$zero_exclusion_interpretation, "power_for_declared_nonzero_target")
  z <- s[s$case_id == "rare12" & s$entity == "E015" & s$method == "jackknife_studentized", ]
  testthat::expect_true(is.na(z$conditional_coverage[z$policy == "production"]))
  testthat::expect_equal(z$conditional_coverage[z$policy == "relaxed"], 1)
  testthat::expect_equal(z$delivery_fraction[z$policy == "production"], 0)
  testthat::expect_equal(z$operational_coverage_and_delivery[z$policy == "production"], 0)
})

testthat::test_that("paired MCSEs use panel differences and disclose joint delivery", {
  a <- c(1, 1, 0, 0); b <- c(1, 0, 1, 1)
  s <- study03_paired_difference(a, b)
  testthat::expect_equal(unname(s["difference"]), .25)
  testthat::expect_equal(unname(s["mcse"]), stats::sd(b - a) / 2)
  testthat::expect_error(study03_paired_difference(NA, 1), "complete finite")
  testthat::expect_true(is.na(study03_paired_difference(numeric(), numeric())["difference"]))
  f <- study03_analysis_fixture(); s <- study03_paired_contrasts(f$regions)
  z <- s[s$case_id == "null20" & s$entity == "E015" & s$baseline == "wald", ]
  testthat::expect_equal(z$difference[z$metric == "conditional_coverage_joint_delivery"], 0)
  testthat::expect_equal(z$difference[z$metric == "log_area_ratio_joint_delivery"], log(2))
  testthat::expect_equal(z$n_pairs[z$metric == "area_joint_delivery"], 3)
  z <- s[s$case_id == "rare12" & s$entity == "E015" & s$baseline == "wald", ]
  testthat::expect_equal(z$difference[z$metric == "delivery"], -.5)
  testthat::expect_equal(z$n_pairs[z$metric == "conditional_coverage_joint_delivery"], 0)
})

testthat::test_that("error cohorts preserve observed-valid and each delivered subset", {
  f <- study03_analysis_fixture(); s <- study03_error_summary(f$estimates, f$regions)
  z <- s[s$case_id == "null20" & s$entity == "E015" & s$cohort == "observed_valid", ]
  testthat::expect_equal(z$bias_dx, .02)
  testthat::expect_equal(z$bias_dy, -.04)
  testthat::expect_equal(z$vector_rmse, sqrt(mean((1:3 * .01)^2 + (1:3 * .02)^2)))
  z <- s[s$case_id == "rare12" & s$entity == "E015", ]
  testthat::expect_equal(z$n_selected[z$cohort == "observed_valid"], 1L)
  testthat::expect_equal(z$n_selected[z$cohort == "delivered_jackknife_studentized"], 0L)
  testthat::expect_true(is.na(z$vector_rmse[z$cohort == "delivered_jackknife_studentized"]))
})

testthat::test_that("failure rates separate planned, attempted, full-fit and inner failures", {
  f <- study03_analysis_fixture()
  s <- study03_failure_summaries(f$caseplan, f$outer, f$attempts, f$studentization)
  z <- s$attempts[s$attempts$case_id == "rare12", ]
  testthat::expect_equal(z$n_planned, 80L)
  testthat::expect_equal(z$n_attempted, 40L)
  testthat::expect_equal(z$n_failed_after_attempt, 1L)
  z <- s$studentization[s$studentization$case_id == "rare12" & s$studentization$entity == "E015", ]
  testthat::expect_equal(z$n_planned, 80L)
  testthat::expect_equal(z$n_attempted, 39L)
  testthat::expect_equal(z$n_covariance_failed_after_attempt, 2L)
  testthat::expect_equal(z$n_pivot_ok, 37L)
  testthat::expect_equal(z$pivot_valid_fraction_of_planned, 37 / 80)
  z <- s$failure_stages
  testthat::expect_equal(sum(z$n_rows[z$ledger == "full_fit"]), 41L)
  testthat::expect_equal(sum(z$n_rows[z$ledger == "studentization"]), 129L)
})

testthat::test_that("covariance ratios compare matched outer errors with method covariance", {
  f <- study03_analysis_fixture()
  e <- f$estimates$case_id == "null20" & f$estimates$entity == "E015"
  f$estimates$dy[e] <- c(-.1, .05, 0)
  S <- 2 * stats::cov(f$estimates[e, c("dx", "dy")])
  r <- f$regions$case_id == "null20" & f$regions$entity == "E015" & f$regions$method == "wald"
  f$regions$var_dx[r] <- S[1, 1]; f$regions$var_dy[r] <- S[2, 2]; f$regions$cov_dx_dy[r] <- S[1, 2]
  s <- study03_covariance_summary(f$estimates, f$regions)
  z <- s[s$case_id == "null20" & s$entity == "E015" & s$method == "wald", ]
  testthat::expect_equal(z$n_covariance_pairs, 3L)
  testthat::expect_equal(z$covariance_trace_ratio, 2)
  testthat::expect_equal(z$generalized_ratio_min, 2)
  testthat::expect_equal(z$generalized_ratio_max, 2)
  testthat::expect_true(is.na(z$trace_ratio_jackknife_mcse))
})

testthat::test_that("selection summaries retain finite full-fit draws when studentization fails", {
  f <- study03_analysis_fixture(); s <- study03_selection_summary(f$estimates, f$studentization)
  z <- s$selection_by_panel[s$selection_by_panel$case_id == "rare12" &
    s$selection_by_panel$entity == "E015" & s$selection_by_panel$dataset_id == 1L &
    s$selection_by_panel$selection_stage == "studentized_pivot", ]
  testthat::expect_equal(z$n_reference_finite[z$metric == "rare_multiplicity"], 40L)
  testthat::expect_equal(z$n_reference_finite[z$metric == "error_norm"], 39L)
  testthat::expect_equal(z$n_failed_finite[z$metric == "error_norm"], 2L)
  testthat::expect_equal(z$valid_minus_planned[z$metric == "rare_multiplicity"], 1 / 40)
  testthat::expect_gt(z$valid_minus_failed[z$metric == "error_norm"], 0)
  z <- s$selection[s$selection$case_id == "rare12" & s$selection$entity == "E015" &
    s$selection$metric == "error_norm" & s$selection$selection_stage == "studentized_pivot", ]
  testthat::expect_equal(z$n_outer_with_valid_and_failed, 1L)
  testthat::expect_true(is.na(z$paired_valid_minus_failed_mcse))
  f$studentization$dx <- NULL
  testthat::expect_error(study03_selection_summary(f$estimates, f$studentization), "composition")
})

testthat::test_that("full-fit selection and conditional pivot selection have distinct reference cohorts", {
  f <- study03_analysis_fixture(); s <- study03_selection_summary(f$estimates, f$studentization)
  z <- s$selection_by_panel[s$selection_by_panel$case_id == "rare12" &
    s$selection_by_panel$entity == "E015" & s$selection_by_panel$dataset_id == 1L &
    s$selection_by_panel$metric == "rare_multiplicity", ]
  testthat::expect_setequal(z$selection_stage, c("full_fit", "studentized_pivot", "studentized_pivot_given_full_fit"))
  testthat::expect_equal(z$n_reference_finite[z$selection_stage == "full_fit"], 40L)
  testthat::expect_equal(z$n_selected_finite[z$selection_stage == "full_fit"], 39L)
  testthat::expect_equal(z$valid_minus_planned[z$selection_stage == "full_fit"], 1 / 40)
  testthat::expect_equal(z$n_reference_finite[z$selection_stage == "studentized_pivot_given_full_fit"], 39L)
  testthat::expect_equal(z$n_selected_finite[z$selection_stage == "studentized_pivot_given_full_fit"], 37L)
  testthat::expect_equal(z$valid_minus_planned[z$selection_stage == "studentized_pivot_given_full_fit"], 0)
  z <- s$selection[s$selection$case_id == "rare12" & s$selection$entity == "E015" &
    s$selection$metric == "rare_multiplicity" & s$selection$selection_stage == "full_fit", ]
  testthat::expect_equal(z$n_outer, 2L)
  testthat::expect_equal(z$n_outer_observed_valid, 1L)
  testthat::expect_equal(z$n_outer_with_valid_and_planned, 1L)
})

testthat::test_that("file-based analysis writes complete auditable tables without figures", {
  f <- study03_analysis_fixture(); path <- tempfile("study03-analysis-"); dir.create(path)
  on.exit(unlink(path, recursive = TRUE), add = TRUE)
  for (name in names(f)) utils::write.csv(f[[name]], file.path(path, paste0(name, ".csv")), row.names = FALSE, na = "")
  answer <- study03_analyze(path, figures = FALSE)
  testthat::expect_setequal(names(answer), c("coverage", "errors", "contrasts", "covariance", "attempts", "studentization", "failure_stages", "selection", "selection_by_panel"))
  testthat::expect_true(all(file.exists(file.path(path, paste0(names(answer), "-summary.csv")))))
  testthat::expect_true(file.exists(file.path(path, "analysis-notes.txt")))
  testthat::expect_equal(nrow(answer$coverage), 60L)
  unlink(file.path(path, "outer.csv"))
  testthat::expect_error(study03_analyze(path, figures = FALSE), "Missing completed-study")
})
