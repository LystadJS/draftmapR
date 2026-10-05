# Outstanding recovery artifacts

The audit ZIP has now been supplied and verified. The remaining artifacts below are identified by that bundle or earlier records. Identification does not mean payload recovery. Exact recorded filenames, versions, IDs, and hashes are in `provenance/RECOVERY_DEPENDENCIES.csv`; a readable list is in `provenance/RECOVERY_DEPENDENCIES.md`. Candidate publication entries are labeled separately from known dependencies.

## Highest priority

All 21 transport parts for checkpoint464, checkpoint468, checkpoint2250 and checkpoint3915 are now recovered and verified. No more parts are needed for those four archives. All 12 exact predecessor journal-prefix comparisons passed across 464 → 468 → 2250 → 3915.

Full historical/scientific reconstruction still requires 57 raw-prefix archives (2,112,868,873 bytes). All 25 original and 22 R1 archives are recovered. 84,855 of the previously missing 163,092 raw journal entries now match restored bytes; 78,237 remain missing. Archived versions differing from the current journal remain separate. Exact serial gaps are in `qa/raw-prefix-coverage.json`.

Next provide these independent archives:

- `driftmapR-S07-R1-r1-final-raw20260921-04-raw-csv-004-products-part-001.tar.gz`
- `driftmapR-S07-R1-r1-final-raw20260921-04-raw-csv-005-products-part-001.tar.gz`
- `driftmapR-S07-R1-r1-final-raw20260921-04-raw-csv-006-products-part-001.tar.gz`

Full filenames and hashes: `provenance/MISSING_ANCESTRAL_ARCHIVES.csv`.

## Original-run coverage limitation

All 25 original-run archives are recovered. Their 6,480 draw-plan keys match the latest input receipts; 6,475 have original checkpoint objects. Five inputs have infrastructure-incident records instead: s07_sparse_m12-0018, -0020, -0030, -0032 and -0037. These five records are preserved separately and are not counted as checkpoint objects. No replacement checkpoint filenames are established by this evidence. Complete R1 inputs remain a separate lineage. See `qa/original-complete-coverage.json`.

## Supplemental provenance

Standalone `driftmapR-S07-R1-checkpoint468-012-manifest.json` and `driftmapR-S07-R1-checkpoint2250-013-manifest.json` would supplement provenance, but archive verification has already passed against the audit records and embedded manifests. The checkpoint3915 original manifest and four roundtrip proofs are included in the audit bundle and need not be reuploaded.

Other supplemental evidence: `driftmapR-S07-R1-engineering.tar.gz`, `driftmapR-S07-R1-handoff.md`, and original audit `-receipt.json` / `-readback-proof.json` files. These are distinct from the missing ancestral scientific archives.

## Earlier dependencies and operational provenance

All 128 earlier archive identities are now resolved: 25 original, 22 R1, and 81 raw-prefix archives. The first 47 total 10,221,806,457 bytes; the 81 raw-prefix archives total 3,064,202,006 bytes. Each raw identity was matched to its hash-bound Recovery009 restoration receipt and publication record. Exact names and hashes are in `provenance/RECOVERY_DEPENDENCIES.csv` under ancestral groups. This is metadata verification; all 22 R1 ancestral archives and 25 original-run archives have been restored; the remaining payloads are still missing. Another 30 published raw candidates are separately labeled and are not automatically additional required inputs.

Preserve `driftmapR-S07-R1-checkpoint361-008.zip.part001` through `.part003`, especially **part002 version 1**, plus `driftmapR-S07-R1-checkpoint361-008-manifest.json`. The exact versioned IDs are recorded in the dependency CSV. The archive's historical name was `driftmapR-S07-R1-progress-20260922-007a.zip`; do not infer identity merely from a renamed file.

Known operational archives in Library:

- `driftmapR-S07-R1-Launch-014.zip` and `driftmapR-S07-R1-Launch-014-receipt.json`.
- `driftmapR-S07-R1-Capacity-and-Fallback-014.zip` and its `-receipt.json` / `-save-confirmation.json`.
- `driftmapR-S07-R1-Later-Phase-Controls-014.zip` and its `-receipt.json` / `-save-confirmation.json`.

Earlier supplemental engineering archives identified in the conversation: `driftmapR-S07-I1-sources.zip`, `driftmapR-S07-I1-engineering.tar.gz`, and `driftmapR-S07-I1-validation.md`.

## Already recovered: do not reupload

Cumulative raw-output recovery after batch 021-023: 84,855 files preserved; 84,855 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-021-023-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 018-020: 79,999 files preserved; 79,999 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-018-020-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 015-017: 75,153 files preserved; 75,153 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-015-017-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 012-014: 70,302 files preserved; 70,302 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-012-014-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 009-011: 65,451 files preserved; 65,451 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-009-011-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 006-008: 60,600 files preserved; 60,600 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-006-008-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

Cumulative raw-output recovery after batch 003-005: 46,519 files preserved; 46,519 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-003-005-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

First three raw-output archives: 24,261 files preserved; 24,261 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-000-002-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

- `driftmapR-S07-checkpoint-11-part-002.tar.gz`, `driftmapR-S07-checkpoint-12-part-001.tar.gz`, `driftmapR-S07-checkpoint-12-part-002.tar.gz`, `driftmapR-S07-checkpoint-12-part-003.tar.gz` — all 12027 files verified.

- `driftmapR-S07-checkpoint-10-part-002.tar.gz`, `driftmapR-S07-checkpoint-10-part-003.tar.gz`, `driftmapR-S07-checkpoint-11-part-001.tar.gz` — all 218 files verified.

- `driftmapR-S07-checkpoint-09-part-001.tar.gz`, `driftmapR-S07-checkpoint-09-part-002.tar.gz`, `driftmapR-S07-checkpoint-10-part-001.tar.gz` — all 282 files verified.

- `driftmapR-S07-checkpoint-08-part-001.tar.gz`, `driftmapR-S07-checkpoint-08-part-002.tar.gz`, `driftmapR-S07-checkpoint-08-part-003.tar.gz` — all 68 files verified.

- `driftmapR-S07-checkpoint-07-part-001.tar.gz`, `driftmapR-S07-checkpoint-07-part-002.tar.gz`, `driftmapR-S07-checkpoint-07-part-003.tar.gz` — all 42 files verified.

- `driftmapR-S07-checkpoint-05-part-002.tar.gz`, `driftmapR-S07-checkpoint-06-part-001.tar.gz`, `driftmapR-S07-checkpoint-06-part-002.tar.gz` — all 114 files verified.

- `driftmapR-S07-checkpoint-04-part-001.tar.gz`, `driftmapR-S07-checkpoint-04-part-002.tar.gz`, and `driftmapR-S07-checkpoint-05-part-001.tar.gz` — all 46 original-run files verified.

- `driftmapR-S07-execution-checkpoint-part-001.tar.gz`, `driftmapR-S07-checkpoint-02-part-001.tar.gz`, and `driftmapR-S07-checkpoint-03-part-001.tar.gz` — 13,142 original-run files verified.

- `driftmapR-S07-R1-checkpoint-03-checkpoints-part-001.tar.gz` through `-003.tar.gz` — three independent archives; all 11,974 files and complete R1 input key coverage verified.

- `driftmapR-S07-R1-checkpoint-02-checkpoints-part-001.tar.gz` through `-016.tar.gz` — 16 independent archives, all 868 files verified.

- `driftmapR-S07-R1-checkpoint-01-checkpoints-part-001.tar.gz` through `-003.tar.gz` — three independent archives, all 13,102 files verified.

- `driftmapR-S07-R1-checkpoint464-011.zip.part001` through `.part012` — reconstructed archive and all 86,023 files verified; full four-checkpoint journal segment verified.

- `driftmapR-S07-R1-checkpoint468-012.zip.part001` through `.part002` — reconstructed archive and 8,465 files verified; journal continuity through checkpoint2250 to checkpoint3915 confirmed.
- `driftmapR-S07-R1-checkpoint2250-013.zip.part001` through `.part004` — reconstructed archive and 21,041 files verified; exact journal continuity to checkpoint3915 confirmed.
- `driftmapR-S07-R1-checkpoint3915-014.zip.part001` through `.part003` — reconstructed archive and all 17,367 files verified; saved state inspected read-only.
- `driftmapR-S07-R1-sources.zip` — 460 files verified.
- `driftmapR-S07-R1-Recovery-009.zip` — 786 files verified.
- `driftmapR-S07-R1-Recovery-Audit-20260924.zip`, including its report, scripts, results, and dependency indexes.
- `driftmapR-S07-D1-specification.zip`.
- `driftmapR-study06-pinned-runtime.tar.gz` (matching historical hash).
- GitHub `LystadJS/draftmapR` at `b77775ee6502a2b6b930b21c320659f14022fee3` and its available history.

The native package test dependency `clue` 0.3-68 was installed in an isolated QA library. This does not establish the frozen scientific dependency/runtime environment.







