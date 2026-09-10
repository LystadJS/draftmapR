# Runnable, deterministic rank-2 feature example. No bootstrap inference.
library(driftmapR)
first <- data.frame(entity = letters[1:8], time = 1,
                    u = c(-2, -1, 0, 1, 2, 3, 1, -1),
                    v = c(0, 1, -1, 2, 0, 1, 3, -2))
second <- transform(first, time = 2)
second$u[second$entity == "h"] <- second$u[second$entity == "h"] + 0.6
second$v[second$entity == "h"] <- second$v[second$entity == "h"] - 0.8
panel <- rbind(first, second)
# Orthonormal loading: these four columns retain the original distances.
panel$f1 <- panel$u / sqrt(2)
panel$f2 <- panel$v / sqrt(2)
panel$f3 <- panel$u / sqrt(2)
panel$f4 <- panel$v / sqrt(2)
features <- paste0("f", 1:4)
raw <- embed_snapshots(panel[c("entity", "time", features)], features, method = "pca")
fit <- align_snapshots(raw, anchors = letters[1:7])
movement <- measure_drift(fit)
print(movement)
print(fit$diagnostics$embedding)
stopifnot(max(movement$distance[movement$entity != "h"]) < 1e-8,
          abs(movement$distance[movement$entity == "h"] - 1) < 1e-8)
mds_fit <- embed_snapshots(panel[c("entity", "time", features)], features,
                           method = "cmds") |>
  align_snapshots(anchors = letters[1:7])
mds_movement <- measure_drift(mds_fit)
stopifnot(max(abs(mds_movement$distance - movement$distance)) < 1e-8)
print(plot_drift_map(fit))
