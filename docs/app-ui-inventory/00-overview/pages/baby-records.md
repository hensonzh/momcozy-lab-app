# 宝宝记录历史

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`baby-records`
- 范围：default
- 入口：宝宝首页 → 记录历史
- 路由：/babies/:babyId/records
- 实现：[baby_records_page.dart](../../../../lib/modules/baby/presentation/baby_records_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 空
- 列表
- 种类和日期切换
- 加载
- 错误
- 删除与撤销

## 归属弹窗／浮层

baby-record、baby-saved

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 空 | [baby-journey-history-sleep-empty](../../04-baby/baby-journey-history-sleep-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 列表 | [baby-journey-history-first-page](../../04-baby/baby-journey-history-first-page/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 种类和日期切换 | [baby-journey-history-feeding](../../04-baby/baby-journey-history-feeding/README.md) · [baby-journey-history-previous-month](../../04-baby/baby-journey-history-previous-month/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [baby-journey-history-more-loading](../../04-baby/baby-journey-history-more-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [baby-journey-history-more-error](../../04-baby/baby-journey-history-more-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 删除与撤销 | [baby-journey-history-deleted](../../04-baby/baby-journey-history-deleted/README.md) · [baby-journey-history-restored](../../04-baby/baby-journey-history-restored/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../04-baby/baby-development-recovery-restore-403/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-restore-403/README.md) | 2 | Undo returns HTTP 403 → error and retained deletion receipt |
| [图](../../04-baby/baby-diaper-controls-wet-history-saved/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-wet-history-saved/README.md) | 1 | Save wet type → stool fields omitted from returned record |
| [图](../../04-baby/baby-journey-history-feeding/default.png) · [入口及前驱](../../04-baby/baby-journey-history-feeding/README.md) | 1 | Saved home → View all records |
| [图](../../04-baby/baby-development-management-head-delete-kept/default.png) · [入口及前驱](../../04-baby/baby-development-management-head-delete-kept/README.md) | 4 | Keep → original head record unchanged |
| [图](../../04-baby/baby-development-controls-history-reopened/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-reopened/README.md) | 1 | Reopen first edited behavior → saved status persists |
| [图](../../04-baby/baby-feeding-time-maximum-volume-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-maximum-volume-saved/README.md) | 1 | Save maximum bottle volume; nursing fields removed |
| [图](../../04-baby/baby-development-recovery-delete-unconfirmed/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-delete-unconfirmed/README.md) | 1 | Delete fails 503 → unconfirmed mutation, record retained and month/edit locked |
| [图](../../04-baby/baby-journey-history-growth-empty/default.png) · [入口及前驱](../../04-baby/baby-journey-history-growth-empty/README.md) | 1 | Tap 生长 filter → empty category |
| [图](../../04-baby/baby-sleep-controls-history-active-reopened/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-history-active-reopened/README.md) | 1 | Reopen active interval from history → editable times visible |
| [图](../../04-baby/baby-development-management-sound-delete-confirm/default.png) · [入口及前驱](../../04-baby/baby-development-management-sound-delete-confirm/README.md) | 1 | Delete sound → record-specific confirmation |
| [图](../../04-baby/baby-journey-delete-cancelled/default.png) · [入口及前驱](../../04-baby/baby-journey-delete-cancelled/README.md) | 2 | Keep record → same history record |
| [图](../../04-baby/baby-growth-controls-history-decimal/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history-decimal/README.md) | 1 | Enter decimal weight with surrounding spaces |
| [图](../../04-baby/baby-journey-history-month-picker/default.png) · [入口及前驱](../../04-baby/baby-journey-history-month-picker/README.md) | 1 | Tap month → date picker |
| [图](../../04-baby/baby-development-controls-history/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history/README.md) | 1 | Open developmental history → each behavior and saved status |
| [图](../../04-baby/baby-diaper-controls-dirty-optional-empty/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-dirty-optional-empty/README.md) | 2 | Reopen wet then switch dirty → no stale saved stool selections |
| [图](../../04-baby/baby-journey-history-formula/default.png) · [入口及前驱](../../04-baby/baby-journey-history-formula/README.md) | 3 | Baby → all records with existing formula record |
| [图](../../04-baby/baby-development-recovery-restore-unconfirmed/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-restore-unconfirmed/README.md) | 1 | Undo fails 503 → unconfirmed restore with retry |
| [图](../../04-baby/baby-feeding-time-optional-duration-reopened/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-optional-duration-reopened/README.md) | 1 | Reopen history → empty optional duration and current instant persisted |
| [图](../../04-baby/baby-journey-history-previous-month/default.png) · [入口及前驱](../../04-baby/baby-journey-history-previous-month/README.md) | 1 | Previous month → August |
| [图](../../04-baby/baby-development-controls-history-lifts-head-open/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-lifts-head-open/README.md) | 1 | Edit 俯卧时短暂抬起头 → only original behavior available |
| [图](../../04-baby/baby-development-management-sound-restored-edit/default.png) · [入口及前驱](../../04-baby/baby-development-management-sound-restored-edit/README.md) | 1 | Edit restored sound → original behavior and status preserved |
| [图](../../04-baby/baby-journey-history-edit/default.png) · [入口及前驱](../../04-baby/baby-journey-history-edit/README.md) | 1 | History → Edit saved feeding |
| [图](../../04-baby/baby-feeding-controls-optional-volume-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-optional-volume-saved/README.md) | 1 | Save formula without measured volume → count-only history |
| [图](../../04-baby/baby-development-management-sound-head-history/default.png) · [入口及前驱](../../04-baby/baby-development-management-sound-head-history/README.md) | 1 | History development tab → sound-head records with each saved status |
| [图](../../04-baby/baby-history-source/default.png) · [入口及前驱](../../04-baby/baby-history-source/README.md) | 1 | history edits and restores the same baby record at 390.0 / 1.0 |
| [图](../../04-baby/baby-diaper-controls-both-reopened/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-both-reopened/README.md) | 1 | Edit combined diaper → all saved optional fields restored |
| [图](../../04-baby/baby-journey-history-deleted/default.png) · [入口及前驱](../../04-baby/baby-journey-history-deleted/README.md) | 1 | Confirm deletion → empty list with undo |
| [图](../../04-baby/baby-journey-history-restored/default.png) · [入口及前驱](../../04-baby/baby-journey-history-restored/README.md) | 1 | Undo deletion → restored record |
| [图](../../04-baby/baby-development-controls-history-looks-at-face-changed/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-looks-at-face-changed/README.md) | 1 | Choose 暂未观察到 for this existing behavior |
| [图](../../04-baby/baby-development-management-sound-delete-kept/default.png) · [入口及前驱](../../04-baby/baby-development-management-sound-delete-kept/README.md) | 4 | Keep → original sound record unchanged |
| [图](../../04-baby/baby-development-management-face-sound-history/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-sound-history/README.md) | 1 | History development tab → face-sound records with each saved status |
| [图](../../04-baby/baby-feeding-time-maximum-volume-reopened/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-maximum-volume-reopened/README.md) | 1 | Reopen and verify 1000 ml persisted |
| [图](../../04-baby/baby-growth-controls-history-reopened/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history-reopened/README.md) | 1 | Reopen weight → trimmed parsed value persisted |
| [图](../../04-baby/baby-history/default.png) · [入口及前驱](../../04-baby/baby-history/README.md) | 1 | history edits and restores the same baby record at 390.0 / 1.0 |
| [图](../../04-baby/baby-development-management-face-delete-kept/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-delete-kept/README.md) | 6 | Keep → original face record unchanged |
| [图](../../04-baby/baby-feeding-controls-optional-volume-cleared/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-optional-volume-cleared/README.md) | 2 | Clear optional bottle volume before saving |
| [图](../../04-baby/baby-growth-controls-history-saved/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history-saved/README.md) | 1 | Save edit → 4.25 kg, same record, two other measurements retained |
| [图](../../04-baby/baby-sleep-controls-history-active-saved/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-history-active-saved/README.md) | 1 | Save history edit with no wake → active interval persisted |
| [图](../../04-baby/baby-development-management-face-head-history/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-head-history/README.md) | 1 | History development tab → face-head records with each saved status |
| [图](../../04-baby/baby-development-management-head-delete-confirm/default.png) · [入口及前驱](../../04-baby/baby-development-management-head-delete-confirm/README.md) | 1 | Delete head → record-specific confirmation |
| [图](../../04-baby/baby-feeding-controls-unchanged-editor-closed/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-unchanged-editor-closed/README.md) | 1 | Close unchanged saved record → no discard dialog |
| [图](../../04-baby/baby-journey-delete-confirm/default.png) · [入口及前驱](../../04-baby/baby-journey-delete-confirm/README.md) | 1 | Record Delete → confirmation |
| [图](../../04-baby/baby-development-management-face-delete-confirm/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-delete-confirm/README.md) | 1 | Delete face → record-specific confirmation |
| [图](../../04-baby/baby-journey-history-all-pages/default.png) · [入口及前驱](../../04-baby/baby-journey-history-all-pages/README.md) | 1 | Second page resolves → all 51 records and no load more button |
| [图](../../04-baby/baby-development-management-face-restored-edit/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-restored-edit/README.md) | 1 | Edit restored face → original behavior and status preserved |
| [图](../../04-baby/baby-development-controls-history-responds-to-sound-saved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-responds-to-sound-saved/README.md) | 1 | Save changed status → same record updated; other behaviors retained |
| [图](../../04-baby/baby-sleep-controls-history-editor/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-history-editor/README.md) | 1 | Edit completed sleep → start, wake and note restored |
| [图](../../04-baby/baby-journey-history-delete-error/default.png) · [入口及前驱](../../04-baby/baby-journey-history-delete-error/README.md) | 1 | Confirm deletion → service unavailable, record remains |
| [图](../../04-baby/baby-development-recovery-reentered-empty/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-reentered-empty/README.md) | 2 | Reenter development history → empty list without prior undo receipt |
| [图](../../04-baby/baby-journey-history-diaper-empty/default.png) · [入口及前驱](../../04-baby/baby-journey-history-diaper-empty/README.md) | 1 | Tap 尿便 filter → empty category |
| [图](../../04-baby/baby-journey-history-sleep-empty/default.png) · [入口及前驱](../../04-baby/baby-journey-history-sleep-empty/README.md) | 1 | Tap 睡眠 filter → empty category |
| [图](../../04-baby/baby-development-controls-history-looks-at-face-open/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-looks-at-face-open/README.md) | 1 | Edit 看向靠近的脸 → only original behavior available |
| [图](../../04-baby/baby-development-recovery-delete-403/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-delete-403/README.md) | 2 | Delete returns HTTP 403 → error, record retained and other edits enabled |
| [图](../../04-baby/baby-development-recovery-restore-409/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-restore-409/README.md) | 2 | Undo returns HTTP 409 → error and retained deletion receipt |
| [图](../../04-baby/baby-feeding-controls-nursing-history/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-nursing-history/README.md) | 1 | View all records → saved nursing with duration and note |
| [图](../../04-baby/baby-journey-history-restore-error/default.png) · [入口及前驱](../../04-baby/baby-journey-history-restore-error/README.md) | 1 | Undo deletion → service unavailable, restore retry state |
| [图](../../04-baby/baby-development-controls-history-responds-to-sound-changed/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-responds-to-sound-changed/README.md) | 1 | Choose 不确定 for this existing behavior |
| [图](../../04-baby/baby-sleep-controls-history-wake-cleared/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-history-wake-cleared/README.md) | 1 | Clear saved wake in history editor → draft becomes open interval |
| [图](../../04-baby/baby-feeding-time-maximum-volume-ready/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-maximum-volume-ready/README.md) | 1 | Change to expressed milk; enter maximum 1000 ml |
| [图](../../04-baby/baby-development-controls-history-lifts-head-saved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-lifts-head-saved/README.md) | 1 | Save changed status → same record updated; other behaviors retained |
| [图](../../04-baby/baby-feeding-controls-nursing-history-edit/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-nursing-history-edit/README.md) | 1 | Edit saved nursing → persisted values, note expanded |
| [图](../../04-baby/baby-development-controls-history-looks-at-face-cleared/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-looks-at-face-cleared/README.md) | 1 | Clear original status and save → required validation; stored record unchanged |
| [图](../../04-baby/baby-development-management-face-deleted/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-deleted/README.md) | 5 | Confirm delete → empty development history and undo action |
| [图](../../04-baby/baby-development-recovery-delete-409/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-delete-409/README.md) | 2 | Delete returns HTTP 409 → error, record retained and other edits enabled |
| [图](../../04-baby/baby-diaper-controls-edit-wet/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-edit-wet/README.md) | 1 | Change saved combined diaper to wet → stool controls hidden |
| [图](../../04-baby/baby-feeding-controls-formula-history-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-formula-history-saved/README.md) | 1 | Save type change → formula shown, nursing fields omitted |
| [图](../../04-baby/baby-feeding-time-minimum-duration-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-minimum-duration-saved/README.md) | 1 | Save minimum one-minute duration in history |
| [图](../../04-baby/baby-journey-history-more-loading/default.png) · [入口及前驱](../../04-baby/baby-journey-history-more-loading/README.md) | 1 | Retry page load while response pending |
| [图](../../04-baby/baby-development-management-head-restored-edit/default.png) · [入口及前驱](../../04-baby/baby-development-management-head-restored-edit/README.md) | 1 | Edit restored head → original behavior and status preserved |
| [图](../../04-baby/baby-development-controls-history-lifts-head-cleared/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-lifts-head-cleared/README.md) | 1 | Clear original status and save → required validation; stored record unchanged |
| [图](../../04-baby/baby-development-controls-history-responds-to-sound-cleared/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-responds-to-sound-cleared/README.md) | 1 | Clear original status and save → required validation; stored record unchanged |
| [图](../../04-baby/baby-journey-history-source-expanded/default.png) · [入口及前驱](../../04-baby/baby-journey-history-source-expanded/README.md) | 1 | Expand data source and privacy explanation |
| [图](../../04-baby/baby-development-recovery-restore-pending/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-restore-pending/README.md) | 1 | Retry restore → response pending while empty list remains |
| [图](../../04-baby/baby-development-controls-history-lifts-head-changed/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-lifts-head-changed/README.md) | 1 | Choose 观察到 for this existing behavior |
| [图](../../04-baby/baby-growth-controls-history/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history/README.md) | 1 | Open growth history → three saved measurements |
| [图](../../04-baby/baby-development-recovery-delete-pending/default.png) · [入口及前驱](../../04-baby/baby-development-recovery-delete-pending/README.md) | 1 | Retry deletion with response pending → controls stay locked |
| [图](../../04-baby/baby-diaper-controls-both-history/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-both-history/README.md) | 1 | History diaper tab → combined diaper facts |
| [图](../../04-baby/baby-journey-history-delete-retry/default.png) · [入口及前驱](../../04-baby/baby-journey-history-delete-retry/README.md) | 1 | Retry unconfirmed deletion → deleted record and undo |
| [图](../../04-baby/baby-sleep-controls-history-completed/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-history-completed/README.md) | 1 | History sleep tab → completed record with start/end and note |
| [图](../../04-baby/baby-growth-controls-history-editor/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history-editor/README.md) | 1 | Edit saved weight → metric cannot change, original value restored |
| [图](../../04-baby/baby-feeding-time-optional-duration-history/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-optional-duration-history/README.md) | 1 | Open history → saved nursing without invented duration |
| [图](../../04-baby/baby-diaper-controls-dirty-optional-saved/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-dirty-optional-saved/README.md) | 1 | Save dirty diaper with optional color/consistency/signs empty |
| [图](../../04-baby/baby-development-controls-history-responds-to-sound-open/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-responds-to-sound-open/README.md) | 1 | Edit 听到声音后有动作或表情反应 → only original behavior available |
| [图](../../04-baby/baby-growth-controls-history-empty-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-history-empty-rejected/README.md) | 1 | Clear weight and save → required error; saved value unchanged |
| [图](../../04-baby/baby-feeding-controls-edit-formula-decimal/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-edit-formula-decimal/README.md) | 2 | Change saved nursing to formula and enter decimal 90.5 ml |
| [图](../../04-baby/baby-development-controls-history-looks-at-face-saved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-history-looks-at-face-saved/README.md) | 1 | Save changed status → same record updated; other behaviors retained |
| [图](../../04-baby/baby-journey-history-more-error/default.png) · [入口及前驱](../../04-baby/baby-journey-history-more-error/README.md) | 1 | Load more → page failure keeps first page visible |
| [图](../../04-baby/baby-journey-history-first-page/default.png) · [入口及前驱](../../04-baby/baby-journey-history-first-page/README.md) | 1 | Baby → monthly feeding history with 51 records, first 50 loaded |

## 实际操作链与状态依据

[BABY-JOURNEYS.md](../BABY-JOURNEYS.md) · [BABY-FEEDING-CONTROLS.md](../BABY-FEEDING-CONTROLS.md) · [BABY-DIAPER-CONTROLS.md](../BABY-DIAPER-CONTROLS.md) · [BABY-SLEEP-CONTROLS.md](../BABY-SLEEP-CONTROLS.md) · [BABY-GROWTH-CONTROLS.md](../BABY-GROWTH-CONTROLS.md) · [BABY-DEVELOPMENT-CONTROLS.md](../BABY-DEVELOPMENT-CONTROLS.md)
