#!/usr/bin/env python3
"""Read-only semantic checks of restored S07-R1 checkpoints.
Does not infer scientific validity from archive integrity, execute controls,
recompute estimators, or regard historical process records as live ownership.
"""
import argparse, collections, csv, hashlib, json, time
from pathlib import Path

REL='pinned-workspace/study07-r1-operations/resumable-collection-state'
JOURNALS=('panel-journal.jsonl','chunk-journal.jsonl','json-journal.jsonl','compact-cache-005.jsonl')

def read_jsonl(path):
    with path.open('rb') as f:
        for lineno,line in enumerate(f,1):
            if not line.endswith(b'\n'):raise ValueError(f'{path}:{lineno}: incomplete line')
            if not line.strip():raise ValueError(f'{path}:{lineno}: empty line')
            yield json.loads(line)

def identity(path):
    h=hashlib.sha256(); count=0; end=None
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):
            h.update(b);count+=b.count(b'\n');end=b[-1:]
    return {'bytes':path.stat().st_size,'rows':count,'sha256':h.hexdigest(),'newline_complete':end==b'\n'}

def check_prefix(old,new):
    with old.open('rb') as a,new.open('rb') as b:
        for x in iter(lambda:a.read(1<<20),b''):
            if x!=b.read(len(x)):return False
    return True

def main():
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);root=p.parse_args().root.resolve();started=time.time()
    checks=[]
    def check(name,passed,detail=None):
        checks.append({'check':name,'passed':bool(passed),'detail':detail})
    suffixes={464:'011',468:'012',2250:'013',3915:'014'}; nums=(464,468,2250,3915); manifests={n:json.loads((root/f'recovered/driftmapR-S07-R1-checkpoint{n}-{suffixes[n]}/SNAPSHOT-MANIFEST.json').read_text()) for n in nums}
    states={n:root/f'recovered/driftmapR-S07-R1-checkpoint{n}-{suffixes[n]}'/REL for n in nums}; prefixes=[]
    for old,new in zip(nums,nums[1:]):
        for name in JOURNALS:
            got=identity(states[old]/name);expected=manifests[new]['base_journal_prefixes'][name]
            bound=all(got[k]==expected[k] for k in ('bytes','rows','sha256'))
            exact=check_prefix(states[old]/name,states[new]/name)
            check(f'{old}->{new}: {name}: bound exact byte prefix',bound and exact and got['newline_complete'])
            prefixes.append({'old':old,'new':new,'journal':name,'old_identity':got,'matches_bound_prefix':bound,'exact_byte_prefix':exact})
    latest=states[3915]; meta=manifests[3915]
    panels=list(read_jsonl(latest/'panel-journal.jsonl')); caches=list(read_jsonl(latest/'compact-cache-005.jsonl'));exports=list(read_jsonl(latest/'json-journal.jsonl'))
    panelmap={x['key']:x for x in panels};cachemap={x['key']:x for x in caches};jsonmap={x['key']:x for x in exports}
    check('3915 committed unique panel keys',len(panels)==len(panelmap)==3915)
    check('Sequential committed panel indices 1..3915',[x['panel_index'] for x in panels]==list(range(1,3916)))
    check('Strictly increasing panel chunk boundaries',all(a['through_chunk']<b['through_chunk'] for a,b in zip(panels,panels[1:])))
    check('3916 unique cache entries',len(caches)==len(cachemap)==3916)
    check('3924 unique JSON export entries',len(exports)==len(jsonmap)==3924)
    population=[x for x in exports if x['path'].startswith('population/')]; paneljson=[x for x in exports if x['path'].startswith('panels/')]
    check('JSON exports partition into 3915 panels and 9 populations',len(paneljson)==3915 and len(population)==9 and len(population)+len(paneljson)==len(exports))
    check('Panel export keyset equals committed keyset',{x['key'] for x in paneljson}==set(panelmap))
    check('Every committed panel has matching cache and JSON checkpoint MD5',all(k in cachemap and k in jsonmap and x['checkpoint_md5']==cachemap[k]['checkpoint_md5']==jsonmap[k]['checkpoint_md5'] for k,x in panelmap.items()))
    extras=set(cachemap)-set(panelmap);check('Exactly expected unfinished cache key',extras=={'s07_normal_mean_m160-1436'})
    cachefiles={p.stem:p for p in (latest/'compact-cache-005').glob('*.rds')};receiptfiles={p.stem:p for p in (latest/'verification-006').glob('*.rds')}
    check('Cache files equal cache ledger keyset',set(cachefiles)==set(cachemap))
    cache_hash_fail=[]
    for k,row in cachemap.items():
        if hashlib.file_digest(cachefiles[k].open('rb'),'sha256').hexdigest()!=row['sha256']:cache_hash_fail.append(k)
    check('All 3916 cache files freshly match cache journal SHA256',not cache_hash_fail,cache_hash_fail[:10])
    check('6480 unique input-verification receipt filenames',len(receiptfiles)==6480)
    check('All cached/committed keys have input-verification receipt',set(cachemap)<=set(receiptfiles))
    raw={};json_delta={};raw_counts={};json_counts={}
    for n,m in manifests.items():
        rcount=jcount=0
        for member in m['members']:
            cats=member.get('categories',[])
            if 'journaled_raw_delta' in cats:
                serial=int(Path(member['member']).stem);assert serial not in raw, f'duplicate raw delta {serial}'
                raw[serial]=(n,member);rcount+=1
            if 'journaled_json_delta' in cats:
                suffix=member['member'].split('/tables/',1)[1];assert suffix not in json_delta, f'duplicate JSON delta {suffix}'
                json_delta[suffix]=(n,member);jcount+=1
        raw_counts[n]=rcount;json_counts[n]=jcount
    check('Recovered journaled raw delta has exact serial coverage 163093..258466',set(raw)==set(range(163093,258467)))
    mismatch=[];raw_bound=0;chunk_keys=set();chunk_serial_count=0;checkpoint_mismatch=[];partial=[];last_for_panel={};products=collections.Counter();num_raw_rows=0
    for row in read_jsonl(latest/'chunk-journal.jsonl'):
        chunk_serial_count+=1; serial=row['serial'];k=row['panel'];products[row['product']]+=1;num_raw_rows+=row['rows']
        if serial!=chunk_serial_count:mismatch.append(('nonsequential',serial))
        if row['chunk'] in chunk_keys:mismatch.append(('duplicate-path',serial))
        chunk_keys.add(row['chunk']);last_for_panel[k]=serial
        if k not in cachemap or row['checkpoint_md5']!=cachemap[k]['checkpoint_md5']:checkpoint_mismatch.append(serial)
        if serial in raw:
            n,m=raw[serial];expected_suffix='/study07-results/S07-R1/'+row['chunk']
            if not m['member'].endswith(expected_suffix) or m['md5']!=row['md5'] or m['bytes']!=row['bytes']:mismatch.append(('payload-binding',serial))
            raw_bound+=1
        if k in extras:partial.append(row)
    check('258466 sequential unique chunk journal records',chunk_serial_count==258466 and not mismatch,mismatch[:10])
    check('All chunk checkpoint hashes agree with saved cache ledger',not checkpoint_mismatch,checkpoint_mismatch[:10])
    check('95374 restored raw payloads bound to latest chunk journal',raw_bound==95374 and not mismatch)
    check('All committed panel boundaries equal their last journaled chunk',all(last_for_panel.get(k)==v['through_chunk'] for k,v in panelmap.items()))
    check('Partial panel has exactly draw chunk258466, no committed panel/JSON export',len(partial)==1 and partial[0]['serial']==258466 and partial[0]['product']=='draws.csv.gz' and all(k not in jsonmap for k in extras))
    export_by_path={row['path']:row for row in exports};json_bad=[]
    for path,(n,m) in json_delta.items():
        row=export_by_path.get(path)
        if row is None or m['md5']!=row['md5'] or m['bytes']!=row['bytes']:json_bad.append(path)
    check('All restored JSON delta payloads match latest JSON journal',not json_bad,json_bad[:10])
    outcsv=root/'qa/full-chain-state/cache-ledger-for-r.csv'
    with outcsv.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['key','checkpoint_md5','sha256','committed']);w.writeheader()
        w.writerows(dict(x,committed=x['key'] in panelmap) for x in caches)
    tempfiles=[p for p in latest.iterdir() if p.is_file() and (p.name.startswith('json-export') or p.name.startswith('serialize'))]
    result={'schema':'driftmapR-20260924-checkpoint-lineage-audit-v1','status':'PASS' if all(x['passed'] for x in checks) else 'FAIL','started_epoch':started,'finished_epoch':time.time(),
      'committed_panels':len(panels),'planned_panels_from_receipt_file_count':len(receiptfiles),'remaining_uncommitted_panels':6480-len(panels),
      'compact_caches':len(caches),'json_exports':len(exports),'json_panel_exports':len(paneljson),'json_population_exports':len(population),'population_export_keys':[x['key'] for x in population],
      'journaled_chunks':chunk_serial_count,'last_committed_panel':panels[-1],'partial_panel':partial,'verified_raw_delta_files':len(raw),'verified_json_delta_files':len(json_delta),
      'raw_delta_counts':raw_counts,'json_delta_counts':json_counts,'historical_raw_prefix_not_freshly_restored':163092,
      'chunk_product_counts':dict(products),'journal_reported_raw_rows_not_recounted_from_csv':num_raw_rows,
      'preserved_state_temporary_files':len(tempfiles),'prefix_comparisons':prefixes,'checks_passed':sum(x['passed'] for x in checks),'checks':checks,
      'scientific_operations_performed':0,'scientific_completion':False,'limitations':[
        'Earlier raw prefix and original checkpoint/draw-plan payloads are not freshly restored; saved receipts are not equivalent to those original bytes.',
        'Raw CSV rows are bound through authenticated manifest and ledger metadata, not independently recomputed or interpreted as scientific results.',
        'This audit preserves the unfinished panel; it does not authorize cache adoption or collection restart.',
        'Historical ownership, source/runtime reviews, and completion gates remain distinct from current verification.']}
    (root/'qa/full-chain-state/checkpoint-lineage-audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('prefix_comparisons','checks')},indent=2))
    if result['status']!='PASS':
        print(json.dumps([x for x in checks if not x['passed']],indent=2));raise SystemExit(1)
if __name__=='__main__':main()

