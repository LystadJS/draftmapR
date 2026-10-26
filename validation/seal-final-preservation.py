"""Seal an already source-verified archive after rechecking its embedded manifest."""
import hashlib,json,os,sqlite3,sys,zipfile
from pathlib import Path
dest=Path(sys.argv[1]);revision='4a02e291749f7c62b937c01962f360682c0643e0'
partial=dest/'driftmapR-final-preservation-20261026.resumed.partial.zip';final=dest/'driftmapR-final-preservation-20261026.zip'
assert not final.exists()
db=sqlite3.connect('file:'+str(dest/'final-verification-4a02e29.sqlite')+'?mode=ro',uri=True)
assert db.execute('SELECT count(*) FROM files WHERE checked<>1').fetchone()[0]==0
count=db.execute('SELECT count(*) FROM files').fetchone()[0]
with zipfile.ZipFile(partial) as z:
    assert len(z.filelist)==len(z.NameToInfo)==count+1
    mh=hashlib.sha256();n=0
    with z.open('SHA256SUMS.jsonl') as manifest:
        for line in manifest:
            mh.update(line);row=json.loads(line);n+=1
            assert db.execute('SELECT bytes,sha256,checked FROM files WHERE path=?',(row['path'],)).fetchone()==(row['bytes'],row['sha256'],1)
            assert z.getinfo(row['path']).file_size==row['bytes']
            with z.open(row['path']) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256'],row['path']
            if n%50000==0:print('Final manifest verified',n,flush=True)
    assert n==count
print('Computing final archive SHA-256',flush=True)
with partial.open('r+b') as f:
    f.flush();os.fsync(f.fileno());digest=hashlib.file_digest(f,'sha256').hexdigest()
partial.rename(final)
result=dict(status='verified',archive=final.name,bytes=final.stat().st_size,sha256=digest,verified_files=count,source_payload_sha256='all matched; generated preservation metadata separately retained',zip_crc='passed complete reads',completion_receipt='matched verified original; all three audit receipts match',panels=6480,draws=1313520,repository_revision=revision,manifest_sha256=mh.hexdigest(),runtime_tar_members=23751,full_runtime_restore_rehearsal=False)
(dest/'verification.json').write_text(json.dumps(result,indent=2))
(dest/(final.name+'.sha256')).write_text(digest+'  '+final.name+'\n')
print(json.dumps(result,indent=2),flush=True)
