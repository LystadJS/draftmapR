from pathlib import Path,PurePosixPath
import json,hashlib,tarfile,gzip,shutil,collections
root=Path(__file__).resolve().parents[1]
ev=root/'recovered/driftmapR-S07-R1-Recovery-009/evidence/raw'
prefix=json.loads((ev/'verified-prefix.json').read_text())
state=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state'
journal_path=state/'chunk-journal.jsonl'
journal={r['chunk']:r for r in map(json.loads,journal_path.read_text().splitlines())}
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
records=[];members=[]
for i in range(39,42):
 rp=ev/f'restored-{i:03d}.json';binding=next(r for r in prefix['archive_receipts'] if Path(r['path']).name==rp.name)
 assert sha(rp)==binding['sha256']
 rec=json.loads(rp.read_text());name=Path(rec['archive']).name;source=Path('C:/Users/John/Downloads')/name
 assert source.stat().st_size==rec['archive_bytes'] and sha(source)==rec['archive_sha256']
 archive=root/'archives'/name
 if not archive.exists():shutil.copyfile(source,archive)
 assert sha(archive)==rec['archive_sha256']
 expected={r['path']:r for r in rec['restored_members']};seen=set();total=0;count=0
 target=root/'recovered'/name.removesuffix('.tar.gz')
 with tarfile.open(archive,'r:gz') as t:
  for m in t:
   pp=PurePosixPath(m.name);assert not pp.is_absolute() and '..' not in pp.parts and '\\' not in m.name and m.isfile()
   assert m.name.startswith('study07-results/S07-R1/')
   key=m.name.removeprefix('study07-results/S07-R1/');assert key not in seen;seen.add(key)
   data=t.extractfile(m).read();md=hashlib.md5(data).hexdigest();assert len(data)==m.size
   if key in expected:assert len(data)==expected[key]['bytes'] and md==expected[key]['md5']
   row=journal.get(key);match=bool(row and row['bytes']==len(data) and row['md5']==md)
   dest=target.joinpath(*pp.parts);assert dest.resolve().is_relative_to(target.resolve());dest.parent.mkdir(parents=True,exist_ok=True)
   if dest.exists():assert dest.read_bytes()==data
   else:dest.write_bytes(data)
   members.append({'path':dest.relative_to(root).as_posix(),'original_path':m.name,'receipt_path':key,'archive':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'md5':md,'historical_restored_member':key in expected,'latest_journal_match':match,'serial':row['serial'] if row else None})
   total+=len(data);count+=1
 assert expected.keys()<=seen and count==rec['archive_members_verified'] and total==rec['archive_member_bytes']
 with gzip.open(archive,'rb') as f:
  while f.read(1<<20):pass
 records.append({'filename':name,'bytes':rec['archive_bytes'],'sha256':rec['archive_sha256'],'source':str(source),'files':count,'historical_receipt_sha256':binding['sha256'],'gzip_crc':'passed'})
 print(name+': '+str(count)+' files verified',flush=True)
matching=[m['serial'] for m in members if m['latest_journal_match']];assert len(matching)==len(set(matching))
result={'status':'passed','archives':records,'members':members,'journal_sha256':sha(journal_path),'matched_current_journal_files':len(matching),'historical_receipt_member_matches':sum(m['historical_restored_member'] for m in members),'other_archive_versions':[{'path':m['receipt_path'],'md5':m['md5'],'latest_md5':journal.get(m['receipt_path'],{}).get('md5')} for m in members if not m['latest_journal_match']],'serial_min':min(matching),'serial_max':max(matching),'scientific_execution':False,'scope':'Archive SHA256, full member count/bytes, gzip CRC, receipt subset MD5 and latest journal MD5 comparisons. Fresh member SHA256 recorded; archive-only versions remain separate.'}
(root/'qa/raw-039-041-verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('archives','members','other_archive_versions')},indent=2));print('Other archived versions:',len(result['other_archive_versions']))













