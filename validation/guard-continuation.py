"""Capacity supervision for the recovered immutable collector; never auto-resumes."""
import importlib.util, os, signal, shutil, sys
from pathlib import Path
root=Path('/workspace/scratch/837e4400dd1d')
ops=root/'study07-r1-operations'
spec=importlib.util.spec_from_file_location('resume',ops/'execute-resume.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
run=root/'study07-results/S07-R1'
def capacity():
    # The Docker virtual disk reports virtual capacity, not host physical headroom.
    snapshot=m.raw_allocation_guard(0,reserve_bytes=3*m.GIB)
    snapshot['host_free_bytes']=shutil.disk_usage('/lower').free
    snapshot['output_free_bytes']=shutil.disk_usage(run).free
    return snapshot
mode=sys.argv[1]
if mode=='partial':
    driver=Path('/validation/validate-partial.R');args=[]
elif mode=='collect':
    if not (ops/'partial-validation-20261021.json').exists():
        raise RuntimeError('Partial validation receipt required')
    import json
    receipt=json.loads((ops/'partial-validation-20261021.json').read_text())
    if receipt['status']!='passed' or receipt['committed_panels']!=3916:
        raise RuntimeError('Partial validation did not pass')
    driver=ops/'resume-collection-prefix-006.R'
    args=['reserved',root/'study07-results/S07-D1',run,
          ops/'resumable-collection-state',run/'csv-chunks-20260921192657143845-45-1',
          ops/'PUBLICATION-INDEX.json','/workspace/scratch/1e9a01af2c37/final-preservation',
          ops/'launch-006/launch-review.json']
else:raise ValueError(mode)
os.environ['PYTHONDONTWRITEBYTECODE']='1'
os.environ['S07_COMPRESSION_ROUTE_ROOT_005']='/root/.codex/tmp/s07r1-compression-006'
files=[driver,Path(__file__),ops/'execute-resume.py',ops/'resumable-collect-prefix-005.R',ops/'resumable-collect.R']
hashes={str(p):m.sha256(p) for p in files}
def guarded_capacity():
    for p,h in hashes.items():
        if m.sha256(p)!=h:raise RuntimeError('Operational code changed: '+p)
    return capacity()
# No RAM spill: recovered lower files are already on durable disk. Relocating
# them into tmpfs would consume memory without releasing any host disk space.
s=m.ResumeSupervisor(ops,run,[root/'r-runtime/bin/Rscript-local',driver,*args],
    guarded_capacity,code_hashes=hashes,minimum_disk_bytes=3*m.GIB,interval=5,
    disk_free=lambda:min(shutil.disk_usage('/lower').free,shutil.disk_usage(run).free),
    phase_file=ops/'resumable-collection-state/driver-status.json')
def pause(number,frame):s.external_pause_requested='Received signal '+str(number)
signal.signal(signal.SIGTERM,pause);signal.signal(signal.SIGINT,pause)
sys.exit(s.run_to_terminal())
