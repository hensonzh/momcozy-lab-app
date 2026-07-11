# Agent Hub 旧 Web 体验对齐风险台账

## 目的

本文记录 2026-07-11 对旧 Web `AgentHub` 与 Flutter Agent Hub 的专项审查结果，作为后续分批修复、测试和验收的唯一风险清单。

审查基准：

- 旧 Web 用户体验以 `legacy_web/src/pages/AgentHub.tsx`、`legacy_web/src/pages/agentHub/AgentHubRichTextBlock.tsx` 和相关组件测试为准。
- 新 Flutter 事件合同以 `docs/backend-contract/api-contract-handoff.md` 和 `docs/backend-contract/flutter-client-compatibility.md` 为准。
- 已经明确调整的产品行为不作为风险：移除历史气泡手动播报、切页继续播报、返回 Agent Hub 不自动聚焦输入框、状态条不显示前置圆点、状态渐变加速、冷启动开启新会话。

## 状态约定

| 状态 | 含义 |
| --- | --- |
| 待处理 | 已确认风险，尚未开始修复 |
| 设计中 | 正在明确合同、边界或实现方案 |
| 处理中 | 已开始修改代码 |
| 待验证 | 已实现，等待自动化和真机验收 |
| 已关闭 | 验收通过且没有残留阻塞风险 |

## 风险总览

| ID | 优先级 | 风险 | 当前状态 | 主要影响 |
| --- | --- | --- | --- | --- |
| R01 | P1 | 最终文本未覆盖 transient delta | 设计中 | 最终可见回复可能不是后端权威消息 |
| R02 | P1 | 媒体资源和全屏查看链路不可用 | 待处理 | 开箱图片、PDF、视频无法可靠查看 |
| R03 | P1 | 正式 App 未接通图片和语音输入 | 待处理 | 旧 Web 的多模态输入入口不可用 |
| R04 | P1 | 待产包购物车丢失 artifact 个性化数据 | 待处理 | 默认清单可能覆盖用户定制清单 |
| R05 | P2 | 已提交表单在历史消息中可能恢复可编辑 | 待处理 | 用户可能重复提交或重复生成服务结果 |
| R06 | P2 | 售后工单草稿 artifact 未实现 | 待处理 | 工单确认表单可能完全不显示 |
| R07 | P2 | 普通链接和专业引用点击无效 | 待处理 | 用户无法打开来源和非媒体链接 |
| R08 | P2 | 用户资料复用和信息采集表单归一化不完整 | 待处理 | 重复询问、默认值缺失、必填规则不一致 |
| R09 | P2 | 专项卡片数据语义未完全对齐 | 待处理 | 分娩沟通卡和待产包卡丢失部分有效内容 |
| R10 | P2 | IBCLC 上下文和咨询完成状态丢失 | 待处理 | 咨询身份、返回位置和完成状态不连续 |
| R11 | P2 | Artifact 出现时机早于旧 Web | 待处理 | 卡片可能先于解释文字出现并抢占滚动位置 |
| R12 | P2/P3 | 媒体语义播报和卡片导出缺失 | 待处理 | 步骤图片说明不播报，计划卡无法保存图片 |

## R01 最终文本与 transient delta 不一致

### 现状

Flutter 在收到 transient `message.delta` 时，同时累加 `textContent` 和 `provisionalTextContent`。收到 `message.completed` 后，如果最终文本不是当前文本的前缀，`_finalizedTextContent` 会继续保留已经展示的临时文本。

这与生产合同相反：transient delta 只允许作为临时预览，`message.completed.payload.text` 必须成为最终权威内容。

关键证据：

- `flutter_app/lib/core/agent_stream/agent_stream_run_state.dart:224`
- `flutter_app/lib/core/agent_stream/agent_stream_run_state.dart:419`
- `flutter_app/test/core/agent_stream/agent_stream_run_state_test.dart:193`
- `docs/backend-contract/api-contract-handoff.md:80`
- `docs/backend-contract/flutter-client-compatibility.md:60`

### 用户体验判断

用户对“不一致”的担忧成立。若直接在结束时把整段回复替换成不同文本，会产生闪变、跳行和阅读位置漂移；若像当前实现一样保留临时文本，又会让错误、未清洗或不可恢复的内容成为最终消息。两种极端方案都不可接受。

### 已确认产品不变量

1. 最终回答一旦产生稳定文本，就立即以 delta 交付并展示；不能等待整段回答生成完或等待 `message.completed`。
2. 已经进入回答气泡的正文只能追加，不能撤回、替换或在完成时重写；用户最终看到的正文必须与流式过程中看到的正文连续一致。
3. `message.completed` 只负责确认完整性和终态，正常链路不能触发正文跳变。
4. 不采用固定时间窗口聚合 delta；只允许为识别未闭合控制结构保留最小的语义尾部。
5. 屏幕正文与实时语音消费同一条已提交文本流，不能各自清洗出不同结果。

### 推荐方案

采用五层治理，把“低延迟”和“不可变正文”同时写入 runtime 事件合同，而不是只修改 Flutter 的一个条件分支。

这会收紧现有 transient delta 的语义，必须由后端先完成 append-only 保证和增量字段，再切换 Flutter reducer；不能先让客户端假设旧事件已经满足新不变量。

#### 1. Runtime 明确区分工具模式和回答模式

- 一个模型 turn 必须二选一：调用工具，或者生成用户可见回答；工具 turn 不得产生 `message.delta`。
- 工具执行过程只通过受控的 `run.progress`、`tool.*` 和 artifact/action 事件表达，不能把模型自由生成的工具前话术塞进回答气泡。
- Provider 的 output item 类型是模式信号：出现 function call 时进入工具模式；出现 assistant message 时锁定回答模式，并从第一个稳定文本 delta 开始立即发布。
- 回答模式一旦开始，本 turn 不再接受后置工具调用。模型提示负责预防混合输出，runtime 负责校验；若发布正文前发现违规可静默重试，若正文已经提交则不得删除正文，应终止该次违规执行并提供重试状态。
- 这里不等待整个模型 turn，更不等待最终回答生成完成；只是在事件源处阻止“不确定是不是正文”的内容进入 `message.delta`。

#### 2. 后端建立同源、只追加的文本投影器

- 回答模式下的 raw model delta 先进入同一个 response accumulator，再由一个有提交边界的 stateful text projector 生成 canonical 正文。
- projector 只发布已经稳定、后续不会被改写的前缀；未闭合的 `<think>`、JSON、Markdown fence/link 和待归一化空白暂存在未提交尾部，结构闭合或 finalize 时再决定保留、替换或丢弃。
- 不再对累计全文反复调用非单调 sanitizer 后用字符串前缀推算增量；`strip`、结构化 JSON 提取等变换会回改已经发送的文本，正是当前不一致的来源之一。
- projector 每提交一个片段，就同时追加到 live delta 和 canonical message builder；已经提交的前缀永远不可修改。
- 最终持久化文本必须直接取自同一个 builder 的 `finalize()` 结果，不能再经过另一套全文清洗或格式化。Provider completed output 只用于完整性检查，不能覆盖已经提交的正文。
- 正常完成时应满足：按顺序合并且去重后的 delta 文本等于 `message.completed.payload.text`。
- 后端记录 `delta_char_count`、`final_char_count`、最终 delta cursor 和不可逆内容摘要，监控 `stream_final_mismatch`；目标是正常链路零不一致。

这是根治用户可见闪变的核心。客户端无法在最终事件到达前猜出后端之后会怎样重写文本。

#### 3. Delta 合同支持缺口检测

- transient 表示事件载体没有持久化，不表示正文内容可以被撤回；已发布 delta 的内容语义是 committed、append-only。
- 每个 `message.delta` 携带稳定的 `message_stream_id`、连续 `segment_index` 和累计摘要；`message.completed` 携带最终 `segment_count`、内容摘要和完整正文。
- 客户端只追加连续 segment。遇到重复则去重，遇到缺口则暂存后续 segment 并请求 Redis replay 或 canonical snapshot，不能把缺失中段后的文本直接拼到页面上。
- 这样即使发生丢包或重连，页面已展示内容仍然始终是最终正文的前缀，恢复过程只会继续追加。
- 新字段保持 schema additive；后端先上线并验证 delta/final 一致率，再由 Flutter 启用严格完整性 reducer，避免新旧版本交叉期产生错误假设。

#### 4. Flutter reducer 使用 live/canonical 双缓冲

- live buffer 只接收按 segment 连续验证过的 committed delta。
- `textContent` 只保存持久化、可恢复的权威文本。
- 流式阶段 UI 优先展示 live buffer；没有 live 内容时展示 canonical buffer。
- 收到 `message.completed` 后，若正文完全一致，只切换数据来源并结束 run，不重建正文 Widget。
- 若 completed 正文是 live buffer 的扩展，只追加因断流缺失的尾部，再切换数据来源。
- 若二者发生非前缀冲突，将其视为事件合同或数据完整性错误：先按 segment replay/resync，禁止直接替换已展示正文；仍无法恢复时进入可重试错误态并上报诊断。
- 断线重连和历史恢复只认 canonical buffer，不能把 transient 文本持久化为最终回复。
- 正文组件保持稳定 identity 和滚动锚点，完成事件不能触发整段 Markdown 重新入场或逐字动画。

#### 5. 实时语音消费同一 committed segment

- 实时语音直接消费通过 projector 提交的 segment，不能另行读取 raw/provider final 文本，也不能为了等待 `message.completed` 延迟首段播报。
- 以稳定 segment ID 和 grapheme range 分别记录已提交给 TTS、已进入待播队列和已实际播放的文本游标，不能只用一个字符串长度推断进度。
- completed 事件只补交尚未消费的连续 segment，不重播已经提交或播放的内容。
- 安全过滤必须发生在 projector 提交前；不能先把正文展示或播出，再依赖最终事件删除敏感内容。

### 不采用的方案

- 不让 Flutter 在 completed 冲突时自行选择保留 live 文本或覆盖 canonical 文本：冲突必须在事件源和 replay 层解决。
- 不关闭流式输出等待最终消息：首字延迟和实时感明显退化。
- 不等待整个模型 turn 才判断是否展示最终回答：回答模式确认后，稳定 delta 必须立即交付。
- 不把工具 turn 的自由文本先当正文展示、完成时再删除：这在逻辑上无法同时满足低延迟和无跳变。
- 不按固定时间节流 delta：继续保持“有 delta 就交付前端”的产品要求。
- 不在 completed 时做最长公共前缀替换、淡化或整段 Markdown 重建：这些只能掩饰合同错误，仍会造成用户所反感的内容变化。

### R01 验收标准

1. 回答模式首个稳定文本 delta 无需等待本轮生成完成或 `message.completed` 即可到达 Flutter。
2. 每次页面更新都只是追加正文；完成时不存在字符撤回、后缀替换、整段闪烁、滚动跳变或逐字动画重播。
3. 按 `segment_index` 合并后的 delta 与 `message.completed.payload.text` 逐字符一致，内容摘要一致。
4. 工具 turn 不产生 `message.delta`，工具状态通过语义事件展示；回答模式开始后不再执行后置工具调用。
5. transient delta 只更新 live buffer，不自行进入持久化历史；completed 无差异切换到 canonical buffer。
6. 丢失、重复、乱序和重连场景只能导致暂停追加或补齐尾部，不能产生非前缀正文。
7. 重连后没有 delta 也能仅凭 `message.completed` 恢复完整回复。
8. TTS 与屏幕消费相同 segment，只补播缺失尾部，不从头重复，也不播出工具轮草稿。
9. 快捷回复、artifact、action card 和回复完成状态不受正文完整性校验影响。
10. 后端覆盖工具混合输出、未闭合 think/JSON/Markdown、尾部空白、断流和 finalize 测试，证明正文 append-only 且合并 delta 与最终文本一致。
11. 新增 reducer、widget、重连和实时语音回归测试，并删除“completed mismatch 保留临时文本”的错误测试预期。

## 其他风险详情

### R02 媒体资源和全屏查看链路不可用

- Flutter 仍处理已退出生产合同的 `/skill-assets/...`，没有完整接入 `/v1/assets/{asset_id}`。
- `_MediaViewerContent` 不使用传入的 URL，图片、PDF 和视频都只是占位 UI。
- 修复目标：统一 typed asset model、鉴权资源加载、图片缩放、PDF 分页、视频播放和加载/失败/重试状态。
- 验收重点：开箱步骤图片、远程 PDF、视频、返回导航和三个移动 viewport。

### R03 正式 App 未接通图片和语音输入

- `_buildDefaultAgentHubPage` 没有注入图片 picker、录音器和 voice input controller。
- 拍照与上传共用同一回调，附件只显示数量，发送后历史气泡不保留缩略图。
- 当前按住说话只在松手后触发一次 `captureAndTranscribe()`，而 controller 会立即开始并停止录音。
- 修复目标：区分相机/相册来源、独立附件状态、按下开始/松开结束/取消丢弃、权限状态和发送后缩略图。

### R04 待产包购物车丢失个性化数据

- Artifact 卡片跳转没有携带 `groups/totals`，购物车页面固定读取 `_hospitalBagCartGroups`。
- 页面可能把默认数据同步到后端，覆盖本轮 Agent 生成的个性化清单。
- 修复目标：建立共享 cart repository/state，以 artifact cart update 为输入，路由只传稳定 cart/session ID。

### R05 表单提交状态不持久

- `submitted` 只存在于 `AgentArtifactForm` 的 Widget state。
- 回复归档到历史列表后，表单可能重新创建为 editing，并继续拥有 `onFormSubmit`。
- 修复目标：按 `artifact_id` 保存表单 lifecycle 和已提交值，历史表单只读展示，幂等键阻止重复提交。

### R06 售后工单草稿未实现

- Mapper 不读取 `ticket` envelope，presentation kind 中没有 support ticket。
- 修复目标：支持旧 Web 的工单字段、校验、确认文案、提交完成态，并与生产 action contract 明确边界。

### R07 链接和引用点击无效

- Citation action 没有可执行 route，生产 action handler 会直接忽略。
- 普通 Markdown 链接只识别媒体扩展名和待产包路径。
- 修复目标：受控外链打开器、同源路由分发、`momcozy.web_search.citations` 展示、URL 安全校验和失败反馈。

### R08 用户资料和表单归一化不完整

- Flutter greeting profile 只读取姓名，旧 Web 以姓名和年龄共同判断 onboarding 是否完成。
- 表单没有合并孕期资料默认值，也缺少旧表单识别、历史值归一化和部分强制必填规则。
- 修复目标：定义 typed `BirthPrepProfileDefaults`，由页面 controller 注入表单 mapper，避免 UI 层重复请求资料。

### R09 专项卡片数据语义未完全对齐

- 分娩沟通卡没有完整兼容旧字段别名、嵌套值和显示值归一化。
- 待产包卡没有展示 `explain`、`personalized_by`、证件复印要求等个性化原因。
- 修复目标：先建立 schema fixture 和 golden，再统一 mapper normalization，renderer 只消费稳定 view model。

### R10 IBCLC 上下文和完成状态丢失

- 卡片硬编码顾问信息；页面丢弃 `consultId`、问题背景和 return-to 上下文。
- 咨询结束没有回写卡片完成态。
- 修复目标：typed consult route state、稳定 consult ID、完成事件回写和原滚动位置恢复。

### R11 Artifact 出现时机偏早

- Flutter 收到 artifact 事件后立即渲染并触发 focus。
- 旧 Web 先暂存 artifact，正文开始输出后才追加。
- 修复目标：在 transcript controller 中维护 pending artifacts；首段可见正文出现后再发布，纯 artifact 回复则在 `message.completed` 或终态时兜底发布。

### R12 媒体语义播报和卡片导出缺失

- Flutter 语音清洗会删除图片 Markdown，未消费 `media_voice` 的 spoken label/detail。
- 孕期计划、分娩沟通卡和待产包卡没有 PNG 导出入口。
- 修复目标：媒体 narration resolver、语音去重，以及卡片导出/系统分享能力。

## 建议推进顺序

1. **阶段 A：消息正确性。** 先完成 R01 的后端 stateful text projector、同源不变量、Flutter 双缓冲和回归测试。
2. **阶段 B：核心能力断点。** 完成 R02、R03、R04，恢复媒体、多模态输入和个性化购物车闭环。
3. **阶段 C：可执行组件。** 完成 R05、R06、R07，保证表单、工单和链接动作可靠且幂等。
4. **阶段 D：数据语义对齐。** 完成 R08、R09、R10、R11，统一 profile、card mapper、consult context 和 artifact 时序。
5. **阶段 E：体验补齐。** 完成 R12，并做旧 Web/Flutter 真机并排验收。

每个阶段都遵循：先补失败测试和 fixture，再实现，运行专项测试与全量静态分析，最后做三个 viewport 的 Golden/真机检查。上一阶段验收通过后再进入下一阶段。

## 当前验证基线

- `flutter analyze`：通过。
- Flutter Agent Hub、reducer、feature page 相关测试：197 项通过。
- 旧 Web 输入栏、artifact、事件语义和顺序专项测试：91 项通过。
- 现有测试通过不代表风险已关闭；部分测试当前使用 fake provider、只验证占位页面存在，或固化了 R01 的错误 reducer 行为。

## 变更记录

| 日期 | 变更 | 结果 |
| --- | --- | --- |
| 2026-07-11 | 建立首次专项审查风险台账 | 记录 R01-R12；R01 进入设计中 |
| 2026-07-11 | 确认 R01 低延迟与正文不可变要求 | 将方案收敛为回答模式即时流式、正文 append-only、completed 无差异确认 |
