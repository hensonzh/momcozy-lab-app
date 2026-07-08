# Agent Hub 旧 Web 运行时对齐测试计划

## 旧 Web 核心契约

旧 Web 的 Agent Hub 行为不是完全挂在可见页面组件生命周期上，而是拆到了页面外的运行时：

- 主对话流由 `legacy_web/src/lib/agentHubMainChatRuntime.ts` 持有。
- 自动语音播放和头像视觉状态由 `legacy_web/src/lib/agentHubVoicePlaybackRuntime.ts` 持有。
- 语音优先级仲裁由 `legacy_web/src/lib/agentVoicePlaybackCoordinator.ts` 持有。
- `AgentHub.tsx` 通过 `useSyncExternalStore` 订阅这些运行时，因此页面重渲染或站内导航不等于主动取消对话流或语音播放。

Flutter App 需要保留同样的用户可感知契约：用户切换底部 tab 或进入其它站内页面时，不能静默停止正在回复的 Agent，不能丢失流式订阅，也不能丢掉正在播放的语音状态。

## 验收标准

1. 用户离开 Agent Hub 去其它底部 tab 时，主 Agent 回复继续运行。
2. Agent Hub 隐藏期间收到的流式事件，在用户返回后仍能展示。
3. 除非用户主动点击停止，或发送一条会打断当前回复的新消息，否则不能取消 stream。
4. 自动语音播放状态必须存在于临时可见页面子树之外。
5. 通知语音、手动气泡语音、自动回复语音继续遵循现有优先级规则。
6. 通知语音阻塞自动回复语音后，通知结束必须触发一次待播报自动回复重试。
7. 手动新建会话的 greeting voice 只属于问候语；用户发起真实 turn 后要立即丢弃并停止。
8. 冷启动进入 Agent Hub 必须是新会话，不从 secure/local 持久层恢复旧 transcript；站内 tab 切换使用内存 keep-alive 保留当前会话。
9. 通过路由带入的 Agent 输入预填仍然生效；`agentAutoSend/autoSend` 为 true 时只自动发送一次，同时不能生成重复的 Agent Hub 实例。
10. 隐藏的 Agent Hub 不能出现在非 Agent 页面，也不能影响底栏隐藏规则。

## Flutter 测试矩阵

| 层级 | 测试场景 | 期望结果 |
| --- | --- | --- |
| 路由 Shell widget | 启动 Agent stream，切到 `/schedule`，继续注入事件，再回到 `/` | 最终 assistant 文本可见，不出现“连接中断”兜底文案。 |
| 路由 Shell widget | Agent 完成后触发自动语音，切 tab 后再返回 | 智能体头像仍反映正在播放状态。 |
| 路由 Shell widget | 冷启动默认进入 Agent Hub | 默认路由不启用 durable transcript store，只显示 fresh greeting。 |
| 路由 Shell widget | 从状态/计划等模块带 route prefill 进入 Agent Hub | 预填文本进入输入框；带 auto-send 标记时提交一次，重复 rebuild 不重复发送。 |
| 路由 Shell widget | 切换到 `/pump` 等专注流程页面 | 隐藏 Agent Hub 不可见，底栏隐藏规则保持不变。 |
| Agent Hub 页面 | 用户在 active run 中显式停止 | 取消 stream subscription，并调用后端 cancel 路径。 |
| Agent Hub 页面 | 手动新建会话 | 自动语音开启时开始 greeting voice，关闭时只显示 greeting。 |
| Agent Hub 页面 | greeting voice 播放中发送真实消息 | greeting voice 被取消，新用户消息正常进入 run。 |
| Agent Hub 页面 | 初始 composer prefill 携带 auto-send | 首帧后发送该 prefill，composer 清空，后续 rebuild 不重复发送。 |
| Agent Hub 页面 | 通知语音阻塞自动回复语音后结束 | 自动回复语音重试，头像切换到 speaking。 |
| Agent 语音单元 | 通知语音播放时自动回复语音尝试开始 | 通知语音保持 active，自动回复被等待或拒绝。 |
| Agent 语音单元 | active playback 结束 | idle listener 收到通知，且高优先级语音接管时不误发 idle。 |
| Agent 语音单元 | 手动气泡语音打断通知语音 | 前一个语音的 cancel callback 只执行一次。 |

## 本阶段实现目标

采用由 Shell 持有的 Agent Hub keep-alive slot，让 Agent Hub 在站内导航时保持挂载。这个结构对应旧 Web 的模块级运行时模型，同时避免一次性重写完整路由架构。非 Agent 页面显示正常 route child；Agent Hub 则以 offstage 方式保留挂载，从而继续接收 stream 事件并维持语音协调器状态。

长期方向是把 Agent run reducer 和语音播放状态继续下沉为 App 级 controller，让 `AgentHubPage` 更接近纯 view/controller adapter。本阶段的 Shell keep-alive 是保护当前 UX 的最小对齐步骤。
