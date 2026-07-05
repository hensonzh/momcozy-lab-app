# Flutter UI Parity Automation

This workflow compares legacy Web screenshots with Flutter feature-page goldens.
It is designed for triage first: it generates ranked reports and visual diff
artifacts, then humans decide which differences are product-significant.

## Commands

Generate a report from existing screenshots:

```bash
npm run ui:parity-report
```

Refresh both sides, then generate the report:

```bash
npm run ui:parity-refresh
```

Use as a failing gate:

```bash
MOMCOZY_UI_PARITY_MAX_DIFF_RATIO=0.015 npm run ui:parity-gate
```

## Inputs

Legacy Web screenshots:

```text
test/screenshots/legacy_web/compact_390x844/
```

Flutter screenshots:

```text
flutter_app/test/goldens/feature_pages/
```

The first automated pass covers the compact `390x844` page set:

- Agent Hub
- Status
- Schedule
- Device
- Device manage
- Device user
- W1
- Hospital bag
- IBCLC
- Media viewer
- Pump
- Calibration
- Community

Records and Not Found now remain Flutter-owned route regression goldens only.
They are no longer captured as legacy Web reference pages because the old Web
`/records` mock page and stale 404 screenshot were retired from the active UI
parity baseline.

## Outputs

Reports are written to:

```text
test/reports/ui_parity/compact_390x844/
```

Important files:

- `report.md`: ranked human-readable report.
- `summary.json`: machine-readable metrics.
- `triptychs/*.png`: legacy Web, Flutter, and diff in one image.
- `diffs/*.png`: pixel diff only.

## Environment

```bash
MOMCOZY_UI_PARITY_WARN_RATIO=0.015
MOMCOZY_UI_PARITY_MAX_DIFF_RATIO=0.015
MOMCOZY_UI_PARITY_PIXEL_THRESHOLD=0.12
MOMCOZY_UI_PARITY_FAIL=1
MOMCOZY_UI_PARITY_VIEWPORT=compact_390x844
MOMCOZY_UI_PARITY_LEGACY_DIR=/path/to/legacy
MOMCOZY_UI_PARITY_FLUTTER_DIR=/path/to/flutter
MOMCOZY_UI_PARITY_OUTPUT_DIR=/path/to/report
```

## Review Rules

Treat the report as a queue, not a verdict.

- High diff ratio usually means layout, spacing, copy, or missing controls.
- Low diff ratio can still contain important issues, especially icon state,
  disabled controls, badges, or clickable affordances.
- Some pages intentionally diverge from old screenshot captures when the adopted
  golden standard follows source behavior instead, such as IBCLC keeping its
  consultation composer.

For every accepted fix, update the relevant Flutter golden and run:

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter analyze
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test
```
