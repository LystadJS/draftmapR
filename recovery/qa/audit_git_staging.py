from pathlib import Path
import subprocess,hashlib,json,re
root=Path(__file__).resolve().parents[1];repo=root.parent/'driftmapR-git'
records=subprocess.check_output(['git','-C',str(repo),'ls-files','-s','-z']).split(b'\0')
indexed={r.split(b'\t',1)[1].decode():r.split()[1].decode() for r in records if r}
source={p.relative_to(root/'driftmapR').as_posix():p for p in (root/'driftmapR').rglob('*') if p.is_file()}
assert len(source)==188
missing=[];different=[]
for name,path in source.items():
    data=path.read_bytes();expected=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    if 'driftmapR/'+name not in indexed:missing.append(name)
    elif indexed['driftmapR/'+name]!=expected:different.append(name)
secret_patterns=re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----')
suspect=[];large=[]
for name in indexed:
    path=repo/name
    if path.stat().st_size>=100*1024*1024:large.append(name)
    if path.suffix in ('.zip','.pdf','.rds'):continue
    if secret_patterns.search(path.read_bytes()):suspect.append(name)
result={'package_expected_files':len(source),'missing_package_paths':missing,'different_package_blobs':different,'credential_pattern_files':suspect,'files_at_least_100_MiB':large,'tracked_files':len(indexed),'scope':'Staged package blob identity and basic publication hygiene; not scientific or package execution.'}
print(json.dumps(result,indent=2))
(root/'qa/git-staging-audit.json').write_text(json.dumps(result,indent=2))
assert not missing and not different and not suspect and not large
