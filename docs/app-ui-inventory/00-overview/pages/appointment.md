# 独立预约详情

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`appointment`
- 范围：default
- 入口：通知或日程 → 指定预约
- 路由：/services/appointments/:appointmentId
- 实现：[appointment_detail_page.dart](../../../../lib/modules/services/presentation/appointment_detail_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- held
- confirmed
- in_progress
- completed
- cancelled
- expired
- 加载
- 错误

## 归属弹窗／浮层

appointment-cancel、notification-education

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| held | [appointment-held](../../08-expert-service/appointment-held/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| confirmed | [appointment-detail](../../08-expert-service/appointment-detail/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| in_progress | [appointment-in-progress](../../00-overview/reused-state-evidence/appointment-in-progress/README.md) | REUSED_RENDERED_EVIDENCE; scoped source hashes match; route proven separately |
| completed | [appointment-completed](../../00-overview/reused-state-evidence/appointment-completed/README.md) | REUSED_RENDERED_EVIDENCE; scoped source hashes match; route proven separately |
| cancelled | [appointment-cancelled](../../08-expert-service/appointment-cancelled/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| expired | [appointment-expired](../../08-expert-service/appointment-expired/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [appointment-loading](../../00-overview/reused-state-evidence/appointment-loading/README.md) | REUSED_RENDERED_EVIDENCE; scoped source hashes match; route proven separately |
| 错误 | [appointment-unavailable](../../08-expert-service/appointment-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/appointment-cancelled/default.png) · [入口及前驱](../../08-expert-service/appointment-cancelled/README.md) | 1 | appointment actions follow cancelled state |
| [图](../../08-expert-service/appointment-detail/default.png) · [入口及前驱](../../08-expert-service/appointment-detail/README.md) | 1 | appointment detail at 390.0 / 1.0 |
| [图](../../08-expert-service/appointment-held/default.png) · [入口及前驱](../../08-expert-service/appointment-held/README.md) | 1 | appointment actions follow held state |
| [图](../../08-expert-service/appointment-unavailable/default.png) · [入口及前驱](../../08-expert-service/appointment-unavailable/README.md) | 1 | appointment read failure retries instead of showing stale actions |
| [图](../../08-expert-service/appointment-cancel-uncertain/default.png) · [入口及前驱](../../08-expert-service/appointment-cancel-uncertain/README.md) | 1 | cancel pending locks return and retry uses original appointment version |
| [图](../../08-expert-service/appointment-expired/default.png) · [入口及前驱](../../08-expert-service/appointment-expired/README.md) | 1 | appointment actions follow expired state |
| [图](../../08-expert-service/appointment-cancel/default.png) · [入口及前驱](../../08-expert-service/appointment-cancel/README.md) | 1 | appointment keep and cancel at 390.0 / 1.0 |
| [图](../../07-me/notification-current-notification-to-appointment/default.png) · [入口及前驱](../../07-me/notification-current-notification-to-appointment/README.md) | 3 | Open available update → validated UUID appointment route |

## 实际操作链与状态依据

[BOOKING-RECOVERY-CURRENT.md](../BOOKING-RECOVERY-CURRENT.md) · [NOTIFICATION-NAVIGATION-CURRENT.md](../NOTIFICATION-NAVIGATION-CURRENT.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)

## 已有改版运行图，优先复用

- [20260914-appointment-detail](../../../ui-refactor/20260914-appointment-detail/HANDOFF.md)：5 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
