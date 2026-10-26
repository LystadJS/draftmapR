"""Create and fully read back a ZIP64 preservation archive on an external drive."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile
from pathlib import Path

base = Path(__file__).resolve().parents[2]
repo = base / 'driftmapR-git'
destination = Path(sys.argv[1]).resolve()
assert destination.drive.upper() == 'D:'
assert not destination.exists(), 'Use a fresh directory; never overwrite a backup'
assert shutil.disk_usage(destination.parent).free > 60 * 1024**3
destination.mkdir()
container = 'driftmapr-collection-20261023'
git = ['git', '-c', 'safe.directory='+repo.as_posix(), '-C', str(repo)]
def run(args, **kw):
    return subprocess.run(args, check=True, **kw)
revision = subprocess.check_output(git+['rev-parse','HEAD'], text=True).strip()
assert not subprocess.check_output(git+['status','--porcelain'], text=True).strip(), 'Commit scripts first'
bundle = destination/'repository.bundle'
tree = destination/'repository.tar'
runtime = destination/'runtime-container.tar'
print('Saving repository and reconstructed container runtime', flush=True)
run(git+['bundle','create',str(bundle),'--all'])
run(git+['bundle','verify',str(bundle)])
run(git+['archive','--format=tar','-o',str(tree),'HEAD'])
run(['docker','export','--output',str(runtime),container])
final = destination/'driftmapR-final-preservation-20261026.zip'
partial = final.with_suffix('.partial.zip')
rows = []; names = set(); started = time.time()
def write_member(z, name, stream, size, mode=0o644):
    assert name not in names and not name.startswith('/') and '..' not in Path(name).parts
    assert shutil.disk_usage(destination).free - size > 3*1024**3, 'Preserve disk reserve'
    names.add(name)
    info = zipfile.ZipInfo(name); info.create_system = 3; info.external_attr = (0o100000|mode)<<16
    info.compress_type = zipfile.ZIP_STORED
    h=hashlib.sha256(); count=0
    with z.open(info,'w',force_zip64=True) as out:
        while chunk := stream.read(1024*1024):
            out.write(chunk); h.update(chunk); count += len(chunk)
    assert count == size, name
    rows.append(dict(path=name,bytes=count,sha256=h.hexdigest(),mode=oct(mode)))
    if len(rows)%5000 == 0: print('Archived',len(rows),'files',sum(r['bytes'] for r in rows),'bytes',flush=True)
with zipfile.ZipFile(partial,'x',allowZip64=True) as z:
    for p in [bundle,tree,runtime]:
        with p.open('rb') as f:write_member(z,'preservation/'+p.name,f,p.stat().st_size)
    err = (destination/'export-stderr.log').open('wb')
    proc=subprocess.Popen(['docker','exec',container,'python3','/validation/export-preservation-stream.py'],stdout=subprocess.PIPE,stderr=err)
    try:
        with tarfile.open(fileobj=proc.stdout,mode='r|') as incoming:
            for member in incoming:
                assert member.isfile(), member.name
                write_member(z,member.name,incoming.extractfile(member),member.size,member.mode)
                incoming.members.clear()  # Streaming tar must not retain hundreds of thousands of headers.
        proc.stdout.close()
        assert proc.wait()==0, 'Source export failed; inspect export-stderr.log'
    finally:
        err.close()
        if proc.poll() is None:proc.terminate();proc.wait()
    # Host provenance and runtime reconstruction inputs supplement the retained scratch roots.
    for root in [base/'driftmapR-recovery/provenance',base/'runtime-reconstruction']:
        for p in sorted(root.rglob('*')):
            if p.is_file():
                before=p.stat()
                with p.open('rb') as f:write_member(z,'host/'+p.relative_to(base).as_posix(),f,before.st_size)
                after=p.stat();assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns)
    import io
    readme=('Final completed driftmapR preservation checkpoint. Repository revision: '+revision+'\n'
      'Extract on a Linux filesystem with adequate space. All regular files use SHA-256 in MANIFEST.json.\n'
      'Import preservation/runtime-container.tar with docker import to reconstruct the OS and graphics dependencies.\n'
      'Extract scratch/ into /workspace/scratch in an isolated container with the original 12 GiB/2 CPU limits.\n'
      'Completed linked file payloads are materialized as regular files. source-links.json records original links.\n'
      'Sixteen dangling historical .committing links describe never-created files in the interrupted attempt;\n'
      'they are metadata only and are not missing completed products. Do not restore absolute operational links blindly.\n'
      'Restore repository history with git clone preservation/repository.bundle; repository.tar is the tracked tree.\n'
      'Docker export excludes mounted data; the scratch members supply the completed mounted study state.\n'
      'Reapply read-only scientific source mounts and verification gates before further work.\n'
      'This archive preserves the current complete reconstruction, not every older redundant archive ZIP.\n'
      'Private operational records are included; do not publish the archive without reviewing them.\n').encode()
    write_member(z,'preservation/RESTORE.txt',io.BytesIO(readme),len(readme))
    manifest=dict(schema=1,repository_revision=revision,files=rows,archive_mode='ZIP64_STORED',scope='Completed reconstructed study, runtime, provenance and repository history')
    z.writestr('MANIFEST.json',json.dumps(manifest,indent=2))
with partial.open('rb') as f:os.fsync(f.fileno())
print('Reopening archive and verifying every member',flush=True)
with zipfile.ZipFile(partial) as z:
    assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
    embedded=json.loads(z.read('MANIFEST.json'));assert embedded==manifest
    for i,row in enumerate(rows,1):
        with z.open(row['path']) as f:
            h=hashlib.sha256();count=0
            while chunk:=f.read(1024*1024):h.update(chunk);count+=len(chunk)
        assert count==row['bytes'] and h.hexdigest()==row['sha256'],row['path']
        if i%10000==0:print('Verified',i,'members',flush=True)
    prefix='scratch/837e4400dd1d/study07-results/S07-R1/'
    audit=json.loads(z.read(prefix+'final-audit.json'));receipt=json.loads(z.read(prefix+'execution-complete.json'))
    assert audit['status']=='passed' and receipt['independent_audit_passed'] is True
    assert audit['panels']==receipt['panels']==6480 and audit['planned_draws']==receipt['draws']==1313520
    assert hashlib.sha256(z.read(prefix+'execution-complete.json')).hexdigest()=='8aa965e96c411dea3fc1253362c1f7bebc45c32888861a32538140cdf68086bd'
    assert hashlib.sha256(z.read(prefix+'final-audit.json')).hexdigest()=='901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'
print('Computing whole-archive SHA-256',flush=True)
with partial.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
partial.rename(final)
result=dict(status='verified',archive=final.name,bytes=final.stat().st_size,sha256=digest,verified_files=len(rows),all_member_sha256='passed',zip_crc='passed on complete member reads',completion_receipt='matched verified original',repository_revision=revision,elapsed_seconds=time.time()-started)
(destination/'verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2),flush=True)
