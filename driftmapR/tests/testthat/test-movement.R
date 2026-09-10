test_that("movement requires an explicitly fitted coordinate system", {
  object <- drift_data(fixture_snapshots()$data)
  expect_error(measure_drift(object))
})

test_that("missing aligned columns produce an informative validation error", {
  object <- align_snapshots(drift_data(fixture_snapshots()$data))
  for (column in c("entity", "time", "period_index", "x", "y")) {
    invalid <- object
    invalid$aligned[[column]] <- NULL
    expect_error(measure_drift(invalid), "Malformed aligned coordinates", fixed = TRUE)
  }
})

test_that("movement returns tidy endpoints, displacement, and Euclidean distance", {
  fixture <- fixture_snapshots(movement = data.frame(entity = "H", dx = 3, dy = 4))
  object <- align_snapshots(drift_data(fixture$data), anchors = LETTERS[1:7])
  result <- measure_drift(object)
  expect_s3_class(result, "data.frame")
  expect_true(all(c("entity", "time_from", "time_to", "x_from", "y_from",
                    "x_to", "y_to", "dx", "dy", "distance") %in% names(result)))
  expect_equal(result$dx, result$x_to - result$x_from, tolerance = 1e-10)
  expect_equal(result$dy, result$y_to - result$y_from, tolerance = 1e-10)
  expect_equal(result$distance, sqrt(result$dx^2 + result$dy^2), tolerance = 1e-10)
  expect_equal(result$distance[result$entity == "H"], 5, tolerance = 1e-10)
  expect_equal(unique(result$time_from), 1)
  expect_equal(unique(result$time_to), 2)
})

test_that("movement never bridges a period in which an entity was absent", {
  cloud <- fixture_cloud()
  first <- transform(cloud, time = 1)
  middle <- transform(cloud[cloud$entity != "H", ], time = 2)
  last <- transform(cloud, time = 3)
  object <- align_snapshots(drift_data(rbind(first, middle, last)))
  result <- measure_drift(object)
  expect_false("H" %in% result$entity)
  expect_equal(nrow(result), 14)
  expect_true(all(result$time_to - result$time_from == 1))
})

test_that("movement preserves Date period values", {
  data <- fixture_snapshots()$data
  data$time <- as.Date("2025-01-01") + data$time - 1
  result <- measure_drift(align_snapshots(drift_data(data)))
  expect_s3_class(result$time_from, "Date")
  expect_s3_class(result$time_to, "Date")
})

test_that("distance to a fixed anchor is computed in aligned coordinates", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.4), translation = c(7, 2))
  object <- align_snapshots(drift_data(fixture$data))
  result <- distance_to_anchor(object, anchor = c(0, 0))
  expect_true(all(c("entity", "time", "x", "y", "anchor_x", "anchor_y", "distance") %in%
                    names(result)))
  expect_equal(result$distance, sqrt(result$x^2 + result$y^2), tolerance = 1e-10)
  expect_equal(result$anchor_x, rep(0, nrow(result)))
  expect_equal(result$anchor_y, rep(0, nrow(result)))
})

test_that("an entity anchor uses its contemporaneous aligned position", {
  fixture <- fixture_snapshots(movement = data.frame(entity = "H", dx = 1, dy = -2))
  object <- align_snapshots(drift_data(fixture$data), anchors = LETTERS[1:7])
  result <- distance_to_anchor(object, anchor = "H")
  expect_equal(result$distance[result$entity == "H"], c(0, 0), tolerance = 1e-10)
  for (period in 1:2) {
    xy <- as.numeric(fixture_xy(object$aligned, period, "H"))
    selected <- result[result$time == period, ]
    expect_equal(selected$anchor_x, rep(xy[1], nrow(selected)), tolerance = 1e-10)
    expect_equal(selected$anchor_y, rep(xy[2], nrow(selected)), tolerance = 1e-10)
  }
})

test_that("anchors must be defined and available in every period", {
  object <- align_snapshots(drift_data(fixture_snapshots(drop = "H")$data))
  expect_error(distance_to_anchor(object, anchor = "H"))
  expect_error(distance_to_anchor(object, anchor = "not_present"))
  expect_error(distance_to_anchor(object, anchor = c(0, 1, 2)))
  expect_error(distance_to_anchor(object, anchor = c(0, NA_real_)))
})
