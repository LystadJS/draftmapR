"""Update human-readable recovery indexes from verified batch receipts."""
from pathlib import Path
import json,csv,re,sys
root=Path(__file__).resolve().parents[1];batch=sys.argv[1]
latest=json.loads((root/f'qa/original-{batch}-verification.json').read_text())
proofs=[json.loads(p.read_text()) for p in sorted((root/'qa').glob('original-*-verification.json'))]
assert all(p['status']=='passed' for p in proofs)
archive_names=[r['filename'] for p in proofs for r in p['archives']]
assert len(archive_names)==len(set(archive_names))
keys=[m['receipt_path'] for p in proofs for m in p['members'] if m['receipt_path'].startswith('checkpoints/') and m['receipt_path'].endswith('.rds') and not m['receipt_path'].endswith('.manifest.rds')]
assert len(keys)==len(set(keys)), 'Repeated checkpoint key needs explicit historical-version review'
with (root/'provenance/RECOVERY_DEPENDENCIES.csv').open(encoding='utf-8-sig',newline='') as f:rows=list(csv.DictReader(f))
missing=[r for r in rows if r['group'].startswith('ancestral_') and r['local_status']!='verified']
size=sum(int(r['bytes']) for r in missing);original_missing=sum(r['group']=='ancestral_original' for r in missing)
with (root/'provenance/MISSING_ANCESTRAL_ARCHIVES.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(missing)
lines=['# Missing ancestral archives','',f'{len(missing)} of the 128 identified ancestral archives remain unrecovered: {original_missing} original and 81 raw-prefix. All 22 R1 archives and {len(archive_names)} original archives are recovered. Preserve exact versions and hashes.']
for group in dict.fromkeys(r['group'] for r in missing):
    lines+=['','## '+group,'']+[f"- `{r['filename']}` — {r['bytes']} bytes; version {r['version']}" for r in missing if r['group']==group]
(root/'provenance/MISSING_ANCESTRAL_ARCHIVES.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
summary={'status':'passed','verified_original_archives':len(archive_names),'distinct_original_checkpoint_objects':len(keys),'missing_ancestral_archives':len(missing),'missing_ancestral_bytes':size,'scientific_execution':False}
(root/'qa/original-input-coverage.json').write_text(json.dumps(summary,indent=2))
names=', '.join('`'+r['filename']+'`' for r in latest['archives'])
count=sum(m['receipt_path'].startswith('checkpoints/') and m['receipt_path'].endswith('.rds') and not m['receipt_path'].endswith('.manifest.rds') for m in latest['members'])
description=f'{names} ({sum(r["bytes"] for r in latest["archives"]):,} bytes total) passed immutable archive SHA-256 identities, complete member inventories, member size/MD5 comparisons and gzip CRC checks. All {len(latest["members"]):,} regular files are preserved unchanged. This batch adds {count} checkpoint objects with no key overlap in the recovered original-run set; cumulative coverage is {len(keys)} distinct original-run checkpoint objects. Fresh per-member SHA-256 is recorded, not represented as supplied by historical receipts. See `qa/original-{batch}-verification.json` and `qa/original-input-coverage.json`. Original and R1 bytes remain separate. No simulations or package tests were rerun.'
path=root/'README.md';text=path.read_text(encoding='utf-8-sig')
current=f'Current recovery status: all four checkpoint deltas, all 22 ancestral R1 archives and {len(archive_names)} original-run archives are verified. The R1 inputs include all 6,480 checkpoint objects, all 6,480 draw plans and nine population objects, with companion manifests. Separately preserved original-run inputs include 6,480 draw plans, {len(keys)} distinct checkpoint objects and nine population objects. There are {len(missing)} ancestral archives still missing ({size:,} bytes): {original_missing} original-run and 81 raw-prefix archives. See `MISSING_ARTIFACTS.md`. Input recovery does not establish completed scientific execution.'
text=re.sub(r'^Current recovery status:.*$',current,text,flags=re.M)
heading=f'## Original-run archives {batch} recovered'
assert heading not in text
text=text.replace('## Most comprehensive later checkpoint identified',heading+'\n\n'+description+'\n\n## Most comprehensive later checkpoint identified')
path.write_text(text,encoding='utf-8')
path=root/'provenance/SOURCES.md';text=path.read_text(encoding='utf-8-sig');text=text.replace('## Fresh verification versus historical evidence\n','## Fresh verification versus historical evidence\n\n'+description+'\n',1);path.write_text(text,encoding='utf-8')
path=root/'MISSING_ARTIFACTS.md';text=path.read_text(encoding='utf-8-sig');start=text.index('Full historical/scientific reconstruction still requires');end=text.index('## Supplemental provenance')
block=f'Full historical/scientific reconstruction still requires {len(missing)} ancestral archives ({size:,} bytes): {original_missing} original-run and 81 raw-prefix. All 22 R1 archives and {len(archive_names)} original-run archives are recovered. Original-run coverage is {len(keys)} distinct checkpoint objects. Raw serials 1–163092 remain missing.\n\nExact filenames, hashes, IDs and versions are in `provenance/MISSING_ANCESTRAL_ARCHIVES.csv` and the readable `.md` checklist.\n\nNext provide these independent original-run archives:\n\n'
block+='\n'.join(f"{i}. `{r['filename']}`" for i,r in enumerate(missing[:3],1))+'\n\nDo not concatenate these independent archives.\n\n'
text=text[:start]+block+text[end:]
text=re.sub(r'all 22 R1 ancestral archives and (?:the first \w+|\d+) original-run archives have been restored',f'all 22 R1 ancestral archives and {len(archive_names)} original-run archives have been restored',text)
text=text.replace('## Already recovered: do not reupload','## Already recovered: do not reupload\n\n- '+names+f' — all {len(latest["members"])} files verified.',1)
path.write_text(text,encoding='utf-8');print(json.dumps(summary,indent=2))

