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
| R01 | P1 | 流式正文与持久化最终正文未同源 | 已完成 | 结束、重连或历史恢复时正文可能分叉 |
| R02 | P1 | 媒体资源和全屏查看链路不可用 | 已完成 | 开箱图片、PDF、视频无法可靠查看 |
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

## R01 流式正文与持久化最终正文未同源

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

用户对“不一致”的担忧成立。产品最终选择优先保证低延迟和阅读连续性：completed 不得覆盖已经展示的正文；相应地，已发布 delta 不能再被定义为可推翻的临时草稿，而必须由后端纳入最终 canonical message。错误或未清洗内容应在发布前治理，不能依赖完成事件事后改写。

### 已确认产品不变量

1. 模型一旦产生经过必要安全清洗的稳定文本，就立即以 delta 交付并展示；不能等待工具/回答模式判断、整段生成完成或 `message.completed`。
2. 已经进入回答气泡的正文就是 canonical 内容，只能追加，不能撤回、替换或在完成时重写；用户最终看到的正文必须与流式过程中看到的正文连续一致。
3. `message.completed` 只负责确认完整性和终态，正常链路不能触发正文跳变。
4. 不采用固定时间窗口聚合 delta；只允许为识别未闭合控制结构保留最小的语义尾部。
5. 屏幕正文与实时语音消费同一条已提交文本流，不能各自清洗出不同结果。

### 推荐方案

采用五层治理，把“有文本立即输出”和“已展示正文不可撤销”同时写入 runtime 事件合同，而不是只修改 Flutter 的一个条件分支。

这会收紧现有 transient delta 的语义，必须由后端先完成 append-only 保证和增量字段，再切换 Flutter reducer；不能先让客户端假设旧事件已经满足新不变量。

#### 1. Runtime 不在热路径判断工具文本和最终文本

- 所有模型 turn 共用同一个 run-scoped canonical message builder；经过 projector 提交的文本立即追加到 builder 并发布 `message.delta`，无论之后是否发生工具调用。
- 工具调用、进度和 artifact/action 事件照常独立发布，但不能撤回已经显示的工具前话术。
- 工具调用后的回答继续追加到同一个气泡。工具前文本、工具后文本和最终结论共同构成最终持久化消息。
- Provider 每个 turn 的 completed text 只用于补发该 turn 没有流出的尾部和完整性诊断，不能覆盖已经提交的片段。
- Prompt 应尽量让工具前话术保持简短、中性，不在工具结果返回前陈述未经验证的事实；这是内容质量约束，不作为延迟正文的运行时门禁。

#### 2. 后端建立同源、只追加的文本投影器

- 所有 user-visible raw model delta 先进入同一个 response accumulator，再由一个有提交边界的 stateful text projector 生成 canonical 正文。
- projector 只发布已经稳定、后续不会被改写的前缀；未闭合的 `<think>`、JSON、Markdown fence/link 和待归一化空白暂存在未提交尾部，结构闭合或 finalize 时再决定保留、替换或丢弃。
- 不再对累计全文反复调用非单调 sanitizer 后用字符串前缀推算增量；`strip`、结构化 JSON 提取等变换会回改已经发送的文本，正是当前不一致的来源之一。
- projector 每提交一个片段，就同时追加到 live delta 和 canonical message builder；已经提交的前缀永远不可修改。
- 最终持久化文本必须直接取自同一个 builder 的 `finalize()` 结果，不能再经过另一套全文清洗或格式化。若 Provider final 与 builder 冲突，保留 builder、记录 `stream_final_mismatch`，不能用 Provider final 改写正文。
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
- 若二者发生非前缀冲突，继续保留已经展示的 live buffer，不允许 completed 覆盖；同时上报事件合同错误。后端完成 append-only builder 后，该兼容分支不应再被正常链路触发。
- 若本轮完全没有收到 delta，允许使用 completed 正文作为整个回复，这是非流式 Provider、断线或恢复场景的兜底。
- 断线重连和历史恢复只认 canonical buffer，不能把 transient 文本持久化为最终回复。
- 正文组件保持稳定 identity 和滚动锚点，完成事件不能触发整段 Markdown 重新入场或逐字动画。

#### 5. 实时语音消费同一 committed segment

- 实时语音直接消费通过 projector 提交的 segment，包括工具调用前已经显示的文本；不能另行读取 raw/provider final 文本，也不能为了等待 `message.completed` 延迟首段播报。
- 以稳定 segment ID 和 grapheme range 分别记录已提交给 TTS、已进入待播队列和已实际播放的文本游标，不能只用一个字符串长度推断进度。
- completed 事件只补交尚未消费的连续 segment，不重播已经提交或播放的内容。
- 安全过滤必须发生在 projector 提交前；不能先把正文展示或播出，再依赖最终事件删除敏感内容。

### 已接受的取舍

- 工具调用前已经输出的“我先帮你查一下”等文字会保留在最终气泡、历史消息和语音中。
- 如果模型在工具结果返回前输出了错误事实，系统不会在完成时静默改写；应通过 prompt/eval 限制工具前内容为中性过程话术。
- 未闭合 think/JSON/Markdown 或尚未通过安全检查的片段不属于“稳定文本”，可以保留最小语义尾部；除此之外不增加分类等待或时间窗口。
- 文本自然增长造成的换行属于正常流式排版；禁止的是字符被删除、替换或整段重新入场。

### 不采用的方案

- 不允许 Flutter 在 completed 冲突时覆盖已经展示的 live 文本；兼容期保留 live 并上报，根因由后端 canonical builder 消除。
- 不关闭流式输出等待最终消息：首字延迟和实时感明显退化。
- 不通过 output item 或结构化事件锁定工具/回答模式后再输出：模式判断会增加首段等待，且不是本方案的产品取舍。
- 不把工具 turn 的自由文本先展示、完成时再删除：一旦展示，它就属于最终 canonical 正文。
- 不按固定时间节流 delta：继续保持“有 delta 就交付前端”的产品要求。
- 不在 completed 时做最长公共前缀替换、淡化或整段 Markdown 重建：这些只能掩饰合同错误，仍会造成用户所反感的内容变化。

### R01 验收标准

1. 任意模型 turn 的首个稳定文本 delta 无需等待工具/回答分类、本轮生成完成或 `message.completed` 即可到达 Flutter。
2. 每次页面更新都只是追加正文；完成时不存在字符撤回、后缀替换、整段闪烁、滚动跳变或逐字动画重播。
3. 按 `segment_index` 合并后的 delta 与 `message.completed.payload.text` 逐字符一致，内容摘要一致。
4. 工具调用前后的正文 delta 按原顺序保留并持久化，completed 不删除工具前文本。
5. transient delta 只更新 live buffer，不自行进入持久化历史；completed 无差异切换到 canonical buffer。
6. 丢失、重复、乱序和重连场景只能导致暂停追加或补齐尾部，不能产生非前缀正文。
7. 重连后没有 delta 也能仅凭 `message.completed` 恢复完整回复。
8. TTS 与屏幕消费相同 segment，只补播缺失尾部，不从头重复；工具前文本的播报结果与屏幕一致。
9. 快捷回复、artifact、action card 和回复完成状态不受正文完整性校验影响。
10. 后端覆盖工具前/后文本、未闭合 think/JSON/Markdown、尾部空白、断流和 finalize 测试，证明正文 append-only 且合并 delta 与最终文本一致。
11. 新增 reducer、widget、重连和实时语音回归测试，明确固化“completed mismatch 不覆盖已展示文本”，同时用后端测试保证正常链路不再产生 mismatch。

## 其他风险详情

### R02 媒体资源和全屏查看链路不可用

- 已建立 typed asset model，并通过统一仓库鉴权加载 `/v1/assets/{asset_id}`；退役的 `/skill-assets/...` 和 `/demo/...` 不再作为有效媒体源。
- 图片已支持内存解码、加载/失败/重试、全屏 contain、双击和手势缩放；PDF 已支持多页解析、滚动、`0.1-4x` 缩放和解析级重试。
- Android PDF 查看器锁定 `pdfrx 2.2.24`，避开 2.3+ 在 flavor integration APK 中遗漏 PDFium 的上游问题；统一构建入口会验证 PDFium，并从 release APK 移除无用 WASM 资源。
- 视频已支持带鉴权 header 的原生流式播放、一次 token 刷新、加载/运行中失败重试、播放/静音/进度控制、应用内沉浸式和竖屏横向片源旋转。
- 后端 `/v1/assets/{asset_id}` 已支持单区间 `206/416`；Local 使用 seek/read，S3/OSS 直接发送 Range，不再为视频拖动整包读取对象。
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

1. **阶段 A：消息正确性。** 先完成 R01 的后端 canonical builder、stateful text projector、append-only segment 合同、Flutter live/canonical 双缓冲和回归测试。
2. **阶段 B：核心能力断点。** 完成 R02、R03、R04，恢复媒体、多模态输入和个性化购物车闭环。
3. **阶段 C：可执行组件。** 完成 R05、R06、R07，保证表单、工单和链接动作可靠且幂等。
4. **阶段 D：数据语义对齐。** 完成 R08、R09、R10、R11，统一 profile、card mapper、consult context 和 artifact 时序。
5. **阶段 E：体验补齐。** 完成 R12，并做旧 Web/Flutter 真机并排验收。

每个阶段都遵循：先补失败测试和 fixture，再实现，运行专项测试与全量静态分析，最后做三个 viewport 的 Golden/真机检查。上一阶段验收通过后再进入下一阶段。

## 当前验证基线

- `flutter analyze`：通过。
- Flutter 全量单元、Widget 和 Golden 测试：592 项通过。
- Flutter Agent Hub、reducer、feature page 相关测试：197 项通过。
- 旧 Web 输入栏、artifact、事件语义和顺序专项测试：91 项通过。
- 现有测试通过不代表剩余风险已关闭；R03-R12 仍需按各自合同补齐真实平台能力、跨端 fixture 和真机验收。

## 变更记录

| 日期 | 变更 | 结果 |
| --- | --- | --- |
| 2026-07-11 | 建立首次专项审查风险台账 | 记录 R01-R12；R01 进入设计中 |
| 2026-07-11 | 阶段性评估回答模式锁定方案 | 该方案随后被“所有稳定文本立即输出”的最终决策取代 |
| 2026-07-11 | 确认不等待工具/回答模式判断 | 所有稳定文本立即追加；工具前文本进入最终消息，completed 永不覆盖已展示正文 |
| 2026-07-11 | 完成 R01 append-only canonical stream | 后端投影、Flutter reducer、完整性元数据和语音消费统一通过回归测试 |
| 2026-07-11 | 完成 R02 图片与 PDF 子项 | 鉴权资源、图片缩放、多页 PDF、三档 viewport、Android PDFium 和 release 打包门禁通过 |
| 2026-07-11 | 完成 R02 视频与 Range 子项 | Local/S3 分段读取、鉴权原生播放、控制栏、沉浸式、Android 真解码和三档 viewport 通过 |
