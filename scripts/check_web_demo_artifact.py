#!/usr/bin/env python3
"""Reject accidental main entrypoints, remote dependencies and leaked defines."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
main = root / 'main.dart.js'
index = root / 'index.html'
bootstrap = root / 'flutter_bootstrap.js'
if not all(path.is_file() for path in (main, index, bootstrap)):
    raise SystemExit('Missing Web demo entrypoint bundle')
html = index.read_text()
js = main.read_text()
loader = bootstrap.read_text()
if 'Web Demo' not in html or 'WEB DEMO' not in js:
    raise SystemExit('Wrong Web entrypoint (did you build lib/main.dart?)')
if 'IBCLC Workspace' in html:
    raise SystemExit('Legacy workspace metadata in Web demo')
if "connect-src 'self'" not in html or "form-action 'none'" not in html:
    raise SystemExit('Static demo must block cross-origin API calls and form submissions')
if '"useLocalCanvasKit":true' not in loader or 'fontFallbackBaseUrl:' not in loader or not loader.rstrip().endswith('}});'):
    raise SystemExit('Web renderer must use the bundled CanvasKit and no service worker')
for label in ('MOMCOZY_API_TOKEN', 'MOMCOZY_REFRESH_TOKEN'):
    if label in js:
        raise SystemExit(f'Sensitive define label {label} found in public bundle')
if (root / '404.html').read_text() != html:
    raise SystemExit('Missing SPA fallback for direct links')
if (root / 'version.json').exists():
    raise SystemExit('Public demo must not expose the mobile build number')
if (root / 'flutter_service_worker.js').exists():
    raise SystemExit('Web demo must not install a persistent service worker')
if (root / 'assets/assets/certificates').exists():
    raise SystemExit('Internal certificate included in public demo')
for font in ('roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2', 'notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYkldv7JjxkkgFsFSSOPMOkySAZ73y9ViAt3acb8NexQ2w.119.woff2'):
    if not (root / 'demo-fonts' / font).is_file():
        raise SystemExit(f'Missing local font fallback: {font}')
print(f'Validated fictional Web demo artifact: {root}')
