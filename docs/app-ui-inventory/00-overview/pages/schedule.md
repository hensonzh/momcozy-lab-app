# 日程

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`schedule`
- 范围：default
- 入口：Schedule Tab
- 路由：/schedule
- 实现：[schedule_page.dart](../../../../lib/modules/schedule/presentation/schedule_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 空日期
- 有事项
- 月和日期切换
- 任务状态
- 预约卡
- 加载
- 错误

## 归属弹窗／浮层

schedule-editor、schedule-delete

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 空日期 | [schedule-journey-empty](../../06-schedule/schedule-journey-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 有事项 | [schedule-overview](../../06-schedule/schedule-overview/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 月和日期切换 | [schedule-journey-date-changed](../../06-schedule/schedule-journey-date-changed/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 任务状态 | [schedule-journey-task-completed](../../06-schedule/schedule-journey-task-completed/README.md) · [schedule-journey-task-in-progress](../../06-schedule/schedule-journey-task-in-progress/README.md) · [schedule-journey-task-skipped](../../06-schedule/schedule-journey-task-skipped/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 预约卡 | [schedule-journey-appointment-entry](../../06-schedule/schedule-journey-appointment-entry/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [schedule-short-loading](../../06-schedule/schedule-short-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [schedule-short-offline](../../06-schedule/schedule-short-offline/README.md) · [schedule-journey-current-task-error](../../06-schedule/schedule-journey-current-task-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../06-schedule/schedule-journey-picker-time-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-time-invalid/README.md) | 1 | Enter hour 25 → time validation |
| [图](../../06-schedule/schedule-journey-refresh-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-refresh-error/README.md) | 1 | Next month read fails with cached page retained |
| [图](../../06-schedule/schedule-save-uncertain/default.png) · [入口及前驱](../../06-schedule/schedule-save-uncertain/README.md) | 1 | failed save preserves the draft and retries the same creation |
| [图](../../06-schedule/schedule-journey-picker-time-corrected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-time-corrected/README.md) | 1 | Correct time to 10:45 → editor |
| [图](../../06-schedule/schedule-journey-large-picker-date-out-of-range/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-date-out-of-range/README.md) | 1 | Enter date beyond allowed years → range error |
| [图](../../06-schedule/schedule-journey-current-create-conflict/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-create-conflict/README.md) | 1 | Create conflicts → conflict message with draft retained |
| [图](../../06-schedule/schedule-journey-picker-date-corrected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-date-corrected/README.md) | 1 | Correct date → editor retains September 15 |
| [图](../../06-schedule/schedule-journey-date-cancelled/default.png) · [入口及前驱](../../06-schedule/schedule-journey-date-cancelled/README.md) | 2 | Cancel date picker → original date retained |
| [图](../../06-schedule/schedule-journey-deleted/default.png) · [入口及前驱](../../06-schedule/schedule-journey-deleted/README.md) | 2 | Confirm delete → empty selected day |
| [图](../../06-schedule/schedule-journey-date-changed/default.png) · [入口及前驱](../../06-schedule/schedule-journey-date-changed/README.md) | 1 | Select September 14 → OK |
| [图](../../06-schedule/schedule-journey-large-picker-editor/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-editor/README.md) | 1 | Add event → responsive editor |
| [图](../../06-schedule/schedule-date-picker/default.png) · [入口及前驱](../../06-schedule/schedule-date-picker/README.md) | 1 | personal schedule create edit delete at 390.0/1.0 |
| [图](../../06-schedule/schedule-care/default.png) · [入口及前驱](../../06-schedule/schedule-care/README.md) | 2 | published care plan and appointment at 390.0 / 1.0 |
| [图](../../06-schedule/schedule-journey-validation-recovered/default.png) · [入口及前驱](../../06-schedule/schedule-journey-validation-recovered/README.md) | 1 | Retry accepted → agenda |
| [图](../../06-schedule/schedule-date-range-error-320-2x-short/default.png) · [入口及前驱](../../06-schedule/schedule-date-range-error-320-2x-short/README.md) | 1 | large editor date and time validation retain draft and accepted values |
| [图](../../06-schedule/schedule-journey-picker-saved/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-saved/README.md) | 1 | Save corrected date/time → selected day agenda |
| [图](../../06-schedule/schedule-delete/default.png) · [入口及前驱](../../06-schedule/schedule-delete/README.md) | 1 | personal schedule create edit delete at 390.0/1.0 |
| [图](../../06-schedule/schedule-journey-year-selector/default.png) · [入口及前驱](../../06-schedule/schedule-journey-year-selector/README.md) | 1 | Date header → year selector |
| [图](../../06-schedule/schedule-save-busy/default.png) · [入口及前驱](../../06-schedule/schedule-save-busy/README.md) | 1 | pending personal save locks edits and close then creates once |
| [图](../../06-schedule/schedule-time-error-320-2x-short/default.png) · [入口及前驱](../../06-schedule/schedule-time-error-320-2x-short/README.md) | 1 | large editor date and time validation retain draft and accepted values |
| [图](../../06-schedule/schedule-journey-current-delete-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-delete-error/README.md) | 1 | Delete cannot be confirmed → snackbar and retained event |
| [图](../../06-schedule/schedule-journey-picker-editor/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-editor/README.md) | 1 | Add event → responsive editor |
| [图](../../06-schedule/schedule-journey-task-menu/default.png) · [入口及前驱](../../06-schedule/schedule-journey-task-menu/README.md) | 1 | Task more options → statuses and service link |
| [图](../../06-schedule/schedule-journey-delete-confirm/default.png) · [入口及前驱](../../06-schedule/schedule-journey-delete-confirm/README.md) | 1 | Delete → confirmation |
| [图](../../06-schedule/schedule-journey-appointment-held/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-held/README.md) | 2 | Schedule → appointment status held |
| [图](../../06-schedule/schedule-journey-date-picker/default.png) · [入口及前驱](../../06-schedule/schedule-journey-date-picker/README.md) | 1 | Date field → calendar dialog |
| [图](../../06-schedule/schedule-task-menu/default.png) · [入口及前驱](../../06-schedule/schedule-task-menu/README.md) | 1 | task menu writes progress with the current version at 390.0/1.0 |
| [图](../../06-schedule/schedule-journey-discarded/default.png) · [入口及前驱](../../06-schedule/schedule-journey-discarded/README.md) | 2 | Leave → unsaved note discarded |
| [图](../../06-schedule/schedule-journey-current-task-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-task-error/README.md) | 1 | Care task write fails → reconciliation feedback |
| [图](../../06-schedule/schedule-short-refresh-error/default.png) · [入口及前驱](../../06-schedule/schedule-short-refresh-error/README.md) | 1 | short large initial load error retries and cached refresh retains agenda |
| [图](../../06-schedule/schedule-journey-current-edit-conflict/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-edit-conflict/README.md) | 1 | Edit conflicts → changed note retained in edit form |
| [图](../../06-schedule/schedule-journey-save-uncertain/default.png) · [入口及前驱](../../06-schedule/schedule-journey-save-uncertain/README.md) | 1 | Save HTTP 503 → uncertain result and locked fields |
| [图](../../06-schedule/schedule-journey-appointment-expired/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-expired/README.md) | 2 | Schedule → appointment status expired |
| [图](../../06-schedule/schedule-journey-delete-recovered/default.png) · [入口及前驱](../../06-schedule/schedule-journey-delete-recovered/README.md) | 3 | Reopen delete and confirm → event removed |
| [图](../../06-schedule/schedule-journey-create-filled/default.png) · [入口及前驱](../../06-schedule/schedule-journey-create-filled/README.md) | 1 | Enter title and note |
| [图](../../06-schedule/schedule-journey-appointment-cancelled/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-cancelled/README.md) | 2 | Schedule → appointment status cancelled |
| [图](../../06-schedule/schedule-journey-task-in-progress/default.png) · [入口及前驱](../../06-schedule/schedule-journey-task-in-progress/README.md) | 1 | Mark in progress → refreshed task badge |
| [图](../../06-schedule/schedule-journey-conflict/default.png) · [入口及前驱](../../06-schedule/schedule-journey-conflict/README.md) | 1 | Retry HTTP 409 → conflict feedback |
| [图](../../06-schedule/schedule-journey-picker-date-out-of-range/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-date-out-of-range/README.md) | 1 | Enter date beyond allowed years → range error |
| [图](../../06-schedule/schedule-journey-current-create-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-create-invalid/README.md) | 1 | Create validation rejected → editable draft and feedback |
| [图](../../06-schedule/schedule-create/default.png) · [入口及前驱](../../06-schedule/schedule-create/README.md) | 1 | personal schedule create edit delete at 390.0/1.0 |
| [图](../../06-schedule/schedule-journey-plan-expanded/default.png) · [入口及前驱](../../06-schedule/schedule-journey-plan-expanded/README.md) | 1 | Expand current care plan → full summary and progress |
| [图](../../06-schedule/schedule-journey-save-pending/default.png) · [入口及前驱](../../06-schedule/schedule-journey-save-pending/README.md) | 1 | Retry same idempotency key → request pending |
| [图](../../06-schedule/schedule-journey-multiple-services/default.png) · [入口及前驱](../../06-schedule/schedule-journey-multiple-services/README.md) | 2 | Schedule tab → two service periods and completed consultation |
| [图](../../06-schedule/schedule-journey-personal-menu/default.png) · [入口及前驱](../../06-schedule/schedule-journey-personal-menu/README.md) | 1 | Personal event more options |
| [图](../../06-schedule/schedule-journey-task-skipped/default.png) · [入口及前驱](../../06-schedule/schedule-journey-task-skipped/README.md) | 1 | Skip → disabled completion checkbox |
| [图](../../06-schedule/schedule-journey-next-tooltip/default.png) · [入口及前驱](../../06-schedule/schedule-journey-next-tooltip/README.md) | 1 | Long press next month → tooltip |
| [图](../../06-schedule/schedule-journey-current-add-tooltip/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-add-tooltip/README.md) | 1 | Long press add → tooltip |
| [图](../../06-schedule/schedule-short-loading/default.png) · [入口及前驱](../../06-schedule/schedule-short-loading/README.md) | 1 | short large initial load error retries and cached refresh retains agenda |
| [图](../../06-schedule/schedule-journey-draft-kept/default.png) · [入口及前驱](../../06-schedule/schedule-journey-draft-kept/README.md) | 1 | Continue filling → draft retained |
| [图](../../06-schedule/schedule-task-busy/default.png) · [入口及前驱](../../06-schedule/schedule-task-busy/README.md) | 1 | task write disables competing changes and keeps server version |
| [图](../../06-schedule/schedule-journey-large-picker-time-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-time-invalid/README.md) | 1 | Enter hour 25 → time validation |
| [图](../../06-schedule/schedule-journey-year-selected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-year-selected/README.md) | 1 | Choose 2027 → calendar for selected year |
| [图](../../06-schedule/schedule-journey-add-tooltip/default.png) · [入口及前驱](../../06-schedule/schedule-journey-add-tooltip/README.md) | 1 | Long press add → tooltip |
| [图](../../06-schedule/schedule-journey-large-picker-time-corrected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-time-corrected/README.md) | 1 | Correct time to 10:45 → editor |
| [图](../../06-schedule/schedule-journey-discard-confirm/default.png) · [入口及前驱](../../06-schedule/schedule-journey-discard-confirm/README.md) | 1 | Close dirty editor → discard confirmation |
| [图](../../06-schedule/schedule-long-agenda-end/default.png) · [入口及前驱](../../06-schedule/schedule-long-agenda-end/README.md) | 1 | hundred loaded entries scroll to final action on short large display |
| [图](../../06-schedule/schedule-journey-previous-month/default.png) · [入口及前驱](../../06-schedule/schedule-journey-previous-month/README.md) | 1 | Previous month → September first day |
| [图](../../06-schedule/schedule-journey-picker-date-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-picker-date-invalid/README.md) | 1 | Enter invalid date → validation without dismissal |
| [图](../../06-schedule/schedule-journey-large-picker-date-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-date-invalid/README.md) | 1 | Enter invalid date → validation without dismissal |
| [图](../../06-schedule/schedule-edit/default.png) · [入口及前驱](../../06-schedule/schedule-edit/README.md) | 1 | personal schedule create edit delete at 390.0/1.0 |
| [图](../../06-schedule/schedule-journey-appointment-entry/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-entry/README.md) | 7 | Schedule → confirmed consultation |
| [图](../../06-schedule/schedule-journey-read-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-read-error/README.md) | 1 | First read fails → retry view |
| [图](../../06-schedule/schedule-journey-create-empty/default.png) · [入口及前驱](../../06-schedule/schedule-journey-create-empty/README.md) | 1 | Today heading → add; empty title disables save |
| [图](../../06-schedule/schedule-journey-delete-conflict/default.png) · [入口及前驱](../../06-schedule/schedule-journey-delete-conflict/README.md) | 1 | Delete stale event → uncertain deletion feedback |
| [图](../../06-schedule/schedule-journey-date-input/default.png) · [入口及前驱](../../06-schedule/schedule-journey-date-input/README.md) | 1 | Date calendar → text input mode |
| [图](../../06-schedule/schedule-time-picker/default.png) · [入口及前驱](../../06-schedule/schedule-time-picker/README.md) | 1 | personal schedule create edit delete at 390.0/1.0 |
| [图](../../06-schedule/schedule-journey-year-editor/default.png) · [入口及前驱](../../06-schedule/schedule-journey-year-editor/README.md) | 1 | Confirm future year → editor |
| [图](../../06-schedule/schedule-journey-loading/default.png) · [入口及前驱](../../06-schedule/schedule-journey-loading/README.md) | 1 | Schedule tab → first read pending |
| [图](../../06-schedule/schedule-journey-edit/default.png) · [入口及前驱](../../06-schedule/schedule-journey-edit/README.md) | 1 | Modify → persisted fields |
| [图](../../06-schedule/schedule-journey-pull-refresh-reconciled/default.png) · [入口及前驱](../../06-schedule/schedule-journey-pull-refresh-reconciled/README.md) | 1 | Pull refresh → event retained with server state |
| [图](../../06-schedule/schedule-journey-created/default.png) · [入口及前驱](../../06-schedule/schedule-journey-created/README.md) | 1 | Save → refresh selected September 14 agenda |
| [图](../../06-schedule/schedule-journey-current-next-tooltip/default.png) · [入口及前驱](../../06-schedule/schedule-journey-current-next-tooltip/README.md) | 1 | Long press next month → tooltip |
| [图](../../06-schedule/schedule-journey-uncertain-discard/default.png) · [入口及前驱](../../06-schedule/schedule-journey-uncertain-discard/README.md) | 1 | Close uncertain save → reconciliation warning |
| [图](../../06-schedule/schedule-journey-time-input/default.png) · [入口及前驱](../../06-schedule/schedule-journey-time-input/README.md) | 1 | Clock → keyboard time input |
| [图](../../06-schedule/schedule-journey-invalid/default.png) · [入口及前驱](../../06-schedule/schedule-journey-invalid/README.md) | 1 | Save HTTP 422 → editable draft and validation feedback |
| [图](../../06-schedule/schedule-journey-time-picker/default.png) · [入口及前驱](../../06-schedule/schedule-journey-time-picker/README.md) | 1 | Start time field → clock dialog |
| [图](../../06-schedule/schedule-journey-service-filter-menu/default.png) · [入口及前驱](../../06-schedule/schedule-journey-service-filter-menu/README.md) | 1 | Service period selector → all and individual plans |
| [图](../../06-schedule/schedule-short-offline/default.png) · [入口及前驱](../../06-schedule/schedule-short-offline/README.md) | 1 | short large initial load error retries and cached refresh retains agenda |
| [图](../../06-schedule/schedule-journey-service-filter-selected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-service-filter-selected/README.md) | 1 | Choose second service → only its dates highlighted |
| [图](../../06-schedule/schedule-journey-large-picker-date-corrected/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-date-corrected/README.md) | 1 | Correct date → editor retains September 15 |
| [图](../../06-schedule/schedule-journey-task-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-task-error/README.md) | 1 | Status write fails → refresh reconciliation message |
| [图](../../06-schedule/schedule-journey-task-completed/default.png) · [入口及前驱](../../06-schedule/schedule-journey-task-completed/README.md) | 2 | Checkbox → completed task and progress count |
| [图](../../06-schedule/schedule/default.png) · [入口及前驱](../../06-schedule/schedule/README.md) | 1 | schedule month and selected day agenda at 390.0 / 1.0 |
| [图](../../06-schedule/schedule-journey-next-month/default.png) · [入口及前驱](../../06-schedule/schedule-journey-next-month/README.md) | 2 | Next month → October calendar |
| [图](../../06-schedule/schedule-journey-delete-error/default.png) · [入口及前驱](../../06-schedule/schedule-journey-delete-error/README.md) | 1 | Delete fails → uncertain snackbar, event retained |
| [图](../../08-expert-service/consultation-journey-current-summary-full-plan/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-full-plan/README.md) | 1 | Summary → full action plan opens Schedule |
| [图](../../06-schedule/schedule-journey-large-picker-saved/default.png) · [入口及前驱](../../06-schedule/schedule-journey-large-picker-saved/README.md) | 1 | Save corrected date/time → selected day agenda |
| [图](../../06-schedule/schedule-journey-delete-cancelled/default.png) · [入口及前驱](../../06-schedule/schedule-journey-delete-cancelled/README.md) | 2 | Keep event → agenda unchanged |
| [图](../../06-schedule/schedule-journey-first-page-end/default.png) · [入口及前驱](../../06-schedule/schedule-journey-first-page-end/README.md) | 2 | Scroll to final loaded event → no load-more control |
| [图](../../06-schedule/schedule-journey-edit-conflict/default.png) · [入口及前驱](../../06-schedule/schedule-journey-edit-conflict/README.md) | 1 | Existing event changed on server → update conflict |
| [图](../../06-schedule/schedule-plan/default.png) · [入口及前驱](../../06-schedule/schedule-plan/README.md) | 1 | published care plan and appointment at 390.0 / 1.0 |

## 实际操作链与状态依据

[SCHEDULE-CURRENT.md](../SCHEDULE-CURRENT.md) · [SCHEDULE-FEEDBACK-CURRENT.md](../SCHEDULE-FEEDBACK-CURRENT.md) · [SCHEDULE-JOURNEYS.md](../SCHEDULE-JOURNEYS.md)

SCHEDULE-FEEDBACK-CURRENT.md：当前主要界面及具名旧反馈状态已核对，其它历史证据保留来源与最终映射边界。

## 有限收尾队列进度

- G05：已完成：当前代表图与完整长图归档，历史操作链保留。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-schedule](../../../ui-refactor/20260914-schedule/HANDOFF.md)：34 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
