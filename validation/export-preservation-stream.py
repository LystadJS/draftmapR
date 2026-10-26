"""Read-only tar stream of retained scratch roots, with explicit link metadata."""
import json
import os
import sys
import tarfile
from pathlib import Path

roots = [Path('/workspace/scratch/837e4400dd1d'), Path('/workspace/scratch/1e9a01af2c37')]
links = []
skip = set(json.load(sys.stdin)) if '--skip-stdin' in sys.argv else set()
with tarfile.open(fileobj=sys.stdout.buffer, mode='w|') as archive:
    for root in roots:
        for directory, dirs, files in os.walk(root, followlinks=False):
            dirs.sort(); files.sort()
            for name in list(dirs):
                p = Path(directory) / name
                if p.is_symlink():
                    links.append(dict(path=str(p), target=os.readlink(p), kind='directory'))
                    dirs.remove(name)
            for name in files:
                p = Path(directory) / name
                rel = 'scratch/' + str(p.relative_to('/workspace/scratch'))
                if p.is_symlink():
                    links.append(dict(path=str(p), target=os.readlink(p), kind='file', dereferenced=p.exists()))
                    if not p.exists():
                        assert 'compression-interruption-20261024/table-links/' in str(p), str(p)
                        continue
                if rel in skip:
                    continue
                before = p.stat()
                assert p.is_file(), str(p)
                info = tarfile.TarInfo(rel)
                info.size = before.st_size
                info.mode = before.st_mode & 0o7777
                info.mtime = before.st_mtime
                with p.open('rb') as f:
                    archive.addfile(info, f)
                after = p.stat()
                assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), str(p)
    import io
    content = json.dumps(links, indent=2).encode()
    info = tarfile.TarInfo('preservation/source-links.json'); info.size = len(content); info.mode = 0o600
    archive.addfile(info, io.BytesIO(content))
