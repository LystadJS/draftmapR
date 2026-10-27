"""Validate the isolated archive restore without resuming scientific execution."""
import hashlib,json,struct,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]);support=Path(sys.argv[2]);container='driftmapr-isolated-restore-20261026'
extraction=json.loads((root/'restore-extraction-verification.json').read_text())
assert extraction['status']=='passed' and extraction['restored_files']==342417
state=json.loads(subprocess.check_output(['docker','inspect',container]))[0];limits=state['HostConfig']
assert limits['Memory']==limits['MemorySwap']==12884901888 and limits['NanoCpus']==2000000000 and limits['ShmSize']==6442450944
assert limits['NetworkMode']=='none' and limits['ReadonlyRootfs']
assert not any(m['Type']=='volume' for m in state['Mounts'])
assert next(m for m in state['Mounts'] if m['Destination']=='/workspace/scratch')['RW'] is False
def execute(label,args):
    result=subprocess.run(['docker','exec',container]+args,capture_output=True,text=True)
    (support/(label+'.log')).write_text(result.stdout+'\nSTDERR:\n'+result.stderr)
    assert result.returncode==0,label+' failed; inspect private rehearsal log'
    return result.stdout
inventory=execute('system-packages',['dpkg-query','-W','-f=${binary:Package}\t${Version}\n'])
expected=(support/'repository/validation/2026-10-25/graphics-recovery/system-packages.tsv').read_text()
assert set(inventory.splitlines())==set(expected.splitlines()),'System package inventory differs'
execute('pinned-linux',['env','S07_SOURCE_ROOT=/workspace/scratch/837e4400dd1d','sh','/rehearsal-output/repository/validation/verify-pinned-linux.sh'])
r='/workspace/scratch/837e4400dd1d/r-runtime/bin/Rscript-local'
execute('graphics-probe',[r,'-e','stopifnot(getRversion() == "4.5.3", capabilities("png"), capabilities("cairo")); png("/rehearsal-output/graphics-probe.png", type="cairo"); plot(1:3, 1:3); dev.off(); cat(R.version.string, "\\n")'])
png=(support/'graphics-probe.png').read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
assert all(x>0 for x in struct.unpack('>II',png[16:24]))
reports=root/'scratch/837e4400dd1d/study07-results/S07-R1'
digests={}
for name,wanted in [('final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-final-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('recovery-audit.json','901b02fd5c348448a091dccd0862c7e87e827f3487e7b3c79becd2336cdc2043'),('execution-complete.json','8aa965e96c411dea3fc1253362c1f7bebc45c32888861a32538140cdf68086bd')]:
    digests[name]=hashlib.sha256((reports/name).read_bytes()).hexdigest();assert digests[name]==wanted
audit=json.loads((reports/'final-audit.json').read_text());receipt=json.loads((reports/'execution-complete.json').read_text())
assert audit['status']=='passed' and receipt['independent_audit_passed'] is True
assert audit['panels']==receipt['panels']==6480 and audit['planned_draws']==receipt['draws']==1313520
git=['git','-c','safe.directory='+str(support/'repository'),'-C',str(support/'repository')]
subprocess.run(git+['fsck','--full'],check=True,capture_output=True)
revision=subprocess.check_output(git+['rev-parse','HEAD'],text=True).strip();assert revision=='4a02e291749f7c62b937c01962f360682c0643e0'
result=dict(status='passed',restored_files=extraction['restored_files'],archive_sha256=extraction['archive_sha256'],restored_runtime='R 4.5.3, exact frozen implementation and numerical runtime validation passed',system_package_inventory='exact match to archived graphics-recovery inventory',graphics_png='passed',completion_receipts=digests,panels=6480,draws=1313520,repository_revision=revision,git_fsck='passed',limits_unchanged=True,network_disabled=True,source_mount_readonly=True,live_recovery_volume_attached=False,study_resumed=False,full_scientific_audits_rerun=False)
(support/'restore-runtime-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
