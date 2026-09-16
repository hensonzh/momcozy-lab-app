# 通知跳转会话复核

清单的通知会话目的截图仍是旧 Expando 字符串 key 崩溃画面。此前 [目的页面复核](../20260914-destination-review/REVIEW.md) 已修复该问题，本轮进一步用真实 App 路由、通知协调器和隔离 HTTP 数据验证目标聊天页的当前视觉，不重跑或覆盖 Session A 的截图。

复用聊天主体已完成的 [普通画板](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=246-1144) 与 [大字号画板](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=247-1150)，本轮重新读取了它们的布局尺寸和文本。历史消息采用已完成 AI 消息卡，既有运行空闲问候沿用问候卡；顶部控件、输入区、快捷操作及回到最新消息按钮沿用此前实现。

扩展原 notification_conversation_route_test 为 393×844 / 1× 与 320×844 / 2× 两组，保存并目视检查 [普通截图](verified/notification-conversation-393-1x.png) 和 [大字号截图](verified/notification-conversation-320-2x.png)。长会话标识来自固定测试数据。大字号历史位于可滚动区域，测试先滚动到该消息再验证与截图，底部输入和导航保持可达。预加载现有头像资产，避免测试截图只显示图片加载占位。

- [2 项路由及截图测试通过](design-tests.log)。保留通知已读、目标历史读取、两会话草稿隔离、往返恢复及新登录 runtime 不继承旧草稿的原有断言。
- 关闭更新基线后，[13 项路由、聊天恢复与 runtime 联测通过](joint-tests.log)。
- [修改的测试文件静态分析通过](analyze.log)。生产代码本轮未修改。

此次关闭原通知目的状态的待核对项；源截图仍保留原崩溃事实，当前修复结果由独立设计测试证明。源图、当前实现指纹和 Figma 对应节点均已保存。

收尾新增 8 个认证短屏状态、更新 30 个认证状态及 1 个返回 More 状态，见 [新清单记录](new-inventory.json)，共 39 个增量已入待核对队列。已观察清单共 2719 个状态，数量不代表页面数或全 App 完成度。继续处理截图支持的聊天附件、菜单、语音提示、复杂 Markdown、表单与结果卡片，同时核对认证增量。goal 保持 active，未构建或发布。
