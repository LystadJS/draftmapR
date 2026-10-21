from pathlib import Path,PurePosixPath
import json,csv,io,zipfile,hashlib,shutil,stat,collections
r=Path(__file__).resolve().parents[1];src=Path('C:/Users/John/Downloads/driftmapR-S07-R1-live-state-20260921-002.zip');a=r/'archives'/src.name
with src.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()=='82da3464aab96d65f7ec208532a6c922b17a1d9d26a0356bb6ae6a663fbe51ed'
if not a.exists():shutil.copyfile(src,a)
target=r/'recovered'/a.stem;rows=[]
with zipfile.ZipFile(a) as z:
 expected={x['path']:x for x in csv.DictReader(io.StringIO(z.read('MEMBERS-SHA256.csv').decode()))}
 assert len(z.namelist())==len(set(z.namelist()))==9771 and set(z.namelist())==set(expected)|{'MEMBERS-SHA256.csv'}
 for info in z.infolist():
  pp=PurePosixPath(info.filename);assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in info.filename and ':' not in info.filename and stat.S_IFMT(info.external_attr>>16) in (0,stat.S_IFREG)
  data=z.read(info);h=hashlib.sha256(data).hexdigest()
  if info.filename in expected:assert len(data)==int(expected[info.filename]['bytes']) and h==expected[info.filename]['sha256']
  p=target.joinpath(*pp.parts);assert p.resolve().is_relative_to(target.resolve());p.parent.mkdir(parents=True,exist_ok=True)
  if p.exists():assert p.read_bytes()==data
  else:p.write_bytes(data)
  rows.append({'path':p.relative_to(r).as_posix(),'bytes':len(data),'sha256':h})

missing=list(csv.DictReader((r/'qa/remaining-raw-live002-map.csv').open()))
filled=[]
for x in missing:
 p=target/x['archive_member'];data=p.read_bytes()
 assert len(data)==int(x['bytes']) and hashlib.md5(data).hexdigest()==x['md5'] and hashlib.sha256(data).hexdigest()==x['archive_member_sha256']
 filled.append({'serial':int(x['serial']),'chunk':x['chunk'],'bytes':int(x['bytes']),'md5':x['md5'],'path':p.relative_to(r).as_posix()})
latest=r/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state'
lineage=[]
for name in ['chunk-journal.jsonl','json-journal.jsonl','panel-journal.jsonl']:
 old=(target/'pinned-workspace/study07-r1-operations/resumable-collection-state'/name).read_bytes();new=(latest/name).read_bytes()
 assert new.startswith(old)
 lineage.append({'journal':name,'exact_prefix':True,'prefix_bytes':len(old)})
proof={'status':'passed','archive':a.name,'bytes':a.stat().st_size,'sha256':'82da3464aab96d65f7ec208532a6c922b17a1d9d26a0356bb6ae6a663fbe51ed','verified_files':len(rows),'members':rows,'filled_gap':filled,'lineage':lineage,'scientific_execution':False}
(r/'qa/live002-verification.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in proof.items() if k not in ('members','filled_gap')},indent=2));print('gap fills',len(filled))
