from pathlib import Path,PurePosixPath
import json
root=Path(__file__).resolve().parents[1]
proofs=[json.loads((root/f'qa/r1-{i:02d}-verification.json').read_text()) for i in range(1,4)]
assert all(p['status']=='passed' for p in proofs)
keys=[k for p in proofs for k in p['checkpoint_keys']]
assert len(keys)==len(set(keys))==6480
state=root/'recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state'
receipts={p.stem for p in (state/'verification-006').glob('*.rds')}
assert set(keys)==receipts
draws=[]
for p in proofs:
    for m in p['members']:
        path=PurePosixPath(m['original_path'])
        if path.parent.name=='draw-plans' and path.name.endswith('.rds') and not path.name.endswith('.manifest.rds'):draws.append(path.stem)
assert len(draws)==len(set(draws))==6480 and set(draws)==receipts
cache={r['key'] for r in map(json.loads,(state/'compact-cache-005.jsonl').read_text().splitlines())}
assert len(cache)==3916 and cache<=receipts
summary={'status':'passed','r1_ancestral_archives_recovered':sum(len(p['archives']) for p in proofs),'unique_checkpoint_objects':len(keys),'unique_draw_plan_objects':len(draws),'checkpoint_and_draw_plan_keysets_equal_latest_6480_input_receipts':True,'cache_ledger_bound_checkpoints':sum(p['checkpoint_objects_bound_to_latest_cache_ledger'] for p in proofs),'recovered_checkpoint_inputs_without_compact_cache':len(receipts-cache),'scientific_execution':False,'scope':'Complete R1 checkpoint/draw-plan input coverage, not completed scientific work; original archives and earlier raw outputs remain missing.'}
assert summary['cache_ledger_bound_checkpoints']==3916
(root/'qa/r1-input-coverage.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
