# Cozymate 首页、失败与对话复核

2026-09-12。覆盖 `agent/home`、`agent/12-agent-error`、`agent/12b-agent-conversation` 的用户 App UI/UX。源码依据重新核对的 `UserApp.tsx` AgentPage、`styles.css` 的 `.agent-run-fallback` / `.agent-run-detail` 与 `me-agent.css` 的气泡、页头及输入框规则。原稿截图为 `agent/home-viewport.png`、`agent/reference/12-agent-error.png` 和 `agent/reference/12b-agent-conversation.png`。

## 差异与修改

- 无内容的失败此前被画成普通回复气泡，使用冗长旧提示；现为独立的“这次没有拿到回复。”，14 字号、1.45 行高和错误色，保留屏幕阅读器 live region。
- 已收到的正文不因连接失败整体变红，仍采用 16 / 1.65 和 Agent 正文色。失败说明独立显示，12 / 1.4、图标18、距正文9。
- 重试采用浅玫瑰辅助按钮，触控至少44；补齐 DM Sans / 中文回退，避免按钮中文字形缺失。
- 失败恢复刚发送的可见问题，用户可以编辑后继续；只在输入框为空时恢复，不覆盖已经输入的新草稿。点击重试清除与原问题一致的恢复文本，保留不同的新草稿。后台隐藏请求不会写入输入框。

## 交互与协议边界

完整流使用真实 AgentHubPage、AgentStreamRunner、事件解析和底部导航，事件源为可控的本地 StreamClient：

1. 带 Mia 档案的首次问候不发起 Agent 请求。
2. 首次网络失败显示说明并恢复问题；重试保留同一幂等标识，尚无执行 ID 时不伪造 ID。
3. 流式正文、完成事件和正常回复按设计显示。
4. `run.failed` 终止态不恢复已终止执行；问题回到输入框，用户可提交新一轮。本项保留原生契约 `canRetry == disconnected`，没有把设计 Demo 的通用重试按钮接成可能重复动作的服务调用。
5. 部分回复断线保留正文及用户新草稿；重试携带原执行 ID 与 `afterSequence: 2`，收到完成事件后显示完整内容。

设计图中原始网络错误字符串已替换为用户可读说明。历史按钮仍依赖后端能力；启用态的独立历史流程已在 `evidence/agent-history` 验证，未强行打开本地 capability。问候继续按真实档案是否完整选择文案；测试档案不会写入普通账号。

## 验证证据

- `before.log`、`draft-before.log` 分别记录失败提示结构和丢失草稿的修改前断言。
- `regression.log`：593 项 Agent、流协议、媒体和共享组件回归通过，包括隐藏请求失败后输入框仍为空。
- `component-final.log`：最终六种宽度/字号组合通过；42 张首页、断线空回复、流式、成功回复、终止失败、部分回复断线及恢复金图正常匹配。
- `menu-golden-update.log`：新样式影响了六张重试菜单背景图，已目视核对；其余已有基线哈希未变。菜单复制/重试行为仍由回归覆盖。
- `analyze.log`：五个实现及测试文件静态检查通过。
- `native.log`：Android 1x/2x 的七状态流程通过，14 张实际截图归档。已目视核对空回复错误、正常回复和双倍字号的部分回复/新草稿，操作保持可达。
- `native-input-initial.log`：最初 Native 在输入框重新取得焦点前写入草稿，断线前没有确认写入值，导致断言失败。测试改为点击、等待焦点稳定、写入并断言后才触发断线；最终 Native 通过。没有为该测试增加产品延迟或降低保留草稿断言。

本次证明 UI 和原生客户端协议边界，未向远端模型发送测试问题，不代表云模型、TTS、历史服务已完成联调。既有记录中的模型鉴权失败仍是单独的服务问题；本轮没有修改凭据或服务开关。保留这些限制不妨碍用可控真实协议事件验证成功与失败 UI，但不能将本报告表述为远端模型成功调用。

清单这三项 UI/UX 状态完成后为 147 / Completed 141 / Need Review 6 / Missing Reference 0。剩余为隐私映射、咨询房间与结束态、自主管理、转介、全局样式汇总。

普通 local APK 构建及覆盖安装成功，见 `build.log`、`install.log`。冷启动后再次读取 UI，`native-restored-home.xml` 确认恢复到 Mia 的 Me 页面，截图已归档。
