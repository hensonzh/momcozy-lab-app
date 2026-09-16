# 咨询总结与后续任务

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`summary`
- 范围：default
- 入口：咨询结束或通知 → 总结
- 路由：/services/appointments/:appointmentId/summary
- 实现：[consultation_summary_page.dart](../../../../lib/modules/services/presentation/consultation_summary_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 首次加载
- 待发布
- 尚未产生总结
- 咨询未完成
- 读取失败及重试
- 已发布：当前行动／后续行动／观察目标／更多帮助
- 无行动
- 服务信息折叠／展开
- 行动详情及四种进度
- 更新中与关闭禁用
- 更新结果不确定及重试
- 方案替换及重新载入
- 行动移除提示
- 刷新失败保留内容
- 完整行动计划与服务进度入口

## 归属弹窗／浮层

summary-task-detail

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 首次加载 | [summary-loading](../../08-expert-service/summary-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 待发布 | [summary-pending](../../08-expert-service/summary-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 尚未产生总结 | [summary-empty](../../08-expert-service/summary-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 咨询未完成 | [summary-failed-320-2x-short](../../08-expert-service/summary-failed-320-2x-short/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 读取失败及重试 | [summary-offline](../../08-expert-service/summary-offline/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已发布：当前行动／后续行动／观察目标／更多帮助 | [summary-published](../../08-expert-service/summary-published/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 无行动 | [summary-no-actions-information-320-2x-short](../../08-expert-service/summary-no-actions-information-320-2x-short/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 服务信息折叠／展开 | [summary-metadata](../../08-expert-service/summary-metadata/README.md) · [consultation-journey-current-summary-service-information](../../08-expert-service/consultation-journey-current-summary-service-information/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 行动详情及四种进度 | [consultation-journey-current-summary-task-detail](../../08-expert-service/consultation-journey-current-summary-task-detail/README.md) · [consultation-journey-current-summary-task-in-progress](../../08-expert-service/consultation-journey-current-summary-task-in-progress/README.md) · [consultation-journey-current-summary-task-skipped](../../08-expert-service/consultation-journey-current-summary-task-skipped/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 更新中与关闭禁用 | [summary-short-updating-320-2x-short](../../08-expert-service/summary-short-updating-320-2x-short/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 更新结果不确定及重试 | [summary-short-uncertain-320-2x-short](../../08-expert-service/summary-short-uncertain-320-2x-short/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 方案替换及重新载入 | [summary-superseded](../../08-expert-service/summary-superseded/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 行动移除提示 | [summary-removed-action](../../08-expert-service/summary-removed-action/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 刷新失败保留内容 | [summary-refresh-error](../../08-expert-service/summary-refresh-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 完整行动计划与服务进度入口 | [consultation-journey-current-summary-full-plan](../../08-expert-service/consultation-journey-current-summary-full-plan/README.md) · [consultation-journey-current-summary-to-progress](../../08-expert-service/consultation-journey-current-summary-to-progress/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/summary-empty/default.png) · [入口及前驱](../../08-expert-service/summary-empty/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-summary-service-information/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-service-information/README.md) | 1 | Expand consultation and service information → progress entry |
| [图](../../08-expert-service/summary-short-uncertain-320-2x-short/default.png) · [入口及前驱](../../08-expert-service/summary-short-uncertain-320-2x-short/README.md) | 1 | short large task keeps pending updates locked and retryable |
| [图](../../07-me/notification-navigation-current-summary-load-error/default.png) · [入口及前驱](../../07-me/notification-navigation-current-summary-load-error/README.md) | 1 | Notification → summary GET 503 → unavailable card with retry |
| [图](../../08-expert-service/consultation-journey-current-summary-task-uncertain/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-task-uncertain/README.md) | 1 | Task update unavailable → previous progress retained, retry required |
| [图](../../08-expert-service/summary-superseded/default.png) · [入口及前驱](../../08-expert-service/summary-superseded/README.md) | 1 | superseded action removed by reload remains safely closable at large text |
| [图](../../08-expert-service/summary-refresh-error/default.png) · [入口及前驱](../../08-expert-service/summary-refresh-error/README.md) | 1 | refresh failure retains publication and reloads without a task mutation |
| [图](../../08-expert-service/consultation-journey-summary-task-detail/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-task-detail/README.md) | 1 | Published task → action detail and progress choices |
| [图](../../08-expert-service/summary-metadata/default.png) · [入口及前驱](../../08-expert-service/summary-metadata/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-safety-summary-pending/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-safety-summary-pending/README.md) | 2 | Safety escalation outcome → summary publication pending |
| [图](../../08-expert-service/consultation-journey-current-summary-task-in-progress/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-task-in-progress/README.md) | 1 | Set task progress → persisted in-progress state |
| [图](../../08-expert-service/consultation-journey-summary-task-in-progress/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-task-in-progress/README.md) | 1 | Set task progress → persisted in-progress state |
| [图](../../08-expert-service/consultation-journey-current-outcome-summary/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-outcome-summary/README.md) | 1 | Outcome → 查看咨询总结; shared destination for equivalent outcome CTAs |
| [图](../../08-expert-service/summary-short-updating-320-2x-short/default.png) · [入口及前驱](../../08-expert-service/summary-short-updating-320-2x-short/README.md) | 1 | short large task keeps pending updates locked and retryable |
| [图](../../08-expert-service/consultation-journey-summary-task-uncertain/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-task-uncertain/README.md) | 1 | Task update unavailable → previous progress retained, retry required |
| [图](../../08-expert-service/summary-short-progress-320-2x-short/default.png) · [入口及前驱](../../08-expert-service/summary-short-progress-320-2x-short/README.md) | 1 | short large task keeps pending updates locked and retryable |
| [图](../../08-expert-service/consultation-journey-summary-task-skipped/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-task-skipped/README.md) | 1 | Change completed task to skipped → explicit progress state |
| [图](../../08-expert-service/summary-failed-320-2x-short/default.png) · [入口及前驱](../../08-expert-service/summary-failed-320-2x-short/README.md) | 1 | empty action list and unsuccessful consultation keep appropriate destinations |
| [图](../../08-expert-service/summary-no-actions-information-320-2x-short/default.png) · [入口及前驱](../../08-expert-service/summary-no-actions-information-320-2x-short/README.md) | 1 | empty action list and unsuccessful consultation keep appropriate destinations |
| [图](../../08-expert-service/summary-task/default.png) · [入口及前驱](../../08-expert-service/summary-task/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../06-schedule/schedule-journey-consultation-summary-route/default.png) · [入口及前驱](../../06-schedule/schedule-journey-consultation-summary-route/README.md) | 4 | Completed appointment summary → actual published summary route |
| [图](../../08-expert-service/summary-uncertain/default.png) · [入口及前驱](../../08-expert-service/summary-uncertain/README.md) | 1 | task uncertainty retries original version and locks competing updates |
| [图](../../08-expert-service/consultation-journey-current-summary-task-detail/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-task-detail/README.md) | 1 | Published task → action detail and progress choices |
| [图](../../08-expert-service/consultation-journey-current-summary-service-information/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-service-information/README.md) | 1 | Expand consultation and service information → progress entry |
| [图](../../08-expert-service/summary-offline/default.png) · [入口及前驱](../../08-expert-service/summary-offline/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-current-summary-task-recovered/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-task-recovered/README.md) | 1 | Retry original progress update → completed state |
| [图](../../08-expert-service/consultation-journey-summary-task-recovered/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-summary-task-recovered/README.md) | 1 | Retry original progress update → completed state |
| [图](../../08-expert-service/consultation-journey-current-summary-published/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-published/README.md) | 2 | Periodic pending-summary refresh receives published plan |
| [图](../../08-expert-service/progress-current-event-summary/default.png) · [入口及前驱](../../08-expert-service/progress-current-event-summary/README.md) | 1 | Completed event → published summary |
| [图](../../08-expert-service/summary-pending/default.png) · [入口及前驱](../../08-expert-service/summary-pending/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../08-expert-service/summary-removed-action/default.png) · [入口及前驱](../../08-expert-service/summary-removed-action/README.md) | 1 | superseded action removed by reload remains safely closable at large text |
| [图](../../08-expert-service/summary-published/default.png) · [入口及前驱](../../08-expert-service/summary-published/README.md) | 1 | summary content task and destinations 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-current-summary-task-skipped/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-summary-task-skipped/README.md) | 1 | Change completed task to skipped → explicit progress state |
| [图](../../08-expert-service/summary-loading/default.png) · [入口及前驱](../../08-expert-service/summary-loading/README.md) | 1 | loading finishes into pending and refreshed publication |

## 实际操作链与状态依据

[CONSULTATION-SUMMARY-CURRENT.md](../CONSULTATION-SUMMARY-CURRENT.md)

G03 按实际渲染分支细化状态；未发现总结页独立的“未授权”设计状态，认证跳转或接口失败沿共享登录／错误流程归档，不制造新总结页面。

## 有限收尾队列进度

- G03：已完成：总结、行动状态、长图及日程/进度去向已核对。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-consultation-summary](../../../ui-refactor/20260914-consultation-summary/HANDOFF.md)：9 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
