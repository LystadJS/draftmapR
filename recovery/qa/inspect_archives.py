from pathlib import Path
import zipfile, tarfile, json, hashlib
root = Path(__file__).resolve().parents[1]
results = []
for p in sorted((root/'archives').glob('*')):
    row = {'file':p.name, 'bytes':p.stat().st_size, 'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest()}
    if p.suffix == '.zip':
        with zipfile.ZipFile(p) as z:
            row['crc_failure'] = z.testzip()
            row['entries'] = len(z.infolist())
            target = root/'recovered'/p.stem
            for item in z.infolist():
                out = (target/item.filename).resolve()
                if not out.is_relative_to(target.resolve()): raise ValueError(item.filename)
            z.extractall(target)
    elif p.name.endswith('.tar.gz'):
        with tarfile.open(p) as t:
            members = t.getmembers()
            row['entries'] = len(members)
            row['first_entries'] = [m.name for m in members[:20]]
            for m in members:
                if m.isfile():
                    f=t.extractfile(m)
                    while f.read(1024*1024): pass
            row['all_member_payloads_read'] = True
    results.append(row)
(root/'qa'/'archive-inspection.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
