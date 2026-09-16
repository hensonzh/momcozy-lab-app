# 咨询准备、通话与结束

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`consultation`
- 范围：default
- 入口：预约详情 → 咨询前准备／进入咨询
- 路由：/services/appointments/:appointmentId/room
- 实现：[room_page.dart](../../../../lib/modules/consultation/presentation/room_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 准备
- 等待专家
- 可进入
- 通话
- 断线与恢复
- 离开
- 结束
- 取消
- 过期
- 加载
- 错误

## 归属弹窗／浮层

appointment-cancel、device-check、video-consent、consultation-start、consultation-leave

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 准备 | [consultation-journey-preparation-intake-required](../../08-expert-service/consultation-journey-preparation-intake-required/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 等待专家 | [video-waiting](../../08-expert-service/video-waiting/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 可进入 | [consultation-journey-preparation-ready](../../08-expert-service/consultation-journey-preparation-ready/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 通话 | [consultation-journey-current-live-active](../../08-expert-service/consultation-journey-current-live-active/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 断线与恢复 | [video-disconnected](../../08-expert-service/video-disconnected/README.md) · [video-reconnecting](../../08-expert-service/video-reconnecting/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 离开 | [consultation-journey-current-live-leave-confirmation](../../08-expert-service/consultation-journey-current-live-leave-confirmation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 结束 | [consultation-journey-current-completed-outcome](../../08-expert-service/consultation-journey-current-completed-outcome/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 取消 | [consultation-journey-current-cancelled-outcome](../../08-expert-service/consultation-journey-current-cancelled-outcome/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 过期 | [consultation-journey-preparation-window-expired](../../08-expert-service/consultation-journey-preparation-window-expired/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [consultation-journey-current-room-loading](../../08-expert-service/consultation-journey-current-room-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [consultation-journey-current-room-load-error](../../08-expert-service/consultation-journey-current-room-load-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/consultation-journey-location-rejected/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-location-rejected/README.md) | 1 | Confirm unsupported current location → server blocks entry |
| [图](../../08-expert-service/consultation-journey-video-consent/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-video-consent/README.md) | 1 | Video authorization CTA → explicit episode consent dialog |
| [图](../../08-expert-service/consultation-journey-video-consent-selected/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-video-consent-selected/README.md) | 1 | Consent checked → confirmation enabled, no grant before submit |
| [图](../../08-expert-service/consultation-journey-preparation-demo-early/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-demo-early/README.md) | 1 | Server allows sandbox early join → test-mode preparation |
| [图](../../08-expert-service/device-checking/default.png) · [入口及前驱](../../08-expert-service/device-checking/README.md) | 1 | device check pending partial failure retry ready 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-location-selected/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-location-selected/README.md) | 1 | Choose New York → current location draft changes |
| [图](../../08-expert-service/consultation-journey-current-live-reentry-preparation/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-live-reentry-preparation/README.md) | 1 | Booking → return to consultation → preparation offers re-entry |
| [图](../../08-expert-service/consultation-journey-current-completed-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-completed-outcome/README.md) | 1 | Me → service → booking → preparation → device check → enter; server completed → result |
| [图](../../08-expert-service/consultation-journey-no-show-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-no-show-outcome/README.md) | 1 | Server passes attendance deadline without a join → no-show outcome actions |
| [图](../../08-expert-service/preparation-intake/default.png) · [入口及前驱](../../08-expert-service/preparation-intake/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-join-request-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-join-request-error/README.md) | 1 | Location passes and room prepares; join unavailable → awaiting recovery |
| [图](../../08-expert-service/preflight-consent-offline/default.png) · [入口及前驱](../../08-expert-service/preflight-consent-offline/README.md) | 1 | consent retry preserves video scope and original version |
| [图](../../08-expert-service/consultation-journey-current-no-show-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-no-show-outcome/README.md) | 1 | Me → service → booking → preparation without joining; attendance deadline passes → no-show result |
| [图](../../08-expert-service/consultation-journey-current-video-consent-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-video-consent-error/README.md) | 1 | Video consent submit fails → selected consent retained in dialog |
| [图](../../08-expert-service/consultation-journey-current-before-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-before-outcome/README.md) | 1 | Me → expert plan → my service → booking → preparation → device check → confirm entry |
| [图](../../08-expert-service/preflight-offline/default.png) · [入口及前驱](../../08-expert-service/preflight-offline/README.md) | 1 | location network failure retries without joining prematurely |
| [图](../../08-expert-service/consultation-journey-video-consent-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-video-consent-error/README.md) | 1 | Submit episode video consent → request unavailable; dialog remains open |
| [图](../../08-expert-service/preflight-preparing/default.png) · [入口及前驱](../../08-expert-service/preflight-preparing/README.md) | 1 | closing a preparing room cancels pending automatic join |
| [图](../../08-expert-service/preparation-demo/default.png) · [入口及前驱](../../08-expert-service/preparation-demo/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-current-join-request-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-join-request-error/README.md) | 1 | Location accepted → join fails, start dialog awaits recovery |
| [图](../../08-expert-service/video-leave/default.png) · [入口及前驱](../../08-expert-service/video-leave/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/video-reconnecting/default.png) · [入口及前驱](../../08-expert-service/video-reconnecting/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/room-device/default.png) · [入口及前驱](../../08-expert-service/room-device/README.md) | 1 | device check states 390.0 / 1.0 |
| [图](../../08-expert-service/room-leave-failure/default.png) · [入口及前驱](../../08-expert-service/room-leave-failure/README.md) | 1 | leave recovery 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-device-recovered/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-device-recovered/README.md) | 1 | Retry device APIs after permission recovery → ready |
| [图](../../08-expert-service/preflight-region-blocked/default.png) · [入口及前驱](../../08-expert-service/preflight-region-blocked/README.md) | 1 | device consent region and enter 390.0 / 1.0 |
| [图](../../08-expert-service/video-disconnected/default.png) · [入口及前驱](../../08-expert-service/video-disconnected/README.md) | 2 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-preparation-case-consent-required/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-case-consent-required/README.md) | 1 | Refresh room with withdrawn case consent → sharing notice |
| [图](../../08-expert-service/preparation-ready/default.png) · [入口及前驱](../../08-expert-service/preparation-ready/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-room-load-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-room-load-error/README.md) | 1 | Initial room request fails → retry state |
| [图](../../08-expert-service/room-entry-modal-error/default.png) · [入口及前驱](../../08-expert-service/room-entry-modal-error/README.md) | 1 | entry loads, retries one request and recovers true/390.0/1.0 |
| [图](../../08-expert-service/consultation-journey-current-room-load-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-room-load-error/README.md) | 1 | Initial room read fails → retry feedback |
| [图](../../08-expert-service/room-end-confirm/default.png) · [入口及前驱](../../08-expert-service/room-end-confirm/README.md) | 1 | expert end reason sheet and cancel 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-safety-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-safety-outcome/README.md) | 1 | Server safety_escalation → session disconnect and outcome actions |
| [图](../../08-expert-service/consultation-journey-current-technical-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-technical-outcome/README.md) | 1 | Me → service → booking → preparation → device check → enter; server technical_failure → result |
| [图](../../08-expert-service/consultation-journey-current-live-leave-confirmation/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-live-leave-confirmation/README.md) | 1 | Me → service → booking → preparation → passed checks → room → Leave |
| [图](../../08-expert-service/home-preparation-ready/default.png) · [入口及前驱](../../08-expert-service/home-preparation-ready/README.md) | 1 | home preparation closes, cancels and enters through existing checks 390.0/1.0 |
| [图](../../08-expert-service/room-preparation/default.png) · [入口及前驱](../../08-expert-service/room-preparation/README.md) | 1 | consultation preparation at 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-technical-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-technical-outcome/README.md) | 1 | Server technical_failure → session disconnect and outcome actions |
| [图](../../08-expert-service/consultation-journey-video-consent-granted/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-video-consent-granted/README.md) | 2 | Submit video consent → actual start confirmation restored |
| [图](../../08-expert-service/progress-current-event-appointment/default.png) · [入口及前驱](../../08-expert-service/progress-current-event-appointment/README.md) | 1 | Confirmed event → appointment detail |
| [图](../../08-expert-service/room-no-show/default.png) · [入口及前驱](../../08-expert-service/room-no-show/README.md) | 1 | unsuccessful room outcomes 390.0 / 1.0 |
| [图](../../08-expert-service/room-device-error/default.png) · [入口及前驱](../../08-expert-service/room-device-error/README.md) | 1 | device check states 390.0 / 1.0 |
| [图](../../06-schedule/schedule-journey-appointment-room-route/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-room-route/README.md) | 7 | Confirmed consultation view → real preparation route |
| [图](../../08-expert-service/video-media-error/default.png) · [入口及前驱](../../08-expert-service/video-media-error/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/preflight-consent-required/default.png) · [入口及前驱](../../08-expert-service/preflight-consent-required/README.md) | 1 | device consent region and enter 390.0 / 1.0 |
| [图](../../08-expert-service/video-camera-off/default.png) · [入口及前驱](../../08-expert-service/video-camera-off/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/room-location/default.png) · [入口及前驱](../../08-expert-service/room-location/README.md) | 1 | room location and consent 390.0 / 1.0 |
| [图](../../08-expert-service/preflight-consent/default.png) · [入口及前驱](../../08-expert-service/preflight-consent/README.md) | 1 | device consent region and enter 390.0 / 1.0 |
| [图](../../06-schedule/schedule-journey-appointment-cancelled-route/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-cancelled-route/README.md) | 1 | Appointment action → actual room preparation for cancelled |
| [图](../../08-expert-service/room-outcome/default.png) · [入口及前驱](../../08-expert-service/room-outcome/README.md) | 1 | ended room destinations 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-preparation-window-expired/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-window-expired/README.md) | 1 | Entry window elapsed → rebook action |
| [图](../../08-expert-service/room-leave-retry-confirmation/default.png) · [入口及前驱](../../08-expert-service/room-leave-retry-confirmation/README.md) | 1 | leave recovery 390.0 / 1.0 |
| [图](../../08-expert-service/room-entry-page-error/default.png) · [入口及前驱](../../08-expert-service/room-entry-page-error/README.md) | 1 | entry loads, retries one request and recovers false/390.0/1.0 |
| [图](../../06-schedule/schedule-journey-appointment-expired-intake-return/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-expired-intake-return/README.md) | 4 | Unchanged intake system back → preparation |
| [图](../../08-expert-service/consultation-journey-location-request-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-location-request-error/README.md) | 1 | Correct location then confirm → network failure, no room join |
| [图](../../08-expert-service/device-ready/default.png) · [入口及前驱](../../08-expert-service/device-ready/README.md) | 1 | device check pending partial failure retry ready 390.0 / 1.0 |
| [图](../../08-expert-service/home-preparation-cancel/default.png) · [入口及前驱](../../08-expert-service/home-preparation-cancel/README.md) | 1 | home preparation closes, cancels and enters through existing checks 390.0/1.0 |
| [图](../../08-expert-service/consultation-journey-current-pending-record-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-pending-record-outcome/README.md) | 1 | Me → service → booking → preparation → device check → enter; server pending-record → result |
| [图](../../08-expert-service/consultation-journey-consultation-active/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-consultation-active/README.md) | 2 | Server reports expert joined and consultation started → active room |
| [图](../../08-expert-service/consultation-journey-current-live-active/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-live-active/README.md) | 1 | Stay and close confirmation both retain the room; expert joins → active consultation |
| [图](../../08-expert-service/consultation-journey-room-loading/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-room-loading/README.md) | 1 | Booking preparation CTA → room initial request pending |
| [图](../../08-expert-service/consultation-journey-current-safety-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-safety-outcome/README.md) | 1 | Me → service → booking → preparation → device check → enter; server safety_escalation → result |
| [图](../../08-expert-service/consultation-journey-preparation-video-disabled/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-video-disabled/README.md) | 1 | Video service disabled → unavailable explanation |
| [图](../../08-expert-service/video-expert-ready/default.png) · [入口及前驱](../../08-expert-service/video-expert-ready/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/room-technical-failure/default.png) · [入口及前驱](../../08-expert-service/room-technical-failure/README.md) | 1 | unsuccessful room outcomes 390.0 / 1.0 |
| [图](../../08-expert-service/device-continue/default.png) · [入口及前驱](../../08-expert-service/device-continue/README.md) | 1 | preflight continues only after readiness and an explicit tap |
| [图](../../08-expert-service/consultation-journey-join-poll-recovered/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-join-poll-recovered/README.md) | 6 | Actual room poll retries pending join → waiting room connected |
| [图](../../08-expert-service/consultation-journey-device-checking/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-device-checking/README.md) | 1 | Device probe pending → permission check in progress |
| [图](../../08-expert-service/room-end-reason/default.png) · [入口及前驱](../../08-expert-service/room-end-reason/README.md) | 1 | expert end reason sheet and cancel 390.0 / 1.0 |
| [图](../../08-expert-service/video-media-audio-enabled/default.png) · [入口及前驱](../../08-expert-service/video-media-audio-enabled/README.md) | 1 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-preparation-intake-required/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-intake-required/README.md) | 1 | Booking consultation preparation → missing intake blocks start |
| [图](../../08-expert-service/consultation-journey-location-options/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-location-options/README.md) | 1 | Open current state selector → supported choices |
| [图](../../08-expert-service/room-leave-pending/default.png) · [入口及前驱](../../08-expert-service/room-leave-pending/README.md) | 1 | inventory leave pending then returns |
| [图](../../08-expert-service/consultation-journey-device-denied/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-device-denied/README.md) | 1 | Start consultation → device API denial shown in check dialog |
| [图](../../08-expert-service/preparation-disabled/default.png) · [入口及前驱](../../08-expert-service/preparation-disabled/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-leave-confirmation/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-leave-confirmation/README.md) | 1 | Leave waiting room → confirmation overlay |
| [图](../../08-expert-service/consultation-journey-consultation-completed/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-consultation-completed/README.md) | 1 | Server ends consultation → disconnected outcome and summary CTA |
| [图](../../08-expert-service/consultation-journey-current-cancelled-outcome/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-cancelled-outcome/README.md) | 1 | Me → service → booking → preparation → device check → enter; server cancelled → result |
| [图](../../08-expert-service/video-controls/default.png) · [入口及前驱](../../08-expert-service/video-controls/README.md) | 2 | user waiting media controls and leave 390.0 x 844.0 / 1.0 |
| [图](../../08-expert-service/preparation-expired/default.png) · [入口及前驱](../../08-expert-service/preparation-expired/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/room-entry-page-loading/default.png) · [入口及前驱](../../08-expert-service/room-entry-page-loading/README.md) | 1 | entry loads, retries one request and recovers false/390.0/1.0 |
| [图](../../08-expert-service/preflight-short-blocked-footer/default.png) · [入口及前驱](../../08-expert-service/preflight-short-blocked-footer/README.md) | 1 | short screen enlarged text keeps consent and region reachable |
| [图](../../08-expert-service/device-error/default.png) · [入口及前驱](../../08-expert-service/device-error/README.md) | 1 | device check pending partial failure retry ready 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-preparation-too-early/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-too-early/README.md) | 1 | Server entry window not open → start disabled and opening time shown |
| [图](../../08-expert-service/home-preparation-room/default.png) · [入口及前驱](../../08-expert-service/home-preparation-room/README.md) | 2 | home preparation closes, cancels and enters through existing checks 390.0/1.0 |
| [图](../../07-me/notification-navigation-current-room-opened/default.png) · [入口及前驱](../../07-me/notification-navigation-current-room-opened/README.md) | 1 | Tap notification → validated room target, notification marked read |
| [图](../../08-expert-service/room-entry-modal-loading/default.png) · [入口及前驱](../../08-expert-service/room-entry-modal-loading/README.md) | 1 | entry loads, retries one request and recovers true/390.0/1.0 |
| [图](../../08-expert-service/consultation-journey-current-room-loading/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-room-loading/README.md) | 1 | Booking → consultation preparation, initial room read pending |
| [图](../../08-expert-service/consultation-journey-current-location-request-error/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-location-request-error/README.md) | 1 | Confirm current location → request fails, entry remains blocked |
| [图](../../08-expert-service/preparation-early/default.png) · [入口及前驱](../../08-expert-service/preparation-early/README.md) | 1 | preparation time and requirements 390.0 / 1.0 |
| [图](../../08-expert-service/preflight-ready/default.png) · [入口及前驱](../../08-expert-service/preflight-ready/README.md) | 1 | device consent region and enter 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-start-confirmation/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-start-confirmation/README.md) | 2 | Device check success → location and missing video consent |
| [图](../../08-expert-service/progress-current-in-progress-room/default.png) · [入口及前驱](../../08-expert-service/progress-current-in-progress-room/README.md) | 1 | In-progress event → active consultation entry |

## 实际操作链与状态依据

[CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT.md](../CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT.md) · [CONSULTATION-LIVE-CURRENT.md](../CONSULTATION-LIVE-CURRENT.md) · [CONSULTATION-OUTCOME-CURRENT.md](../CONSULTATION-OUTCOME-CURRENT.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)

G01/G02 与 G11 准备反馈已核对；其余原条目在最终映射保留来源和版本。

## 有限收尾队列进度

- G01：已完成：当前正式路由、完整页面及全部 11 个结果 CTA 已核对。[版本、证据及下一动作](../VISUAL-GAPS.md)。
- G02：已完成：当前通话、离开/留在/重入链及媒体反馈已核对。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-consultation-entry](../../../ui-refactor/20260914-consultation-entry/HANDOFF.md)：28 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
- [20260914-consultation-live-room](../../../ui-refactor/20260914-consultation-live-room/HANDOFF.md)：7 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
- [20260914-consultation-outcomes](../../../ui-refactor/20260914-consultation-outcomes/HANDOFF.md)：6 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
- [20260914-consultation-summary](../../../ui-refactor/20260914-consultation-summary/HANDOFF.md)：9 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
