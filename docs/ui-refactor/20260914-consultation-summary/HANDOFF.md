# 咨询总结与行动详情

完成现有 22 个用户截图条目对应的咨询总结与行动详情。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=201-1108) 设计并检查，再更新 Flutter。[24 个画板](figma-nodes.json) 覆盖已发布、整理中、首次加载、读取失败、未完成咨询、无行动、服务信息展开，以及行动更新、原版本重试、方案替换和短屏大字号。

专家身份现在置于总结开头，复用 MomServiceExpertIdentity 并明确发布确认时间；当前行动采用妈妈页的柔和重点卡，后续行动、观察目标、额外支持与服务信息分层呈现。正文和长页面保持自然滚动。服务信息普通字号两列、大字号单列；行动详情复用 MomSettingsFlowDialog，标题固定，正文与进度选项可滚动，进度选项整格可点。

保留发布状态判定和任务优先顺序，没有改变专家建议、目标、任务内容、更新版本或跳转语义。正常更新、不确定结果重试、方案已替换后重新载入和行动已被移除等分支继续使用原控制器；不确定更新期间仍禁止竞争提交，忙碌时仍不能关闭或通过系统返回退出。

共用 ProductErrorView 增加可选 `useMomStyle`，由总结页和行动详情启用，复用 MomSettingsCard 与妈妈页文字样式。默认值为 false，旧调用方的渲染保持不变；错误文案与重试标签仍共用原映射。

验证结果：

- [总结专项](design-tests.log) **13 项通过**，包含 320/390/430 宽度、1×/2× 字号、320×568 短屏、原版本重试、忙碌返回拦截、行动移除后的关闭、刷新失败保留内容、无行动及未完成咨询的正确入口。
- [联测](joint-tests.log) **73 项通过**，涵盖总结、服务进度、预约、专业记录控制器与共用错误组件；[静态分析](analyze.log) 4 个文件无问题。
- [行为对比](behavior-checks.json) 确认发布和任务选择逻辑、控制器、生命周期轮询、跳转回调与错误组件默认渲染保持不变。比较忽略格式化及参数末尾逗号；空状态按钮从 TextButton 改为 OutlinedButton，回调不变。
- 实际检查 [Figma 完整总结](figma/published-full.png)、[Figma 行动详情](figma/task.png)、[Figma 短屏进度](figma/short-progress.png)，以及 [Flutter 总结](verified/summary-published-390.png)、[行动详情](verified/summary-task-390.png)、[短屏进度](verified/summary-short-progress-320-2x-short.png)、[短屏重试](verified/summary-short-uncertain-320-2x-short.png)。

[源条目](source-inventory.json)、[源图指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json) 已保存。没有改写 Session A 截图，没有运行截图清单生成测试，未构建或发布 App。本轮证据为控件、控制器及视觉基线验证，未重采集原生设备画面。

29 个预约恢复增量已 [复核](../20260914-booking-resume/REVIEW.md)，27 项预约测试通过，沿用现有设计。当前观察到 2675 个截图状态；完整行动计划目标页、续购和其他未处理页面仍按各自截图继续，整体任务保持 active。
