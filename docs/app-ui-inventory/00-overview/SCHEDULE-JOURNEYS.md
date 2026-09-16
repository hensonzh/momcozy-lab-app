# 日程实际路由与操作状态补验

后续新增 43 个状态、分页及待确认预约入口问题、Android 原生证据见 [SCHEDULE-FOLLOWUP.md](SCHEDULE-FOLLOWUP.md)。以下为首轮 53 状态的执行记录。

新增 **53 个真实 App 路由状态、13 张完整长图**。正式页面、路由、Controller、Repository 和 DTO 均保持原实现；测试仅替换 HTTP 数据及既有平台依赖，不写入当前账号的个人日程或照护任务。

## 已执行的 7 条流程

1. More → Schedule → 上/下月 → 返回今天 → 新增空表单/已填表单 → 日期选择并确认 → 时间选择 → 保存 → 更多菜单 → 修改/保存 → 删除确认/保留/确认删除 → 空日程。
2. 新增草稿 → 关闭/放弃确认/继续填写 → HTTP 503 保存结果未确认 → 锁定字段/关闭提醒 → 同一幂等键重试/请求等待/保存成功 → 修改草稿并放弃。断言只有一条新增记录。
3. 首次加载等待/读取错误/重试 → 新增日程 → 删除失败 Snackbar/再次删除成功 → 切换月份读取失败、保留缓存 → 重试恢复。
4. 保存 422 校验失败 → 409 冲突提示 → 保留草稿再次保存成功。
5. 已购服务日程 → 任务菜单 → 进行中/跳过/恢复待完成 → 勾选完成/取消完成 → 保存失败/刷新核对 → 展开当前照护方案 → 点击进入真实服务进度路由。
6. 两个服务期 → 服务选择菜单 → 单服务高亮/全部服务恢复 → 已完成咨询的“总结”进入真实咨询总结路由。
7. 新增 → 日期文字输入/取消 → 时间键盘输入/取消 → 无修改直接关闭 → 任务菜单“查看服务计划”进入真实服务进度路由。

每个截图断言当前路由，记录触发动作与前驱截图。所有点击启用 hit-test 警告失败检查。数据时钟固定为 2026-09-13，用户/预约/服务为隔离 fixture；不能将其作为真实服务交易或远程数据写入证明。

## 长图修正与验证

视觉检查发现日程固定“添加”按钮在旧长图拼接处留下重复边缘。采集器现在测量同一路由、滚动文档之外的底部 Positioned 浮层，以其实际上边界和阴影余量决定内部截取范围，最后一帧保留真实按钮。源窗口未改动，也未放宽金图容差。

- 最終全量视觉采集：**75 个测试文件，961 通过，6 个既有跳过，0 失败**，运行 55 秒。见 [日志](capture.log)、[命令](capture-command.json)、[结果](capture-result.json)。这是全量视觉场景采集，不是所有非视觉单元测试。
- 日程专项严格采集：7 项通过，见 [专项日志](runs/20260913T123215-targeted/capture.log)。全量重采包含这 7 项。
- 全仓静态检查：No issues found，见 [日志](schedule-journey-analyze.log)。三个变更 Dart 文件格式检查通过。
- 已查看全部 53 个窗口的五张汇总图、修正后 13 张长图的三张汇总图，并单独检查完整展开方案。额外检查固定浮层修正涉及的服务进度和 Agent 长图代表场景。哈希与路径见 [窗口审阅来源](schedule-visual-review/overview-sources.json)、[长图审阅来源](schedule-visual-review/long-sources.json)。
- 全部产物文件/PNG/哈希/测量范围/链接验证 PASS；当前 835 条目、459 个真实路由状态。该检查不证明全 App 覆盖完成。

## 当前产品观察与剩余范围

- 服务选择器只过滤日历服务期高亮，不过滤当天所有任务与咨询，截图保留实际行为。
- 任务“查看服务计划”和展开卡片的“查看照护方案”均实际进入服务进度页，而不是独立任务详情页。
- 保存或删除失败的提示使用“结果暂未确认”，保存重试保持原幂等键。输入锁定、可继续填写及离开警告已分别记录。
- 日程专项还需补：未完成预约的查看/确认入口、咨询其它状态返回链；实际改变时间、日期/时间输入错误、年份选择、大字号/小屏路径；Tooltip、任务写入等待、更新/删除冲突与下拉刷新，以及超过首批数量时的可达内容检查。
- 全 App 仍有其它入口和条件状态、系统权限层、全体长图审核及无正常入口代码最终分类未完成。保持完整目标，不将本模块新增证据当作整体完成。

## 逐状态索引

| 状态 | 实际路由 | 触发操作 | 截图与前驱 |
| --- | --- | --- | --- |
| care | `/schedule` | Schedule tab → appointment and published task | [状态证据](../06-schedule/schedule-journey-care/README.md) |
| clean-editor-closed | `/schedule` | Close unchanged editor → agenda without discard prompt | [状态证据](../06-schedule/schedule-journey-clean-editor-closed/README.md) |
| conflict | `/schedule` | Retry HTTP 409 → conflict feedback | [状态证据](../06-schedule/schedule-journey-conflict/README.md) |
| consultation-summary-route | `/services/appointments/service-appointment/summary` | Completed appointment summary → actual published summary route | [状态证据](../06-schedule/schedule-journey-consultation-summary-route/README.md) |
| create-empty | `/schedule` | Today heading → add; empty title disables save | [状态证据](../06-schedule/schedule-journey-create-empty/README.md) |
| create-filled | `/schedule` | Enter title and note | [状态证据](../06-schedule/schedule-journey-create-filled/README.md) |
| created | `/schedule` | Save → refresh selected September 14 agenda | [状态证据](../06-schedule/schedule-journey-created/README.md) |
| date-cancelled | `/schedule` | Cancel date picker → original date retained | [状态证据](../06-schedule/schedule-journey-date-cancelled/README.md) |
| date-changed | `/schedule` | Select September 14 → OK | [状态证据](../06-schedule/schedule-journey-date-changed/README.md) |
| date-input | `/schedule` | Date calendar → text input mode | [状态证据](../06-schedule/schedule-journey-date-input/README.md) |
| date-picker | `/schedule` | Date field → calendar dialog | [状态证据](../06-schedule/schedule-journey-date-picker/README.md) |
| delete-cancelled | `/schedule` | Keep event → agenda unchanged | [状态证据](../06-schedule/schedule-journey-delete-cancelled/README.md) |
| delete-confirm | `/schedule` | Delete → confirmation | [状态证据](../06-schedule/schedule-journey-delete-confirm/README.md) |
| delete-error | `/schedule` | Delete fails → uncertain snackbar, event retained | [状态证据](../06-schedule/schedule-journey-delete-error/README.md) |
| delete-recovered | `/schedule` | Reopen delete and confirm → event removed | [状态证据](../06-schedule/schedule-journey-delete-recovered/README.md) |
| deleted | `/schedule` | Confirm delete → empty selected day | [状态证据](../06-schedule/schedule-journey-deleted/README.md) |
| discard-confirm | `/schedule` | Close dirty editor → discard confirmation | [状态证据](../06-schedule/schedule-journey-discard-confirm/README.md) |
| discarded | `/schedule` | Leave → unsaved note discarded | [状态证据](../06-schedule/schedule-journey-discarded/README.md) |
| draft-kept | `/schedule` | Continue filling → draft retained | [状态证据](../06-schedule/schedule-journey-draft-kept/README.md) |
| edit | `/schedule` | Modify → persisted fields | [状态证据](../06-schedule/schedule-journey-edit/README.md) |
| edited | `/schedule` | Save modification → updated agenda | [状态证据](../06-schedule/schedule-journey-edited/README.md) |
| empty | `/schedule` | More → Schedule bottom tab | [状态证据](../06-schedule/schedule-journey-empty/README.md) |
| invalid | `/schedule` | Save HTTP 422 → editable draft and validation feedback | [状态证据](../06-schedule/schedule-journey-invalid/README.md) |
| loading | `/schedule` | Schedule tab → first read pending | [状态证据](../06-schedule/schedule-journey-loading/README.md) |
| multiple-services | `/schedule` | Schedule tab → two service periods and completed consultation | [状态证据](../06-schedule/schedule-journey-multiple-services/README.md) |
| next-month | `/schedule` | Next month → October calendar | [状态证据](../06-schedule/schedule-journey-next-month/README.md) |
| personal-menu | `/schedule` | Personal event more options | [状态证据](../06-schedule/schedule-journey-personal-menu/README.md) |
| plan-expanded | `/schedule` | Expand current care plan → full summary and progress | [状态证据](../06-schedule/schedule-journey-plan-expanded/README.md) |
| plan-route | `/services/episodes/service-episode` | View care plan → actual episode route | [状态证据](../06-schedule/schedule-journey-plan-route/README.md) |
| previous-month | `/schedule` | Previous month → September first day | [状态证据](../06-schedule/schedule-journey-previous-month/README.md) |
| read-error | `/schedule` | First read fails → retry view | [状态证据](../06-schedule/schedule-journey-read-error/README.md) |
| read-recovered | `/schedule` | Retry → empty calendar | [状态证据](../06-schedule/schedule-journey-read-recovered/README.md) |
| refresh-error | `/schedule` | Next month read fails with cached page retained | [状态证据](../06-schedule/schedule-journey-refresh-error/README.md) |
| refresh-recovered | `/schedule` | Retry → requested month loaded | [状态证据](../06-schedule/schedule-journey-refresh-recovered/README.md) |
| save-pending | `/schedule` | Retry same idempotency key → request pending | [状态证据](../06-schedule/schedule-journey-save-pending/README.md) |
| save-recovered | `/schedule` | Retry response → one persisted event | [状态证据](../06-schedule/schedule-journey-save-recovered/README.md) |
| save-uncertain | `/schedule` | Save HTTP 503 → uncertain result and locked fields | [状态证据](../06-schedule/schedule-journey-save-uncertain/README.md) |
| service-filter-menu | `/schedule` | Service period selector → all and individual plans | [状态证据](../06-schedule/schedule-journey-service-filter-menu/README.md) |
| service-filter-reset | `/schedule` | All services → restore both date periods | [状态证据](../06-schedule/schedule-journey-service-filter-reset/README.md) |
| service-filter-selected | `/schedule` | Choose second service → only its dates highlighted | [状态证据](../06-schedule/schedule-journey-service-filter-selected/README.md) |
| task-completed | `/schedule` | Checkbox → completed task and progress count | [状态证据](../06-schedule/schedule-journey-task-completed/README.md) |
| task-error | `/schedule` | Status write fails → refresh reconciliation message | [状态证据](../06-schedule/schedule-journey-task-error/README.md) |
| task-in-progress | `/schedule` | Mark in progress → refreshed task badge | [状态证据](../06-schedule/schedule-journey-task-in-progress/README.md) |
| task-menu | `/schedule` | Task more options → statuses and service link | [状态证据](../06-schedule/schedule-journey-task-menu/README.md) |
| task-pending | `/schedule` | Restore pending → checkbox enabled | [状态证据](../06-schedule/schedule-journey-task-pending/README.md) |
| task-plan-route | `/services/episodes/service-episode` | Task menu view service plan → actual episode route | [状态证据](../06-schedule/schedule-journey-task-plan-route/README.md) |
| task-reconciled | `/schedule` | Refresh → server pending state restored | [状态证据](../06-schedule/schedule-journey-task-reconciled/README.md) |
| task-skipped | `/schedule` | Skip → disabled completion checkbox | [状态证据](../06-schedule/schedule-journey-task-skipped/README.md) |
| time-cancelled | `/schedule` | Cancel time input → original time retained | [状态证据](../06-schedule/schedule-journey-time-cancelled/README.md) |
| time-input | `/schedule` | Clock → keyboard time input | [状态证据](../06-schedule/schedule-journey-time-input/README.md) |
| time-picker | `/schedule` | Start time field → clock dialog | [状态证据](../06-schedule/schedule-journey-time-picker/README.md) |
| uncertain-discard | `/schedule` | Close uncertain save → reconciliation warning | [状态证据](../06-schedule/schedule-journey-uncertain-discard/README.md) |
| validation-recovered | `/schedule` | Retry accepted → agenda | [状态证据](../06-schedule/schedule-journey-validation-recovered/README.md) |
