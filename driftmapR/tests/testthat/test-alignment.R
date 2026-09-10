test_that("identical maps align to identity with approximately zero drift", {
  fixture <- fixture_snapshots()
  object <- align_snapshots(drift_data(fixture$data))
  expect_equal(fixture_xy(object$aligned, 1), fixture_xy(object$aligned, 2),
               tolerance = 1e-10)
  expect_inverse_transform(object, fixture)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
  expect_equal(object$transformations$rotation[[1]], diag(2), tolerance = 1e-10)
  expect_equal(as.numeric(object$transformations$translation[[1]]), c(0, 0))
})

test_that("translation is removed and its inverse is recovered", {
  fixture <- fixture_snapshots(translation = c(17, -9))
  object <- align_snapshots(drift_data(fixture$data))
  expect_inverse_transform(object, fixture)
  expect_equal(fixture_xy(object$aligned, 2), as.matrix(fixture$first[c("x", "y")]),
               tolerance = 1e-10)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
})

test_that("a 90-degree rotation is removed using the row-coordinate convention", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(pi / 2))
  object <- align_snapshots(drift_data(fixture$data))
  expect_inverse_transform(object, fixture)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
})

test_that("reflections are allowed and do not create apparent drift", {
  fixture <- fixture_snapshots(rotation = diag(c(-1, 1)))
  object <- align_snapshots(drift_data(fixture$data))
  expect_inverse_transform(object, fixture)
  expect_equal(object$transformations$determinant[2], -1, tolerance = 1e-10)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
})

test_that("rotation and translation are jointly removed", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.73),
                               translation = c(9, -6))
  object <- align_snapshots(drift_data(fixture$data))
  expect_inverse_transform(object, fixture)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
  expect_equal(fixture_xy(object$coordinates, 2), fixture_xy(fixture$data, 2))
})

test_that("uniform scale is removed only when requested", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(-0.61),
                               translation = c(4, -7), scale = 2.5)
  object <- align_snapshots(drift_data(fixture$data), scale = TRUE)
  expect_inverse_transform(object, fixture)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
  unscaled <- align_snapshots(drift_data(fixture$data), scale = FALSE)
  expect_equal(unscaled$transformations$scale[2], 1)
  expect_gt(max(measure_drift(unscaled)$distance), 1)
})

test_that("known entity motion is preserved when stable anchors identify the frame", {
  movement <- data.frame(entity = "H", dx = 1.4, dy = -0.8)
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.41),
                               translation = c(-8, 4), movement = movement)
  object <- align_snapshots(drift_data(fixture$data), anchors = LETTERS[1:7])
  expect_inverse_transform(object, fixture)
  result <- measure_drift(object)
  mover <- result[result$entity == "H", ]
  expect_equal(mover$dx, movement$dx, tolerance = 1e-10)
  expect_equal(mover$dy, movement$dy, tolerance = 1e-10)
  expect_equal(mover$distance, sqrt(1.4^2 + 0.8^2), tolerance = 1e-10)
  expect_equal(result$distance[result$entity != "H"], rep(0, 7), tolerance = 1e-10)
  expect_equal(object$transformations$n_shared[2], 8)
  expect_equal(object$transformations$n_matched[2], 7)
})

test_that("fitting on moving entities exposes the expected frame-estimation attenuation", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.41),
                               movement = data.frame(entity = "H", dx = 1.4, dy = -0.8))
  result <- measure_drift(align_snapshots(drift_data(fixture$data)))
  estimated <- result$distance[result$entity == "H"]
  expect_gt(estimated, 0.5)
  expect_lt(estimated, sqrt(1.4^2 + 0.8^2))
  expect_gt(max(result$distance[result$entity != "H"]), 1e-4)
})

test_that("disappearing and new entities use the common-entity transformation", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.83),
                               translation = c(3, 7), drop = "A",
                               add = data.frame(entity = "NEW", x = 5, y = -4))
  object <- align_snapshots(drift_data(fixture$data))
  expect_inverse_transform(object, fixture)
  expect_equal(object$transformations$n_shared[2], 7)
  expect_equal(object$transformations$n_matched[2], 7)
  expect_setequal(object$transformations$matched_entities[[2]], LETTERS[2:8])
  expect_equal(as.numeric(fixture_xy(object$aligned, 2, "NEW")), c(5, -4),
               tolerance = 1e-10)
  movement <- measure_drift(object)
  expect_setequal(movement$entity, LETTERS[2:8])
  expect_equal(movement$distance, rep(0, 7), tolerance = 1e-10)
})

test_that("sequential alignment targets already aligned previous coordinates", {
  cloud <- fixture_cloud()
  rotations <- list(diag(2), fixture_rotation(0.9), diag(c(-1, 1)))
  offsets <- list(c(0, 0), c(7, -2), c(-4, 9))
  periods <- lapply(1:3, function(t) {
    xy <- sweep(as.matrix(cloud[c("x", "y")]) %*% rotations[[t]],
                2, offsets[[t]], "+")
    data.frame(entity = cloud$entity, time = t, x = xy[, 1], y = xy[, 2])
  })
  data <- do.call(rbind, periods)
  for (strategy in c("previous", "first")) {
    object <- align_snapshots(drift_data(data), reference = strategy)
    expect_equal(fixture_xy(object$aligned, 3), fixture_xy(object$aligned, 1),
                 tolerance = 1e-10)
    expect_equal(measure_drift(object)$distance, rep(0, 16), tolerance = 1e-10)
    expect_equal(unname(object$transformations$rotation[[3]]), t(rotations[[3]]),
                 tolerance = 1e-10)
    expected_reference <- if (strategy == "previous") 2 else 1
    expect_equal(object$transformations$reference_time[3], expected_reference)
  }
})

test_that("previous references support overlap chains without first-period overlap", {
  first <- transform(fixture_cloud(), time = 1)
  middle <- rbind(fixture_cloud(), transform(fixture_cloud(), entity = paste0(entity, "2")))
  middle <- transform(middle, time = 2)
  last <- transform(fixture_cloud(), entity = paste0(entity, "2"), time = 3)
  object <- drift_data(rbind(first, middle, last))
  expect_s3_class(align_snapshots(object, reference = "previous"), "driftmap")
  expect_error(align_snapshots(object, reference = "first"))
})

test_that("degenerate geometry and insufficient shared entities are rejected", {
  fixture <- fixture_snapshots()
  data <- fixture$data[fixture$data$entity %in% LETTERS[1:2], ]
  expect_error(align_snapshots(drift_data(data)))
  data <- fixture$data
  data$y <- 2 * data$x
  expect_error(align_snapshots(drift_data(data)))
  data <- fixture$data
  data$x[data$time == 2] <- 0
  data$y[data$time == 2] <- 0
  expect_error(align_snapshots(drift_data(data)))
  expect_error(align_snapshots(drift_data(fixture$data), anchors = LETTERS[1:2]))
})

test_that("full-rank maps still require an identifiable cross-covariance", {
  first <- data.frame(entity = LETTERS[1:4], time = 1,
                      x = c(-1, 1, 1, -1), y = c(-1, -1, 1, 1))
  second <- data.frame(entity = LETTERS[1:4], time = 2,
                       x = first$x, y = c(1, -1, 1, -1))
  expect_equal(qr(as.matrix(first[c("x", "y")]))$rank, 2L)
  expect_equal(qr(as.matrix(second[c("x", "y")]))$rank, 2L)
  expect_error(align_snapshots(drift_data(rbind(first, second))))
})

test_that("scale, reflection, and translation can be removed together", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.67) %*% diag(c(-1, 1)),
                               translation = c(11, -13), scale = 0.4)
  object <- align_snapshots(drift_data(fixture$data), scale = TRUE)
  expect_inverse_transform(object, fixture)
  expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-10)
  expect_equal(object$transformations$determinant[2], -1, tolerance = 1e-10)
})

test_that("alignment controls reject invalid or ambiguous values", {
  object <- drift_data(fixture_snapshots()$data)
  expect_error(align_snapshots(object, reference = "consensus"))
  expect_error(align_snapshots(object, scale = NA))
  expect_error(align_snapshots(object, scale = 1))
  expect_error(align_snapshots(object, rank_tol = -1))
  expect_error(align_snapshots(object, rank_tol = 0))
  expect_error(align_snapshots(object, rank_tol = 1))
  expect_error(align_snapshots(object, anchors = character()))
})

test_that("alignment diagnostics expose each fitted transformation", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.27),
                               translation = c(6, 4))
  object <- align_snapshots(drift_data(fixture$data))
  required <- c("time", "reference_time", "n_shared", "n_matched", "scale", "rss",
                 "rmse", "disparity", "determinant", "rotation", "translation",
                 "matched_entities")
  expect_true(all(required %in% names(object$transformations)))
  expect_equal(nrow(object$transformations), 2)
  rotation <- object$transformations$rotation[[2]]
  expect_equal(unname(crossprod(rotation)), diag(2), tolerance = 1e-10)
  raw <- fixture_xy(object$coordinates, 2)
  manual <- sweep(object$transformations$scale[2] * raw %*% rotation, 2,
                  object$transformations$translation[[2]], "+")
  expect_equal(unname(manual), unname(fixture_xy(object$aligned, 2)), tolerance = 1e-10)
})
