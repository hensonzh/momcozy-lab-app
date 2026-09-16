# 当前服务时间线：浏览、刷新、预约、总结和续购

正式 App 从 More → Me → 服务进度进入。使用现有 GoRouter、ServiceProgressPage、ServiceTimeline、CareOverviewController 以及正式 Repository/codec；仅会话、HTTP 和业务数据使用隔离替身。393 px / 1x 与 320 px / 2x 各运行三条完整链，未建立真实订单、预约或音视频连接。

## 已运行链路

| 操作 | 到达的页面或状态 |
| --- | --- |
| 首页服务进度 | 概览请求等待 → 503 → 重试返回无对应服务 → 缺失提示 → 返回妈妈主页 → 再进服务进度 |
| 预约记录同步 | 概览成功但预约等待 → 503 → 服务身份和购买记录保留、显示重试读取预约 → 重试成功 |
| 下拉刷新 | 现有时间线保留并显示进度 → 概览 503 时整个内容切为错误卡 → 重试恢复。预约上下文单独 503 时保留旧事件与局部重试 |
| 更早／最近记录 | 多事件默认滚动到最近；点击更早到身份与首个事件；出现最近按钮；点击最近返回尾部。普通字号为悬浮按钮，大字号为底部独立按钮 |
| 事件与动作 | 购买、已完成、已取消、已过期、已确认和进行中分别展示；held 不出现在正式时间线，取消和过期无查看动作 |
| 已完成事件 | 查看咨询总结 → 正式已发布总结正文 → 返回原时间线；总结内部操作留给当前咨询补验 |
| 已确认事件 | 查看预约 → 正式预约详情 → 关闭返回时间线；时间线的预约咨询在已有预约时进入 BookingPage 的预约详情，并非新预约前确认 |
| 进行中事件 | 刷新为进行中 → 查看预约 → 显示已开始、重新进入咨询室入口 → 关闭返回；本批未点击加入音视频 |
| 无现有预约 | active 服务 → 预约咨询 → 正式预约前确认弹窗 → 关闭 → 预约页 → 返回时间线 |
| 服务状态 | 刷新服务为 provisioning_pending、paused、completed、cancelled，分别记录标签与可用动作；前两者无预约/续购，后两者显示继续支持 |
| 续购入口 | 已结束服务 → 继续支持 → 四种方案 → 选择首项 → 真实购买资格弹窗 → 关闭 → 续购页 → 返回原时间线；未创建订单 |
| 次数及结束日期 | active 且零次数无预约/续购；active 且 endsAt 已过仍显示预约，实际点击仍进入预约前确认。回到首页时，首页卡按结束日期显示到期并禁用预约，这是当前两个入口的真实差异 |
| 返回链 | 各场景最终返回 Me，并按最新隔离数据刷新服务信息 |

状态变化通过正式请求后的界面观察，未调用控制器私有方法制造页面。隔离服务响应允许稳定复现失败与服务状态；不把这些变更描述成真实账号业务操作。

## 图像与审阅

47 个状态、94 份窗口、61 张完整长图，19 个状态以长图为主图。155 张 PNG 分为 366 个连续全宽片段；145 个唯一片段全部审阅。首轮稳定截图的 118 个新增片段形成 20 张审阅页，27 个引用此前已审阅像素；最终重新采集后，155 张图片 SHA-256 全部相同，更新映射复用了 145 个已审阅片段。

- 长图覆盖身份、全部历史事件、错误重试、预约/续购按钮以及“已显示当前服务记录”页尾；固定标题和更早按钮只展示一次。普通悬浮最近按钮与大字独立页脚分别保留实际窗口，并避免重复拼进内容。
- 窗口保留点击后的实际位置，完整内容另有长图；较长预约详情、已发布总结、续购和购买确认均完整输出。
- 审阅发现关闭预约详情会等待 endOfFrame 才 pop，最初截图落在返回动画内。本批测试增加返回后的动画等待，重新生成并严格验证稳定画面；没有修改生产代码或全局采集器。
- 首页按实际滚动访问懒加载服务区并等待数据后返回顶部再截图。该补验没有改变已采图片哈希。大字号首页已有预约卡的“查看预约”文字仍呈低对比灰色，作为当前视觉表现保留，不将其解释成已修复。

[审阅原页](progress-current-visual-review/sources.json) · [最终完整映射](progress-current-visual-review-update/sources.json) · [像素与源码审计](progress-current-evidence-audit.json) · [采集源码快照](progress-current-capture-source-snapshot.json)。最初已被替换的 3 张多余审阅页保存在 `runs/20260914T013946-targeted/superseded-review/`，不算最终审阅证据。

## 逐状态入口与图片

| 实际操作 | 图片及前驱证明 |
| --- | --- |
| Active plan → appointment action | [状态证据](../08-expert-service/progress-current-active/README.md) |
| Active plan without appointment → booking precheck | [状态证据](../08-expert-service/progress-current-active-booking/README.md) |
| Close precheck → start-confirmation page | [状态证据](../08-expert-service/progress-current-active-booking-closed/README.md) |
| Booking Back → active timeline | [状态证据](../08-expert-service/progress-current-active-booking-return/README.md) |
| Active service with zero remaining → no new booking or renewal | [状态证据](../08-expert-service/progress-current-active-exhausted/README.md) |
| Server still active after endsAt → current timeline retains booking action | [状态证据](../08-expert-service/progress-current-active-past-end/README.md) |
| Appointment Close → timeline | [状态证据](../08-expert-service/progress-current-appointment-return/README.md) |
| Appointment read 503 → service identity retained | [状态证据](../08-expert-service/progress-current-appointments-error/README.md) |
| Overview recovered, appointment context pending | [状态证据](../08-expert-service/progress-current-appointments-loading/README.md) |
| Retry appointment read → purchase-only timeline | [状态证据](../08-expert-service/progress-current-appointments-recovered/README.md) |
| Booking Back → timeline | [状态证据](../08-expert-service/progress-current-booking-return/README.md) |
| Retry returns no matching episode → missing service | [状态证据](../08-expert-service/progress-current-episode-missing/README.md) |
| More → Me before timeline request | [状态证据](../08-expert-service/progress-current-errors-home/README.md) |
| Timeline Back → Me | [状态证据](../08-expert-service/progress-current-errors-home-return/README.md) |
| Confirmed event → appointment detail | [状态证据](../08-expert-service/progress-current-event-appointment/README.md) |
| Timeline booking with confirmed appointment → existing appointment detail | [状态证据](../08-expert-service/progress-current-event-booking/README.md) |
| Refresh current consultation → in-progress event | [状态证据](../08-expert-service/progress-current-event-in-progress/README.md) |
| Completed event → published summary | [状态证据](../08-expert-service/progress-current-event-summary/README.md) |
| Earlier records → identity and first event | [状态证据](../08-expert-service/progress-current-events-earlier/README.md) |
| More → Me with existing service | [状态证据](../08-expert-service/progress-current-events-home/README.md) |
| Timeline Back → Me | [状态证据](../08-expert-service/progress-current-events-home-return/README.md) |
| Open multi-event service → latest event | [状态证据](../08-expert-service/progress-current-events-latest/README.md) |
| Back to latest → latest event and footer | [状态证据](../08-expert-service/progress-current-events-latest-return/README.md) |
| Appointment context 503 → retained old events and retry | [状态证据](../08-expert-service/progress-current-events-refresh-error/README.md) |
| Pull refresh → existing events while appointment context waits | [状态证据](../08-expert-service/progress-current-events-refresh-pending/README.md) |
| Retry → synced events and latest position | [状态证据](../08-expert-service/progress-current-events-refresh-recovered/README.md) |
| Close active consultation entry → timeline | [状态证据](../08-expert-service/progress-current-in-progress-return/README.md) |
| In-progress event → active consultation entry | [状态证据](../08-expert-service/progress-current-in-progress-room/README.md) |
| Overview 503 → retry card | [状态证据](../08-expert-service/progress-current-initial-error/README.md) |
| Service progress → overview pending | [状态证据](../08-expert-service/progress-current-initial-loading/README.md) |
| Missing service action → original Me | [状态证据](../08-expert-service/progress-current-missing-home-return/README.md) |
| Past-end active plan booking → actual target handling | [状态证据](../08-expert-service/progress-current-past-end-booking/README.md) |
| Booking Back → unchanged active timeline | [状态证据](../08-expert-service/progress-current-past-end-return/README.md) |
| Overview refresh 503 → full error surface | [状态证据](../08-expert-service/progress-current-refresh-error/README.md) |
| Pull refresh → retained timeline with progress | [状态证据](../08-expert-service/progress-current-refresh-loading/README.md) |
| Retry overview → service timeline restored | [状态证据](../08-expert-service/progress-current-refresh-recovered/README.md) |
| Ended service Continue support → renewal options | [状态证据](../08-expert-service/progress-current-renew-options/README.md) |
| Select renewal plan → real eligibility dialog | [状态证据](../08-expert-service/progress-current-renew-purchase/README.md) |
| Close eligibility → renewal options | [状态证据](../08-expert-service/progress-current-renew-purchase-closed/README.md) |
| Renewal Back → ended timeline | [状态证据](../08-expert-service/progress-current-renew-return/README.md) |
| Refresh server episode cancelled → supported state and actions | [状态证据](../08-expert-service/progress-current-state-cancelled/README.md) |
| Refresh server episode completed → supported state and actions | [状态证据](../08-expert-service/progress-current-state-completed/README.md) |
| Refresh server episode paused → supported state and actions | [状态证据](../08-expert-service/progress-current-state-paused/README.md) |
| Refresh server episode provisioning_pending → supported state and actions | [状态证据](../08-expert-service/progress-current-state-provisioning_pending/README.md) |
| More → Me with existing service | [状态证据](../08-expert-service/progress-current-states-home/README.md) |
| Timeline Back → Me | [状态证据](../08-expert-service/progress-current-states-home-return/README.md) |
| Summary Back → original timeline | [状态证据](../08-expert-service/progress-current-summary-return/README.md) |

## 验证与余项

6 项严格采集通过，不更新 Golden；全仓静态检查 No issues found，退出码 0。测试为 `test/modules/services/progress_current_inventory_test.dart`，仅新增本批采集测试与证据，没有修改产品业务代码。

- [严格采集日志](runs/20260914T014536-targeted/capture.log)
- [全仓静态检查](progress-current-analyze.log)
- [完整性检查](progress-current-final-verify.log)

当前时间线主要控件已有运行链，预约详情、信息采集、咨询和总结的内部动作仍继续按当前源码核对。`mom_appointment_widgets.dart` 已在本批真实预约详情路径观察到，不再列作未观察文件。服务续购其余方案、失败/恢复及付款后链仍与既有报告对照，不以到达入口代替内部覆盖。完整目标保持 **NOT_PROVEN**。
