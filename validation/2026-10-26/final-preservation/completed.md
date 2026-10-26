# Final preservation completed

The final archive is `D:/driftmapR-final-preservation-20261026/driftmapR-final-preservation-20261026.zip` on the user-selected T7 Shield. Its verified size is 43,704,671,136 bytes. `verification.json` records its SHA-256 and the embedded manifest checksum.

## Executed verification

- Read all 342,417 payload files completely, checking ZIP CRC and SHA-256 against the embedded `SHA256SUMS.jsonl` manifest.
- Independently compared retained study source payloads: native Windows reads for read-only base files, Linux reads for overlay-owned files and materialized links. Host provenance and runtime-reconstruction files also matched. Generated preservation metadata is distinguished from recovered source payloads.
- Matched the original execution-complete receipt and all three final audit receipts by SHA-256. The preserved passed receipts report 6,480 panels and 1,313,520 draws.
- Verified the repository Git bundles; the latest bundled history is revision `4a02e291749f7c62b937c01962f360682c0643e0`. The later sealing fix is retained in GitHub history.
- Parsed all 23,751 exported runtime TAR entries, including restored Cairo and Pango libraries.
- Reopened and verified the embedded manifest, flushed the archive with a Windows-compatible writable handle, computed the whole-archive SHA-256, and renamed the successfully verified archive from its partial name.

The archive contains the current reconstructed study, runtime, provenance, repository history, and restore instructions. It contains private operational records and has not been published to GitHub. Only tooling and safe verification metadata are committed.

## Repairs and preservation boundaries

The initial exporter exhausted host memory near file 335,189. The completed ZIP prefix was copied to a new file, the interrupted final member was replaced, and the missing payloads were appended. Streaming TAR header retention was removed. Container interruptions were resolved by restarting the idle container and restoring the original mounts, without restarting study execution. A Windows read-only-handle flush error was corrected before final sealing.

All source hashes and all archived payloads passed after these repairs. The interrupted partial archive and temporary verification ledgers remain on D:; no recovery archives, checkpoints, or active R work were deleted. Original capacity limits remained unchanged. Sixteen dangling historical `.committing` links are retained as link metadata; they describe never-created interrupted outputs, not missing completed products.

## Limits and next target

No new scientific simulations or audits were executed for this archive operation; existing completed audit receipts were checked. A full extraction and runtime restoration rehearsal has not been performed. An isolated restore rehearsal is the next optional preservation test. This archive preserves the current complete reconstruction rather than every redundant historical archive.
