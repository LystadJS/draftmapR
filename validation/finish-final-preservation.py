"""Recheck the completed ZIP and compare its payloads using native base-file access."""
import gc,hashlib,json,os,sqlite3,subprocess,sys,zipfile
from pathlib import Path
base=Path(__file__).resolve().parents[2];repo=base/'driftmapR-git';dest=Path(sys.argv[1])
partial=dest/'driftmapR-final-preservation-20261026.resumed.partial.zip';final=dest/'driftmapR-final-preservation-20261026.zip'
assert not final.exists()
git=['git','-c','safe.directory='+repo.as_posix(),'-C',str(repo)]
revision=subprocess.check_output(git+['rev-parse','HEAD'],text=True).strip()
assert not subprocess.check_output(git+['status','--porcelain'],text=True).strip()
bundle=dest/('final-verification-tooling-'+revision[:7]+'.bundle')
subprocess.run(git+['bundle','create',str(bundle),'--all'],check=True)
subprocess.run(git+['bundle','verify',str(bundle)],check=True)
with zipfile.ZipFile(partial,'a',allowZip64=True) as z:
    assert 'preservation/'+bundle.name not in z.NameToInfo
    z.write(bundle,'preservation/'+bundle.name)
    z.writestr('preservation/VERIFICATION-NOTE-'+revision[:7]+'.txt','The latest repository history is '+bundle.name+', revision '+revision+'. Other bundles retain earlier preservation stages. All payloads are checked in SHA256SUMS.jsonl.\n')
del z;gc.collect()
db=sqlite3.connect(dest/('final-verification-'+revision[:7]+'.sqlite'))
db.execute('CREATE TABLE files(path TEXT PRIMARY KEY, bytes INTEGER, sha256 TEXT, checked INTEGER DEFAULT 0)')
print('Rechecking archive CRC and SHA-256',flush=True)
with zipfile.ZipFile(partial) as z:
    assert len(z.filelist)==len(z.NameToInfo)
    for n,info in enumerate(z.filelist,1):
        with z.open(info) as f:h=hashlib.file_digest(f,'sha256').hexdigest()
        db.execute('INSERT INTO files(path,bytes,sha256) VALUES(?,?,?)',(info.filename,info.file_size,h))
        if n%50000==0:db.commit();print('Archive checked',n,flush=True)
db.commit();del z;gc.collect()
container='driftmapr-collection-20261023'
running=subprocess.check_output(['docker','inspect','--format','{{.State.Running}}',container],text=True).strip()
if running!='true':
    subprocess.run(['docker','start',container],check=True)
    subprocess.run(['docker','exec',container,'sh','/validation/mount-continuation.sh'],check=True)
print('Matching independent sources through native base access',flush=True)
with (dest/'hybrid-hash-stderr.log').open('wb') as err:
    p=subprocess.Popen(['docker','exec','driftmapr-collection-20261023','python3','/validation/hash-preservation-hybrid.py'],stdout=subprocess.PIPE,stderr=err,text=True)
    try:
        for n,line in enumerate(p.stdout,1):
            row=json.loads(line)
            if 'base' in row:
                path=base/'continuation-base-20261021'/row['base'];before=path.stat()
                with path.open('rb') as f:row['sha256']=hashlib.file_digest(f,'sha256').hexdigest()
                after=path.stat();assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns)
                row['bytes']=before.st_size
            found=db.execute('SELECT bytes,sha256,checked FROM files WHERE path=?',(row['path'],)).fetchone()
            assert found==(row['bytes'],row['sha256'],0),row['path']
            db.execute('UPDATE files SET checked=1 WHERE path=?',(row['path'],))
            if n%10000==0:db.commit();print('Source matched',n,flush=True)
        assert p.wait()==0
    finally:
        if p.poll() is None:p.terminate();p.wait()
for name,size,digest in db.execute('SELECT path,bytes,sha256 FROM files WHERE checked=0').fetchall():
    if name.startswith('host/'):path=base/name[5:]
    elif name.startswith('preservation/') and (name.endswith('.bundle') or Path(name).name in ['repository.tar','runtime-container.tar']):path=dest/Path(name).name
    elif name in ['preservation/RESTORE.txt','preservation/source-links.json'] or name.startswith('preservation/VERIFICATION-NOTE'):path=None
    else:raise AssertionError('Source absent from visible inventory: '+name)
    if path:
        assert path.stat().st_size==size
        with path.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==digest,name
    db.execute('UPDATE files SET checked=1 WHERE path=?',(name,))
db.commit()
with zipfile.ZipFile(partial) as z:
    links=json.loads(z.read('preservation/source-links.json'))
    assert sum(x.get('dereferenced') is False for x in links)==16
    prefix='scratch/837e4400dd1d/study07-results/S07-R1/'
    for name,expected in [('execution-complete.json','8aa965e96c411dea3fc1253362c1f7bebc45c32888861a32538140cdf68086bd'),('final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043')]:
        assert hashlib.sha256(z.read(prefix+name)).hexdigest()==expected
    audit=json.loads(z.read(prefix+'final-audit.json'));receipt=json.loads(z.read(prefix+'execution-complete.json'))
    assert audit['status']=='passed' and receipt['independent_audit_passed'] is True
    assert audit['panels']==receipt['panels']==6480 and audit['planned_draws']==receipt['draws']==1313520
manifest=dest/'SHA256SUMS.jsonl'
with manifest.open('w',encoding='utf-8',newline='\n') as f:
    for name,size,h in db.execute('SELECT path,bytes,sha256 FROM files ORDER BY path'):f.write(json.dumps(dict(path=name,bytes=size,sha256=h))+'\n')
with zipfile.ZipFile(partial,'a',allowZip64=True) as z:z.write(manifest,'SHA256SUMS.jsonl')
with manifest.open('rb') as f:mh=hashlib.file_digest(f,'sha256').hexdigest()
count=db.execute('SELECT count(*) FROM files').fetchone()[0]
with zipfile.ZipFile(partial) as z:
    assert len(z.filelist)==len(z.NameToInfo)==count+1
    with z.open('SHA256SUMS.jsonl') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==mh
print('Computing whole-archive SHA-256',flush=True)
with partial.open('r+b') as f:os.fsync(f.fileno());digest=hashlib.file_digest(f,'sha256').hexdigest()
partial.rename(final)
result=dict(status='verified',archive=final.name,bytes=final.stat().st_size,sha256=digest,verified_files=count,source_payload_sha256='all matched; generated preservation metadata separately retained',zip_crc='passed complete reads',completion_receipt='matched verified original; all three audit receipts match',panels=6480,draws=1313520,repository_revision=revision,manifest_sha256=mh)
(dest/'verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2),flush=True)
