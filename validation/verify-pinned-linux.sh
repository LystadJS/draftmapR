#!/bin/sh
# Validation only; never generate or resume reserved study panels.
set -eu
root=/workspace/scratch/837e4400dd1d
: "${S07_SOURCE_ROOT:?Set S07_SOURCE_ROOT to a read-only copy of recovered driftmapR-S07-R1-sources}"
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
test -x "$root/r-runtime/bin/Rscript-local"
export PYTHONDONTWRITEBYTECODE=1
python3 "$S07_SOURCE_ROOT/study07-specification/scripts/freeze.py" verify
"$root/r-runtime/bin/Rscript-local" "$S07_SOURCE_ROOT/study07-execution/scripts/verify.R"
python3 "$S07_SOURCE_ROOT/study07-execution/scripts/manifest.py" verify "$S07_SOURCE_ROOT/study07-execution"
printf '%s\n' 'Frozen implementation validation passed. Study was not resumed.'
