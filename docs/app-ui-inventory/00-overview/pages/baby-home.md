# 宝宝首页

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`baby-home`
- 范围：default
- 入口：Baby Tab
- 路由：/baby
- 实现：[baby_home_page.dart](../../../../lib/modules/baby/presentation/baby_home_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 无宝宝
- 有宝宝
- 有记录
- 加载
- 局部错误
- 生长曲线切换

## 归属弹窗／浮层

baby-profile、baby-record、baby-saved、baby-switcher、knowledge

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 无宝宝 | [baby-journey-no-profile](../../04-baby/baby-journey-no-profile/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 有宝宝 | [baby-journey-empty-home](../../04-baby/baby-journey-empty-home/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 有记录 | [baby-journey-records-loaded](../../04-baby/baby-journey-records-loaded/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [baby-journey-records-loading](../../04-baby/baby-journey-records-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 局部错误 | [baby-journey-record-read-error](../../04-baby/baby-journey-record-read-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 生长曲线切换 | [baby-journey-growth-curve-weight](../../04-baby/baby-journey-growth-curve-weight/README.md) · [baby-journey-growth-curve-length](../../04-baby/baby-journey-growth-curve-length/README.md) · [baby-journey-growth-curve-head](../../04-baby/baby-journey-growth-curve-head/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../04-baby/baby-profile-controls-feeding-formula/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-formula/README.md) | 1 | Select feeding mode formula |
| [图](../../04-baby/baby-diaper-controls-color-black/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-black/README.md) | 1 | Select stool color 黑色 |
| [图](../../04-baby/baby-journey-record-read-error/default.png) · [入口及前驱](../../04-baby/baby-journey-record-read-error/README.md) | 1 | More → Baby; record API fails, profile remains usable |
| [图](../../04-baby/baby-sleep-controls-home-active-return/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-home-active-return/README.md) | 1 | Return Baby → reopened sleep shown as active |
| [图](../../04-baby/baby-diaper-controls-sign-mucus/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-sign-mucus/README.md) | 1 | Deselect blood → mucus remains selected |
| [图](../../04-baby/baby-journey-first-profile-created/default.png) · [入口及前驱](../../04-baby/baby-journey-first-profile-created/README.md) | 2 | Save minimum profile → new baby home with missing birth date and sex |
| [图](../../04-baby/baby-growth-controls-date-future/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-future/README.md) | 1 | Confirm tomorrow → picker range error |
| [图](../../04-baby/baby-sleep-controls-note-expanded/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-note-expanded/README.md) | 1 | Expand optional sleep note |
| [图](../../04-baby/baby-diaper-controls-color-brown/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-brown/README.md) | 1 | Select stool color 棕色 |
| [图](../../04-baby/baby-development-controls-looks-at-face-notObserved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-looks-at-face-notObserved/README.md) | 1 | Select 看向靠近的脸 → 暂未观察到 |
| [图](../../04-baby/baby-development-controls-discard-confirm/default.png) · [入口及前驱](../../04-baby/baby-development-controls-discard-confirm/README.md) | 1 | Close dirty observation draft → discard confirmation |
| [图](../../04-baby/baby-knowledge-source-sleep-detail/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-sleep-detail/README.md) | 2 | Tap sleep knowledge card → complete article |
| [图](../../04-baby/baby-growth-missing-both/default.png) · [入口及前驱](../../04-baby/baby-growth-missing-both/README.md) | 1 | missing both growth profile at 390.0/1.0 is actionable without fabricated reference |
| [图](../../04-baby/baby-knowledge-source-source-exception-error/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-source-exception-error/README.md) | 2 | PlatformException → same error feedback; article remains |
| [图](../../04-baby/baby-feeding-controls-side-right/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-side-right/README.md) | 5 | Tap 右侧 → selected nursing side |
| [图](../../04-baby/baby-profile-controls-feeding-menu-formula/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-menu-formula/README.md) | 1 | Open feeding mode menu before choosing formula |
| [图](../../04-baby/baby-feeding-controls-volume-not-number/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-volume-not-number/README.md) | 1 | Tap save → 请检查瓶喂量。; no write request |
| [图](../../04-baby/baby-knowledge-source-growth-home/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-growth-home/README.md) | 2 | Pull to refresh with growth data → production-selected knowledge card |
| [图](../../04-baby/baby-development-boundaries-birth-input-only/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-birth-input-only/README.md) | 1 | Reopen birth date at large text → input-only picker without month navigation |
| [图](../../04-baby/baby-feeding-editor/default.png) · [入口及前驱](../../04-baby/baby-feeding-editor/README.md) | 1 | feeding editor remains usable at 390.0 / 1.0 |
| [图](../../04-baby/baby-journey-profile-new-validation/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-new-validation/README.md) | 1 | Save without baby name → required validation |
| [图](../../04-baby/baby-save-uncertain/default.png) · [入口及前驱](../../04-baby/baby-save-uncertain/README.md) | 1 | collapsed notes preserve the draft and uncertain save retries once |
| [图](../../04-baby/baby-growth-controls-head-entry/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-head-entry/README.md) | 1 | Tap 头围 home card → matching measurement selected |
| [图](../../04-baby/baby-feeding-time-optional-duration-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-optional-duration-saved/README.md) | 2 | Save nursing at current minute without duration → one count |
| [图](../../04-baby/baby-profile-boundaries-name-scroll-end/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-name-scroll-end/README.md) | 1 | Drag name field left → final character of maximum-length name |
| [图](../../04-baby/baby-growth-controls-length-entry/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-length-entry/README.md) | 1 | Tap 身长 home card → matching measurement selected |
| [图](../../04-baby/baby-diaper-controls-color-pale/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-pale/README.md) | 1 | Select stool color 灰白 / 很浅 |
| [图](../../04-baby/baby-development-boundaries-single-saved/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-single-saved/README.md) | 8 | Response acknowledged → exactly one observation on birth date |
| [图](../../04-baby/baby-profile-boundaries-previous-month/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-previous-month/README.md) | 1 | Calendar previous month → July 2026 |
| [图](../../04-baby/baby-profile-boundaries-name-120/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-name-120/README.md) | 2 | Enter maximum 120-character name |
| [图](../../04-baby/baby-feeding-controls-note-expanded/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-note-expanded/README.md) | 1 | Expand optional feeding note |
| [图](../../04-baby/baby-development-controls-save-uncertain/default.png) · [入口及前驱](../../04-baby/baby-development-controls-save-uncertain/README.md) | 2 | Batch POST fails 503 → unconfirmed save, draft locked and retry |
| [图](../../04-baby/baby-development-date-no-birth-editor/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-editor/README.md) | 1 | Open observation for baby without birth date |
| [图](../../04-baby/baby-sleep-controls-start-future-rejected/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-start-future-rejected/README.md) | 1 | Tap save → 发生时间不能晚于现在。; no write request |
| [图](../../04-baby/baby-feeding-controls-volume-upper-bound/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-volume-upper-bound/README.md) | 1 | Enter 1000 ml upper bound → validation cleared |
| [图](../../04-baby/baby-journey-growth-batch-undone/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-batch-undone/README.md) | 2 | Retry undo → all three batch measurements removed |
| [图](../../04-baby/baby-profile-boundaries-name-119/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-name-119/README.md) | 1 | Enter 119-character profile name |
| [图](../../04-baby/baby-feeding-controls-nursing-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-nursing-saved/README.md) | 1 | Save nursing → home refresh; dormant bottle value omitted and note trimmed |
| [图](../../04-baby/baby-diaper-controls-wet-open/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-wet-open/README.md) | 2 | Tap wet status card → wet diaper selected |
| [图](../../04-baby/baby-development-date-known-birth-input/default.png) · [入口及前驱](../../04-baby/baby-development-date-known-birth-input/README.md) | 1 | Large text input-only picker: enter Sep 12 |
| [图](../../04-baby/baby-journey-profile-discard-confirm/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-discard-confirm/README.md) | 1 | Edit name then close → discard confirmation |
| [图](../../04-baby/baby-profile-boundaries-date-saved/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-date-saved/README.md) | 1 | Save new birth date → home age and growth range refresh |
| [图](../../04-baby/baby-profile-boundaries-removed-before-reload-conflict/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-removed-before-reload-conflict/README.md) | 1 | Concurrent profile update → conflict before membership is removed |
| [图](../../04-baby/baby-diaper-editor/default.png) · [入口及前驱](../../04-baby/baby-diaper-editor/README.md) | 1 | diaper editor remains usable at 390.0 / 1.0 |
| [图](../../04-baby/baby-diaper-controls-kind-required/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-kind-required/README.md) | 1 | Tap save → 先选择这次换到的尿布。; no write request |
| [图](../../04-baby/baby-diaper-controls-consistency-hard/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-hard/README.md) | 1 | Select stool consistency 干硬 |
| [图](../../04-baby/baby-diaper-controls-both-restores-stool/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-both-restores-stool/README.md) | 1 | Choose wet and dirty → original stool selections restored |
| [图](../../04-baby/baby-journey-record-saving/default.png) · [入口及前驱](../../04-baby/baby-journey-record-saving/README.md) | 1 | Submit feeding while response pending → disabled save controls |
| [图](../../04-baby/baby-journey-records-loading/default.png) · [入口及前驱](../../04-baby/baby-journey-records-loading/README.md) | 1 | Baby entered; profile ready while records requests are pending |
| [图](../../04-baby/baby-profile-boundaries-maximum-name-saved/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-maximum-name-saved/README.md) | 1 | Save 120-character name → home identity and knowledge label update |
| [图](../../04-baby/baby-profile-boundaries-year-selected/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-year-selected/README.md) | 1 | Choose year 2025 → September calendar |
| [图](../../04-baby/baby-profile-existing/default.png) · [入口及前驱](../../04-baby/baby-profile-existing/README.md) | 1 | switcher changes the selected baby and opens its profile at 390.0/1.0 |
| [图](../../04-baby/baby-profile-controls-feeding-menu-mixed/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-menu-mixed/README.md) | 1 | Open feeding mode menu before choosing mixed |
| [图](../../04-baby/baby-profile-boundaries-removed-leave-confirm/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-removed-leave-confirm/README.md) | 1 | Close removed profile draft → discard confirmation |
| [图](../../04-baby/baby-profile-controls-sex-unspecified/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-sex-unspecified/README.md) | 1 | Select profile sex unspecified |
| [图](../../04-baby/baby-journey-growth-date-invalid/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-date-invalid/README.md) | 1 | Confirm invalid date text → picker validation |
| [图](../../04-baby/baby-feeding-controls-duration-fraction/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-duration-fraction/README.md) | 1 | Tap save → 亲喂时长请填写整数分钟。; no write request |
| [图](../../04-baby/baby-journey-switched-leo/default.png) · [入口及前驱](../../04-baby/baby-journey-switched-leo/README.md) | 2 | Choose Leo → second profile and independently empty records |
| [图](../../04-baby/baby-journey-feeding-save-error/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-save-error/README.md) | 1 | Save → HTTP 503 from isolated transport |
| [图](../../04-baby/baby-sleep-controls-note-collapsed/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-note-collapsed/README.md) | 1 | Collapse filled note → value retained |
| [图](../../04-baby/baby-diaper-controls-note-filled/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-note-filled/README.md) | 1 | Enter multiline diaper note with surrounding whitespace |
| [图](../../04-baby/baby-profile-controls-feeding-breastfeeding/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-breastfeeding/README.md) | 1 | Select feeding mode breastfeeding |
| [图](../../04-baby/baby-growth-controls-weight-entry/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-entry/README.md) | 2 | Tap weight home card → weight selected |
| [图](../../04-baby/baby-development-date-known-birth-day-selected/default.png) · [入口及前驱](../../04-baby/baby-development-date-known-birth-day-selected/README.md) | 1 | Tap day grid Sep 12 → selected, still awaiting confirmation |
| [图](../../04-baby/baby-development-boundaries-pending-back-blocked/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-pending-back-blocked/README.md) | 2 | Platform Back during save → editor remains without discard dialog |
| [图](../../04-baby/baby-development-editor/default.png) · [入口及前驱](../../04-baby/baby-development-editor/README.md) | 1 | development editor remains usable at 390.0 / 1.0 |
| [图](../../04-baby/baby-journey-stool-blood/default.png) · [入口及前驱](../../04-baby/baby-journey-stool-blood/README.md) | 1 | Select observed blood sign |
| [图](../../04-baby/baby-journey-sleep-start-editor/default.png) · [入口及前驱](../../04-baby/baby-journey-sleep-start-editor/README.md) | 3 | Tap sleep summary → new active sleep editor |
| [图](../../04-baby/baby-growth-controls-head-over-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-head-over-rejected/README.md) | 1 | Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request |
| [图](../../04-baby/baby-journey-growth-three-values/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-three-values/README.md) | 1 | Fill weight, length and head circumference across measurement tabs |
| [图](../../04-baby/baby-development-boundaries-unconfirmed-back-confirm/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-unconfirmed-back-confirm/README.md) | 1 | Platform Back on unconfirmed save → uncertainty discard confirmation |
| [图](../../04-baby/baby-feeding-controls-method-deselected/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-method-deselected/README.md) | 1 | Tap save → 先选择这次的喂养方式。; no write request |
| [图](../../04-baby/baby-profile-recovery-saved-reopened/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-saved-reopened/README.md) | 1 | Reopen saved profile → confirmed name persisted |
| [图](../../04-baby/baby-growth-controls-hidden-length-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-hidden-length-rejected/README.md) | 1 | Save from head tab → focus invalid length tab; no write |
| [图](../../04-baby/baby-sleep-controls-wake-valid/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-valid/README.md) | 1 | Choose valid wake at current time → validation cleared |
| [图](../../04-baby/baby-journey-growth-curve-weight/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-curve-weight/README.md) | 2 | Switch growth curve to 体重 |
| [图](../../04-baby/baby-profile-recovery-unconfirmed-reopened/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-unconfirmed-reopened/README.md) | 1 | Reopen → persisted profile, no unconfirmed local draft |
| [图](../../04-baby/baby-profile-controls-birth-cancelled/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-birth-cancelled/README.md) | 2 | Cancel typed birth date → draft remains empty |
| [图](../../04-baby/baby-development-controls-date-input/default.png) · [入口及前驱](../../04-baby/baby-development-controls-date-input/README.md) | 1 | Input yesterday before confirming observation date |
| [图](../../04-baby/baby-development-boundaries-save-unconfirmed/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-save-unconfirmed/README.md) | 1 | Second draft save fails 503 → unconfirmed result |
| [图](../../04-baby/baby-nursing/default.png) · [入口及前驱](../../04-baby/baby-nursing/README.md) | 1 | nursing keeps its primary action visible at 390.0/1.0 |
| [图](../../04-baby/baby-growth-controls-weight-over/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-over/README.md) | 1 | Enter weight 50.1 before save validation |
| [图](../../04-baby/baby-development-date-no-birth-year-selected/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-year-selected/README.md) | 1 | Select 2025 → September calendar |
| [图](../../04-baby/baby-profile-controls-knowledge-detail/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-knowledge-detail/README.md) | 1 | Tap knowledge card → full article |
| [图](../../04-baby/baby-sleep-controls-wake-before/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-before/README.md) | 1 | Select wake 14:59 before validation |
| [图](../../04-baby/baby-feeding-controls-volume-over-limit/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-volume-over-limit/README.md) | 1 | Tap save → 瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。; no write request |
| [图](../../04-baby/baby-diaper-controls-color-unsure/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-unsure/README.md) | 1 | Select stool color 不确定 |
| [图](../../04-baby/baby-development-controls-batch-saved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-batch-saved/README.md) | 1 | Retry acknowledged → three dated observations saved together |
| [图](../../04-baby/baby-growth/default.png) · [入口及前驱](../../04-baby/baby-growth/README.md) | 2 | baby overview matches the current product design at 390.0 |
| [图](../../04-baby/baby-development-date-no-birth-input/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-input/README.md) | 1 | Large text input-only picker: enter Sep 15 2025 |
| [图](../../04-baby/baby-journey-profile-saved/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-saved/README.md) | 1 | Save profile → updated home identity |
| [图](../../04-baby/baby-journey-returned-home/default.png) · [入口及前驱](../../04-baby/baby-journey-returned-home/README.md) | 1 | History Back → Baby with refreshed 100 ml record |
| [图](../../04-baby/baby-diaper-controls-consistency-loose/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-loose/README.md) | 2 | Select stool consistency 稀软 |
| [图](../../04-baby/baby-feeding-time-previous-day-input/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-previous-day-input/README.md) | 1 | Enter previous date before confirmation |
| [图](../../04-baby/baby-development-controls-batch-lifts-head/default.png) · [入口及前驱](../../04-baby/baby-development-controls-batch-lifts-head/README.md) | 3 | Choose 不确定 for 俯卧时短暂抬起头 while preserving other groups |
| [图](../../04-baby/baby-knowledge-source-diaper-detail/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-diaper-detail/README.md) | 2 | Tap diaper knowledge card → complete article |
| [图](../../04-baby/baby-journey-feeding-filled/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-filled/README.md) | 1 | Select expressed milk and enter 80 ml |
| [图](../../04-baby/baby-journey-knowledge-detail/default.png) · [入口及前驱](../../04-baby/baby-journey-knowledge-detail/README.md) | 3 | Tap knowledge card → full educational article |
| [图](../../04-baby/baby-profile-boundaries-date-corrected/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-date-corrected/README.md) | 1 | Confirm valid date → draft September 1 |
| [图](../../04-baby/baby-journey-feeding-saved/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-saved/README.md) | 1 | Retry succeeds → home refresh and saved feedback |
| [图](../../04-baby/baby-development-date-known-birth-years/default.png) · [入口及前驱](../../04-baby/baby-development-date-known-birth-years/README.md) | 1 | Tap calendar header → only birth/current year selectable |
| [图](../../04-baby/baby-growth-controls-weight-malformed/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-malformed/README.md) | 1 | Enter weight oops before save validation |
| [图](../../04-baby/baby-sleep-controls-wake-equal-rejected/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-equal-rejected/README.md) | 1 | Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request |
| [图](../../04-baby/baby-journey-development-saved/default.png) · [入口及前驱](../../04-baby/baby-journey-development-saved/README.md) | 1 | Save observation → home with completion feedback |
| [图](../../04-baby/baby-sleep-controls-wake-time-empty/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-time-empty/README.md) | 1 | Confirm wake date → current clock, not yet committed |
| [图](../../04-baby/baby-growth-editor/default.png) · [入口及前驱](../../04-baby/baby-growth-editor/README.md) | 1 | growth editor remains usable at 390.0 / 1.0 |
| [图](../../04-baby/baby-diaper-controls-wet-hides-stool/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-wet-hides-stool/README.md) | 1 | Switch to wet → stool controls hidden; draft retained |
| [图](../../04-baby/baby-profile-controls-saved-reopened/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-saved-reopened/README.md) | 1 | Reopen saved profile → all saved fields restored |
| [图](../../04-baby/baby-profile-controls-knowledge-baby-return/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-knowledge-baby-return/README.md) | 3 | Cozymate → Baby, saved profile retained |
| [图](../../04-baby/baby-journey-feeding-mode-selected/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-mode-selected/README.md) | 1 | Select mixed feeding |
| [图](../../04-baby/baby-feeding-validation/default.png) · [入口及前驱](../../04-baby/baby-feeding-validation/README.md) | 1 | feeding validation, save, uncertain undo and feedback at 390.0/1.0 |
| [图](../../04-baby/baby-sleep-controls-active-saved/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-active-saved/README.md) | 1 | Save active sleep with empty wake → home active record |
| [图](../../04-baby/baby-journey-feeding-empty/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-empty/README.md) | 1 | Tap today feeding card → feeding editor |
| [图](../../04-baby/baby-journey-profile-new/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-new/README.md) | 1 | Switcher → add baby |
| [图](../../04-baby/baby-journey-sleep-started/default.png) · [入口及前驱](../../04-baby/baby-journey-sleep-started/README.md) | 1 | Start sleep → active sleep stored and home feedback |
| [图](../../04-baby/baby-diaper-controls-sign-blood/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-sign-blood/README.md) | 1 | Select blood sign → one selected observation |
| [图](../../04-baby/baby-profile-boundaries-day-selected/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-day-selected/README.md) | 1 | Choose September 15 in calendar |
| [图](../../04-baby/baby-development-date-before-minimum-rejected/default.png) · [入口及前驱](../../04-baby/baby-development-date-before-minimum-rejected/README.md) | 1 | Submit Dec 31 1899 → range validation, draft unchanged |
| [图](../../04-baby/baby-journey-growth-curve-head/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-curve-head/README.md) | 1 | Switch growth curve to 头围 |
| [图](../../04-baby/baby-knowledge-source-feeding-detail/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-feeding-detail/README.md) | 2 | Tap feeding knowledge card → complete article |
| [图](../../04-baby/baby-growth-controls-weight-zero-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-zero-rejected/README.md) | 1 | Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request |
| [图](../../04-baby/baby-development-date-baby-switcher/default.png) · [入口及前驱](../../04-baby/baby-development-date-baby-switcher/README.md) | 2 | Tap Luna → baby switcher |
| [图](../../04-baby/baby-knowledge-source-sleep-home/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-sleep-home/README.md) | 2 | Pull to refresh with sleep data → production-selected knowledge card |
| [图](../../04-baby/baby-profile-recovery-busy-close-blocked/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-busy-close-blocked/README.md) | 2 | Tap disabled close then platform back → saving editor stays open |
| [图](../../04-baby/baby-journey-feeding-validation/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-validation/README.md) | 1 | Submit without feeding method → validation |
| [图](../../04-baby/baby-wet/default.png) · [入口及前驱](../../04-baby/baby-wet/README.md) | 1 | wet keeps its primary action visible at 390.0/1.0 |
| [图](../../04-baby/baby-diaper-controls-color-yellow/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-yellow/README.md) | 2 | Select stool color 黄色 |
| [图](../../04-baby/baby-development-date-no-birth-years/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-years/README.md) | 1 | Open year list without birth date → earlier years available |
| [图](../../04-baby/baby-development-boundaries-birth-selected/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-birth-selected/README.md) | 2 | Confirm birth date → earliest valid observation date |
| [图](../../04-baby/baby-profile-boundaries-birth-open/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-birth-open/README.md) | 3 | Open birth date calendar or large-text input |
| [图](../../04-baby/baby-profile-recovery-forbidden-discard-confirm/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-forbidden-discard-confirm/README.md) | 1 | Close rejected draft → discard confirmation |
| [图](../../04-baby/baby-journey-sleep-adjust/default.png) · [入口及前驱](../../04-baby/baby-journey-sleep-adjust/README.md) | 1 | Expand active sleep time and note controls |
| [图](../../04-baby/baby-sleep-controls-start-future/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-start-future/README.md) | 1 | Choose start one minute in future |
| [图](../../04-baby/baby-feeding-controls-volume-zero/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-volume-zero/README.md) | 1 | Tap save → 瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。; no write request |
| [图](../../04-baby/baby-development-date-minimum-discard/default.png) · [入口及前驱](../../04-baby/baby-development-date-minimum-discard/README.md) | 1 | Close minimum-date draft → discard confirmation |
| [图](../../04-baby/baby-development-date-known-birth-confirmed/default.png) · [入口及前驱](../../04-baby/baby-development-date-known-birth-confirmed/README.md) | 1 | Confirm Sep 12 → observation draft date changes |
| [图](../../04-baby/baby-feeding-saved/default.png) · [入口及前驱](../../04-baby/baby-feeding-saved/README.md) | 1 | feeding validation, save, uncertain undo and feedback at 390.0/1.0 |
| [图](../../04-baby/baby-growth-controls-home-return/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-home-return/README.md) | 1 | Return Baby after history weight edit |
| [图](../../04-baby/baby-profile-controls-feeding-menu-breastfeeding/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-menu-breastfeeding/README.md) | 1 | Open feeding mode menu before choosing breastfeeding |
| [图](../../04-baby/baby-profile-controls-birth-restored/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-birth-restored/README.md) | 1 | Confirm restored birth date August 22 |
| [图](../../04-baby/baby-development-date-minimum-confirmed/default.png) · [入口及前驱](../../04-baby/baby-development-date-minimum-confirmed/README.md) | 1 | Confirm Jan 1 1900 → accepted as draft, no observation saved |
| [图](../../04-baby/baby-profile-boundaries-input-to-calendar/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-input-to-calendar/README.md) | 1 | Correct typed date then return to calendar preview |
| [图](../../04-baby/baby-development-controls-lifts-head-notObserved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-lifts-head-notObserved/README.md) | 1 | Select 俯卧时短暂抬起头 → 暂未观察到 |
| [图](../../04-baby/baby-development-controls-date-selected/default.png) · [入口及前驱](../../04-baby/baby-development-controls-date-selected/README.md) | 1 | Confirm yesterday → all observations share selected date |
| [图](../../04-baby/baby-profile-recovery-reload-pending/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-reload-pending/README.md) | 1 | Click reload while profile response pending → controls disabled |
| [图](../../04-baby/baby-growth-controls-date-cancelled/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-cancelled/README.md) | 2 | Cancel date → today and three values retained |
| [图](../../04-baby/baby-profile-recovery-reload-current/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-reload-current/README.md) | 1 | Reload succeeds → latest server name and feeding mode replace draft |
| [图](../../04-baby/baby-profile-recovery-forbidden-discarded/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-forbidden-discarded/README.md) | 2 | Confirm leave → refreshed home shows server profile |
| [图](../../04-baby/baby-journey-profile-draft-preserved/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-draft-preserved/README.md) | 1 | Continue editing → draft name preserved |
| [图](../../04-baby/baby-sleep-controls-start-past/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-start-past/README.md) | 3 | Correct start to 15:00, validation cleared |
| [图](../../04-baby/baby-profile-boundaries-invalid-date-format/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-invalid-date-format/README.md) | 1 | Submit malformed date → localized format validation |
| [图](../../04-baby/baby-profile-recovery-saved/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-saved/README.md) | 1 | Response acknowledged → refreshed home with version 3 |
| [图](../../04-baby/baby-sleep-controls-wake-future-rejected/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-future-rejected/README.md) | 1 | Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request |
| [图](../../04-baby/baby-profile-controls-feeding-menu-unknown/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-menu-unknown/README.md) | 1 | Open feeding mode menu before choosing unknown |
| [图](../../04-baby/baby-growth-controls-date-before-birth/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-before-birth/README.md) | 1 | Confirm date before birth → picker range error |
| [图](../../04-baby/baby-profile-controls-save-unconfirmed/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-save-unconfirmed/README.md) | 2 | Profile PUT returns 503 → locked draft and retry confirmation |
| [图](../../04-baby/baby-journey-growth-batch-saved/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-batch-saved/README.md) | 1 | Save → atomic measurement batch and home latest metrics |
| [图](../../04-baby/baby-feeding-time-future-minute-rejected/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-future-minute-rejected/README.md) | 1 | Tap save → 发生时间不能晚于现在。; no write request |
| [图](../../04-baby/baby-sleep-controls-start-date/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-start-date/README.md) | 1 | Open sleep start date picker |
| [图](../../04-baby/baby-development-boundaries-date-before-birth-rejected/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-date-before-birth-rejected/README.md) | 1 | Submit before-birth date → picker validation, draft date unchanged |
| [图](../../04-baby/baby-sleep-controls-wake-date-empty/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-date-empty/README.md) | 1 | Open empty wake date → current date |
| [图](../../04-baby/baby-sleep-controls-note-filled/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-note-filled/README.md) | 1 | Enter short sleep note with surrounding spaces and newline |
| [图](../../04-baby/baby-profile-boundaries-calendar-confirmed/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-calendar-confirmed/README.md) | 1 | Confirm calendar selection → profile draft date changes |
| [图](../../04-baby/baby-journey-profile-existing/default.png) · [入口及前驱](../../04-baby/baby-journey-profile-existing/README.md) | 1 | Switcher → edit current profile |
| [图](../../04-baby/baby-profile-boundaries-unicode-length-validation/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-unicode-length-validation/README.md) | 1 | 61 combining-accent letters exceed 120 Unicode code points → domain length validation |
| [图](../../04-baby/baby-diaper-controls-color-yellowBrown/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-yellowBrown/README.md) | 1 | Select stool color 黄褐色 |
| [图](../../04-baby/baby-journey-growth-curve-length/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-curve-length/README.md) | 1 | Switch growth curve to 身长 |
| [图](../../04-baby/baby-knowledge-source-feeding-home/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-feeding-home/README.md) | 2 | Pull to refresh with feeding data → production-selected knowledge card |
| [图](../../04-baby/baby-feeding-time-date-open/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-date-open/README.md) | 1 | Open occurred date; today follows fixed timezone clock |
| [图](../../04-baby/baby-journey-record-discard/default.png) · [入口及前驱](../../04-baby/baby-journey-record-discard/README.md) | 1 | Close dirty record → discard confirmation |
| [图](../../04-baby/baby-development-date-no-birth-home/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-home/README.md) | 3 | Save profile with no birth date → Baby |
| [图](../../04-baby/baby-feeding-time-home-volume-refreshed/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-home-volume-refreshed/README.md) | 1 | Return Baby → actual 1000 ml home summary |
| [图](../../04-baby/baby-feeding-controls-side-both/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-side-both/README.md) | 1 | Tap 两侧 → selected nursing side |
| [图](../../04-baby/baby-sleep-active/default.png) · [入口及前驱](../../04-baby/baby-sleep-active/README.md) | 1 | sleep-active keeps its primary action visible at 390.0/1.0 |
| [图](../../04-baby/baby-profile-controls-missing-birth-picker/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-missing-birth-picker/README.md) | 1 | Open missing birth date → initial date is injected today |
| [图](../../04-baby/baby-journey-first-profile-form/default.png) · [入口及前驱](../../04-baby/baby-journey-first-profile-form/README.md) | 1 | Empty page CTA → first baby form |
| [图](../../04-baby/baby-profile-short/default.png) · [入口及前驱](../../04-baby/baby-profile-short/README.md) | 1 | profile dialog scrolls and saves at 390.0 / 1.0 / long=true |
| [图](../../04-baby/baby-profile-controls-name-empty-validation/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-name-empty-validation/README.md) | 1 | Save whitespace name → required validation, saved profile untouched |
| [图](../../04-baby/baby-growth-controls-head-empty/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-head-empty/README.md) | 1 | Switch to head circumference → hidden invalid length remains draft |
| [图](../../04-baby/baby-growth-controls-length-empty/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-length-empty/README.md) | 1 | Switch to length → completed weight indicator retained |
| [图](../../04-baby/baby-profile-controls-feeding-menu-expressedMilk/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-menu-expressedMilk/README.md) | 1 | Open feeding mode menu before choosing expressedMilk |
| [图](../../04-baby/baby-profile-recovery-unconfirmed/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-unconfirmed/README.md) | 1 | Save returns 503 → pending result and locked draft |
| [图](../../04-baby/baby-diaper-controls-color-cleared/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-cleared/README.md) | 3 | Tap selected unsure color → optional color cleared |
| [图](../../04-baby/baby-knowledge-source-growth-detail/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-growth-detail/README.md) | 2 | Tap growth knowledge card → complete article |
| [图](../../04-baby/baby-development-boundaries-date-format-rejected/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-date-format-rejected/README.md) | 1 | Submit format date → picker validation, draft date unchanged |
| [图](../../04-baby/baby-development-boundaries-date-open/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-date-open/README.md) | 4 | Open observation date: birth 8/22 through today 9/13 |
| [图](../../04-baby/baby-profile-editor/default.png) · [入口及前驱](../../04-baby/baby-profile-editor/README.md) | 1 | profile dialog scrolls and saves at 390.0 / 1.0 / long=false |
| [图](../../04-baby/baby-growth-missing-birth/default.png) · [入口及前驱](../../04-baby/baby-growth-missing-birth/README.md) | 1 | missing birth growth profile at 390.0/1.0 is actionable without fabricated reference |
| [图](../../04-baby/baby-profile-recovery-conflict/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-conflict/README.md) | 2 | Save stale version → conflict, retain local draft and offer reload |
| [图](../../04-baby/baby-knowledge-source-source-error-dialog-closed/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-source-error-dialog-closed/README.md) | 1 | Close article while Snackbar remains → Baby home |
| [图](../../04-baby/baby-sleep-controls-active-expanded/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-active-expanded/README.md) | 2 | Expand active sleep times and saved note |
| [图](../../04-baby/baby-journey-growth-date-input/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-date-input/README.md) | 1 | Switch date picker to text input |
| [图](../../04-baby/baby-feeding-time-future-minute-input/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-future-minute-input/README.md) | 1 | Correct to 16:01 on today; one minute after current time |
| [图](../../04-baby/baby-development-controls-batch-responds-to-sound/default.png) · [入口及前驱](../../04-baby/baby-development-controls-batch-responds-to-sound/README.md) | 2 | Choose 暂未观察到 for 听到声音后有动作或表情反应 while preserving other groups |
| [图](../../04-baby/baby-profile-boundaries-year-list/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-year-list/README.md) | 1 | Tap calendar month header → year picker |
| [图](../../04-baby/baby-development-controls-responds-to-sound-unsure/default.png) · [入口及前驱](../../04-baby/baby-development-controls-responds-to-sound-unsure/README.md) | 1 | Select 听到声音后有动作或表情反应 → 不确定 |
| [图](../../04-baby/baby-diaper-controls-sign-both/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-sign-both/README.md) | 1 | Select mucus as well → both observations selected |
| [图](../../04-baby/baby-profile-recovery-local-draft/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-local-draft/README.md) | 1 | Edit name locally; server version remains 1 |
| [图](../../04-baby/baby-profile-controls-sex-male/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-sex-male/README.md) | 1 | Select profile sex male |
| [图](../../04-baby/baby-feeding-controls-expressed-milk-selected/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-expressed-milk-selected/README.md) | 1 | Switch to expressed milk → volume replaces nursing controls; nursing draft retained |
| [图](../../04-baby/baby-journey-development-editor/default.png) · [入口及前驱](../../04-baby/baby-journey-development-editor/README.md) | 1 | Tap record developmental observation |
| [图](../../04-baby/baby-development-date-earlier-date-input-mode/default.png) · [入口及前驱](../../04-baby/baby-development-date-earlier-date-input-mode/README.md) | 1 | Switch reopened calendar to date text input |
| [图](../../04-baby/baby-diaper-controls-consistency-formed/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-formed/README.md) | 1 | Select stool consistency 成形 |
| [图](../../04-baby/baby-diaper-controls-color-red/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-red/README.md) | 2 | Select stool color 红色 |
| [图](../../04-baby/baby-sleep-editor/default.png) · [入口及前驱](../../04-baby/baby-sleep-editor/README.md) | 1 | sleep editor remains usable at 390.0 / 1.0 |
| [图](../../04-baby/baby-journey-growth-undo-error/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-undo-error/README.md) | 1 | Undo batch → API failure retains saved measurements and retry |
| [图](../../04-baby/baby-profile-recovery-unconfirmed-leave-dialog/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-unconfirmed-leave-dialog/README.md) | 1 | Close pending save → uncertain-result warning |
| [图](../../04-baby/baby-development-controls-saving/default.png) · [入口及前驱](../../04-baby/baby-development-controls-saving/README.md) | 1 | Retry save → pending request and disabled saving action |
| [图](../../04-baby/baby-development-controls-responds-to-sound-notObserved/default.png) · [入口及前驱](../../04-baby/baby-development-controls-responds-to-sound-notObserved/README.md) | 3 | Select 听到声音后有动作或表情反应 → 暂未观察到 |
| [图](../../04-baby/baby-development-date-earlier-date-reopened/default.png) · [入口及前驱](../../04-baby/baby-development-date-earlier-date-reopened/README.md) | 2 | Reopen picker at selected date Sep 15 2025 |
| [图](../../04-baby/baby-journey-growth-invalid-value/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-invalid-value/README.md) | 1 | Save zero weight → measurement range validation |
| [图](../../04-baby/baby-diaper-controls-both-saved/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-both-saved/README.md) | 1 | Save combined diaper → one record with stool fields and trimmed note |
| [图](../../04-baby/baby-feeding-controls-duration-upper-bound/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-duration-upper-bound/README.md) | 1 | Enter valid 240 minute upper bound → validation cleared |
| [图](../../04-baby/baby-development-date-no-birth-picker/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-picker/README.md) | 1 | No birth date → earliest selectable date Jan 1 1900 |
| [图](../../04-baby/baby-profile-controls-birth-input/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-birth-input/README.md) | 1 | Calendar → birth date input |
| [图](../../04-baby/baby-journey-no-profile/default.png) · [入口及前驱](../../04-baby/baby-journey-no-profile/README.md) | 1 | More → Baby with no owned profile |
| [图](../../04-baby/baby-feeding-controls-side-deselected/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-side-deselected/README.md) | 2 | Tap save → 请选择这次亲喂的侧别。; no write request |
| [图](../../04-baby/baby-sleep-controls-wake-before-rejected/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-before-rejected/README.md) | 1 | Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request |
| [图](../../04-baby/baby-development-boundaries-save-pending/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-save-pending/README.md) | 1 | Save single observation → request pending |
| [图](../../04-baby/baby-sleep-controls-completed-now/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-completed-now/README.md) | 1 | Record wake now → same record updated, one hour complete |
| [图](../../04-baby/baby-feeding-controls-note-filled/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-note-filled/README.md) | 1 | Enter multiline note with boundary whitespace |
| [图](../../04-baby/baby-development-controls-all-cleared-rejected/default.png) · [入口及前驱](../../04-baby/baby-development-controls-all-cleared-rejected/README.md) | 2 | Tap save → 至少记录一项具体行为，拿不准可以选择“不确定”。; no write request |
| [图](../../04-baby/baby-knowledge-source-development-detail/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-development-detail/README.md) | 2 | Tap development knowledge card → complete article |
| [图](../../04-baby/baby-growth-controls-date-birth/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-birth/README.md) | 1 | Confirm birth date → earliest date accepted in draft |
| [图](../../04-baby/baby-development-management-sound-head-selected-lifts-head/default.png) · [入口及前驱](../../04-baby/baby-development-management-sound-head-selected-lifts-head/README.md) | 1 | Choose 不确定 for 俯卧时短暂抬起头; retain previous choices |
| [图](../../04-baby/baby-development-controls-lifts-head-unsure/default.png) · [入口及前驱](../../04-baby/baby-development-controls-lifts-head-unsure/README.md) | 2 | Select 俯卧时短暂抬起头 → 不确定 |
| [图](../../04-baby/baby-growth-controls-head-over/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-head-over/README.md) | 1 | Enter head circumference above maximum |
| [图](../../04-baby/baby-growth-controls-date-previous-day/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-previous-day/README.md) | 1 | Set yesterday for saved measurements |
| [图](../../04-baby/baby-growth-controls-weight-malformed-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-malformed-rejected/README.md) | 1 | Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request |
| [图](../../04-baby/baby-profile-controls-name-corrected/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-name-corrected/README.md) | 1 | Correct profile name → validation clears |
| [图](../../04-baby/baby-development-date-birth-cleared/default.png) · [入口及前驱](../../04-baby/baby-development-date-birth-cleared/README.md) | 2 | Clear birth date in profile draft |
| [图](../../04-baby/baby-development-boundaries-reopened-clean/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-reopened-clean/README.md) | 6 | Reopen after unconfirmed leave → fresh empty editable draft dated today |
| [图](../../04-baby/baby-development-date-known-birth-discard/default.png) · [入口及前驱](../../04-baby/baby-development-date-known-birth-discard/README.md) | 1 | Close date-modified draft → discard confirmation |
| [图](../../04-baby/baby-profile-controls-birth-future-rejected/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-birth-future-rejected/README.md) | 1 | Confirm future birth date → picker range error; original date preserved |
| [图](../../04-baby/baby-feeding-controls-duration-over-limit/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-duration-over-limit/README.md) | 1 | Tap save → 亲喂时长需要为 1–240 分钟，也可以留空。; no write request |
| [图](../../04-baby/baby-journey-development-unsure/default.png) · [入口及前驱](../../04-baby/baby-journey-development-unsure/README.md) | 1 | Select unsure observation status |
| [图](../../04-baby/baby-development-boundaries-date-future-rejected/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-date-future-rejected/README.md) | 1 | Submit future date → picker validation, draft date unchanged |
| [图](../../04-baby/baby-knowledge-source-diaper-home/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-diaper-home/README.md) | 2 | Pull to refresh with diaper data → production-selected knowledge card |
| [图](../../04-baby/baby-diaper-controls-note-expanded/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-note-expanded/README.md) | 1 | Expand optional diaper note |
| [图](../../04-baby/baby-growth-controls-weight-over-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-over-rejected/README.md) | 1 | Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request |
| [图](../../04-baby/baby-profile-recovery-reload-unavailable/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-reload-unavailable/README.md) | 1 | Reload fails 503 → preserved local draft; reload action disappears |
| [图](../../04-baby/baby-development-boundaries-next-month/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-next-month/README.md) | 1 | Next month → September calendar |
| [图](../../04-baby/baby-development-management-face-head-selected-lifts-head/default.png) · [入口及前驱](../../04-baby/baby-development-management-face-head-selected-lifts-head/README.md) | 1 | Choose 不确定 for 俯卧时短暂抬起头; retain previous choices |
| [图](../../04-baby/baby-development-date-no-birth-confirmed/default.png) · [入口及前驱](../../04-baby/baby-development-date-no-birth-confirmed/README.md) | 1 | Confirm earlier year → no-birth observation draft accepts date |
| [图](../../04-baby/baby-development-controls-uncertain-close/default.png) · [入口及前驱](../../04-baby/baby-development-controls-uncertain-close/README.md) | 1 | Close unconfirmed observation save → uncertainty warning |
| [图](../../04-baby/baby-feeding-controls-formula-selected/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-formula-selected/README.md) | 1 | Switch expressed milk → formula; bottle volume retained |
| [图](../../04-baby/baby-profile-controls-uncertain-leave-confirm/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-uncertain-leave-confirm/README.md) | 1 | Close unconfirmed save → uncertain-result leave dialog |
| [图](../../04-baby/baby-profile-boundaries-name-scroll-start/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-name-scroll-start/README.md) | 1 | Drag name field right → beginning of maximum-length name |
| [图](../../04-baby/baby-sleep-controls-start-time/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-start-time/README.md) | 1 | Confirm date → sleep start time picker |
| [图](../../04-baby/baby-feeding-controls-nursing-selected/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-nursing-selected/README.md) | 1 | Select nursing → side and optional duration appear |
| [图](../../04-baby/baby-knowledge-source-source-pending/default.png) · [入口及前驱](../../04-baby/baby-knowledge-source-source-pending/README.md) | 1 | External dispatch response pending → article remains interactive |
| [图](../../04-baby/baby-diaper-controls-color-green/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-color-green/README.md) | 1 | Select stool color 绿色 |
| [图](../../04-baby/baby-diaper-controls-home-dirty-only/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-home-dirty-only/README.md) | 1 | Return Baby → dirty count updated, wet count removed |
| [图](../../04-baby/baby-sleep-controls-wake-future/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-future/README.md) | 1 | Select wake 16:01 before validation |
| [图](../../04-baby/baby-profile-recovery-save-forbidden/default.png) · [入口及前驱](../../04-baby/baby-profile-recovery-save-forbidden/README.md) | 1 | Save returns 403 → access error, editable draft and no server update |
| [图](../../04-baby/baby-profile-controls-birth-changed/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-birth-changed/README.md) | 1 | Confirm valid birth date August 10 |
| [图](../../04-baby/baby-sleep-controls-active-collapsed/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-active-collapsed/README.md) | 2 | Collapse time and note controls without modifying record |
| [图](../../04-baby/baby-profile-controls-feeding-expressedMilk/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-expressedMilk/README.md) | 1 | Select feeding mode expressedMilk |
| [图](../../04-baby/baby-profile-boundaries-date-before-minimum/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-date-before-minimum/README.md) | 1 | Submit date before 1900 → range validation |
| [图](../../04-baby/baby-feeding-controls-home-count-only/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-home-count-only/README.md) | 1 | History Back → home counts feeding without invented ml |
| [图](../../04-baby/baby-feeding-time-time-open/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-time-open/README.md) | 1 | Confirm date → time picker; editor instant still unchanged |
| [图](../../04-baby/baby-development-boundaries-one-selected/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-one-selected/README.md) | 7 | Choose observed for one behavior only |
| [图](../../04-baby/baby-sleep-controls-wake-equal/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-wake-equal/README.md) | 1 | Select wake 15:00 before validation |
| [图](../../04-baby/baby-profile-boundaries-latest-month/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-latest-month/README.md) | 1 | Calendar next month → current month, future navigation disabled |
| [图](../../04-baby/baby-journey-sleep-active-editor/default.png) · [入口及前驱](../../04-baby/baby-journey-sleep-active-editor/README.md) | 1 | Tap active sleep → record wake time action |
| [图](../../04-baby/baby-switcher/default.png) · [入口及前驱](../../04-baby/baby-switcher/README.md) | 1 | switcher changes the selected baby and opens its profile at 390.0/1.0 |
| [图](../../04-baby/baby-journey-growth-profile-entry/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-profile-entry/README.md) | 1 | Growth reference missing data → complete profile |
| [图](../../04-baby/baby-profile-controls-feeding-mixed/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-feeding-mixed/README.md) | 1 | Select feeding mode mixed |
| [图](../../04-baby/baby-sleep-controls-active-manual-wake/default.png) · [入口及前驱](../../04-baby/baby-sleep-controls-active-manual-wake/README.md) | 1 | Choose manual wake 15:30 in active editor |
| [图](../../04-baby/baby-development-boundaries-birth-calendar/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-birth-calendar/README.md) | 2 | Reopen birth date and switch to calendar |
| [图](../../04-baby/baby-feeding-time-invalid-clock/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-invalid-clock/README.md) | 1 | Confirm hour 24/minute 60 → invalid time; picker remains |
| [图](../../04-baby/baby-diaper-controls-consistency-watery/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-watery/README.md) | 1 | Select stool consistency 水样 |
| [图](../../04-baby/baby-growth-controls-maxima-saved/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-maxima-saved/README.md) | 1 | Save atomic batch → three boundary fixture measurements shown on home |
| [图](../../04-baby/baby-growth-controls-date-open/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-date-open/README.md) | 2 | Open measurement date with birth-to-today range |
| [图](../../04-baby/baby-sleep-start/default.png) · [入口及前驱](../../04-baby/baby-sleep-start/README.md) | 1 | sleep-start keeps its primary action visible at 390.0/1.0 |
| [图](../../04-baby/baby-development-controls-responds-to-sound-observed/default.png) · [入口及前驱](../../04-baby/baby-development-controls-responds-to-sound-observed/README.md) | 1 | Select 听到声音后有动作或表情反应 → 观察到 |
| [图](../../04-baby/baby-journey-feeding-mode-menu/default.png) · [入口及前驱](../../04-baby/baby-journey-feeding-mode-menu/README.md) | 1 | Profile feeding mode → dropdown options |
| [图](../../04-baby/baby-growth-controls-empty-rejected/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-empty-rejected/README.md) | 2 | Tap save → 请至少填写一项测量数值。; no write request |
| [图](../../04-baby/baby-growth-missing-sex/default.png) · [入口及前驱](../../04-baby/baby-growth-missing-sex/README.md) | 1 | missing sex growth profile at 390.0/1.0 is actionable without fabricated reference |
| [图](../../04-baby/baby-feeding-controls-duration-zero/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-duration-zero/README.md) | 1 | Tap save → 亲喂时长需要为 1–240 分钟，也可以留空。; no write request |
| [图](../../04-baby/baby-development-controls-home-return/default.png) · [入口及前驱](../../04-baby/baby-development-controls-home-return/README.md) | 3 | Return Baby after developmental history edits |
| [图](../../04-baby/baby-profile-boundaries-removed-on-reload/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-removed-on-reload/README.md) | 1 | Reload list no longer contains current baby → access error and draft retained |
| [图](../../04-baby/baby-journey-growth-date-selected/default.png) · [入口及前驱](../../04-baby/baby-journey-growth-date-selected/README.md) | 1 | Choose previous measurement date → editor preserves all three values |
| [图](../../04-baby/baby-diaper-controls-consistency-pasty/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-pasty/README.md) | 1 | Select stool consistency 糊状 |
| [图](../../04-baby/baby-profile-boundaries-maximum-name-reopened/default.png) · [入口及前驱](../../04-baby/baby-profile-boundaries-maximum-name-reopened/README.md) | 1 | Reopen maximum-length saved name |
| [图](../../04-baby/baby-feeding-time-future-date-rejected/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-future-date-rejected/README.md) | 1 | Confirm tomorrow → date range validation, no time picker |
| [图](../../04-baby/baby-development-boundaries-home-entry/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-home-entry/README.md) | 39 | More → Baby before date and save boundaries |
| [图](../../04-baby/baby-journey-sleep-note/default.png) · [入口及前驱](../../04-baby/baby-journey-sleep-note/README.md) | 1 | Expand note and enter observation |
| [图](../../04-baby/baby-diaper-controls-consistency-unsure/default.png) · [入口及前驱](../../04-baby/baby-diaper-controls-consistency-unsure/README.md) | 1 | Select stool consistency 不确定 |
| [图](../../04-baby/baby-feeding-controls-side-left/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-side-left/README.md) | 2 | Tap 左侧 → selected nursing side |
| [图](../../04-baby/baby-development-controls-lifts-head-observed/default.png) · [入口及前驱](../../04-baby/baby-development-controls-lifts-head-observed/README.md) | 1 | Select 俯卧时短暂抬起头 → 观察到 |
| [图](../../04-baby/baby-feeding-controls-note-collapsed/default.png) · [入口及前驱](../../04-baby/baby-feeding-controls-note-collapsed/README.md) | 2 | Collapse note → filled marker and draft retained |
| [图](../../04-baby/baby-development-date-profile-editor/default.png) · [入口及前驱](../../04-baby/baby-development-date-profile-editor/README.md) | 4 | Edit current baby profile through switcher |
| [图](../../04-baby/baby-development-controls-looks-at-face-unsure/default.png) · [入口及前驱](../../04-baby/baby-development-controls-looks-at-face-unsure/README.md) | 1 | Select 看向靠近的脸 → 不确定 |
| [图](../../04-baby/baby-feeding-time-future-minute-selected/default.png) · [入口及前驱](../../04-baby/baby-feeding-time-future-minute-selected/README.md) | 1 | Confirm syntactically valid future minute into draft |
| [图](../../04-baby/baby-growth-controls-weight-zero/default.png) · [入口及前驱](../../04-baby/baby-growth-controls-weight-zero/README.md) | 1 | Enter weight 0 before save validation |

## 实际操作链与状态依据

[BABY-JOURNEYS.md](../BABY-JOURNEYS.md) · [BABY-PROFILE-CONTROLS.md](../BABY-PROFILE-CONTROLS.md) · [BABY-KNOWLEDGE-SOURCES.md](../BABY-KNOWLEDGE-SOURCES.md)
