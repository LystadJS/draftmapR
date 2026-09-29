"""Read-only continuity audit; no scientific runner or model execution."""
from pathlib import Path
import json, hashlib, importlib.util
root=Path(__file__).resolve().parents[1]
script=root/'recovered/driftmapR-S07-R1-Recovery-Audit-20260924/scripts/audit_lineage.py'
spec=importlib.util.spec_from_file_location('historical_audit_helpers',script)
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
bases={n:root/f'recovered/driftmapR-S07-R1-checkpoint{n}-{suffix}' for n,suffix in [(2250,'013'),(3915,'014')]}
states={n:b/h.REL for n,b in bases.items()}
manifests={n:json.loads((b/'SNAPSHOT-MANIFEST.json').read_text()) for n,b in bases.items()}
checks=[]
def check(name,value):
    checks.append({'check':name,'passed':bool(value)})
    assert value,name
prefixes=[]
for name in h.JOURNALS:
    got=h.identity(states[2250]/name);bound=manifests[3915]['base_journal_prefixes'][name]
    check(name+' bound exact prefix',got['newline_complete'] and all(got[k]==bound[k] for k in ('bytes','rows','sha256')) and h.check_prefix(states[2250]/name,states[3915]/name))
    prefixes.append({'journal':name,**got})
panels=list(h.read_jsonl(states[2250]/'panel-journal.jsonl'))
caches=list(h.read_jsonl(states[2250]/'compact-cache-005.jsonl'))
exports=list(h.read_jsonl(states[2250]/'json-journal.jsonl'))
pm={r['key']:r for r in panels};cm={r['key']:r for r in caches};em={r['key']:r for r in exports}
check('2250 sequential unique committed panels',len(pm)==len(panels)==2250 and [r['panel_index'] for r in panels]==list(range(1,2251)))
check('Unique cache and export identities',len(cm)==len(caches) and len(em)==len(exports))
check('Committed checkpoint identities agree',all(k in cm and k in em and r['checkpoint_md5']==cm[k]['checkpoint_md5']==em[k]['checkpoint_md5'] for k,r in pm.items()))
cachefiles={p.stem:p for p in (states[2250]/'compact-cache-005').glob('*.rds')}
check('Cache file membership equals cache ledger',set(cachefiles)==set(cm))
for k,p in cachefiles.items():
    with p.open('rb') as f:check('Cache hash '+k,hashlib.file_digest(f,'sha256').hexdigest()==cm[k]['sha256'])
raw={};js={};counts={}
for n,m in manifests.items():
    counts[n]={'raw':0,'json':0}
    for r in m['members']:
        cats=r.get('categories',[])
        if 'journaled_raw_delta' in cats:
            key=int(Path(r['member']).stem)
            check('Nonoverlapping raw delta '+str(key),key not in raw)
            raw[key]=r;counts[n]['raw']+=1
        if 'journaled_json_delta' in cats:
            key=r['member'].split('/tables/',1)[1]
            check('Nonoverlapping JSON delta '+key,key not in js)
            js[key]=r;counts[n]['json']+=1
bound=0
for r in h.read_jsonl(states[3915]/'chunk-journal.jsonl'):
    if r['serial'] in raw:
        m=raw[r['serial']]
        check('Raw journal binding '+str(r['serial']),m['member'].endswith('/study07-results/S07-R1/'+r['chunk']) and m['bytes']==r['bytes'] and m['md5']==r['md5'])
        bound+=1
check('All recovered raw deltas bound',bound==len(raw))
latestexports={r['path']:r for r in h.read_jsonl(states[3915]/'json-journal.jsonl')}
for path,m in js.items():
    r=latestexports.get(path)
    check('JSON journal binding '+path,r and m['bytes']==r['bytes'] and m['md5']==r['md5'])
serials=sorted(raw)
result={'status':'passed','checkpoint2250_committed_panels':len(pm),'checkpoint2250_caches':len(cm),'checkpoint2250_exports':len(em),'prefixes':prefixes,'delta_counts':counts,'raw_files_bound_to_latest_journal':bound,'raw_serial_min':min(raw),'raw_serial_max':max(raw),'raw_serials_contiguous':serials==list(range(min(raw),max(raw)+1)),'json_files_bound_to_latest_journal':len(js),'checks_passed':len(checks),'scientific_execution':False,'scope':'2250 to 3915 journal continuity and both recovered delta payload bindings. Earlier checkpoints and ancestral payloads remain absent; no scientific conclusions verified.'}
(root/'qa/checkpoint2250-to-3915-lineage.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
