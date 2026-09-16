# 服务购买、预约与信息采集正常入口补验

从已登录 More → Me → 专家陪伴计划进入正式服务路由，使用 MomCozyFlutterApp、GoRouter、生产 Repository 与 codec。HTTP、会话存储和原生依赖采用隔离实现；订单、付款卡号、宝宝资料、授权和预约均仅存于测试传输层，不请求真实交易或修改真实账号。

## 已执行的 9 条流程

1. 服务目录 → 专家团队 → 四个方案详情 → 各方案团队弹窗 → 返回目录与首页。
2. 购买前确认 → 地区未选/不支持 → 可购买 → 卡号校验 → 拒付 → 银行验证 → 成功 → 预约前确认 → 返回已购方案及目录 → 下拉刷新。
3. 预约前确认 → 地区不支持/紧急情况 → 合格 → 选时段 → 保留时间 → 关闭/重新打开确认 → 确认预约 → 信息采集 → 返回预约 → 取消/保留 → 取消失败/重试 → 方案详情 → 取消记录时间线。
4. 创建订单失败/原操作重试 → 关闭待付订单 → 目录刷新 → 恢复付款失败 Snackbar → 提示消失 → 同订单继续付款 → 提交中/结果不确定/重试成功 → 稍后预约。
5. 银行验证取消 → 无购买权益 → 新建订单 → 付款核对中 → 查询失败 → 完成模拟付款 → 已购。
6. 目录加载/失败/空目录/恢复 → 方案详情读取失败/恢复 → 付款功能未开放。
7. 预约专家选择 → 时段读取失败/空时段/恢复 → 保留失败/重试 → 确认失败/重试 → 信息采集。
8. 信息采集问题多选、目标、可选背景、喂养方式、授权说明/同意 → 离开保留草稿 → 保存中/不确定/离开警告/原内容重试 → 完成弹窗 → 查看预约 → 重开已填写表单 → 修改保存返回预约。
9. 预约日期日历/键盘/非法日期/取消/选择另一日期 → 信息采集读取失败/加载/恢复 → 出生日期日历、性别/地区菜单、撤销草稿授权 → 保存禁用 → 重新同意并保存 → 开始预问诊 → 正式 Cozymate 路由预填，未自动发送。

共 **96 个实际运行状态、19 张主长图**。每个状态均有实际路由、点击动作和前驱状态。

## 验证与采集修正

- 最终严格采集 **9 项通过、0 失败**：[日志](runs/20260913T115037-targeted/capture.log)、[命令](runs/20260913T115037-targeted/capture-command.json)、[结果](runs/20260913T115037-targeted/capture-result.json)。基准建立与严格证据采集分开执行，无像素容差放宽。
- 全仓 `flutter analyze --no-pub`：No issues found；[静态检查](service-journey-analyze.log)。修复了本轮服务测试传输层的两条 if 大括号提示，没有修改生产代码。
- 遍历时排除输入框自带滚动区，滚动实际页面寻找懒加载按钮；点击未命中警告升级为失败。保存前检查按钮可用，保存后检查生产 Repository 已提交请求；重复订单/时段请求检查操作头保持一致。
- 恢复付款失败的 Snackbar 实际遮挡底部按钮，分别采集显示和消失状态，再继续点击。
- 目录 Loading 等路由切换完成后采集，保持 HTTP gate 关闭。删除误将背后首页滚动范围纳入的旧长图，当前 Loading 是普通一屏状态。
- 信息采集首次保存才显示完成弹窗；已有信息保存修改后直接返回预约。测试按实际行为执行。

## 视觉复核

已查看全部 96 个窗口截图的 8 张汇总图及 19 张长图的 4 张汇总图，源文件与 SHA-256 位于[窗口清单](service-visual-review/overview-sources.json)、[长图清单](service-visual-review/long-sources.json)。单独复核服务目录全长、信息采集保存不确定全长、付款不确定全长：字段、错误区、底部重试按钮完整。当前 Loading 不再包含背景首页滚动范围。

汇总图用于逐状态检查整体布局，不宣称全仓每张长图均完成逐像素审核。页面错误提示会扩展成大块浅黄色背景；弹窗内容滚动后，窗口内可能只显示部分正文。保留实际界面，对应可滚动内容以长图完整展示。

## 当前产品观察

- 购买成功或生成待付订单后返回目录，目录沿用已加载数据。下拉刷新后才出现已购/继续付款入口；同时保留刷新前后截图。
- 取消预约成功直接返回方案详情，取消事件可在服务进度中查看。
- 信息采集勾选草稿授权不请求写接口，保存成功后才记录授权。开始预问诊只是进入已预填的对话页，不证明咨询信息已传给专家或 Agent。

## 剩余范围

服务专项仍需继续：已购计划提醒/通知授权、咨询前准备、设备与系统权限、入会与退出、已发布总结及续购的正式入口链；购买可用性和版本冲突的其它主要分支；信息采集多宝宝选择、字段校验/冲突/放弃，以及更多日期和授权变化。既有组件截图不能替代这些真实路由证明。

全 App 尚未完成所有可点击入口、系统权限及全体长图视觉审阅。文件完整性 PASS 只证明已有文件和引用一致，不是目标完成证明。

## 逐状态索引

| 状态 | 实际路由 | 操作 | 页面与完整证据 |
| --- | --- | --- | --- |
| booking-availability-error | `/services/episodes/service-episode/booking` | Refresh with slot read failure → error and retained selection | [截图/入口链](../08-expert-service/service-journey-booking-availability-error/README.md) |
| booking-cancel-confirm | `/services/episodes/service-episode/booking` | Cancel appointment → cancellation confirmation | [截图/入口链](../08-expert-service/service-journey-booking-cancel-confirm/README.md) |
| booking-cancel-error | `/services/episodes/service-episode/booking` | Cancel request fails → original operation retained | [截图/入口链](../08-expert-service/service-journey-booking-cancel-error/README.md) |
| booking-cancel-retained | `/services/episodes/service-episode/booking` | Keep appointment → confirmed details unchanged | [截图/入口链](../08-expert-service/service-journey-booking-cancel-retained/README.md) |
| booking-cancelled | `/services/feeding-confidence` | Retry cancellation → actual product returns to package detail | [截图/入口链](../08-expert-service/service-journey-booking-cancelled/README.md) |
| booking-cancelled-timeline | `/services/episodes/service-episode` | Package service progress → cancellation included in timeline | [截图/入口链](../08-expert-service/service-journey-booking-cancelled-timeline/README.md) |
| booking-confirm-error | `/services/episodes/service-episode/booking` | Confirm hold unavailable → retry original confirmation | [截图/入口链](../08-expert-service/service-journey-booking-confirm-error/README.md) |
| booking-confirm-recovered | `/services/appointments/service-appointment/intake` | Retry confirmation → intake page | [截图/入口链](../08-expert-service/service-journey-booking-confirm-recovered/README.md) |
| booking-confirmed-details | `/services/episodes/service-episode/booking` | Intake back → confirmed appointment details | [截图/入口链](../08-expert-service/service-journey-booking-confirmed-details/README.md) |
| booking-date-applied | `/services/episodes/service-episode/booking` | Confirm another date → availability reloaded | [截图/入口链](../08-expert-service/service-journey-booking-date-applied/README.md) |
| booking-date-calendar | `/services/episodes/service-episode/booking` | Open appointment date calendar | [截图/入口链](../08-expert-service/service-journey-booking-date-calendar/README.md) |
| booking-date-cancelled | `/services/episodes/service-episode/booking` | Cancel invalid date → original slot date retained | [截图/入口链](../08-expert-service/service-journey-booking-date-cancelled/README.md) |
| booking-date-input | `/services/episodes/service-episode/booking` | Switch appointment date picker to typed input | [截图/入口链](../08-expert-service/service-journey-booking-date-input/README.md) |
| booking-date-invalid | `/services/episodes/service-episode/booking` | Submit malformed appointment date → inline validation | [截图/入口链](../08-expert-service/service-journey-booking-date-invalid/README.md) |
| booking-date-selected | `/services/episodes/service-episode/booking` | Select September 14 in calendar before confirmation | [截图/入口链](../08-expert-service/service-journey-booking-date-selected/README.md) |
| booking-emergency | `/services/episodes/service-episode/booking` | Potential emergency selected → guidance and disabled booking | [截图/入口链](../08-expert-service/service-journey-booking-emergency/README.md) |
| booking-held | `/services/episodes/service-episode/booking` | Select slot → server hold and confirm time dialog | [截图/入口链](../08-expert-service/service-journey-booking-held/README.md) |
| booking-held-collapsed | `/services/episodes/service-episode/booking` | Close time confirmation → hold retained on booking page | [截图/入口链](../08-expert-service/service-journey-booking-held-collapsed/README.md) |
| booking-hold-error | `/services/episodes/service-episode/booking` | Hold unavailable → uncertain submission and retry CTA | [截图/入口链](../08-expert-service/service-journey-booking-hold-error/README.md) |
| booking-hold-recovered | `/services/episodes/service-episode/booking` | Retry original hold → confirmation dialog | [截图/入口链](../08-expert-service/service-journey-booking-hold-recovered/README.md) |
| booking-intake-entry | `/services/appointments/service-appointment/intake` | Confirm hold → actual intake route | [截图/入口链](../08-expert-service/service-journey-booking-intake-entry/README.md) |
| booking-no-slots | `/services/episodes/service-episode/booking` | Slot retry returns no availability → empty state | [截图/入口链](../08-expert-service/service-journey-booking-no-slots/README.md) |
| booking-precheck | `/services/episodes/service-episode/booking` | Owned package → booking precheck | [截图/入口链](../08-expert-service/service-journey-booking-precheck/README.md) |
| booking-provider-menu | `/services/episodes/service-episode/booking` | Open provider selector | [截图/入口链](../08-expert-service/service-journey-booking-provider-menu/README.md) |
| booking-region-blocked | `/services/episodes/service-episode/booking` | Unsupported booking region → cannot continue | [截图/入口链](../08-expert-service/service-journey-booking-region-blocked/README.md) |
| booking-slots | `/services/episodes/service-episode/booking` | Suitable and eligible → available and unavailable slots | [截图/入口链](../08-expert-service/service-journey-booking-slots/README.md) |
| catalog | `/services` | Me expert plan → actual service catalog | [截图/入口链](../08-expert-service/service-journey-catalog/README.md) |
| catalog-empty | `/services` | Retry returns no packages → empty catalog | [截图/入口链](../08-expert-service/service-journey-catalog-empty/README.md) |
| catalog-loading | `/services` | Catalog navigation with requests pending | [截图/入口链](../08-expert-service/service-journey-catalog-loading/README.md) |
| catalog-pull-refreshed | `/services` | Pull refresh → packages restored | [截图/入口链](../08-expert-service/service-journey-catalog-pull-refreshed/README.md) |
| catalog-read-error | `/services` | Catalog unavailable → full-page error | [截图/入口链](../08-expert-service/service-journey-catalog-read-error/README.md) |
| catalog-return | `/services` | All four package detail back paths → catalog | [截图/入口链](../08-expert-service/service-journey-catalog-return/README.md) |
| catalog-return-home | `/me` | Catalog back → Me | [截图/入口链](../08-expert-service/service-journey-catalog-return-home/README.md) |
| catalog-team | `/services` | Learn about team → provider modal | [截图/入口链](../08-expert-service/service-journey-catalog-team/README.md) |
| intake-birth-calendar | `/services/appointments/service-appointment/intake` | Open prefilled baby birth date calendar | [截图/入口链](../08-expert-service/service-journey-intake-birth-calendar/README.md) |
| intake-consent-info | `/services/appointments/service-appointment/intake` | Information use details → consent explanation dialog | [截图/入口链](../08-expert-service/service-journey-intake-consent-info/README.md) |
| intake-consent-withdrawn-draft | `/services/appointments/service-appointment/intake` | Uncheck draft consent → save disabled without server mutation | [截图/入口链](../08-expert-service/service-journey-intake-consent-withdrawn-draft/README.md) |
| intake-discard-confirm | `/services/appointments/service-appointment/intake` | Back with edited intake → discard confirmation | [截图/入口链](../08-expert-service/service-journey-intake-discard-confirm/README.md) |
| intake-feeding-menu | `/services/appointments/service-appointment/intake` | Open feeding method selector | [截图/入口链](../08-expert-service/service-journey-intake-feeding-menu/README.md) |
| intake-load-error | `/services/appointments/service-appointment/intake` | Confirmed appointment → intake read failure with retry | [截图/入口链](../08-expert-service/service-journey-intake-load-error/README.md) |
| intake-load-recovered | `/services/appointments/service-appointment/intake` | Read retry resolves → intact editable form | [截图/入口链](../08-expert-service/service-journey-intake-load-recovered/README.md) |
| intake-loading | `/services/appointments/service-appointment/intake` | Retry intake while read pending → loading view | [截图/入口链](../08-expert-service/service-journey-intake-loading/README.md) |
| intake-optional-filled | `/services/appointments/service-appointment/intake` | Choose concerns, goal and optional background | [截图/入口链](../08-expert-service/service-journey-intake-optional-filled/README.md) |
| intake-preconsult-completion | `/services/appointments/service-appointment/intake` | First intake save → completion choices | [截图/入口链](../08-expert-service/service-journey-intake-preconsult-completion/README.md) |
| intake-ready | `/services/appointments/service-appointment/intake` | Explicit consent → save enabled | [截图/入口链](../08-expert-service/service-journey-intake-ready/README.md) |
| intake-region-menu | `/services/appointments/service-appointment/intake` | Open intake current-state selector | [截图/入口链](../08-expert-service/service-journey-intake-region-menu/README.md) |
| intake-reopened | `/services/appointments/service-appointment/intake` | Reopen saved intake → populated data and granted consent | [截图/入口链](../08-expert-service/service-journey-intake-reopened/README.md) |
| intake-save-uncertain | `/services/appointments/service-appointment/intake` | Save unavailable → snapshot retained and retry enabled | [截图/入口链](../08-expert-service/service-journey-intake-save-uncertain/README.md) |
| intake-saved | `/services/appointments/service-appointment/intake` | Retry original snapshot → intake completion modal | [截图/入口链](../08-expert-service/service-journey-intake-saved/README.md) |
| intake-saved-return | `/services/episodes/service-episode/booking` | Save complete then view appointment → confirmed detail | [截图/入口链](../08-expert-service/service-journey-intake-saved-return/README.md) |
| intake-saving | `/services/appointments/service-appointment/intake` | Save response pending → fields locked | [截图/入口链](../08-expert-service/service-journey-intake-saving/README.md) |
| intake-sex-menu | `/services/appointments/service-appointment/intake` | Open recorded sex options | [截图/入口链](../08-expert-service/service-journey-intake-sex-menu/README.md) |
| intake-to-cozymate | `/` | Preconsult CTA → actual Cozymate route with context draft | [截图/入口链](../08-expert-service/service-journey-intake-to-cozymate/README.md) |
| intake-uncertain-leave | `/services/appointments/service-appointment/intake` | Back with uncertain save → reconciliation warning | [截图/入口链](../08-expert-service/service-journey-intake-uncertain-leave/README.md) |
| intake-unfilled | `/services/appointments/service-appointment/intake` | Confirmed booking → unfilled intake with profile prefill | [截图/入口链](../08-expert-service/service-journey-intake-unfilled/README.md) |
| intake-update-saved | `/services/episodes/service-episode/booking` | Modify saved intake → return to confirmed appointment | [截图/入口链](../08-expert-service/service-journey-intake-update-saved/README.md) |
| package-better-breastfeeding | `/services/better-breastfeeding` | Catalog 亲喂改善 → detail and purchase CTA | [截图/入口链](../08-expert-service/service-journey-package-better-breastfeeding/README.md) |
| package-comfortable-feeding | `/services/comfortable-feeding` | Catalog 舒适哺乳支持 → detail and purchase CTA | [截图/入口链](../08-expert-service/service-journey-package-comfortable-feeding/README.md) |
| package-feeding-confidence | `/services/feeding-confidence` | Catalog 喂养安心 → detail and purchase CTA | [截图/入口链](../08-expert-service/service-journey-package-feeding-confidence/README.md) |
| package-milk-supply-care | `/services/milk-supply-care` | Catalog 奶量管理 → detail and purchase CTA | [截图/入口链](../08-expert-service/service-journey-package-milk-supply-care/README.md) |
| package-payment-disabled | `/services/feeding-confidence` | Package with disabled payment mode → purchase unavailable | [截图/入口链](../08-expert-service/service-journey-package-payment-disabled/README.md) |
| package-read-error | `/services/feeding-confidence` | Enter package while API unavailable → detail error | [截图/入口链](../08-expert-service/service-journey-package-read-error/README.md) |
| package-read-recovered | `/services/feeding-confidence` | Retry package read → full detail | [截图/入口链](../08-expert-service/service-journey-package-read-recovered/README.md) |
| package-team-better-breastfeeding | `/services/better-breastfeeding` | Package detail → team information | [截图/入口链](../08-expert-service/service-journey-package-team-better-breastfeeding/README.md) |
| package-team-comfortable-feeding | `/services/comfortable-feeding` | Package detail → team information | [截图/入口链](../08-expert-service/service-journey-package-team-comfortable-feeding/README.md) |
| package-team-feeding-confidence | `/services/feeding-confidence` | Package detail → team information | [截图/入口链](../08-expert-service/service-journey-package-team-feeding-confidence/README.md) |
| package-team-milk-supply-care | `/services/milk-supply-care` | Package detail → team information | [截图/入口链](../08-expert-service/service-journey-package-team-milk-supply-care/README.md) |
| purchase-bank-challenge | `/services/feeding-confidence` | Challenge test card → bank verification | [截图/入口链](../08-expert-service/service-journey-purchase-bank-challenge/README.md) |
| purchase-cancelled-detail | `/services/feeding-confidence` | Cancelled order back → package can be purchased again | [截图/入口链](../08-expert-service/service-journey-purchase-cancelled-detail/README.md) |
| purchase-card-form | `/services/feeding-confidence` | Eligibility and order API responses → sandbox card form | [截图/入口链](../08-expert-service/service-journey-purchase-card-form/README.md) |
| purchase-challenge-cancelled | `/services/feeding-confidence` | Cancel bank verification → cancelled order with no entitlement | [截图/入口链](../08-expert-service/service-journey-purchase-challenge-cancelled/README.md) |
| purchase-declined | `/services/feeding-confidence` | Declined test card → retryable payment failure | [截图/入口链](../08-expert-service/service-journey-purchase-declined/README.md) |
| purchase-eligibility-empty | `/services/feeding-confidence` | Purchase → eligibility dialog | [截图/入口链](../08-expert-service/service-journey-purchase-eligibility-empty/README.md) |
| purchase-eligibility-ready | `/services/feeding-confidence` | Supported state → eligibility can be submitted | [截图/入口链](../08-expert-service/service-journey-purchase-eligibility-ready/README.md) |
| purchase-invalid-card | `/services/feeding-confidence` | Submit short card number → inline validation | [截图/入口链](../08-expert-service/service-journey-purchase-invalid-card/README.md) |
| purchase-later-booking | `/services/feeding-confidence` | Book later → owned detail without automatic booking | [截图/入口链](../08-expert-service/service-journey-purchase-later-booking/README.md) |
| purchase-order-error | `/services/feeding-confidence` | Order creation unavailable → retry retains eligibility | [截图/入口链](../08-expert-service/service-journey-purchase-order-error/README.md) |
| purchase-owned-catalog | `/services` | Package back → catalog retains prior loaded state until refresh | [截图/入口链](../08-expert-service/service-journey-purchase-owned-catalog/README.md) |
| purchase-owned-catalog-refreshed | `/services` | Pull refresh → catalog marks purchased plan | [截图/入口链](../08-expert-service/service-journey-purchase-owned-catalog-refreshed/README.md) |
| purchase-owned-detail | `/services/feeding-confidence` | Booking back → purchased package detail | [截图/入口链](../08-expert-service/service-journey-purchase-owned-detail/README.md) |
| purchase-payment-pending | `/services/feeding-confidence` | Payment response pending → controls and close disabled | [截图/入口链](../08-expert-service/service-journey-purchase-payment-pending/README.md) |
| purchase-payment-uncertain | `/services/feeding-confidence` | Payment unavailable → pending outcome retained for retry | [截图/入口链](../08-expert-service/service-journey-purchase-payment-uncertain/README.md) |
| purchase-pending-catalog | `/services` | Package back → catalog retains its previously loaded state | [截图/入口链](../08-expert-service/service-journey-purchase-pending-catalog/README.md) |
| purchase-pending-catalog-refreshed | `/services` | Pull refresh → pending order resume action | [截图/入口链](../08-expert-service/service-journey-purchase-pending-catalog-refreshed/README.md) |
| purchase-pending-detail | `/services/feeding-confidence` | Close unpaid order → continue payment on package | [截图/入口链](../08-expert-service/service-journey-purchase-pending-detail/README.md) |
| purchase-query-error | `/services/feeding-confidence` | Query reconciling payment fails → recoverable order error | [截图/入口链](../08-expert-service/service-journey-purchase-query-error/README.md) |
| purchase-reconciliation-complete | `/services/feeding-confidence` | Complete pending sandbox payment → purchased benefits | [截图/入口链](../08-expert-service/service-journey-purchase-reconciliation-complete/README.md) |
| purchase-reconciling | `/services/feeding-confidence` | Server payment reconciliation → query instead of duplicate payment | [截图/入口链](../08-expert-service/service-journey-purchase-reconciling/README.md) |
| purchase-region-menu | `/services/feeding-confidence` | Open current state selector | [截图/入口链](../08-expert-service/service-journey-purchase-region-menu/README.md) |
| purchase-resume-error | `/services/feeding-confidence` | Resume order read fails → snackbar on package | [截图/入口链](../08-expert-service/service-journey-purchase-resume-error/README.md) |
| purchase-resume-message-dismissed | `/services/feeding-confidence` | Transient error snackbar expires → payment CTA unobscured | [截图/入口链](../08-expert-service/service-journey-purchase-resume-message-dismissed/README.md) |
| purchase-resumed-form | `/services/feeding-confidence` | Retry resume → same order card form | [截图/入口链](../08-expert-service/service-journey-purchase-resumed-form/README.md) |
| purchase-retry-success | `/services/feeding-confidence` | Retry same outcome → payment and benefits confirmed | [截图/入口链](../08-expert-service/service-journey-purchase-retry-success/README.md) |
| purchase-success | `/services/feeding-confidence` | Confirm bank verification → purchased benefits | [截图/入口链](../08-expert-service/service-journey-purchase-success/README.md) |
| purchase-to-booking | `/services/episodes/service-episode/booking` | Purchase success CTA → booking route and precheck | [截图/入口链](../08-expert-service/service-journey-purchase-to-booking/README.md) |
| purchase-unsupported-region | `/services/feeding-confidence` | Unsupported state and acknowledgment → blocked CTA | [截图/入口链](../08-expert-service/service-journey-purchase-unsupported-region/README.md) |
