"""Explicitly resume an inspected process only after capacity has recovered."""
import json, os, shutil, sys, uuid
from pathlib import Path
ops=Path('/workspace/scratch/837e4400dd1d/study07-r1-operations')
state=json.loads((ops/'execution-process.json').read_text())
token,pid=sys.argv[1],int(sys.argv[2])
if state['supervisor_token']!=token or state['pid']!=pid:
    raise RuntimeError('Process ownership differs')
if state['child_state']!='paused_for_capacity':
    raise RuntimeError('Expected a capacity-paused process')
if min(shutil.disk_usage('/lower').free,shutil.disk_usage('/upper').free)<4*1024**3:
    raise RuntimeError('Require 4 GiB free before explicitly resuming')
request=ops/'resume-execution-request.json'
if request.exists():raise RuntimeError('Pending resume request already exists')
temporary=ops/('.resume-'+uuid.uuid4().hex)
with temporary.open('x') as f:
    json.dump(dict(action='resume',supervisor_token=token,child_pid=pid),f)
    f.flush();os.fsync(f.fileno())
os.replace(temporary,request)
fd=os.open(ops,os.O_DIRECTORY);os.fsync(fd);os.close(fd)
print('Explicit resume request submitted; supervisor must recheck guards')
