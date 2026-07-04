# Flutter UI Component Parity Plan

> Status: execution plan v0.1  
> Date: 2026-07-04  
> Branch: `feat/test2`  
> Scope: component-level visual parity between legacy Web and Flutter for the compact `390x844` baseline first.

## 1. Goal

The current page-level parity workflow has reduced simple layout drift. The remaining visual gap is now mostly component-level:

- icon family and stroke differences,
- chart painter details,
- card material, gradient, shadow, and radius differences,
- internal text layout and badge treatment,
- product image clipping and fixed bottom bar rendering,
- modal and blurred background rendering.

This plan moves the work from page-offset tuning to widget-test-driven component repainting.

## 2. Source Of Truth

Primary references:

| Reference | Purpose |
|---|---|
| `doc/legacy-web-ui-ux-golden-standard.md` | Product UI/UX contract. |
| `test/screenshots/legacy_web/compact_390x844/*.png` | Legacy page-level visual reference. |
| `test/reports/ui_parity/compact_390x844/report.md` | Ranked page-level diff queue. |
| `test/reports/ui_parity/compact_390x844/triptychs/*.png` | Human review artifact for each page. |
| Legacy source under `src/` | Exact layout, copy, colors, icons, and behavior reference. |
| Flutter source under `flutter_app/lib/` | Implementation under migration. |

Flutter page goldens remain current snapshots, not the source of truth.

## 3. Execution Loop

Every component-level change follows this loop:

1. Select the highest-ranked page or the highest-diff component inside that page.
2. Add or update a focused widget/golden test for the component or component state.
3. Repaint the component against the legacy Web reference.
4. Run the focused Flutter test.
5. Update the page golden for compact `390x844`.
6. Run `npm run ui:parity-report`.
7. Keep the change only if the page diff decreases and no previously OK page regresses meaningfully.
8. Run self-checks.
9. Commit one component or tightly-related component group.

Self-check commands:

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter analyze

cd ..
git diff --check
npm run ui:parity-report
```

## 4. Test Strategy

### 4.1 Component Golden Tests

Add component-level tests under:

```text
flutter_app/test/features/app_pages/component_parity/
```

Recommended files:

| Test file | Scope |
|---|---|
| `status_component_parity_golden_test.dart` | Status identity cards, module cards, trend card/painter. |
| `records_component_parity_golden_test.dart` | Records dashboard, trend chart, milk rows. |
| `hospital_bag_component_parity_golden_test.dart` | Product rows, section headers, fixed checkout footer. |
| `schedule_component_parity_golden_test.dart` | Week strip, plan summary, Agent context card, empty/task blocks. |
| `pump_component_parity_golden_test.dart` | Calibration prompt modal, pump control groups, blurred backdrop. |
| `w1_component_parity_golden_test.dart` | Hero, product summary, selling point rows. |
| `device_component_parity_golden_test.dart` | Device header, W1 banner, deck cards, subpage headers. |
| `agent_component_parity_golden_test.dart` | Agent greeting, composer, history bubbles. |

Use compact component fixtures first. Add `360x800` and `430x932` only when a component is responsive or previously broke on small/wide mobile.

### 4.2 Widget Behavior Tests

For every component that is interactive, pair the golden with behavior assertions:

| Component type | Required widget assertions |
|---|---|
| Tabs / segmented controls | selected state, disabled state, tap target route/state change. |
| Buttons | visible enabled/disabled state, tap callback, loading state. |
| Charts | no overflow, semantic label if meaningful, empty/data rendering. |
| Rows/cards | long text truncation, badge visibility, trailing action visibility. |
| Modals/fixed bars | safe-area avoidance, primary/secondary action visibility. |

### 4.3 Page-Level Gate

The component test is necessary but not sufficient. A component change must still improve the page-level report.

Current compact gate:

```bash
npm run ui:parity-report
```

Target threshold remains:

```text
review threshold: 1.50%
```

## 5. Current Page Queue

Current compact report after the last accepted visual commits:

| Priority | Page | Current diff | Pixels | Target for this phase | Commit granularity |
|---:|---|---:|---:|---|---|
| P0 | 宝宝和我 | 5.07% | 16,699 | below 4.50%, then below 3.50% | module cards, then trend card/painter |
| P0 | 妈妈点滴 | 4.96% | 16,338 | below 4.50%, then below 3.50% | dashboard, chart, rows |
| P0 | 待产包 | 4.80% | 15,816 | below 4.00%, then below 3.00% | product row, section header, checkout footer |
| P0 | 计划 | 4.50% | 14,824 | below 4.00%, then below 3.00% | week strip, context card, empty/task blocks |
| P0 | 吸乳 | 4.32% | 14,229 | below 3.75%, then below 3.00% | prompt modal, backdrop, controls |
| P1 | W1 | 3.72% | 12,235 | below 3.00%, then below 2.25% | hero, product summary, selling points |
| P1 | 舒适负压调节 | 2.59% | 8,509 | below 2.00% | top bar typography, intro card |
| P1 | 用户参数 | 2.55% | 8,400 | below 2.00% | subpage header, form controls |
| P1 | IBCLC | 2.03% | 6,689 | below 1.50% | header, loading card, bottom nav edge |
| P1 | Agent Hub | 1.70% | 5,589 | below 1.50% | composer, greeting typography, avatar opacity |
| P1 | 设备 | 1.59% | 5,229 | below 1.50% | header/banner final polish |
| P2 | 设备提醒 | 1.29% | 4,239 | keep OK | regression guard only |
| P2 | 社区 | 1.18% | 3,893 | keep OK | regression guard only |
| P2 | 404 | 0.93% | 3,054 | keep OK | regression guard only |
| P2 | 媒体 | 0.44% | 1,435 | keep OK | regression guard only |

## 6. Page Component Matrix

### 6.1 宝宝和我 `/status`

Legacy sources:

```text
src/pages/Status.tsx
src/pages/status/StatusOverviewBody.tsx
```

Flutter target:

```text
flutter_app/lib/features/app_pages/momcozy_feature_pages.dart
```

Components:

| Component | Test file | Initial target | Notes |
|---|---|---|---|
| Care stage segmented control | `status_component_parity_golden_test.dart` | no regression | Already structurally aligned. |
| Mom/Baby identity cards | `status_component_parity_golden_test.dart` | reduce tab-card diff | Check selected left rail, avatar opacity, text weight. |
| Postpartum module grid | `status_component_parity_golden_test.dart` | reduce `modulesTop/modulesBottom` diff | First implementation slice. |
| Status module card | `status_component_parity_golden_test.dart` | component golden stable | Match gradient, icon bubble, heading, metric rows, action pill. |
| Milk trend card | `status_component_parity_golden_test.dart` | reduce trend diff | Second implementation slice. |
| Trend painter | `status_component_parity_golden_test.dart` | stable chart geometry | Match grid, axis labels, legend, line/points, week/month pill. |
| Pregnancy diary/plan state | `status_state_golden_test.dart` | no regression | Existing state coverage; extend only if touched. |

Commit order:

1. `test: add status component parity goldens`
2. `fix: align status module cards`
3. `fix: align status trend chart`

### 6.2 妈妈点滴 `/records`

Components:

| Component | Test file | Initial target | Notes |
|---|---|---|---|
| Month header | `records_component_parity_golden_test.dart` | stable | Already improved; guard against regression. |
| Dashboard mini stats | `records_component_parity_golden_test.dart` | reduce dashboard diff | Icon and label treatment differs. |
| Records trend painter | `records_component_parity_golden_test.dart` | reduce chart diff | Chart geometry already close; focus icon/text/axis painter. |
| M.ai insight row | `records_component_parity_golden_test.dart` | stable | Already improved; guard. |
| Milk record row | `records_component_parity_golden_test.dart` | reduce row diff | Badge/icon style differs from Web. |

Commit order:

1. dashboard/stat cards,
2. trend painter,
3. milk rows.

### 6.3 待产包 `/hospital-bag-cart`

Components:

| Component | Test file | Initial target | Notes |
|---|---|---|---|
| Header | `hospital_bag_component_parity_golden_test.dart` | small reduction | Low risk, small gain. |
| Section header | `hospital_bag_component_parity_golden_test.dart` | small reduction | Align badge/title spacing. |
| Product row | `hospital_bag_component_parity_golden_test.dart` | largest row reduction | Image clipping, shadow, delete pill. |
| Fixed checkout footer | `hospital_bag_component_parity_golden_test.dart` | reduce footer diff | Avoid over-blur regression. |

Commit order:

1. product row,
2. checkout footer,
3. header/section polish.

### 6.4 计划 `/schedule`

Components:

| Component | Test file | Initial target | Notes |
|---|---|---|---|
| Week strip | `schedule_component_parity_golden_test.dart` | no regression | Already aligned by position. |
| Plan progress card | `schedule_component_parity_golden_test.dart` | reduce card internal diff | Icon, title, progress line. |
| Agent context card | `schedule_component_parity_golden_test.dart` | reduce text/button diff | Large vertical moves regress; repaint internals only. |
| Empty task card | `schedule_component_parity_golden_test.dart` | reduce empty-state diff | Icon bubble and text weights. |
| Today task header/actions | `schedule_component_parity_golden_test.dart` | reduce action row diff | Button icon size and spacing. |

Commit order:

1. progress card,
2. context card internals,
3. empty/task blocks.

### 6.5 吸乳 `/pump`

Components:

| Component | Test file | Initial target | Notes |
|---|---|---|---|
| Calibration prompt modal | `pump_component_parity_golden_test.dart` | reduce modal diff | Modal has no useful offset gain; repaint internals. |
| Blurred background | `pump_component_parity_golden_test.dart` | no regression | Larger shifts regress; tune blur/color carefully. |
| Pump controls | `pump_component_parity_golden_test.dart` | reduce background diff | Only after modal stabilizes. |

Commit order:

1. prompt modal,
2. backdrop,
3. controls.

### 6.6 Remaining P1 Pages

| Page | Components | Test file | Commit granularity |
|---|---|---|---|
| W1 | hero, product summary, selling points | `w1_component_parity_golden_test.dart` | one component group at a time |
| 舒适负压调节 | top bar, progress, intro card | `device_component_parity_golden_test.dart` or dedicated calibration file | top bar, then card |
| 用户参数 | subpage header, dropdowns, action buttons | `device_component_parity_golden_test.dart` | header/form |
| IBCLC | header, loading card | `agent_component_parity_golden_test.dart` | header/loading |
| Agent Hub | greeting, composer | `agent_component_parity_golden_test.dart` | greeting/composer |
| 设备 | header, banner, deck cards | `device_component_parity_golden_test.dart` | final polish only |

## 7. Review Assessment Per Completed Item

Each completed item must record:

```text
Page:
Component:
Before diff:
After diff:
Delta:
Focused tests:
Full parity report:
Analyzer:
Decision: keep / revert
Commit:
Notes:
```

The assessment can live in the commit summary or in the working log for the turn. Do not commit visual changes that raise the page diff unless the change fixes a product-critical UX issue and is explicitly accepted.

## 8. Starting Slice

Start with `宝宝和我` because it is currently the highest-ranked page.

First execution slice:

1. Add `status_component_parity_golden_test.dart`.
2. Add focused component harnesses for:
   - postpartum mom module grid,
   - module card states,
   - milk trend card/painter.
3. Repaint postpartum module cards.
4. Run focused golden, page golden, full parity report.
5. Commit if the page diff drops.
6. Repaint status trend chart.
7. Run the same gate and commit if the page diff drops.
