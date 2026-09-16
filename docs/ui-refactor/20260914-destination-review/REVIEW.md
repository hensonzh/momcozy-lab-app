# 返回页面复核与通知会话修复

本轮核对增量队列的 [31 个状态](source-inventory.json)。其中 29 个是妈妈页入口或返回状态，1 个是通知打开咨询准备页，已由现有设计覆盖；剩余 1 个通知会话状态记录了真实崩溃。本轮修复该崩溃，会话视觉重构仍保持待处理。

## 设计复核

源图按字节指纹归为 [8 组](source-groups.json)，逐组查看全部默认长图，并抽查 320 屏宽、2× 字号原始视口。妈妈页包含无姓名、无记录、未购买、已购买、已有预约、剩余咨询次数改变和权益耗尽状态。它们沿用相同的 AI 分析、泌乳、今日状态、专家发现和我的陪伴计划模块，没有新的页面布局需要重做。

通过 Figma 工具重新读取并核对 [妈妈页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=19-2)、[已购买妈妈页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=88-111)、[咨询准备](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=178-1108) 和视频不可用分支 178:1276。保存了 [妈妈页画板](figma/mother-purchased.png) 和 [咨询准备画板](figma/preparation.png)。30 个源状态的对应关系见 [复核决策](review-decisions.json)，本轮没有重复修改稳定页面，也没有新增 Figma 画板。

## 会话路由修复

`/?conversationId=…` 原来将 `userId:conversationId` 字符串传入 AgentHubPage 的 Expando 缓存；Dart 拒绝这种键，历史请求尚未开始就渲染 ErrorWidget。新增测试先通过真实通知点击和 App 路由复现 [ArgumentError](conversation-red.log)，再修改路由组装处：使用与当前 API runtime 关联的对象键表，每个用户及会话获得稳定对象键。该表由 Expando 持有，runtime 释放后不需要永久保留所有会话键。

新的 [路由回归测试](../../../test/app/notification_conversation_route_test.dart) 验证通知已读、目标历史真实经过仓库加载、切换两个会话时草稿独立恢复、返回 More 后重入，以及新的相同用户 runtime 不继承旧草稿。未修改 Agent Hub 的请求、消息处理、历史仓库或视觉实现。当前修复不代表会话页面已完成新版设计，也不是实机推送端到端验证。

## 验证

- [首次定向测试](conversation-green.log)通过。
- 首次联测 239 项通过、1 项失败：早期咨询弹层测试仍查找旧文案“正在载入”。核对已完成的 Figma 211:1631、211:1787 和 consultation-entry 交付后，将预期更新为“正在读取咨询信息”，并重新核对短屏加载、离线错误两张测试基线。没有为此修改生产 UI。
- [最终 256 项联测](joint-tests-final.log)全部通过，覆盖通知路由与登录运行环境、会话页面及历史面板、交互状态存储、妈妈页无记录/有记录/已购买和权益状态、咨询准备和首次加载、短屏大字号错误重试。
- [6 项底部导航检查](navigation-tests.log)通过，覆盖 320/390/430 屏宽、2× 字号及五个目的地点击。
- [3 个文件静态分析](analyze-final.log)通过。目视检查了更新后的短屏加载与离线错误截图，标题、关闭和重试可见，无溢出。

当前清单仍有 2675 个截图状态，[无增量变化](inventory-delta.json)。[源文件指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json) 已保存。没有写入 Session A 的清单或运行截图整理测试，未构建、部署或发布。

增量队列从 31 项待核对变为 1 项，但其他尚未列入 progress.json 的截图页面仍需设计。下一步处理已有截图中的 Cozymate 会话及历史页面，必须先做 Figma 设计，再实现；整体 goal 保持 active。
