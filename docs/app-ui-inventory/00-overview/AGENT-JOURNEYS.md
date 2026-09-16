# Cozymate 正常入口、回复与系统选择器补验

新增 **40 个正常路由状态、44 个尺寸/字号变体、4 张主长图（8 个长图变体）**，另有 **20 张当前 Android 安装版窗口截图**。9 条实际交互测试通过；本轮仅补测试、隔离传输及证据，没有修改生产页面。

## 已执行路径

- More → Cozymate：个性化问候、播报开关、附件菜单、草稿输入、新建会话清空草稿、长按新建 Tooltip。
- 输入并发送 → 首事件等待 → SSE delta → 最终 Markdown；回复期间新建按钮禁用。长按用户/助手消息 → 复制菜单 → 剪贴板与 Snackbar；复制失败 → 再次复制成功。
- More → 返回 Cozymate：当前对话保持；新建会话后才清空当前对话。
- 可重试的传输错误 → 默认三次自动重连 → 空回复重试提示；手动重试保留幂等键。部分回复断线后保留下一条草稿，从消息菜单重试继续使用 runId 与 sequence 游标，最终收到完整回复。
- 停止 → HTTP 确认等待 → 已停止或“本地已停止，服务端取消未确认”；首个 runId 到达前停止不调用缺少 runId 的取消接口，随后可发送新问题。
- 终态 run.failed：保留安全的错误反馈与输入，不显示测试中的内部错误详情；资料加载失败仍可使用通用问候。
- 393/1x 与 320/2x：长 Markdown、手动追问、第二条回复完成、重开新会话。正文和底部输入区完整滚动采集。
- Android 实际 App：照片/PDF 选择器、照片 Collections、首次相机授权、取消后的反馈、消息菜单及返回。原消息、未发送草稿与相机权限保持，最终恢复原妈妈页。见[原生步骤](../native/agent/README.md)。

## 运行边界与未开放入口

测试通过正式 `MomCozyFlutterApp/createMomCozyRouter` 的公共 `agentHubBuilder` 注入 `AgentHubPage`，仍使用正式 SSE parser、AgentStreamRunner 默认重试策略、取消 HTTP client、会话请求构造器、资料 Repository、页面和底部导航。隔离的是 SSE 字节流、取消 HTTP、JSON 数据、语音播放器和平台剪贴板；不产生远程模型请求或真实健康记录。生产 runner 在默认页面工厂中直接构造，因此本轮没有将测试称为真实后端端到端联调。

原生 20 张截图来自当前已安装 1.0.0+57 local APK，本轮没有重新构建；与当前源码测试分别记录。原生 XML 和截图顺序采集，不是同一瞬间：`reopened` XML 仍为加载态，而随后 PNG 已显示首页，不能把该 PNG 标为 Loading 证据。

- 默认 local 构建未开启会话历史：运行断言历史按钮不存在。历史组件已有预览图，但不是默认入口证明；指定 conversationId 路由和开启开关后的链路仍需另验。入口审计已标明条件。
- `AgentQuickRepliesBar` 代码存在，但实际 AgentHubPage 暂时传入 `onQuickReplySelected: null`。发送有效三项 quick_replies 后，运行断言仍无快捷回复按钮。没有制造一个可点击的假入口；长对话后续通过实际输入发送完成。
- 本轮未注入或验证 action confirmation、表单提交、artifact 导航、支持工单、附件上传/删除及语音播放全流程；已有组件截图不能替代这些正常入口链。

## 运行中发现的问题

1. **消息菜单系统返回异常**：当前源码的完整路由测试中，`handlePopRoute` 抛出 GoRouter `_findCurrentNavigators` 的 TypeError，返回 false，菜单留在原位。测试明确断言这一异常，并继续点击外部关闭菜单；没有忽略其它异常。当前安装版按返回实际显示 Android 桌面；重开后原会话/草稿恢复。未捕获到对应原生 Dart 异常，不能仅凭两者一致的操作断定退出根因相同。
2. **取消相机授权的反馈不准确**：原生首次权限弹窗按返回取消，App 显示“图片上传失败，请重试。”，没有拍照或上传。CAMERA 的授权值与 flags 前后完全一致。
3. 320/2x 下长单词、导航标签与输入提示明显换行；正文没有缺段，控件可操作。本轮保留当前产品布局用于后续设计复核。
4. 长图中的固定背景渐变会在拼接处产生色块接缝，正文、气泡顺序及唯一页头/底栏仍完整。接缝是分屏拼接的表现，不把它当作原页面静态设计，也不宣称这批图已做到无接缝的视觉还原。

## 逐状态入口

每条 README 包含真实路由、触发动作、前驱、原窗口、长图、测试来源及测量数据。

| 状态 | 路由 | 实际操作 | 证据 |
| --- | --- | --- | --- |
| after-early-stop | `/` | Send again after early stop → completed response | [状态](../05-agent/agent-journey-after-early-stop/README.md) |
| assistant-copied | `/` | Copy answer → raw Markdown retained in clipboard | [状态](../05-agent/agent-journey-assistant-copied/README.md) |
| assistant-menu | `/` | Long press final answer → message menu | [状态](../05-agent/agent-journey-assistant-menu/README.md) |
| attachment-menu | `/` | Composer add → supported attachment sources | [状态](../05-agent/agent-journey-attachment-menu/README.md) |
| cancel-finished | `/` | Cancellation status 200 → local result | [状态](../05-agent/agent-journey-cancel-finished/README.md) |
| cancel-new | `/` | New conversation after local stop → greeting | [状态](../05-agent/agent-journey-cancel-new/README.md) |
| cancel-pending | `/` | Stop response → cancellation HTTP pending | [状态](../05-agent/agent-journey-cancel-pending/README.md) |
| cancel-unconfirmed-finished | `/` | Cancellation status 503 → local result | [状态](../05-agent/agent-journey-cancel-unconfirmed-finished/README.md) |
| cancel-unconfirmed-new | `/` | New conversation after local stop → greeting | [状态](../05-agent/agent-journey-cancel-unconfirmed-new/README.md) |
| cancel-unconfirmed-pending | `/` | Stop response → cancellation HTTP pending | [状态](../05-agent/agent-journey-cancel-unconfirmed-pending/README.md) |
| copy-failed | `/` | Copy with unavailable platform clipboard → failure snackbar | [状态](../05-agent/agent-journey-copy-failed/README.md) |
| copy-recovered | `/` | Reopen message menu and copy → success snackbar | [状态](../05-agent/agent-journey-copy-recovered/README.md) |
| disconnected-empty | `/` | Connection fails through three automatic retries → retry UI | [状态](../05-agent/agent-journey-disconnected-empty/README.md) |
| disconnected-partial | `/` | Retry exhaustion after delta → partial answer and next draft retained | [状态](../05-agent/agent-journey-disconnected-partial/README.md) |
| draft | `/` | Enter unsent composer draft | [状态](../05-agent/agent-journey-draft/README.md) |
| draft-reset | `/` | New conversation → unsent draft cleared without prompt | [状态](../05-agent/agent-journey-draft-reset/README.md) |
| home | `/` | More → Cozymate; default history entry disabled | [状态](../05-agent/agent-journey-home/README.md) |
| long-followup-completed | `/` | Second response completes → two exchanges retained | [状态](../05-agent/agent-journey-long-followup-completed/README.md) |
| long-followup-sent | `/` | Type and send a follow-up → second message in the same conversation | [状态](../05-agent/agent-journey-long-followup-sent/README.md) |
| long-reply | `/` | Receive long Markdown and quick-reply payload; current page omits quick-reply controls | [状态](../05-agent/agent-journey-long-reply/README.md) |
| long-reset | `/` | New conversation after long exchange → fresh greeting | [状态](../05-agent/agent-journey-long-reset/README.md) |
| manual-retry | `/` | Manual retry → same idempotency key | [状态](../05-agent/agent-journey-manual-retry/README.md) |
| menu-dismissed | `/` | Tap outside message menu → same conversation | [状态](../05-agent/agent-journey-menu-dismissed/README.md) |
| menu-system-back-failed | `/` | System back → GoRouter null NavigatorState error; message menu remains | [状态](../05-agent/agent-journey-menu-system-back-failed/README.md) |
| new-conversation | `/` | New conversation → exchange cleared and greeting restored | [状态](../05-agent/agent-journey-new-conversation/README.md) |
| new-tooltip | `/` | Long press new conversation → tooltip | [状态](../05-agent/agent-journey-new-tooltip/README.md) |
| partial-menu | `/` | Long press disconnected answer → copy and retry menu | [状态](../05-agent/agent-journey-partial-menu/README.md) |
| profile-fallback | `/` | Profile request fails → usable generic greeting and composer | [状态](../05-agent/agent-journey-profile-fallback/README.md) |
| reply | `/` | SSE completion → final Markdown response | [状态](../05-agent/agent-journey-reply/README.md) |
| resumed | `/` | Retry from message menu → resume cursor and final answer | [状态](../05-agent/agent-journey-resumed/README.md) |
| sent-waiting | `/` | Send message → waiting for first SSE event | [状态](../05-agent/agent-journey-sent-waiting/README.md) |
| stop-before-run-id | `/` | Stop before server run identifier → local stop | [状态](../05-agent/agent-journey-stop-before-run-id/README.md) |
| streaming | `/` | Receive SSE delta → live response | [状态](../05-agent/agent-journey-streaming/README.md) |
| tab-more | `/more` | More tab → agent remains mounted offstage | [状态](../05-agent/agent-journey-tab-more/README.md) |
| tab-return | `/` | Return to Cozymate → existing exchange retained | [状态](../05-agent/agent-journey-tab-return/README.md) |
| terminal-error | `/` | Terminal run failure → safe feedback and editable input | [状态](../05-agent/agent-journey-terminal-error/README.md) |
| user-copied | `/` | Copy → clipboard and snackbar | [状态](../05-agent/agent-journey-user-copied/README.md) |
| user-menu | `/` | Long press submitted user message → copy menu | [状态](../05-agent/agent-journey-user-menu/README.md) |
| voice-off | `/` | Toggle automatic voice off | [状态](../05-agent/agent-journey-voice-off/README.md) |
| voice-on | `/` | Toggle automatic voice on | [状态](../05-agent/agent-journey-voice-on/README.md) |

## 验证与视觉复核

- 专项严格采集：**9 项通过、0 失败**，未使用金图容差；[最终日志](runs/20260913T125844-targeted/capture.log)。
- 当前全仓 `flutter analyze --no-pub`：**No issues found**；[日志](agent-journeys-analyze.log)。原先新测试的局部函数声明顺序问题与一处大括号 lint 已修复。
- 两个新增 Dart 文件格式检查：0 changed。
- 40 张主窗口已查看四张总览；4 张主长图已查看完整总览。320/2x 的所有 8 张窗口/长图按 900px 高切成 22 段逐段检查，避免仅以缩略图判断长文是否完整。
- [主窗口来源及哈希](agent-visual-review/overview-sources.json)、[主长图来源](agent-visual-review/long-sources.json)、[大字号分段来源](agent-visual-review/narrow-sources.json)；大字号长图分别高 4527、4412、4168、1173px。
- Android 20 张原图已查看两张总览，消息菜单、系统选择器与权限弹窗清晰可辨。记录包含图片/XML 哈希、前驱和恢复断言，独立于模块的 40 个合成数据状态。
- 全局采集器未修改，本轮只重采本模块；此前 75 文件的全量视觉采集仍是历史记录，不声称本轮重新全量运行。

## 下一步与未完成范围

继续补 Cozymate 奶量分析/恢复评估入口、artifact 到实际业务页、附件上传/移除/重试及预览、表单与 action 确认、语音/麦克风、历史开关或目标会话路由。相机权限允许/拒绝后的完整分支、真实附件选择和其他系统权限仍未覆盖。其它模块剩余分支、全部长图视觉审核及无正常入口代码的最终清单仍需完成。

当前总量 918 个条目（899 用户 App、19 工作台）、1969 个变体、542 个正常路由状态。完整性 PASS 仅证明文件、哈希、链接及滚动测量一致，不能作为“全部页面已经盘点完毕”的证明。


附件上传、移除、重试及图片查看的后续证据已补充，见 [AGENT-ATTACHMENTS.md](AGENT-ATTACHMENTS.md)。本报告中的总量与全量采集描述为当时记录。
