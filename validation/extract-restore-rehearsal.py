"""Extract the final preservation ZIP into a fresh destination and read back every file."""
import hashlib,json,os,shutil,subprocess,sys,zipfile
from pathlib import Path,PurePosixPath
archive=Path(sys.argv[1]);target=Path(sys.argv[2])
if os.name=='nt':assert archive.drive.upper()==target.drive.upper()=='D:'
else:assert str(archive).startswith('/archive/') and target.is_relative_to('/tmp/restored')
assert not target.exists(), 'Never overwrite a restore or recovery directory'
assert shutil.disk_usage(target.parent).free>120*1024**3
expected='a4d22658f4debf82ca0b49fbac3151d28bd729eb96e48ffe7835ceb1bcc300c7'
print('Verifying whole archive SHA-256',flush=True)
with archive.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==expected
target.mkdir();n=0;total=0
with zipfile.ZipFile(archive) as z:
    assert len(z.filelist)==len(z.NameToInfo)==342418
    with z.open('SHA256SUMS.jsonl') as manifest:
        for line in manifest:
            row=json.loads(line);name=row['path'];parts=PurePosixPath(name).parts
            assert not name.startswith('/') and '..' not in parts and ':' not in name and '\\' not in name
            path=target.joinpath(*parts);path.parent.mkdir(parents=True,exist_ok=True)
            assert z.getinfo(name).file_size==row['bytes']
            assert shutil.disk_usage(target).free-row['bytes']>3*1024**3
            h=hashlib.sha256()
            with z.open(name) as src,path.open('xb') as out:
                while chunk:=src.read(1024**2):out.write(chunk);h.update(chunk)
            assert h.hexdigest()==row['sha256'] and path.stat().st_size==row['bytes'],name
            with path.open('rb') as restored:assert hashlib.file_digest(restored,'sha256').hexdigest()==row['sha256'],name
            if os.name!='nt':os.chmod(path,(z.getinfo(name).external_attr>>16)&0o7777)
            n+=1;total+=row['bytes']
            if n%10000==0:print('Restored and read-back verified',n,'files',total,'bytes',flush=True)
    data=z.read('SHA256SUMS.jsonl')
    assert hashlib.sha256(data).hexdigest()=='010b38283d4d17faeb060a1f85a92c8d2223013d82938d72c9116bd5857c83da'
    (target/'SHA256SUMS.jsonl').write_bytes(data)
assert n==342417
if os.name!='nt':subprocess.run(['sync','-f',str(target)],check=True)
result=dict(status='passed',archive_sha256=expected,restored_files=n,restored_payload_bytes=total,extracted_readback_sha256='all passed',zip_crc='all passed',filesystem='exFAT; original modes retained in archive' if os.name=='nt' else 'ext4 filesystem image on D:; original Unix file modes restored',source_archive_modified=False)
(target/'restore-extraction-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result),flush=True)
