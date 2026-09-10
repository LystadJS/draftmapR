# Prototype simulation design

The complete reproducible generator is `data-raw/simulate-prototype.R` in the
source checkout. It uses base/recommended R, `driftmapR`, and `ggplot2` only.

| Component | Design |
|---|---|
| Seed | 260910 |
| Periods | 3 ordered snapshots |
| Entities | 104 unique; 96 observed in each period |
| True groups | 3 supplied clusters; these are not fitted cluster labels |
| Presence changes | Four exits and four entrants at each period boundary |
| Adjacent comparisons | 184 entity transitions per fitted scenario |
| Coordinate artifacts | Rotation, reflection, and translation; first frame is identity |
| Individual movement | Four cluster-1 entities |
| Coordinated movement | Cluster 3 translates by (1, -0.5) per period |
| Identifying anchors | 24 known stationary entities from clusters 1 and 2 |
| Noise | Independent coordinate Gaussian SD 0 or 0.025 before transformation |
| Reference | Previous already-aligned snapshot |
| Fitting comparison | All shared entities versus known stationary anchors |

Known true coordinates and transformations are generated before model fitting
and saved separately. Ground-truth movement is calculated by direct adjacent
joins independently of the package movement implementation. Both fitting
strategies retain identical transition denominators. The noiseless anchor
case must recover each displacement vector within `1e-9` coordinate units.

Exported metrics include movement-magnitude bias/RMSE, displacement-vector RMSE,
maximum vector error, mean true and estimated movement, wall-clock fit time, and
stored analysis-object bytes. Metrics are reported both overall and for stable
entities, individually moving entities, and the moving cluster. Timing and
object size describe individual runs and are not generalized benchmarks.

All-shared fitting may attenuate a coordinated true shift because that shift
influences the fitted coordinate frame. It can also induce apparent motion
among stationary entities. The anchored fit illustrates recovery when stable
external reference information is available. It is not an automatic anchor
selection procedure. The noisy version shows descriptive estimation error;
its coordinate SD is not an uncertainty interval.

This is a minimal executable demonstration, not the planned full Monte Carlo
validation study. No interval coverage, false-positive detection, bootstrap,
inferred clusters, split/merge correspondence, or inferential claims are made.
