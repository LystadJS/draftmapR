"""Build a portable recovery checkpoint and verify every archived file."""
from pathlib import Path
import hashlib, json, zipfile, csv
root=Path(__file__).resolve().parents[1]
def sha(p):
    with p.open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
vendor=root/'recovered/driftmapR-S07-D1-specification/study07-specification/vendor/study06-specification/vendor/driftmapR'
package=root/'driftmapR'
comparison=[]
for p in sorted(vendor.rglob('*')):
    if p.is_file():
        q=package/p.relative_to(vendor)
        comparison.append({'path':p.relative_to(vendor).as_posix(),'identical':q.is_file() and sha(p)==sha(q)})
assert all(x['identical'] for x in comparison)
(root/'qa/package-copy-proof.json').write_text(json.dumps(comparison,indent=2))
runtime=next(x for x in json.loads((root/'qa/archive-inspection.json').read_text()) if x['file']=='driftmapR-study06-pinned-runtime.tar.gz')
receipt=json.loads((root/'recovered/driftmapR-S07-D1-specification/study07-specification/vendor/study06-execution/evidence/runtime-archive.json').read_text())
assert runtime['sha256']==receipt['sha256'] and runtime['bytes']==receipt['bytes']
(root/'qa/runtime-receipt-proof.json').write_text(json.dumps({'bytes':runtime['bytes'],'sha256':runtime['sha256'],'matches_historical_receipt':True,'runtime_executed':False},indent=2))
def included(p):
    rel=p.relative_to(root)
    return p.is_file() and '.git' not in rel.parts and 'R-library' not in rel.parts and '__pycache__' not in rel.parts and rel.as_posix()!='FILE_MANIFEST.json'
files=sorted(p for p in root.rglob('*') if included(p))
manifest=[{'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in files]
(root/'FILE_MANIFEST.json').write_text(json.dumps({'scope':'All checkpoint files except this manifest, .git (history preserved in bundle), generated Python caches, and machine-local QA R-library','files':manifest},indent=2))
out=root.parent/'driftmapR-recovery-20260928-chain2250-3915.zip'
with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
    for p in files+[root/'FILE_MANIFEST.json']: z.write(p,'driftmapR-recovery/'+p.relative_to(root).as_posix())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    for r in manifest:
        data=z.read('driftmapR-recovery/'+r['path'])
        assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256']
summary={'archive':out.name,'bytes':out.stat().st_size,'sha256':sha(out),'verified_files':len(manifest),'zip_crc':'passed','all_member_hashes':'passed','package_copy_files':len(comparison),'note':'Does not include outstanding Library scientific payloads; see README and MISSING_ARTIFACTS.'}
out.with_suffix('.verification.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
