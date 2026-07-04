# Flutter UI Component Parity Plan

> Status: execution plan v0.3
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
| P0 | 待产包 | 4.30% | 14,139 | below 4.00%, then below 3.00% | product row, section header, checkout footer |
| P0 | 妈妈点滴 | 4.26% | 14,016 | below 4.00%, then below 3.00% | dashboard, chart, rows |
| P0 | 吸乳 | 4.13% | 13,579 | below 3.75%, then below 3.00% | prompt modal, backdrop, controls |
| P0 | 宝宝和我 | 3.85% | 12,670 | below 3.50%, then below 2.50% | module cards, then trend card/painter |
| P0 | 计划 | 3.72% | 12,255 | below 3.50%, then below 2.50% | week strip, context card, empty/task blocks |
| P1 | W1 | 3.07% | 10,089 | below 2.75%, then below 2.25% | hero, product summary, selling points |
| P1 | 用户参数 | 2.45% | 8,055 | below 2.00% | subpage header, form controls |
| P1 | 舒适负压调节 | 2.17% | 7,142 | below 2.00% | top bar typography, intro card |
| P2 | Agent Hub | 1.45% | 4,766 | keep OK | composer, greeting typography, avatar opacity |
| P2 | 设备 | 1.50% | 4,927 | keep at or below threshold | header/banner final polish |
| P2 | IBCLC | 1.49% | 4,908 | keep OK | header/loading |
| P2 | 设备提醒 | 1.29% | 4,239 | keep OK | regression guard only |
| P2 | 社区 | 1.18% | 3,893 | keep OK | regression guard only |
| P2 | 404 | 0.68% | 2,225 | keep OK | regression guard only |
| P2 | 媒体 | 0.44% | 1,435 | keep OK | regression guard only |

Accepted component slices so far:

| Page | Component | Before | After | Commit |
|---|---|---:|---:|---|
| 宝宝和我 | Trend target icon | 12,958 px | 12,751 px | `be81d27` |
| 宝宝和我 | Breast health icon | 12,751 px | 12,747 px | `d0885e0` |
| 宝宝和我 | Module action pill text alignment | 12,747 px | 12,676 px | `9eb5a7b` |
| 宝宝和我 | Trend segmented weight | 12,676 px | 12,673 px | `e679e9e` |
| 宝宝和我 | Module action pill surface | 12,673 px | 12,670 px | `04a3efa` |
| 妈妈点滴 | Milk stat accent | 14,256 px | 14,144 px | `db5bfcd` |
| 妈妈点滴 | Mini stat units | 14,144 px | 14,068 px | `0389c1f` |
| 妈妈点滴 | Month label weight | 14,068 px | 14,049 px | `d283bae` |
| 妈妈点滴 | Month chevron size | 14,049 px | 14,045 px | `2c3a3f2` |
| 妈妈点滴 | Milk row amount weight | 14,045 px | 14,016 px | `5243d83` |
| 待产包 | Product image foreground border | 14,153 px | 14,139 px | `25495c9` |
| 计划 | Agent context card surface | 12,492 px | 12,360 px | `ac67052` |
| 计划 | Agent context button icons | 12,360 px | 12,284 px | `383c505` |
| 计划 | Today task toolbar icon size | 12,284 px | 12,255 px | `01a2b88` |
| W1 | Summary typography | 10,195 px | 10,172 px | `933ca14` |
| W1 | Hero eyebrow weight | 10,172 px | 10,166 px | `07abe7b` |
| W1 | Hero eyebrow tone | 10,166 px | 10,143 px | `489d06b` |
| W1 | Hero subtitle tone | 10,143 px | 10,115 px | `7f3b33c` |
| W1 | Hero wellness tone | 10,115 px | 10,089 px | `9b1fba6` |
| 舒适负压调节 | Intro card position | 7,501 px | 7,294 px | `b67fb25` |
| Agent Hub | Selected agent nav gradient | 5,065 px | 4,968 px | `2243ab2` |
| Agent Hub | Composer image icon size | 4,968 px | 4,950 px | `3840bc6` |
| Agent Hub | Composer send icon size | 4,950 px | 4,946 px | `408aeb8` |
| Agent Hub | Composer vertical offset 15 -> 16 | 4,946 px | 4,942 px | `9d026ac` |
| Agent Hub | Composer input typography | 4,942 px | 4,766 px | `135616c` |
| 用户参数 | Delete outline button foreground | 8,182 px | 8,129 px | `ee85581` |
| 用户参数 | Action icon size | 8,129 px | 8,086 px | `3b03b33` |
| 用户参数 | Form control horizontal padding | 8,086 px | 8,055 px | `fc899fd` |
| 舒适负压调节 | Intro description weight | 7,294 px | 7,202 px | `2ccce9d` |
| 舒适负压调节 | Top progress track position | 7,202 px | 7,142 px | `f56b3b8` |

Component guard additions:

| Scope | Test coverage | Commit |
|---|---|---|
| Bottom navigation | selected Agent center tab golden | `4c4e2a8` |

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
| 舒适负压调节 | top bar, progress, intro card | `calibration_component_parity_golden_test.dart` | top bar, then card |
| 用户参数 | subpage header, dropdowns, action buttons | `device_user_component_parity_golden_test.dart` | header/form |
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

Latest rejected probes to avoid repeating:

| Page | Probe | Result | Decision |
|---|---|---:|---|
| 待产包 | Footer CTA height 48 -> 46 | 14,153 px -> 15,194 px | reverted |
| 待产包 | Product row shadow to Tailwind shadow-sm geometry | 14,153 px -> 14,153 px | reverted |
| 待产包 | Product row title-desc gap 4 -> Web-like 2 | 14,153 px -> 14,153 px | reverted |
| 待产包 | Product row text column y offset -1 -> 0 | 14,153 px -> 14,906 px | reverted |
| 待产包 | Header/group chip vertical padding 5 -> Web-like 4 | 14,153 px -> 19,312 px | reverted |
| 待产包 | Product image radius 28 -> Web `rounded-2xl` 16 | 14,153 px -> 14,286 px | reverted |
| 待产包 | Product image offset `(1,1)` -> `(0,0)` | 14,153 px -> 15,196 px | reverted |
| 待产包 | Product image `FilterQuality.high` -> `medium` | 14,153 px -> 14,222 px | reverted |
| 待产包 | Footer total row offset `(0,3)` -> `(0,0)` | 14,153 px -> 14,783 px | reverted |
| 妈妈点滴 | Dashboard chart height 136 -> 160 | 14,068 px -> 16,800 px | reverted |
| 妈妈点滴 | Page title weight w900 -> w700 | 14,068 px -> 14,068 px | reverted |
| 妈妈点滴 | Month button width 30 -> 20 | 14,045 px -> 14,045 px | reverted |
| 妈妈点滴 | Dashboard mini-stat radius 16 -> 12 | 14,045 px -> 14,045 px | reverted |
| 妈妈点滴 | Trend title emoji -> Material chart icon | 14,045 px -> 14,050 px | reverted |
| 妈妈点滴 | Pump row detail weight w700 -> Web-like w400 | 14,016 px -> 14,016 px | reverted |
| 妈妈点滴 | Source badge weight w800 -> Web-like w600 | 14,016 px -> 14,016 px | reverted |
| 妈妈点滴 | List toolbar text 12/w900 -> Web-like 11/w600 | 14,016 px -> 14,019 px | reverted |
| 妈妈点滴 | Add inventory total to header | 14,016 px -> 14,996 px | reverted |
| 妈妈点滴 | Dashboard header label explicit 11px | 14,016 px -> 14,202 px | reverted |
| 妈妈点滴 | Trend chart rect to Recharts axis widths | 14,016 px -> 14,164 px | reverted |
| 妈妈点滴 | Page title mark custom bars -> emoji | 14,016 px -> 14,150 px | reverted |
| 妈妈点滴 | Mini-stat icon size 15 -> Web 14 | 14,016 px -> 14,031 px | reverted |
| 吸乳 | Prompt overlay alpha 0.43 -> 0.40 | 13,579 px -> 14,021 px | reverted |
| 吸乳 | Prompt overlay blur 5 -> 4 | 13,579 px -> 13,893 px | reverted |
| 吸乳 | Prompt rich text line-height 1.55 -> 1.625 | 13,579 px -> 15,049 px | reverted |
| 吸乳 | Prompt card shadow to Tailwind `shadow-2xl` geometry | 13,579 px -> 13,579 px | reverted |
| 吸乳 | Control console AI/manual tab icons removed | 13,579 px -> 13,579 px | reverted |
| 吸乳 | Prompt flower painter -> native emoji | 13,579 px -> 14,100 px | reverted |
| 吸乳 | Prompt card vertical offset 4 -> 0 | 13,579 px -> 15,647 px | reverted |
| 计划 | Agent button weights w900 -> Web-like bold/extrabold | 12,360 px -> 12,360 px | reverted |
| 计划 | Agent button label explicit 12px | 12,284 px -> 12,556 px | reverted |
| 计划 | Agent text line-height 1.45 -> Web-like 1.625 | 12,284 px -> 13,939 px | reverted |
| 计划 | Week strip chevron size 19 -> 16 | 12,360 px -> 12,362 px | reverted |
| 计划 | Empty task title to Web 18px/700 | 12,360 px -> 13,009 px | reverted |
| 计划 | Empty task icon size 34 -> Web 32 | 12,284 px -> 12,337 px | reverted |
| 宝宝和我 | Postpartum recovery card old PNG asset icon | 12,747 px -> 12,852 px | reverted |
| 宝宝和我 | Module card padding 12 -> Web-like 14 | 12,747 px -> 14,694 px | reverted |
| 宝宝和我 | Milk trend axis tick font 8 -> 9 | 12,747 px -> 12,805 px | reverted |
| 宝宝和我 | Milk trend axis label color `#9c7651` -> Web `#8a6742` | 12,747 px -> 12,754 px | reverted |
| 宝宝和我 | Milk trend legend spacing 9 -> Web-like 8 | 12,747 px -> 12,747 px | reverted |
| 宝宝和我 | Status segmented vertical padding 4 -> Web-like 2 | 12,673 px -> 13,753 px | reverted |
| 宝宝和我 | Status segmented horizontal padding 9 -> Web-like 8 | 12,673 px -> 12,704 px | reverted |
| 宝宝和我 | Milk trend chart height 188 -> 185 | 12,747 px -> 13,666 px | reverted |
| 宝宝和我 | Milk trend card three-stop Web gradient | 12,747 px -> 13,092 px | reverted |
| 宝宝和我 | Identity tab minHeight 72 -> Web 68 | 12,670 px -> 16,089 px | reverted |
| W1 | Hero circular product stage radial fill | 10,089 px -> 10,123 px | reverted |
| W1 | Summary spec tile vertical padding 9 -> Web-like 8 | 10,089 px -> 11,295 px | reverted |
| W1 | Section label weight w900 -> Web-like w600 | 10,089 px -> 10,089 px | reverted |
| Agent Hub | Composer vertical offset 16 -> 17 | 4,942 px -> 4,952 px | reverted |
| Agent Hub | Top action gap 4 -> Web gap 8 | 4,942 px -> 4,942 px | reverted |
| Agent Hub | Greeting max width 260 -> 258 | 4,942 px -> 4,942 px | reverted |
| 用户参数 | Form label weight w900 -> Web-like w500 | 8,086 px -> 8,089 px | reverted |
| 用户参数 | Form card y offset 7 -> 2 | 8,086 px -> 10,601 px | reverted |
| 用户参数 | Form card x offset 0 -> -3 | 8,055 px -> 8,678 px | reverted |
| 用户参数 | Action button minimum height -> Web 44 | 8,055 px -> 8,653 px | reverted |
| 舒适负压调节 | Step card title weight w900 -> Web-like w800 | 7,202 px -> 7,202 px | reverted |
| 舒适负压调节 | Step card eyebrow weight w900 -> Web-like w700 | 7,202 px -> 7,203 px | reverted |
| 舒适负压调节 | Intro card x offset 0 -> -4 | 7,142 px -> 7,965 px | reverted |
| 舒适负压调节 | Top bar title 15px/w700 | 7,142 px -> 7,188 px | reverted |
| Agent Hub | Send icon rounded -> outlined | 4,942 px -> 4,945 px | reverted |
| Agent Hub | Transcript text explicit 15px/1.45 | 4,942 px -> 5,469 px | reverted |
| 待产包 | Footer checkout icon rounded -> outlined | 14,153 px -> 14,153 px | reverted |
| 妈妈点滴 | Pump row Material icon -> bottle emoji | 14,016 px -> 14,212 px | reverted |

## 8. Starting Slice

Initial execution started with `宝宝和我` because it was the highest-ranked page at v0.1.

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

Current continuation policy:

1. Prefer the highest-ranked page when there is a clear component-local candidate.
2. For pages where broad movement has regressed, move to the next smallest near-threshold component and return later with a narrower repaint.
3. Keep or commit only candidates that reduce the page-level pixel diff.
