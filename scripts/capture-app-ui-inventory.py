#!/usr/bin/env python3
"""Collect fresh screenshots from visual Flutter scenarios, never old baselines."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone

APP = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default=shutil.which('flutter'))
    parser.add_argument('--test', action='append', help='Limit a targeted follow-up capture')
    args = parser.parse_args()
    if not args.flutter:
        parser.error('Pass --flutter or add Flutter to PATH.')
    tests = args.test or [str(p.relative_to(APP)) for p in sorted((APP/'test').rglob('*_test.dart'))
                          if 'matchesGoldenFile' in p.read_text() and 'testWidgets(' in p.read_text()]
    output = APP/'docs/app-ui-inventory'
    overview = output/'00-overview'
    overview.mkdir(parents=True, exist_ok=True)
    record_dir = overview if not args.test else overview/'runs'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S-targeted')
    record_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    if env.get('MOMCOZY_GOLDEN_PRECISION_TOLERANCE'):
        parser.error('Inventory requires strict golden comparison; unset golden tolerance.')
    env.update(MOMCOZY_UI_INVENTORY_DIR=str(output/'raw'), MOMCOZY_UI_INVENTORY_LONG='1')
    command = [args.flutter, 'test', '--no-pub', '--reporter', 'expanded', *tests]
    (record_dir/'capture-command.json').write_text(json.dumps({'command': command, 'tests': tests,
        'note': 'Only visual tests: eagerly installing a widget binding would replace HTTP in IO unit tests.'}, indent=2)+'\n')
    with (record_dir/'capture.log').open('w') as log:
        result = subprocess.run(command, cwd=APP, env=env, stdout=log, stderr=subprocess.STDOUT)
    (record_dir/'capture-result.json').write_text(json.dumps({'exit_code': result.returncode,
        'test_files': len(tests), 'log': 'capture.log'}, indent=2)+'\n')
    print(json.dumps({'exit_code': result.returncode, 'test_files': len(tests), 'log': str(record_dir/'capture.log')}))
    raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
