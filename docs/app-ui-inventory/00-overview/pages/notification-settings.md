# 通知设置

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`notification-settings`
- 范围：default
- 入口：通知中心 → Settings
- 路由：/notifications/settings
- 实现：[notification_settings_page.dart](../../../../lib/features/notifications/presentation/notification_settings_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 分类开关
- 未申请
- 允许
- 拒绝
- 设备注册中
- 注册错误
- 不可用

## 归属弹窗／浮层

notification-education

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 分类开关 | [notification-permission-current-permission-restored-enabled](../../07-me/notification-permission-current-permission-restored-enabled/README.md) · [notification-permission-current-permission-restored-disabled](../../07-me/notification-permission-current-permission-restored-disabled/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 未申请 | [notification-permission-current-education-ready](../../07-me/notification-permission-current-education-ready/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 允许 | [notification-permission-current-request-authorized](../../07-me/notification-permission-current-request-authorized/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 拒绝 | [notification-permission-current-education-denied](../../07-me/notification-permission-current-education-denied/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 设备注册中 | [notification-permission-current-registration-pending](../../07-me/notification-permission-current-registration-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 注册错误 | [notification-permission-current-registration-http-error](../../07-me/notification-permission-current-registration-http-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 不可用 | [notification-permission-current-registration-sdk-unavailable](../../07-me/notification-permission-current-registration-sdk-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../07-me/notification-permission-current-registration-waiting/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-waiting/README.md) | 1 | Refresh status → installation request pending, categories disabled |
| [图](../../07-me/notification-journey-preferences-loading/default.png) · [入口及前驱](../../07-me/notification-journey-preferences-loading/README.md) | 1 | Retry preferences → loading and switches disabled |
| [图](../../07-me/notifications-settings/default.png) · [入口及前驱](../../07-me/notifications-settings/README.md) | 1 | notification settings and consent at 390.0 / 1.0 |
| [图](../../07-me/notification-permission-current-education-back-dismissed/default.png) · [入口及前驱](../../07-me/notification-permission-current-education-back-dismissed/README.md) | 4 | Framework back → education dismissed with off feedback |
| [图](../../10-global-modals/native-permission-deny-system-settings-on/default.png) · [入口及前驱](../../10-global-modals/native-permission-deny-system-settings-on/README.md) | 1 | Turn on Android master switch → enabled; system Back returns to App |
| [图](../../07-me/notification-permission-current-education-feedback-dismissed/default.png) · [入口及前驱](../../07-me/notification-permission-current-education-feedback-dismissed/README.md) | 2 | Feedback timeout → original settings |
| [图](../../07-me/notification-journey-category-service-updates-off/default.png) · [入口及前驱](../../07-me/notification-journey-category-service-updates-off/README.md) | 1 | Disable Service updates notifications |
| [图](../../07-me/notification-current-inbox-to-settings/default.png) · [入口及前驱](../../07-me/notification-current-inbox-to-settings/README.md) | 1 | Inbox settings toolbar → notification preferences |
| [图](../../07-me/notification-current-preferences-initial-error/default.png) · [入口及前驱](../../07-me/notification-current-preferences-initial-error/README.md) | 1 | Initial preferences 503 → error and no editable values |
| [图](../../07-me/notification-current-preference-write-pending/default.png) · [入口及前驱](../../07-me/notification-current-preference-write-pending/README.md) | 1 | Disable consultations → pending write, all switches disabled |
| [图](../../07-me/notification-journey-preference-write-error/default.png) · [入口及前驱](../../07-me/notification-journey-preference-write-error/README.md) | 1 | Enable consultation category fails → previous switch value and Snackbar retained |
| [图](../../07-me/notification-journey-category-expert-feedback-on/default.png) · [入口及前驱](../../07-me/notification-journey-category-expert-feedback-on/README.md) | 3 | Re-enable Expert feedback → persisted preference |
| [图](../../07-me/notification-permission-current-education-before-back/default.png) · [入口及前驱](../../07-me/notification-permission-current-education-before-back/README.md) | 6 | Enable again → education before back |
| [图](../../07-me/notification-followup-settings-refresh-waiting/default.png) · [入口及前驱](../../07-me/notification-followup-settings-refresh-waiting/README.md) | 1 | Refresh status → registration pending and categories disabled |
| [图](../../07-me/notification-current-appointments-on/default.png) · [入口及前驱](../../07-me/notification-current-appointments-on/README.md) | 10 | Enable appointments → saved true |
| [图](../../07-me/notification-journey-settings-push-unavailable/default.png) · [入口及前驱](../../07-me/notification-journey-settings-push-unavailable/README.md) | 1 | Settings retains preferences while background push unavailable |
| [图](../../07-me/native-permission-allow-not-requested/default.png) · [入口及前驱](../../07-me/native-permission-allow-not-requested/README.md) | 2 | Inbox toolbar → not requested, category off |
| [图](../../07-me/notification-journey-settings-denied/default.png) · [入口及前驱](../../07-me/notification-journey-settings-denied/README.md) | 1 | Notification settings after denial → system permission off |
| [图](../../10-global-modals/native-permission-allow-system-request/default.png) · [入口及前驱](../../10-global-modals/native-permission-allow-system-request/README.md) | 1 | App Continue → actual Android request; choose allow |
| [图](../../07-me/notification-permission-current-registration-http-error/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-http-error/README.md) | 1 | Registration 503 → settings error, category values retained |
| [图](../../07-me/more-current-notification-settings/default.png) · [入口及前驱](../../07-me/more-current-notification-settings/README.md) | 3 | Inbox settings → real preferences and authorization state |
| [图](../../07-me/notification-current-expert_feedback-off/default.png) · [入口及前驱](../../07-me/notification-current-expert_feedback-off/README.md) | 1 | Disable expert_feedback → saved false |
| [图](../../07-me/notification-journey-appointments-disabled/default.png) · [入口及前驱](../../07-me/notification-journey-appointments-disabled/README.md) | 1 | Disable appointment notifications category |
| [图](../../07-me/native-permission-allow-education/default.png) · [入口及前驱](../../07-me/native-permission-allow-education/README.md) | 1 | Enable category → App permission explanation |
| [图](../../07-me/notification-current-preference-write-error/default.png) · [入口及前驱](../../07-me/notification-current-preference-write-error/README.md) | 1 | Write 503 → prior switch value plus Snackbar |
| [图](../../07-me/native-permission-deny-settings-offer/default.png) · [入口及前驱](../../07-me/native-permission-deny-settings-offer/README.md) | 1 | Enable after denial → offer Android settings |
| [图](../../07-me/notification-permission-current-education-denied/default.png) · [入口及前驱](../../07-me/notification-permission-current-education-denied/README.md) | 3 | Continue → simulated native denial, settings off and Snackbar |
| [图](../../07-me/notification-current-preferences-initial-loading/default.png) · [入口及前驱](../../07-me/notification-current-preferences-initial-loading/README.md) | 1 | Open settings → preference request pending, switches disabled |
| [图](../../07-me/notification-current-settings-unavailable/default.png) · [入口及前驱](../../07-me/notification-current-settings-unavailable/README.md) | 1 | Unavailable platform and SDK → delivery unavailable |
| [图](../../07-me/notification-journey-preference-write-retry/default.png) · [入口及前驱](../../07-me/notification-journey-preference-write-retry/README.md) | 2 | Retry enabling consultation category → saved |
| [图](../../07-me/notification-followup-settings-token-error/default.png) · [入口及前驱](../../07-me/notification-followup-settings-token-error/README.md) | 1 | Refresh → SDK token unavailable |
| [图](../../07-me/notification-followup-settings-registration-error/default.png) · [入口及前驱](../../07-me/notification-followup-settings-registration-error/README.md) | 1 | Registration HTTP failure → settings error and unavailable delivery |
| [图](../../07-me/native-permission-deny-education/default.png) · [入口及前驱](../../07-me/native-permission-deny-education/README.md) | 1 | Enable category → App permission explanation |
| [图](../../07-me/notification-current-settings-provisional/default.png) · [入口及前驱](../../07-me/notification-current-settings-provisional/README.md) | 1 | Refresh after quiet authorization → delivery available |
| [图](../../07-me/notification-journey-category-expert-feedback-off/default.png) · [入口及前驱](../../07-me/notification-journey-category-expert-feedback-off/README.md) | 1 | Disable Expert feedback notifications |
| [图](../../07-me/notification-permission-current-education-ready/default.png) · [入口及前驱](../../07-me/notification-permission-current-education-ready/README.md) | 2 | Notification center settings → preferences |
| [图](../../07-me/native-permission-allow-allowed/default.png) · [入口及前驱](../../07-me/native-permission-allow-allowed/README.md) | 2 | Android allow → permission refreshed and category result |
| [图](../../07-me/native-permission-allow-category-disabled/default.png) · [入口及前驱](../../07-me/native-permission-allow-category-disabled/README.md) | 3 | Disable service category; Android permission remains allowed |
| [图](../../07-me/notification-permission-current-direct-settings-error/default.png) · [入口及前驱](../../07-me/notification-permission-current-direct-settings-error/README.md) | 1 | Direct Settings → platform opening error and Snackbar |
| [图](../../07-me/notification-current-consultations-off/default.png) · [入口及前驱](../../07-me/notification-current-consultations-off/README.md) | 2 | Disable consultations → saved false |
| [图](../../07-me/notification-journey-permission-platform-unavailable/default.png) · [入口及前驱](../../07-me/notification-journey-permission-platform-unavailable/README.md) | 1 | Platform reports unavailable and push SDK unavailable → settings explain delivery boundary |
| [图](../../07-me/notification-followup-settings-ready/default.png) · [入口及前驱](../../07-me/notification-followup-settings-ready/README.md) | 6 | Inbox settings → registered device |
| [图](../../07-me/notification-journey-preferences-read-error/default.png) · [入口及前驱](../../07-me/notification-journey-preferences-read-error/README.md) | 1 | Refresh preferences fails → inline error |
| [图](../../07-me/notification-current-settings-denied/default.png) · [入口及前驱](../../07-me/notification-current-settings-denied/README.md) | 2 | Refresh after simulated system denial → unavailable delivery labels |
| [图](../../07-me/notification-permission-current-offer-settings-dialog/default.png) · [入口及前驱](../../07-me/notification-permission-current-offer-settings-dialog/README.md) | 2 | Enable after denial → system-settings explanation |
| [图](../../10-global-modals/native-permission-deny-system-request/default.png) · [入口及前驱](../../10-global-modals/native-permission-deny-system-request/README.md) | 1 | App Continue → actual Android request; choose deny |
| [图](../../07-me/native-permission-deny-denied/default.png) · [入口及前驱](../../07-me/native-permission-deny-denied/README.md) | 1 | Android deny → permission refreshed and category result |
| [图](../../07-me/notification-current-appointments-off/default.png) · [入口及前驱](../../07-me/notification-current-appointments-off/README.md) | 4 | Disable appointments → saved false |
| [图](../../07-me/notification-permission-current-registration-pending-enable/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-pending-enable/README.md) | 1 | Enable while token registration pending → Snackbar, no preference write |
| [图](../../07-me/notification-permission-current-registration-ready/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-ready/README.md) | 1 | Notification center settings → preferences |
| [图](../../07-me/notification-permission-current-registration-token-error/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-token-error/README.md) | 1 | Refresh → SDK token exception |
| [图](../../10-global-modals/native-permission-deny-system-settings-off/default.png) · [入口及前驱](../../10-global-modals/native-permission-deny-system-settings-off/README.md) | 1 | App Open settings → Android notification master switch off |
| [图](../../07-me/notification-followup-settings-registration-pending/default.png) · [入口及前驱](../../07-me/notification-followup-settings-registration-pending/README.md) | 1 | Refresh → server token registration pending |
| [图](../../07-me/notifications-consent/default.png) · [入口及前驱](../../07-me/notifications-consent/README.md) | 1 | notification settings and consent at 390.0 / 1.0 |
| [图](../../07-me/notification-journey-category-consultations-off/default.png) · [入口及前驱](../../07-me/notification-journey-category-consultations-off/README.md) | 1 | Disable Consultations notifications |
| [图](../../07-me/notification-current-service_updates-off/default.png) · [入口及前驱](../../07-me/notification-current-service_updates-off/README.md) | 1 | Disable service_updates → saved false |
| [图](../../07-me/notification-permission-current-registration-null-token/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-null-token/README.md) | 2 | Refresh → SDK returns no token, registration pending |
| [图](../../07-me/notification-permission-current-registration-sdk-unavailable/default.png) · [入口及前驱](../../07-me/notification-permission-current-registration-sdk-unavailable/README.md) | 2 | Refresh → SDK unavailable, in-app inbox remains |

## 实际操作链与状态依据

[NOTIFICATION-PERMISSION-CURRENT.md](../NOTIFICATION-PERMISSION-CURRENT.md) · [NATIVE-NOTIFICATION-PERMISSIONS.md](../NATIVE-NOTIFICATION-PERMISSIONS.md)
