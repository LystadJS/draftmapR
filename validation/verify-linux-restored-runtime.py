"""Run final gates inside the isolated imported runtime against the ext4 restore."""
import hashlib,json,os,struct,subprocess
from pathlib import Path
root=Path('/tmp/restored/rehearsal');support=Path('/rehearsal-output')
extraction=json.loads((root/'restore-extraction-verification.json').read_text())
assert extraction['status']=='passed' and extraction['restored_files']==342417
assert int(Path('/sys/fs/cgroup/memory.max').read_text())==12884901888
quota,period=map(int,Path('/sys/fs/cgroup/cpu.max').read_text().split());assert quota/period==2
assert int(Path('/sys/fs/cgroup/memory.swap.max').read_text())==0
assert os.statvfs('/workspace/scratch').f_flag & os.ST_RDONLY
assert os.path.ismount('/workspace/scratch')
assert os.stat('/workspace/scratch').st_dev==os.stat(root/'scratch').st_dev
assert json.loads((support/'persisted-restore-verification.json').read_text())['status']=='passed'
isolation=json.loads((support/'linux-container-isolation.json').read_text())
assert isolation['network']=='none' and isolation['shm_size']==6442450944 and not isolation['recovery_volume_attached']
def execute(label,args,env=None):
    result=subprocess.run(args,capture_output=True,text=True,env=env)
    (support/(label+'.log')).write_text(result.stdout+'\nSTDERR:\n'+result.stderr)
    assert result.returncode==0,label+' failed; inspect private rehearsal log'
    return result.stdout
inventory=execute('restored-system-packages',['dpkg-query','-W','-f=${binary:Package}\t${Version}\n'])
expected=(support/'repository/validation/2026-10-25/graphics-recovery/system-packages.tsv').read_text()
assert set(inventory.splitlines())==set(expected.splitlines())
env=dict(os.environ,S07_SOURCE_ROOT='/workspace/scratch/837e4400dd1d',PYTHONDONTWRITEBYTECODE='1')
execute('restored-pinned-linux',['sh','/rehearsal-output/repository/validation/verify-pinned-linux.sh'],env)
r='/workspace/scratch/837e4400dd1d/r-runtime/bin/Rscript-local'
execute('restored-graphics',[r,'-e','stopifnot(getRversion() == "4.5.3", capabilities("png"), capabilities("cairo")); png("/rehearsal-output/restored-graphics.png", type="cairo"); plot(1:3, 1:3); dev.off()'])
png=(support/'restored-graphics.png').read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
assert all(x>0 for x in struct.unpack('>II',png[16:24]))
reports=Path('/workspace/scratch/837e4400dd1d/study07-results/S07-R1');digests={}
for name,wanted in [('final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('execution-complete.json','8aa965e96c411dea3fc1253362c1f7bebc45c32888861a32538140cdf68086bd')]:
    digests[name]=hashlib.sha256((reports/name).read_bytes()).hexdigest();assert digests[name]==wanted
audit=json.loads((reports/'final-audit.json').read_text());receipt=json.loads((reports/'execution-complete.json').read_text())
assert audit['status']=='passed' and receipt['independent_audit_passed'] is True
assert audit['panels']==receipt['panels']==6480 and audit['planned_draws']==receipt['draws']==1313520
result=dict(status='passed',restored_files=342417,archive_sha256=extraction['archive_sha256'],filesystem=extraction['filesystem'],restored_runtime='R 4.5.3; exact frozen implementation and numerical runtime validation passed',system_packages='162 packages exactly match archived inventory',graphics_png='passed',completion_receipts=digests,panels=6480,draws=1313520,limits_unchanged=True,network_disabled=True,source_mount_readonly=True,live_recovery_volume_attached=False,study_resumed=False,full_scientific_audits_rerun=False)
(support/'restore-runtime-verification.json').write_text(json.dumps(result,indent=2))
(support/'restore-extraction-verification.json').write_text(json.dumps(extraction,indent=2))
print(json.dumps(result,indent=2))
