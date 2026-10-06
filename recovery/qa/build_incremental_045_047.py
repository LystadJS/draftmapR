from pathlib import Path
import json,hashlib,zipfile,shutil
root=Path(__file__).resolve().parents[1]
base=root.parent/'driftmapR-recovery-20261005-raw-042-044-integrated.zip'
out=root.parent/'driftmapR-recovery-20261006-raw-045-047-incremental.zip'
proof=json.loads((root/'qa/raw-045-047-verification.json').read_text());assert proof['status']=='passed'
base_receipt=json.loads(base.with_suffix('.verification.json').read_text())
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
assert sha(base)==base_receipt['sha256']
files={p.relative_to(root).as_posix():p for folder in (root,root/'qa',root/'provenance') for p in folder.iterdir() if p.is_file() and p.name!='FILE_MANIFEST.json'}
for r in proof['archives']:
 p=root/'archives'/r['filename'];assert sha(p)==r['sha256'];files[p.relative_to(root).as_posix()]=p
for r in proof['members']:
 p=root/r['path'];assert sha(p)==r['sha256'];files[r['path']]=p
assert shutil.disk_usage(out.parent).free>sum(p.stat().st_size for p in files.values())+1024**3
manifest={'scope':'Incremental recovery bundle; requires the exact base checkpoint. Overlay enclosed driftmapR-recovery files on a copy of the extracted base; retained base files remain unchanged. This is not standalone.','required_base':base_receipt,'scientific_execution':False,'files':[]}
with zipfile.ZipFile(out,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as z:
 for rel,p in files.items():
  data=p.read_bytes();manifest['files'].append({'path':rel,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()});z.writestr('driftmapR-recovery/'+rel,data,compress_type=zipfile.ZIP_STORED if rel.endswith(('.zip','.tar.gz')) else zipfile.ZIP_DEFLATED)
 z.writestr('INCREMENTAL-MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(out) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(files)+1
 for r in manifest['files']:
  data=z.read('driftmapR-recovery/'+r['path']);assert len(data)==r['bytes'] and hashlib.sha256(data).hexdigest()==r['sha256']
result={'archive':out.name,'bytes':out.stat().st_size,'sha256':sha(out),'verified_files':len(files),'all_member_hashes':'passed','zip_crc':'passed on every member read','required_base':base.name,'required_base_sha256':base_receipt['sha256'],'standalone':False,'scientific_execution':False}
out.with_suffix('.verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
