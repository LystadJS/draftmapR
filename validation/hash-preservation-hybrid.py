"""Inventory visible overlay; hash Linux payloads, delegate read-only base files to host."""
import hashlib,json,os
from pathlib import Path
upper=Path('/upper/unified')
owned=set()
for directory,dirs,files in os.walk(upper,followlinks=False):
    for name in files:owned.add(str((Path(directory)/name).relative_to(upper)))
for root in [Path('/workspace/scratch/837e4400dd1d'),Path('/workspace/scratch/1e9a01af2c37')]:
    for directory,dirs,files in os.walk(root,followlinks=False):
        dirs.sort();files.sort()
        with os.scandir(directory) as scan:links={e.name for e in scan if e.is_symlink()}
        dirs[:]=[d for d in dirs if d not in links]
        for name in files:
            p=Path(directory)/name;rel=str(p.relative_to(root));key='scratch/'+str(p.relative_to('/workspace/scratch'))
            if name in links and not p.exists():
                assert 'compression-interruption-20261024/table-links/' in str(p);continue
            if name in links or (root.name=='837e4400dd1d' and rel in owned):
                before=p.stat()
                with p.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
                after=p.stat();assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns)
                print(json.dumps(dict(path=key,bytes=before.st_size,sha256=digest)),flush=True)
            else:print(json.dumps(dict(path=key,base=str(p.relative_to('/workspace/scratch')))),flush=True)
