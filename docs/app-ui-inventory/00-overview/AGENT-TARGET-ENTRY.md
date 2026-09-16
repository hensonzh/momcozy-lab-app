# 通知 → 指定 Cozymate 会话：实际入口审计

> 历史版本报告：当前初始化错误已修复，指定会话入口及历史抽屉条件以 [G08 当前核验](AGENT-ENTRY-CURRENT.md) 为准。以下错误图和日志保留作版本记录。

使用正式 `MomCozyFlutterApp/createMomCozyRouter`、通知 coordinator/repository 以及默认 Agent 页面构建器，从“更多 → 通知 → Conversation ready”逐步点击。没有注入 Agent 页面、没有开启历史功能开关，也没有绕过通知路由校验。

本轮新增 **9 个实际状态、18 个尺寸/字号变体**，其中窄屏恢复页有 **1 张完整长图**。4 项测试严格比较通过；2 个新增 Dart 文件静态检查无问题、格式无变化。生产代码、采集器与索引算法均未修改。

## 观察结果

1. 默认 `/` 不提供历史按钮。通知 `/open` 返回合法 UUID 的 `/?conversationId=…` 时，客户端允许导航；后端 `modules/notifications/lifecycle.py` 的 `agent_conversation` 分支也明确支持这一路径。因此这是有实际协议来源的条件入口，不是任意拼接路由。
2. 当前默认页面构建器把 `用户ID:会话ID` 字符串作为 `stateCacheKey`。`AgentHubPage._restoreCachedInteractionState` 将它用于 `Expando`，抛出 `ArgumentError`，页面显示框架 ErrorWidget。异常发生在历史 Repository 调用之前，测试确认 `/v1/agent/threads` 没有任何请求；不能把“历史加载失败重试/历史列表/切换”描述为这条入口已到达的状态。
3. 通知已被标记为已读。点击底部 More 正常离开，没有再次抛异常；点 Cozymate 回到不带会话 ID 的 `/`，默认聊天页面恢复、历史按钮仍不出现。再次打开通知页，该条已读。
4. 无效 UUID、多余 query 参数和外部 URL 均被通知路由检查拒绝，留在通知页并显示 `This update is no longer available.`；关闭提示后保留已读通知。未打开外部网站。

## 截图与链路

| 实际状态 | 入口 / 操作 | 证据 |
| --- | --- | --- |
| default-recovered | Bottom Cozymate → normal / page recovers without history button | [截图及前驱链](../05-agent/agent-history-journey-default-recovered/README.md) |
| error-away | Bottom More → leave failed target route; More renders without another exception | [截图及前驱链](../05-agent/agent-history-journey-error-away/README.md) |
| external-target | Open notification → route allowlist rejects external-target; inbox and message retained | [截图及前驱链](../05-agent/agent-history-journey-external-target/README.md) |
| extra-query | Open notification → route allowlist rejects extra-query; inbox and message retained | [截图及前驱链](../05-agent/agent-history-journey-extra-query/README.md) |
| invalid-id | Open notification → route allowlist rejects invalid-id; inbox and message retained | [截图及前驱链](../05-agent/agent-history-journey-invalid-id/README.md) |
| notification-entry | More → notification inbox with conversation update | [截图及前驱链](../05-agent/agent-history-journey-notification-entry/README.md) |
| read-notification | Return to inbox → conversation notification marked read despite target initialization error | [截图及前驱链](../05-agent/agent-history-journey-read-notification/README.md) |
| rejected-dismissed | Dismiss target unavailable message → read inbox remains | [截图及前驱链](../05-agent/agent-history-journey-rejected-dismissed/README.md) |
| target-error | Open notification → default target route throws ArgumentError for string Expando key before history HTTP | [截图及前驱链](../05-agent/agent-history-journey-target-error/README.md) |

## 验证材料及边界

- [本轮严格采集日志](runs/20260913T135729-targeted/capture.log)：4 PASS；没有更新基线或放宽比较容差。最早测试按“目标页应打开”编写，真实执行首先暴露初始化异常，最终测试据实际产品行为断言该错误并继续验证恢复路径。
- [静态检查](agent-target-analyze.log)：No issues found；格式检查 2 files / 0 changed。
- [393 异常堆栈](../raw/agent-target-init-393-error.txt)、[320 异常堆栈](../raw/agent-target-init-320-error.txt)：精确到 Expando 与页面初始化调用点。
- 已查看 [393 全部窗口](agent-target-visual-review/windows-393.png)、[320/2x 全部窗口](agent-target-visual-review/windows-320-2x.png)，以及[恢复页完整长图](../raw/test/goldens/ui_inventory/agent-history-journey-default-recovered-320-2x.long.png)。[19 个图片来源与哈希](agent-target-visual-review/sources.json)对应 18 个窗口和 1 张长图。
- 框架 ErrorWidget 在宿主 Widget 测试中使用默认测试字体，错误文字呈黄色字块；保留了原始实际窗口，并附可读异常堆栈，没有绘制替代错误页面。此处尚无本轮原生设备截图，不能将宿主字块表现等同于手机错误字体。
- 窄屏 2x 的通知标题/底部标签换行已如实保留。恢复后 Cozymate 首屏问候超出聊天视口，长图完整覆盖 614px 内容、测量偏移 0…329；固定背景渐变有拼接色带，仍是采集限制。
- 通知 HTTP、会话存储、推送/权限平台使用隔离边界；未向真实用户发送推送、未访问真实会话、未改动当前设备账号。列表记录文本为非业务断言用的合成内容。
- 默认入口断点已有证据。开启 `MOMCOZY_ENABLE_AGENT_HISTORY` 的其它构建仍需分开记录，既有历史组件预览继续属于组件状态证据，不能因本次异常入口出现而提升为当前默认构建可达。

## 后续

这完成了当前指定会话通知入口及失败后返回的实际核验，但不代表全 App 盘点完成。其它条件入口、权限/媒体分支、剩余操作链和全体长图视觉审核仍继续；文件完整性校验 PASS 也不能替代最终覆盖审计。
