from pathlib import Path
import json,csv,hashlib
root=Path('driftmapR-recovery')
jp=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state/chunk-journal.jsonl'
journal=[json.loads(x) for x in jp.read_text().splitlines()]
covered={}
for p in sorted((root/'qa').glob('raw-*-verification.json')):
 proof=json.loads(p.read_text());assert proof['status']=='passed'
 for m in proof['members']:
  if m['latest_journal_match']:
   assert m['serial'] not in covered
   covered[m['serial']]={'path':m['path'],'bytes':m['bytes'],'md5':m['md5'],'chunk':m['receipt_path']}
for n,suffix in ((464,'011'),(468,'012'),(2250,'013'),(3915,'014')):
 folder=root/f'recovered/driftmapR-S07-R1-checkpoint{n}-{suffix}'
 for m in json.loads((folder/'SNAPSHOT-MANIFEST.json').read_text())['members']:
  if 'journaled_raw_delta' in m.get('categories',[]):
   serial=int(Path(m['member']).stem);assert serial not in covered
   covered[serial]={'path':(folder/m['member']).relative_to(root).as_posix(),'bytes':m['bytes'],'md5':m['md5'],'chunk':m['member'].split('/study07-results/S07-R1/')[1]}
missing=[]
for row in journal:
 m=covered.get(row['serial'])
 if m:
  assert all(m[k]==row[k] for k in ('bytes','md5','chunk'))
 else:missing.append(row)
with (root/'qa/remaining-raw-journal-files.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=['serial','chunk','bytes','md5','panel','product']);w.writeheader();w.writerows({k:r[k] for k in w.fieldnames} for r in missing)
result={'status':'incomplete_payload_recovery','journal_records':len(journal),'covered_by_verified_archive_evidence':len(covered),'missing_raw_files':len(missing),'missing_raw_bytes':sum(r['bytes'] for r in missing),'journal_sha256':hashlib.sha256(jp.read_bytes()).hexdigest(),'scope':'Reconciliation of prior verified raw receipts and snapshot manifest bindings; not a fresh rehash of every recovered payload. Missing means absent from these verified sources.','next_artifact':'driftmapR-S07-R1-checkpoint361-008.zip parts 001-003 and manifest; part002 version 1 required. Coverage of the remaining gap is not yet confirmed.','scientific_execution':False}
c361=json.loads((root/'qa/checkpoint361-verification.json').read_text());assert not c361['raw_journal_mismatches'] and not c361['filled_gap_serials']
result.update(checkpoint361_verified_files=c361['verified_files'],checkpoint361_raw_journal_matches=c361['raw_journal_matches'],checkpoint361_gap_fills=0,next_artifact='driftmapR-S07-R1-live-state-20260921-002.zip; 9344 missing files mapped by path and size, payload unavailable.')
(root/'qa/raw-complete-inventory-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
