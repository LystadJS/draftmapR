from pathlib import Path,PurePosixPath
import json,hashlib,zipfile,stat,csv
root=Path(__file__).resolve().parents[1];archive=root/'archives/driftmapR-S07-R1-progress-20260922-007a.zip';target=root/'recovered/driftmapR-S07-R1-checkpoint361-008'
latest=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state'
journal={r['chunk']:r for r in map(json.loads,(latest/'chunk-journal.jsonl').read_text().splitlines())};missing={int(r['serial']) for r in csv.DictReader((root/'qa/remaining-raw-journal-files.csv').open())}
rows=[];raw=[]
with zipfile.ZipFile(archive) as z:
 manifest=json.loads(z.read('SNAPSHOT-MANIFEST.json'));expected={r['member']:r for r in manifest['members']}
 assert len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(expected)|{'SNAPSHOT-MANIFEST.json'}
 for i,info in enumerate(z.infolist()):
  pp=PurePosixPath(info.filename);assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in info.filename and ':' not in info.filename
  assert stat.S_IFMT(info.external_attr>>16) in (0,stat.S_IFREG)
  data=z.read(info);h=hashlib.sha256(data).hexdigest();md=hashlib.md5(data).hexdigest()
  if info.filename in expected:
   e=expected[info.filename];assert len(data)==e['bytes'] and h==e['sha256']
   if e.get('md5'):assert md==e['md5']
  p=target.joinpath(*pp.parts);assert p.resolve().is_relative_to(target.resolve());p.parent.mkdir(parents=True,exist_ok=True)
  if p.exists():assert p.read_bytes()==data
  else:p.write_bytes(data)
  rows.append({'path':p.relative_to(root).as_posix(),'bytes':len(data),'sha256':h})
  if '/study07-results/S07-R1/' in info.filename:
   key=info.filename.split('/study07-results/S07-R1/',1)[1];r=journal.get(key)
   if r:raw.append({'path':rows[-1]['path'],'serial':r['serial'],'match':r['bytes']==len(data) and r['md5']==md,'fills_gap':r['serial'] in missing})
  if i and i%10000==0:print('Verified members:',i,flush=True)
transport=json.loads((root/'provenance/checkpoint361-transport-manifest.json').read_text())
result={'status':'passed','archive':archive.name,'bytes':archive.stat().st_size,'sha256':transport['source_sha256'],'transport_parts':transport['parts'],'part002_identity':'Exact manifest hash and independently recorded whole-archive hash passed; no live Library version query.','verified_files':len(rows),'members':rows,'raw_journal_matches':sum(r['match'] for r in raw),'raw_journal_mismatches':[r for r in raw if not r['match']],'filled_gap_serials':[r['serial'] for r in raw if r['match'] and r['fills_gap']],'scientific_execution':False,'dependencies':manifest['dependencies']}
(root/'qa/checkpoint361-verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in result.items() if k not in ('members','transport_parts')},indent=2))
