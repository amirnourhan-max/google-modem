#!/usr/bin/env python3
"""Export synthetic browser test evidence to the job log and step summary.

Uses no upload service, secrets, write token or production/router data.
Artifact storage quota is not a prerequisite for executing validation.
"""
import base64, hashlib, io, json, os, pathlib, zipfile

root = pathlib.Path('test-results')
if not root.is_dir():
    print('Browser evidence unavailable; inspect the failed validation step.')
    raise SystemExit(0)
files = sorted(p for p in root.iterdir() if p.suffix in ('.png', '.json'))
buffer = io.BytesIO()
with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as archive:
    for p in files:
        archive.write(p, p.name)
data = buffer.getvalue()
print('PM_EVIDENCE_SHA256=' + hashlib.sha256(data).hexdigest())
print('PM_EVIDENCE_COMMIT=' + os.environ.get('GITHUB_SHA', 'local'))
encoded = base64.b64encode(data).decode()
for i in range(0, len(encoded), 1024):
    print('PM_EVIDENCE_BASE64=' + encoded[i:i+1024])
summary = os.environ.get('GITHUB_STEP_SUMMARY')
if summary:
    with open(summary, 'a') as f:
        f.write('### Proxy Monitor browser evidence\n\n')
        f.write('Synthetic native Bootstrap light/dark/RTL screenshots and JSON are preserved in this job log as a SHA256-checked ZIP; no Actions artifact storage or repository-write token is used.\n\n')
        f.write('```json\n' + json.dumps(json.loads((root/'browser-report.json').read_text()), indent=2) + '\n```\n')
