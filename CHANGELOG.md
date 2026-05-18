# 更新日志 (Changelog)

> 对比版本：**当前版本 (2026-03-16)** vs **v1.0alpha_FZD_20260310 (2026-03-10 10:43)**
>
> 本文档记录自 3 月 10 日基线版本以来的全量改动项。

---

## v1.0-alpha-20260316 — 全量变更清单

---

### 🏠 Agent Hub 主页 (`src/pages/AgentHub.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **实时速记板书 (Scratchpad)** | 头像右侧新增 glass-panel 速记卡片，实时显示对话主题、步骤摘要，右侧竖排 topic link pills（最多 3 个），底部集成 CalibrationStatus 状态条 |
| 2 | **Mai 头像情绪拨盘** | 头像外圈添加 `conic-gradient` 渐变环，支持点击循环切换 5 种情绪（happy/encourage/calm/thinking/alert），底角叠加语音自动播放开关 badge |
| 3 | **内联工作流系统** | 支持在对话流中直接渲染持久化多步流程：`InlineDeviceFlow`（设备指导）、`InlineScheduleFlow`（日程规划）、`InlineLactationFlow`（泌乳管理）、`InlineCalibration`（力度标定），通过 `forwardRef` + `handleExternalInput` 拦截主输入框 |
| 4 | **chatBus + chatStore 架构** | 引入全局消息总线 (`src/lib/chatBus.ts`) 和持久化存储 (`src/lib/chatStore.ts`)，支持跨页面（如吸乳结束后）向 Hub 推送富文本报告卡片 |
| 5 | **对话流折叠/展开** | 历史消息区支持一键折叠，减少信息密度，仅展示最新几条 |
| 6 | **Scene 场景路由** | 四大场景按钮（设备指导/日程规划/追奶减奶/围产期方案）点击后在对话流中直接推送对应上下文的 inline flow 卡片 |
| 7 | **Pills 两行布局** | 操作药丸从单行横向滚动改为两行固定布局：第一行主操作（开始吸乳/力度滴定）`flex-1` 等宽；第二行场景 pills `flex-1` 等宽，390px 视口下完整可见 |
| 8 | **吸乳后报告自动推送** | 从 PumpSession 结束后通过 chatBus 自动 push 含统计数据（总奶量/时长/左右比/奶阵次数）的报告卡片 + 鼓励卡片 |
| 9 | **FocusVoiceMode 入口** | 输入栏集成专注语音模式按钮，点击全屏推入沉浸式语音交互界面 |
| 10 | **拍照识别入口** | 输入栏支持拍照/上传菜单，可触发配件识别 demo 流程 |

---

### 🍼 沉浸吸乳 (`src/pages/PumpSession.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **拟真双乳可视化** | 新增 `BreastDrop` 组件：SVG 绘制左右乳房图形，流速控制滴落动画频率，排空度影响填充色透明度，奶阵时颜色切换为 orange |
| 2 | **螺旋泵环动画** | `PumpRing` 组件：根据档位均值控制旋转速度，深度/刺激模式切换渐变色，运行时缩放呼吸效果 |
| 3 | **流体管道** | `FlowPipes` 组件：SVG 绘制双分支银河管道，流速正相关于管道粗细和动画速度 |
| 4 | **奶瓶可视化** | `Bottle` 组件：液面高度映射 pct，奶阵时液面颜色变暖，点击切换 mL/oz 单位显示 |
| 5 | **双轨实时流速图** | 使用 Recharts `AreaChart` 分别绘制左右侧流速曲线，支持分段渐变（奶阵区间高亮） |
| 6 | **M.ai 智能陪伴** | 集成 `MaiSessionBubbles`：刺激模式显示鼓励文案，深度模式推送知识卡片，支持点击暂停检查设备 |
| 7 | **目标量/延长机制** | `MilkProgressBar` 显示实时进度，达标后弹 confetti 动画；超额后进入"延长模式"倒计时，Mai 建议是否继续 |
| 8 | **M.ai 目标解释** | `MaiTargetExplainSheet`：半屏浮窗以流式对话形式解释目标量计算依据，支持一键应用建议目标 |
| 9 | **音乐播放器** | `MusicPlayer`：3 个播放列表切换，波形可视化随模式变化（奶阵/低流/标准），播放列表 pill 选择 |
| 10 | **M.ai 托管模式** | 底部 Sheet 支持"交给 M.ai"一键托管，锁定模式/档位控制，仅保留暂停/停止 |
| 11 | **退出确认** | 运行中点击返回弹出居中确认对话框（z-[71]），防止误退出 |
| 12 | **会话报告生成** | 结束时自动组装含曲线描述、L/R 分布、奶阵统计的 ChatMessage，通过 chatBus + chatStore 推送至 Hub |
| 13 | **全局单位同步** | 集成 `useVolumeUnit` hook，奶瓶和进度条统一响应 mL/oz 切换 |
| 14 | **奶瓶图层层级修复** | 中央可视区域 z-index 从 `z-20` 降至 `z-[5]`，确保 M.ai 泡泡 (`z-[200]`) 始终浮于上方 |

---

### 📊 妈妈点滴 (`src/pages/Records.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **今日总览三指标** | 今日总奶量 / 吸奶次数 / 7日均奶量，增删记录后实时联动更新 |
| 2 | **7日趋势面积图** | Recharts 平滑面积图，带 Mai 情绪化批注 |
| 3 | **来源徽标 Badge** | 每条记录标注数据来源：📱设备 / ✍️手动 / ✨Mai记 |
| 4 | **手动记录** | `ManualEntryDialog`：支持新增/编辑模式，mL/oz 自适应 |
| 5 | **库存补录** | `InventoryEntryDialog`：支持"补录"和"瓶喂扣除"两种类型，mL/oz 同步 |
| 6 | **确认对话框** | `ConfirmDialog`：删除/编辑二次确认，防误操作 |
| 7 | **Agent 问答浮窗** | `RecordAgentDrawer`：半屏毛玻璃浮窗，支持"帮我补记"、"分析本周"等快捷指令，直接操作页面 State |
| 8 | **全局 mL/oz 切换** | 集成 `useVolumeUnit`，所有数值显示同步响应单位切换 |

---

### 👶 宝宝陪伴 (`src/pages/BabyGrowth.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **生长指标折叠卷轴** | 默认收起仅显示标题 + 摘要数值（体重/身长/头围），展开后显示编辑指标 + 体重曲线，framer-motion 动画推开 |
| 2 | **摘要数值可读性** | 折叠状态数值 `text-[11px] font-bold`，带标签（体重/身长/头围），附"编辑↓"提示 |
| 3 | **标题防换行** | 标题缩小至 `text-[10px]`，ChevronDown 缩至 `w-3.5 h-3.5`，数值区 `flex-1 justify-end` |
| 4 | **百分位标尺编辑** | 三指标可点击 Pencil 图标进入行内编辑，P25-P75 色带 + 圆形指示器可视化当前位置 |
| 5 | **WHO 体重曲线** | 以周为单位的 ComposedChart，P25-P75 带状参考区域 + 虚线边界 + 实际体重实线 |
| 6 | **Growth Chat** | `GrowthChatDrawer`：问 M.ai 入口，支持记录指标、体重解释、喂养建议等交互 pills |
| 7 | **今日喂养平衡卡片** | 双列布局：左"今日可用乳源"（= 妈妈可用母乳库存 + 配方奶）/ 右"宝宝需求估计"（基于体重的 P25-P50-P75 计算） |
| 8 | **可用乳源自动同步** | 从妈妈点滴页的设备泵奶 + 手动补录自动汇总，配方奶从喂养记录汇总 |
| 9 | **宝宝需求术语优化** | P25/P75 替换为用户友好的「少量」「充足」胶囊标签 |
| 10 | **乳源充足暖色反馈** | 当可用乳源 ≥ P50 需求时，数值变为 `text-mai-warm` 暖色 |
| 11 | **智能通知 Banner** | 根据供需比自动生成 Mai 提醒 banner（不足/偏少/充足/过剩），点击跳转 Hub 触发泌乳评估流程 |
| 12 | **喂养记录列表** | 支持添加配方奶/亲喂/瓶喂母乳，来源 badge，配方奶行特殊暖色高亮 |
| 13 | **追奶计划联动** | 通过 `ChaseMilkDrawer` 一键生成追奶排程，写入 localStorage 联动日程页 |
| 14 | **喂养平衡卡片对齐** | 左右列 `flex flex-col` + `mt-auto` 对齐底部子卡片 |
| 15 | **InfoTip 自动消失** | `?` 提示浮窗 2 秒后自动关闭，使用 fixed 定位避免溢出 |

---

### 📅 日程计划 (`src/pages/Schedule.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **Milky.Way 泌乳周期** | 4 节点横向地图（初乳→建立→稳产→离乳），高亮当前阶段 |
| 2 | **泌乳目标卡** | 显示当前目标（追奶/维持/减奶），支持通过 `LactationGoalSheet` 修改 |
| 3 | **垂直时间轴排程** | 今日任务列表，支持完成标记、顺延半小时、来源标注（设备/Mai/手动/追奶） |
| 4 | **冲突屏蔽时段** | `BlockedSlotDialog`：添加避开时段（如会议），红色高亮显示 |
| 5 | **OCR 日程识别** | 上传截图后弹出 `ScheduleAgentDrawer`，Mai 分析冲突并提供重排建议 |
| 6 | **追奶任务注入** | 来自宝宝页/泌乳流程的追奶排程通过 localStorage 事件注入时间轴 |
| 7 | **日结总结** | `DayEndSummary`：当日任务完成度统计 + Mai 鼓励语 |
| 8 | **提醒开关** | 关闭时触发 `ReminderAlert` 强挽留弹窗 |
| 9 | **ScheduleAgentDrawer** | 多上下文（OCR/目标/避让）的半屏 Agent 对话，pill 驱动交互 |

---

### ⚙️ 设备管理 (`src/pages/DeviceManagement.tsx`)

| # | 改动项 | 说明 |
|---|--------|------|
| 1 | **双侧设备卡** | `DeviceCard`：显示 L/R 侧吸奶器型号、电量条、信号强度、连接状态 |
| 2 | **当前佩戴配置** | 法兰尺寸 / 硅胶塞尺寸显示 |
| 3 | **智能说明书** | `SmartManual`：可搜索的知识卡片列表，覆盖清洗、更换、排障等主题 |
| 4 | **知识卡片 Sheet** | `KnowledgeCardSheet`：半屏展示详细指引，分 sections + tips |
| 5 | **配件拍照识别** | `PhotoIdentifyDrawer`：支持拍照/上传/demo 样品选择，动画分析步骤，识别结果展示 |
| 6 | **蓝牙搜索** | `BluetoothSearchDrawer`：模拟设备搜索、连接过程 |
| 7 | **设备详情 Sheet** | `DeviceInfoSheet`：固件版本、序列号、连接历史等详情 |
| 8 | **M.ai Chat** | `MaiChatDrawer`：设备页专属半屏对话，内嵌快捷指令 + 内联 Calibration |

---

### 🔧 内联工作流组件

| 组件 | 文件 | 说明 |
|------|------|------|
| **InlineDeviceFlow** | `src/components/device/InlineDeviceFlow.tsx` | 开箱引导（蓝牙→配件→组装→穿戴→测量→标定）、尺寸测量、配件识别三种流程，forwardRef 拦截输入 |
| **InlineScheduleFlow** | `src/components/schedule/InlineScheduleFlow.tsx` | 日程查看、避让设置、冲突检测、重排确认等多步对话流 |
| **InlineLactationFlow** | `src/components/lactation/InlineLactationFlow.tsx` | 泌乳阶段查看、目标调整、趋势分析、追奶/减奶计划生成，支持从宝宝页评估上下文启动 |
| **InlineCalibration** | `src/components/calibration/InlineCalibration.tsx` | 穿戴检查→左侧测试→右侧测试→结果保存的分步力度滴定流程 |

---

### 🎙️ 语音交互

| 组件 | 文件 | 说明 |
|------|------|------|
| **FocusVoiceMode** | `src/components/voice/FocusVoiceMode.tsx` | 全屏沉浸语音模式：全尺寸 Mai 形象 + 呼吸光晕 + 实时字幕 + 声波涟漪麦克风 + Barge-in 打断 + 随机 idle 动画 |
| **VoiceChatHistory** | `src/components/voice/VoiceChatHistory.tsx` | 语音对话历史记录抽屉 |

---

### 🐑 M.ai 核心组件

| 组件 | 文件 | 说明 |
|------|------|------|
| **MaiAvatar** | `src/components/Mai/MaiAvatar.tsx` | 多情绪表情（happy/encourage/calm/thinking/alert/worry）切换，支持 sm/md/lg 尺寸，呼吸动画 |
| **MaiInputBar** | `src/components/Mai/MaiInputBar.tsx` | 统一输入栏：文字/语音/拍照菜单/demo 识别，支持 main/drawer 两种变体 |
| **FloatingMaiButton** | `src/components/Mai/FloatingMaiButton.tsx` | 各页面右下角悬浮 Mai 头像按钮 |

---

### 🎨 设计系统与全局

| # | 改动项 | 说明 | 文件 |
|---|--------|------|------|
| 1 | **CSS 变量体系** | 完整 HSL 色彩 token：primary/secondary/accent/mai-warm/mai-blush/mai-glow，dark mode 支持 | `src/index.css` |
| 2 | **Mai 专属动画** | `mai-breathe`/`mai-bounce`/`mai-pulse`/`mandala` 等 keyframes + `.mai-anim-*` 工具类 | `src/index.css` |
| 3 | **毛玻璃/毡质工具类** | `.felt-texture`/`.glass-panel`/`.mai-shadow`/`.mai-glow` | `src/index.css` |
| 4 | **全局字体** | Google Fonts: Quicksand + Noto Sans SC | `src/index.css` |
| 5 | **底部导航** | 5 Tab：M.ai / 妈妈 / 宝宝 / 计划 / 设备，自定义 NursingIcon，active 状态 glow | `src/components/layout/BottomNav.tsx` |
| 6 | **AppLayout** | 全局布局框架 + safe area 适配 | `src/components/layout/AppLayout.tsx` |
| 7 | **全局 mL/oz 单位** | `volumeUnitStore` 全局单例 + `useVolumeUnit` hook + `formatVol`/`unitLabel` 工具函数 | `src/lib/volumeUnit.ts` |
| 8 | **消息总线** | `chatBus`：跨页面推送消息的 pub/sub 系统 | `src/lib/chatBus.ts` |
| 9 | **消息持久化** | `chatStore`：内存级消息存储，供 Hub 恢复对话历史 | `src/lib/chatStore.ts` |
| 10 | **Mock 数据** | 设备/配件/知识卡片/AR 识别结果/宝宝生长/吸乳记录完整 mock 数据集 | `src/data/mockData.ts`, `src/data/deviceMockData.ts` |

---

### 🖼️ 素材资源

| 文件 | 说明 |
|------|------|
| `src/assets/mai-*.png` (10张) | Mai 多情绪头像 + 全身像（happy/calm/thinking/alert/worry/encourage/emoji/full/fullbody/fullbody-clean） |
| `src/assets/mock-*.jpg` (3张) | 配件识别 demo 样张（鸭嘴阀/法兰/硅胶塞） |

---

### 🐛 Bug 修复

| # | 问题 | 修复 | 文件 |
|---|------|------|------|
| 1 | 设备指导流程中用户消息重复发送 | `handleTextInput()` 在 unboxStep 4/5/6 先调 `pushUser()` 再调 `handleChoiceAction()`（内部也调 `pushUser()`），移除前者的冗余调用 | `InlineDeviceFlow.tsx` |
| 2 | 沉浸吸乳页奶瓶遮挡对话泡泡 | 中央可视区 z-index 从 `z-20` 降至 `z-[5]` | `PumpSession.tsx` |

---

### 📁 完整涉及文件清单

```
src/pages/
├── AgentHub.tsx              — 主页 Hub 重构
├── BabyGrowth.tsx            — 宝宝陪伴重构
├── PumpSession.tsx           — 沉浸吸乳重构
├── Records.tsx               — 妈妈点滴重构
├── Schedule.tsx              — 日程计划重构
├── DeviceManagement.tsx      — 设备管理重构
├── ComfortCalibration.tsx    — 舒适度测试页
├── Index.tsx                 — 路由入口
└── NotFound.tsx

src/components/
├── Mai/
│   ├── MaiAvatar.tsx         — 多情绪头像
│   ├── MaiInputBar.tsx       — 统一输入栏
│   └── FloatingMaiButton.tsx — 悬浮按钮
├── baby/
│   ├── ChaseMilkDrawer.tsx   — 追奶计划浮窗
│   ├── FeedingEntryDialog.tsx — 喂养记录对话框
│   ├── GrowthChatDrawer.tsx  — 生长问答浮窗
│   └── PercentileGauge.tsx   — 百分位标尺
├── calibration/
│   └── InlineCalibration.tsx — 内联力度滴定
├── device/
│   ├── BluetoothSearchDrawer.tsx — 蓝牙搜索
│   ├── DeviceInfoSheet.tsx   — 设备详情
│   ├── InlineDeviceFlow.tsx  — 内联设备流程
│   ├── KnowledgeCardSheet.tsx — 知识卡片
│   └── MaiChatDrawer.tsx     — 设备问答浮窗
├── lactation/
│   └── InlineLactationFlow.tsx — 内联泌乳流程
├── layout/
│   ├── AppLayout.tsx         — 全局布局
│   └── BottomNav.tsx         — 底部导航
├── pump/
│   ├── MaiSessionBubbles.tsx — 吸乳中 Mai 泡泡
│   ├── MaiTargetExplainSheet.tsx — 目标解释
│   ├── MilkProgressBar.tsx   — 进度条
│   └── MusicPlayer.tsx       — 音乐播放器
├── records/
│   ├── ConfirmDialog.tsx     — 确认对话框
│   ├── InventoryEntryDialog.tsx — 库存补录
│   ├── ManualEntryDialog.tsx — 手动记录
│   └── RecordAgentDrawer.tsx — 数据问答浮窗
├── schedule/
│   ├── BlockedSlotDialog.tsx — 屏蔽时段
│   ├── DayEndSummary.tsx     — 日结总结
│   ├── InlineScheduleFlow.tsx — 内联排程流程
│   ├── LactationGoalSheet.tsx — 泌乳目标
│   ├── ReminderAlert.tsx     — 提醒开关挽留
│   └── ScheduleAgentDrawer.tsx — 排程问答浮窗
└── voice/
    ├── FocusVoiceMode.tsx    — 全屏语音模式
    └── VoiceChatHistory.tsx  — 语音历史

src/lib/
├── chatBus.ts                — 消息总线
├── chatStore.ts              — 消息持久化
├── volumeUnit.ts             — 全局单位系统
└── utils.ts

src/data/
├── mockData.ts               — 核心 Mock 数据
└── deviceMockData.ts         — 设备/配件 Mock 数据

src/index.css                 — 设计系统 tokens + 动画
tailwind.config.ts            — Tailwind 扩展配置
```

---

## v1.0-alpha-20260310 (基线版本)

> `mai.agenticapp_v1.0alpha_FZD_20260310` — 2026-03-10 10:43
>
> 首个完整功能基线版本，包含核心架构搭建和各模块初版实现。
