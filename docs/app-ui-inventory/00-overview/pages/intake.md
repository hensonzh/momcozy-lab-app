# 咨询信息采集表

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`intake`
- 范围：default
- 入口：预约确认 → 信息采集
- 路由：/services/appointments/:appointmentId/intake
- 实现：[intake_page.dart](../../../../lib/modules/services/presentation/intake_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 已填写
- 补充展开
- 基础信息
- 授权
- 校验
- 保存中
- 错误
- 已保存

## 归属弹窗／浮层

intake-consent、intake-saved

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [service-journey-intake-unfilled](../../08-expert-service/service-journey-intake-unfilled/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已填写 | [service-journey-intake-reopened](../../08-expert-service/service-journey-intake-reopened/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 补充展开 | [intake-optional](../../08-expert-service/intake-optional/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 基础信息 | [intake-profile](../../08-expert-service/intake-profile/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 授权 | [intake-consent](../../08-expert-service/intake-consent/README.md) · [service-journey-intake-consent-withdrawn-draft](../../08-expert-service/service-journey-intake-consent-withdrawn-draft/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 校验 | [intake-consent-validation](../../08-expert-service/intake-consent-validation/README.md) | 实际提交后的授权冲突反馈已截图；前端必填校验由 canSubmit 禁用提交，不能通过普通点击产生 _validated 内的必填错误文案。 |
| 保存中 | [service-journey-intake-saving](../../08-expert-service/service-journey-intake-saving/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [intake-uncertain](../../08-expert-service/intake-uncertain/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已保存 | [intake-saved](../../08-expert-service/intake-saved/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/service-journey-intake-preconsult-completion/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-preconsult-completion/README.md) | 1 | First intake save → completion choices |
| [图](../../08-expert-service/service-journey-intake-saving/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-saving/README.md) | 1 | Save response pending → fields locked |
| [图](../../08-expert-service/service-journey-intake-consent-info/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-consent-info/README.md) | 1 | Information use details → consent explanation dialog |
| [图](../../08-expert-service/intake-sex-menu/default.png) · [入口及前驱](../../08-expert-service/intake-sex-menu/README.md) | 1 | intake profile menus and birth date preserve draft at 1.0 |
| [图](../../08-expert-service/service-journey-intake-birth-calendar/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-birth-calendar/README.md) | 1 | Open prefilled baby birth date calendar |
| [图](../../08-expert-service/intake-consent-validation/default.png) · [入口及前驱](../../08-expert-service/intake-consent-validation/README.md) | 1 | inventory intake server consent validation |
| [图](../../08-expert-service/intake-saved/default.png) · [入口及前驱](../../08-expert-service/intake-saved/README.md) | 1 | intake design disclosures consent and save at 390.0 / 1.0 |
| [图](../../08-expert-service/intake-profile/default.png) · [入口及前驱](../../08-expert-service/intake-profile/README.md) | 1 | intake design disclosures consent and save at 390.0 / 1.0 |
| [图](../../08-expert-service/intake-discard/default.png) · [入口及前驱](../../08-expert-service/intake-discard/README.md) | 1 | intake consent withdrawal and discard preserve edits at 1.0 |
| [图](../../08-expert-service/intake-birth-picker/default.png) · [入口及前驱](../../08-expert-service/intake-birth-picker/README.md) | 1 | intake profile menus and birth date preserve draft at 1.0 |
| [图](../../08-expert-service/service-journey-intake-ready/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-ready/README.md) | 1 | Explicit consent → save enabled |
| [图](../../08-expert-service/intake-optional/default.png) · [入口及前驱](../../08-expert-service/intake-optional/README.md) | 1 | intake design disclosures consent and save at 390.0 / 1.0 |
| [图](../../08-expert-service/intake-consent/default.png) · [入口及前驱](../../08-expert-service/intake-consent/README.md) | 1 | intake design disclosures consent and save at 390.0 / 1.0 |
| [图](../../08-expert-service/service-journey-intake-discard-confirm/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-discard-confirm/README.md) | 1 | Back with edited intake → discard confirmation |
| [图](../../08-expert-service/service-journey-intake-saved/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-saved/README.md) | 1 | Retry original snapshot → intake completion modal |
| [图](../../08-expert-service/service-journey-intake-save-uncertain/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-save-uncertain/README.md) | 1 | Save unavailable → snapshot retained and retry enabled |
| [图](../../08-expert-service/intake-feeding-menu/default.png) · [入口及前驱](../../08-expert-service/intake-feeding-menu/README.md) | 1 | intake profile menus and birth date preserve draft at 1.0 |
| [图](../../08-expert-service/intake-uncertain-leave/default.png) · [入口及前驱](../../08-expert-service/intake-uncertain-leave/README.md) | 1 | intake uncertain save locks fields and retries identical snapshot |
| [图](../../08-expert-service/service-journey-intake-reopened/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-reopened/README.md) | 1 | Reopen saved intake → populated data and granted consent |
| [图](../../08-expert-service/intake-uncertain/default.png) · [入口及前驱](../../08-expert-service/intake-uncertain/README.md) | 1 | intake uncertain save locks fields and retries identical snapshot |
| [图](../../08-expert-service/service-journey-intake-optional-filled/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-optional-filled/README.md) | 1 | Choose concerns, goal and optional background |
| [图](../../08-expert-service/service-journey-intake-region-menu/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-region-menu/README.md) | 1 | Open intake current-state selector |
| [图](../../06-schedule/schedule-journey-appointment-expired-intake/default.png) · [入口及前驱](../../06-schedule/schedule-journey-appointment-expired-intake/README.md) | 2 | Preparation intake link → actual intake route for expired |
| [图](../../08-expert-service/booking-recovery-current-latest-confirmed-intake/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-latest-confirmed-intake/README.md) | 4 | Continue from synchronized confirmation → intake |
| [图](../../08-expert-service/service-journey-intake-consent-withdrawn-draft/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-consent-withdrawn-draft/README.md) | 1 | Uncheck draft consent → save disabled without server mutation |
| [图](../../08-expert-service/service-journey-intake-sex-menu/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-sex-menu/README.md) | 1 | Open recorded sex options |
| [图](../../08-expert-service/service-journey-intake-feeding-menu/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-feeding-menu/README.md) | 1 | Open feeding method selector |
| [图](../../07-me/notification-navigation-current-intake-opened/default.png) · [入口及前驱](../../07-me/notification-navigation-current-intake-opened/README.md) | 1 | Tap notification → validated intake target, notification marked read |
| [图](../../08-expert-service/intake-load-error/default.png) · [入口及前驱](../../08-expert-service/intake-load-error/README.md) | 1 | intake load failure can recover without stale form actions |
| [图](../../08-expert-service/intake-loading/default.png) · [入口及前驱](../../08-expert-service/intake-loading/README.md) | 1 | intake load failure can recover without stale form actions |
| [图](../../08-expert-service/intake-form/default.png) · [入口及前驱](../../08-expert-service/intake-form/README.md) | 1 | intake design disclosures consent and save at 390.0 / 1.0 |
| [图](../../08-expert-service/intake-region-menu/default.png) · [入口及前驱](../../08-expert-service/intake-region-menu/README.md) | 1 | intake profile menus and birth date preserve draft at 1.0 |
| [图](../../08-expert-service/service-journey-intake-load-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-load-error/README.md) | 1 | Confirmed appointment → intake read failure with retry |
| [图](../../08-expert-service/intake/default.png) · [入口及前驱](../../08-expert-service/intake/README.md) | 1 | intake form with missing feeding mode at 390.0 / 1.0 |
| [图](../../08-expert-service/service-journey-intake-loading/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-loading/README.md) | 1 | Retry intake while read pending → loading view |
| [图](../../08-expert-service/consultation-journey-preparation-to-intake/default.png) · [入口及前驱](../../08-expert-service/consultation-journey-preparation-to-intake/README.md) | 6 | Preparation missing-information CTA → actual intake route |
| [图](../../08-expert-service/booking-resume-current-reminder-unavailable-intake/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-reminder-unavailable-intake/README.md) | 1 | Confirm without notification coordinator → saved appointment snackbar and intake |
| [图](../../08-expert-service/service-journey-intake-uncertain-leave/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-uncertain-leave/README.md) | 1 | Back with uncertain save → reconciliation warning |

## 实际操作链与状态依据

[INTAKE-CURRENT.md](../INTAKE-CURRENT.md) · [INTAKE-FEEDBACK-CURRENT.md](../INTAKE-FEEDBACK-CURRENT.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)

[G09 报告](../INTAKE-CURRENT.md) 已归档当前完整表单及两类浮层，保留历史正式入口；其它历史状态版本沿用 G11。

## 有限收尾队列进度

- G09：已完成：表单长图与两类浮层已归属，保留真实操作链。[版本、证据及下一动作](../VISUAL-GAPS.md)。
