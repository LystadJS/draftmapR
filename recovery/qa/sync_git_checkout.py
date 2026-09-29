"""Prepare the separate Git checkout; preserve original recovery files."""
from pathlib import Path
import shutil,hashlib,json
root=Path(__file__).resolve().parents[1];repo=root.parent/'driftmapR-git'
assert (repo/'.git').is_dir()
src=root/'driftmapR';dest=repo/'driftmapR'
original={p.relative_to(src).as_posix():p for p in src.rglob('*') if p.is_file()}
assert len(original)==188
removed=[]
for p in dest.rglob('*'):
    if p.is_file() and p.relative_to(dest).as_posix() not in original:
        assert p.resolve().is_relative_to(repo.resolve())
        removed.append(p.relative_to(repo).as_posix());p.unlink()
for rel,p in original.items():
    q=dest/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
    assert p.read_bytes()==q.read_bytes()
target=repo/'recovery'
def cp(p,rel):
    q=target/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
for name in ['README.md','MISSING_ARTIFACTS.md','GIT_WORKFLOW.md']:cp(root/name,name)
for p in (root/'provenance').iterdir():
    if p.is_file():cp(p,'provenance/'+p.name)
for p in (root/'qa').rglob('*'):
    if not p.is_file():continue
    rel=p.relative_to(root/'qa')
    if 'R-library' in rel.parts or '__pycache__' in rel.parts or p.suffix.lower()=='.rds':continue
    cp(p,'qa/'+rel.as_posix())
compact=['driftmapR-S07-D1-specification.zip','driftmapR-S07-R1-sources.zip','driftmapR-S07-R1-Recovery-Audit-20260924.zip','driftmapR-S07-R1-Recovery-009.zip']
for name in compact:cp(root/'archives'/name,'source-archives/'+name)
(repo/'.gitattributes').write_text('* -text\n')
(repo/'.gitignore').write_text('/recovery/archives/\n/recovery/recovered/\n/recovery/qa/R-library/\n/recovery/qa/*.rds\n/recovery/provenance/conversations/\n**/__pycache__/\n.Rhistory\n.RData\n')
(repo/'README.md').write_text('''# driftmapR

Recovered development package **0.0.8.9000**, with source provenance and partial scientific-checkpoint recovery.

The package is in [`driftmapR/`](driftmapR/). It is byte-identical to the 188-file package vendored in the verified S07 source archives. It includes alignment, movement measurement, supplied-label correspondence, PCA/classical-MDS adapters, and serial paired-measurement-unit bootstrap refits. Inferential coverage has not been established.

Prior native Windows R 4.5.3 package verification recorded 2,619 passing expectations in 147 test blocks, with zero test failures/errors/warnings/skips. Those tests were executed during initial recovery, not rerun for every archive batch. There is no fresh full R CMD check or completed scientific simulation claim.

Recovery status and exact missing files: [`recovery/README.md`](recovery/README.md), [`recovery/MISSING_ARTIFACTS.md`](recovery/MISSING_ARTIFACTS.md). All four checkpoint deltas and all R1 input archives are recovered. Saved execution remains 3,915 committed panels plus one partial panel out of 6,480 planned. Earlier original/raw archives remain missing.

This repository versions package code, recovery scripts, evidence, exact source identities, and four compact source/audit archives. Large scientific/runtime archives and extracted data remain in the local consolidated checkpoint. GitHub does **not** contain those large binary payloads; the source identities and missing/recovered indexes identify them. Conversation exports are not published here.

The existing `documentation/` and `validation/` directories are historical artifacts from the earlier 0.0.3.9000 repository. They are retained for provenance and do not establish current package validation. The original Git history is preserved.

See [`recovery/GIT_WORKFLOW.md`](recovery/GIT_WORKFLOW.md) for the continuing commit/push procedure.
''')
proof={'package_files':len(original),'package_bytes_identical':True,'prior_package_paths_removed':removed,'large_payloads_in_git':False,'compact_source_archives':compact}
(root/'qa/git-package-copy-proof.json').write_text(json.dumps(proof,indent=2))
cp(root/'qa/git-package-copy-proof.json','qa/git-package-copy-proof.json')
print(json.dumps(proof,indent=2))
