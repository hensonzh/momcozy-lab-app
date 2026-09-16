#!/usr/bin/env python3
"""Report additions/changes to Session A's existing screenshot inventory.

Read-only by default; --record updates only this refactor task's observation
snapshot. This neither captures screens nor marks any page design complete.
"""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / 'docs/app-ui-inventory'
SNAPSHOT = ROOT / 'docs/ui-refactor/inventory-observed.json'


def observe():
    rows = json.loads((INVENTORY / 'manifest.json').read_text())
    entries = {}
    for row in rows:
        if row['id'].startswith('workbench-excluded/'):
            continue
        digest = hashlib.sha256(json.dumps(row, sort_keys=True).encode())
        # Include image bytes so replacing a capture under its stable ID is
        # detected even when its manifest entry does not change.
        paths = {row['image'], row.get('viewport', row['image'])}
        for variant in row.get('variants', []):
            if variant.get('metadata'):
                paths.add(variant['metadata'].removesuffix('.json'))
        for relative in sorted(paths):
            path = INVENTORY / relative
            digest.update(relative.encode())
            if not path.is_file():
                raise FileNotFoundError(f'Incomplete inventory capture: {path}')
            digest.update(path.read_bytes())
        entries[row['id']] = digest.hexdigest()
    return entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    entries = observe()
    previous = json.loads(SNAPSHOT.read_text())['entries'] if SNAPSHOT.exists() else {}
    report = {
        'observed_states': len(entries),
        'added': sorted(entries.keys() - previous.keys()),
        'changed': sorted(k for k in entries.keys() & previous.keys() if entries[k] != previous[k]),
        'removed': sorted(previous.keys() - entries.keys()),
        'note': 'Screenshot state counts are not page counts or completion evidence.',
    }
    if args.record:
        SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
        temporary = SNAPSHOT.with_suffix('.tmp')
        temporary.write_text(json.dumps({
            'observed_at': datetime.now(timezone.utc).isoformat(),
            'entries': entries,
        }, ensure_ascii=False, indent=2) + '\n')
        temporary.replace(SNAPSHOT)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
