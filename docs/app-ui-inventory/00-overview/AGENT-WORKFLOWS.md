# Cozymate 业务入口、表单与动作确认

本轮新增 **59 个正常路径状态、74 个尺寸/字号变体、40 张主长图（52 个长图变体）**，9 条实际交互测试通过。只新增测试、隔离传输层与盘点证据；生产页面和全局采集器未修改。

## 实际运行链路

- More → Cozymate → 奶量分析：直接发送正式预设问题。回复中的记录卡片 → 查看泌乳记录 → `/me/lactation` → 关闭 → 妈妈页 → Cozymate；另一按钮进入 `/me/diary` 的默认休息记录页，再关闭并返回 Cozymate。原回复及卡片仍在；没有提交健康记录。
- 向前滚动对话 → “回到最新消息”出现 → 实际点击 → 回到最新回复且按钮消失。与之前仅观察到按钮的证据区分。
- 产后康复评估 → 发送正式预设问题 → 收到 form artifact → 助手完成回复 → 表单入口准备中 → 正式一秒计时自动弹出。
- 空必填提交 → 验证错误；填写说明、单选、下拉、多选“其它”及补充内容，日期选择器选 2026-09-20。393/1x 显示日历；320/2x 显示日期输入模式，实际输入并确认，未强制两种尺寸使用同一布局。
- 取消 → 对话表单入口 → 再打开保留五项草稿 → 提交 → 新 SSE 请求等待服务端接受 → run.started 后关闭表单 → 回复完成 → 从历史对话中的表单入口打开只读信息 → 关闭。两个尺寸均完成。
- 信息采集提交在服务端接受前连接失败 → 默认三次重连耗尽 → 表单保留草稿并显示提交失败 → 再次提交相同幂等键 → 接受与回复完成。
- 发送售后支持请求 → 自动弹出售后表单 → 填写问题与隔离联系地址 → 正式 SupportTicketApiRepository 提交 HTTP → 503 → 草稿与错误 → 同一幂等键重试 → 工单提交成功 → 本地确认回复 → 只读查看并关闭。提交不产生额外模型请求。
- 日程删除动作卡：分别实际点击确认和拒绝，各覆盖等待、HTTP 200 成功、HTTP 503 失败；切换 More 再返回保留结果。成功采用服务端 `applied` / `rejected` 状态。

## 依赖边界

真实执行正式 App、GoRouter、AgentHubPage、SSE parser、runner、artifact mapper、form normalizer、表单组件、action HTTP client、SupportTicketApiRepository、妈妈记录 Repository 和 `dispatchAgentArtifactAction`。通过公开 `agentHubBuilder` 注入 HTTP/SSE 传输、会话/资料与语音替身。字段和响应是受当前客户端支持的协议数据，未调用真实模型或售后系统，未把 UI 状态验证称为真实后端交易。

售后表单使用通用 form 协议中的 `form.id = support_ticket`；这证明该提交分支可达，不等于已覆盖全部专用 support-ticket artifact 类型及其所有字段。动作验证使用回复已结束后仍展示的确认卡；活跃 run 等待确认、确认后自动恢复 SSE、应用事件刷新业务页仍未完成。

## 观察到的问题与证据限制

1. **动作失败没有重试入口**：确认或拒绝的 HTTP 返回 503 后状态变成“失败”，两颗按钮消失；切换 Tab 再返回仍无按钮。源码 `AgentActionCardView.canConfirm` 仅接受 proposed / confirmation_required，实际测试与截图一致。初版测试错误假设可重试，已改为记录真实断点，没有添加产品中不存在的重试按钮。
2. **表单重试留下失败轮次**：同一幂等键提交最终成功后，对话仍保留失败回复，以及失败和成功两条“已提交信息采集表单”气泡。不能仅以提交成功推断失败提示会自动撤销。
3. **中文卡片 CTA 在 Widget 截图缺字**：查看泌乳/身体记录的中文按钮在这组截图中显示方块，实际 Text 标签及点击路由可验证。`agentResultButtonStyle()` 指定 displayFontFamily，未显式给出中文 fallback。当前证据不足以断言 Android/iOS 原生设备同样缺字；需原生复核。保留原图，不用英文替换或后期绘字掩盖问题。
4. 从记录页关闭时，正式 `_back` 在没有可 pop 的历史时回到 `/me`，需要再点 Cozymate 才回对话；不是直接回原卡片位置。返回对话默认位置靠前，“回到最新消息”仍能回到结果。
5. 小屏大字号下表单纵向滚动、按钮竖排，日期切换为输入模式；全部字段和底部操作已采成长图。原窗口保留浮层及当前滚动位置，长图保留完整正文。固定背景渐变在分屏拼接处仍可能有色块接缝，不能把它当作产品静态设计。

## 逐状态入口

每个状态 README 记录正式路由、触发、前驱、原窗口、长图、测试源文件和测量数据。

| 状态 | 路由 | 实际操作 | 证据 |
| --- | --- | --- | --- |
| confirm-failure-away | `/more` | More tab after action result | [状态](../05-agent/agent-workflow-journey-confirm-failure-away/README.md) |
| confirm-failure-pending | `/` | Tap action confirm → HTTP pending | [状态](../05-agent/agent-workflow-journey-confirm-failure-pending/README.md) |
| confirm-failure-preview | `/` | Receive authoritative action preview → controls available | [状态](../05-agent/agent-workflow-journey-confirm-failure-preview/README.md) |
| confirm-failure-result | `/` | HTTP 503 → failed action; confirm/reject controls disappear, no retry entry | [状态](../05-agent/agent-workflow-journey-confirm-failure-result/README.md) |
| confirm-failure-return | `/` | Return to Cozymate → action result retained | [状态](../05-agent/agent-workflow-journey-confirm-failure-return/README.md) |
| confirm-success-away | `/more` | More tab after action result | [状态](../05-agent/agent-workflow-journey-confirm-success-away/README.md) |
| confirm-success-pending | `/` | Tap action confirm → HTTP pending | [状态](../05-agent/agent-workflow-journey-confirm-success-pending/README.md) |
| confirm-success-preview | `/` | Receive authoritative action preview → controls available | [状态](../05-agent/agent-workflow-journey-confirm-success-preview/README.md) |
| confirm-success-result | `/` | HTTP 200 → authoritative applied state | [状态](../05-agent/agent-workflow-journey-confirm-success-result/README.md) |
| confirm-success-return | `/` | Return to Cozymate → action result retained | [状态](../05-agent/agent-workflow-journey-confirm-success-return/README.md) |
| diary-history | `/me/diary` | Tap artifact link → actual mother diary | [状态](../05-agent/agent-workflow-journey-diary-history/README.md) |
| diary-return | `/` | Cozymate tab → original conversation retained | [状态](../05-agent/agent-workflow-journey-diary-return/README.md) |
| intake-accepted | `/` | Server run starts → dialog closes and submitted entry retained | [状态](../05-agent/agent-workflow-journey-intake-accepted/README.md) |
| intake-auto-loading | `/` | Assistant completes → live form entry waiting to auto-open | [状态](../05-agent/agent-workflow-journey-intake-auto-loading/README.md) |
| intake-auto-open | `/` | Production one-second presentation timer → form dialog | [状态](../05-agent/agent-workflow-journey-intake-auto-open/README.md) |
| intake-cancelled | `/` | Cancel form → entry remains in conversation | [状态](../05-agent/agent-workflow-journey-intake-cancelled/README.md) |
| intake-date-picker | `/` | Open form date picker | [状态](../05-agent/agent-workflow-journey-intake-date-picker/README.md) |
| intake-date-selected | `/` | Select day 20 in September 2026 | [状态](../05-agent/agent-workflow-journey-intake-date-selected/README.md) |
| intake-draft-return | `/` | Reopen form → draft values retained | [状态](../05-agent/agent-workflow-journey-intake-draft-return/README.md) |
| intake-dropdown | `/` | Open follow-up dropdown | [状态](../05-agent/agent-workflow-journey-intake-dropdown/README.md) |
| intake-filled | `/` | Enter notes, radio, dropdown, date and other concern | [状态](../05-agent/agent-workflow-journey-intake-filled/README.md) |
| intake-readonly | `/` | Open submitted form → read-only values | [状态](../05-agent/agent-workflow-journey-intake-readonly/README.md) |
| intake-readonly-return | `/` | Close read-only form → same conversation | [状态](../05-agent/agent-workflow-journey-intake-readonly-return/README.md) |
| intake-reply | `/` | Follow-up response completes | [状态](../05-agent/agent-workflow-journey-intake-reply/README.md) |
| intake-request | `/` | Tap recovery assessment shortcut → actual preset request sent | [状态](../05-agent/agent-workflow-journey-intake-request/README.md) |
| intake-submitting | `/` | Submit → synthetic SSE request awaits server run signal | [状态](../05-agent/agent-workflow-journey-intake-submitting/README.md) |
| intake-validation | `/` | Submit empty required notes → inline validation | [状态](../05-agent/agent-workflow-journey-intake-validation/README.md) |
| latest-off-bottom | `/` | Scroll towards earlier messages → latest-message button appears | [状态](../05-agent/agent-workflow-journey-latest-off-bottom/README.md) |
| latest-returned | `/` | Tap latest-message button → scroll to newest response | [状态](../05-agent/agent-workflow-journey-latest-returned/README.md) |
| milk-history | `/me/lactation` | Tap artifact link → actual lactation history | [状态](../05-agent/agent-workflow-journey-milk-history/README.md) |
| milk-request | `/` | Tap milk analysis shortcut → preset question sent | [状态](../05-agent/agent-workflow-journey-milk-request/README.md) |
| milk-result | `/` | Response completes → actionable record card | [状态](../05-agent/agent-workflow-journey-milk-result/README.md) |
| milk-return | `/` | Cozymate tab → original response and artifact retained | [状态](../05-agent/agent-workflow-journey-milk-return/README.md) |
| reject-failure-away | `/more` | More tab after action result | [状态](../05-agent/agent-workflow-journey-reject-failure-away/README.md) |
| reject-failure-pending | `/` | Tap action reject → HTTP pending | [状态](../05-agent/agent-workflow-journey-reject-failure-pending/README.md) |
| reject-failure-preview | `/` | Receive authoritative action preview → controls available | [状态](../05-agent/agent-workflow-journey-reject-failure-preview/README.md) |
| reject-failure-result | `/` | HTTP 503 → failed action; confirm/reject controls disappear, no retry entry | [状态](../05-agent/agent-workflow-journey-reject-failure-result/README.md) |
| reject-failure-return | `/` | Return to Cozymate → action result retained | [状态](../05-agent/agent-workflow-journey-reject-failure-return/README.md) |
| reject-success-away | `/more` | More tab after action result | [状态](../05-agent/agent-workflow-journey-reject-success-away/README.md) |
| reject-success-pending | `/` | Tap action reject → HTTP pending | [状态](../05-agent/agent-workflow-journey-reject-success-pending/README.md) |
| reject-success-preview | `/` | Receive authoritative action preview → controls available | [状态](../05-agent/agent-workflow-journey-reject-success-preview/README.md) |
| reject-success-result | `/` | HTTP 200 → authoritative rejected state | [状态](../05-agent/agent-workflow-journey-reject-success-result/README.md) |
| reject-success-return | `/` | Return to Cozymate → action result retained | [状态](../05-agent/agent-workflow-journey-reject-success-return/README.md) |
| retry-intake-accepted | `/` | Retried run accepted → form closes | [状态](../05-agent/agent-workflow-journey-retry-intake-accepted/README.md) |
| retry-intake-auto-loading | `/` | Assistant completes → live form entry waiting to auto-open | [状态](../05-agent/agent-workflow-journey-retry-intake-auto-loading/README.md) |
| retry-intake-auto-open | `/` | Production one-second presentation timer → form dialog | [状态](../05-agent/agent-workflow-journey-retry-intake-auto-open/README.md) |
| retry-intake-completed | `/` | Retried response completes | [状态](../05-agent/agent-workflow-journey-retry-intake-completed/README.md) |
| retry-intake-failed | `/` | Three SSE retries exhausted before acceptance → editable form failure | [状态](../05-agent/agent-workflow-journey-retry-intake-failed/README.md) |
| retry-intake-pending | `/` | Retry form → same data and idempotency key | [状态](../05-agent/agent-workflow-journey-retry-intake-pending/README.md) |
| retry-intake-request | `/` | Tap recovery assessment shortcut → actual preset request sent | [状态](../05-agent/agent-workflow-journey-retry-intake-request/README.md) |
| ticket-auto-loading | `/` | Assistant completes → live form entry waiting to auto-open | [状态](../05-agent/agent-workflow-journey-ticket-auto-loading/README.md) |
| ticket-auto-open | `/` | Production one-second presentation timer → form dialog | [状态](../05-agent/agent-workflow-journey-ticket-auto-open/README.md) |
| ticket-failed | `/` | HTTP 503 → error with form draft retained | [状态](../05-agent/agent-workflow-journey-ticket-failed/README.md) |
| ticket-readonly | `/` | Open submitted ticket form → read-only | [状态](../05-agent/agent-workflow-journey-ticket-readonly/README.md) |
| ticket-request | `/` | Type and send a support request | [状态](../05-agent/agent-workflow-journey-ticket-request/README.md) |
| ticket-retrying | `/` | Retry same ticket body and idempotency key | [状态](../05-agent/agent-workflow-journey-ticket-retrying/README.md) |
| ticket-return | `/` | Close ticket detail → retained conversation | [状态](../05-agent/agent-workflow-journey-ticket-return/README.md) |
| ticket-submitted | `/` | Ticket accepted → local confirmation message without model request | [状态](../05-agent/agent-workflow-journey-ticket-submitted/README.md) |
| ticket-submitting | `/` | Submit support form → production ticket repository HTTP pending | [状态](../05-agent/agent-workflow-journey-ticket-submitting/README.md) |

## 验证

- 9 条测试通过；最终严格截图采集日志：[capture.log](runs/20260913T132518-targeted/capture.log)，没有设置金图容差或在采集时更新基线。
- 全仓 `flutter analyze --no-pub`：No issues found，见 [日志](agent-workflows-analyze.log)。两个新增 Dart 文件格式检查 0 changed。
- 59 张主窗口已查看五张总览，40 张主长图已查看七张总览；320/2x 的窗口和长图分成 71 段，九张分段审阅图逐张查看。来源/哈希见 [窗口](agent-workflow-visual-review/overview-sources.json)、[长图](agent-workflow-visual-review/long-sources.json)、[大字号分段](agent-workflow-visual-review/narrow-sources.json)。170 条审阅来源的哈希均与当前图片一致。
- 普通截图和长图已检查字段、卡片顺序与完整底部；中文 CTA 缺字仍按上文列为视觉证据限制，不将这批图描述为无差异视觉验收。
- 全局采集器未变，本次仅重采新增工作流文件；77 文件、987 通过的全量视觉采集仍是上一轮记录。

复现：

```sh
flutter test --no-pub test/features/agent_hub/agent_workflow_inventory_journey_test.dart
python3 scripts/capture-app-ui-inventory.py --flutter /Users/lute/.local/share/momcozy-toolchains/flutter/bin/flutter --test test/features/agent_hub/agent_workflow_inventory_journey_test.dart
python3 scripts/index-app-ui-inventory.py
python3 scripts/verify-app-ui-inventory.py
```

## 仍未完成

活跃 run 的 action 确认/恢复、其他 action 类型、专用结果卡/服务卡/动作评估卡及媒体路由、外部引用与导出、语音播放/麦克风、条件历史入口仍需完整点击链。表单还需原生键盘与系统返回、动态字段更新及更多实际业务字段分支；卡片中文 CTA 原生字体表现待核查。其它模块剩余分支、全体长图审核和无正常入口代码最终清单继续保留。

当前总量 **1024 条目（1005 用户 App + 19 工作台）、2107 个变体、648 个正常路由状态、323 张主长图、782 个长图变体**。文件完整性通过不等于整体覆盖完成。
