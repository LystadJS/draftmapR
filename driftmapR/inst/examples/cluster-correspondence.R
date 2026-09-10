# Runnable cluster correspondence example from README.md.
library(driftmapR)
labels <- data.frame(
  entity = rep(letters[1:6], 2), time = rep(1:2, each = 6),
  x = rep(c(0, 1, 0, 4, 5, 4), 2), y = rep(c(0, 0, 1, 0, 0, 1), 2),
  cluster = rep(c("A", "B", "renamed_2", "renamed_1"), each = 3)
)
matched <- drift_data(labels) |> match_clusters()
matched$clusters
matched$diagnostics$cluster_matching$assignments
stopifnot(identical(matched$clusters$cluster_id[1:6],
                    matched$clusters$cluster_id[7:12]))
