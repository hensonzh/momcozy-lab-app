# 宝宝和我 / 计划 / 智能体主页旧 Web 对齐测试方案

## 目标

以 `legacy_web/` 当前保留的旧 Web 实现为行为基准，把三大入口的核心 UI/UX 契约沉淀为 Flutter widget/golden 测试。任何后续 Flutter 调整都必须先通过这些测试，再进入真机验证。

## 旧 Web 核心设计逻辑

### 宝宝和我

- 页面首屏由 care stage（孕期/哺乳期）和 identity tab（妈妈/宝宝）驱动。
- 哺乳期妈妈页展示四个主模块：母乳产出、乳房健康、产后恢复、补能与休息。
- 妈妈页趋势图支持周/月维度切换，切换后标题和图表语义要同步变化。
- 乳房健康、产后恢复、补能与休息等模块按钮必须打开对应详情，不允许只是静态装饰。
- 孕期模式禁用宝宝页，展示孕期日记和孕期计划，不显示哺乳期模块。
- 宝宝页展示奶量摄入、成长发育、宝宝健康、宝宝睡眠；成长发育支持记录指标和 milestone。
- 从宝宝和我切到其它底部 tab 再返回时，已选择的妈妈/宝宝 tab、成长曲线维度、本地新增状态应保留。
- 旧的“下一步 / 补写孕期日记 / 今日待办 / 状态同步失败首屏卡片”不属于当前旧 Web 基准，不应重新出现在 Flutter 首屏。

### 计划

- 顶部日期条以周为单位，只有当天显示“今”，切换到其它日期后页面 summary 和空态文案必须随日期变化。
- 提醒入口位于计划 summary 卡片右上角；关闭提醒需要确认，取消后状态不变，确认后按钮和文案同步切换。
- Agent 建议卡包含头像、调整说明、提醒开关、对话入口；对话入口进入智能体主页并预填“我想调整今天的吸乳排期”。
- 任务区包含说明按钮、调整日程、添加任务、任务 checkbox、编辑弹窗、删除入口和下一任务快捷操作。
- 空任务状态提供“吸奶补录”和“喂养记录”本地入口。
- 从计划切到其它底部 tab 再返回时，提醒状态、本地添加任务、已提交状态应保留。
- 后端同步失败不应在首屏暴露技术化失败卡，应回落到可操作的本地空态或默认状态。

### 智能体主页

- 顶部只有自动语音和新会话入口；正文区域包含历史消息、当前回复、顶部 fade、最新消息按钮。
- 底部输入区包含图片入口、文本输入、语音入口和发送按钮；没有注入真实图片/语音 provider 时，相应按钮保持不可用。
- 输入草稿、图片附件和可见历史窗口在站内切换后保留。
- 从其它模块进入智能体主页时，底栏智能体头像要重播 wake 动效。
- Assistant 当前回复时使用 thinking 动效；自动语音播放时使用 speaking 动效；无动画或 reduced motion 时要有静态头像兜底。
- 发送 follow-up 不能丢失上一轮 assistant 回复；active run 时发送/停止/取消状态要和旧 Web 一致。
- 状态条只展示用户可理解的处理状态，不暴露底层 tool progress 内部细节。
- Agent Hub 的对话流和语音状态属于页面外运行时；切走页面不能静默取消 stream 或语音。

## Flutter 测试矩阵

| 模块 | 测试文件 | 覆盖范围 |
| --- | --- | --- |
| 宝宝和我 | `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` | care stage、妈妈/宝宝 tab、模块卡、趋势图周/月、详情按钮、宝宝成长交互、跨 tab 状态保留、旧首屏残留移除。 |
| 计划 | `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` | 日期切换、提醒确认、Agent 建议卡、任务 toolbar、checkbox、编辑、调整日程、添加任务、空态快捷入口、跨 tab 状态保留。 |
| 智能体主页 | `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` | shell nav、顶部控制、transcript、fade、composer、草稿保留、底栏 wake 动效、历史窗口、图片附件、最新按钮。 |
| 智能体运行时 | `flutter_app/test/widget_test.dart` | Agent Hub lazy keep-alive、切 tab 后 stream/voice 保活、focused route 底栏隐藏规则、artifact route action。 |
| 智能体深状态 | `flutter_app/test/features/agent_hub/agent_hub_page_test.dart` | 发送、线程复用、断线重试、图片/语音输入、自动语音、通知语音优先级、取消、action confirmation、markdown、状态条。 |
| Golden | `flutter_app/test/features/app_pages/*golden_test.dart` 和 `flutter_app/test/features/agent_hub/*golden_test.dart` | 三个移动 viewport 下的页面级、组件级和深状态视觉基线。 |

## 准入命令

```bash
cd MomCozyApp/flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter analyze
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test test/features/agent_hub
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test
```

## 后续扩展原则

- 新增或调整任何三大入口交互时，先在 parity 测试里补旧 Web 契约，再改 Flutter 实现。
- 若旧 Web 行为已经被产品明确废弃，必须在测试名或注释里说明“旧残留已移除”，避免后续误恢复。
- Golden 只用于确认视觉结果；复杂交互必须用 widget test 断言状态变化、按钮可用性、路由跳转和数据保留。
- 与真机相关的 BLE、系统通知、麦克风权限和后台语音只登记为 device-lab 用例，不阻塞非真机准入。
