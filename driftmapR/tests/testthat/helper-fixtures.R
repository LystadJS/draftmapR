# Exact known-truth fixtures use row coordinates: Y = s * X %*% Q + b.
# All clouds have at least three noncollinear points and modest magnitudes.
fixture_cloud <- function() {
  data.frame(
    entity = LETTERS[1:8],
    x = c(-2, 0, 2, -1, 1, 3, -3, 0.5),
    y = c(-1, 2, 0, 3, -2, 2, 1, -0.5),
    stringsAsFactors = FALSE
  )
}

fixture_rotation <- function(angle) {
  matrix(c(cos(angle), -sin(angle), sin(angle), cos(angle)), nrow = 2L)
}

fixture_snapshots <- function(rotation = diag(2), translation = c(0, 0),
                              scale = 1, movement = NULL,
                              drop = character(), add = NULL) {
  cloud <- fixture_cloud()
  first <- transform(cloud, time = 1)
  truth <- cloud
  if (!is.null(movement)) {
    idx <- match(movement$entity, truth$entity)
    truth$x[idx] <- truth$x[idx] + movement$dx
    truth$y[idx] <- truth$y[idx] + movement$dy
  }
  truth <- truth[!truth$entity %in% drop, , drop = FALSE]
  if (!is.null(add)) truth <- rbind(truth, add)
  raw <- sweep(scale * as.matrix(truth[c("x", "y")]) %*% rotation,
               2L, translation, "+")
  second <- data.frame(entity = truth$entity, x = raw[, 1L], y = raw[, 2L],
                       time = 2, stringsAsFactors = FALSE)
  list(
    data = rbind(first, second),
    first = cloud,
    truth = truth,
    forward = list(rotation = rotation, translation = translation, scale = scale),
    inverse = list(rotation = t(rotation),
                   translation = as.numeric(-translation %*% t(rotation) / scale),
                   scale = 1 / scale)
  )
}

fixture_xy <- function(data, time, entities = fixture_cloud()$entity) {
  selected <- data[data$time == time, , drop = FALSE]
  result <- as.matrix(selected[match(entities, selected$entity), c("x", "y"), drop = FALSE])
  rownames(result) <- NULL
  result
}

expect_inverse_transform <- function(object, fixture, tolerance = 1e-10) {
  diagnostics <- object$transformations
  second <- which(diagnostics$time == 2)
  expect_length(second, 1L)
  expect_equal(unname(diagnostics$rotation[[second]]),
               unname(fixture$inverse$rotation), tolerance = tolerance)
  expect_equal(as.numeric(diagnostics$translation[[second]]),
               fixture$inverse$translation, tolerance = tolerance)
  expect_equal(diagnostics$scale[second], fixture$inverse$scale,
               tolerance = tolerance)
  expect_equal(diagnostics$rss[second], 0, tolerance = tolerance)
}
