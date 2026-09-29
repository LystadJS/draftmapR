from pathlib import Path
import json, hashlib
root=Path(__file__).resolve().parents[1]
base=root/'recovered/driftmapR-S07-D1-specification'
def digest(p, algo='sha256'):
    with p.open('rb') as f: return hashlib.file_digest(f,algo).hexdigest()
def verify(base,rows):
    bad=[]
    for r in rows:
        p=base/r['path']
        if not p.is_file() or p.stat().st_size!=r['size_bytes'] or digest(p)!=r['sha256']: bad.append(r['path'])
    return bad
manifest=json.loads((base/'ARCHIVE-MANIFEST.json').read_text())
frozen=base/'study07-specification'
freeze=json.loads((frozen/'FREEZE.json').read_text())
actual={p.relative_to(frozen).as_posix() for p in frozen.rglob('*') if p.is_file() and p.name!='FREEZE.json'}
expected={r['path'] for r in freeze['files']}
result={'archive_members':len(manifest['files']),'archive_mismatches':verify(base,manifest['files']),
        'freeze_members':len(freeze['files']),'freeze_mismatches':verify(frozen,freeze['files']),
        'missing':sorted(expected-actual),'extra':sorted(actual-expected),
        'original_verifier_note':'Original freeze.py compares ordered inventories; Windows Path sorting is case-insensitive. This independent check compares path membership and every size/SHA256 without depending on sort order.'}
(root/'qa/independent-integrity.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
assert not any(result[k] for k in ['archive_mismatches','freeze_mismatches','missing','extra'])
