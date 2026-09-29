from pathlib import Path,PurePosixPath
import json,tarfile,hashlib,shutil,gzip
root=Path(__file__).resolve().parents[1]
evidence=root/'recovered/driftmapR-S07-R1-Recovery-009/evidence/r1'
dependencies=json.loads((root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924/references/historical-recovery009-dependencies/immutable-restore-dependencies.json').read_text())['archives']
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
records=[];members=[]
for i in range(1,4):
    name=f'driftmapR-S07-R1-checkpoint-03-checkpoints-part-{i:03d}.tar.gz'
    rec=json.loads((evidence/(name+'.restored.json')).read_text())
    dep=next(x for x in dependencies if x['filename']==name)
    assert dep==rec['archive']
    source=Path('C:/Users/John/Downloads')/name
    assert source.stat().st_size==dep['bytes'] and sha(source)==dep['sha256']
    archive=root/'archives'/name
    if not archive.exists():shutil.copyfile(source,archive)
    assert sha(archive)==dep['sha256']
    expected={r['path']:r for r in rec['members']}
    target=root/'recovered'/name.removesuffix('.tar.gz');seen=set()
    with tarfile.open(archive,'r:gz') as t:
        for m in t:
            pp=PurePosixPath(m.name)
            assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in m.name
            if m.isdir():continue
            receipt_path=m.name.removeprefix('study07-results/S07-R1/')
            assert m.isfile() and receipt_path in expected and receipt_path not in seen,m.name
            seen.add(receipt_path);data=t.extractfile(m).read();r=expected[receipt_path]
            assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'] and hashlib.md5(data).hexdigest()==r['md5'],m.name
            dest=target.joinpath(*pp.parts);assert dest.resolve().is_relative_to(target.resolve())
            dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists():assert dest.read_bytes()==data
            else:dest.write_bytes(data)
            members.append({'path':dest.relative_to(root).as_posix(),'bytes':len(data),'sha256':r['sha256'],'md5':r['md5'],'original_path':m.name,'archive':name})
    assert seen==set(expected)
    with gzip.open(archive,'rb') as g:
        while g.read(1<<20):pass
    records.append({**dep,'source':str(source),'files':len(seen),'membership_size_sha256_md5':'passed','gzip_crc':'passed'})
    print(name+': '+str(len(seen))+' files verified',flush=True)
ledger=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state/compact-cache-005.jsonl'
caches={r['key']:r for r in map(json.loads,ledger.read_text().splitlines())}
bound=[];not_cached=[]
for r in members:
    p=PurePosixPath(r['original_path'])
    if p.parent.name=='checkpoints' and p.name.endswith('.rds') and not p.name.endswith('.manifest.rds'):
        key=p.stem
        if key in caches:
            assert r['md5']==caches[key]['checkpoint_md5'],key
            bound.append(key)
        else:not_cached.append(key)
assert len(bound)==len(set(bound))
result={'status':'passed','archives':records,'members':members,'checkpoint_objects_bound_to_latest_cache_ledger':len(bound),'checkpoint_keys':bound+not_cached,'checkpoint_keys_without_compact_cache':not_cached,'scientific_execution':False,'scope':'Three R1-03 original archives and member identities verified against Recovery009 receipts; applicable checkpoint MD5s bound to latest cache ledger. Uncached checkpoints require input-receipt binding, not an assertion of completed collection. No simulation or checkpoint code executed.'}
(root/'qa/r1-03-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'status':'passed','archives':len(records),'files':len(members),'checkpoint_objects_bound':len(bound)},indent=2))


