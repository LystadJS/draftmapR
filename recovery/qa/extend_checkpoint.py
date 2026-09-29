"""Extend a verified portable recovery bundle with a verified archive.

Retains prior immutable bytes, refreshes top-level reports/provenance/QA files,
and includes the new archive and every extracted member. Reads archived members
directly to avoid repeated small-file disk I/O. Rehashes all retained bytes and
verifies every final member. Does not run scientific code.
"""
from pathlib import Path
import argparse, hashlib, json, zipfile
p=argparse.ArgumentParser()
p.add_argument('previous');p.add_argument('checkpoint',type=int);p.add_argument('output')
a=p.parse_args()
root=Path(__file__).resolve().parents[1];base=root.parent;prefix=root.name+'/'
previous=base/a.previous;out=base/a.output
assert previous!=out and not out.exists(), 'Use a new output name.'
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
receipt=json.loads(previous.with_suffix('.verification.json').read_text(encoding='utf-8-sig'))
assert previous.stat().st_size==receipt['bytes'] and sha(previous)==receipt['sha256']
newproof=json.loads((root/f'qa/checkpoint{a.checkpoint}-verification.json').read_text())
archive=root/'archives'/newproof['archive']
assert archive.stat().st_size==newproof['bytes'] and sha(archive)==newproof['sha256']
refresh={x.relative_to(root).as_posix():x for folder in [root,root/'qa',root/'provenance'] for x in folder.iterdir() if x.is_file() and x.name!='FILE_MANIFEST.json'}
refresh.update({x.relative_to(root).as_posix():x for x in (root/'qa/full-chain-state').rglob('*') if x.is_file()})
refresh['archives/'+archive.name]=archive
rows={}
with zipfile.ZipFile(previous) as old,zipfile.ZipFile(archive) as incoming,zipfile.ZipFile(out,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
    prior=json.loads(old.read(prefix+'FILE_MANIFEST.json').decode('utf-8-sig'))
    expected={r['path']:r for r in prior['files']}
    assert len(old.namelist())==len(set(old.namelist()))==len(expected)+1
    def put(rel,data,info=None):
        assert rel not in rows,rel
        rows[rel]={'path':rel,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
        z.writestr(info or prefix+rel,data)
    for rel,row in expected.items():
        data=old.read(prefix+rel)
        assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],rel
        if rel in refresh:data=refresh.pop(rel).read_bytes()
        put(rel,data,old.getinfo(prefix+rel))
    print('Prior checkpoint members verified and retained; adding recovered snapshot.',flush=True)
    for rel,path in refresh.items():put(rel,path.read_bytes())
    for info in incoming.infolist():
        put('recovered/'+archive.stem+'/'+info.filename,incoming.read(info))
    manifest={'scope':'Verified previous portable checkpoint plus new archive and every member; refreshed root reports and top-level QA/provenance files. Excludes .git, machine-local QA R-library and Python caches as in previous bundle.','files':[rows[k] for k in sorted(rows)]}
    data=json.dumps(manifest,indent=2).encode()
    z.writestr(prefix+'FILE_MANIFEST.json',data)
    (root/'FILE_MANIFEST.json').write_bytes(data)
print('Archive written; verifying every final member.',flush=True)
with zipfile.ZipFile(out) as z:
    assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
    assert json.loads(z.read(prefix+'FILE_MANIFEST.json'))==manifest
    for r in manifest['files']:
        data=z.read(prefix+r['path'])
        assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'],r['path']
summary={'archive':out.name,'bytes':out.stat().st_size,'sha256':sha(out),'verified_files':len(rows),'zip_crc':'passed on every member read','all_member_hashes':'passed','previous_archive':previous.name,'added_checkpoint':a.checkpoint,'scientific_execution':False,'note':'Partial recovery only; see README and MISSING_ARTIFACTS.'}
out.with_suffix('.verification.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2),flush=True)
