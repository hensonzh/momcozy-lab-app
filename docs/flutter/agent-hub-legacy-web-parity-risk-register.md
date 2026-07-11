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

### 推荐方案

采用四层治理，而不是只修改 Flutter 的一个条件分支。

#### 1. 后端建立同源文本不变量

- raw model delta 先进入同一个 response accumulator，再由一个有提交边界的 stateful text projector 生成 canonical 正文。
- projector 只发布已经稳定、后续不会被改写的前缀；未闭合的 `<think>`、JSON、Markdown fence/link 和待归一化空白暂存在未提交尾部，结构闭合或 finalize 时再决定保留、替换或丢弃。
- 不再对累计全文反复调用非单调 sanitizer 后用字符串前缀推算增量；`strip`、结构化 JSON 提取等变换会回改已经发送的文本，正是当前不一致的来源之一。
- 最终持久化文本必须直接取自同一个 projector 的 `finalize()` 结果，不能再经过另一套全文清洗或格式化。
- 正常完成时应满足：按顺序合并且去重后的 delta 文本等于 `message.completed.payload.text`。
- 后端记录 `delta_char_count`、`final_char_count`、最终 delta cursor 和不可逆内容摘要，监控 `stream_final_mismatch`；目标是正常链路零不一致。

这是根治用户可见闪变的核心。客户端无法在最终事件到达前猜出后端之后会怎样重写文本。

#### 2. Flutter reducer 使用真正的双缓冲

- `provisionalTextContent` 只接收 transient delta。
- `textContent` 只保存持久化、可恢复的权威文本。
- 流式阶段 UI 优先展示 provisional buffer；没有 provisional 时展示 canonical buffer。
- 收到 `message.completed` 后，无条件把 `payload.text` 写入 `textContent` 并清空 provisional buffer。
- 断线重连和历史恢复只认 canonical buffer，不能把 transient 文本持久化为最终回复。

#### 3. 对异常差异做局部平滑校正

即使后端已修复，客户端仍需防御丢帧、重放和版本兼容：

- 完全一致：只切换数据来源，不触发可见动画。
- 最终文本以临时文本开头：仅补齐缺失尾部，不重播、不重建整段气泡。
- 仅尾部不同：按 grapheme cluster 计算最长公共前缀，并回退到安全的 Markdown block 边界，在同一个正文组件中原位替换变化后缀，保持气泡 identity 和滚动锚点稳定。是否增加 120-180ms 的后缀淡入，应通过真机对拍决定，默认不增加整段动画。
- 大范围不同：最终文本仍必须覆盖临时文本，并保持当前滚动锚点；禁止重新执行逐字动画。只有验证确实更平滑时，才对正文层启用一次短交叉淡化。
- 发生任何不一致都上报诊断事件，包含长度和公共前缀比例，不记录原始正文。

#### 4. 实时语音维护独立播放游标

- 实时语音继续消费 provisional delta，不能为了等待 canonical 文本而延迟首段播报。
- 以稳定 segment ID 和 grapheme range 分别记录已提交给 TTS、已进入待播队列和已实际播放的文本游标，不能只用一个字符串长度推断进度。
- 最终文本只是补齐临时文本尾部时，仅把缺失尾部送入 TTS，不重播已提交内容。
- 最终文本在尚未播放的尾部发生变化时，丢弃分歧点之后的待播分段，并按 canonical 后缀重建队列。
- 如果分歧已经落在播放完成的音频中，普通文本差异不从头重播；最终可见文本以 canonical 为准并记录异常。涉及安全删除或敏感信息修正时，应立即停止剩余播放。

### 不采用的方案

- 不保留临时文本作为最终结果：违反合同，重连后还会与历史消息不一致。
- 不关闭流式输出等待最终消息：首字延迟和实时感明显退化。
- 不按固定时间节流 delta：继续保持“有 delta 就交付前端”的产品要求。
- 不在每次完成时无条件重建整个 Markdown 气泡：会造成明显闪动和滚动跳变。

### R01 验收标准

1. 最终可见纯文本语义与 `message.completed.payload.text` 一致。
2. transient delta 只更新 provisional buffer，不进入持久化历史。
3. 完全一致和仅补尾场景不发生整段闪烁、滚动跳变或语音重播。
4. 尾部差异只替换变化后缀；大范围差异最终仍以 canonical 文本为准。
5. 重连后没有 delta 也能仅凭 `message.completed` 恢复完整回复。
6. TTS 仅补播 canonical 缺失尾部，不从头重复；未播放的分歧尾部可以被替换。
7. 快捷回复、artifact、action card 和回复完成状态不受 reconciliation 影响。
8. 后端覆盖未闭合 think/JSON/Markdown、尾部空白、断流和 finalize 的 projector 测试，证明合并 delta 与最终文本一致。
9. 新增 reducer、widget、重连和实时语音回归测试，并删除“completed mismatch 保留临时文本”的错误测试预期。

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
