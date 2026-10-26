"""Stream independent source hashes without retaining per-file state in memory."""
import hashlib,json,os
from pathlib import Path
for root in [Path('/workspace/scratch/837e4400dd1d'),Path('/workspace/scratch/1e9a01af2c37')]:
    for directory,dirs,files in os.walk(root,followlinks=False):
        dirs.sort();files.sort()
        dirs[:]=[d for d in dirs if not (Path(directory)/d).is_symlink()]
        for name in files:
            p=Path(directory)/name
            if not p.exists():
                assert p.is_symlink() and 'compression-interruption-20261024/table-links/' in str(p)
                continue
            before=p.stat()
            with p.open('rb') as f:h=hashlib.file_digest(f,'sha256').hexdigest()
            after=p.stat();assert (before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns)
            print(json.dumps(dict(path='scratch/'+str(p.relative_to('/workspace/scratch')),bytes=before.st_size,sha256=h)),flush=True)
