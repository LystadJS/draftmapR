from pathlib import Path
import json
root=Path('driftmapR-recovery')
coverage=root/'qa/original-input-coverage.json'
x=json.loads(coverage.read_text());x['distinct_original_checkpoint_objects']=6475;x['infrastructure_incident_records']=5;coverage.write_text(json.dumps(x,indent=2))
note='All 25 original-run archives are recovered. Their 6,480 draw-plan keys match the latest input receipts; 6,475 have original checkpoint objects. Five inputs have infrastructure-incident records instead: s07_sparse_m12-0018, -0020, -0030, -0032 and -0037. These five records are preserved separately and are not counted as checkpoint objects. No replacement checkpoint filenames are established by this evidence. Complete R1 inputs remain a separate lineage. See `qa/original-complete-coverage.json`.'
for name in ['README.md','MISSING_ARTIFACTS.md','provenance/SOURCES.md']:
    p=root/name;s=p.read_text(encoding='utf-8-sig')
    s=s.replace('6480 distinct original-run checkpoint objects','6475 distinct original-run checkpoint objects').replace('6480 distinct checkpoint objects','6475 distinct checkpoint objects').replace('6015 checkpoint objects','6010 checkpoint objects')
    if name=='README.md':s=s.replace('## Original-run archives 022-025 recovered','## Original-run archives 022-025 recovered\n\n'+note)
    elif name=='MISSING_ARTIFACTS.md':s=s.replace('## Supplemental provenance','## Original-run coverage limitation\n\n'+note+'\n\n## Supplemental provenance')
    else:s+='\n## Complete original-run inventory\n\n'+note+'\n'
    p.write_text(s,encoding='utf-8')

