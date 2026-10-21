from pathlib import Path
import json,shutil
r=Path(__file__).resolve().parents[1]
receipt=r.parent/'driftmapR-recovery-20261021-live002-incremental.verification.json'
d=json.loads(receipt.read_text());assert d['all_member_hashes']=='passed'
shutil.copyfile(receipt,r/'provenance/live002-incremental-receipt.json')
p=r/'qa/checkpoint-storage-status.json';s=json.loads(p.read_text());s.update(status='verified_live002_incremental_raw_journal_complete',incremental_verification='passed',github_recovery_commit='8a1c5c9');p.write_text(json.dumps(s,indent=2))
p=r/'README.md';p.write_text(p.read_text(encoding='utf-8')+'\nLive002 incremental passed member SHA256 and CRC verification: '+str(d['verified_files'])+' files, '+str(d['bytes'])+' bytes. External completion receipt: provenance/live002-incremental-receipt.json. Immutable ZIP construction-time status predates this completion record.\n',encoding='utf-8')
