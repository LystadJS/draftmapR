# Prespecified full-versus-tangent comparison, tested on fabricated indicators.
if (!exists("study02_tangent_contrasts", mode = "function")) {
  candidates <- c("driftmapR/data-raw/calibration-02", "data-raw/calibration-02", "..", ".")
  directory <- candidates[file.exists(file.path(candidates, "supplemental-analysis.R"))][1L]
  source(file.path(directory, "analyze.R"), local = TRUE)
  source(file.path(directory, "supplemental-analysis.R"), local = TRUE)
}

study02_supplemental_fixture <- function() {
  x <- expand.grid(dataset_id = 1:4, estimator = c("refit_plugin", "tangent_oracle"),
    stringsAsFactors = FALSE)
  x$m <- 20L
  x$anchor <- "original"
  x$entity <- "E015"
  x$budget <- 399L
  x$method <- "wald"
  x$delivered <- !(x$estimator == "tangent_oracle" & x$dataset_id == 4L)
  x$covered <- ifelse(x$estimator == "refit_plugin", x$dataset_id %in% 1:2,
    x$dataset_id %in% c(1L, 3L, 4L))
  x$covered[!x$delivered] <- NA
  x[rev(seq_len(nrow(x))), ]
}

testthat::test_that("supplemental full/tangent contrasts pair datasets and distinguish delivery", {
  x <- study02_supplemental_fixture()
  z <- study02_tangent_contrasts(x)
  conditional <- z[z$metric == "conditional_coverage_joint_delivery", ]
  yield <- z[z$metric == "operational_yield", ]
  delivery <- z[z$metric == "delivery", ]
  testthat::expect_equal(nrow(z), 3L)
  testthat::expect_true(all(z$level_from == "refit_plugin" & z$level_to == "tangent_oracle"))
  testthat::expect_equal(conditional$n_pairs, 3)
  testthat::expect_equal(conditional$difference, 0)
  testthat::expect_equal(conditional$mcse, 1 / sqrt(3))
  testthat::expect_equal(conditional$improved, 1)
  testthat::expect_equal(conditional$worsened, 1)
  testthat::expect_equal(yield$n_pairs, 4)
  testthat::expect_equal(yield$difference, 0)
  testthat::expect_equal(yield$mcse, sqrt(1 / 6))
  testthat::expect_equal(delivery$difference, -.25)
  testthat::expect_equal(delivery$mcse, .25)
  testthat::expect_equal(study02_tangent_contrasts(x[c(2, 6, 1, 8, 3, 7, 4, 5), ]), z, ignore_attr = TRUE)
})

testthat::test_that("supplemental analysis rejects broken pairs and retains zero joint delivery", {
  x <- study02_supplemental_fixture()
  testthat::expect_error(study02_tangent_contrasts(x[-1L, ]), "identical unique dataset")
  x$delivered <- FALSE
  x$covered <- NA
  z <- study02_tangent_contrasts(x)
  conditional <- z[z$metric == "conditional_coverage_joint_delivery", ]
  testthat::expect_equal(conditional$n_pairs, 0)
  testthat::expect_true(is.na(conditional$difference))
  testthat::expect_true(all(z$difference[z$metric != "conditional_coverage_joint_delivery"] == 0))
})
