"""Recover the intact ZIP prefix; independently verify all payloads against sources."""
import gc, hashlib, io, json, os, shutil, sqlite3, subprocess, sys, tarfile, zipfile
from pathlib import Path
base=Path(__file__).resolve().parents[2]; repo=base/'driftmapR-git'
dest=Path(sys.argv[1]); container='driftmapr-collection-20261023'
original=dest/'driftmapR-final-preservation-20261026.partial.zip'
partial=dest/'driftmapR-final-preservation-20261026.resumed.partial.zip'
final=dest/'driftmapR-final-preservation-20261026.zip'
assert not final.exists()
assert shutil.disk_usage(dest).free>60*1024**3
git=['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo)]
revision=subprocess.check_output(git+['rev-parse','HEAD'],text=True).strip()
assert not subprocess.check_output(git+['status','--porcelain'],text=True).strip()
with zipfile.ZipFile(original) as old: infos=old.infolist()
assert infos[-1].filename=='scratch/837e4400dd1d/study07-results/S07-R1/tables/full/geometry-registration.csv.gz'
cut=infos.pop().header_offset
if partial.exists():
    with zipfile.ZipFile(partial) as existing:
        assert [i.filename for i in existing.filelist]==[i.filename for i in infos], 'Only retry an unchanged copied prefix'
        assert existing.start_dir==cut
    print('Reusing intact copied prefix',cut,flush=True)
else:
    print('Copying intact prefix',cut,'bytes;',len(infos),'members',flush=True)
    with original.open('rb') as src,partial.open('xb') as out:
        remaining=cut
        while remaining:
            chunk=src.read(min(8*1024**2,remaining));assert chunk
            out.write(chunk);remaining-=len(chunk)
skip=dest/'resume-skip.json';skip.write_text(json.dumps([i.filename for i in infos]))
def add(z,name,stream,size,mode=0o644):
    assert name not in z.NameToInfo and '..' not in Path(name).parts
    assert shutil.disk_usage(dest).free-size>3*1024**3
    info=zipfile.ZipInfo(name);info.create_system=3;info.external_attr=(0o100000|mode)<<16
    count=0
    with z.open(info,'w',force_zip64=True) as out:
        while chunk:=stream.read(1024**2):out.write(chunk);count+=len(chunk)
    assert count==size,name
with partial.open('r+b') as target:
    target.seek(cut)
    with zipfile.ZipFile(target,'w',allowZip64=True) as z:
        z.filelist=infos;z.NameToInfo={i.filename:i for i in infos};z.start_dir=cut;z._didModify=True
        with skip.open('rb') as inp,(dest/'resume-export-stderr.log').open('wb') as err:
            p=subprocess.Popen(['docker','exec','-i',container,'python3','/validation/export-preservation-stream.py','--skip-stdin'],stdin=inp,stdout=subprocess.PIPE,stderr=err)
            try:
                with tarfile.open(fileobj=p.stdout,mode='r|') as incoming:
                    for member in incoming:
                        assert member.isfile()
                        add(z,member.name,incoming.extractfile(member),member.size,member.mode)
                        incoming.members.clear()
                assert p.wait()==0
            finally:
                if p.poll() is None:p.terminate();p.wait()
        for root in [base/'driftmapR-recovery/provenance',base/'runtime-reconstruction']:
            for path in sorted(root.rglob('*')):
                if path.is_file():
                    before=path.stat()
                    with path.open('rb') as f:add(z,'host/'+path.relative_to(base).as_posix(),f,before.st_size)
                    assert path.stat().st_mtime_ns==before.st_mtime_ns
        subprocess.run(git+['bundle','create',str(dest/'recovery-tooling.bundle'),'--all'],check=True)
        subprocess.run(git+['bundle','verify',str(dest/'recovery-tooling.bundle')],check=True)
        path=dest/'recovery-tooling.bundle'
        with path.open('rb') as f:add(z,'preservation/'+path.name,f,path.stat().st_size)
        restore=('Completed reconstructed study preservation. Private operational records included: do not publish blindly.\n'
          'Verify SHA256SUMS.jsonl for every payload. Extract on Linux with adequate capacity.\n'
          'Import preservation/runtime-container.tar with docker import; mounted study data is separately in scratch/.\n'
          'Restore scratch/ to /workspace/scratch. Keep original 12 GiB memory, 2 CPU limits and read-only scientific mounts.\n'
          'File symlinks are materialized; source-links.json retains original metadata. Sixteen dangling historical committing links are metadata only.\n'
          'Clone recovery-tooling.bundle for latest repository history; repository.bundle and repository.tar preserve pre-repair revision 7cf606b.\n'
          'Do not restart stale process records or restore absolute operational symlinks blindly. Revalidate before future execution.\n'
          'This preserves the current reconstruction, not every redundant historical archive.\n').encode()
        add(z,'preservation/RESTORE.txt',io.BytesIO(restore),len(restore))
    target.flush();os.fsync(target.fileno())
del infos,z;gc.collect()
db=sqlite3.connect(dest/'verification.sqlite');db.execute('CREATE TABLE files(path TEXT PRIMARY KEY, bytes INTEGER, sha256 TEXT, checked INTEGER DEFAULT 0)')
print('Reading every archived payload for SHA-256 and CRC',flush=True)
with zipfile.ZipFile(partial) as z:
    assert len(z.filelist)==len(z.NameToInfo)
    for n,info in enumerate(z.filelist,1):
        with z.open(info) as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
        db.execute('INSERT INTO files(path,bytes,sha256) VALUES(?,?,?)',(info.filename,info.file_size,digest))
        if n%10000==0:db.commit();print('Archive read verified',n,flush=True)
db.commit();del z;gc.collect()
print('Independently comparing source hashes',flush=True)
with (dest/'source-hash-stderr.log').open('wb') as err:
    p=subprocess.Popen(['docker','exec',container,'python3','/validation/hash-preservation-sources.py'],stdout=subprocess.PIPE,stderr=err,text=True)
    for n,line in enumerate(p.stdout,1):
        row=json.loads(line);found=db.execute('SELECT bytes,sha256 FROM files WHERE path=?',(row['path'],)).fetchone()
        assert found==(row['bytes'],row['sha256']),row['path']
        db.execute('UPDATE files SET checked=1 WHERE path=?',(row['path'],))
        if n%10000==0:db.commit();print('Source matched',n,flush=True)
    assert p.wait()==0
for name,size,digest in db.execute('SELECT path,bytes,sha256 FROM files WHERE checked=0').fetchall():
    if name.startswith('host/'):path=base/name[5:]
    elif name in ['preservation/'+n for n in ['repository.bundle','repository.tar','runtime-container.tar','recovery-tooling.bundle']]:path=dest/Path(name).name
    elif name=='preservation/RESTORE.txt':
        assert digest==hashlib.sha256(restore).hexdigest();path=None
    elif name=='preservation/source-links.json':
        with zipfile.ZipFile(partial) as z:links=json.loads(z.read(name))
        assert sum(x.get('dereferenced') is False for x in links)==16;path=None
    else:raise AssertionError('Unmatched source '+name)
    if path:
        assert path.stat().st_size==size
        with path.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==digest,name
    db.execute('UPDATE files SET checked=1 WHERE path=?',(name,))
db.commit();assert db.execute('SELECT count(*) FROM files WHERE checked=0').fetchone()[0]==0
prefix='scratch/837e4400dd1d/study07-results/S07-R1/'
for name,expected in [('execution-complete.json','8aa965e96c411dea3fc1253362c1f7bebc45c32888861a32538140cdf68086bd'),('final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043')]:
    assert db.execute('SELECT sha256 FROM files WHERE path=?',(prefix+name,)).fetchone()[0]==expected
manifest=dest/'SHA256SUMS.jsonl'
with manifest.open('w',encoding='utf-8',newline='\n') as f:
    for name,size,digest in db.execute('SELECT path,bytes,sha256 FROM files ORDER BY path'):f.write(json.dumps(dict(path=name,bytes=size,sha256=digest))+'\n')
with zipfile.ZipFile(partial,'a',allowZip64=True) as z:z.write(manifest,'SHA256SUMS.jsonl')
with manifest.open('rb') as f:mh=hashlib.file_digest(f,'sha256').hexdigest()
with zipfile.ZipFile(partial) as z:
    with z.open('SHA256SUMS.jsonl') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==mh
    assert len(z.filelist)==db.execute('SELECT count(*) FROM files').fetchone()[0]+1
print('Computing final archive hash',flush=True)
with partial.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
partial.rename(final)
result=dict(status='verified',archive=final.name,bytes=final.stat().st_size,sha256=digest,verified_files=db.execute('SELECT count(*) FROM files').fetchone()[0],all_member_sha256='matched independent sources',zip_crc='passed complete reads',completion_receipt='matched verified original',repository_revision=revision,manifest_sha256=mh)
(dest/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result),flush=True)
