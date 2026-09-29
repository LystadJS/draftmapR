"""Verify supplied transport parts, reconstruct and inspect a saved checkpoint.
Does not launch scientific code or merge snapshots into live state.
"""
from pathlib import Path,PurePosixPath
import argparse,json,hashlib,zipfile,stat,shutil
parser=argparse.ArgumentParser()
parser.add_argument('checkpoint',type=int)
parser.add_argument('input_dir',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
audit=root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924'
ids=json.loads((audit/'results/input-identities-and-dependencies.json').read_text())
group=next(x for x in ids['checkpoint_transport_groups'] if x['checkpoint']==args.checkpoint)
record=json.loads((audit/f'results/checkpoint{args.checkpoint}-archive-audit.json').read_text())
def digest(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
parts=[]
for r in sorted(group['parts'],key=lambda x:x['index']):
    p=args.input_dir/r['filename']
    assert p.stat().st_size==r['bytes'] and digest(p)==r['sha256'],p
    parts.append({'path':str(p),'filename':p.name,'bytes':r['bytes'],'sha256':r['sha256']})
out=root/'archives'/group['archive']
if not out.exists():
    with out.open('xb') as f:
        for p in parts:
            with Path(p['path']).open('rb') as src:shutil.copyfileobj(src,f)
assert out.stat().st_size==group['archive_bytes'] and digest(out)==group['archive_sha256']
assert group['archive_sha256']==record['archive_sha256']
expected={r['member']:r for r in record['members']}
target=root/'recovered'/out.stem
with zipfile.ZipFile(out) as z:
    names=z.namelist()
    assert len(names)==len(set(names)) and set(names)==set(expected)
    assert hashlib.sha256(z.read(record['manifest'])).hexdigest()==record['manifest_sha256']
    for info in z.infolist():
        pp=PurePosixPath(info.filename)
        assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in info.filename
        assert stat.S_IFMT(info.external_attr>>16) in (0,stat.S_IFREG)
        data=z.read(info) # Includes ZIP CRC verification.
        r=expected[info.filename]
        assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'],info.filename
        if r.get('md5'):assert hashlib.md5(data).hexdigest()==r['md5']
        p=target.joinpath(*pp.parts)
        assert p.resolve().is_relative_to(target.resolve())
        p.parent.mkdir(parents=True,exist_ok=True)
        if p.exists():assert p.read_bytes()==data
        else:p.write_bytes(data)
result={'checkpoint':args.checkpoint,'archive':out.name,'bytes':out.stat().st_size,'sha256':digest(out),'parts':parts,'member_count':len(expected),'membership_sizes_crc_sha256_md5':'passed','manifest_hash':'passed','scientific_execution':False,'scope':'This checkpoint delta only; ancestral snapshots and payloads still required.'}
(root/f'qa/checkpoint{args.checkpoint}-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:v for k,v in result.items() if k!='parts'},indent=2))
