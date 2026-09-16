# Cozymate 会话历史

本轮完成已有 [9 个源截图状态](source-inventory.json) 对应的会话历史抽屉。先在 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=242-1091) 建立 16 个状态画板和 `MomCozy/ConversationRow` 组件，再实现 Flutter。聊天首页、正文、输入区和消息卡片仍待各自设计，本轮不把整个 `/` 页面标记为完成。

面板保持左侧抽屉，宽度最多 360，窄屏保留至少 24 的外侧关闭区域。固定标题和关闭按钮，下方状态提示与列表共用滚动区。背景、表面、字体、间距和圆角复用妈妈页 Design Tokens；加载、错误和空列表复用 MomSettingsCard，按钮采用局部 momSettingsTheme。

会话条目将标题放在整卡宽度，日期与“✓ 当前会话”标识在下方，当前卡使用薄荷色。普通字号标题最多两行；大字号取消行数限制，长内容可以滚动读完。切换中在目标条目内显示进度及“正在打开…”，其他条目禁用但保持可读。回复锁定和切换失败提示随列表滚动，避免短屏下固定提示挤占所有空间。

[画板记录](figma-nodes.json)包括列表、末尾、锁定、切换中、切换失败、加载、加载失败、空列表，以及 320×568、2× 字号的各状态和单条中文长标题。已目视核对 [普通列表](figma/list.png)、[短屏大字号列表](figma/large-list.png)、[短屏加载错误](figma/large-load-error.png)，以及 Flutter 对应 [列表](verified/agent-history-list-320-2x.png)、[切换错误](verified/agent-history-switch-error-320-2x.png)、[加载错误](verified/agent-history-load-error-320-2x.png)。部分截图保留实际滚动位置。

验证结果：

- 首轮 15 项设计与行为检查通过；现有设计测试覆盖 320/390/430 屏宽、1×/2× 字号，生成 48 张状态基线。
- 新增短屏大字号、超长会话标题场景：滚动到下一会话、重复点击只提交一次、等待期间固定关闭可用、迟到的成功结果不触发二次关闭。
- [174 项联测全部通过](joint-tests.log)：历史设计与切换、会话页面、历史接口和真实通知路由组装测试。[2 个文件静态分析通过](analyze.log)。
- [5 项行为对比通过](behavior-checks.json)：列表读取与选择方法、日期格式保持不变；除面板宽度外，路由、动画、遮罩和只关闭一次的逻辑保持；选择禁用条件及左滑关闭阈值保持。

没有修改会话请求、历史数据含义、列表读取数量、语音或消息运行逻辑；沿用原有历史入口能力开关和仓库条件，没有打开默认关闭的功能。没有执行清单生成测试，没有写入 Session A 的源截图，未构建或发布。本轮开始时清单为 2675 个状态；收尾的[清单检查](inventory-delta.json)发现[新增 10 个咨询结果相关状态](new-inventory.json)，当前为 2685 个，已加入待核对队列，未直接标记覆盖；[源图指纹](source-image-hashes.json) 和 [实现指纹](implementation-hashes.json)已保存。

下一步继续 Cozymate 聊天主体、输入区和恢复状态的 Figma 设计。整体 goal 保持 active，增量队列中的通知会话目的状态也仍待视觉复核。
