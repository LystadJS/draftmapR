from pathlib import Path
import zipfile, hashlib, json, stat
root=Path(__file__).resolve().parents[1]
p=root/'archives/driftmapR-S07-R1-Recovery-Audit-20260924.zip'
expected=json.loads((root/'provenance/audit-receipt-observed.json').read_text())
sha=lambda data:hashlib.sha256(data).hexdigest()
assert p.stat().st_size==expected['archive_bytes']
assert sha(p.read_bytes())==expected['archive_sha256']
target=root/'recovered'/p.stem
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None
    names=z.namelist()
    assert len(names)==len(set(names))
    manifest=z.read('AUDIT-PACKAGE-MANIFEST.json')
    assert sha(manifest)==expected['manifest_sha256']
    rows=json.loads(manifest)['members']
    assert set(names)=={r['member'] for r in rows}|{'AUDIT-PACKAGE-MANIFEST.json'}
    for info in z.infolist():
        assert (target/info.filename).resolve().is_relative_to(target.resolve())
        assert not stat.S_ISLNK(info.external_attr >> 16)
    for r in rows:
        data=z.read(r['member'])
        assert len(data)==r['bytes'] and sha(data)==r['sha256'],r['member']
    assert sha(z.read('driftmapR-S07-R1-Recovery-Audit-20260924.md'))==expected['report_sha256']
    z.extractall(target)
result={'archive':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes()),'receipt_match':True,'manifest_hash_match':True,'member_hashes_verified':len(rows),'entries':len(names),'crc':'passed','scientific_payload_chain_reexecuted':False}
(root/'qa/audit-bundle-verification.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
