from pathlib import Path,PurePosixPath
import json,csv,io,zipfile,hashlib,shutil,stat,collections
r=Path(__file__).resolve().parents[1];src=Path('C:/Users/John/Downloads/driftmapR-S07-R1-Restart-004.zip');a=r/'archives'/src.name
with src.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()=='3261277c5707e49a2414dabb75b8beae58f299e6b96717604b69090f7a02399e'
if not a.exists():shutil.copyfile(src,a)
target=r/'recovered'/a.stem;rows=[]
with zipfile.ZipFile(a) as z:
 expected={x['path']:x for x in csv.DictReader(io.StringIO(z.read('MEMBERS-SHA256.csv').decode()))}
 assert len(z.namelist())==len(set(z.namelist()))==486 and set(z.namelist())==set(expected)|{'MEMBERS-SHA256.csv'}
 for info in z.infolist():
  pp=PurePosixPath(info.filename);assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in info.filename and ':' not in info.filename and stat.S_IFMT(info.external_attr>>16) in (0,stat.S_IFREG)
  data=z.read(info);h=hashlib.sha256(data).hexdigest()
  if info.filename in expected:assert len(data)==int(expected[info.filename]['bytes']) and h==expected[info.filename]['sha256']
  p=target.joinpath(*pp.parts);assert p.resolve().is_relative_to(target.resolve());p.parent.mkdir(parents=True,exist_ok=True)
  if p.exists():assert p.read_bytes()==data
  else:p.write_bytes(data)
  rows.append({'path':p.relative_to(r).as_posix(),'bytes':len(data),'sha256':h})
report=Path('C:/Users/John/Downloads/driftmapR-S07-R1-Restart-004.md');assert report.read_bytes()==(target/report.name).read_bytes()
proof={'status':'passed','archive':a.name,'bytes':a.stat().st_size,'sha256':'3261277c5707e49a2414dabb75b8beae58f299e6b96717604b69090f7a02399e','verified_files':len(rows),'members':rows,'standalone_report_identical':True,'scientific_execution':False}
(r/'qa/restart004-verification.json').write_text(json.dumps(proof,indent=2),encoding='utf-8')
missing=list(csv.DictReader((r/'qa/remaining-raw-journal-files.csv').open()));members=list(csv.DictReader((target/'saved-restart-reference/MEMBERS-SHA256.csv').open()));lookup={x['path'].split('/study07-results/S07-R1/',1)[1]:x for x in members if '/study07-results/S07-R1/' in x['path']}
matched=[];unmapped=[]
for x in missing:
 m=lookup.get(x['chunk'])
 if m and int(m['bytes'])==int(x['bytes']):matched.append(dict(x,archive_member=m['path'],archive_member_sha256=m['sha256']))
 else:unmapped.append(x['serial'])
with (r/'qa/remaining-raw-live002-map.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=list(matched[0]) if matched else list(missing[0]));w.writeheader();w.writerows(matched)
result={'status':'metadata_mapping_only_payload_not_recovered','restart_members_verified':486,'standalone_report_identical':True,'missing_files':len(missing),'mapped_to_live002_manifest':len(matched),'unmapped_serials':unmapped,'target_archive':'driftmapR-S07-R1-live-state-20260921-002.zip','target_bytes':214782459,'target_sha256':'82da3464aab96d65f7ec208532a6c922b17a1d9d26a0356bb6ae6a663fbe51ed','scope':'Exact logical-path and size match to preserved live002 member manifest; SHA256 identities recorded for subsequent payload verification. No missing payload bytes recovered.','scientific_execution':False}
(r/'qa/restart004-gap-trace.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
