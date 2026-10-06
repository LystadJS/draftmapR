"""Preserve compressed members from a verified ZIP and add verified inputs.

Copies complete local ZIP records without recompressing unchanged payloads,
then writes a new central directory and manifest. Every final member is read
and hash-checked. Only metadata/checkpoint recovery; no scientific execution.
"""
from pathlib import Path
import argparse,copy,hashlib,json,zipfile,shutil
p=argparse.ArgumentParser();p.add_argument('previous');p.add_argument('proof');p.add_argument('output');a=p.parse_args()
root=Path(__file__).resolve().parents[1];prefix=root.name+'/'
previous=root.parent/a.previous;out=root.parent/a.output
assert not out.exists() and previous!=out
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
receipt=json.loads(previous.with_suffix('.verification.json').read_text(encoding='utf-8-sig'))
assert sha(previous)==receipt['sha256'] and previous.stat().st_size==receipt['bytes']
proof=json.loads((root/a.proof).read_text());assert proof['status']=='passed'
refresh={x.relative_to(root).as_posix():x for folder in [root,root/'qa',root/'provenance'] for x in folder.iterdir() if x.is_file() and x.name!='FILE_MANIFEST.json'}
for r in proof['archives']:
    path=root/'archives'/r['filename'];assert path.stat().st_size==r['bytes'] and sha(path)==r['sha256']
    refresh[path.relative_to(root).as_posix()]=path
for r in proof['members']:
    path=root/r['path'];assert path.stat().st_size==r['bytes'] and sha(path)==r['sha256']
    refresh[r['path']]=path
required=previous.stat().st_size+sum(p.stat().st_size for p in refresh.values())+1024**3
assert shutil.disk_usage(out.parent).free>=required, f'Insufficient free disk space: need conservative {required:,} bytes before creating cumulative ZIP'
rows={}
with zipfile.ZipFile(previous) as old,previous.open('rb') as source,zipfile.ZipFile(out,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
    prior=json.loads(old.read(prefix+'FILE_MANIFEST.json').decode('utf-8-sig'))
    expected={r['path']:r for r in prior['files']}
    infos=sorted(old.infolist(),key=lambda i:i.header_offset)
    assert len(infos)==len(set(old.namelist()))==len(expected)+1
    for i,info in enumerate(infos):
        rel=info.filename.removeprefix(prefix)
        if rel in refresh or rel=='FILE_MANIFEST.json':continue
        assert rel in expected and info.file_size==expected[rel]['bytes']
        end=infos[i+1].header_offset if i+1<len(infos) else old.start_dir
        size=end-info.header_offset;assert size>0
        destinfo=copy.copy(info);destinfo.header_offset=z.fp.tell()
        source.seek(info.header_offset)
        while size:
            data=source.read(min(size,1<<20));assert data
            z.fp.write(data);size-=len(data)
        z.filelist.append(destinfo);z.NameToInfo[info.filename]=destinfo
        z.start_dir=z.fp.tell();z._didModify=True
        rows[rel]=expected[rel]
    print('Existing compressed members preserved; adding updated reports and recovered inputs.',flush=True)
    for rel,path in refresh.items():
        data=path.read_bytes();rows[rel]={'path':rel,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
        z.writestr(prefix+rel,data,compress_type=zipfile.ZIP_STORED if rel.endswith(('.tar.gz','.zip')) else zipfile.ZIP_DEFLATED)
    manifest={'scope':'Verified prior portable checkpoint with updated top-level reports, QA and provenance; added ancestral archives and all verified extracted files. Prior exclusions (.git, machine-local QA R-library, Python caches) retained.','files':[rows[k] for k in sorted(rows)]}
    data=json.dumps(manifest,indent=2).encode();z.writestr(prefix+'FILE_MANIFEST.json',data)
    (root/'FILE_MANIFEST.json').write_bytes(data)
print('Archive written; checking every active member and the final manifest.',flush=True)
with zipfile.ZipFile(out) as z:
    assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
    assert json.loads(z.read(prefix+'FILE_MANIFEST.json'))==manifest
    for r in manifest['files']:
        data=z.read(prefix+r['path'])
        assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256'],r['path']
summary={'archive':out.name,'bytes':out.stat().st_size,'sha256':sha(out),'verified_files':len(rows),'zip_crc':'passed on every member read','all_member_hashes':'passed','previous_archive':previous.name,'added_archives':[r['filename'] for r in proof['archives']],'scientific_execution':False,'note':'Partial recovery; see README and missing-archive checklist.'}
out.with_suffix('.verification.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2),flush=True)
