from pathlib import Path
import json,csv,hashlib,collections
root=Path(__file__).resolve().parents[1]
base=root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924'
load=lambda p:json.loads((base/p).read_text())
ids=load('results/input-identities-and-dependencies.json')
old=load('references/historical-recovery009-dependencies/immutable-restore-dependencies.json')['archives']
rows=[]
def add(r,group,source):
    row={'group':group,'filename':r.get('filename',r.get('file_name','')),'bytes':r.get('bytes',''),'sha256':r.get('sha256',''),'library_file_id':r.get('library_file_id',''),'file_id':r.get('file_id',''),'version':r.get('version',r.get('current_version_number','')),'source':source,'local_status':'not_recovered'}
    p=root/'archives'/row['filename']
    if p.is_file() and row['sha256']:
        row['local_status']='verified' if hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'] else 'hash_mismatch'
    rows.append(row)
for r in ids['single_file_inputs']: add(r,'source_or_operational','results/input-identities-and-dependencies.json')
groups=[]
for g in ids['checkpoint_transport_groups']:
    local_archive=root/'archives'/g['archive']
    local_verified=local_archive.is_file() and local_archive.stat().st_size==g['archive_bytes'] and hashlib.file_digest(local_archive.open('rb'),'sha256').hexdigest()==g['archive_sha256']
    parts=sorted(g['parts'],key=lambda r:r['index'])
    offset=0
    for i,r in enumerate(parts,1):
        assert r['index']==i and r['offset']==offset
        offset+=r['bytes']
        add(r,f"checkpoint{g['checkpoint']}",'results/input-identities-and-dependencies.json')
        if local_verified:rows[-1]['local_status']='preserved_in_verified_reconstructed_archive'
    assert offset==g['archive_bytes']
    groups.append({'checkpoint':g['checkpoint'],'parts':len(parts),'bytes':offset,'metadata_offsets_and_sizes':'passed','archive_hash_verified_locally':local_verified})
for r in old:add(r,'ancestral_'+r['kind'],'references/historical-recovery009-dependencies/immutable-restore-dependencies.json')
pub=load('references/historical-recovery009-dependencies/PUBLICATION-INDEX.json')
recovery=root/'recovered/driftmapR-S07-R1-Recovery-009'
prefix=json.loads((recovery/'evidence/raw/verified-prefix.json').read_text())
pub_artifacts={(r['filename'],r.get('sha256','')):r for inc in pub['increments'] for r in inc['artifacts']}
raw_bytes=0
assert len(prefix['archive_receipts'])==81
for receipt in prefix['archive_receipts']:
    p=recovery/'evidence/raw'/Path(receipt['path']).name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==receipt['sha256']
    rec=json.loads(p.read_text())
    key=(Path(rec['archive']).name,rec['archive_sha256'])
    r=pub_artifacts[key]
    assert r['bytes']==rec['archive_bytes'] and r['library_file_id']==rec['library_file_id']
    add(r,'ancestral_raw_prefix','Recovery009/evidence/raw/'+p.name)
    raw_bytes+=r['bytes']
seen={(r['filename'],r['sha256']) for r in rows}
for inc in pub['increments']:
    for r in inc['artifacts']:
        key=(r['filename'],r.get('sha256',''))
        if key in seen: continue
        seen.add(key)
        group='published_raw_candidate' if inc['kind']=='product_archive' and r['filename'].endswith('.tar.gz') else 'publication_support'
        add(r,group,'references/historical-recovery009-dependencies/PUBLICATION-INDEX.json')
c361=load('references/historical-recovery009-dependencies/checkpoint361-recovery-index.json')
for r in c361['saved_parts_and_support_files']:add(r,'checkpoint361_support','references/historical-recovery009-dependencies/checkpoint361-recovery-index.json')
out=root/'provenance/RECOVERY_DEPENDENCIES.csv'
with out.open('w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
lines=['# Exact recorded recovery dependencies','','Generated from the verified audit bundle. Historical PASS flags are not current payload verification. Byte/hash blanks indicate the index did not supply that field. See RECOVERY_DEPENDENCIES.csv for IDs and hashes.','']
for group in dict.fromkeys(r['group'] for r in rows):
    lines.extend(['## '+group,''])
    for r in rows:
        if r['group']==group:lines.append('- `'+r['filename']+'`'+(' — version '+str(r['version']) if r['version']!='' else ''))
    lines.append('')
(root/'provenance/RECOVERY_DEPENDENCIES.md').write_text('\n'.join(lines),encoding='utf-8')
summary={'recorded_files':len(rows),'groups':dict(collections.Counter(r['group'] for r in rows)),'original_and_r1_ancestral_bytes':sum(r['bytes'] for r in old),'raw_prefix_archive_bytes':raw_bytes,'checkpoint_transport':groups,'note':'All 128 historical ancestral archive identities resolved: 25 original + 22 R1 + 81 raw prefix. The 81 receipt hashes and publication identity bindings passed metadata checks; ancestral payloads remain absent. Recovered checkpoint archives are identified separately above. Publication support/candidates are not all mandatory.'}
ancestral=[r for r in rows if r['group'].startswith('ancestral_')]
summary['ancestral_archives_verified_locally']=sum(r['local_status']=='verified' for r in ancestral)
summary['ancestral_archives_missing']=sum(r['local_status']!='verified' for r in ancestral)
summary['ancestral_bytes_missing']=sum(int(r['bytes']) for r in ancestral if r['local_status']!='verified')
summary['note']='All 128 historical ancestral archive identities resolved. Local recovery counts and missing bytes are reported separately. The 81 raw receipt hashes and publication bindings passed metadata checks; metadata alone does not recover payloads. Publication support/candidates are not all mandatory.'
(root/'qa/dependency-index-verification.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
