# 智能体对话模块 UI/UX 测试用例基线

状态：source-derived v0.1
范围：旧 Web `AgentHub` 对话模块到 Flutter `AgentHubPage` 的 UI/UX parity
用途：作为 Flutter widget test、golden test、integration test 和 agent stream eval 的验收标准。

## 基准来源

- `legacy_web/src/pages/AgentHub.tsx`
- `legacy_web/src/components/Mai/MaiInputBar.tsx`
- `legacy_web/src/components/Mai/MaiAvatar.tsx`
- `legacy_web/src/lib/agentHubVoicePlaybackRuntime.ts`
- `legacy_web/src/lib/agentVoicePlaybackCoordinator.ts`
- `legacy_web/src/pages/agentHub/AgentHubAssistantAvatarAnimation.test.ts`
- `legacy_web/src/pages/agentHub/AgentHubRichTextBlock.test.tsx`
- `legacy_web/src/components/Mai/MaiInputBar.test.tsx`
- `legacy_web/src/hooks/useAgentHubSpeechInput.test.tsx`

## 测试分层

| 层级 | 目标 | 推荐文件 |
| --- | --- | --- |
| L0 runtime unit | stream merge、thread、voice priority、action confirmation、artifact 参数、取消/重试状态机 | `flutter_app/test/core/agent_stream/*`, `flutter_app/test/features/agent_hub/*_test.dart` |
| L1 widget interaction | 输入栏、按钮、头像、消息流、错误态、路由预填、状态保持 | `flutter_app/test/features/agent_hub/agent_hub_page_test.dart` |
| L2 component golden | 关键视觉态固定截图，防止布局和动效 fallback 回退 | `flutter_app/test/features/agent_hub/agent_hub_golden_test.dart`, `agent_hub_deep_state_golden_test.dart` |
| L3 app integration | 键盘、中文 IME、粘贴图片、系统权限、真实媒体 picker、跨 tab 状态 | `flutter_app/integration_test/agent_hub_*_test.dart` |
| L4 agent eval | 多轮 thread、待确认动作、断线恢复、工具进度、资源打开 | fixture replay + stream transcript assertions |

## 判定口径

| 状态 | 判定 |
| --- | --- |
| P0 | 用户可见核心路径。缺失会造成不能发送、不能停止、上下文丢失、头像/语音错态、待确认动作绕过。 |
| P1 | 高频体验路径。缺失会造成视觉或交互明显不像旧版，但不一定阻断主流程。 |
| P2 | 边界、辅助功能和低频路径。缺失会增加回归风险，应进入 nightly 或 release gate。 |
| 已覆盖 | 当前 Flutter 已有直接断言。仍可补 golden 或集成测试增强。 |
| 需补 | 当前 Flutter 没有等价断言，后续修实现前应先补 failing test。 |
| 需增强 | 已有测试但断言粒度不足，无法覆盖旧 Web 关键细节。 |

## 目标 Flutter 测试文件

```text
flutter_app/test/features/agent_hub/agent_hub_page_test.dart
flutter_app/test/features/agent_hub/agent_hub_deep_state_golden_test.dart
flutter_app/test/features/agent_hub/agent_hub_golden_test.dart
flutter_app/test/features/agent_hub/agent_voice_playback_coordinator_test.dart
flutter_app/test/features/agent_hub/agent_voice_input_controller_test.dart
flutter_app/test/features/app_pages/component_parity/agent_component_parity_golden_test.dart
flutter_app/integration_test/agent_hub_keyboard_voice_test.dart
```

## A. 页面骨架与滚动

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-SHELL-01 | P0 | 顶部语音/新会话控制区固定在聊天 viewport 上方。 | `agent-auto-voice-button`、`agent-new-session-button` 可见，不随消息列表滚出。 | 已覆盖，需 golden 增强 |
| AH-SHELL-02 | P0 | 底部 composer 固定，聊天列表独立滚动。 | 长消息滚动时 `agent-composer-bar` 始终贴底，消息不被输入栏遮挡。 | 已覆盖 |
| AH-SHELL-03 | P1 | 内容不足一屏时，对话靠近底部输入栏上方，不浮在页面中部。 | idle greeting 和短对话在 bottom-aligned 区域渲染。 | 需增强 |
| AH-SHELL-04 | P1 | 内容超出一屏后保持自然向上滚动，最新消息在列表尾部。 | 发送后自动滚动到新用户消息和当前 assistant turn。 | 已覆盖 |
| AH-SHELL-05 | P1 | 用户主动回看历史时不强制抢滚，显示“回到最新消息”。 | 离底部后显示 `agent-scroll-latest-button`，点击后隐藏。 | 已覆盖 |
| AH-SHELL-06 | P2 | 顶部 fade 只做轻遮罩，不能盖住消息可读区域。 | `agent-top-fade` 存在，消息文本 rect 不与 fade 主要区域重叠。 | 需补 |

## B. 空态、新会话与历史

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-SESSION-01 | P0 | 新会话空态只显示默认问候语。 | 首屏只出现 greeting，不出现失败卡、旧流式占位或重复 assistant turn。 | 已覆盖 |
| AH-SESSION-02 | P0 | 新会话会取消当前流、停止语音、清空图片、清空输入、重置 thread。 | 运行中点击新会话不可用；非运行态点击后 draft、attachment、history、thread reset。 | 已覆盖，需增强服务端 cancel |
| AH-SESSION-03 | P1 | 新会话会关闭 photo menu。 | 打开图片菜单后新会话，菜单和 staged images 均消失。 | 已覆盖 |
| AH-SESSION-04 | P1 | 历史消息窗口支持“查看更早对话”，运行中不可加载。 | 有分页时显示入口；运行态入口 disabled 且提示回复结束后可查看。 | 需补 |
| AH-SESSION-05 | P0 | 发送 follow-up 时保留上一轮 assistant 文本、卡片和 artifact。 | 第二条用户消息发送后，前一条 assistant 回复仍在 transcript 中。 | 已覆盖或需增强 |
| AH-SESSION-06 | P0 | 同一 UI 会话内多轮使用同一 backend thread。 | 第一轮事件返回的 `threadId` 会进入第二轮 request。 | 已覆盖 |
| AH-SESSION-07 | P1 | route prefill 只消费一次。 | 计划页跳转带 `agentPrefill` 后填入一次，再次 rebuild 不重复覆盖用户输入。 | 已覆盖 |
| AH-SESSION-08 | P1 | `agentAutoSend=true` 时自动发送一次并清空 route state。 | 自动发送后不会因 rebuild 重复发同一条消息。 | 需补 |

## C. 消息流与 assistant turn

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-MSG-01 | P0 | 点击发送后立即插入用户气泡。 | pump 后无需等待 stream 事件即可看到用户文本或图片-only 文案。 | 已覆盖 |
| AH-MSG-02 | P0 | 当前 assistant turn 在收到文本前显示“我已经收到你的消息啦～”类状态文案。 | pending turn 显示专属状态，不复用默认问候语。 | 已覆盖 |
| AH-MSG-03 | P0 | 网络失败、超时、断连时，错误归属于当前 turn。 | 错误文本和重试入口出现在当前 turn，默认 greeting 不变成错误态。 | 已覆盖 |
| AH-MSG-04 | P0 | 流式 text delta 合并到当前 assistant turn。 | 多个 delta 追加为单条 assistant 回复，不卡成多条气泡。 | 已覆盖 |
| AH-MSG-05 | P0 | `message.completed` 缺文本时要能从 durable message 或最终状态补全文本。 | 没有 delta 的 completed fixture 不显示“没有返回可见内容”。 | 已覆盖或需增强 |
| AH-MSG-06 | P1 | stream render items 里 rich text、tool、artifact 保持旧 Web 排序。 | 文本先于延迟 artifact，tool started/completed 合并为同一行。 | 已覆盖，需 golden 增强 |
| AH-MSG-07 | P1 | 相邻 assistant 消息间距大于同一气泡内部段落间距。 | 连续 assistant turn 使用旧版间距，不误合并。 | 需补 golden |
| AH-MSG-08 | P1 | 用户消息右侧气泡，assistant 为带头像的透明 transcript。 | 用户和 assistant 的 max width、对齐方向、头像 gap 符合旧版。 | 已覆盖，需 golden 增强 |
| AH-MSG-09 | P2 | 长文本换行但不撑破 viewport。 | 360/390/430 宽度下无 overflow，中文和长英文均可换行。 | 已覆盖 |
| AH-MSG-10 | P1 | quick replies 在用户发送新消息后清除。 | 发送后旧 quick replies 不再可见。 | 需补 |

## D. 助手头像动效

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-AVATAR-01 | P0 | 非 active assistant turn 只显示静态 CozyMate 头像。 | idle/历史 assistant 消息没有 thinking/speaking 动效标记。 | 需补 |
| AH-AVATAR-02 | P0 | 当前 assistant run 未完成时使用 thinking/loop 动效。 | active turn 出现 `thinking` mode，动画只绑定当前 replyId。 | 需补 |
| AH-AVATAR-03 | P0 | 自动语音播报时 speaking 动效优先于 thinking。 | `autoVoicePlayingId == msg.id` 时 mode 为 `speaking`，即使 run 仍 active。 | 需补 |
| AH-AVATAR-04 | P0 | speaking 播放结束或取消后恢复静态或 thinking。 | voice handle finish/cancel 后 mode 清理，不残留 speaking。 | 需补 |
| AH-AVATAR-05 | P1 | thinking/speaking 动效有静态头像 fallback。 | 动画资源失败或禁用时仍显示 CozyMate 静态头像。 | 需补 |
| AH-AVATAR-06 | P1 | reduced motion 用户保持静态头像。 | `disableAnimations/reducedMotion` 下不渲染循环动效。 | 需补 |
| AH-AVATAR-07 | P1 | 从其他底部 tab 切回智能体首页，中心头像播放入口招手/attention 动效。 | 切到 Agent tab 后底部中心 avatar 出现一次 entry animation，再稳定。 | 需补 |
| AH-AVATAR-08 | P2 | 只有可见的当前 assistant turn 播放动效，历史不可见 turn 不抢占。 | 多条 assistant 消息中只有 active/speaking id 对应头像动。 | 需补 |

## E. Composer 输入栏布局

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-COMPOSER-01 | P0 | 单行输入时图片、文字、语音、发送按钮垂直居中。 | 三个按钮和首行文字 centerY 在误差范围内一致。 | 已覆盖 |
| AH-COMPOSER-05 | P1 | 空输入 placeholder 与按钮视觉居中。 | placeholder baseline 不偏上，不和图片按钮重叠。 | 已覆盖或需 golden |
| AH-COMPOSER-06 | P1 | 键盘弹出后 composer 避让键盘，列表 tail 仍可见。 | integration test 打开键盘后最后消息和输入栏不被遮挡。 | 需补 L3 |
| AH-COMPOSER-07 | P1 | 中文 IME composition 期间不触发发送，composition end 后可继续输入。 | 拼音候选期间 Enter 不发送，确认文字后发送按钮状态正确。 | 需补 L3 |
| AH-COMPOSER-08 | P2 | 输入框 readOnly 仅在 speechListening 时启用。 | 听写中不能手动改文字，结束后恢复可编辑。 | 需补 |

## F. 发送、停止与运行中状态

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-SEND-01 | P0 | 空输入、无图片、非运行时发送按钮置灰且点击无效。 | tap 后没有新消息、没有 request。 | 已覆盖 |
| AH-SEND-02 | P0 | 有文字时发送按钮主色可点。 | tap 后输入清空、用户气泡插入、runner 被调用。 | 已覆盖 |
| AH-SEND-03 | P0 | 只有图片也可发送，用户气泡文案为“请看这张图片”。 | staged image payload 发送，用户气泡展示图片-only 文案。 | 已覆盖 |
| AH-SEND-04 | P0 | 运行中且空输入时发送按钮变 stop/square，title 为停止回复。 | active run + empty draft 时按钮进入 stop 语义，tap 调 cancel。 | 已覆盖，需视觉增强 |
| AH-SEND-05 | P0 | stop 后保留已生成部分内容。 | 已有 delta 不被清空；无可见内容时显示停止状态。 | 已覆盖 |
| AH-SEND-06 | P1 | 短时间重复 stop 不重复 cancel。 | 连续 tap stop 只发一次 cancel request。 | 需补 |
| AH-SEND-07 | P1 | 旧 Web 允许运行中输入新内容后作为新一轮发送，并先打断当前流。 | active run + non-empty draft 时 tap send 不当作 stop，而是 interrupt + send new turn。 | 需补或产品确认 |
| AH-SEND-08 | P0 | 待确认 action 期间普通发送不可绕过确认。 | waitingForConfirmation 时 composer 不允许正常 send，confirm/reject 才推进。 | 已覆盖或需增强 |
| AH-SEND-09 | P1 | 发送会停止语音听写和当前低优先级播报。 | speechListening 或 auto-reply voice 中发送，先结束对应状态再启动请求。 | 需补 |

## G. 图片与媒体输入

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-MEDIA-01 | P0 | 图片按钮打开 photo menu，再点关闭。 | `agent-photo-menu` 出现/消失。 | 已覆盖 |
| AH-MEDIA-02 | P0 | 拍照入口触发 camera picker，上传入口触发 gallery picker。 | 两个按钮调用不同 picker callback，不发送占位 1x1 图片。 | 已覆盖或需 L3 |
| AH-MEDIA-03 | P0 | 粘贴图片会暂存附件并关闭 photo menu。 | paste image 后 staged chip 可见，menu 关闭。 | 需补 L3 |
| AH-MEDIA-04 | P0 | 附件可移除，移除后发送按钮状态随内容变化。 | remove 最后一张图片且无文字后 send disabled。 | 已覆盖 |
| AH-MEDIA-05 | P1 | staged image 有 ready/uploading/failed 三态。 | 上传中禁用发送或显示进度；失败可移除/重试。 | 需补 |
| AH-MEDIA-06 | P1 | 发送后附件从 composer 清空，但消息气泡保留缩略图。 | send 后 chip 消失，user bubble 内仍显示 sent image preview。 | 已覆盖或需增强 |

## H. 语音输入 STT

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-STT-01 | P0 | 点击麦克风切到“按住说话”模式，原文本草稿暂存。 | voice mode 出现，文本输入替换为 hold button。 | 需补 |
| AH-STT-02 | P0 | 退出语音模式且没有转写文本时恢复原草稿。 | toggle back 后旧 draft 回到输入框。 | 需补 |
| AH-STT-03 | P0 | pointer down 开始听写，pointer up submit 并把文字填入输入框，不自动发送。 | `onVoiceStart`/`onVoiceEnd(submit:true)` 调用，composer 显示 transcript，runner 未调用。 | 已覆盖部分，需补按住路径 |
| AH-STT-04 | P0 | pointer cancel/lost capture/blur 会取消听写，不填入文本。 | cancel 后 transcript 不进入 composer，状态回 idle。 | 需补 |
| AH-STT-05 | P1 | Space/Enter 键盘按住同样支持语音 hold。 | keyDown 开始，keyUp submit。 | 需补 |
| AH-STT-06 | P1 | 听写中显示 overlay 波形；有转写文本时 overlay 显示文本且限高。 | `agent-voice-overlay` 显示波形或文本，位置在 composer 上方。 | 需补 golden |
| AH-STT-07 | P0 | transcribing 时 placeholder 为“正在整理语音...”，voice button disabled。 | transcribing phase 下无法重复开始听写。 | 已覆盖或需增强 |
| AH-STT-08 | P0 | 麦克风权限拒绝有可见错误，并允许回到文字输入。 | denial message 可见，composer 未锁死。 | 已覆盖 |

## I. 语音播报 TTS 与优先级

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-TTS-01 | P0 | 自动语音只在最终 assistant 文本完成后启动。 | streaming delta 阶段不开始 playback；completed 后开始。 | 已覆盖或需增强 |
| AH-TTS-02 | P0 | 播报状态由 coordinator 统一拥有，不由单个 bubble 本地 state 控制。 | 多条消息中只有 active playback id 显示 speaking。 | 已覆盖 L0，需 widget |
| AH-TTS-03 | P0 | 优先级：manual bubble > notification > greeting > auto reply。 | 高优先级打断低优先级，低优先级被 blocked。 | 已覆盖 L0 |
| AH-TTS-04 | P0 | 通知语音播放期间，普通 auto reply 不打断；必要时等通知 idle 后重试。 | notification active 时 auto-reply 被 blocked，idle 后 pending auto voice 启动。 | 已覆盖 |
| AH-TTS-05 | P1 | 关闭自动语音会停止当前播报并清理 speaking 头像。 | tap auto voice off 后 playback cancel，avatar mode 清空。 | 需补 widget |
| AH-TTS-06 | P1 | greeting voice、manual bubble voice、notification voice 都走同一 coordinator。 | 不存在绕过 coordinator 的本地 `autoVoicePlayingId`。 | 已覆盖 legacy source，需 Flutter source/unit |
| AH-TTS-07 | P2 | 语音失败不影响文本回复完成态。 | playback failure 显示或记录错误，但 assistant 文本仍保留。 | 需补 |

## J. 工具进度、Action 与 Artifact

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-AGUI-01 | P0 | tool started/completed/error 按同一 tool_call_id 合并。 | payload `tool_call_id` 相同只显示一行，状态更新。 | 已覆盖 |
| AH-AGUI-02 | P1 | thinking note 可折叠或作为轻量说明，不挤压主文本。 | thinking 文案和主回复区分渲染。 | 需补 |
| AH-AGUI-03 | P0 | action card 等待确认时阻塞普通 send。 | confirm/reject 可见；composer 不能绕过 active run。 | 已覆盖或需增强 |
| AH-AGUI-04 | P0 | confirm/reject 后继续读取后端追加事件。 | action queued/rejected/completed 后 UI 状态刷新，不停留在“等待确认”。 | 已覆盖或需增强 |
| AH-AGUI-05 | P1 | rich text button 点击触发对应导航、预填或 action。 | button action 产生正确 route 或 callback，不丢参数。 | 已覆盖部分 |
| AH-AGUI-06 | P1 | PDF/图片/视频 artifact 点击打开 media viewer，带 kind/url/title。 | `/media-viewer` query 或 extra 完整，不落入缺资源空态。 | 已覆盖或需增强 |
| AH-AGUI-07 | P1 | IBCLC、hospital bag、milk plan、birth journey 等卡片保持旧版交互。 | 每类卡片至少有渲染、主按钮、失败兜底测试。 | 需补矩阵 |
| AH-AGUI-08 | P2 | 工具失败使用脱敏安全文案，不泄露 token、URL secret 或内部栈。 | error text 和 logs 不包含敏感字段。 | 已覆盖部分 |

## K. 取消、重试、断线与恢复

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-ERROR-01 | P0 | cancel 调后调用后端 cancel endpoint，并保留部分内容。 | cancel client 被调用，partial text 保留。 | 已覆盖 |
| AH-ERROR-02 | P0 | retry 复用上一次请求，不重复插入用户气泡。 | retry 后 user bubble count 不增加，runner request payload 等于原始请求。 | 已覆盖 |
| AH-ERROR-03 | P0 | 网络不可用显示可见错误和重试按钮。 | offline fixture 显示网络不可用，不锁 composer。 | 已覆盖 |
| AH-ERROR-04 | P1 | no-visible-response timeout 后显示可重试失败态。 | 超时未收到可见内容时转失败，不永久 loading。 | 已覆盖或需增强 |
| AH-ERROR-05 | P1 | idle timeout 后停止等待，并保留已生成内容。 | 长时间无事件后 turn 结束或断连，不清空文本。 | 已覆盖或需增强 |
| AH-ERROR-06 | P0 | 切到其他页面 dispose 时，active cached run 返回后不能卡死。 | 返回 Agent 页时 active cache 被清理为 disconnected/retry，或恢复订阅。 | 已覆盖 |
| AH-ERROR-07 | P1 | 断线重连或恢复时，最终文本来自 durable message。 | replay fixture 无 delta 时也有最终 assistant 文本。 | 需增强 |

## L. 导航、跨 Tab 状态与入口

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-NAV-01 | P0 | 底部 tab 切换不重置 Agent 草稿、附件、滚动和当前状态。 | 切到计划/宝宝再回来，draft 和 staged image 保持。 | 已覆盖 |
| AH-NAV-02 | P1 | 从计划页“对话”进入 Agent 时预填排期请求。 | route state 写入 composer，不立即清空。 | 已覆盖 |
| AH-NAV-03 | P1 | 通知、分析、设备指导类入口可追加专用消息或 prefill。 | 对应 entry intent 只消费一次，生成正确提示。 | 需补 |
| AH-NAV-04 | P1 | 专注流程如 media viewer 返回后，Agent transcript 保持。 | 打开 artifact 再返回，历史消息和 scroll 不丢。 | 需补 |

## M. 可访问性与降级

| 编号 | 优先级 | 旧 Web 行为 | Flutter 验收断言 | 覆盖 |
| --- | --- | --- | --- | --- |
| AH-A11Y-01 | P1 | 自动语音按钮有 pressed 语义。 | Semantics 中包含 toggled 状态。 | 需补 |
| AH-A11Y-02 | P1 | 语音 hold button 有“按住说话/松开填入语音输入”语义。 | Semantics label 随 phase 切换。 | 需补 |
| AH-A11Y-03 | P1 | 发送按钮 running 时有 busy/stop 语义。 | empty active run 下 label/title 为停止回复。 | 需补 |
| AH-A11Y-04 | P2 | 主要按钮 tap target 不小于移动端最小触达面积。 | image/voice/send/new session/auto voice rect 达标。 | 需补 |
| AH-A11Y-05 | P2 | reduced motion 下动效降级，功能不降级。 | 头像和入口动画关闭后仍可读、可点、可发。 | 需补 |

## N. Golden 截图矩阵

每个截图至少覆盖 `360x800`、`390x844`、`430x932` 三档移动 viewport。

| 编号 | 优先级 | 状态 | 断言目标 |
| --- | --- | --- | --- |
| AH-GOLDEN-01 | P0 | idle greeting + fixed composer | 首屏布局、输入栏、底部导航 |
| AH-GOLDEN-02 | P0 | streaming + thinking avatar | pending 文案、thinking 动效 fallback、stop 按钮 |
| AH-GOLDEN-03 | P0 | completed + speaking avatar | speaking 动效 fallback、assistant transcript |
| AH-GOLDEN-05 | P1 | photo menu + staged image | 菜单、chip、remove button |
| AH-GOLDEN-06 | P1 | voice listening overlay | 波形、overlay 位置、composer readOnly 态 |
| AH-GOLDEN-07 | P1 | action waiting confirmation | confirm/reject card、composer blocked |
| AH-GOLDEN-08 | P1 | disconnected partial response | partial text、重试、错误文案 |
| AH-GOLDEN-09 | P1 | rich text + artifact cards | card 排序、media CTA、引用链接 |
| AH-GOLDEN-10 | P2 | long transcript/history | 回到最新消息、无 overflow |

## O. Agent Stream Fixture / Eval 用例

| 编号 | 优先级 | Fixture | 断言 |
| --- | --- | --- | --- |
| AH-EVAL-01 | P0 | text delta -> completed | 单条 assistant 回复完整，auto voice 只在 completed 后启动。 |
| AH-EVAL-02 | P0 | completed without deltas | durable message 能补全文本。 |
| AH-EVAL-03 | P0 | tool started/completed with payload tool_call_id | 合并为同一 tool progress row。 |
| AH-EVAL-04 | P0 | waiting_for_confirmation -> confirm -> completed | confirm 后继续消费后续事件，run 结束。 |
| AH-EVAL-05 | P0 | user follow-up after thread id returned | 第二轮 request 携带同一 thread id，上一轮回复保留。 |
| AH-EVAL-06 | P1 | notification voice active + auto reply completed | auto reply voice 被阻塞或延后，不打断通知。 |
| AH-EVAL-07 | P1 | network disconnect after partial delta | partial text 保留，显示 retry/disconnected。 |
| AH-EVAL-08 | P1 | artifact action with media params | 打开 media viewer 时 kind/url/title 完整。 |
| AH-EVAL-09 | P2 | unsafe tool error payload | UI 和日志脱敏。 |

## 推荐推进顺序

1. 先补 P0 failing tests：`AH-AVATAR-01` 到 `AH-AVATAR-04`、`AH-SEND-04`、`AH-SEND-08`、`AH-STT-03`、`AH-TTS-01`、`AH-AGUI-04`。
2. 修实现直到 P0 widget tests 全绿。
3. 补 P0/P1 golden：streaming thinking、speaking、voice overlay、action confirmation。
4. 补 L3 integration：键盘避让、中文 IME、真实 picker、粘贴图片、语音权限。
5. 将 `AH-EVAL-*` fixtures 纳入 nightly，避免后端 transport 或 stream event 变化造成 UI 回归。

## 验证命令

聚焦 Agent Hub：

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test \
  test/features/agent_hub/agent_hub_page_test.dart \
  test/features/agent_hub/agent_hub_deep_state_golden_test.dart \
  test/features/agent_hub/agent_voice_playback_coordinator_test.dart \
  test/features/agent_hub/agent_voice_input_controller_test.dart
```

全量 Flutter 回归：

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test
```
