test_that("coordinate inputs construct an extensible canonical object", {
  fixture <- fixture_snapshots()
  fixture$data$cluster <- rep(c("one", "two"), each = 8L)
  object <- drift_data(fixture$data, original_data = list(features = "retained"),
                       embedding_metadata = list(method = "supplied"))
  expect_s3_class(object, "driftmap")
  expect_true(all(c("entity", "time", "x", "y", "period_index", "cluster") %in%
                    names(object$coordinates)))
  expect_equal(nrow(object$coordinates), nrow(fixture$data))
  expect_null(object$aligned)
  expect_null(object$transformations)
  expect_equal(object$original_data, list(features = "retained"))
  expect_equal(object$embedding_metadata, list(method = "supplied"))
  expect_equal(object$settings$periods, c(1, 2))
  expect_silent(validate_drift_data(object))
})

test_that("numeric periods are chronologically ordered even if input is shuffled", {
  data <- fixture_snapshots()$data
  data$time <- ifelse(data$time == 1, 10, 2)
  object <- drift_data(data[nrow(data):1L, ])
  expect_equal(object$settings$periods, c(2, 10))
  expect_equal(unique(object$coordinates$period_index[
    object$coordinates$time == 2]), 1L)
})

test_that("dates retain their type and are ordered chronologically", {
  data <- fixture_snapshots()$data
  data$time <- as.Date("2025-01-01") + (data$time - 1) * 31
  object <- drift_data(data[nrow(data):1L, ])
  expect_s3_class(object$settings$periods, "Date")
  expect_equal(object$settings$periods, as.Date(c("2025-01-01", "2025-02-01")))
  data$time[1] <- as.Date(Inf, origin = "1970-01-01")
  expect_error(drift_data(data))
})

test_that("categorical times require an unambiguous schedule", {
  data <- fixture_snapshots()$data
  data$time <- ifelse(data$time == 1, "baseline", "followup")
  expect_error(drift_data(data))
  object <- drift_data(data, periods = c("baseline", "followup"))
  expect_equal(object$settings$periods, c("baseline", "followup"))
  data$time <- factor(data$time)
  expect_error(drift_data(data))
  data$time <- ordered(data$time, levels = c("baseline", "followup"))
  expect_s3_class(drift_data(data), "driftmap")
})

test_that("explicit schedules reject missing, duplicate, or unobserved periods", {
  data <- fixture_snapshots()$data
  expect_error(drift_data(data, periods = c(1, 1, 2)))
  expect_error(drift_data(data, periods = c(1, NA, 2)))
  expect_error(drift_data(data, periods = 1))
  expect_error(drift_data(data, periods = c(1, 2, 3)))
  data$time[data$time == 2] <- 3
  expect_error(drift_data(data, periods = 1:3))
  # Gaps in numeric labels alone are not evidence of a missing scheduled period.
  expect_equal(drift_data(data)$settings$periods, c(1, 3))
})

test_that("entity and time keys cannot be missing, blank, or duplicated", {
  data <- fixture_snapshots()$data
  invalid <- data
  invalid$entity[1] <- NA_character_
  expect_error(drift_data(invalid))
  invalid$entity[1] <- ""
  expect_error(drift_data(invalid))
  invalid$entity[1] <- "  "
  expect_error(drift_data(invalid))
  invalid <- data
  invalid$time[1] <- NA_real_
  expect_error(drift_data(invalid))
  expect_error(drift_data(rbind(data, data[1, ])))
})

test_that("distinct numeric entity IDs cannot collapse into the same label", {
  data <- fixture_snapshots()$data
  data$entity <- rep(seq_len(8), 2)
  data$entity[data$time == 2 & data$entity == 1] <- 1 + 1e-15
  expect_false(identical(data$entity[1], data$entity[9]))
  expect_identical(as.character(data$entity[1]), as.character(data$entity[9]))
  expect_error(drift_data(data),
               "Distinct numeric entity IDs lose precision when converted to labels", fixed = TRUE)
})

test_that("entity IDs must be a vector rather than a matrix column", {
  data <- fixture_snapshots()$data
  data$entity <- matrix(data$entity, ncol = 1L)
  expect_error(drift_data(data), "Entity IDs must be nonmissing", fixed = TRUE)
})

test_that("coordinates must be finite numeric values in exactly two dimensions", {
  data <- fixture_snapshots()$data
  invalid <- data
  invalid$x <- as.character(invalid$x)
  expect_error(drift_data(invalid))
  for (value in c(NA_real_, NaN, Inf, -Inf)) {
    invalid <- data
    invalid$y[2] <- value
    expect_error(drift_data(invalid))
  }
  expect_error(drift_data(data, coords = "x"))
  data$z <- 0
  expect_error(drift_data(data, coords = c("x", "y", "z")))
  expect_error(drift_data(data, coords = c("x", "x")))
  expect_error(drift_data(data[, c("entity", "time", "x")]))
})

test_that("custom coordinate columns are canonicalized", {
  data <- fixture_snapshots()$data
  names(data)[names(data) == "x"] <- "axis1"
  names(data)[names(data) == "y"] <- "axis2"
  object <- drift_data(data, coords = c("axis1", "axis2"))
  expect_true(all(c("x", "y") %in% names(object$coordinates)))
  expect_equal(nrow(object$coordinates), 16L)
})

test_that("overlap validation is optional at ingestion and enforced before fitting", {
  data <- fixture_snapshots(drop = LETTERS[3:8])$data
  object <- drift_data(data)
  expect_silent(validate_drift_data(object, check_overlap = FALSE))
  expect_error(validate_drift_data(object, check_overlap = TRUE))
  expect_error(align_snapshots(object))
})

test_that("validation detects inconsistent dimensions or corrupted period indices", {
  object <- drift_data(fixture_snapshots()$data)
  invalid <- object
  invalid$coordinates$period_index <- invalid$coordinates$period_index + 0.1
  expect_error(validate_drift_data(invalid))
  invalid <- object
  invalid$settings$dimensions <- 3L
  expect_error(validate_drift_data(invalid))
  invalid <- object
  invalid$coordinates$y <- NULL
  expect_error(validate_drift_data(invalid))
})
