"""Read-only archive identity audit. Does not authorize scientific execution."""
from pathlib import Path
import argparse
import hashlib
import json
import tarfile

p = argparse.ArgumentParser()
p.add_argument('recovery', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
archive = a.recovery / 'archives/driftmapR-study06-pinned-runtime.tar.gz'
freeze = a.recovery / 'recovered/driftmapR-S07-R1-sources/study07-execution/implementation-freeze.json'
runtime = json.loads(freeze.read_text(encoding='utf-8'))['runtime']
with archive.open('rb') as f:
    sha = hashlib.file_digest(f, 'sha256').hexdigest()
assert sha == 'a61e14e5815a70cd8d70e1600e2583c10d52c0af59475773934a9843dd7caf2d'
assert archive.stat().st_size == 117877231
verified, external = [], []
with tarfile.open(archive) as t:
    members = {m.name: m for m in t.getmembers()}
    def check(name, expected):
        with t.extractfile(members[name]) as f:
            actual = hashlib.file_digest(f, 'md5').hexdigest()
        assert actual == expected, name
        verified.append({'member': name, 'md5': actual})
    for path, md5 in zip(runtime['numeric_files'], runtime['numeric_md5'], strict=True):
        if '/r-runtime/' in path:
            check('r-runtime/' + path.split('/r-runtime/', 1)[1], md5)
        else:
            external.append({'path': path, 'md5': md5, 'in_archive': False})
    prefix = 'r-runtime/lib/R/library/driftmapR/'
    actual_engine = {n[len(prefix):] for n,m in members.items() if n.startswith(prefix) and m.isfile()}
    assert actual_engine == set(runtime['engine_files'])
    for name, md5 in zip(runtime['engine_files'], runtime['engine_md5'], strict=True):
        check(prefix + name, md5)
    versions = {}
    packages = ['driftmapR','ggplot2','clue','testthat','rlang','vctrs','S7','cli','withr','scales','gtable']
    for package, expected in zip(packages, runtime['package_versions'], strict=True):
        text = t.extractfile(f'r-runtime/lib/R/library/{package}/DESCRIPTION').read().decode()
        version = next(line.split(':',1)[1].strip() for line in text.splitlines() if line.startswith('Version:'))
        # R packageVersion() normalizes DESCRIPTION's dash separator to a dot.
        assert version.replace('-', '.') == expected, package
        versions[package] = version
    for item in runtime['python']['files']:
        assert not any(Path(n).name == item['name'] for n in members)
result = {'status':'archive_identity_passed_execution_not_validated', 'archive_sha256':sha,
          'freeze_sha256':hashlib.sha256(freeze.read_bytes()).hexdigest(),
          'verified_files':verified, 'package_versions':versions,
          'required_external_numeric_files':external,'required_python':runtime['python'],
          'required_installation_root':'/workspace/scratch/837e4400dd1d',
          'runtime_executed':False,'study_resumed':False,
          'host_blocker':'Docker Desktop startup failed accessing dockerInference socket; Linux engine unavailable.'}
a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='verified_files'},indent=2))
print('Matched numerical and engine files:',len(verified))
