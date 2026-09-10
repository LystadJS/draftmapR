test_that("aligned plots and plot methods return buildable ggplots", {
  object <- fixture_snapshots(rotation = fixture_rotation(pi / 2),
                               translation = c(4, -2))$data |>
    drift_data() |> align_snapshots()
  graph <- plot_drift_map(object, labels = TRUE)
  expect_s3_class(graph, "ggplot")
  built <- ggplot2::ggplot_build(graph)
  expect_equal(nrow(built$data[[1L]]), 8L)
  expect_equal(nrow(built$data[[2L]]), 16L)
  expect_equal(nrow(built$data[[3L]]), 8L)
  expect_s3_class(plot(object), "ggplot")
})

test_that("trajectories never bridge an unobserved intermediate period", {
  cloud <- fixture_cloud()
  observed <- rbind(transform(cloud, time = 1),
                    transform(cloud[cloud$entity != "H", ], time = 2),
                    transform(cloud, time = 3))
  fit <- observed |> drift_data() |> align_snapshots()
  graph <- plot_drift_map(fit)
  built <- ggplot2::ggplot_build(graph)
  expect_equal(nrow(built$data[[1L]]), 14L)
  expect_equal(nrow(built$data[[2L]]), 23L)
  # H appears in the first/last snapshots but contributes no segment.
  absent_coordinate <- fixture_cloud()[fixture_cloud()$entity == "H", ]
  segments <- graph$layers[[1L]]$data
  expect_false(any(abs(segments$x_from - absent_coordinate$x) < 1e-10 &
                     abs(segments$y_from - absent_coordinate$y) < 1e-10))
})

test_that("raw plots and position-only plots build without fitted transformations", {
  object <- drift_data(fixture_snapshots(translation = c(4, -2))$data)
  graph <- plot_drift_map(object, aligned = FALSE, trajectories = FALSE)
  expect_s3_class(graph, "ggplot")
  built <- ggplot2::ggplot_build(graph)
  expect_length(built$data, 1L)
  expect_equal(nrow(built$data[[1L]]), 16L)
  expect_equal(sort(built$data[[1L]]$x), sort(object$coordinates$x))
  raw_arrows <- ggplot2::ggplot_build(plot_drift_map(object, aligned = FALSE))
  expect_equal(nrow(raw_arrows$data[[1L]]), 8L)
})

test_that("plotting rejects missing alignment, invalid flags, and malformed objects", {
  object <- drift_data(fixture_snapshots()$data)
  expect_error(plot_drift_map(object), "align_snapshots")
  expect_error(plot_drift_map(object, aligned = NA), "aligned")
  expect_error(plot_drift_map(object, aligned = FALSE, labels = 1), "labels")
  expect_error(plot_drift_map(object, aligned = FALSE, trajectories = NA), "trajectories")
  expect_error(plot_drift_map(data.frame(x = 1, y = 2)), "driftmap")
  fit <- align_snapshots(object)
  fit$aligned$x[1L] <- NA_real_
  expect_error(plot_drift_map(fit), "[Aa]ligned|finite|[Mm]alformed")
})

test_that("precise distinct times with identical printed labels remain distinct", {
  data <- fixture_snapshots()$data
  data$time[data$time == 2] <- 1 + 1e-15
  expect_equal(length(unique(data$time)), 2L)
  expect_equal(length(unique(as.character(data$time))), 1L)
  fit <- data |> drift_data() |> align_snapshots()
  graph <- plot_drift_map(fit)
  built <- ggplot2::ggplot_build(graph)
  expect_equal(nrow(built$data[[1L]]), 8L)
  expect_equal(length(unique(built$data[[2L]]$colour)), 2L)
  expect_identical(levels(graph$data$period_label), c("1 (period 1)", "1 (period 2)"))
})
