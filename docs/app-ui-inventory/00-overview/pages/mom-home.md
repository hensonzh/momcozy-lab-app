# 妈妈首页

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`mom-home`
- 范围：default
- 入口：Me Tab
- 路由：/me
- 实现：[mother_home_page.dart](../../../../lib/modules/mom/presentation/mother_home_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 有记录
- 已购服务
- 部分数据
- 加载
- 局部错误

## 归属弹窗／浮层

mom-diary-editor、lactation-editor、knowledge、appointment-cancel、home-consultation、device-check、video-consent、consultation-start

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [mom-handoff-initial-top](../../03-mom/mom-handoff-initial-top/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 有记录 | [mom-handoff-recorded-top](../../03-mom/mom-handoff-recorded-top/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已购服务 | [mom-handoff-purchased-top](../../03-mom/mom-handoff-purchased-top/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 部分数据 | [mom-partial-records](../../03-mom/mom-partial-records/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [mom-loading](../../03-mom/mom-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 局部错误 | [mom-diary-error](../../03-mom/mom-diary-error/README.md) · [mom-insight-unavailable](../../03-mom/mom-insight-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../03-mom/mom-rest-control-duration-underThreeHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-underThreeHours/README.md) | 1 | Rest / 昨夜大约睡了多久 → select <3 小时 |
| [图](../../03-mom/mom-milk-control-comfort-comfortable-cleared/default.png) · [入口及前驱](../../03-mom/mom-milk-control-comfort-comfortable-cleared/README.md) | 5 | Tap 舒服 again → comfort cleared |
| [图](../../03-mom/mom-diary-error/default.png) · [入口及前驱](../../03-mom/mom-diary-error/README.md) | 1 | inventory mom diary-error |
| [图](../../03-mom/mom-mood-control-home-refreshed/default.png) · [入口及前驱](../../03-mom/mom-mood-control-home-refreshed/README.md) | 2 | Close saved mood → refreshed home with steady mood |
| [图](../../03-mom/mom-rest-control-disruption-other/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-other/README.md) | 1 | Rest / 影响休息的原因 → select 其他 |
| [图](../../03-mom/mom-milk-dial-accepted/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-accepted/README.md) | 1 | Confirm dial → draft 11:20 |
| [图](../../03-mom/mom-rest-clear-saved/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-saved/README.md) | 1 | Save restored five rest fields → success |
| [图](../../07-me/notification-followup-booking-mom/default.png) · [入口及前驱](../../07-me/notification-followup-booking-mom/README.md) | 4 | More bottom Me → mother home |
| [图](../../08-expert-service/booking-precheck-current-availability-home/default.png) · [入口及前驱](../../08-expert-service/booking-precheck-current-availability-home/README.md) | 33 | More → Me → owned plan |
| [图](../../03-mom/mom-milk-dial-home-return/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-home-return/README.md) | 1 | Discard editor → saved noon record retained, home |
| [图](../../03-mom/mom-journey-diary-save-error/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-save-error/README.md) | 1 | Save diary → API error preserves entries |
| [图](../../03-mom/mom-journey-milk-home-refreshed/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-home-refreshed/README.md) | 1 | Close saved panel → home displays 80 ml |
| [图](../../03-mom/mom-rest-control-disruption-clear-other/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-other/README.md) | 2 | Deselect rest disruption 其他 |
| [图](../../03-mom/mom-body-control-energy-managing/default.png) · [入口及前驱](../../03-mom/mom-body-control-energy-managing/README.md) | 1 | Body / 今天身体的电量 → select 勉强应付 |
| [图](../../03-mom/mom-rest-control-day-rest-none/default.png) · [入口及前驱](../../03-mom/mom-rest-control-day-rest-none/README.md) | 1 | Rest / 今天有没有一段不被打扰的休息 → select 没有 |
| [图](../../03-mom/mom-milk-control-pump-reopened/default.png) · [入口及前驱](../../03-mom/mom-milk-control-pump-reopened/README.md) | 1 | Edit saved pump → all fields retained and optional section expanded |
| [图](../../03-mom/mom-insight-generating/default.png) · [入口及前驱](../../03-mom/mom-insight-generating/README.md) | 1 | inventory mom insight-generating |
| [图](../../03-mom/mom-milk-control-comfort-painful/default.png) · [入口及前驱](../../03-mom/mom-milk-control-comfort-painful/README.md) | 1 | Select breast comfort 疼痛 |
| [图](../../03-mom/mom-missing-delivery/default.png) · [入口及前驱](../../03-mom/mom-missing-delivery/README.md) | 1 | inventory mom missing-delivery |
| [图](../../08-expert-service/home-consultation-journey-loading/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-loading/README.md) | 1 | View appointment → room context pending in modal above home |
| [图](../../03-mom/mom-milk-dial-close-confirm/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-close-confirm/README.md) | 1 | Close record editor → discard confirmation |
| [图](../../03-mom/mom-journey-home-loading/default.png) · [入口及前驱](../../03-mom/mom-journey-home-loading/README.md) | 2 | Me tab entered with homepage data requests pending |
| [图](../../03-mom/mom-handoff-purchased-bottom/default.png) · [入口及前驱](../../03-mom/mom-handoff-purchased-bottom/README.md) | 2 | handoff purchased 393.0/1.0 |
| [图](../../03-mom/mom-journey-diary-optional-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-optional-discard-confirm/README.md) | 1 | Close optional diary draft → discard confirmation |
| [图](../../03-mom/mom-rest-control-duration-cleared/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-cleared/README.md) | 1 | Tap selected sleep duration again → no duration selected |
| [图](../../03-mom/mom-milk-control-pump-decimal/default.png) · [入口及前驱](../../03-mom/mom-milk-control-pump-decimal/README.md) | 1 | Enter decimal pump volume 80.5 ml |
| [图](../../03-mom/mom-rest-clear-recovery-selected/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-recovery-selected/README.md) | 1 | Rest / 今天醒来时感觉怎样 → select 很疲惫 |
| [图](../../10-global-modals/native-device-deny-microphone/default.png) · [入口及前驱](../../10-global-modals/native-device-deny-microphone/README.md) | 1 | Actual Android microphone permission → choose deny |
| [图](../../03-mom/mom-mood-control-empty/default.png) · [入口及前驱](../../03-mom/mom-mood-control-empty/README.md) | 2 | Home Mood title → empty editor without preset |
| [图](../../03-mom/mom-mood-control-support-alone/default.png) · [入口及前驱](../../03-mom/mom-mood-control-support-alone/README.md) | 1 | Mood / 今天有人接住你吗？ → select 基本靠自己 |
| [图](../../03-mom/mom-rest-control-resleep-easy/default.png) · [入口及前驱](../../03-mom/mom-rest-control-resleep-easy/README.md) | 1 | Rest / 醒来后容易再睡着吗 → select 容易 |
| [图](../../03-mom/mom-journey-milk-new-pump/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-new-pump/README.md) | 5 | Home record lactation → new pump editor |
| [图](../../03-mom/mom-journey-milk-filled/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-filled/README.md) | 1 | Enter 80 ml and select right side |
| [图](../../03-mom/native-device-checking/default.png) · [入口及前驱](../../03-mom/native-device-checking/README.md) | 1 | Start consultation → device checking before native permission response |
| [图](../../03-mom/mom-rest-control-interruptions-threeToFour/default.png) · [入口及前驱](../../03-mom/mom-rest-control-interruptions-threeToFour/README.md) | 1 | Rest / 夜里大约被打断几次 → select 3–4 次 |
| [图](../../03-mom/mom-note-boundary-home-return/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-home-return/README.md) | 1 | Close lactation list → home |
| [图](../../03-mom/mom-rest-clear-reopened-optional/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-reopened-optional/README.md) | 1 | Expand saved optional fields → three restored values preserved; disruptions unset |
| [图](../../03-mom/mom-journey-diary-home-complete/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-home-complete/README.md) | 1 | Close editor → all three home status groups completed |
| [图](../../03-mom/mom-journey-milk-uncertain-return-home/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-uncertain-return-home/README.md) | 1 | Return from reconciled save → updated home total |
| [图](../../10-global-modals/native-device-deny-camera/default.png) · [入口及前驱](../../10-global-modals/native-device-deny-camera/README.md) | 1 | Actual Android camera permission → choose deny |
| [图](../../03-mom/mom-milk-control-nurse-duration/default.png) · [入口及前驱](../../03-mom/mom-milk-control-nurse-duration/README.md) | 1 | Enter nursing duration 12 minutes |
| [图](../../03-mom/mom-mood-control-tone-reactive/default.png) · [入口及前驱](../../03-mom/mom-mood-control-tone-reactive/README.md) | 1 | Mood / 今天心里更接近哪一种 → select 很容易被触发 |
| [图](../../03-mom/mom-note-boundary-milk-empty/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-empty/README.md) | 1 | Open lactation optional note → empty |
| [图](../../03-mom/mom-milk-dial-input-mode/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-input-mode/README.md) | 1 | Clock → manual input mode |
| [图](../../03-mom/mom-body-control-saved/default.png) · [入口及前驱](../../03-mom/mom-body-control-saved/README.md) | 1 | Save body through production repository → success feedback |
| [图](../../03-mom/mom-body-control-trend-same/default.png) · [入口及前驱](../../03-mom/mom-body-control-trend-same/README.md) | 1 | Body / 和昨天相比，身体感觉 → select 差不多 |
| [图](../../03-mom/mom-note-boundary-milk-saved-long-note/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-saved-long-note/README.md) | 1 | Save maximum note without optional measurement → long record list |
| [图](../../03-mom/mom-journey-mood-multiple-pressures/default.png) · [入口及前驱](../../03-mom/mom-journey-mood-multiple-pressures/README.md) | 1 | Mood tab → select two pressure sources |
| [图](../../03-mom/mom-mood-control-pressure-clear-selfDoubt/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-selfDoubt/README.md) | 1 | Deselect ordinary pressure 对自己没信心 |
| [图](../../03-mom/mom-rest-clear-day-rest-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-day-rest-restored/README.md) | 2 | Restore 今天有没有一段不被打扰的休息 with 没有 |
| [图](../../03-mom/mom-mood-control-pressure-bodyRecovery/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-bodyRecovery/README.md) | 2 | Mood / 什么一直占据着你的心？ → select 身体恢复 |
| [图](../../03-mom/mom-body-control-optional-open/default.png) · [入口及前驱](../../03-mom/mom-body-control-optional-open/README.md) | 2 | Expand toileting and pelvic floor options |
| [图](../../03-mom/mom-journey-milk-return-home/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-return-home/README.md) | 1 | Close history → original home refreshes 95 ml |
| [图](../../03-mom/mom-body-control-empty/default.png) · [入口及前驱](../../03-mom/mom-body-control-empty/README.md) | 5 | Home Body card → empty quick body editor |
| [图](../../03-mom/mom-body-control-site-cesarean/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-cesarean/README.md) | 1 | Body / 今天哪里最需要照顾？ → select 剖腹产切口 |
| [图](../../03-mom/mom-milk-validation-time-input/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-time-input/README.md) | 1 | Time dial → input mode |
| [图](../../03-mom/mom-milk-validation-time-open/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-time-open/README.md) | 1 | Open time picker at current 16:00 |
| [图](../../08-expert-service/home-consultation-journey-cancel-confirm/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-cancel-confirm/README.md) | 1 | Cancel appointment → nested confirmation dialog |
| [图](../../03-mom/mom-mood-control-empty-replacement-validation/default.png) · [入口及前驱](../../03-mom/mom-mood-control-empty-replacement-validation/README.md) | 1 | Attempt to save emptied existing diary → validation; saved version unchanged |
| [图](../../03-mom/mom-insight-unavailable/default.png) · [入口及前驱](../../03-mom/mom-insight-unavailable/README.md) | 1 | inventory mom insight-unavailable |
| [图](../../03-mom/mom-rest-clear-resleep-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-resleep-restored/README.md) | 1 | Restore 醒来后容易再睡着吗 with 容易 |
| [图](../../03-mom/mom-journey-diary-return-home/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-return-home/README.md) | 1 | Close standalone diary → home reloads changed mood |
| [图](../../03-mom/mom-body-control-energy-depleted/default.png) · [入口及前驱](../../03-mom/mom-body-control-energy-depleted/README.md) | 1 | Body / 今天身体的电量 → select 身体被掏空 |
| [图](../../03-mom/mom-milk-validation-nurse-limit-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-limit-saved/README.md) | 1 | Save nursing 240 minutes → version 3 |
| [图](../../03-mom/mom-journey-milk-save-error/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-save-error/README.md) | 1 | Save → HTTP failure, draft locked pending retry |
| [图](../../03-mom/mom-journey-diary-conflict-reload-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-conflict-reload-confirm/README.md) | 1 | Reload conflicting diary → explicit discard confirmation |
| [图](../../03-mom/mom-milk-validation-past-time-input/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-past-time-input/README.md) | 1 | Enter past time 08:00 AM |
| [图](../../03-mom/mom-rest-control-disruption-clear-cannotSleep/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-cannotSleep/README.md) | 1 | Deselect rest disruption 睡不回去 |
| [图](../../03-mom/mom-rest-control-interruptions-unknown/default.png) · [入口及前驱](../../03-mom/mom-rest-control-interruptions-unknown/README.md) | 1 | Rest / 夜里大约被打断几次 → select 记不清 |
| [图](../../03-mom/mom-journey-diary-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-discard-confirm/README.md) | 1 | Close unsaved three-section diary → discard confirmation |
| [图](../../03-mom/mother-home/default.png) · [入口及前驱](../../03-mom/mother-home/README.md) | 2 | mother home matches the product baseline at 390.0 / 1.0 |
| [图](../../03-mom/mom-milk-control-comfort-comfortable/default.png) · [入口及前驱](../../03-mom/mom-milk-control-comfort-comfortable/README.md) | 3 | Select breast comfort 舒服 |
| [图](../../03-mom/mom-journey-diary-empty-validation/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-empty-validation/README.md) | 1 | Save empty diary → validation |
| [图](../../03-mom/mom-milk-validation-nurse-zero-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-zero-saved/README.md) | 1 | Save nursing 0 minutes → version 4 |
| [图](../../03-mom/mom-journey-trend-return-home/default.png) · [入口及前驱](../../03-mom/mom-journey-trend-return-home/README.md) | 1 | Close trend → today total independent of historical measurements |
| [图](../../08-expert-service/home-consultation-journey-intake-required/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-intake-required/README.md) | 1 | Home preparation room context requires intake before joining |
| [图](../../03-mom/mom-journey-diary-conflict/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-conflict/README.md) | 2 | Save returns version conflict → draft preserved |
| [图](../../03-mom/mom-body-control-site-back/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-back/README.md) | 1 | Body / 今天哪里最需要照顾？ → select 腰背 |
| [图](../../03-mom/mom-note-boundary-body-2000/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-2000/README.md) | 3 | Enter body note at limit → 2000/2000 |
| [图](../../03-mom/mom-rest-control-duration-fourToFiveHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-fourToFiveHours/README.md) | 1 | Rest / 昨夜大约睡了多久 → select 4–5 小时 |
| [图](../../03-mom/mom-expert-portrait-missing/default.png) · [入口及前驱](../../03-mom/mom-expert-portrait-missing/README.md) | 1 | inventory mom expert-portrait-missing |
| [图](../../03-mom/mom-milk-dial-noon-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-noon-saved/README.md) | 1 | Save noon → record version 2 |
| [图](../../03-mom/mom-milk-validation-nurse-above-limit/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-above-limit/README.md) | 1 | Submit nursing 241 → out_of_range; saved version remains 2 |
| [图](../../03-mom/mom-mood-control-pressure-clear-familyFriction/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-familyFriction/README.md) | 1 | Deselect ordinary pressure 和家人相处 |
| [图](../../03-mom/mom-plan-exhausted/default.png) · [入口及前驱](../../03-mom/mom-plan-exhausted/README.md) | 1 | inventory mom plan-exhausted |
| [图](../../03-mom/mom-journey-diary-read-error/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-read-error/README.md) | 1 | Open quick diary → independent diary load error |
| [图](../../03-mom/mom-milk-dial-invalid-input-left-edge/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-invalid-input-left-edge/README.md) | 1 | Drag picker right → horizontal left edge shows help and AM/PM |
| [图](../../03-mom/mom-milk-dial-hour-header/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-hour-header/README.md) | 1 | Tap hour header → switch back to hour dial |
| [图](../../03-mom/mom-milk-control-comfort-full/default.png) · [入口及前驱](../../03-mom/mom-milk-control-comfort-full/README.md) | 1 | Select breast comfort 胀满 |
| [图](../../03-mom/mom-milk-validation-pump-negative/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-negative/README.md) | 1 | Submit pump -1 → out_of_range; no write |
| [图](../../03-mom/mom-note-boundary-body-home/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-home/README.md) | 2 | Close saved body note → home counts 1/3; body headline remains 待记录 |
| [图](../../03-mom/mom-milk-dial-minute-twenty/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-minute-twenty/README.md) | 1 | Tap minute 20 → 23:20 |
| [图](../../03-mom/mom-note-boundary-milk-1999/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-1999/README.md) | 1 | Enter lactation note one character below limit → 1999/2000 |
| [图](../../03-mom/mom-rest-control-duration-unknown/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-unknown/README.md) | 1 | Rest / 昨夜大约睡了多久 → select 记不清 |
| [图](../../03-mom/mom-body-control-site-clear-lowerAbdomen/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-clear-lowerAbdomen/README.md) | 1 | Deselect discomfort site 下腹 / 宫缩 |
| [图](../../03-mom/mom-rest-clear-day-rest-selected/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-day-rest-selected/README.md) | 1 | Rest / 今天有没有一段不被打扰的休息 → select ≥1 小时 |
| [图](../../08-expert-service/home-service-ready/default.png) · [入口及前驱](../../08-expert-service/home-service-ready/README.md) | 1 | home purchased, intake and preparation actions 390.0/1.0 |
| [图](../../03-mom/mom-body-control-severity-noticeable/default.png) · [入口及前驱](../../03-mom/mom-body-control-severity-noticeable/README.md) | 1 | Body / 这种不适有多难受？ → select 明显 |
| [图](../../08-expert-service/expert-appointment/default.png) · [入口及前驱](../../08-expert-service/expert-appointment/README.md) | 1 | home displays and opens confirmed appointment at 390.0 / 1.0 |
| [图](../../03-mom/mom-mood-control-impact-some/default.png) · [入口及前驱](../../03-mom/mom-mood-control-impact-some/README.md) | 1 | Mood / 这份难受影响到你了吗？ → select 有一点影响 |
| [图](../../03-mom/mom-rest-control-reopened/default.png) · [入口及前驱](../../03-mom/mom-rest-control-reopened/README.md) | 1 | Home Rest card → persisted rest record reopened |
| [图](../../03-mom/mom-journey-milk-invalid-volume/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-invalid-volume/README.md) | 1 | Submit out of range pump volume → validation |
| [图](../../03-mom/mom-milk-control-pump-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-control-pump-saved/README.md) | 1 | Save pump through production repository → list and saved feedback |
| [图](../../03-mom/mom-body-control-home-entry/default.png) · [入口及前驱](../../03-mom/mom-body-control-home-entry/README.md) | 36 | More → Me → initial home |
| [图](../../08-expert-service/progress-current-events-home/default.png) · [入口及前驱](../../08-expert-service/progress-current-events-home/README.md) | 1 | More → Me with existing service |
| [图](../../03-mom/mom-milk-validation-back-confirm/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-back-confirm/README.md) | 1 | Dispatch platform back → discard confirmation |
| [图](../../03-mom/mom-journey-mood-quick-prefilled/default.png) · [入口及前驱](../../03-mom/mom-journey-mood-quick-prefilled/README.md) | 6 | Home quick mood → diary with mood preselected, no write yet |
| [图](../../03-mom/mom-mood-control-pressure-clear-bodyRecovery/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-bodyRecovery/README.md) | 1 | Deselect ordinary pressure 身体恢复 |
| [图](../../07-me/notification-navigation-current-summary-home-return/default.png) · [入口及前驱](../../07-me/notification-navigation-current-summary-home-return/README.md) | 1 | Target Back/Close → mother home (notification route was replaced) |
| [图](../../03-mom/native-device-denied/default.png) · [入口及前驱](../../03-mom/native-device-denied/README.md) | 1 | Deny camera and microphone → actual device errors |
| [图](../../03-mom/mom-body-control-site-headChest/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-headChest/README.md) | 1 | Body / 今天哪里最需要照顾？ → select 头痛 / 胸闷 |
| [图](../../03-mom/mom-milk-dial-cancelled/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-cancelled/README.md) | 2 | Cancel picker → draft stays noon |
| [图](../../03-mom/mom-body-control-bowel-restored/default.png) · [入口及前驱](../../03-mom/mom-body-control-bowel-restored/README.md) | 2 | Select smooth bowel after clearing |
| [图](../../03-mom/mom-body-control-impact-none/default.png) · [入口及前驱](../../03-mom/mom-body-control-impact-none/README.md) | 1 | Body / 这种不适影响到你了吗？ → select 没有影响 |
| [图](../../03-mom/mom-milk-dial-hour-nine/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-hour-nine/README.md) | 1 | Tap dial hour 9 → minute dial, 21:00 |
| [图](../../03-mom/mom-milk-validation-pump-limit-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-limit-filled/README.md) | 1 | Edit pump → upper boundary 2000 |
| [图](../../03-mom/mom-note-boundary-body-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-discard-confirm/README.md) | 1 | Close cleared body note → discard confirmation |
| [图](../../03-mom/mom-rest-control-recovery-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-control-recovery-restored/README.md) | 1 | Rest / 今天醒来时感觉怎样 → select 有恢复 |
| [图](../../03-mom/mom-rest-control-saved/default.png) · [入口及前驱](../../03-mom/mom-rest-control-saved/README.md) | 1 | Save complete rest record through production repository → saved feedback |
| [图](../../03-mom/mom-rest-clear-day-rest-cleared/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-day-rest-cleared/README.md) | 2 | Tap selected 今天有没有一段不被打扰的休息 again → no selection |
| [图](../../03-mom/mom-note-boundary-body-cleared/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-cleared/README.md) | 1 | Clear saved body note in draft → 0/2000 |
| [图](../../03-mom/mom-journey-diary-saving/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-saving/README.md) | 1 | Submit replacement draft → controls disabled while pending |
| [图](../../03-mom/native-device-appointment/default.png) · [入口及前驱](../../03-mom/native-device-appointment/README.md) | 1 | View appointment → actual preparation dialog |
| [图](../../03-mom/mom-body-control-note-restored/default.png) · [入口及前驱](../../03-mom/mom-body-control-note-restored/README.md) | 1 | Enter final body note and leave input |
| [图](../../08-expert-service/progress-current-states-home-return/default.png) · [入口及前驱](../../08-expert-service/progress-current-states-home-return/README.md) | 1 | Timeline Back → Me |
| [图](../../03-mom/mom-partial-records/default.png) · [入口及前驱](../../03-mom/mom-partial-records/README.md) | 1 | inventory mom partial-records |
| [图](../../03-mom/mom-journey-purchased-booking-return/default.png) · [入口及前驱](../../03-mom/mom-journey-purchased-booking-return/README.md) | 3 | Booking back → active plan unchanged |
| [图](../../08-expert-service/service-current-owned-home-return/default.png) · [入口及前驱](../../08-expert-service/service-current-owned-home-return/README.md) | 1 | Return through package and catalog → home |
| [图](../../03-mom/mom-rest-clear-stretch-selected/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-stretch-selected/README.md) | 1 | Rest / 最长一段完整休息 → select 记不清 |
| [图](../../03-mom/mom-body-control-dependent-refilled/default.png) · [入口及前驱](../../03-mom/mom-body-control-dependent-refilled/README.md) | 2 | Fill returned severity and impact |
| [图](../../03-mom/mom-milk-validation-pump-not-number/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-not-number/README.md) | 1 | Submit pump abc → invalid_number; no write |
| [图](../../03-mom/mom-mood-control-impact-none/default.png) · [入口及前驱](../../03-mom/mom-mood-control-impact-none/README.md) | 3 | Mood / 这份难受影响到你了吗？ → select 没有影响 |
| [图](../../03-mom/mom-mood-control-pressure-noTime/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-noTime/README.md) | 2 | Mood / 什么一直占据着你的心？ → select 没有自己的时间 |
| [图](../../03-mom/mom-rest-control-day-rest-sixtyMinutesPlus/default.png) · [入口及前驱](../../03-mom/mom-rest-control-day-rest-sixtyMinutesPlus/README.md) | 1 | Rest / 今天有没有一段不被打扰的休息 → select ≥1 小时 |
| [图](../../03-mom/mom-milk-validation-return-record-confirm/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-return-record-confirm/README.md) | 1 | Tap top Return records → discard confirmation |
| [图](../../03-mom/mom-rest-clear-recovery-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-recovery-restored/README.md) | 1 | Restore 今天醒来时感觉怎样 with 有恢复 |
| [图](../../03-mom/mom-body-control-urination-painfulDifficult/default.png) · [入口及前驱](../../03-mom/mom-body-control-urination-painfulDifficult/README.md) | 1 | Body / 排尿 → select 刺痛 / 困难 |
| [图](../../03-mom/mom-milk-validation-past-time-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-past-time-saved/README.md) | 1 | Save corrected past time → version 5 |
| [图](../../03-mom/mom-body-control-site-perineum/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-perineum/README.md) | 1 | Body / 今天哪里最需要照顾？ → select 会阴 / 伤口 |
| [图](../../03-mom/mom-note-boundary-body-reopened/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-reopened/README.md) | 1 | Reopen saved body note → all 2000 characters retained |
| [图](../../03-mom/mom-milk-dial-invalid-input-right-edge/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-invalid-input-right-edge/README.md) | 1 | Drag picker left → horizontal right edge shows minutes and confirmation |
| [图](../../03-mom/mom-journey-milk-modal-saved/default.png) · [入口及前驱](../../03-mom/mom-journey-milk-modal-saved/README.md) | 1 | Retry save → actual record list and saved feedback |
| [图](../../03-mom/mom-milk-control-nurse-no-duration-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-control-nurse-no-duration-saved/README.md) | 1 | Save converted nursing with optional duration unset → updated record |
| [图](../../03-mom/mom-mood-control-pressure-refill-selfDoubt/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-refill-selfDoubt/README.md) | 2 | Add ordinary pressure 对自己没信心 after exclusive transition |
| [图](../../03-mom/mom-body-control-optional-collapsed/default.png) · [入口及前驱](../../03-mom/mom-body-control-optional-collapsed/README.md) | 3 | Collapse filled toileting options |
| [图](../../03-mom/mom-mood-control-quick-low-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-mood-control-quick-low-discard-confirm/README.md) | 1 | Close quick 不太好 draft → discard confirmation |
| [图](../../03-mom/mom-plan-expired/default.png) · [入口及前驱](../../03-mom/mom-plan-expired/README.md) | 1 | inventory mom plan-expired |
| [图](../../03-mom/mom-body-control-reopened-optional/default.png) · [入口及前驱](../../03-mom/mom-body-control-reopened-optional/README.md) | 1 | Expand persisted toileting values |
| [图](../../03-mom/mom-mood-control-quick-unclear/default.png) · [入口及前驱](../../03-mom/mom-mood-control-quick-unclear/README.md) | 2 | Home quick mood 一般 → prefilled draft without save |
| [图](../../03-mom/mom-mood-control-pressure-clear-sleepLoss/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-sleepLoss/README.md) | 1 | Deselect ordinary pressure 睡不好 |
| [图](../../03-mom/mom-mood-control-empty-replacement-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-mood-control-empty-replacement-discard-confirm/README.md) | 1 | Close cleared existing diary → discard confirmation |
| [图](../../03-mom/mom-body-control-note-cleared/default.png) · [入口及前驱](../../03-mom/mom-body-control-note-cleared/README.md) | 1 | Clear body note → empty value and character count |
| [图](../../03-mom/mom-rest-control-disruption-clear-feeding/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-feeding/README.md) | 1 | Deselect rest disruption 喂奶 |
| [图](../../03-mom/mom-body-control-urination-leakingUrgency/default.png) · [入口及前驱](../../03-mom/mom-body-control-urination-leakingUrgency/README.md) | 1 | Body / 排尿 → select 尿急 / 漏尿 |
| [图](../../03-mom/mom-mood-control-pressure-familyFriction/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-familyFriction/README.md) | 2 | Mood / 什么一直占据着你的心？ → select 和家人相处 |
| [图](../../03-mom/mom-rest-control-stretch-twoToThreeHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-stretch-twoToThreeHours/README.md) | 1 | Rest / 最长一段完整休息 → select 2–3 小时 |
| [图](../../03-mom/mom-rest-control-disruption-clear-discomfort/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-discomfort/README.md) | 1 | Deselect rest disruption 身体不适 |
| [图](../../03-mom/mom-body-control-impact-cleared/default.png) · [入口及前驱](../../03-mom/mom-body-control-impact-cleared/README.md) | 3 | Tap selected discomfort impact again → cleared |
| [图](../../03-mom/mom-mood-control-pressure-exclusive-restored/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-exclusive-restored/README.md) | 2 | Restore exclusive unclear pressure |
| [图](../../03-mom/mom-journey-diary-mood-empty/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-mood-empty/README.md) | 1 | Quick diary → Mood tab |
| [图](../../03-mom/mom-milk-validation-pump-above-limit/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-above-limit/README.md) | 1 | Submit pump 2001 → out_of_range; no write |
| [图](../../03-mom/mom-rest-control-disruption-clear-baby/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-baby/README.md) | 1 | Deselect rest disruption 宝宝醒了 |
| [图](../../03-mom/mom-milk-validation-future-time-input/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-future-time-input/README.md) | 1 | Select PM and enter 05:00 → 17:00 after fixed current 16:00 |
| [图](../../03-mom/mom-journey-mood-exclusive-pressure/default.png) · [入口及前驱](../../03-mom/mom-journey-mood-exclusive-pressure/README.md) | 1 | Select unclear pressure → exclusive choice replaces selected sources |
| [图](../../03-mom/mom-journey-body-optional-expanded/default.png) · [入口及前驱](../../03-mom/mom-journey-body-optional-expanded/README.md) | 1 | Expand optional toilet and pelvic floor questions |
| [图](../../03-mom/mom-rest-control-recovery-managing/default.png) · [入口及前驱](../../03-mom/mom-rest-control-recovery-managing/README.md) | 1 | Rest / 今天醒来时感觉怎样 → select 勉强能撑 |
| [图](../../03-mom/mom-rest-control-stretch-unknown/default.png) · [入口及前驱](../../03-mom/mom-rest-control-stretch-unknown/README.md) | 1 | Rest / 最长一段完整休息 → select 记不清 |
| [图](../../03-mom/mom-rest-control-recovery-exhausted/default.png) · [入口及前驱](../../03-mom/mom-rest-control-recovery-exhausted/README.md) | 1 | Rest / 今天醒来时感觉怎样 → select 很疲惫 |
| [图](../../03-mom/mom-note-boundary-milk-note-scroll-start/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-note-scroll-start/README.md) | 1 | Drag lactation note to start → 开始 |
| [图](../../03-mom/mom-journey-rest-optional-expanded/default.png) · [入口及前驱](../../03-mom/mom-journey-rest-optional-expanded/README.md) | 1 | Rest tab → expand continuous rest, naps and interruption causes |
| [图](../../03-mom/mom-note-boundary-milk-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-discard-confirm/README.md) | 1 | Cancel cleared lactation note → discard confirmation |
| [图](../../03-mom/mom-body-control-trend-worse/default.png) · [入口及前驱](../../03-mom/mom-body-control-trend-worse/README.md) | 1 | Body / 和昨天相比，身体感觉 → select 更不舒服 |
| [图](../../03-mom/mom-mood-control-pressure-clear-feedingPressure/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-feedingPressure/README.md) | 1 | Deselect ordinary pressure 喂养压力 |
| [图](../../03-mom/mom-handoff-initial-bottom/default.png) · [入口及前驱](../../03-mom/mom-handoff-initial-bottom/README.md) | 2 | handoff initial 393.0/1.0 |
| [图](../../03-mom/mom-rest-clear-home-refreshed/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-home-refreshed/README.md) | 2 | Close saved record → home reflects rest without duration |
| [图](../../03-mom/mom-milk-control-time-reopened/default.png) · [入口及前驱](../../03-mom/mom-milk-control-time-reopened/README.md) | 1 | Reopen time picker → accepted time retained |
| [图](../../03-mom/mom-body-control-severity-cleared/default.png) · [入口及前驱](../../03-mom/mom-body-control-severity-cleared/README.md) | 2 | Tap selected severity again → cleared |
| [图](../../03-mom/mom-rest-clear-empty/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-empty/README.md) | 3 | Home Rest card → empty editor |
| [图](../../03-mom/mom-milk-validation-nurse-negative/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-negative/README.md) | 1 | Submit nursing -1 → out_of_range; saved version remains 2 |
| [图](../../03-mom/mom-note-boundary-milk-2000/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-2000/README.md) | 3 | Enter lactation note at limit → 2000/2000 |
| [图](../../03-mom/mom-milk-control-home-nursing-only/default.png) · [入口及前驱](../../03-mom/mom-milk-control-home-nursing-only/README.md) | 2 | Close saved nursing → home count without invented milk amount |
| [图](../../03-mom/mom-milk-validation-time-am-selected/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-time-am-selected/README.md) | 1 | Select AM instead of PM |
| [图](../../03-mom/mom-rest-control-disruption-environment/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-environment/README.md) | 1 | Rest / 影响休息的原因 → select 环境影响 |
| [图](../../03-mom/mom-milk-validation-nurse-fraction/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-fraction/README.md) | 1 | Submit nursing 1.5 → invalid_number; saved version remains 2 |
| [图](../../03-mom/mom-rest-control-duration-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-restored/README.md) | 1 | Select 3–4 hours after clearing duration |
| [图](../../03-mom/mom-mood-control-tone-tense/default.png) · [入口及前驱](../../03-mom/mom-mood-control-tone-tense/README.md) | 1 | Mood / 今天心里更接近哪一种 → select 有点绷着 |
| [图](../../03-mom/mom-milk-validation-pump-zero-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-zero-filled/README.md) | 1 | Correct pump to lower boundary 0 → error clears |
| [图](../../03-mom/mom-body-control-severity-mild/default.png) · [入口及前驱](../../03-mom/mom-body-control-severity-mild/README.md) | 1 | Body / 这种不适有多难受？ → select 轻微 |
| [图](../../03-mom/mom-mood-control-pressure-refill-sleepLoss/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-refill-sleepLoss/README.md) | 2 | Add ordinary pressure 睡不好 after exclusive transition |
| [图](../../03-mom/mom-milk-control-side-right/default.png) · [入口及前驱](../../03-mom/mom-milk-control-side-right/README.md) | 1 | Select right breast → right volume label |
| [图](../../03-mom/mom-milk-validation-back-editor/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-back-editor/README.md) | 3 | Reopen saved record before platform back |
| [图](../../03-mom/mom-body-control-impact-careLimited/default.png) · [入口及前驱](../../03-mom/mom-body-control-impact-careLimited/README.md) | 2 | Body / 这种不适影响到你了吗？ → select 影响走路 / 抱宝宝 |
| [图](../../03-mom/mom-milk-dial-midnight-dial/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-midnight-dial/README.md) | 1 | Correct to 12:00 AM → return to clock showing midnight |
| [图](../../03-mom/mom-rest-control-disruption-cannotSleep/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-cannotSleep/README.md) | 1 | Rest / 影响休息的原因 → select 睡不回去 |
| [图](../../03-mom/mom-milk-dial-cancel-selection/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-cancel-selection/README.md) | 1 | Reopen noon and select hour 3 → unsaved picker value 15:00 |
| [图](../../03-mom/mom-mood-control-impact-cleared/default.png) · [入口及前驱](../../03-mom/mom-mood-control-impact-cleared/README.md) | 4 | Tap selected mood impact → cleared |
| [图](../../03-mom/mom-rest-control-disruption-feeding/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-feeding/README.md) | 2 | Rest / 影响休息的原因 → select 喂奶 |
| [图](../../03-mom/mom-journey-body-discomfort-expanded/default.png) · [入口及前驱](../../03-mom/mom-journey-body-discomfort-expanded/README.md) | 1 | Select discomfort site → severity and impact questions appear |
| [图](../../08-expert-service/progress-current-events-home-return/default.png) · [入口及前驱](../../08-expert-service/progress-current-events-home-return/README.md) | 1 | Timeline Back → Me |
| [图](../../03-mom/mom-milk-dial-noon-dial/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-noon-dial/README.md) | 1 | Select PM → noon 12:00 |
| [图](../../03-mom/mom-rest-control-day-rest-thirtyToSixtyMinutes/default.png) · [入口及前驱](../../03-mom/mom-rest-control-day-rest-thirtyToSixtyMinutes/README.md) | 1 | Rest / 今天有没有一段不被打扰的休息 → select 30–60 分钟 |
| [图](../../03-mom/mom-note-boundary-milk-reopened/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-reopened/README.md) | 1 | Edit saved lactation → all 2000 characters retained |
| [图](../../03-mom/mom-milk-validation-back-left/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-back-left/README.md) | 2 | Confirm platform back → preserve saved record |
| [图](../../03-mom/mom-milk-control-time-input-mode/default.png) · [入口及前驱](../../03-mom/mom-milk-control-time-input-mode/README.md) | 1 | Time dial → manual input |
| [图](../../03-mom/mom-milk-control-optional-collapsed/default.png) · [入口及前驱](../../03-mom/mom-milk-control-optional-collapsed/README.md) | 1 | Collapse filled optional fields → filled indicator remains |
| [图](../../03-mom/mom-lactation-error/default.png) · [入口及前驱](../../03-mom/mom-lactation-error/README.md) | 1 | inventory mom lactation-error |
| [图](../../08-expert-service/booking-recovery-current-cancel-in-progress-home-return/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-cancel-in-progress-home-return/README.md) | 1 | Booking Back → Me |
| [图](../../03-mom/mom-mood-control-support-restored/default.png) · [入口及前驱](../../03-mom/mom-mood-control-support-restored/README.md) | 2 | Restore supported |
| [图](../../03-mom/mom-rest-clear-interruptions-selected/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-interruptions-selected/README.md) | 1 | Rest / 夜里大约被打断几次 → select 记不清 |
| [图](../../03-mom/mom-mood-control-saved-all-cleared/default.png) · [入口及前驱](../../03-mom/mom-mood-control-saved-all-cleared/README.md) | 1 | Clear last saved field → empty draft, persisted record remains |
| [图](../../08-expert-service/home-service-intake/default.png) · [入口及前驱](../../08-expert-service/home-service-intake/README.md) | 1 | home purchased, intake and preparation actions 390.0/1.0 |
| [图](../../03-mom/mom-journey-diary-rest-empty/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-rest-empty/README.md) | 1 | Quick diary → Rest tab |
| [图](../../08-expert-service/home-service-paid/default.png) · [入口及前驱](../../08-expert-service/home-service-paid/README.md) | 1 | home purchased, intake and preparation actions 390.0/1.0 |
| [图](../../03-mom/mom-journey-diary-draft-retained/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-draft-retained/README.md) | 1 | Continue editing → selected mood and other draft sections remain |
| [图](../../03-mom/mom-journey-diary-conflict-return-home/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-conflict-return-home/README.md) | 1 | Close saved diary → body state refreshed on home |
| [图](../../03-mom/mom-milk-dial-minute-forty-five/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-minute-forty-five/README.md) | 1 | Tap minute 45 → 21:45 |
| [图](../../03-mom/mom-rest-control-stretch-oneToTwoHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-stretch-oneToTwoHours/README.md) | 1 | Rest / 最长一段完整休息 → select 1–2 小时 |
| [图](../../03-mom/mom-milk-dial-form-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-form-filled/README.md) | 1 | Record milk → enter pump 120 ml |
| [图](../../03-mom/mom-rest-clear-reopened/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-reopened/README.md) | 1 | Reopen saved rest → interruptions and recovery restored; duration unset |
| [图](../../03-mom/mom-milk-control-saved-switch-to-nurse/default.png) · [入口及前驱](../../03-mom/mom-milk-control-saved-switch-to-nurse/README.md) | 1 | Switch saved pump to nursing → clear numeric value, preserve side, note and comfort |
| [图](../../03-mom/mom-rest-control-interruptions-oneToTwo/default.png) · [入口及前驱](../../03-mom/mom-rest-control-interruptions-oneToTwo/README.md) | 1 | Rest / 夜里大约被打断几次 → select 1–2 次 |
| [图](../../08-expert-service/home-consultation-journey-cancel-kept-home/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-cancel-kept-home/README.md) | 4 | Keep appointment → nested dialog and preparation close; no cancellation mutation |
| [图](../../03-mom/mom-journey-diary-modal-saved/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-modal-saved/README.md) | 1 | Retry save → saved feedback in quick editor |
| [图](../../03-mom/mom-rest-clear-interruptions-restored/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-interruptions-restored/README.md) | 2 | Restore 夜里大约被打断几次 with 没有 |
| [图](../../03-mom/mom-rest-control-disruption-discomfort/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-discomfort/README.md) | 1 | Rest / 影响休息的原因 → select 身体不适 |
| [图](../../03-mom/mom-rest-control-optional-open/default.png) · [入口及前驱](../../03-mom/mom-rest-control-optional-open/README.md) | 1 | Expand rest optional fields |
| [图](../../03-mom/mom-milk-validation-nurse-zero-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-zero-filled/README.md) | 1 | Edit nursing → lower boundary 0 |
| [图](../../03-mom/mom-note-boundary-body-1999/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-1999/README.md) | 1 | Enter body note one character below limit → 1999/2000 |
| [图](../../03-mom/mom-rest-clear-resleep-selected/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-resleep-selected/README.md) | 1 | Rest / 醒来后容易再睡着吗 → select 很难 |
| [图](../../03-mom/mom-purchased-no-records/default.png) · [入口及前驱](../../03-mom/mom-purchased-no-records/README.md) | 1 | inventory mom purchased-no-records |
| [图](../../03-mom/native-device-ready/default.png) · [入口及前驱](../../03-mom/native-device-ready/README.md) | 2 | Allow camera and microphone → actual local tracks created and released |
| [图](../../03-mom/mom-body-control-home-refreshed/default.png) · [入口及前驱](../../03-mom/mom-body-control-home-refreshed/README.md) | 3 | Close saved body editor → home displays updated body summary |
| [图](../../03-mom/mom-handoff-recorded-bottom/default.png) · [入口及前驱](../../03-mom/mom-handoff-recorded-bottom/README.md) | 2 | handoff recorded 393.0/1.0 |
| [图](../../03-mom/mom-rest-control-disruption-clear-environment/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-clear-environment/README.md) | 1 | Deselect rest disruption 环境影响 |
| [图](../../03-mom/native-device-mom/default.png) · [入口及前驱](../../03-mom/native-device-mom/README.md) | 2 | Bottom Me → home with isolated active appointment |
| [图](../../03-mom/mom-journey-diary-conflict-resolved/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-conflict-resolved/README.md) | 1 | Save response → persisted diary feedback |
| [图](../../03-mom/mom-milk-control-note-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-control-note-filled/README.md) | 1 | Enter optional note |
| [图](../../03-mom/mom-note-boundary-body-empty/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-empty/README.md) | 1 | Body editor → focus empty optional note |
| [图](../../03-mom/mom-rest-control-day-rest-underThirtyMinutes/default.png) · [入口及前驱](../../03-mom/mom-rest-control-day-rest-underThirtyMinutes/README.md) | 1 | Rest / 今天有没有一段不被打扰的休息 → select <30 分钟 |
| [图](../../03-mom/mom-rest-control-interruptions-none/default.png) · [入口及前驱](../../03-mom/mom-rest-control-interruptions-none/README.md) | 1 | Rest / 夜里大约被打断几次 → select 没有 |
| [图](../../08-expert-service/home-consultation-journey-load-error/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-load-error/README.md) | 1 | Room context fails → error and retry within home modal |
| [图](../../03-mom/mom-body-control-site-clear-cesarean/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-clear-cesarean/README.md) | 1 | Deselect discomfort site 剖腹产切口 |
| [图](../../03-mom/mom-plan-paused/default.png) · [入口及前驱](../../03-mom/mom-plan-paused/README.md) | 1 | inventory mom plan-paused |
| [图](../../03-mom/mom-mood-control-quick-unclear-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-mood-control-quick-unclear-discard-confirm/README.md) | 1 | Close quick 一般 draft → discard confirmation |
| [图](../../03-mom/mom-milk-dial-invalid-input/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-invalid-input/README.md) | 1 | Submit hour 00 and minute 60 → invalid picker input, draft unchanged |
| [图](../../03-mom/mom-journey-home-diary-partial-error/default.png) · [入口及前驱](../../03-mom/mom-journey-home-diary-partial-error/README.md) | 1 | Pull refresh → diary request fails while other modules remain available |
| [图](../../03-mom/mom-milk-dial-hour-eleven/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-hour-eleven/README.md) | 1 | Tap hour 11 → minute dial with 45 retained |
| [图](../../03-mom/native-device-start-confirm/default.png) · [入口及前驱](../../03-mom/native-device-start-confirm/README.md) | 1 | Device check continue → actual consultation confirmation, no room join |
| [图](../../07-me/account-current-delete-mom/default.png) · [入口及前驱](../../07-me/account-current-delete-mom/README.md) | 15 | Authenticated Me before More navigation |
| [图](../../10-global-modals/native-device-allow-microphone/default.png) · [入口及前驱](../../10-global-modals/native-device-allow-microphone/README.md) | 1 | Actual Android microphone permission → choose allow |
| [图](../../03-mom/mom-milk-control-time-open/default.png) · [入口及前驱](../../03-mom/mom-milk-control-time-open/README.md) | 2 | Open record time picker |
| [图](../../03-mom/mom-rest-control-disruption-baby/default.png) · [入口及前驱](../../03-mom/mom-rest-control-disruption-baby/README.md) | 1 | Rest / 影响休息的原因 → select 宝宝醒了 |
| [图](../../08-expert-service/booking-recovery-current-expiry-home-return/default.png) · [入口及前驱](../../08-expert-service/booking-recovery-current-expiry-home-return/README.md) | 1 | Booking Back → Me |
| [图](../../03-mom/mom-milk-control-nurse-switch-cleared/default.png) · [入口及前驱](../../03-mom/mom-milk-control-nurse-switch-cleared/README.md) | 1 | Switch pump to nurse → measurement cleared and minutes shown |
| [图](../../03-mom/mom-milk-control-comfort-uncertain/default.png) · [入口及前驱](../../03-mom/mom-milk-control-comfort-uncertain/README.md) | 1 | Select breast comfort 说不清楚 |
| [图](../../03-mom/mom-body-control-site-clear-perineum/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-clear-perineum/README.md) | 1 | Deselect discomfort site 会阴 / 伤口 |
| [图](../../03-mom/mom-rest-control-optional-collapsed/default.png) · [入口及前驱](../../03-mom/mom-rest-control-optional-collapsed/README.md) | 1 | Collapse filled optional rest fields → filled indicator retained |
| [图](../../03-mom/mom-rest-control-stretch-underOneHour/default.png) · [入口及前驱](../../03-mom/mom-rest-control-stretch-underOneHour/README.md) | 1 | Rest / 最长一段完整休息 → select <1 小时 |
| [图](../../10-global-modals/native-device-allow-camera/default.png) · [入口及前驱](../../10-global-modals/native-device-allow-camera/README.md) | 1 | Actual Android camera permission → choose allow |
| [图](../../03-mom/mom-milk-validation-pump-zero-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-zero-saved/README.md) | 1 | Save pump 0 ml → one real fixture record |
| [图](../../03-mom/mom-mood-control-reopened/default.png) · [入口及前驱](../../03-mom/mom-mood-control-reopened/README.md) | 1 | Reopen mood by title → all four saved groups preserved |
| [图](../../03-mom/mom-profile-error/default.png) · [入口及前驱](../../03-mom/mom-profile-error/README.md) | 1 | inventory mom profile-error |
| [图](../../03-mom/mom-rest-control-interruptions-fivePlus/default.png) · [入口及前驱](../../03-mom/mom-rest-control-interruptions-fivePlus/README.md) | 1 | Rest / 夜里大约被打断几次 → select 5 次以上 |
| [图](../../03-mom/mom-milk-dial-minute-header/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-minute-header/README.md) | 1 | Tap minute header → minute dial at noon |
| [图](../../03-mom/mom-milk-validation-future-time-accepted/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-future-time-accepted/README.md) | 1 | Accept valid clock 17:00 → record draft has future time |
| [图](../../03-mom/mom-rest-control-stretch-threeHoursPlus/default.png) · [入口及前驱](../../03-mom/mom-rest-control-stretch-threeHoursPlus/README.md) | 1 | Rest / 最长一段完整休息 → select ≥3 小时 |
| [图](../../03-mom/mom-mood-control-saved-tone-cleared/default.png) · [入口及前驱](../../03-mom/mom-mood-control-saved-tone-cleared/README.md) | 1 | Clear saved mood tone in draft |
| [图](../../03-mom/mom-mood-control-quick-low/default.png) · [入口及前驱](../../03-mom/mom-mood-control-quick-low/README.md) | 2 | Home quick mood 不太好 → prefilled draft without save |
| [图](../../03-mom/mom-rest-control-duration-sixHoursPlus/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-sixHoursPlus/README.md) | 1 | Rest / 昨夜大约睡了多久 → select ≥6 小时 |
| [图](../../03-mom/mom-body-control-bowel-difficult/default.png) · [入口及前驱](../../03-mom/mom-body-control-bowel-difficult/README.md) | 1 | Body / 排便 → select 费力 |
| [图](../../03-mom/mom-mood-control-pressure-feedingPressure/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-feedingPressure/README.md) | 2 | Mood / 什么一直占据着你的心？ → select 喂养压力 |
| [图](../../03-mom/mom-milk-validation-return-record-left/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-return-record-left/README.md) | 1 | Return records → leave → unchanged list |
| [图](../../03-mom/mom-note-boundary-milk-cleared/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-cleared/README.md) | 1 | Clear maximum lactation note in draft → 0/2000 |
| [图](../../03-mom/mom-note-boundary-body-saved/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-saved/README.md) | 1 | Save body note at maximum → success feedback |
| [图](../../03-mom/mom-milk-validation-pump-limit-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-limit-saved/README.md) | 1 | Save pump 2000 ml → version 2 |
| [图](../../03-mom/mom-body-control-impact-some/default.png) · [入口及前驱](../../03-mom/mom-body-control-impact-some/README.md) | 1 | Body / 这种不适影响到你了吗？ → select 有一点影响 |
| [图](../../03-mom/mom-journey-body-note/default.png) · [入口及前驱](../../03-mom/mom-journey-body-note/README.md) | 1 | Enter optional body note |
| [图](../../03-mom/mom-note-boundary-milk-retained/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-milk-retained/README.md) | 1 | Discard cleared note → original long record remains |
| [图](../../03-mom/mom-body-control-reopened/default.png) · [入口及前驱](../../03-mom/mom-body-control-reopened/README.md) | 1 | Reopen Body → assert all saved values |
| [图](../../03-mom/mom-body-control-site-clear-headChest/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-clear-headChest/README.md) | 1 | Deselect discomfort site 头痛 / 胸闷 |
| [图](../../03-mom/mom-rest-control-home-refreshed/default.png) · [入口及前驱](../../03-mom/mom-rest-control-home-refreshed/README.md) | 2 | Close saved rest editor → home shows 3–4 hours and one completed group |
| [图](../../03-mom/mom-rest-control-duration-threeToFourHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-threeToFourHours/README.md) | 1 | Rest / 昨夜大约睡了多久 → select 3–4 小时 |
| [图](../../03-mom/mom-milk-validation-nurse-empty/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-empty/README.md) | 1 | Convert pump to nursing → numeric draft clears |
| [图](../../03-mom/mom-mood-control-support-carryingMost/default.png) · [入口及前驱](../../03-mom/mom-mood-control-support-carryingMost/README.md) | 1 | Mood / 今天有人接住你吗？ → select 有人，但主要还是我在扛 |
| [图](../../03-mom/mom-milk-validation-future-time-rejected/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-future-time-rejected/README.md) | 1 | Save future record → validation, version 4 retained |
| [图](../../03-mom/mom-body-control-bowel-cleared/default.png) · [入口及前驱](../../03-mom/mom-body-control-bowel-cleared/README.md) | 3 | Tap selected bowel again → cleared |
| [图](../../03-mom/native-device-retry-checking/default.png) · [入口及前驱](../../03-mom/native-device-retry-checking/README.md) | 1 | Retry device check → requesting permissions again |
| [图](../../03-mom/mom-rest-control-reopened-optional/default.png) · [入口及前驱](../../03-mom/mom-rest-control-reopened-optional/README.md) | 1 | Expand persisted optional rest values |
| [图](../../03-mom/mom-mood-control-saved-impact-cleared/default.png) · [入口及前驱](../../03-mom/mom-mood-control-saved-impact-cleared/README.md) | 1 | Clear saved impact in draft |
| [图](../../03-mom/mom-catalog-error/default.png) · [入口及前驱](../../03-mom/mom-catalog-error/README.md) | 1 | inventory mom catalog-error |
| [图](../../03-mom/mom-mood-control-saved-pressure-cleared/default.png) · [入口及前驱](../../03-mom/mom-mood-control-saved-pressure-cleared/README.md) | 1 | Clear saved pressure in draft |
| [图](../../03-mom/mom-mood-control-quick-steady-discard-confirm/default.png) · [入口及前驱](../../03-mom/mom-mood-control-quick-steady-discard-confirm/README.md) | 1 | Close quick 不错 draft → discard confirmation |
| [图](../../03-mom/mom-body-control-energy-energized/default.png) · [入口及前驱](../../03-mom/mom-body-control-energy-energized/README.md) | 3 | Body / 今天身体的电量 → select 有力气 |
| [图](../../03-mom/mom-rest-control-duration-fiveToSixHours/default.png) · [入口及前驱](../../03-mom/mom-rest-control-duration-fiveToSixHours/README.md) | 1 | Rest / 昨夜大约睡了多久 → select 5–6 小时 |
| [图](../../03-mom/mom-milk-control-time-accepted/default.png) · [入口及前驱](../../03-mom/mom-milk-control-time-accepted/README.md) | 2 | Confirm valid time → editor displays 12:34 |
| [图](../../03-mom/mom-body-control-note-entered/default.png) · [入口及前驱](../../03-mom/mom-body-control-note-entered/README.md) | 1 | Enter body note → visible value and character count |
| [图](../../08-expert-service/home-consultation-journey-load-recovered/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-load-recovered/README.md) | 4 | Retry room context → appointment preparation |
| [图](../../08-expert-service/booking-resume-current-confirm-home-return/default.png) · [入口及前驱](../../08-expert-service/booking-resume-current-confirm-home-return/README.md) | 3 | Booking Back → Me |
| [图](../../03-mom/mom-milk-control-time-valid-input/default.png) · [入口及前驱](../../03-mom/mom-milk-control-time-valid-input/README.md) | 1 | Enter valid record time 12:34 |
| [图](../../03-mom/mom-milk-validation-pump-not-finite/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-pump-not-finite/README.md) | 1 | Submit pump NaN → out_of_range; no write |
| [图](../../03-mom/mom-mood-control-pressure-clear-babyWorry/default.png) · [入口及前驱](../../03-mom/mom-mood-control-pressure-clear-babyWorry/README.md) | 1 | Deselect ordinary pressure 担心宝宝 |
| [图](../../03-mom/mom-rest-control-resleep-somewhatHard/default.png) · [入口及前驱](../../03-mom/mom-rest-control-resleep-somewhatHard/README.md) | 1 | Rest / 醒来后容易再睡着吗 → select 有点难 |
| [图](../../08-expert-service/home-consultation-journey-window-expired/default.png) · [入口及前驱](../../08-expert-service/home-consultation-journey-window-expired/README.md) | 1 | Home view appointment → expired entry window in actual over-home dialog |
| [图](../../03-mom/mom-note-boundary-body-note-scroll-start/default.png) · [入口及前驱](../../03-mom/mom-note-boundary-body-note-scroll-start/README.md) | 1 | Drag body note to start → 开始 |
| [图](../../08-expert-service/expert-support/default.png) · [入口及前驱](../../08-expert-service/expert-support/README.md) | 1 | active expert support at 390.0 / 1.0 |
| [图](../../03-mom/mom-body-control-site-clear-back/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-clear-back/README.md) | 1 | Deselect discomfort site 腰背 |
| [图](../../03-mom/mom-body-control-bowel-painfulPiles/default.png) · [入口及前驱](../../03-mom/mom-body-control-bowel-painfulPiles/README.md) | 1 | Body / 排便 → select 疼痛 / 痔疮 |
| [图](../../03-mom/mom-milk-dial-reopened/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-reopened/README.md) | 1 | Edit saved record → picker retains 11:20 |
| [图](../../03-mom/mom-mood-control-saved/default.png) · [入口及前驱](../../03-mom/mom-mood-control-saved/README.md) | 1 | Save mood record through production repository → success feedback |
| [图](../../03-mom/mom-milk-dial-saved/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-saved/README.md) | 1 | Save pump 120 ml at 11:20 → list |
| [图](../../03-mom/mom-mood-control-impact-hard/default.png) · [入口及前驱](../../03-mom/mom-mood-control-impact-hard/README.md) | 1 | Mood / 这份难受影响到你了吗？ → select 很难完成日常事情 |
| [图](../../03-mom/mom-milk-validation-nurse-limit-filled/default.png) · [入口及前驱](../../03-mom/mom-milk-validation-nurse-limit-filled/README.md) | 1 | Correct nursing to upper boundary 240 |
| [图](../../03-mom/mom-milk-dial-am/default.png) · [入口及前驱](../../03-mom/mom-milk-dial-am/README.md) | 1 | Select AM on dial → 11:20 |
| [图](../../03-mom/mom-rest-clear-optional-open/default.png) · [入口及前驱](../../03-mom/mom-rest-clear-optional-open/README.md) | 2 | Expand optional rest fields |
| [图](../../03-mom/mom-body-control-site-lowerAbdomen/default.png) · [入口及前驱](../../03-mom/mom-body-control-site-lowerAbdomen/README.md) | 2 | Body / 今天哪里最需要照顾？ → select 下腹 / 宫缩 |

## 实际操作链与状态依据

[MOM-JOURNEYS.md](../MOM-JOURNEYS.md) · [MOM-CONTROL-COVERAGE.md](../MOM-CONTROL-COVERAGE.md) · [SERVICE-JOURNEYS.md](../SERVICE-JOURNEYS.md)
