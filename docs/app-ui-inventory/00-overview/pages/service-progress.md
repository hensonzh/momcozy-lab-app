# 服务详情与时间线

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`service-progress`
- 范围：default
- 入口：已购计划 → 服务进度
- 路由：/services/episodes/:episodeId
- 实现：[service_progress_page.dart](../../../../lib/modules/services/presentation/service_progress_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 进行中
- 暂停
- 到期
- 次数用尽
- 最近与更早
- 加载
- 错误

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 进行中 | [progress-current-active](../../08-expert-service/progress-current-active/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 暂停 | [progress-current-state-paused](../../08-expert-service/progress-current-state-paused/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 到期 | [progress-current-active-past-end](../../08-expert-service/progress-current-active-past-end/README.md) · [progress-current-state-completed](../../08-expert-service/progress-current-state-completed/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 次数用尽 | [progress-current-active-exhausted](../../08-expert-service/progress-current-active-exhausted/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 最近与更早 | [progress-current-events-earlier](../../08-expert-service/progress-current-events-earlier/README.md) · [progress-current-events-latest](../../08-expert-service/progress-current-events-latest/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [progress-current-initial-loading](../../08-expert-service/progress-current-initial-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [progress-current-initial-error](../../08-expert-service/progress-current-initial-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/progress-current-active-past-end/default.png) · [入口及前驱](../../08-expert-service/progress-current-active-past-end/README.md) | 2 | Server still active after endsAt → current timeline retains booking action |
| [图](../../08-expert-service/progress-empty/default.png) · [入口及前驱](../../08-expert-service/progress-empty/README.md) | 1 | missing service has recoverable empty state |
| [图](../../08-expert-service/progress-current-episode-missing/default.png) · [入口及前驱](../../08-expert-service/progress-current-episode-missing/README.md) | 1 | Retry returns no matching episode → missing service |
| [图](../../08-expert-service/progress-current-initial-loading/default.png) · [入口及前驱](../../08-expert-service/progress-current-initial-loading/README.md) | 1 | Service progress → overview pending |
| [图](../../08-expert-service/service-journey-booking-cancelled-timeline/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-cancelled-timeline/README.md) | 1 | Package service progress → cancellation included in timeline |
| [图](../../08-expert-service/progress-current-appointments-error/default.png) · [入口及前驱](../../08-expert-service/progress-current-appointments-error/README.md) | 1 | Appointment read 503 → service identity retained |
| [图](../../08-expert-service/progress-current-state-paused/default.png) · [入口及前驱](../../08-expert-service/progress-current-state-paused/README.md) | 1 | Refresh server episode paused → supported state and actions |
| [图](../../08-expert-service/progress-current-renew-return/default.png) · [入口及前驱](../../08-expert-service/progress-current-renew-return/README.md) | 2 | Renewal Back → ended timeline |
| [图](../../06-schedule/schedule-journey-plan-route/default.png) · [入口及前驱](../../06-schedule/schedule-journey-plan-route/README.md) | 2 | View care plan → actual episode route |
| [图](../../08-expert-service/progress-current-appointment-return/default.png) · [入口及前驱](../../08-expert-service/progress-current-appointment-return/README.md) | 6 | Appointment Close → timeline |
| [图](../../08-expert-service/consultation-journey-current-summary-to-progress/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-to-progress/README.md) | 1 | Summary service progress → episode timeline |
| [图](../../08-expert-service/progress-offline/default.png) · [入口及前驱](../../08-expert-service/progress-offline/README.md) | 1 | failed appointment read preserves order and retry reads fresh appointments |
| [图](../../08-expert-service/progress-current-events-refresh-recovered/default.png) · [入口及前驱](../../08-expert-service/progress-current-events-refresh-recovered/README.md) | 1 | Retry → synced events and latest position |
| [图](../../03-mom/mom-journey-purchased-progress/default.png) · [入口及前驱](../../03-mom/mom-journey-purchased-progress/README.md) | 2 | Owned plan → actual service timeline route |
| [图](../../08-expert-service/renew-journey-completed-progress/default.png) · [入口及前驱](../../08-expert-service/renew-journey-completed-progress/README.md) | 2 | More → Me → completed service progress; continue support CTA |
| [图](../../08-expert-service/progress-current-active-exhausted/default.png) · [入口及前驱](../../08-expert-service/progress-current-active-exhausted/README.md) | 1 | Active service with zero remaining → no new booking or renewal |
| [图](../../08-expert-service/progress-completed-renewal/default.png) · [入口及前驱](../../08-expert-service/progress-completed-renewal/README.md) | 1 | ended service opens renewal without changing the service |
| [图](../../08-expert-service/service-progress/default.png) · [入口及前驱](../../08-expert-service/service-progress/README.md) | 1 | service progress at 390.0 / 1.0 |
| [图](../../08-expert-service/progress-current-state-provisioning_pending/default.png) · [入口及前驱](../../08-expert-service/progress-current-state-provisioning_pending/README.md) | 1 | Refresh server episode provisioning_pending → supported state and actions |
| [图](../../08-expert-service/progress-current-active/default.png) · [入口及前驱](../../08-expert-service/progress-current-active/README.md) | 5 | Active plan → appointment action |
| [图](../../08-expert-service/progress-current-initial-error/default.png) · [入口及前驱](../../08-expert-service/progress-current-initial-error/README.md) | 2 | Overview 503 → retry card |
| [图](../../08-expert-service/progress-current-refresh-loading/default.png) · [入口及前驱](../../08-expert-service/progress-current-refresh-loading/README.md) | 1 | Pull refresh → retained timeline with progress |
| [图](../../08-expert-service/consultation-journey-summary-to-progress/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-to-progress/README.md) | 1 | Summary service progress → episode timeline |
| [图](../../08-expert-service/progress-current-state-completed/default.png) · [入口及前驱](../../08-expert-service/progress-current-state-completed/README.md) | 1 | Refresh server episode completed → supported state and actions |
| [图](../../08-expert-service/progress-current-events-refresh-error/default.png) · [入口及前驱](../../08-expert-service/progress-current-events-refresh-error/README.md) | 1 | Appointment context 503 → retained old events and retry |
| [图](../../07-me/notification-navigation-current-episode-opened/default.png) · [入口及前驱](../../07-me/notification-navigation-current-episode-opened/README.md) | 1 | Tap notification → validated episode target, notification marked read |
| [图](../../08-expert-service/progress-current-event-in-progress/default.png) · [入口及前驱](../../08-expert-service/progress-current-event-in-progress/README.md) | 2 | Refresh current consultation → in-progress event |
| [图](../../08-expert-service/progress-earlier/default.png) · [入口及前驱](../../08-expert-service/progress-earlier/README.md) | 2 | full timeline navigation at 390.0 / 1.0 |
| [图](../../08-expert-service/progress-current-events-refresh-pending/default.png) · [入口及前驱](../../08-expert-service/progress-current-events-refresh-pending/README.md) | 1 | Pull refresh → existing events while appointment context waits |
| [图](../../08-expert-service/progress-current-appointments-loading/default.png) · [入口及前驱](../../08-expert-service/progress-current-appointments-loading/README.md) | 1 | Overview recovered, appointment context pending |
| [图](../../08-expert-service/progress-short/default.png) · [入口及前驱](../../08-expert-service/progress-short/README.md) | 1 | short display with enlarged text keeps timeline scrollable |
| [图](../../08-expert-service/progress-loading/default.png) · [入口及前驱](../../08-expert-service/progress-loading/README.md) | 1 | pending context and navigation away release safely |

## 实际操作链与状态依据

[PROGRESS-CURRENT.md](../PROGRESS-CURRENT.md)
