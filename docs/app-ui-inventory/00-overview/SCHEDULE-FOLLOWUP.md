# 日程分支、分页边界与 Android 原生入口补验

本轮新增 **43 个实际路由状态、17 张主长图、8 张 Android 当前安装 App 截图**。日程专项现有 96 个路由观察点。保持原有产品行为，未修改生产页面或写入当前账号日程。

## 新增实际链路

- 393 常规字号和 320/2x 大字号：新增表单 → 日期文字输入格式错误/超出允许范围/修正 → 时间输入错误/改为 10:45 → 保存至 9 月 15 日 → 断言服务层日期、时间与界面一致。
- 添加、下个月按钮长按 Tooltip；日历年份列表 → 选择 2027 → 确认至编辑器 → 放弃未保存的草稿。
- 照护任务提交等待/控件禁用/完成；个人日程修改冲突、删除冲突 Snackbar；下拉刷新后服务器原记录保留。
- 已确认预约查看 → 咨询准备 → 系统返回日程；待确认、已取消、已过期预约分别进入真实 room 路由并返回。待确认和已过期继续点击信息采集入口，到达“请先确认预约时间”的阻断页，再返回准备页和日程。
- 101 条服务器个人日程 → 首批 100 条 → 从头滚动到第 100 条 → 没有继续加载入口 → 点击第 101 条所在日期 → 显示无安排。
- Android 当前 App：妈妈 → Schedule → 新增空表单 → 日期/取消 → 时间/取消 → 关闭表单 → 原日程 → 原妈妈页。未输入文字、保存或删除；恢复前后语义标签一致。详见[原生记录](../native/schedule/README.md)。

## 已复现的产品问题

### 日程分页没有后续入口

后端 `/v1/schedule` 支持 offset/limit/has_more。真实 ScheduleApiRepository 请求 limit=100，ScheduleController 只请求 offset=0，SchedulePage 未提供下一页入口。本轮隔离 HTTP 按后端的 start/end/offset/limit 裁切数据。101 条中前 100 条位于 9 月 13 日，第 101 条位于 9 月 14 日；实际点击后，9 月 14 日被显示为空。

断言仅一次日程读取、offset=0，第 101 条未出现在已渲染 UI。8933 px 长图完整包含前 100 条与末尾导航；不能把未加载的第 101 条补画成当前 App 内容。[完整首批](../06-schedule/schedule-journey-first-page-overflow/README.md)、[末尾](../06-schedule/schedule-journey-first-page-end/README.md)、[错误空日](../06-schedule/schedule-journey-unloaded-day-empty/README.md)。

### 待确认预约进入无法确认的链路

日程待确认预约的“确认”实际跳转 `/services/appointments/:id/room`，显示咨询准备，缺少信息采集时开始按钮禁用。点击信息采集后提示“请先确认预约时间”，这条路径没有完成预约确认的入口。已过期 hold 也进入相同的信息采集阻断页，而非重约引导。

本轮按后端约束设置 held/expired 尚未确认、未提交 intake；已发布照护任务关联较早预约。未将“未确认但已提交 intake”的不一致数据当作有效状态。GET room context 可以读取这些状态；后端提交 intake 要求 confirmed/in_progress，与实际阻断 UI 一致。[待确认入口](../06-schedule/schedule-journey-appointment-held/README.md)、[准备页](../06-schedule/schedule-journey-appointment-held-route/README.md)、[信息采集阻断](../06-schedule/schedule-journey-appointment-held-intake/README.md)。

## 证据和校验

- 全部 16 条日程流程严格采集通过，0 失败：[日志](runs/20260913T124205-targeted/capture.log)、[命令](runs/20260913T124205-targeted/capture-command.json)、[结果](runs/20260913T124205-targeted/capture-result.json)。未放宽像素容差。此前 75 文件/961 通过的全量视觉回归见上轮报告；本轮只改日程测试及其 HTTP fixture，未重跑全量。
- 当前全仓静态检查 No issues found：[日志](schedule-followup-analyze.log)。两个变更 Dart 文件格式检查通过。
- 已查看新增窗口汇总、17 张新增长图汇总、更新后的 held/expired 原图，以及原生日程表单和时间选择器。100 条长图另拆为 9 个连续检查窗口，逐段看过顶部、第 1–100 条和底部导航；没有把缩略细线当作充分审阅。
- 来源路径和 SHA-256：[新增窗口](schedule-followup-visual-review/overview-sources.json)、[新增长图](schedule-followup-visual-review/long-sources.json)、[分页长图逐段审阅](schedule-followup-visual-review/pagination-sources.json)。原生版本、前驱与恢复校验见[原生 evidence](../native/schedule/evidence.json)。
- 文件完整性检查 PASS：878 条目、1925 个变体、709 个长图测量、502 个实际路由状态。目标仍为 NOT_PROVEN；完整性不等于覆盖完成。

## 尚未完成

日程仍需继续核对进行中咨询的日程入口、取消后的重约/总结按钮完整返回链、其余 Tooltip、鉴权/离线编辑分支及跨月份缓存边界。上述已发现的问题保持当前真实 UI，不把产品修复混同于页面盘点。

全 App 还需其它模块真实入口和条件分支、系统权限层、全体长图审阅及无正常入口代码最终清单。工作台继续单列。

## 新增逐状态索引

| 状态 | 实际路由 | 操作 | 截图与前驱 |
| --- | --- | --- | --- |
| add-tooltip | `/schedule` | Long press add → tooltip | [状态证据](../06-schedule/schedule-journey-add-tooltip/README.md) |
| appointment-cancelled | `/schedule` | Schedule → appointment status cancelled | [状态证据](../06-schedule/schedule-journey-appointment-cancelled/README.md) |
| appointment-cancelled-return | `/schedule` | System back → cancelled agenda retained | [状态证据](../06-schedule/schedule-journey-appointment-cancelled-return/README.md) |
| appointment-cancelled-route | `/services/appointments/service-appointment/room` | Appointment action → actual room preparation for cancelled | [状态证据](../06-schedule/schedule-journey-appointment-cancelled-route/README.md) |
| appointment-entry | `/schedule` | Schedule → confirmed consultation | [状态证据](../06-schedule/schedule-journey-appointment-entry/README.md) |
| appointment-expired | `/schedule` | Schedule → appointment status expired | [状态证据](../06-schedule/schedule-journey-appointment-expired/README.md) |
| appointment-expired-intake | `/services/appointments/service-appointment/intake` | Preparation intake link → actual intake route for expired | [状态证据](../06-schedule/schedule-journey-appointment-expired-intake/README.md) |
| appointment-expired-intake-return | `/services/appointments/service-appointment/room` | Unchanged intake system back → preparation | [状态证据](../06-schedule/schedule-journey-appointment-expired-intake-return/README.md) |
| appointment-expired-return | `/schedule` | System back → expired agenda retained | [状态证据](../06-schedule/schedule-journey-appointment-expired-return/README.md) |
| appointment-expired-route | `/services/appointments/service-appointment/room` | Appointment action → actual room preparation for expired | [状态证据](../06-schedule/schedule-journey-appointment-expired-route/README.md) |
| appointment-held | `/schedule` | Schedule → appointment status held | [状态证据](../06-schedule/schedule-journey-appointment-held/README.md) |
| appointment-held-intake | `/services/appointments/service-appointment/intake` | Preparation intake link → actual intake route for held | [状态证据](../06-schedule/schedule-journey-appointment-held-intake/README.md) |
| appointment-held-intake-return | `/services/appointments/service-appointment/room` | Unchanged intake system back → preparation | [状态证据](../06-schedule/schedule-journey-appointment-held-intake-return/README.md) |
| appointment-held-return | `/schedule` | System back → held agenda retained | [状态证据](../06-schedule/schedule-journey-appointment-held-return/README.md) |
| appointment-held-route | `/services/appointments/service-appointment/room` | Appointment action → actual room preparation for held | [状态证据](../06-schedule/schedule-journey-appointment-held-route/README.md) |
| appointment-return | `/schedule` | System back from preparation → Schedule | [状态证据](../06-schedule/schedule-journey-appointment-return/README.md) |
| appointment-room-route | `/services/appointments/service-appointment/room` | Confirmed consultation view → real preparation route | [状态证据](../06-schedule/schedule-journey-appointment-room-route/README.md) |
| delete-conflict | `/schedule` | Delete stale event → uncertain deletion feedback | [状态证据](../06-schedule/schedule-journey-delete-conflict/README.md) |
| edit-conflict | `/schedule` | Existing event changed on server → update conflict | [状态证据](../06-schedule/schedule-journey-edit-conflict/README.md) |
| first-page-end | `/schedule` | Scroll to final loaded event → no load-more control | [状态证据](../06-schedule/schedule-journey-first-page-end/README.md) |
| first-page-overflow | `/schedule` | 101 server events → first 100 rendered; full scroll evidence | [状态证据](../06-schedule/schedule-journey-first-page-overflow/README.md) |
| large-picker-date-corrected | `/schedule` | Correct date → editor retains September 15 | [状态证据](../06-schedule/schedule-journey-large-picker-date-corrected/README.md) |
| large-picker-date-invalid | `/schedule` | Enter invalid date → validation without dismissal | [状态证据](../06-schedule/schedule-journey-large-picker-date-invalid/README.md) |
| large-picker-date-out-of-range | `/schedule` | Enter date beyond allowed years → range error | [状态证据](../06-schedule/schedule-journey-large-picker-date-out-of-range/README.md) |
| large-picker-editor | `/schedule` | Add event → responsive editor | [状态证据](../06-schedule/schedule-journey-large-picker-editor/README.md) |
| large-picker-saved | `/schedule` | Save corrected date/time → selected day agenda | [状态证据](../06-schedule/schedule-journey-large-picker-saved/README.md) |
| large-picker-time-corrected | `/schedule` | Correct time to 10:45 → editor | [状态证据](../06-schedule/schedule-journey-large-picker-time-corrected/README.md) |
| large-picker-time-invalid | `/schedule` | Enter hour 25 → time validation | [状态证据](../06-schedule/schedule-journey-large-picker-time-invalid/README.md) |
| next-tooltip | `/schedule` | Long press next month → tooltip | [状态证据](../06-schedule/schedule-journey-next-tooltip/README.md) |
| picker-date-corrected | `/schedule` | Correct date → editor retains September 15 | [状态证据](../06-schedule/schedule-journey-picker-date-corrected/README.md) |
| picker-date-invalid | `/schedule` | Enter invalid date → validation without dismissal | [状态证据](../06-schedule/schedule-journey-picker-date-invalid/README.md) |
| picker-date-out-of-range | `/schedule` | Enter date beyond allowed years → range error | [状态证据](../06-schedule/schedule-journey-picker-date-out-of-range/README.md) |
| picker-editor | `/schedule` | Add event → responsive editor | [状态证据](../06-schedule/schedule-journey-picker-editor/README.md) |
| picker-saved | `/schedule` | Save corrected date/time → selected day agenda | [状态证据](../06-schedule/schedule-journey-picker-saved/README.md) |
| picker-time-corrected | `/schedule` | Correct time to 10:45 → editor | [状态证据](../06-schedule/schedule-journey-picker-time-corrected/README.md) |
| picker-time-invalid | `/schedule` | Enter hour 25 → time validation | [状态证据](../06-schedule/schedule-journey-picker-time-invalid/README.md) |
| pull-refresh-reconciled | `/schedule` | Pull refresh → event retained with server state | [状态证据](../06-schedule/schedule-journey-pull-refresh-reconciled/README.md) |
| task-write-finished | `/schedule` | Response → completed task | [状态证据](../06-schedule/schedule-journey-task-write-finished/README.md) |
| task-write-pending | `/schedule` | Complete task → request pending; controls disabled | [状态证据](../06-schedule/schedule-journey-task-write-pending/README.md) |
| unloaded-day-empty | `/schedule` | Select day of unrequested event 101 → empty agenda; product gap | [状态证据](../06-schedule/schedule-journey-unloaded-day-empty/README.md) |
| year-editor | `/schedule` | Confirm future year → editor | [状态证据](../06-schedule/schedule-journey-year-editor/README.md) |
| year-selected | `/schedule` | Choose 2027 → calendar for selected year | [状态证据](../06-schedule/schedule-journey-year-selected/README.md) |
| year-selector | `/schedule` | Date header → year selector | [状态证据](../06-schedule/schedule-journey-year-selector/README.md) |
