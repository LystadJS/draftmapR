"""Preserve compression links after container termination; never remove payloads."""
import csv, hashlib, json, os, shutil
from pathlib import Path

root = Path('/workspace/scratch/837e4400dd1d')
ops = root / 'study07-r1-operations'
tables = root / 'study07-results/S07-R1/tables'
archive = ops / 'compression-interruption-20261024'
new_route = Path('/root/.codex/tmp/s07r1-compression-restart-20261024')
assert not archive.exists() and not os.path.lexists(new_route)
assert shutil.disk_usage('/lower').free > 5 * 1024**3
for proc in Path('/proc').iterdir():
    if proc.name.isdigit():
        try:
            command = (proc / 'cmdline').read_bytes()
        except (FileNotFoundError, PermissionError):
            continue
        assert b'resume-collection-prefix-006.R' not in command
        assert b'compress-tables.py' not in command
with (tables / 'csv-chunk-manifest.csv').open() as f:
    names = list(dict.fromkeys(r['product'] for r in csv.DictReader(f)))
assert len(names) == 35
links = []
for name in names:
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    for suffix in ('', '.committing'):
        p = tables / (name + suffix)
        if os.path.lexists(p):
            assert p.is_symlink(), str(p)
            target = p.resolve()
            assert target.is_relative_to('/upper/compression-staging/s07r1-compression-006')
            links.append((p, name + suffix, os.readlink(p), target.stat().st_size if target.exists() else 0))
assert len(links) == 35
archive.mkdir()
for filename in ('execution-process.json',):
    shutil.copy2(ops / filename, archive / filename)
shutil.copy2(ops / 'resumable-collection-state/driver-status.json', archive / 'driver-status.json')
shutil.copy2(tables / 'csv-chunk-manifest.csv', archive / 'csv-chunk-manifest.csv')
receipt = dict(status='preserved_interrupted_compression', links=[dict(path=n,target=t,bytes=b) for _,n,t,b in links], payloads_deleted=False, frozen_code_changed=False)
(archive / 'intent.json').write_text(json.dumps(receipt, indent=2))
for p, name, target, size in links:
    dest = archive / 'table-links' / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    os.rename(p, dest)
    assert os.readlink(dest) == target
receipt['status'] = 'preserved_and_ready_for_fresh_routing'
(archive / 'complete.json').write_text(json.dumps(receipt, indent=2))
print(json.dumps(receipt, indent=2))
