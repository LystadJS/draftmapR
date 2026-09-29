from pathlib import Path
import json,hashlib,csv
root=Path(__file__).resolve().parents[1]
base=root/'recovered/driftmapR-S07-R1-checkpoint3915-014'
state=base/'pinned-workspace/study07-r1-operations/resumable-collection-state'
out=root/'qa/checkpoint3915-state'
out.mkdir(exist_ok=True)
def read(name):
    with (state/name).open('rb') as f:
        for line in f:
            assert line.endswith(b'\n') and line.strip()
            yield json.loads(line)
panels=list(read('panel-journal.jsonl'));caches=list(read('compact-cache-005.jsonl'));exports=list(read('json-journal.jsonl'))
pm={x['key']:x for x in panels};cm={x['key']:x for x in caches};em={x['key']:x for x in exports}
assert len(pm)==len(panels)==3915 and [r['panel_index'] for r in panels]==list(range(1,3916))
assert len(cm)==len(caches)==3916 and len(em)==len(exports)==3924
assert set(cm)-set(pm)=={'s07_normal_mean_m160-1436'}
assert {r['key'] for r in exports if r['path'].startswith('panels/')}==set(pm)
assert sum(r['path'].startswith('population/') for r in exports)==9
for k in pm:assert pm[k]['checkpoint_md5']==cm[k]['checkpoint_md5']==em[k]['checkpoint_md5']
files={p.stem:p for p in (state/'compact-cache-005').glob('*.rds')}
assert set(files)==set(cm)
for k,p in files.items():
    with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==cm[k]['sha256']
receipts={p.stem for p in (state/'verification-006').glob('*.rds')}
assert len(receipts)==6480 and set(cm)<=receipts
manifest=json.loads((base/'SNAPSHOT-MANIFEST.json').read_text())
raw={int(Path(r['member']).stem):r for r in manifest['members'] if 'journaled_raw_delta' in r.get('categories',[])}
chunks=set();last={};partial=[];bound=0
for count,r in enumerate(read('chunk-journal.jsonl'),1):
    assert r['serial']==count and r['chunk'] not in chunks
    chunks.add(r['chunk']);last[r['panel']]=count
    assert r['checkpoint_md5']==cm[r['panel']]['checkpoint_md5']
    if count in raw:
        x=raw[count]
        assert x['member'].endswith('/study07-results/S07-R1/'+r['chunk']) and x['bytes']==r['bytes'] and x['md5']==r['md5']
        bound+=1
    if r['panel'] not in pm:partial.append(r)
assert count==258466 and bound==len(raw)==4995
assert all(last[k]==r['through_chunk'] for k,r in pm.items())
assert len(partial)==1 and partial[0]['serial']==258466 and partial[0]['product']=='draws.csv.gz'
assert partial[0]['panel'] not in em
with (out/'cache-ledger-for-r.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['key','checkpoint_md5','sha256','committed']);w.writeheader()
    w.writerows(dict(x,committed=x['key'] in pm) for x in caches)
summary={'committed_panel_records':len(pm),'cached_panels':len(cm),'input_receipts':len(receipts),'chunk_records':count,'verified_raw_delta_bindings':bound,'partial_panel':partial[0]['panel'],'remaining_uncommitted':6480-len(pm),'status':'passed','scope':'Latest snapshot journals, cache bytes and delta bindings only. Earlier journal prefix continuity and missing raw payloads not verified. No scientific execution.'}
(out/'journal-audit.json').write_text(json.dumps(summary,indent=2))
original=root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924/scripts/audit_saved_state.R'
code=original.read_text()
code=code.replace('staging/checkpoint3915/','recovered/driftmapR-S07-R1-checkpoint3915-014/')
code=code.replace('"staging/sources"','"recovered/driftmapR-S07-R1-sources"')
code=code.replace('output <- file.path(root, "results")','output <- file.path(root, "qa", "checkpoint3915-state")')
code=code.replace('# R 4.6.1 here is an inspection runtime, NOT the frozen scientific R 4.5.3 runtime.','# Adapted for local paths and native Windows R 4.5.3 inspection; not the pinned Linux runtime.')
(root/'qa/audit_checkpoint3915_state.R').write_text(code)
print(json.dumps(summary,indent=2))
