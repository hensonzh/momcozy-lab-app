#!/usr/bin/env python3
"""Verify evidence integrity. Passing does NOT assert complete UI coverage."""
from pathlib import Path
import hashlib
import json
import math
import re
import struct

APP = Path(__file__).resolve().parents[1]
OUT = APP / 'docs/app-ui-inventory'


def main():
    states = json.loads((OUT / 'manifest.json').read_text())
    errors = []
    ids = set()
    checked_pngs = set()
    metadata_files = set()
    long_bounds_checked = 0
    for row in states:
        if row['id'] in ids:
            errors.append(f"Duplicate state: {row['id']}")
        ids.add(row['id'])
        for key in ['image', 'viewport', 'metadata']:
            path = OUT / row[key]
            if not path.is_file():
                errors.append(f'Missing {key}: {path}')
            elif path.suffix == '.png':
                checked_pngs.add(path)
        for variant in row['variants']:
            image = OUT / 'raw' / variant['source']
            meta_file = OUT / variant['metadata']
            if not image.is_file() or not meta_file.is_file():
                errors.append(f"Missing variant: {variant['source']}")
                continue
            checked_pngs.add(image)
            metadata_files.add(meta_file)
            meta = json.loads(meta_file.read_text())
            if hashlib.sha256(image.read_bytes()).hexdigest() != meta['sha256']:
                errors.append(f'Variant hash mismatch: {image}')
            long = meta.get('long_capture', {})
            if meta.get('needs_long_capture') and long.get('status') == 'no-active-vertical-overflow':
                errors.append(f'Overflow incorrectly reported as a non-scrolling page: {meta_file}')
            if long.get('status') == 'complete-measured-scroll-stitch':
                long_bounds_checked += 1
                long_path = Path(long['file'])
                if not long_path.is_absolute():
                    long_path = APP / long_path
                if not long_path.is_file():
                    errors.append(f'Missing measured long image: {long_path}')
                    continue
                checked_pngs.add(long_path)
                offsets = long['offsets']
                bounds = long['scroll_bounds']
                if not offsets or abs(offsets[0]) > .5 or any(b < a for a, b in zip(offsets, offsets[1:])):
                    errors.append(f'Invalid scroll coverage: {meta_file}')
                elif abs(long['content_height'] - bounds[3] - offsets[-1]) > 1:
                    errors.append(f'Missing or repeated long content: {meta_file}')
                dims = struct.unpack('>II', long_path.read_bytes()[16:24])
                expected_height = math.ceil(meta['height'] - bounds[3] + long['content_height'])
                if dims[0] != meta['width'] or abs(dims[1] - expected_height) > 1:
                    errors.append(f'Long image dimensions disagree with measured content: {long_path}')
        if row['normal_entry_verified'] and not row.get('journey'):
            errors.append(f"Missing verified journey evidence: {row['id']}")
        for file in row['production_widget_files']:
            if not (APP / file).is_file():
                errors.append(f'Missing production source: {file}')
    for path in checked_pngs:
        header = path.read_bytes()[:24]
        if header[:8] != b'\x89PNG\r\n\x1a\n' or len(header) < 24:
            errors.append(f'Invalid PNG: {path}')
        elif min(struct.unpack('>II', header[16:24])) <= 0:
            errors.append(f'Empty PNG dimensions: {path}')
    native_rows = []
    for manifest in ['native/media-manifest.json', 'native/resource-manifest.json', 'native/permission-manifest.json', 'native/device-manifest.json']:
        if (OUT/manifest).exists(): native_rows.extend(json.loads((OUT/manifest).read_text()))
    for row in native_rows:
        if hashlib.sha256((OUT / row['image']).read_bytes()).hexdigest() != row['sha256']:
            errors.append(f"Native hash mismatch: {row['image']}")
        if row.get('xml_sha256') and hashlib.sha256((OUT/row['xml']).read_bytes()).hexdigest() != row['xml_sha256']:
            errors.append(f"Native UI hierarchy hash mismatch: {row['xml']}")
        if row.get('source_sha256') and hashlib.sha256((APP/row['source']).read_bytes()).hexdigest() != row['source_sha256']:
            errors.append(f"Native source changed since capture: {row['source']}")
        if row.get('full_document_sha256') and hashlib.sha256((OUT/row['full_document']).read_bytes()).hexdigest() != row['full_document_sha256']:
            errors.append(f"Native long image hash mismatch: {row['id']}")
        if row.get('scroll_metadata'):
            m = json.loads((OUT / row['scroll_metadata']).read_text())
            if m['first_visible_top'] > .5 or m['last_visible_bottom'] < m['document_height'] - .5:
                errors.append(f"Incomplete native document: {row['id']}")
            offsets = m['pixel_offsets']
            if not offsets or abs(offsets[0]) > .5 or any(b < a for a, b in zip(offsets, offsets[1:])):
                errors.append(f"Invalid native scroll offsets: {row['id']}")
            width, height = struct.unpack('>II', (OUT/row['image']).read_bytes()[16:24])
            long_width, long_height = struct.unpack('>II', (OUT/row['full_document']).read_bytes()[16:24])
            expected = height - m['viewport_bounds'][3] + m['stitched_content_height']
            if long_width != width or abs(long_height - math.ceil(expected)) > 1:
                errors.append(f"Native long dimensions disagree with measured content: {row['id']}")
    links_checked = 0
    readmes = [OUT/'README.md', OUT/'00-overview/VERIFIED-JOURNEYS.md', OUT/'native/README.md']
    readmes += [OUT/row['id']/'README.md' for row in states]
    for path in readmes:
        if not path.is_file():
            errors.append(f'Missing README: {path}')
            continue
        for link in re.findall(r'\]\(([^)]+)\)', path.read_text()):
            if re.match(r'\w+://', link) or link.startswith('#'):
                continue
            target = (path.parent / link.split('#')[0]).resolve()
            links_checked += 1
            if not target.exists():
                errors.append(f'Broken link in {path.relative_to(OUT)}: {link}')
    for group in OUT.iterdir():
        if not group.is_dir() or not re.match(r'(?:\d\d-|workbench-)', group.name) or group.name == '00-overview':
            continue
        for image in group.glob('*/default.png'):
            state_id = str(image.parent.relative_to(OUT))
            if state_id not in ids:
                errors.append(f'Unindexed generated state: {state_id}')
    journeys = json.loads((OUT/'00-overview/verified-journeys.json').read_text())
    for edge in journeys:
        if edge['to'] not in ids or (edge['from'] is not None and edge['from'] not in ids):
            errors.append(f"Dangling journey edge: {edge['source']}")
    report = {
        'artifact_integrity': 'PASS' if not errors else 'FAIL',
        'goal_completion': 'NOT_PROVEN',
        'scope': 'file integrity, PNG headers, recorded viewport hashes, measured scroll coverage, links, native document bounds and journey references only',
        'states': len(states), 'pngs_checked': len(checked_pngs),
        'metadata_hashes_checked': len(metadata_files), 'links_checked': links_checked,
        'long_bounds_checked': long_bounds_checked,
        'verified_route_states': sum(s['normal_entry_verified'] for s in states),
        'errors': errors,
    }
    (OUT/'00-overview/artifact-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(report, ensure_ascii=False))
    raise SystemExit(bool(errors))


if __name__ == '__main__':
    main()
