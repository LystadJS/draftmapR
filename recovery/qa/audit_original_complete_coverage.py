from pathlib import Path,PurePosixPath
import json,collections
root=Path(__file__).resolve().parents[1]
proofs=[json.loads(p.read_text()) for p in sorted((root/'qa').glob('original-*-verification.json'))]
assert all(p['status']=='passed' for p in proofs)
members=[m for p in proofs for m in p['members']]
def keys(folder):
    return [PurePosixPath(m['receipt_path']).stem for m in members if PurePosixPath(m['receipt_path']).parent.name==folder and m['receipt_path'].endswith('.rds') and not m['receipt_path'].endswith('.manifest.rds')]
cp=keys('checkpoints');dp=keys('draw-plans')
state=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state'
receipts={p.stem for p in (state/'verification-006').glob('*.rds')}
assert len(cp)==len(set(cp))==6475
assert len(dp)==len(set(dp))==len(receipts)==6480
assert set(cp)<set(dp)==receipts
incidents=[m['receipt_path'] for m in members if '/infrastructure-incidents/' in m['receipt_path']]
incident_keys={PurePosixPath(p).name.split('.rds-')[0] for p in incidents}
assert set(dp)-set(cp)==incident_keys and len(incidents)==5
archives=[a['filename'] for p in proofs for a in p['archives']]
assert len(archives)==len(set(archives))==25
extra=[m['receipt_path'] for m in members if PurePosixPath(m['receipt_path']).parent.name=='checkpoints' and not m['receipt_path'].endswith('.rds')]
result={'status':'passed','original_archives':25,'checkpoint_objects':6475,'draw_plan_objects':6480,'draw_plan_keys_equal_latest_input_receipts':True,'checkpoint_keys_subset_of_receipts':True,'inputs_with_incident_records_instead_of_checkpoints':sorted(incident_keys),'incident_paths':incidents,'other_checkpoint_directory_files':extra,'scientific_execution':False,'scope':'Original-run names and immutable bytes verified; matching input keys do not imply equivalence to R1 contents or completed simulations.'}
(root/'qa/original-complete-coverage.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
