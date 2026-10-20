from pathlib import Path
import json,hashlib,zipfile
r=Path('driftmapR-recovery');rel='pinned-workspace/study07-r1-operations/resumable-collection-state/';checks=[]
with zipfile.ZipFile(r/'archives/driftmapR-S07-R1-progress-20260922-007a.zip') as z:
 for name in ('chunk-journal.jsonl','panel-journal.jsonl','json-journal.jsonl','compact-cache-005.jsonl'):
  old=z.read(rel+name);new=(r/'recovered/driftmapR-S07-R1-checkpoint464-011'/rel/name).read_bytes()
  checks.append({'journal':name,'rows':len(old.splitlines()),'sha256':hashlib.sha256(old).hexdigest(),'exact_prefix_of_464':new.startswith(old)})
result={'status':'passed' if all(x['exact_prefix_of_464'] for x in checks) else 'requires_review','checks':checks,'scientific_execution':False}
(r/'qa/checkpoint361-to-464-lineage.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result,indent=2))
