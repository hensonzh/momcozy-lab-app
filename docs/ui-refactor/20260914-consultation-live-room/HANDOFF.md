# 用户实时咨询室

已完成 18 个截图条目对应的用户咨询室与离开确认界面。先完成 Figma 状态设计，再修改 Flutter；画板见 [咨询室设计](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=188-1108) 和 [15 个画板清单](figma-nodes.json)。

新版将真实专家身份、预约时间与连接状态放在视频区上方，复用 MomServiceExpertIdentity；视频区独立呈现远端画面、等待状态与本机预览。麦克风、摄像头和离开操作采用统一的薄荷、淡紫、淡粉操作区。异常信息独立呈现，开启声音和断线恢复按钮可完整滚动到达。离开确认复用 MomSettingsFlowDialog，按内容高度展开，继续保留“留在房间”和“暂时离开”的原有含义。

设计覆盖等待、专家进入、摄像头关闭、重连、媒体错误、断线恢复、离开确认、离开失败、模拟咨询，以及双倍字号滚动与短屏。代表性 [Figma 等待室](figma/waiting.png)、[短屏离开确认](figma/short-large-leave.png) 与 [Flutter 等待室](verified/video-waiting-390.png)、[断线恢复](verified/video-disconnected-actions-320-2x.png)、[短屏操作区](verified/video-controls-320-2x-short.png)、[短屏离开确认](verified/video-leave-320-2x-short.png) 已实际查看。

验证结果：

- [专项验证](design-tests.log) 16 项通过：320/390/430 宽度、1×/2× 字号及 320×568 短屏；验证静音、摄像头、忙碌和重连禁用、开启音频、重新连接、取消离开与离开失败重试。
- [咨询流程联测](joint-tests.log) 111 项通过，覆盖咨询准备、设备检测、入室确认、控制器、首页弹窗、专家端与结束状态；[静态分析](analyze.log) 5 个文件无问题。
- [行为对比](behavior-checks.json) 确认 `_back`、`_startConsultation` 及其后流程代码、视频轨道选择和专家视频区未改变，媒体控制的 connected / sandbox / busy 条件保持原样。
- 视觉基线先查看差异后更新。room_page_test 补齐滚动完成后的等待；没有改写 Session A 截图，没有运行库存截图生成测试。

本次只标记 `room#live-room`；咨询结束页面、总结和续购仍需各自设计。本轮未运行原生双端视频通话或发布构建；真实音视频渲染路径保留，当前证据为控件与控制器测试。

增量记录：本轮新增 107 个预约预检查/选择状态，另有 6 个服务进度截图变化。已加入待处理队列并记录库存快照，当前共观察到 2646 个截图状态；数量不代表页面完成数。47 个服务进度增量已单独 [复核](../20260914-progress-current/REVIEW.md)，43 个沿用现有设计，4 个续购/总结目标保留待处理。
