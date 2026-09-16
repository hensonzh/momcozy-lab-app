# Cozymate 语音播报与页面往返补验

当前新增 **30 个正式入口状态、45 个尺寸/字号变体、5 张主长图、18 个长图变体**。7 项交互测试通过；393/1x 与 320/2x 覆盖问候失败重播、流式失败、完成后重播及开关；键盘场景使用 320/2x，增量自动恢复与持续播放跨 Tab 使用 393/1x。

## 真实入口与替换边界

通过正式 `MomCozyFlutterApp/createMomCozyRouter`，从已登录 More 点击底部 Cozymate 进入。使用公开 `agentHubBuilder` 注入真实 SSE parser/runner、profile repository 和正式语音协调器；仅将音频播放器换成可控制完成/失败的公开接口实现，服务请求和账号采用隔离传输层。实际点击开关、重播、关闭提示、新建会话和 Tab，记录每个前驱与路由。

这组截图证明 Flutter 页面及交互状态，不证明 TTS 服务可用性、扬声器音质、真实等待时延、系统音频焦点或后台播放。键盘用 `viewInsets=300` 复现布局占位，图片中的空白区域不是 Android/iOS 系统键盘截图。本轮没有安装 APK、操作原生账号或发送真实模型请求。

## 实际支持的链路

- 进入会话自动播放问候，头像呈播报态；播放器失败后显示安全提示，不展示内部错误。点击“播放回复”重播同一问候，不发起新聊天请求；完成后停止播报指示。
- 发送文字 → 等待回复 → 首段到达自动播放。播放失败且 run 未结束时，“播放回复”禁用；最终回复没有新增文字时保留错误，run 结束后允许手动重播。
- 若失败后继续收到新增文字，页面会自动创建新播放会话，**只播放新增后缀**，并清除错误提示。再次终态失败后，手动重播发送完整回复文本。
- 关闭实时语音会取消当前播放。再打开不会自动重播已经完成的回复；开关状态可跨 Tab 保留。
- **切到 More 不会取消播放**。返回 Cozymate 后仍是原会话及原播放 session，直到播放器完成；没有误标为离开页面即暂停。
- 键盘占位下关闭错误提示保留未发送草稿；新建会话清空草稿并开始新的问候；再次关播报可停止。

当前正常聊天界面没有独立暂停/继续进度、麦克风录音输入或音频加载页；顶部开关控制自动播报，错误提示提供重播。不能用播放器内部状态虚构独立产品页面。动作评估的实时语音流程另行盘点。

## 长图采集修正

旧采集器只处理高于 150px 的滚动视口，误把键盘状态下 77px/103px 的对话区记成无需长图。本次移除高度门槛，保留实际溢出、方向、前景路由和边界判断；帧上限增加到 400，仍保留 40000px 内容上限。两种短视口均完整覆盖 614px 正文，并保留底部错误提示/输入区域与导航。

半像素滚动步长会使细条拼接的文字抖动，现改为整像素步长；已查看修正后的全文。动态“回到最新消息”浮层继续按真实位置避让，原窗口保留用户当时所见，长图展示完整正文。固定背景渐变仍可能出现色带接缝，长图不作为无接缝静态设计原稿。

完整性校验新增“测得溢出却报告无溢出”的矛盾检查。通过内存注入旧错误验证该检查会失败，未修改实际元数据或覆盖正式 PASS 报告。见 [校验器负向回归](agent-voice-verifier-regression.log)。

## 验证与视觉审阅

- 最终全量采集：**79 个视觉测试文件，1003 通过，6 项既有跳过，0 失败**，61 秒。见 [日志](capture.log)、[执行命令](capture-command.json)、[结果](capture-result.json)。语音专项为其中 7 项。
- 定向采集严格比对通过：[日志](runs/20260913T133703-targeted/capture.log)。采集时未更新金图或放宽容差。
- 三个 Dart 文件静态检查无问题：[日志](agent-voice-analyze.log)；格式检查 0 changed。
- 已查看 30 个主窗口、5 张主长图及全部 320/2x 原窗口和长图的 57 个连续分段。审阅图见 [overview-1](agent-voice-visual-review/overview-1.jpg)、[overview-2](agent-voice-visual-review/overview-2.jpg)、[overview-3](agent-voice-visual-review/overview-3.jpg)、[long-1](agent-voice-visual-review/long-1.jpg) 和 `narrow-1…8.jpg`。各 `*-sources.json` 记录原图哈希和分段范围。
- 大字号下导航英文标签分行、对话区明显变短，“回到最新消息”会遮挡当前窗口的一部分文字。对应正文已在长图完整保留，不将首屏裁切误记成正文缺失。

本次全量重采更新了其它模块长图，但不自动表示它们都已重新逐图审阅；以前审阅哈希需与最新产物核对。真实系统权限、原生音频中断、后台/前台恢复、通知抢占、动作评估语音暂停及其它模块剩余交互仍待补，整体任务保持未完成。

## 逐状态入口

| 状态 | 路由 | 实际触发 | 证据 |
| --- | --- | --- | --- |
| active-audio-away | `/more` | Tap More during voice journey | [状态](../05-agent/agent-voice-journey-active-audio-away/README.md) |
| active-audio-return | `/` | Tap Cozymate → restored conversation | [状态](../05-agent/agent-voice-journey-active-audio-return/README.md) |
| completed-text-playing | `/` | Reply text completes while audio remains active | [状态](../05-agent/agent-voice-journey-completed-text-playing/README.md) |
| greeting-failed | `/` | Greeting player fails → safe notice and replay | [状态](../05-agent/agent-voice-journey-greeting-failed/README.md) |
| greeting-finished | `/` | Greeting player completes → speaking indicator ends | [状态](../05-agent/agent-voice-journey-greeting-finished/README.md) |
| greeting-finished-away | `/more` | Tap More during voice journey | [状态](../05-agent/agent-voice-journey-greeting-finished-away/README.md) |
| greeting-finished-return | `/` | Tap Cozymate → restored conversation | [状态](../05-agent/agent-voice-journey-greeting-finished-return/README.md) |
| greeting-playing | `/` | More → Cozymate automatically starts greeting playback | [状态](../05-agent/agent-voice-journey-greeting-playing/README.md) |
| greeting-replaying | `/` | Tap replay → greeting restarts without a chat request | [状态](../05-agent/agent-voice-journey-greeting-replaying/README.md) |
| keyboard-dismissed | `/` | Dismiss voice notice → draft remains and composer expands | [状态](../05-agent/agent-voice-journey-keyboard-dismissed/README.md) |
| keyboard-failed | `/` | Focus input with unsent draft → 300dp keyboard inset and voice notice | [状态](../05-agent/agent-voice-journey-keyboard-failed/README.md) |
| later-text-failed | `/` | Realtime player fails after first paragraph | [状态](../05-agent/agent-voice-journey-later-text-failed/README.md) |
| later-text-full-finished | `/` | Replayed audio completes successfully | [状态](../05-agent/agent-voice-journey-later-text-full-finished/README.md) |
| later-text-full-replay | `/` | Tap replay → both paragraphs submitted to playback | [状态](../05-agent/agent-voice-journey-later-text-full-replay/README.md) |
| later-text-recovered | `/` | Next SSE delta automatically starts a new player with only the new suffix | [状态](../05-agent/agent-voice-journey-later-text-recovered/README.md) |
| later-text-terminal-failed | `/` | Playback fails after reply finishes → replay entire reply is available | [状态](../05-agent/agent-voice-journey-later-text-terminal-failed/README.md) |
| new-greeting-off | `/` | Turn voice off during fresh greeting → stop | [状态](../05-agent/agent-voice-journey-new-greeting-off/README.md) |
| new-greeting-off-away | `/more` | Tap More during voice journey | [状态](../05-agent/agent-voice-journey-new-greeting-off-away/README.md) |
| new-greeting-off-return | `/` | Tap Cozymate → restored conversation | [状态](../05-agent/agent-voice-journey-new-greeting-off-return/README.md) |
| new-greeting-playing | `/` | New conversation clears draft and starts fresh greeting | [状态](../05-agent/agent-voice-journey-new-greeting-playing/README.md) |
| reply-audio-completed | `/` | Original audio session completes after tab return → speaking indicator stops | [状态](../05-agent/agent-voice-journey-reply-audio-completed/README.md) |
| reply-ended-failed | `/` | SSE reply completes → replay becomes available | [状态](../05-agent/agent-voice-journey-reply-ended-failed/README.md) |
| reply-off | `/` | Turn voice off → active session cancelled | [状态](../05-agent/agent-voice-journey-reply-off/README.md) |
| reply-on | `/` | Turn voice back on → no automatic restart of completed reply | [状态](../05-agent/agent-voice-journey-reply-on/README.md) |
| reply-on-away | `/more` | Tap More during voice journey | [状态](../05-agent/agent-voice-journey-reply-on-away/README.md) |
| reply-on-return | `/` | Tap Cozymate → restored conversation | [状态](../05-agent/agent-voice-journey-reply-on-return/README.md) |
| reply-replaying | `/` | Tap replay → read completed reply without regenerating | [状态](../05-agent/agent-voice-journey-reply-replaying/README.md) |
| reply-stream-failed | `/` | Player fails during reply → replay disabled until run ends | [状态](../05-agent/agent-voice-journey-reply-stream-failed/README.md) |
| reply-stream-playing | `/` | First SSE delta → realtime voice session and speaking avatar | [状态](../05-agent/agent-voice-journey-reply-stream-playing/README.md) |
| reply-waiting | `/` | Send typed message → waiting for first reply | [状态](../05-agent/agent-voice-journey-reply-waiting/README.md) |
