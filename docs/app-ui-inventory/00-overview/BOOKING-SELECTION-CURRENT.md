# 当前专家、日期选择及预约保留与确认

从正式 App 的 More → Me → 已购计划 → 预约咨询进入，实际填写预约前确认后开始。复用 GoRouter、BookingPage、BookingController、BookingSelectionDialog、共享日期选择器、AppointmentApiRepository 及正式 codec。会话、HTTP 响应和固定业务时钟为隔离依赖；本批未建立真实预约或发送通知。

393 px / 1x 与 320 px / 2x 各运行两条操作链。普通字号支持日历与年份选择；大字号按照正式组件逻辑使用日期输入，未强行构造日历状态。

## 实际执行的链路

| 操作 | 结果与验证 |
| --- | --- |
| 专家下拉选择 | 打开两位专家菜单 → 选择 East Coast IBCLC → 时段加载 → 时区改为 America/New_York，17:00 UTC 显示为 13:00 EDT；验证请求 provider_id |
| 日历浏览 | 普通字号下打开日历 → 下月 → 上月 → 年份选择 → 2026 年 → 点击 14 日 → 切换输入；大字号直接进入输入模式 |
| 日期校验 | 格式错误、早于今天、超过 90 天分别提交并显示错误；验证选择范围为 2026-09-13 至 2026-12-12 |
| 日期取消与保存 | 取消错误输入保留原日期；重开输入明天并确认，验证 availability 请求 date=2026-09-14 |
| 专家切回 | 改回 Pacific 专家，日期保留为 9 月 14 日，时区和时段显示改回 PDT |
| 保留时段 | 点击可用时段 → 请求挂起 → HTTP 503 → 重试；验证重试请求体及 Idempotency-Key 与首次相同；成功打开确认预约时间 |
| 提醒草稿 | 点击提前 15 分钟提醒为勾选，再点击取消勾选；本链确认时提醒关闭，没有将草稿当作已启用系统提醒 |
| 关闭／重开 | 关闭确认弹窗后时段仍为 held；专家及日期不可改，选中时段有勾选；点击查看所选时间重新打开 |
| 重新选择 | 发出取消 held 请求 → 等待 → HTTP 503 → 重试上次提交 → 取消成功，弹窗关闭、时段选择恢复 |
| 再次保留 | 再次点击时段产生新 hold，验证使用新的 Idempotency-Key，并打开确认弹窗 |
| 确认预约 | 提交 expected_version → 请求挂起，框架返回不能关闭弹窗 → HTTP 503 → 重试相同请求体 → confirmed |
| 确认后导航 | 自动进入正式信息采集表 → 未编辑直接返回 → 已确认预约详情 → 返回 Me，首页显示下次咨询及填写信息入口 |

所有页面变化来自正常路由与实际控件点击；错误由 HTTP 边界返回，未直接调用控制器私有状态。

## 图像、审阅和边界

35 个状态，67 份窗口、34 张完整长图，8 个状态以长图作为主图。101 张 PNG 按全宽连续切为 225 段，其中 137 个唯一片段完整审阅：117 个新增片段共 20 张审阅页，20 个引用此前已审阅且像素一致的片段。修正测试 if 大括号后再次严格采集，101 张 PNG 哈希完全一致。

- 预约确认长图包含咨询身份、时区、保留时间、提醒、错误、重试和重新选择按钮；信息采集长图覆盖到信息使用授权及保存按钮。
- 普通日历的下月、年份和日期格只在普通字号实际存在，因此这三个状态没有伪造 2x 变体。
- 日期选择器的今天描边使用组件默认系统日期，本次为 9 月 14 日；预约业务时钟固定在 9 月 13 日。范围和选择值由正式 BookingPage 传入，截图保留当前实际行为。
- 大字号下专家菜单闭合文本、标题与时区按当前布局缩略或换行。返回首页后“填写信息”按钮的文字仍为低对比灰色，作为当前视觉表现记录，未声称本批修复。
- 提醒实际启用、通知权限与保存失败，以及信息采集内部填写保存，并未因到达其入口就视为本批完成。

[全宽审阅映射](booking-selection-current-visual-review/sources.json) · [像素／源码／前驱审计](booking-selection-current-evidence-audit.json) · [采集源码快照](booking-selection-current-capture-source-snapshot.json)。

## 逐状态入口与图片

| 实际操作 | 图片与运行来源 |
| --- | --- |
| Pending Back blocked; confirm HTTP 503 → retry | [状态证据](../08-expert-service/booking-selection-current-confirm-error/README.md) |
| Confirm held appointment → expected-version request pending | [状态证据](../08-expert-service/booking-selection-current-confirm-pending/README.md) |
| Return from unchanged intake → confirmed booking detail | [状态证据](../08-expert-service/booking-selection-current-confirmed-detail/README.md) |
| Retry confirmation → real information intake page | [状态证据](../08-expert-service/booking-selection-current-confirmed-intake/README.md) |
| Confirm beyond 90 days → out-of-range error | [状态证据](../08-expert-service/booking-selection-current-date-after-window/README.md) |
| Confirm date → September 14 availability | [状态证据](../08-expert-service/booking-selection-current-date-applied/README.md) |
| Confirm past date → out-of-range error | [状态证据](../08-expert-service/booking-selection-current-date-before-today/README.md) |
| Cancel date input → prior September 13 preserved | [状态证据](../08-expert-service/booking-selection-current-date-cancelled/README.md) |
| Select September 14, awaiting confirmation | [状态证据](../08-expert-service/booking-selection-current-date-day-selected/README.md) |
| Confirm malformed date → validation error | [状态证据](../08-expert-service/booking-selection-current-date-invalid/README.md) |
| Next month → October calendar | [状态证据](../08-expert-service/booking-selection-current-date-next-month/README.md) |
| Open date picker; large text uses input only | [状态证据](../08-expert-service/booking-selection-current-date-open/README.md) |
| Enter tomorrow → valid date draft | [状态证据](../08-expert-service/booking-selection-current-date-valid-input/README.md) |
| Calendar header → year selection | [状态证据](../08-expert-service/booking-selection-current-date-year-menu/README.md) |
| Close review → time remains held; provider and date disabled | [状态证据](../08-expert-service/booking-selection-current-held-closed/README.md) |
| View selected time → reopen review | [状态证据](../08-expert-service/booking-selection-current-held-reopened/README.md) |
| Retry same idempotency key → held appointment review | [状态证据](../08-expert-service/booking-selection-current-held-review/README.md) |
| Hold HTTP 503 → unresolved submission with retry | [状态证据](../08-expert-service/booking-selection-current-hold-error/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-selection-current-hold-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-selection-current-hold-home-return/README.md) |
| Select available time → hold request pending | [状态证据](../08-expert-service/booking-selection-current-hold-pending/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-selection-current-hold-slots/README.md) |
| Select east coast expert → new timezone and times pending | [状态证据](../08-expert-service/booking-selection-current-provider-loading/README.md) |
| Provider dropdown → two available experts | [状态证据](../08-expert-service/booking-selection-current-provider-menu/README.md) |
| Switch back to Pacific expert → keep date and change timezone | [状态证据](../08-expert-service/booking-selection-current-provider-return/README.md) |
| Availability loaded in America/New_York | [状态证据](../08-expert-service/booking-selection-current-provider-selected/README.md) |
| Disable reminder draft | [状态证据](../08-expert-service/booking-selection-current-reminder-cleared/README.md) |
| Enable reminder draft | [状态证据](../08-expert-service/booking-selection-current-reminder-selected/README.md) |
| Cancel hold HTTP 503 → retry previous submission | [状态证据](../08-expert-service/booking-selection-current-reselect-error/README.md) |
| Reselect → cancel held time pending | [状态证据](../08-expert-service/booking-selection-current-reselect-pending/README.md) |
| Retry cancel → review closes and time selection restored | [状态证据](../08-expert-service/booking-selection-current-reselect-restored/README.md) |
| Select again → fresh hold review | [状态证据](../08-expert-service/booking-selection-current-second-held/README.md) |
| More → Me → owned service | [状态证据](../08-expert-service/booking-selection-current-selection-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-selection-current-selection-home-return/README.md) |
| Complete precheck → available times | [状态证据](../08-expert-service/booking-selection-current-selection-slots/README.md) |

## 验证与后续范围

4 项严格采集通过，不更新 Golden；`flutter --suppress-analytics analyze --no-pub lib test integration_test` 通过。本次新增采集测试、截图和报告，没有修改产品代码。专项静态检查不等于全仓文档快照也通过。

- [严格采集日志](runs/20260914T022936-targeted/capture.log)
- [代码与测试静态检查](booking-selection-current-analyze.log)
- [完整性检查](booking-selection-current-final-verify.log)

[预约前确认](BOOKING-PRECHECK-CURRENT.md) 与本批串联已有正常购买后的预约主链。保留过期、资格失效、时段冲突及其他业务拒绝、未决操作关闭后恢复、已确认取消、提醒启用和信息采集／咨询／总结内部流程仍须继续核对。完整目标保持 **NOT_PROVEN**。
