# 泌乳记录与趋势

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`mom-lactation`
- 范围：default
- 入口：妈妈首页 → 查看记录
- 路由：/me/lactation
- 实现：[lactation_page.dart](../../../../lib/modules/mom/presentation/lactation_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 空记录
- 有记录与趋势
- 日期切换
- 加载
- 错误
- 删除与撤销

## 归属弹窗／浮层

lactation-editor

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 空记录 | [mom-journey-milk-history-empty](../../03-mom/mom-journey-milk-history-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 有记录与趋势 | [lactation-current-overview](../../03-mom/lactation-current-overview/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 日期切换 | [lactation-current-30-days](../../03-mom/lactation-current-30-days/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [lactation-current-loading](../../03-mom/lactation-current-loading/README.md) | REUSED_RENDERED_EVIDENCE; scoped source hashes match; route proven separately |
| 错误 | [lactation-current-read-error](../../03-mom/lactation-current-read-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 删除与撤销 | [lactation-current-restored](../../03-mom/lactation-current-restored/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../03-mom/mom-journey-trend-seven-days/default.png) · [入口及前驱](../../03-mom/mom-journey-trend-seven-days/README.md) | 2 | Home history → seven-day measured curve with gaps |
| [图](../../03-mom/lactation-current-save-conflict/default.png) · [入口及前驱](../../03-mom/lactation-current-save-conflict/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/lactation-entry/default.png) · [入口及前驱](../../03-mom/lactation-entry/README.md) | 1 | lactation entry renders at 390.0 / 1.0 |
| [图](../../03-mom/lactation-dialog-nurse/default.png) · [入口及前驱](../../03-mom/lactation-dialog-nurse/README.md) | 1 | lactation modal switches to nursing and saves at 390.0 / 1.0 |
| [图](../../03-mom/milk-state-editing/default.png) · [入口及前驱](../../03-mom/milk-state-editing/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-history-empty/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-empty/README.md) | 2 | Home View records → empty standalone lactation history |
| [图](../../03-mom/mom-journey-milk-uncertain-save/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-uncertain-save/README.md) | 1 | Unavailable create response → uncertain result and retry controls |
| [图](../../03-mom/mom-milk-control-cancel-confirm/default.png) · [入口及前驱](../../03-mom/mom-milk-control-cancel-confirm/README.md) | 1 | Cancel unchanged lactation editor → confirmation still shown |
| [图](../../03-mom/milk-state-empty/default.png) · [入口及前驱](../../03-mom/milk-state-empty/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-leave-confirm/default.png) · [入口及前驱](../../03-mom/lactation-current-leave-confirm/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-time-dial/default.png) · [入口及前驱](../../03-mom/lactation-current-time-dial/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-uncertain-retried/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-uncertain-retried/README.md) | 1 | Retry same pending save → saved list |
| [图](../../03-mom/mom-journey-trend-thirty-days/default.png) · [入口及前驱](../../03-mom/mom-journey-trend-thirty-days/README.md) | 1 | Select 30 days → expanded period and older measurements |
| [图](../../03-mom/mom-journey-milk-delete-failed/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-delete-failed/README.md) | 1 | Delete rejected → record stays visible with error |
| [图](../../03-mom/mom-journey-nursing-saved/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-saved/README.md) | 1 | Response received → saved nursing history |
| [图](../../03-mom/mom-milk-control-history-reopened/default.png) · [入口及前驱](../../03-mom/mom-milk-control-history-reopened/README.md) | 1 | History Edit → saved nursing with empty duration and retained note |
| [图](../../03-mom/lactation-current-time-invalid/default.png) · [入口及前驱](../../03-mom/lactation-current-time-invalid/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/milk-state-uncertain/default.png) · [入口及前驱](../../03-mom/milk-state-uncertain/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-history-deleted/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-deleted/README.md) | 1 | Delete record directly → deletion feedback with undo |
| [图](../../03-mom/mom-journey-milk-history-edit/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-edit/README.md) | 1 | History edit → record editor |
| [图](../../03-mom/mom-journey-nursing-empty/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-empty/README.md) | 1 | History Add → switch to nursing form |
| [图](../../03-mom/mom-journey-milk-history-restored/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-restored/README.md) | 1 | Retry undo → record restored |
| [图](../../03-mom/milk-state-optional-keyboard/default.png) · [入口及前驱](../../03-mom/milk-state-optional-keyboard/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-saving/default.png) · [入口及前驱](../../03-mom/lactation-current-saving/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/milk-state-updated/default.png) · [入口及前驱](../../03-mom/milk-state-updated/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-nursing-time-picker/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-time-picker/README.md) | 1 | Record time → time picker |
| [图](../../03-mom/mom-journey-nursing-cancel-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-cancel-confirm/README.md) | 1 | Cancel record → discard confirmation |
| [图](../../03-mom/milk-state-restored/default.png) · [入口及前驱](../../03-mom/milk-state-restored/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-nursing-time-input/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-time-input/README.md) | 1 | Time picker → keyboard time entry |
| [图](../../03-mom/lactation-current-delete-error/default.png) · [入口及前驱](../../03-mom/lactation-current-delete-error/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-30-days/default.png) · [入口及前驱](../../03-mom/lactation-current-30-days/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-nursing-optional-filled/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-optional-filled/README.md) | 1 | Expand feeling and notes → enter optional observation |
| [图](../../03-mom/lactation-current-restore-error/default.png) · [入口及前驱](../../03-mom/lactation-current-restore-error/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-restored/default.png) · [入口及前驱](../../03-mom/lactation-current-restored/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-history-updated/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-updated/README.md) | 1 | Save changed volume → refreshed history and update feedback |
| [图](../../03-mom/mom-journey-nursing-cancel-retained/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-cancel-retained/README.md) | 1 | Continue editing → all entered fields remain |
| [图](../../03-mom/lactation-current-long-note-end/default.png) · [入口及前驱](../../03-mom/lactation-current-long-note-end/README.md) | 3 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-restore-error/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-restore-error/README.md) | 1 | Undo → API failure preserves undo entry |
| [图](../../03-mom/mom-journey-nursing-new-discarded/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-new-discarded/README.md) | 1 | Cancel another new record and discard → existing history unchanged |
| [图](../../03-mom/lactation-dialog-pump/default.png) · [入口及前驱](../../03-mom/lactation-dialog-pump/README.md) | 1 | lactation modal switches to nursing and saves at 390.0 / 1.0 |
| [图](../../03-mom/mom-journey-milk-conflict-reloaded/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-conflict-reloaded/README.md) | 1 | Discard conflict draft → latest saved list |
| [图](../../03-mom/milk-state-nurse/default.png) · [入口及前驱](../../03-mom/milk-state-nurse/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-conflict/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-conflict/README.md) | 1 | Edit saved milk and receive conflict → draft preserved |
| [图](../../03-mom/mom-journey-milk-history-read-error/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history-read-error/README.md) | 1 | Enter standalone lactation page → records request error |
| [图](../../05-agent/agent-workflow-journey-milk-history/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-milk-history/README.md) | 1 | Tap artifact link → actual lactation history |
| [图](../../03-mom/mom-journey-milk-history/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-history/README.md) | 1 | Home View records → standalone lactation history/trend |
| [图](../../03-mom/mom-journey-nursing-saving/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-saving/README.md) | 1 | Submit nursing while response pending → saving state |
| [图](../../03-mom/lactation-current-uncertain-leave/default.png) · [入口及前驱](../../03-mom/lactation-current-uncertain-leave/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/lactation-current-time-input/default.png) · [入口及前驱](../../03-mom/lactation-current-time-input/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/milk-state-validation/default.png) · [入口及前驱](../../03-mom/milk-state-validation/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-nursing-duration-invalid/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-duration-invalid/README.md) | 1 | Submit duration over limit → validation |
| [图](../../03-mom/lactation-list/default.png) · [入口及前驱](../../03-mom/lactation-list/README.md) | 1 | lactation list renders at 390.0 / 1.0 |
| [图](../../03-mom/lactation-current-saved-zero/default.png) · [入口及前驱](../../03-mom/lactation-current-saved-zero/README.md) | 1 | lactation route time input validates and pending save locks edits 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-uncertain-leave-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-uncertain-leave-confirm/README.md) | 1 | Close uncertain record → reconciliation warning |
| [图](../../03-mom/mom-milk-control-cancel-return-history/default.png) · [入口及前驱](../../03-mom/mom-milk-control-cancel-return-history/README.md) | 2 | Confirm leave → history retains version 2 |
| [图](../../03-mom/lactation-current-read-error/default.png) · [入口及前驱](../../03-mom/lactation-current-read-error/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |
| [图](../../03-mom/milk-state-saved/default.png) · [入口及前驱](../../03-mom/milk-state-saved/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-nursing-time-invalid/default.png) · [入口及前驱](../../03-mom/mom-journey-nursing-time-invalid/README.md) | 1 | Invalid hour → time picker error |
| [图](../../03-mom/milk-state-deleted/default.png) · [入口及前驱](../../03-mom/milk-state-deleted/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/mom-journey-milk-conflict-reload-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-conflict-reload-confirm/README.md) | 1 | Reload conflicted milk → discard confirmation |
| [图](../../03-mom/milk-state-pump/default.png) · [入口及前驱](../../03-mom/milk-state-pump/README.md) | 1 | lactation states validate, retry, edit and undo 390.0/1.0 |
| [图](../../03-mom/lactation-current-loading/default.png) · [入口及前驱](../../03-mom/lactation-current-loading/README.md) | 1 | lactation route reads, charts, long notes, conflicts and undo 390.0/1.0 |

## 实际操作链与状态依据

[MOM-JOURNEYS.md](../MOM-JOURNEYS.md) · [MOM-MILK-CONTROLS.md](../MOM-MILK-CONTROLS.md) · [MOM-MILK-VALIDATION.md](../MOM-MILK-VALIDATION.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md) · [LACTATION-VERSION-CURRENT.md](../LACTATION-VERSION-CURRENT.md)
