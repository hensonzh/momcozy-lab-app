# 咨询入口加载与错误

独立咨询页和妈妈页预约弹窗现已共用加载与错误状态。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=211-1108) 完成并检查 [10 个画板](figma-nodes.json)，再修改 Flutter。来源为 [6 个已有截图条目](source-inventory.json)：两种入口各自的首次加载、载入失败与重试恢复；恢复后的咨询准备继续使用已完成设计。

独立入口采用同一视频咨询导航栏。加载卡明确正在读取咨询信息，并说明载入后的下一步；错误复用 ProductErrorView 的妈妈页样式与原错误文案。弹窗沿用 MomSettingsFlowDialog，标题和关闭操作固定，正文可滚动。妈妈页弹窗重试时现在显示加载状态，原失败提示在请求结束后按结果更新，避免重试过程中继续显示旧错误。

没有修改请求、自动轮询、媒体连接、权限或路由。控制器读取成功后仍进入原咨询准备；加载期间关闭仍执行原 leave，晚到结果由原 generation/dispose 保护忽略。数据未返回时沿用原先无法判定专家身份的通用入口；已经载入的专家界面没有变化。

验证结果：

- [入口专项](design-tests.log) 16 项通过，覆盖两个入口、320/390/430 宽度、1×/2× 字号、320×568 短屏、失败重试与恢复，以及关闭后迟到的响应。读取和恢复均未自动加入房间。
- [联测](joint-tests.log) 86 项通过，涵盖入口、咨询控制器、咨询准备、房间、咨询结果、用户视频与共用错误组件。[静态分析](analyze.log) 两个文件无问题。
- [行为对比](behavior-checks.json) 确认控制器、返回与离开确认、生命周期轮询、咨询准备与取消、已载入房间和专家内容、系统返回规则保持不变。
- 视觉检查 [Figma 妈妈页加载](figma/home-loading.png)、[短屏弹窗错误](figma/short-modal-error.png)，以及 [Flutter 独立加载](verified/room-entry-page-loading-390.png)、[弹窗错误](verified/room-entry-modal-error-390.png)、[短屏大字号加载](verified/room-entry-modal-loading-320-2x-short.png) 和 [短屏离线](verified/room-entry-page-offline-320-2x-short.png)。控件测试隔离背景以验证弹窗本身；完整妈妈页背景沿用既有设计。

[源图指纹](source-image-hashes.json) 与 [实现指纹](implementation-hashes.json) 已保存。没有修改 Session A 的截图清单，没有运行清单生成测试，未构建或发布 App，也未重新采集原生设备画面。当前观察到 2675 个截图状态，无新增变化。

整体任务保持 active。完整行动计划及其他未处理页面仍需按各自截图继续设计，不能据本轮结果视为全 App 已完成。
