from pathlib import Path
import json,hashlib,shutil,zipfile
r=Path('driftmapR-recovery');d=Path('C:/Users/John/Downloads');m=json.loads((d/'driftmapR-S07-R1-checkpoint361-008-manifest.json').read_text());expected='6a77c721e26ccf794169f19e0db0fa0da8ba0b33f1710284bedbb4e37987024d'
assert m['source_sha256']==expected and m['source_bytes']==569351915
pos=0
for x in m['parts']:
 p=d/x['file'];assert x['offset']==pos and p.stat().st_size==x['bytes']
 with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==x['sha256']
 pos+=x['bytes']
assert pos==m['source_bytes']
p=r/'archives'/m['source_archive']
if not p.exists():
 with p.open('xb') as out:
  for x in m['parts']:
   with (d/x['file']).open('rb') as f:shutil.copyfileobj(f,out)
with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==expected
shutil.copyfile(d/'driftmapR-S07-R1-checkpoint361-008-manifest.json',r/'provenance/checkpoint361-transport-manifest.json')
with zipfile.ZipFile(p) as z:
 print('entries',len(z.namelist()));print(z.namelist()[:12]);names=[n for n in z.namelist() if 'MANIFEST' in n.upper()];print(names[:20])
 for n in names[:1]:print(z.read(n)[:6000].decode())
