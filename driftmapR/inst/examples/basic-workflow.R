# Runnable example from README.md; requires installed driftmapR.
library(driftmapR)

first <- data.frame(
  entity = letters[1:5], time = 1,
  x = c(0, 3, 0, 2, 1), y = c(0, 0, 3, 2, 1)
)
truth_second <- first
truth_second$time <- 2
truth_second$x[5] <- truth_second$x[5] + 0.8
truth_second$y[5] <- truth_second$y[5] + 0.6

# A 90-degree row-vector rotation plus arbitrary translation.
rotation <- matrix(c(0, 1, -1, 0), nrow = 2, byrow = TRUE)
raw_second <- truth_second
xy <- as.matrix(truth_second[c("x", "y")]) %*% rotation
xy <- sweep(xy, 2, c(7, -4), "+")
raw_second[c("x", "y")] <- xy

map <- drift_data(rbind(first, raw_second), periods = 1:2)
fit <- align_snapshots(map, reference = "previous", anchors = letters[1:4])
movement <- measure_drift(fit)
movement                          # entity e moves 1 unit; anchors ~0
stopifnot(abs(movement$distance[movement$entity == "e"] - 1) < 1e-10)
fit$transformations[c("time", "reference_time", "n_matched", "rss")]
fit$transformations$rotation[[2]]  # explicit raw-to-aligned rotation
distance_to_anchor(fit, "a")
plot_drift_map(fit, labels = TRUE)
