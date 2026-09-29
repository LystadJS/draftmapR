from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
source=root/'recovered/driftmapR-S07-R1-sources/study07-specification/vendor/study06-specification/vendor/driftmapR'
working=root/'driftmapR'
def inv(base):
    return {p.relative_to(base).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in base.rglob('*') if p.is_file()}
a,b=inv(source),inv(working)
result={'source_files':len(a),'working_files':len(b),'added':sorted(a.keys()-b.keys()),'removed':sorted(b.keys()-a.keys()),'changed':[k for k in a.keys()&b.keys() if a[k]!=b[k]],'identical':a==b}
(root/'qa/r1-package-comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
