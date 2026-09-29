# Recovery version control

User instruction: after each completed recovery step, commit and push the current state to the confirmed driftmapR GitHub repository. This is continuing authorization; do not repeatedly request routine approval.

Use the separate `../driftmapR-git` checkout. Keep the recovered original `repository/` snapshot and `sources/` untouched. Before a push, check the remote branch and preserve newer remote work; never force-push recovery history.

Version the byte-preserved current package, recovery README and missing-file checklist, source records, verification scripts/results, and compact source/audit archives. Keep conversation exports private to the recovery workspace. Large scientific/runtime archives and extracted data remain in the local consolidated bundle; commit their exact identities and verification records, not a claim that GitHub contains their bytes. A Git push is therefore not a backup of all large binaries.

Confirmed destination: **https://github.com/LystadJS/draftmapR**, public, branch `main`. The user explicitly confirmed this destination. Commit and push there after each completed recovery step without asking again.

Verify the resulting remote commit after pushing. Record commit IDs and push status locally in `qa/git-sync-status.json`; this local receipt is excluded from Git to avoid recursive commit-ID updates. Do not claim successful upload until verified.
