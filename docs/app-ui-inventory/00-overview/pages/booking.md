# 预约与预约内详情

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`booking`
- 范围：default
- 入口：已购计划 → 预约咨询
- 路由：/services/episodes/:episodeId/booking
- 实现：[booking_page.dart](../../../../lib/modules/services/presentation/booking_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 前确认入口
- 时段列表
- 保留
- 已确认
- 咨询中
- 业务拒绝
- 等待
- 错误恢复

## 归属弹窗／浮层

booking-precheck、booking-review、appointment-cancel、notification-education

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 前确认入口 | [booking-precheck-current-initial](../../08-expert-service/booking-precheck-current-initial/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 时段列表 | [booking-selection-current-selection-slots](../../08-expert-service/booking-selection-current-selection-slots/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 保留 | [booking-selection-current-held-review](../../08-expert-service/booking-selection-current-held-review/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已确认 | [booking-selection-current-confirmed-detail](../../08-expert-service/booking-selection-current-confirmed-detail/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 咨询中 | [booking-recovery-current-cancel-in-progress-return](../../08-expert-service/booking-recovery-current-cancel-in-progress-return/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 业务拒绝 | [booking-recovery-current-hold-service_not_bookable](../../08-expert-service/booking-recovery-current-hold-service_not_bookable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 等待 | [booking-selection-current-confirm-pending](../../08-expert-service/booking-selection-current-confirm-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误恢复 | [booking-recovery-current-cancel-uncertain](../../08-expert-service/booking-recovery-current-cancel-uncertain/README.md) · [booking-selection-current-confirm-error](../../08-expert-service/booking-selection-current-confirm-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../07-me/notification-followup-registration-pending/default.png) · [入口及前驱](../../07-me/notification-followup-registration-pending/README.md) | 1 | Registration returned no token binding → reminder remains off with Snackbar |
| [图](../../08-expert-service/service-current-paused-booking/default.png) · [入口及前驱](../../08-expert-service/service-current-paused-booking/README.md) | 1 | Package booking action on paused plan → actual eligibility block |
| [图](../../08-expert-service/consultation-journey-current-live-left-booking/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-current-live-left-booking/README.md) | 1 | Temporary leave → booking with ongoing consultation; re-entry remains available |
| [图](../../08-expert-service/booking-selection-current-held-closed/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-held-closed/README.md) | 1 | Close review → time remains held; provider and date disabled |
| [图](../../07-me/notification-followup-registration-waiting/default.png) · [入口及前驱](../../07-me/notification-followup-registration-waiting/README.md) | 1 | Enable reminder → device registration request pending |
| [图](../../08-expert-service/service-journey-booking-date-calendar/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-calendar/README.md) | 1 | Open appointment date calendar |
| [图](../../08-expert-service/service-journey-booking-date-selected/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-selected/README.md) | 1 | Select September 14 in calendar before confirmation |
| [图](../../07-me/notification-journey-reminder-read-error/default.png) · [入口及前驱](../../07-me/notification-journey-reminder-read-error/README.md) | 1 | Booking reminder read fails → localized retry |
| [图](../../08-expert-service/booking-precheck-current-server-emergency_help/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-server-emergency_help/README.md) | 1 | Continue → server ineligible: emergency_help |
| [图](../../08-expert-service/booking-selection-current-date-after-window/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-after-window/README.md) | 1 | Confirm beyond 90 days → out-of-range error |
| [图](../../08-expert-service/booking-precheck-current-closed/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-closed/README.md) | 2 | Close precheck → start confirmation card |
| [图](../../08-expert-service/booking-recovery-current-eligibility-reopened/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-eligibility-reopened/README.md) | 1 | Expired precheck → Start confirmation with prior choices retained |
| [图](../../07-me/notification-followup-registration-http-error/default.png) · [入口及前驱](../../07-me/notification-followup-registration-http-error/README.md) | 1 | Retry reminder → installation HTTP error and feedback |
| [图](../../08-expert-service/booking-recovery-current-cancel-query-error/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-query-error/README.md) | 3 | Query HTTP 503 → uncertainty retained |
| [图](../../08-expert-service/booking-emergency/default.png) · [入口及前驱](../../08-expert-service/booking-emergency/README.md) | 1 | booking precheck and held dialog flow at 390.0 / 1.0 |
| [图](../../08-expert-service/consultation-journey-left-to-booking/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-left-to-booking/README.md) | 1 | Confirm temporary leave → actual booking route; consultation not ended |
| [图](../../08-expert-service/booking-selection-current-provider-return/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-provider-return/README.md) | 1 | Switch back to Pacific expert → keep date and change timezone |
| [图](../../08-expert-service/booking-recovery-current-cancel-open/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-open/README.md) | 2 | Cancel appointment → confirmation dialog |
| [图](../../08-expert-service/booking-recovery-current-hold-hold_expired/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-hold_expired/README.md) | 1 | Select time → HTTP 409 business rejection: hold_expired |
| [图](../../08-expert-service/booking-held/default.png) · [入口及前驱](../../08-expert-service/booking-held/README.md) | 1 | booking precheck and held dialog flow at 390.0 / 1.0 |
| [图](../../08-expert-service/booking-precheck-current-region-menu/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-region-menu/README.md) | 1 | Current state dropdown → CA / NY / TX choices |
| [图](../../07-me/notification-followup-registration-retry-enabled/default.png) · [入口及前驱](../../07-me/notification-followup-registration-retry-enabled/README.md) | 2 | Retry after token recovery → reminder saved and enabled |
| [图](../../08-expert-service/booking-recovery-current-hold-appointment_exists/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-appointment_exists/README.md) | 1 | Select time → HTTP 409 business rejection: appointment_exists |
| [图](../../08-expert-service/booking-recovery-current-cancel-query-pending/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-query-pending/README.md) | 1 | Query latest appointment → pending |
| [图](../../08-expert-service/booking-precheck-current-suitable-cleared/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-suitable-cleared/README.md) | 1 | Uncheck service suitability → continue disabled |
| [图](../../08-expert-service/booking-precheck-current-submit-error/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-submit-error/README.md) | 1 | Pending back blocked; eligibility HTTP 503 → retryable notice |
| [图](../../08-expert-service/booking-resume-current-reminder-selected/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-reminder-selected/README.md) | 2 | Select reminder before confirming |
| [图](../../07-me/notification-journey-permission-denied/default.png) · [入口及前驱](../../07-me/notification-journey-permission-denied/README.md) | 3 | Platform denies permission → reminder stays off with feedback |
| [图](../../08-expert-service/booking-precheck-current-availability-empty/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-empty/README.md) | 1 | Availability succeeds with no slots |
| [图](../../08-expert-service/booking-precheck-current-server-region_not_supported/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-server-region_not_supported/README.md) | 1 | Continue → server ineligible: region_not_supported |
| [图](../../08-expert-service/booking-precheck-current-suitable/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-suitable/README.md) | 1 | Check lactation or feeding consultation suitability |
| [图](../../08-expert-service/service-journey-booking-held/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-held/README.md) | 2 | Select slot → server hold and confirm time dialog |
| [图](../../08-expert-service/booking-precheck-current-context-loading/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-context-loading/README.md) | 1 | Book consultation → booking context pending |
| [图](../../08-expert-service/booking-resume-current-configured-reminder-enabled/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-configured-reminder-enabled/README.md) | 1 | Confirm booking → permission explanation → deny → intake → booking reminder → system settings offer → refreshed authorization → enable |
| [图](../../08-expert-service/booking-selection-current-hold-pending/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-hold-pending/README.md) | 1 | Select available time → hold request pending |
| [图](../../08-expert-service/booking-recovery-current-hold-service_not_bookable/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-service_not_bookable/README.md) | 1 | Select time → HTTP 409 business rejection: service_not_bookable |
| [图](../../08-expert-service/booking-recovery-current-latest-confirmed-return/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-latest-confirmed-return/README.md) | 1 | Unchanged intake Back → confirmed appointment |
| [图](../../07-me/notification-journey-reminder-education/default.png) · [入口及前驱](../../07-me/notification-journey-reminder-education/README.md) | 1 | Enable appointment reminder → permission education |
| [图](../../08-expert-service/booking-selection-current-date-before-today/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-before-today/README.md) | 1 | Confirm past date → out-of-range error |
| [图](../../08-expert-service/progress-current-event-booking/default.png) · [入口及前驱](../../08-expert-service/progress-current-event-booking/README.md) | 1 | Timeline booking with confirmed appointment → existing appointment detail |
| [图](../../08-expert-service/booking-resume-current-hold-unknown/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-hold-unknown/README.md) | 2 | Hold HTTP 503 → retry action |
| [图](../../07-me/notification-journey-push-unavailable/default.png) · [入口及前驱](../../07-me/notification-journey-push-unavailable/README.md) | 1 | Server push delivery unavailable → no reminder write and explanation |
| [图](../../08-expert-service/service-journey-booking-date-applied/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-applied/README.md) | 1 | Confirm another date → availability reloaded |
| [图](../../08-expert-service/booking-confirm-uncertain/default.png) · [入口及前驱](../../08-expert-service/booking-confirm-uncertain/README.md) | 1 | held confirmation blocks back, retries original version then opens intake once |
| [图](../../08-expert-service/booking-resume-current-cancel-unknown/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-cancel-unknown/README.md) | 4 | Reselect held time → cancellation HTTP 503 |
| [图](../../08-expert-service/booking-hold-expired/default.png) · [入口及前驱](../../08-expert-service/booking-hold-expired/README.md) | 1 | expired hold removes confirm and reselect does not cancel expired data |
| [图](../../08-expert-service/booking-selection-current-confirm-pending/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-confirm-pending/README.md) | 2 | Confirm held appointment → expected-version request pending |
| [图](../../08-expert-service/booking-selection-current-provider-menu/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-provider-menu/README.md) | 1 | Provider dropdown → two available experts |
| [图](../../08-expert-service/service-journey-booking-no-slots/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-no-slots/README.md) | 1 | Slot retry returns no availability → empty state |
| [图](../../08-expert-service/booking/default.png) · [入口及前驱](../../08-expert-service/booking/README.md) | 1 | booking date and expert selection at 390.0 / 1.0 |
| [图](../../08-expert-service/booking-recovery-current-cancel-pending/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-pending/README.md) | 1 | Confirm cancellation → request pending and dismissal disabled |
| [图](../../08-expert-service/booking-selection-current-date-applied/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-applied/README.md) | 1 | Confirm date → September 14 availability |
| [图](../../08-expert-service/booking-recovery-current-latest-confirmed/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-latest-confirmed/README.md) | 1 | Query latest reveals confirmed → continue intake action |
| [图](../../08-expert-service/booking-precheck-current-submit-pending/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-submit-pending/README.md) | 1 | Continue → eligibility request pending; controls disabled |
| [图](../../08-expert-service/booking-selection-current-date-open/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-open/README.md) | 1 | Open date picker; large text uses input only |
| [图](../../08-expert-service/booking-recovery-current-cancel-no-longer-allowed/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-no-longer-allowed/README.md) | 1 | Query latest in_progress → cannot cancel, return action |
| [图](../../08-expert-service/booking-recovery-current-hold-region_unavailable/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-region_unavailable/README.md) | 1 | Select time → HTTP 409 business rejection: region_unavailable |
| [图](../../08-expert-service/service-journey-booking-held-collapsed/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-held-collapsed/README.md) | 1 | Close time confirmation → hold retained on booking page |
| [图](../../08-expert-service/booking-selection-current-date-valid-input/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-valid-input/README.md) | 1 | Enter tomorrow → valid date draft |
| [图](../../08-expert-service/service-journey-booking-provider-menu/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-provider-menu/README.md) | 1 | Open provider selector |
| [图](../../08-expert-service/booking-resume-current-cancel-closed/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-cancel-closed/README.md) | 3 | Close unresolved held cancellation → page retry |
| [图](../../08-expert-service/service-journey-booking-region-blocked/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-region-blocked/README.md) | 1 | Unsupported booking region → cannot continue |
| [图](../../08-expert-service/booking-selection-current-date-invalid/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-invalid/README.md) | 1 | Confirm malformed date → validation error |
| [图](../../08-expert-service/booking-precheck-current-region-supported/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-region-supported/README.md) | 1 | Select CA → suitable service region |
| [图](../../08-expert-service/booking-precheck-current-availability-pending/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-pending/README.md) | 1 | Eligibility accepted → availability pending; dialog remains waiting |
| [图](../../07-me/notification-journey-permission-settings-offer/default.png) · [入口及前驱](../../07-me/notification-journey-permission-settings-offer/README.md) | 1 | Enable after denial → offer system settings |
| [图](../../08-expert-service/booking-recovery-current-confirm-version-conflict/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-confirm-version-conflict/README.md) | 1 | New hold confirmation HTTP 409 → query latest state |
| [图](../../03-mom/mom-journey-purchased-booking-cancel-precheck/default.png) · [入口及前驱](../../03-mom/mom-journey-purchased-booking-cancel-precheck/README.md) | 1 | Cancel suitability check → booking page |
| [图](../../08-expert-service/booking-recovery-current-latest-expired/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-latest-expired/README.md) | 1 | Query latest returns expired → reselect remains |
| [图](../../08-expert-service/service-journey-booking-cancel-confirm/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-cancel-confirm/README.md) | 1 | Cancel appointment → cancellation confirmation |
| [图](../../08-expert-service/service-journey-booking-date-input/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-input/README.md) | 1 | Switch appointment date picker to typed input |
| [图](../../07-me/notification-followup-registration-token-error/default.png) · [入口及前驱](../../07-me/notification-followup-registration-token-error/README.md) | 1 | Retry reminder → push token error and feedback |
| [图](../../08-expert-service/service-journey-booking-availability-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-availability-error/README.md) | 1 | Refresh with slot read failure → error and retained selection |
| [图](../../08-expert-service/booking-unavailable/default.png) · [入口及前驱](../../08-expert-service/booking-unavailable/README.md) | 1 | booking precheck and held dialog flow at 390.0 / 1.0 |
| [图](../../08-expert-service/service-journey-booking-date-invalid/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-invalid/README.md) | 1 | Submit malformed appointment date → inline validation |
| [图](../../08-expert-service/booking-recovery-current-confirm-hold-expired/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-confirm-hold-expired/README.md) | 1 | Confirm rejected with hold_expired → query latest action |
| [图](../../07-me/notification-journey-notification-preference-disabled/default.png) · [入口及前驱](../../07-me/notification-journey-notification-preference-disabled/README.md) | 1 | Reminder rejected by server: notification_preference_disabled |
| [图](../../08-expert-service/consultation-journey-preparation-rebook/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-rebook/README.md) | 1 | Expired preparation rebook → actual booking route |
| [图](../../08-expert-service/booking-recovery-current-hold-timeout/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-timeout/README.md) | 1 | Injected device clock passes hold expiry → reselect notice |
| [图](../../08-expert-service/booking-precheck-current-emergency-help/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-emergency-help/README.md) | 1 | Select emergency or uncertain → urgent help notice |
| [图](../../07-me/notification-followup-registration-disabled/default.png) · [入口及前驱](../../07-me/notification-followup-registration-disabled/README.md) | 5 | Turn reminder off → saved disabled |
| [图](../../08-expert-service/service-journey-booking-cancel-retained/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-cancel-retained/README.md) | 2 | Keep appointment → confirmed details unchanged |
| [图](../../03-mom/mom-journey-purchased-booking-precheck/default.png) · [入口及前驱](../../03-mom/mom-journey-purchased-booking-precheck/README.md) | 5 | Book from home → actual booking route and suitability dialog |
| [图](../../08-expert-service/service-journey-booking-emergency/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-emergency/README.md) | 1 | Potential emergency selected → guidance and disabled booking |
| [图](../../08-expert-service/service-journey-booking-cancel-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-cancel-error/README.md) | 1 | Cancel request fails → original operation retained |
| [图](../../08-expert-service/booking-recovery-current-cancel-in-progress-return/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-in-progress-return/README.md) | 1 | Return → refreshed in-progress appointment detail |
| [图](../../08-expert-service/booking-selection-current-date-year-menu/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-year-menu/README.md) | 1 | Calendar header → year selection |
| [图](../../08-expert-service/booking-precheck/default.png) · [入口及前驱](../../08-expert-service/booking-precheck/README.md) | 1 | booking precheck and held dialog flow at 390.0 / 1.0 |
| [图](../../08-expert-service/booking-precheck-current-availability-retry-pending/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-retry-pending/README.md) | 1 | Retry availability → picker loading spinner |
| [图](../../08-expert-service/booking-recovery-current-hold-eligibility_required/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-eligibility_required/README.md) | 1 | Select time → HTTP 409 business rejection: eligibility_required |
| [图](../../08-expert-service/service-journey-booking-confirm-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-confirm-error/README.md) | 1 | Confirm hold unavailable → retry original confirmation |
| [图](../../08-expert-service/booking-precheck-current-context-error/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-context-error/README.md) | 1 | Booking context returns HTTP 503 |
| [图](../../08-expert-service/booking-precheck-current-availability-ready/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-ready/README.md) | 2 | Complete region, suitability and risk inputs |
| [图](../../08-expert-service/service-journey-booking-hold-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-hold-error/README.md) | 1 | Hold unavailable → uncertain submission and retry CTA |
| [图](../../08-expert-service/booking-selection-current-date-day-selected/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-day-selected/README.md) | 1 | Select September 14, awaiting confirmation |
| [图](../../08-expert-service/booking-recovery-current-after-timeout-held/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-after-timeout-held/README.md) | 8 | Select time again → fresh hold |
| [图](../../08-expert-service/booking-precheck-current-accepted-slots/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-accepted-slots/README.md) | 19 | Retry accepted → provider, date and available/occupied times |
| [图](../../08-expert-service/booking-selection-current-date-next-month/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-next-month/README.md) | 1 | Next month → October calendar |
| [图](../../08-expert-service/booking-precheck-current-availability-error/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-error/README.md) | 1 | Availability HTTP 503 → picker with retry error |
| [图](../../08-expert-service/booking-recovery-current-hold-slot_unavailable/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-hold-slot_unavailable/README.md) | 1 | Select time → HTTP 409 business rejection: slot_unavailable |
| [图](../../08-expert-service/booking-precheck-current-server-service_unsuitable/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-server-service_unsuitable/README.md) | 1 | Continue → server ineligible: service_unsuitable |
| [图](../../08-expert-service/booking-precheck-current-region-unsupported/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-region-unsupported/README.md) | 1 | Select NY → unsupported region notice |
| [图](../../08-expert-service/booking-selection-current-provider-loading/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-provider-loading/README.md) | 1 | Select east coast expert → new timezone and times pending |
| [图](../../08-expert-service/booking-recovery-current-cancel-confirmed/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-confirmed/README.md) | 5 | Confirm → intake → Back to confirmed detail |
| [图](../../08-expert-service/booking-selection-current-date-cancelled/default.png) · [入口及前驱](../../08-expert-service/booking-selection-current-date-cancelled/README.md) | 2 | Cancel date input → prior September 13 preserved |
| [图](../../08-expert-service/service-journey-intake-saved-return/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-saved-return/README.md) | 2 | Save complete then view appointment → confirmed detail |
| [图](../../08-expert-service/booking-resume-current-confirm-reopened/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-confirm-reopened/README.md) | 1 | View selected time → unresolved review restored |
| [图](../../08-expert-service/booking-precheck-current-initial/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-initial/README.md) | 7 | Retry booking context → automatic precheck |
| [图](../../08-expert-service/service-journey-booking-date-cancelled/default.png) · [入口及前驱](../../08-expert-service/service-journey-booking-date-cancelled/README.md) | 2 | Cancel invalid date → original slot date retained |
| [图](../../07-me/notification-journey-reminder-expired/default.png) · [入口及前驱](../../07-me/notification-journey-reminder-expired/README.md) | 1 | Reminder rejected by server: reminder_expired |

## 实际操作链与状态依据

[BOOKING-PRECHECK-CURRENT.md](../BOOKING-PRECHECK-CURRENT.md) · [BOOKING-SELECTION-CURRENT.md](../BOOKING-SELECTION-CURRENT.md) · [BOOKING-RECOVERY-CURRENT.md](../BOOKING-RECOVERY-CURRENT.md) · [BOOKING-REMINDER-ENTRY-CURRENT.md](../BOOKING-REMINDER-ENTRY-CURRENT.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)

## 有限收尾队列进度

- G07：已完成：正式协调器下预约提醒入口及授权恢复链已核对。[版本、证据及下一动作](../VISUAL-GAPS.md)。
