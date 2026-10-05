from pathlib import Path
import json,csv,re,itertools,sys
root=Path(__file__).resolve().parents[1]
batch=sys.argv[1]
latest=json.loads((root/f'qa/raw-{batch}-verification.json').read_text())
proofs=[json.loads(f.read_text()) for f in sorted((root/'qa').glob('raw-*-verification.json'))]
assert all(x['status']=='passed' for x in proofs)
p={k:[r for x in proofs for r in x[k]] for k in ('archives','members','other_archive_versions')}
assert len({a['filename'] for a in p['archives']})==len(p['archives'])
assert len({m['receipt_path'] for m in p['members'] if m['latest_journal_match']})==sum(m['latest_journal_match'] for m in p['members'])
rows=list(csv.DictReader((root/'provenance/RECOVERY_DEPENDENCIES.csv').open(encoding='utf-8-sig')))
missing=[r for r in rows if r['group'].startswith('ancestral_') and r['local_status']!='verified']
assert all(r['group']=='ancestral_raw_prefix' for r in missing)
with (root/'provenance/MISSING_ANCESTRAL_ARCHIVES.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(missing)
size=sum(int(r['bytes']) for r in missing)
(root/'provenance/MISSING_ANCESTRAL_ARCHIVES.md').write_text('# Missing ancestral archives\n\n'+f'{len(missing)} raw-prefix archives remain ({size:,} bytes). All 25 original-run and 22 R1 archives are recovered.\n\n'+'\n'.join(f"- `{r['filename']}` — {r['bytes']} bytes; version {r['version']}" for r in missing)+'\n',encoding='utf-8')
matched={m['serial'] for m in p['members'] if m['latest_journal_match']}
absent=sorted(set(range(1,163093))-matched)
ranges=[]
for _,g in itertools.groupby(enumerate(absent),lambda x:x[1]-x[0]):
 values=[x[1] for x in g];ranges.append([values[0],values[-1]])
summary={'status':'passed','verified_raw_archives':len(p['archives']),'preserved_raw_files':len(p['members']),'latest_journal_matched_prefix_files':len(matched),'archive_versions_differing_from_latest_journal':len(p['other_archive_versions']),'missing_prefix_files':len(absent),'missing_serial_ranges':ranges,'missing_ancestral_archives':len(missing),'missing_ancestral_bytes':size,'scientific_execution':False}
(root/'qa/raw-prefix-coverage.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
desc=f"Cumulative raw-output recovery after batch {batch}: {len(p['members']):,} files preserved; {len(matched):,} match the latest chunk journal. {len(p['other_archive_versions'])} additional archived versions differ from the latest journal and remain separately preserved; they do not fill those current-state gaps. Every historical restoration-receipt member matched size/MD5. Full archive SHA256, member counts/bytes and gzip CRC passed. Fresh per-member SHA256 recorded. See `qa/raw-{batch}-verification.json` and `qa/raw-prefix-coverage.json`. No scientific execution or package tests were performed."
path=root/'README.md';s=path.read_text(encoding='utf-8-sig');s=re.sub(r'There are \d+ ancestral (?:raw-prefix )?archives still missing .*?See `MISSING_ARTIFACTS.md`\.',f'There are {len(missing)} ancestral raw-prefix archives still missing ({size:,} bytes). See `MISSING_ARTIFACTS.md`.',s);s=s.replace('## Most comprehensive later checkpoint identified',f'## Raw-output batch {batch} recovered\n\n'+desc+'\n\n## Most comprehensive later checkpoint identified',1);path.write_text(s,encoding='utf-8')
path=root/'MISSING_ARTIFACTS.md';s=path.read_text(encoding='utf-8-sig');a=s.index('Full historical/scientific reconstruction still requires');b=s.index('## Original-run coverage limitation')
s=s[:a]+f'Full historical/scientific reconstruction still requires {len(missing)} raw-prefix archives ({size:,} bytes). All 25 original and 22 R1 archives are recovered. {len(matched):,} of the previously missing 163,092 raw journal entries now match restored bytes; {len(absent):,} remain missing. Archived versions differing from the current journal remain separate. Exact serial gaps are in `qa/raw-prefix-coverage.json`.\n\nNext provide these independent archives:\n\n'+'\n'.join(f"- `{r['filename']}`" for r in missing[:3])+'\n\nFull filenames and hashes: `provenance/MISSING_ANCESTRAL_ARCHIVES.csv`.\n\n'+s[b:]
s=s.replace('## Already recovered: do not reupload','## Already recovered: do not reupload\n\n'+desc,1);path.write_text(s,encoding='utf-8')
path=root/'provenance/SOURCES.md';s=path.read_text(encoding='utf-8-sig');s+=f'\n## Raw-output batch {batch} recovered\n\n'+desc+'\n';path.write_text(s,encoding='utf-8')
print(json.dumps(summary,indent=2))
