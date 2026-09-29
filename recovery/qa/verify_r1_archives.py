from pathlib import Path,PurePosixPath
import json,zipfile,hashlib,stat
root=Path(__file__).resolve().parents[1]
audit=root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924'
results=[]
for name,record in [('driftmapR-S07-R1-sources.zip','frozen-sources-audit.json'),('driftmapR-S07-R1-Recovery-009.zip','recovery009-archive-audit.json')]:
    p=root/'archives'/name
    expected=json.loads((audit/'results'/record).read_text())
    assert hashlib.sha256(p.read_bytes()).hexdigest()==expected['archive_sha256']
    assert p.stat().st_size==expected['archive_bytes']
    rows={r['member']:r for r in expected['members']}
    destination=root/'recovered'/p.stem
    with zipfile.ZipFile(p) as z:
        assert z.testzip() is None
        names=z.namelist()
        assert len(names)==len(set(names)) and set(names)==set(rows)
        for info in z.infolist():
            pp=PurePosixPath(info.filename)
            assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in info.filename
            assert stat.S_IFMT(info.external_attr>>16) in (0,stat.S_IFREG)
            data=z.read(info)
            row=rows[info.filename]
            assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
            assert hashlib.md5(data).hexdigest()==row['md5']
            target=destination.joinpath(*pp.parts)
            assert target.resolve().is_relative_to(destination.resolve())
            target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists(): assert target.read_bytes()==data
            else: target.write_bytes(data)
    results.append({'archive':name,'sha256':expected['archive_sha256'],'bytes':p.stat().st_size,'verified_files':len(rows),'crc':'passed','membership_size_sha256_md5':'passed','scientific_execution':False})
(root/'qa/r1-archive-verification.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
