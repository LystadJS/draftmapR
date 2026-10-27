"""Verify persisted ext4 data; optionally repair only rehearsal copies from the archive."""
import hashlib,json,os,subprocess,sys,zipfile
from pathlib import Path
root=Path('/tmp/restored/rehearsal');support=Path('/rehearsal-output');repair='--repair' in sys.argv
if not repair:assert os.statvfs(root).f_flag & os.ST_RDONLY
n=0;fixed=[]
with zipfile.ZipFile('/archive/driftmapR-final-preservation-20261026.zip') as z:
    with z.open('SHA256SUMS.jsonl') as manifest:
        for line in manifest:
            row=json.loads(line);path=root/row['path'];valid=False
            try:
                if path.stat().st_size==row['bytes']:
                    with path.open('rb') as f:valid=hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
            except OSError:pass
            if not valid:
                assert repair,'Persisted payload mismatch: '+row['path']
                temp=path.with_name(path.name+'.rehearsal-repair');path.parent.mkdir(parents=True,exist_ok=True)
                h=hashlib.sha256()
                with z.open(row['path']) as src,temp.open('wb') as out:
                    while chunk:=src.read(1024**2):out.write(chunk);h.update(chunk)
                    out.flush();os.fsync(out.fileno())
                assert h.hexdigest()==row['sha256'] and temp.stat().st_size==row['bytes']
                os.chmod(temp,(z.getinfo(row['path']).external_attr>>16)&0o7777);os.replace(temp,path)
                fixed.append(row['path'])
            n+=1
            if n%10000==0:print('Persisted files checked',n,'repaired',len(fixed),flush=True)
    with (root/'SHA256SUMS.jsonl').open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()=='010b38283d4d17faeb060a1f85a92c8d2223013d82938d72c9116bd5857c83da'
assert n==342417
if repair:subprocess.run(['sync','-f',str(root)],check=True)
result=dict(status='repair-pass-complete; requires unmount and read-only verification' if repair else 'passed',files=n,repaired_files=len(fixed),readonly_filesystem=not repair,all_sha256_matched=True)
(support/('restore-repair.json' if repair else 'persisted-restore-verification.json')).write_text(json.dumps(result,indent=2))
if repair:(support/'restore-repaired-paths.json').write_text(json.dumps(fixed,indent=2))
print(json.dumps(result),flush=True)
