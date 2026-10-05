"""Restore original-run lineage; keep distinct from later R1 input identities."""
from pathlib import Path,PurePosixPath
import json,tarfile,hashlib,shutil,gzip,collections
root=Path(__file__).resolve().parents[1]
evidence=root/'recovered/driftmapR-S07-R1-Recovery-009/evidence/original'
deps=json.loads((root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924/references/historical-recovery009-dependencies/immutable-restore-dependencies.json').read_text())['archives']
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
records=[];members=[]
for i in range(22,26):
    rec=json.loads((evidence/f'archive-{i:03d}-restored.json').read_text())
    dep=next(x for x in deps if x['filename']==rec['archive']['filename']);assert dep==rec['archive']
    name=dep['filename'];source=Path('C:/Users/John/Downloads')/name
    assert source.stat().st_size==dep['bytes'] and sha(source)==dep['sha256']
    archive=root/'archives'/name
    if not archive.exists():shutil.copyfile(source,archive)
    assert sha(archive)==dep['sha256']
    expected={r['path']:r for r in rec['members']};seen=set()
    target=root/'recovered'/name.removesuffix('.tar.gz')
    with tarfile.open(archive,'r:gz') as t:
        for m in t:
            pp=PurePosixPath(m.name)
            assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in m.name
            if m.isdir():continue
            assert m.isfile(),m.name
            candidates=[k for k in expected if m.name==k or m.name.endswith('/'+k)]
            assert len(candidates)==1,(m.name,candidates)
            key=candidates[0];assert key not in seen;seen.add(key)
            data=t.extractfile(m).read();r=expected[key]
            assert len(data)==r['bytes'] and hashlib.md5(data).hexdigest()==r['md5'],m.name
            digest=hashlib.sha256(data).hexdigest()
            if r.get('sha256'):assert digest==r['sha256']
            dest=target.joinpath(*pp.parts);assert dest.resolve().is_relative_to(target.resolve())
            dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists():assert dest.read_bytes()==data
            else:dest.write_bytes(data)
            members.append({'path':dest.relative_to(root).as_posix(),'original_path':m.name,'receipt_path':key,'bytes':len(data),'sha256':digest,'md5':r['md5'],'archive':name})
    assert seen==set(expected)
    with gzip.open(archive,'rb') as f:
        while f.read(1<<20):pass
    records.append({**dep,'source':str(source),'files':len(seen),'membership_size_md5':'passed','gzip_crc':'passed','member_sha256':'freshly recorded; only compared historically when supplied'})
    print(f'{name}: {len(seen)} files verified',flush=True)
result={'status':'passed','archives':records,'members':members,'categories':dict(collections.Counter(m['receipt_path'].split('/')[0] for m in members)),'scientific_execution':False,'scope':'Original-run archives verified against immutable archive SHA256 and Recovery009 member size/MD5; fresh member SHA256 recorded. These are historical originals, not replacements for R1 files.'}
(root/'qa/original-022-025-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ('archives','members')},indent=2))






