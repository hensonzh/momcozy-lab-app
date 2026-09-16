# Cozymate 聊天主体与输入区

本轮完成已有 [9 个源截图状态](source-inventory.json) 对应的首次问候、基础对话、生成中、空回复断线、部分回复断线、终止错误和恢复结果。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=246-1086) 设计 [19 个画板](figma-nodes.json)，再实现 Flutter。画板聚焦聊天内容区域，App 外壳的既有底部导航继续复用。

整页改用妈妈页奶油底色，浅紫渐变集中在首次问候卡。问候沿用原内容，首行以 22 字号展示，右侧保留原 36/40 肖像，正文使用 14 字号和 1.55 行高；个人资料未返回时仍显示原默认问候。后续历史消息保持普通对话形式。顶部标题左对齐，历史入口、语音开关和新建按钮保留原可用条件，大字号分行排列。

普通消息保持左右关系，用户消息采用共享玫瑰色，AI 回复采用共享表面与边框。正文统一 NotoSansSCHome、16 字号和 1.65 行高。大字号 AI 肖像与身份行移至正文上方，用户消息也可使用更宽区域。`_AgentAssistantTurn` 统一历史消息与当前回复的排列；首次问候复用 MomSettingsCard。

输入区保持原来的紧凑和展开模式、44 触控区、附件入口及发送/停止条件。本轮发现换行测量未计入系统字号，且空输入按空格而非提示文字计算，导致 2× 字号提示挤在按钮之间。现在使用真实提示文案和系统字号测量，长内容与大字号提示在按钮上方完整换行；原多行输入和草稿内容不变。快捷操作与回到最新消息按钮也采用共享字体、玫瑰色和圆角，原动作及出现条件保持。

验证：

- [25 项视觉与输入检查通过](visual-tests.log)，覆盖 320/390/430 屏宽、1×/2× 字号、键盘出现，以及基础 Markdown、历史面板和已有嵌入表单行为。保存本轮对应的 48 张聊天截图；其中非聊天组件的测试通过不代表其视觉重构已完成。
- 新增大字号空提示、中英文长草稿的布局回归：附件和发送控件必须位于正文下方，触控区至少 44，草稿内容保持不变。
- [最终 224 项联测全部通过](joint-tests-final.log)，覆盖消息页面、运行状态、历史切换、语音播放、媒体预览和通知会话路由。[3 个文件静态分析通过](analyze-final.log)。
- 恢复场景验证原 idempotency key、run ID、afterSequence、已收到回复、未发送草稿，以及终止错误不显示内部错误内容。
- [8 项行为对比通过](behavior-checks.json)：页面状态/生命周期/动作方法、分阶段回复文案、请求辅助函数、历史模型与 Sliver、回复状态优先级、Markdown 与引用解析、肖像语音动画、运行辅助函数保持不变。

已目视检查 Figma [问候](figma/home.png)、[大字号问候](figma/large-home.png)、[大字号部分回复重试](figma/large-partial.png)，以及 Flutter [问候](verified/agent-conversation-home-390-1x.png)、[默认问候](verified/agent-home-320.png)、[基础 Markdown](verified/agent-chat-390.png)、[大字号对话](verified/agent-conversation-reply-320-2x.png)、[空回复重试](verified/agent-conversation-disconnected-empty-390-1x.png)、[大字号部分回复](verified/agent-conversation-disconnected-partial-320-2x.png)。长内容可滚动，恢复截图保留测试实际定位到的最新回复或重试位置。

没有更改 API、消息运行协议或语音执行逻辑，没有运行清单生成测试、写入 Session A 的截图，也没有构建或发布。[源图指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json)已保存。

本轮开始清单为 2685 个状态；收尾的[检查](inventory-delta.json)发现新增 26 个、更新 16 个咨询相关状态，当前共 2711 个。这些增量已加入[待核对记录](new-inventory.json)，不会直接继承已完成设计的覆盖结论。

下一步继续附件菜单、语音提示、复杂 Markdown、表单与结果卡片，以及待核对的咨询增量和通知会话目的状态。本轮不把整个 Cozymate 或整个 App 标记为完成，goal 保持 active。
