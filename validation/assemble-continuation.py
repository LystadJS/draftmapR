"""Assemble an inactive hard-link base; mount it READ ONLY, write via overlay."""
from pathlib import Path, PurePosixPath
import json, os, argparse
p=argparse.ArgumentParser();p.add_argument('recovery',type=Path);p.add_argument('target',type=Path);a=p.parse_args()
r=a.recovery.resolve();target=a.target.resolve();target.mkdir(parents=True,exist_ok=True)
assert not (target/'assembly-complete.json').exists()
files={};prefix='/workspace/scratch/'
def add(dest,source,size,sha):
    q=PurePosixPath(dest);assert not q.is_absolute() and '..' not in q.parts
    assert q.parts[0] in ('837e4400dd1d','1e9a01af2c37')
    files[dest]={'source':source,'bytes':size,'sha256':sha}
for pattern in ('original-*-verification.json','r1-0?-verification.json','raw-*-verification.json'):
    for proof in sorted((r/'qa').glob(pattern)):
        d=json.loads(proof.read_text());assert d['status']=='passed'
        for m in d['members']:
            add('837e4400dd1d/'+m['original_path'],m['path'],m['bytes'],m['sha256'])
src=r/'recovered/driftmapR-S07-R1-sources'
inventory={x['path']:x for x in json.loads((r/'FILE_MANIFEST.json').read_text())['files']}
for folder in ('study07-specification','study07-execution','study07-recovery'):
    for f in (src/folder).rglob('*'):
        if f.is_file():
            rel=f.relative_to(r).as_posix();m=inventory[rel]
            add('837e4400dd1d/'+f.relative_to(src).as_posix(),rel,m['bytes'],m['sha256'])
live=json.loads((r/'qa/live002-verification.json').read_text())
for m in live['members']:
    rel=m['path'].split('/driftmapR-S07-R1-live-state-20260921-002/',1)[1]
    if rel.startswith('pinned-workspace/study07-results/'):
        add('837e4400dd1d/'+rel.removeprefix('pinned-workspace/'),m['path'],m['bytes'],m['sha256'])
    elif rel.startswith('current-workspace/final-preservation/'):
        add('1e9a01af2c37/'+rel.removeprefix('current-workspace/'),m['path'],m['bytes'],m['sha256'])
for n,s in [(464,'011'),(468,'012'),(2250,'013'),(3915,'014')]:
    folder=r/f'recovered/driftmapR-S07-R1-checkpoint{n}-{s}'
    for m in json.loads((folder/'SNAPSHOT-MANIFEST.json').read_text())['members']:
        assert m['source_path'].startswith(prefix)
        dest=m['source_path'].removeprefix(prefix)
        # The latest full state replaces prior state as a consistent snapshot.
        if '/resumable-collection-state/' in dest and n!=3915:continue
        add(dest,(folder/m['member']).relative_to(r).as_posix(),m['bytes'],m['sha256'])
rows=[]
for i,(dest,m) in enumerate(sorted(files.items()),1):
    source=r/m['source'];out=target/dest
    assert source.is_file() and source.stat().st_size==m['bytes'],str(source)
    out.parent.mkdir(parents=True,exist_ok=True)
    if out.exists():assert os.path.samefile(source,out),str(out)
    else:os.link(source,out)
    rows.append({'path':dest,**m})
    if i%25000==0:print('linked',i,flush=True)
receipt={'status':'inactive_read_only_base_assembled','files':len(rows),'logical_bytes':sum(x['bytes'] for x in rows),'scope':'Manifest identities from prior successful verification; current source size and hard-link identity checked. Full content verification remains in continuation gates. Never mount this base writable.','study_started':False,'members':rows}
(target/'assembly-complete.json').write_text(json.dumps(receipt,indent=2))
print('assembly complete',len(rows),flush=True)
