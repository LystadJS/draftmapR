# driftmapR recovery checkpoint — updated 29 September 2026

This directory consolidates recovered package code, frozen design material, historical evidence, Git history, and fresh verification. It is a **partial recovery checkpoint**, not a complete S07 scientific checkpoint or CRAN release.

Current recovery status: all four checkpoint deltas, all 22 ancestral R1 archives and 25 original-run archives are verified. The R1 inputs include all 6,480 checkpoint objects, all 6,480 draw plans and nine population objects, with companion manifests. Separately preserved original-run inputs include 6,480 draw plans, 6475 distinct checkpoint objects and nine population objects. There are 30 ancestral raw-prefix archives still missing (1,037,578,588 bytes). See `MISSING_ARTIFACTS.md`. Input recovery does not establish completed scientific execution.

## Start here

- `driftmapR/`: working package 0.0.8.9000, copied byte-for-byte from the package vendored in S07-D1 and now confirmed identical to all 188 package files vendored in S07-R1.
- `recovered/`: immutable extracted specification and its nested S06/S05 sources, protocols, plans, and historical evidence.
- `repository/`: unchanged GitHub repository snapshot, including Git history. Its package is older (0.0.3.9000). Its newer README overstates the capabilities of that older code; it is preserved as provenance, not selected as the implementation baseline.
- `archives/`: original recovered archives and a portable Git history bundle.
- `provenance/`: conversation exports, project instructions, and source/chain records.
- `qa/`: newly executed verification scripts and results. Historical results remain in their original source locations.
- `reference/`: recovered presentation assets, preserved without claiming visual validation.

## Verified in this recovery

The specification ZIP passed CRC inspection. All 353 manifest-listed files match their saved sizes and SHA-256 values; all 352 frozen members match with no missing or extra files. The original freeze verifier failed because its ordered comparison depends on platform-specific path sorting; independent path-keyed verification passed without editing frozen bytes.

The pinned Linux runtime archive was recovered, all member payloads were read, and its 117,877,231 bytes and SHA-256 match the historical runtime receipt. It has not been installed or used to execute the frozen study. External BLAS/LAPACK and runtime identity checks remain necessary for scientific reproduction.

Package 0.0.8.9000 installed in an isolated library using native Windows R 4.5.3. All 115 recovered package R files parsed. Fresh package tests yielded **2,619 passing expectations in 147 blocks, zero failures/errors/warnings/skips**. These counts are from this run, not the historical 2,622-assertion claim. No full R CMD check or reserved simulation was run.

The first test harness used `test_dir()` without the package's internal namespace and failed; it was corrected to `test_local()`. The successful test result object was saved before a CSV export error; its scalar summary was then exported successfully. Logs retain both issues. Neither required a package source change. R startup reported locale-setting warnings, distinct from zero warnings in test results.

## Audit evidence added

The user supplied `driftmapR-S07-R1-Recovery-Audit-20260924.zip`. Its 9,895,830 bytes and SHA-256 match the previously inspected receipt. All 54 ZIP entries passed CRC inspection; all 53 manifest-listed payloads, the manifest itself, and the report matched their recorded hashes. The unchanged archive and extracted evidence are now included. This verifies the audit bundle's integrity, not the scientific archives described by the audit.

The exact transport list confirms 12 + 2 + 4 + 3 parts for the four checkpoints. Metadata offsets and total sizes are consistent. Recovery009 now resolves all 128 ancestral archive identities: 25 original, 22 R1, and 81 raw-prefix archives. All 81 receipt hashes and publication identity bindings passed fresh metadata checks. A further 30 published raw archives remain separately labeled candidates. See `provenance/RECOVERY_DEPENDENCIES.md` and its CSV for exact names, hashes, versions, and groups.

## S07-R1 source and Recovery009 added

Both archives were supplied and verified against the recovered audit records, including exact membership, CRC, sizes, SHA-256, and MD5: 460 files in `driftmapR-S07-R1-sources.zip` and 786 files in `driftmapR-S07-R1-Recovery-009.zip`. Sources remain unchanged under `recovered/`. The former includes the S07 recovery runner, execution source, frozen design, and vendored package. Recovery009 contains restoration evidence and controls, not the complete scientific payload.

All 191 R source files in the later source archive parsed with native R 4.5.3. Parsing is not execution. The package files are identical to those previously tested, so those tests were not repeated. No engineering or reserved scientific run was launched.

Runtime distinction: the pinned Linux runtime archive contains installed driftmapR **0.0.7.9000**, as confirmed by its archived DESCRIPTION; the editable vendored source is **0.0.8.9000**. The scientific runner's README also specifies the older pinned engine. Native Windows package-test success for 0.0.8.9000 does not validate substituting that package into the frozen scientific run.

## Checkpoint3915 recovered and inspected

All three supplied transport parts matched their recorded sizes and SHA-256 hashes. Their concatenation reconstructed the 275,145,095-byte archive, SHA-256 `35937acbabb66d70347b89bf14bda5cd057c5b025632e3218f061ce0c83952fc`.

All 17,367 extracted files matched the audit's membership, sizes, CRC, SHA-256, and MD5 records. The reconstructed archive and unchanged extracted files are included; the original transport parts remain in Downloads. Their identities and paths are recorded in `qa/checkpoint3915-verification.json`.

Fresh read-only journal and R-object inspections passed: 3,915 committed panel records, 3,916 readable caches, 6,480 input receipts, 258,466 chunk records, and 4,995 raw delta file bindings. Receipt identities, cache hashes and schemas were checked. Panel `s07_normal_mean_m160-1436` is partial, with one draw chunk and no committed panel record. There are 2,565 uncommitted panels in the 6,480-panel plan. Results and scope are in `qa/checkpoint3915-state/`. These inspections did not execute scientific code or generate simulations.

This is a delta archive. Earlier raw payloads remain unavailable. Continuity from checkpoint2250 is now verified below; earlier links remain unverified. See `MISSING_ARTIFACTS.md`.

## Checkpoint2250 recovered and linked to checkpoint3915

All four supplied parts matched their recorded hashes and sizes, reconstructing the 343,136,277-byte archive with SHA-256 `bbfa48bc60f25fb5e84f4f8225251af5d8f1121c5e3ab2ef26ece640c18f0516`. All 21,041 extracted files passed membership, size, CRC, SHA-256 and MD5 verification against the audit records. Original extracted bytes and the reconstructed archive are preserved.

All four checkpoint2250 journals are exact byte prefixes of checkpoint3915's journals and match its recorded predecessor identities. Checkpoint2250 contains 2,250 committed panel records and 2,251 caches; all cache files matched their recorded hashes. The two recovered deltas contain 15,309 raw files covering contiguous serials 243158–258466, and 3,447 JSON files, all bound to the latest journals by paths, sizes and hashes. See `qa/checkpoint2250-verification.json` and `qa/checkpoint2250-to-3915-lineage.json`.

This verifies the 2250 → 3915 link, not the whole chain or scientific conclusions. The latest stopping point remains 3,915 committed panels plus a partial next panel. No new package tests, simulations, or scientific execution were performed during this addition.

## Checkpoint468 recovered and linked through checkpoint3915

Both supplied parts matched their recorded sizes and SHA-256 values. The reconstructed archive is 135,663,966 bytes with SHA-256 `a63c1189611e247a0b785a6d224bc47a3ead555a668c25f632c67235201e34e8`. All 8,465 extracted files matched the audit's membership, sizes, CRC, SHA-256 and MD5 records; archive and unchanged extracted files are preserved.

All four journals are exact byte prefixes of checkpoint2250's journals and match its predecessor bindings. The 2250 → 3915 links were checked again. Checkpoint468 has 468 committed panel records and 469 caches; all cache files matched their ledger hashes. Across the three recovered deltas, 16,654 raw files cover contiguous serials 241813–258466, and 3,450 JSON files match the latest journals by path, size and hash. See `qa/checkpoint468-verification.json` and `qa/checkpoint468-to-3915-lineage.json`.

The 468 → 2250 → 3915 segment passed verification. Checkpoint464 has since been recovered as described below. No scientific execution or new package tests were performed.

## All four checkpoint deltas recovered

All 12 checkpoint464 transport parts matched their recorded sizes and SHA-256 values. The reconstructed archive is 1,207,516,379 bytes, SHA-256 `d1fae48aab8d7afab071bdcbd34f91802e8f1cc12527e262c75618e7fa7c9c6f`. All 86,023 extracted files matched the audit's membership, size, CRC, SHA-256 and MD5 records. See `qa/checkpoint464-verification.json`.

The fresh full-segment lineage audit passed all 32 checks, including all 12 exact predecessor journal-prefix comparisons across **464 → 468 → 2250 → 3915**. Across these four archives, 95,374 recovered raw files cover contiguous serials 163093–258466, and 3,643 JSON files match the latest journal records. All latest cache files also match their ledger hashes. The original historical audit script was adapted only for local paths/output, preserving the original script unchanged. Detailed results are in `qa/full-chain-state/checkpoint-lineage-audit.json`.

This completes recovery of the four checkpoint deltas, not reconstruction of the entire scientific workspace. Raw serials 1–163092 and additional earlier checkpoint inputs remain unavailable. The next section records recovered ancestral inputs and the reduced missing-file list. This audit did not rerun simulations, validate scientific conclusions, or launch the frozen collection process. The latest saved stopping point remains 3,915 committed panels and one partial next panel.

## R1-01 ancestral inputs recovered — 29 September 2026

All three `driftmapR-S07-R1-checkpoint-01-checkpoints-part-001.tar.gz` through `-003.tar.gz` archives matched the immutable dependency identities and Recovery009 receipts (572,195,430 bytes total). All 13,102 regular files passed membership, size, SHA-256 and MD5 checks; compressed streams passed CRC verification. Original archives and unchanged extracted files are preserved separately.

Contents include all 6,480 draw-plan objects, 59 checkpoint objects and nine population objects, each with its companion manifest, plus six administrative files. All 13,096 files referenced by the latest per-job input receipts match those receipt MD5s. The six administrative files are not referenced by those per-job receipts and instead retain their verified archive/member provenance. The 59 checkpoint objects also match the latest compact-cache checkpoint identities. See `qa/r1-01-verification.json`, `qa/r1-01-receipt-bindings.csv`, and the corresponding log.

The first receipt-audit harness incorrectly required administrative files to occur in per-job receipts; its initial failure log is preserved. The corrected audit explicitly accounts for those six files and passes. Native R emitted startup locale warnings. No scientific computation or package tests were run. The missing ancestral set is now **125 archives / 12,713,813,033 bytes** (25 original, 19 R1, 81 raw-prefix). Exact outstanding identities are in `provenance/MISSING_ANCESTRAL_ARCHIVES.csv` and `.md`.

## R1-02 ancestral inputs recovered — 29 September 2026

All 16 `driftmapR-S07-R1-checkpoint-02-checkpoints-part-001.tar.gz` through `-016.tar.gz` archives passed their recorded archive identities, complete member inventories, size/SHA-256/MD5 and gzip CRC checks. The archives total 3,840,913,714 bytes and contain 868 regular files: 434 checkpoint objects and 434 companion manifests. All 868 file identities match the latest per-job receipts; all 434 checkpoint MD5s match the latest compact-cache ledger. They are distinct from the 59 R1-01 checkpoint objects, bringing the recovered ancestral total to 493. See `qa/r1-02-verification.json` and `qa/r1-02-receipt-bindings.csv`/`.log`.

The remaining ancestral set is now 109 archives: 25 original, three R1-03, and 81 raw-prefix archives (8,872,899,319 bytes total). All original supplied archives and extracted bytes are preserved separately. Read-only verification ran under native R 4.5.3 with startup locale warnings; no package tests, simulations, frozen scientific execution, or scientific conclusion checks were performed in this addition. Saved execution progress remains 3,915 committed panels and one partial next panel.

## R1-03 recovered: complete R1 checkpoint and draw-plan inputs

All three `driftmapR-S07-R1-checkpoint-03-checkpoints-part-001.tar.gz` through `-003.tar.gz` archives passed their recorded identities, complete member inventories, size/SHA-256/MD5 and gzip CRC checks. These archives total 722,620,639 bytes and contain 11,974 regular files: 5,987 checkpoint objects and companion manifests. All 11,974 file identities match the latest per-job receipts. Of these checkpoint objects, 3,423 match existing compact-cache ledger identities; 2,564 belong to inputs without a compact cache. Their absence from the cache does not indicate missing input files or completed collection.

The cumulative audit now confirms exactly 6,480 distinct checkpoint inputs and 6,480 distinct draw plans across all 22 R1 archives, with both key sets equal to the latest 6,480 input-receipt keys. All 3,916 applicable cache checkpoint hashes agree. See `qa/r1-03-verification.json`, `qa/r1-03-receipt-bindings.csv`/`.log`, and `qa/r1-input-coverage.json`.

The inherited verification harness initially assumed every checkpoint had a compact cache. This assumption failed at an unprocessed panel; it was corrected to bind only applicable cache entries and use input receipts for all recovered files. No recovered bytes were changed. The corrected integrity and coverage audits passed. Native R emitted startup locale warnings; no simulations or package tests were rerun. Scientific saved progress remains 3,915 committed panels and one partial next panel. The 106 missing original/raw archives total 8,150,278,680 bytes.

## First three original-run archives recovered

The original execution-checkpoint archive and checkpoint-02/checkpoint-03 archives (612,311,470 bytes total) match their immutable archive SHA-256 identities. All 13,142 regular members match Recovery009's inventories, sizes and MD5s; compressed streams passed CRC checks. SHA-256 values were freshly computed for every member; historical per-member SHA-256 was not supplied by these original-run receipts. The 6,480 draw plans, 80 checkpoint objects and nine population objects are preserved with their companion manifests and four administrative files. They remain separate from the later R1 versions. See `qa/original-001-003-verification.json`.

No scientific execution or package tests were rerun. The remaining ancestral set is 103 archives / 7,537,967,210 bytes. The user has now requested a commit and push after each completed recovery step; see `GIT_WORKFLOW.md` for persistence scope and destination handling.

## Original-run archives 004–006 recovered

Both checkpoint-04 archives and checkpoint-05 part-001 (597,817,737 bytes total) passed their immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 46 regular files are checkpoint objects or their companion manifests: 23 objects with no key overlap with the previously recovered 80 original-run checkpoints. Original-run coverage is now 103 distinct checkpoint objects. Fresh SHA-256 values are recorded for all members; historical per-member SHA-256 was not supplied by these receipts. See `qa/original-004-006-verification.json`.

This batch preserves historical original-run bytes separately from R1 inputs. No package tests or scientific execution were rerun. The remaining ancestral set is 100 archives / 6,940,149,473 bytes. Source, evidence and missing-file records are committed and pushed to the confirmed `LystadJS/draftmapR` repository after the recovery step; large scientific archives remain in the local consolidated checkpoint.

## Original-run archives 007-009 recovered

`driftmapR-S07-checkpoint-05-part-002.tar.gz`, `driftmapR-S07-checkpoint-06-part-001.tar.gz`, `driftmapR-S07-checkpoint-06-part-002.tar.gz` (507,962,576 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 114 regular files are preserved unchanged. This batch adds 57 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 160 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-007-009-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## Original-run archives 010-012 recovered

`driftmapR-S07-checkpoint-07-part-001.tar.gz`, `driftmapR-S07-checkpoint-07-part-002.tar.gz`, `driftmapR-S07-checkpoint-07-part-003.tar.gz` (633,260,264 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 42 regular files are preserved unchanged. This batch adds 21 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 181 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-010-012-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## Original-run archives 013-015 recovered

`driftmapR-S07-checkpoint-08-part-001.tar.gz`, `driftmapR-S07-checkpoint-08-part-002.tar.gz`, `driftmapR-S07-checkpoint-08-part-003.tar.gz` (603,278,306 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 68 regular files are preserved unchanged. This batch adds 34 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 215 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-013-015-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## Original-run archives 016-018 recovered

`driftmapR-S07-checkpoint-09-part-001.tar.gz`, `driftmapR-S07-checkpoint-09-part-002.tar.gz`, `driftmapR-S07-checkpoint-10-part-001.tar.gz` (675,596,338 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 282 regular files are preserved unchanged. This batch adds 141 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 356 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-016-018-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## Original-run archives 019-021 recovered

`driftmapR-S07-checkpoint-10-part-002.tar.gz`, `driftmapR-S07-checkpoint-10-part-003.tar.gz`, `driftmapR-S07-checkpoint-11-part-001.tar.gz` (670,242,329 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 218 regular files are preserved unchanged. This batch adds 109 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 465 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-019-021-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## Original-run archives 022-025 recovered

All 25 original-run archives are recovered. Their 6,480 draw-plan keys match the latest input receipts; 6,475 have original checkpoint objects. Five inputs have infrastructure-incident records instead: s07_sparse_m12-0018, -0020, -0030, -0032 and -0037. These five records are preserved separately and are not counted as checkpoint objects. No replacement checkpoint filenames are established by this evidence. Complete R1 inputs remain a separate lineage. See `qa/original-complete-coverage.json`.

`driftmapR-S07-checkpoint-11-part-002.tar.gz`, `driftmapR-S07-checkpoint-12-part-001.tar.gz`, `driftmapR-S07-checkpoint-12-part-002.tar.gz`, `driftmapR-S07-checkpoint-12-part-003.tar.gz` (785,607,654 bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All 12,027 regular files are preserved unchanged. This batch adds 6010 checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is 6475 distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-022-025-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.

## First raw-output archives recovered

First three raw-output archives: 24,261 files preserved; 24,261 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-000-002-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 003-005 recovered

Cumulative raw-output recovery after batch 003-005: 46,519 files preserved; 46,519 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-003-005-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 006-008 recovered

Cumulative raw-output recovery after batch 006-008: 60,600 files preserved; 60,600 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-006-008-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 009-011 recovered

Cumulative raw-output recovery after batch 009-011: 65,451 files preserved; 65,451 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-009-011-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 012-014 recovered

Cumulative raw-output recovery after batch 012-014: 70,302 files preserved; 70,302 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-012-014-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 015-017 recovered

Cumulative raw-output recovery after batch 015-017: 75,153 files preserved; 75,153 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-015-017-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 018-020 recovered

Cumulative raw-output recovery after batch 018-020: 79,999 files preserved; 79,999 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-018-020-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 021-023 recovered

Cumulative raw-output recovery after batch 021-023: 84,855 files preserved; 84,855 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-021-023-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 024-026 recovered

Cumulative raw-output recovery after batch 024-026: 90,946 files preserved; 90,946 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-024-026-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 027-029 recovered

Cumulative raw-output recovery after batch 027-029: 96,794 files preserved; 96,794 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-027-029-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 030-032 recovered

Cumulative raw-output recovery after batch 030-032: 103,467 files preserved; 103,467 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-030-032-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 033-035 recovered

Cumulative raw-output recovery after batch 033-035: 109,721 files preserved; 109,721 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-033-035-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 036-038 recovered

Cumulative raw-output recovery after batch 036-038: 115,142 files preserved; 115,142 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-036-038-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 039-041 recovered

Cumulative raw-output recovery after batch 039-041: 116,394 files preserved; 116,394 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-039-041-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 042-044 recovered

Cumulative raw-output recovery after batch 042-044: 117,645 files preserved; 117,645 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-042-044-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 045-047 recovered

Cumulative raw-output recovery after batch 045-047: 118,890 files preserved; 118,890 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-045-047-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Raw-output batch 048-050 recovered

Cumulative raw-output recovery after batch 048-050: 120,147 files preserved; 120,147 match the latest chunk journal. 0 additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-048-050-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed.

## Most comprehensive later checkpoint identified

The verified 24 September audit bundle identifies an incremental chain ending at **checkpoint3915-014**: Recovery009 → 464 → 468 → 2250 → 3915. Its saved stopping point is now independently confirmed by inspecting the recovered latest snapshot. The complete scientific payload chain has not been reconstructed here, and this audit does not validate scientific conclusions or mark the simulation study complete. Later operational records do not preserve later scientific payloads.

See `MISSING_ARTIFACTS.md` for the exact known recovery targets. Do not run the old collection commands directly or replace the pinned scientific environment with the native Windows test environment.


## Checkpoint storage status after raw batch 045-047

The new cumulative ZIP attempt exhausted disk space and its incomplete output was removed. The recovered directory and GitHub evidence contain batch 045-047. At the time of the failed attempt, the last verified full ZIP was `driftmapR-recovery-20261005-raw-042-044-integrated.zip`. A separate incremental bundle passed full member verification; consult its receipt before use. It requires that exact base and is not standalone. The user authorized deletion of the superseded original-004-006 and original-007-009 full ZIPs; their receipts are retained. After the authorized cleanup, the full checkpoint driftmapR-recovery-20261006-raw-045-047-integrated.zip passed CRC and SHA256 verification for all 305,865 manifest files (28,377,504,819 bytes). It is now the latest verified full checkpoint. See provenance/checkpoint-raw-045-047-bundle.json. The builder now checks available disk space before creating a cumulative ZIP. The ZIP preserves the reports as they stood during construction; this completion record and its external receipt were added afterward.

## Checkpoint storage after raw batch 048-050

All 1,257 files in this batch passed recovery checks. Available disk space (26,603,589,632 bytes at preflight) is less than the existing full checkpoint alone (28,377,504,819 bytes). This batch uses an incremental checkpoint requiring the exact driftmapR-recovery-20261006-raw-045-047-integrated.zip base. Keep that base and the incremental ZIP together; the incremental is not standalone. Follow INCREMENTAL-MANIFEST.json and verify the external receipt. Overlay reports supersede base reports; the base FILE_MANIFEST.json covers the base only, while INCREMENTAL-MANIFEST.json covers added or updated files. The working recovery directory contains the consolidated files. No additional backups were deleted.

