# 咨询准备、入会和总结的正常入口补验

从已登录 More → Me → 专家陪伴计划 → 我的服务 → 预约 → 咨询前准备进入正式 App 路由。新增 **58 个运行状态、5 张完整长图**，每项保存当前路由、实际操作和前驱截图。本轮未修改生产页面或通用采集器。

## 已执行的 8 条流程

1. 缺信息采集 → 真实采集表 → 返回；缺资料授权、未开放、测试提前进入、视频停用、超过进入时间 → 重约入口。
2. 准备 → 设备检查中 → 设备权限拒绝的 App 提示 → 重试通过 → 所在地确认 → 视频授权勾选与保存 → 等待室 → 离开确认/留在房间 → 专家开始 → 暂时离开 → 进行中预约。
3. 等待室 → 咨询开始 → 服务端完成 → 总结待发布 → 周期刷新取得已发布总结 → 查看怎么做 → 行动待完成/进行中/更新失败且结果不确定/原操作重试完成/暂时跳过 → 关闭 → 展开咨询与服务信息 → 服务进度。
4. 视频授权请求失败/重试 → 所在州菜单与选择 → 地区不支持 → 修正地区但请求失败 → 入会请求失败 → 周期轮询恢复入会 → 视频授权被撤销后断开并返回准备。
5. 咨询室加载中/读取失败/重试 → 关闭设备检测 → 重开 → 关闭未同意的视频授权 → 关闭开始确认，均未加入房间。
6. 进入等待室 → 服务端技术失败 → 不扣次数结果 → 重新预约，进入新的预约前确认。
7. 打开准备但未入会 → 服务端时间超过预约开始 10 分钟 → 未出席结果 → 返回妈妈首页。
8. 等待室 → 服务端安全升级结束 → 后续支持提示 → 总结待发布。

## 数据和设备证据边界

- 使用正式 MomCozyFlutterApp、GoRouter、Repository、JSON codec、咨询 controller、LiveKit 设备检查与原生轨道对象。HTTP、FlutterWebRTC/livekit_client 方法通道是隔离替身；咨询媒体采用产品现有 sandbox 模式。
- 没有真实远端视频、推送、支付或专家操作；没有写真实账号记录。设备拒绝截图是 App 的响应，不是 Android/iOS 原生权限弹窗。系统权限层仍待采集。
- 咨询终态按 backend 的 `room_service.end` 规则更新：预约完成；仅正常完成扣减次数；技术失败/未出席/安全升级不扣次数。开始状态同时更新预约和专家参与者。未出席不先让用户入会，并等待服务端截止时间；不是伪造不允许发生的状态组合。
- 正常咨询使用已填写信息和个案授权的隔离数据；缺信息场景显式清除。总结内容沿用仓库 fixture，不将英文测试文本视为产品默认文案。

## 检查与修正

- 最终严格截图采集 **8 项通过，0 失败**：[日志](runs/20260913T121023-targeted/capture.log)、[命令](runs/20260913T121023-targeted/capture-command.json)、[结果](runs/20260913T121023-targeted/capture-result.json)。不放宽像素容差，基准生成与实际证据采集分开执行。
- 全仓静态检查通过：[日志](consultation-journey-analyze.log)。设备替身中两条 if 大括号提示已修复；3 个新增测试文件格式通过。
- 原生设备检查的轨道释放涉及外部异步调度，使用有次数上限的等待，并断言实际设备就绪文本；不将暂时无动画当作成功。
- 总结的任务标题不是按钮，真实入口是“查看怎么做”。已修正点击并增加详情弹窗断言，删除错误判定方式并重新采集相同状态。
- 周期刷新可能清掉授权错误提示。错误场景保持下一次房间读取挂起，断言错误显示后截图，再释放并实际重试。
- 5 张窗口汇总图覆盖全部 58 状态，另查看 5 张长图汇总；单独查看信息采集全长、总结服务信息展开全长、未出席返回首页全长，底部授权/保存、服务进度、首页固定导航均完整。源路径与哈希见[窗口清单](consultation-visual-review/overview-sources.json)、[长图清单](consultation-visual-review/long-sources.json)。汇总检查不替代全仓长图逐项审核。

## 仍需继续

咨询专项：预约提醒与通知设置的正常入口链、原生系统权限、真实媒体支持的麦克风/摄像头/重连状态、准备页取消预约、全部关闭/返回/重入分支、总结读取失败/版本冲突/保存中、完整行动计划到日程的入口及反馈链。

全 App 的所有可点击入口、系统层及全体长图审核仍未完成。完整性检查 PASS 只证明现有文件与引用一致，不证明目标完成。

## 逐状态索引

| 状态 | 实际路由 | 触发 | 截图及前驱关系 |
| --- | --- | --- | --- |
| consent-revoked-in-room | `/services/appointments/service-appointment/room` | Server revokes video consent → media disconnected, preparation restored | [页面证据](../08-expert-service/consultation-journey-consent-revoked-in-room/README.md) |
| consultation-active | `/services/appointments/service-appointment/room` | Server reports expert joined and consultation started → active room | [页面证据](../08-expert-service/consultation-journey-consultation-active/README.md) |
| consultation-completed | `/services/appointments/service-appointment/room` | Server ends consultation → disconnected outcome and summary CTA | [页面证据](../08-expert-service/consultation-journey-consultation-completed/README.md) |
| device-check-dismissed | `/services/appointments/service-appointment/room` | Close passed device check → preparation, no join | [页面证据](../08-expert-service/consultation-journey-device-check-dismissed/README.md) |
| device-checking | `/services/appointments/service-appointment/room` | Device probe pending → permission check in progress | [页面证据](../08-expert-service/consultation-journey-device-checking/README.md) |
| device-denied | `/services/appointments/service-appointment/room` | Start consultation → device API denial shown in check dialog | [页面证据](../08-expert-service/consultation-journey-device-denied/README.md) |
| device-recovered | `/services/appointments/service-appointment/room` | Retry device APIs after permission recovery → ready | [页面证据](../08-expert-service/consultation-journey-device-recovered/README.md) |
| join-poll-recovered | `/services/appointments/service-appointment/room` | Actual room poll retries pending join → waiting room connected | [页面证据](../08-expert-service/consultation-journey-join-poll-recovered/README.md) |
| join-request-error | `/services/appointments/service-appointment/room` | Location passes and room prepares; join unavailable → awaiting recovery | [页面证据](../08-expert-service/consultation-journey-join-request-error/README.md) |
| leave-confirmation | `/services/appointments/service-appointment/room` | Leave waiting room → confirmation overlay | [页面证据](../08-expert-service/consultation-journey-leave-confirmation/README.md) |
| leave-retained | `/services/appointments/service-appointment/room` | Stay in room → same waiting connection retained | [页面证据](../08-expert-service/consultation-journey-leave-retained/README.md) |
| left-to-booking | `/services/episodes/service-episode/booking` | Confirm temporary leave → actual booking route; consultation not ended | [页面证据](../08-expert-service/consultation-journey-left-to-booking/README.md) |
| location-options | `/services/appointments/service-appointment/room` | Open current state selector → supported choices | [页面证据](../08-expert-service/consultation-journey-location-options/README.md) |
| location-rejected | `/services/appointments/service-appointment/room` | Confirm unsupported current location → server blocks entry | [页面证据](../08-expert-service/consultation-journey-location-rejected/README.md) |
| location-request-error | `/services/appointments/service-appointment/room` | Correct location then confirm → network failure, no room join | [页面证据](../08-expert-service/consultation-journey-location-request-error/README.md) |
| location-selected | `/services/appointments/service-appointment/room` | Choose New York → current location draft changes | [页面证据](../08-expert-service/consultation-journey-location-selected/README.md) |
| no-show-before-outcome | `/services/appointments/service-appointment/room` | Preparation opened without joining → before attendance deadline | [页面证据](../08-expert-service/consultation-journey-no-show-before-outcome/README.md) |
| no-show-home | `/me` | No-show outcome → Mom home | [页面证据](../08-expert-service/consultation-journey-no-show-home/README.md) |
| no-show-outcome | `/services/appointments/service-appointment/room` | Server passes attendance deadline without a join → no-show outcome actions | [页面证据](../08-expert-service/consultation-journey-no-show-outcome/README.md) |
| preflight-dismissed | `/services/appointments/service-appointment/room` | Close preflight → preparation, no join | [页面证据](../08-expert-service/consultation-journey-preflight-dismissed/README.md) |
| preparation-case-consent-required | `/services/appointments/service-appointment/room` | Refresh room with withdrawn case consent → sharing notice | [页面证据](../08-expert-service/consultation-journey-preparation-case-consent-required/README.md) |
| preparation-demo-early | `/services/appointments/service-appointment/room` | Server allows sandbox early join → test-mode preparation | [页面证据](../08-expert-service/consultation-journey-preparation-demo-early/README.md) |
| preparation-intake-required | `/services/appointments/service-appointment/room` | Booking consultation preparation → missing intake blocks start | [页面证据](../08-expert-service/consultation-journey-preparation-intake-required/README.md) |
| preparation-ready | `/services/appointments/service-appointment/room` | Booked active service → consultation preparation | [页面证据](../08-expert-service/consultation-journey-preparation-ready/README.md) |
| preparation-rebook | `/services/episodes/service-episode/booking` | Expired preparation rebook → actual booking route | [页面证据](../08-expert-service/consultation-journey-preparation-rebook/README.md) |
| preparation-to-intake | `/services/appointments/service-appointment/intake` | Preparation missing-information CTA → actual intake route | [页面证据](../08-expert-service/consultation-journey-preparation-to-intake/README.md) |
| preparation-too-early | `/services/appointments/service-appointment/room` | Server entry window not open → start disabled and opening time shown | [页面证据](../08-expert-service/consultation-journey-preparation-too-early/README.md) |
| preparation-video-disabled | `/services/appointments/service-appointment/room` | Video service disabled → unavailable explanation | [页面证据](../08-expert-service/consultation-journey-preparation-video-disabled/README.md) |
| preparation-window-expired | `/services/appointments/service-appointment/room` | Entry window elapsed → rebook action | [页面证据](../08-expert-service/consultation-journey-preparation-window-expired/README.md) |
| room-load-error | `/services/appointments/service-appointment/room` | Initial room request fails → retry state | [页面证据](../08-expert-service/consultation-journey-room-load-error/README.md) |
| room-load-retry | `/services/appointments/service-appointment/room` | Retry room load → preparation ready | [页面证据](../08-expert-service/consultation-journey-room-load-retry/README.md) |
| room-loading | `/services/appointments/service-appointment/room` | Booking preparation CTA → room initial request pending | [页面证据](../08-expert-service/consultation-journey-room-loading/README.md) |
| safety-before-outcome | `/services/appointments/service-appointment/room` | Passed preflight → consultation before server outcome | [页面证据](../08-expert-service/consultation-journey-safety-before-outcome/README.md) |
| safety-outcome | `/services/appointments/service-appointment/room` | Server safety_escalation → session disconnect and outcome actions | [页面证据](../08-expert-service/consultation-journey-safety-outcome/README.md) |
| safety-summary-pending | `/services/appointments/service-appointment/summary` | Safety escalation outcome → summary publication pending | [页面证据](../08-expert-service/consultation-journey-safety-summary-pending/README.md) |
| start-confirmation | `/services/appointments/service-appointment/room` | Device check success → location and missing video consent | [页面证据](../08-expert-service/consultation-journey-start-confirmation/README.md) |
| summary-consultation-started | `/services/appointments/service-appointment/room` | Expert starts consultation → active session before completion | [页面证据](../08-expert-service/consultation-journey-summary-consultation-started/README.md) |
| summary-entry-waiting-room | `/services/appointments/service-appointment/room` | Preparation and passed checks → room before expert completion | [页面证据](../08-expert-service/consultation-journey-summary-entry-waiting-room/README.md) |
| summary-pending | `/services/appointments/service-appointment/summary` | Completed room summary CTA → expert publication pending | [页面证据](../08-expert-service/consultation-journey-summary-pending/README.md) |
| summary-published | `/services/appointments/service-appointment/summary` | Periodic pending-summary refresh receives published plan | [页面证据](../08-expert-service/consultation-journey-summary-published/README.md) |
| summary-service-information | `/services/appointments/service-appointment/summary` | Expand consultation and service information → progress entry | [页面证据](../08-expert-service/consultation-journey-summary-service-information/README.md) |
| summary-task-detail | `/services/appointments/service-appointment/summary` | Published task → action detail and progress choices | [页面证据](../08-expert-service/consultation-journey-summary-task-detail/README.md) |
| summary-task-in-progress | `/services/appointments/service-appointment/summary` | Set task progress → persisted in-progress state | [页面证据](../08-expert-service/consultation-journey-summary-task-in-progress/README.md) |
| summary-task-recovered | `/services/appointments/service-appointment/summary` | Retry original progress update → completed state | [页面证据](../08-expert-service/consultation-journey-summary-task-recovered/README.md) |
| summary-task-return | `/services/appointments/service-appointment/summary` | Close task detail → updated summary | [页面证据](../08-expert-service/consultation-journey-summary-task-return/README.md) |
| summary-task-skipped | `/services/appointments/service-appointment/summary` | Change completed task to skipped → explicit progress state | [页面证据](../08-expert-service/consultation-journey-summary-task-skipped/README.md) |
| summary-task-uncertain | `/services/appointments/service-appointment/summary` | Task update unavailable → previous progress retained, retry required | [页面证据](../08-expert-service/consultation-journey-summary-task-uncertain/README.md) |
| summary-to-progress | `/services/episodes/service-episode` | Summary service progress → episode timeline | [页面证据](../08-expert-service/consultation-journey-summary-to-progress/README.md) |
| technical-before-outcome | `/services/appointments/service-appointment/room` | Passed preflight → consultation before server outcome | [页面证据](../08-expert-service/consultation-journey-technical-before-outcome/README.md) |
| technical-outcome | `/services/appointments/service-appointment/room` | Server technical_failure → session disconnect and outcome actions | [页面证据](../08-expert-service/consultation-journey-technical-outcome/README.md) |
| technical-rebook | `/services/episodes/service-episode/booking` | Technical failure → rebooking route | [页面证据](../08-expert-service/consultation-journey-technical-rebook/README.md) |
| video-consent | `/services/appointments/service-appointment/room` | Video authorization CTA → explicit episode consent dialog | [页面证据](../08-expert-service/consultation-journey-video-consent/README.md) |
| video-consent-dismissed | `/services/appointments/service-appointment/room` | Close consent without granting → preflight still requires consent | [页面证据](../08-expert-service/consultation-journey-video-consent-dismissed/README.md) |
| video-consent-error | `/services/appointments/service-appointment/room` | Submit episode video consent → request unavailable; dialog remains open | [页面证据](../08-expert-service/consultation-journey-video-consent-error/README.md) |
| video-consent-granted | `/services/appointments/service-appointment/room` | Submit video consent → actual start confirmation restored | [页面证据](../08-expert-service/consultation-journey-video-consent-granted/README.md) |
| video-consent-retry | `/services/appointments/service-appointment/room` | Retry consent → grant stored, return to preflight | [页面证据](../08-expert-service/consultation-journey-video-consent-retry/README.md) |
| video-consent-selected | `/services/appointments/service-appointment/room` | Consent checked → confirmation enabled, no grant before submit | [页面证据](../08-expert-service/consultation-journey-video-consent-selected/README.md) |
| waiting-room | `/services/appointments/service-appointment/room` | Confirm location and enter → sandbox waiting room | [页面证据](../08-expert-service/consultation-journey-waiting-room/README.md) |
