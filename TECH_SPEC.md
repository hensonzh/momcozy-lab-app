# 原型功能开发及技术规范说明

> **版本**：mai.agenticapp_v1.1alpha_FZD_20260316  
> **技术栈**：React 18 + TypeScript + Vite + Tailwind CSS + Framer Motion + Recharts  
> **目标设备**：移动端 Web（基准视口 390×844 CSS px）

---

## 1. 全局架构与路由地图

### 1.1 路由表

| 路径 | 页面组件 | 底部导航 Tab | 说明 |
|------|----------|-------------|------|
| `/` | `AgentHub` | M.ai | 对话即中枢主页，所有 inline 工作流宿主 |
| `/records` | `Records` | 妈妈 | 妈妈点滴（吸乳记录 + 库存管理） |
| `/baby` | `BabyGrowth` | 宝宝 | 宝宝陪伴（生长追踪 + 喂养平衡） |
| `/schedule` | `Schedule` | 计划 | 日程规划（任务时间轴 + 冲突管理） |
| `/device` | `DeviceManagement` | 设备 | 设备管理（BT 状态 + 配件识别 + 说明书） |
| `/pump` | `PumpSession` | *(隐藏导航)* | 沉浸式吸乳全屏界面 |
| `/calibration` | `ComfortCalibration` | *(隐藏导航)* | 独立力度滴定页（备用入口） |

### 1.2 全局布局

```
AppLayout
├── SafeAreaTopBanner        // --top-safe CSS 变量控制，primary 色填充
├── <main>
│   ├── {children}           // Route 渲染区
│   └── VersionFooter        // "mai.agenticapp_v1.1alpha_FZD_20260316"
└── BottomNav                // 5-tab，pathname === "/pump" 时隐藏
```

### 1.3 全局状态管理

**无 React Context / Redux**。当前使用三个轻量级模块级单例：

| 模块 | 文件 | 机制 | 用途 |
|------|------|------|------|
| `chatStore` | `src/lib/chatStore.ts` | 内存对象 + getter/setter | Hub 消息列表、Mai 情绪、速记板内容的跨组件共享 |
| `chatBus` | `src/lib/chatBus.ts` | pub/sub + pending queue | 跨页面（如 PumpSession → AgentHub）推送 ChatMessage |
| `volumeUnitStore` | `src/lib/volumeUnit.ts` | localStorage + pub/sub | 全局 mL ↔ oz 单位同步 |

**跨页面数据流向图：**

```
PumpSession ──(chatBus.push)──→ AgentHub (subscribe → append to messages)
BabyGrowth  ──(chatBus.push)──→ AgentHub (navigate("/") 后消费)
BabyGrowth  ──(localStorage "chaseMilkTasks")──→ Schedule (window event 监听)
BabyGrowth  ──(CustomEvent "inventoryRecordAdded")──→ Records (window event 监听)
volumeUnitStore ──(subscribe)──→ Records, PumpSession, BabyGrowth (useVolumeUnit hook)
calibration result ──(localStorage "calibration")──→ AgentHub (CalibrationStatus 读取)
```

### 1.4 导航跳转逻辑

| 触发 | 起点 | 目标 | 方式 |
|------|------|------|------|
| 点击"开始吸乳" pill → 对话卡片中"准备好了" | AgentHub | `/pump` | `navigate("/pump")` |
| 点击 ■ 结束吸乳 | PumpSession | `/` | `navigate("/")` + chatBus push 报告 |
| 智能通知 banner 点击 | BabyGrowth | `/` | `navigate("/")` + chatBus push 评估上下文 |
| 配件识别 → "带着结果去找 Mai 聊聊" | DeviceManagement | `/` | `navigate("/")` + chatBus push 教程卡片 |
| 力度滴定完成 → "去吸乳" | ComfortCalibration / InlineCalibration | `/pump` | `navigate("/pump")` |

---

## 2. 核心数据模型

### 2.1 PumpRecord（吸乳/库存/喂养记录）

```typescript
interface PumpRecord {
  id: string;                                          // UUID
  date: string;                                        // "YYYY-MM-DD"
  time: string;                                        // "HH:mm"
  durationMin: number;                                 // 吸乳时长（分钟），亲喂时为喂奶时长，手动补录为 0
  leftMl: number;                                      // 左侧奶量 mL
  rightMl: number;                                     // 右侧奶量 mL
  totalMl: number;                                     // 总奶量 mL（leftMl + rightMl）
  source: "device" | "manual" | "voice";               // 数据来源
  mode: "stimulate" | "deep";                          // 吸乳模式
  subLabel?: "补录" | "亲喂" | "配方奶" | "瓶喂";       // 记录子类型
  category?: "inventory" | "feeding";                  // 记录分类：供给(inventory) or 消费(feeding)
}
```

**分类规则（前端推导）：**

| category | 判定条件 | 页面归属 |
|----------|----------|----------|
| `inventory` | `source === "device"` 或 `subLabel === "补录"` | 妈妈点滴 |
| `feeding` | `subLabel ∈ {"亲喂", "瓶喂", "配方奶"}` | 宝宝陪伴 |

### 2.2 BabyData（宝宝生长数据）

```typescript
interface BabyData {
  name: string;                    // "小豆豆"
  birthDate: string;               // "2025-12-15"
  ageWeeks: number;                // 12
  records: GrowthRecord[];
}

interface GrowthRecord {
  date: string;                    // "YYYY-MM-DD"
  weightKg: number;                // 体重 kg
  heightCm: number;                // 身长 cm
  headCm: number;                  // 头围 cm
}
```

### 2.3 ScheduleTask（日程任务）

```typescript
interface ScheduleTask {
  id: string;
  time: string;                                // "HH:mm"
  type: "pump" | "feed" | "meeting";
  title: string;
  done: boolean;
  adjusted?: string;                           // 调整原因（如"因会议顺延"）
  source?: "mai" | "manual" | "device";        // 任务来源
  reason?: string;                             // 业务原因（如"追奶"、"减奶"）
}

interface BlockedSlot {
  id: string;
  title: string;
  start: string;                               // "HH:mm"
  end: string;                                 // "HH:mm"
  source: "meeting" | "agent" | "manual";
}
```

### 2.4 DeviceInfo（设备信息）

```typescript
interface DeviceInfo {
  id: string;
  side: "L" | "R";
  connected: boolean;
  battery: number;                             // 0-100
  flangeSize: number;                          // mm (21/24/27/30)
  sealSize: string;                            // "S"/"M"/"L"
  model: string;                               // "Momcozy M.ai Pro"
  firmware: string;                            // "v2.1.4"
  serialNumber: string;
}
```

### 2.5 ChatMessage（对话消息）

```typescript
interface ChatMessage {
  id: string;
  role: "mai" | "user";
  content: string;                             // Markdown 格式文本
  timestamp: string;                           // "HH:mm" 或 ISO string
  cardType?: CardType;                         // 富卡片类型
  cardData?: Record<string, unknown>;          // 卡片附加数据（流程参数、报告数据等）
  links?: ChatMessageLink[];                   // 可点击的操作链接
}

type CardType =
  | "report"          // 吸乳报告卡片
  | "data"            // 数据展示卡片
  | "tutorial"        // 教程/指南卡片
  | "plan"            // 计划/方案卡片
  | "encourage"       // 鼓励/情感卡片
  | "calibration"     // 力度标定内联流程
  | "device-flow"     // 设备指导内联流程
  | "schedule-flow"   // 日程规划内联流程
  | "lactation-flow"; // 泌乳管理内联流程

interface ChatMessageLink {
  label: string;
  route?: string;                              // 页面路由跳转
  action?: string;                             // 流程动作触发
}
```

### 2.6 KnowledgeCardData（知识卡片）

```typescript
interface KnowledgeCardData {
  title: string;
  icon: string;                                // emoji
  sections: { heading: string; content: string }[];
  tip?: string;
}
```

### 2.7 PhotoIdentifyResult（配件识别结果）

```typescript
interface PhotoIdentifyResult {
  partName: string;                            // "鸭嘴阀"
  partIcon: string;                            // "🦆"
  description: string;
  suggestion: string;
  knowledgeKey: string;                        // → knowledgeCards[key]
  chatCardContent: string;                     // 推送到 Hub 的 Markdown 内容
  confidence: number;                          // 0-100（内部使用，不展示）
  mockImage: string;                           // 图片映射 key
  specInfo: string;
}
```

### 2.8 CalibrationResult（力度标定结果）

```typescript
interface CalibrationResult {
  mode: "stimulate" | "deep";
  feedbacks: { pillKey: string; gear: number }[];
  maxSafeGear: number;                         // 安全上限档位
  minEffectiveGear: number;                    // 最低有效档位
  cozyGear: number;                            // 推荐舒适档位
}
```

**持久化**：`localStorage.setItem("calibration", JSON.stringify({ stimulate: CalibrationResult, deep: CalibrationResult }))`

### 2.9 VolumeUnit（全局单位）

```typescript
type VolumeUnit = "mL" | "oz";
// 存储: localStorage "volume-unit"
// 换算: 1 mL = 0.033814 oz
```

---

## 3. 模块功能详细说明

---

### 3.1 Agent Hub（主页 `/`）

**文件**：`src/pages/AgentHub.tsx`（758 行）

#### UI 结构

```
AgentHub
├── TopHub (flex-shrink-0)
│   ├── MaiAvatar (w-16, conic-gradient ring, emotion cycle onClick)
│   │   └── VoiceToggle badge (bottom-right)
│   └── ScratchpadCard (glass-panel)
│       ├── RealtimeNote (topic + summary)
│       ├── TopicLinkPills (max 3, vertical stack)
│       └── CalibrationStatus
├── ChatMessages (flex-1, overflow-y-auto)
│   ├── TopFade + BottomFade (gradient overlays)
│   ├── CollapseToggle
│   └── MessageList
│       ├── TextBubble (mai / user)
│       ├── CardBubble (report / encourage / plan / tutorial)
│       ├── InlineDeviceFlow (cardType: "device-flow")
│       ├── InlineScheduleFlow (cardType: "schedule-flow")
│       ├── InlineLactationFlow (cardType: "lactation-flow")
│       └── InlineCalibration (cardType: "calibration")
├── PillsBar (flex-shrink-0, 2 rows)
│   ├── Row1: [🍼 开始吸乳] [🎛️ 力度滴定] (flex-1 each)
│   └── Row2: [设备指导] [日程规划] [追奶/减奶] [围产期方案] (flex-1 each)
├── MaiInputBar
└── FocusVoiceMode (full-screen overlay, conditional)
```

#### 触发器与交互逻辑

| 用户行为 | 系统响应 |
|----------|----------|
| 点击 Mai 头像 | 循环切换 emotion：happy → encourage → calm → thinking → alert |
| 点击语音开关 badge | `autoVoice` toggle |
| 点击 topic link pill | 根据 `action` 字段路由：`open-unbox` → 注入 device-flow 卡片；`schedule-*` → 注入 schedule-flow；`lactation-*` → 注入 lactation-flow；有 `route` → navigate |
| 点击"🍼 开始吸乳" | Push encourage 卡片 + "准备好了，启动~" link（→ `/pump`） |
| 点击"🎛️ 力度滴定" | Push calibration 卡片 → 渲染 InlineCalibration |
| 点击场景 pill | `handleSceneClick(key)` → push 对应 `sceneResponses[key]` 卡片，含 action links |
| 点击 action link | 根据 action 前缀分发到对应 inline flow |
| 文字输入 Send | 若存在 active flow（deviceFlowRef / scheduleFlowRef / lactationFlowRef），先尝试 `handleExternalInput(text)`；若未消费，fallback 到通用 Mai echo |
| 拍照/上传 | MaiInputBar 触发 `onPhotoFile` / `onDemoIdentify`，注入识别流程 |
| 点击"专注模式" | 打开 FocusVoiceMode 全屏覆盖 |
| chatBus 消息到达 | subscribe 回调 append 到 messages，自动滚动到底部 |

#### 数据流

- **Input**：`chatStore.get()` 恢复初始消息/情绪/速记、`localStorage("calibration")` 读取标定状态
- **Output**：`chatStore.setMessages()` 持久化消息、`chatStore.setEmotion()` 持久化情绪

#### 内联工作流路由表

| cardType | 组件 | ref 变量 | 输入拦截 |
|----------|------|---------|---------|
| `device-flow` | `InlineDeviceFlow` | `deviceFlowRef` | `handleExternalInput(text): boolean` |
| `schedule-flow` | `InlineScheduleFlow` | `scheduleFlowRef` | `handleExternalInput(text): boolean` |
| `lactation-flow` | `InlineLactationFlow` | `lactationFlowRef` | `handleExternalInput(text): boolean` |
| `calibration` | `InlineCalibration` | *(none)* | 自包含，不拦截输入 |

---

### 3.2 沉浸式吸乳（`/pump`）

**文件**：`src/pages/PumpSession.tsx`（1370 行）

#### UI 结构

```
PumpSession (fixed full-screen, BottomNav hidden)
├── Header (时间 + 状态 + 返回)
├── FlowCharts (2x AreaChart: L/R 流速曲线)
│   └── 分段渐变（奶阵区间 orange，正常 primary）
├── MilkProgressBar (merged / per-side toggle)
├── MusicPlayer
├── CentralVisual (z-[5])
│   ├── BreastDrop × 2 (SVG, flow-driven animation)
│   ├── PumpRing (旋转环，gear-driven)
│   ├── FlowPipes (SVG 双分支管道)
│   └── Bottle (液面 + 单位切换)
├── ControlCard (bg-card/70, backdrop-blur)
│   ├── MaiAvatar + MaiSessionBubbles (z-[200])
│   ├── SideSelector: [L] [SYNC] [R]
│   ├── ModeSelector: [刺激] [深度]
│   ├── GearSlider: 1-9 档
│   ├── [暂停] [停止]
│   └── [M.ai 托管] toggle
├── MaiTargetExplainSheet (半屏)
├── MaiChatDrawer (半屏)
└── ExitConfirmOverlay (z-[71])
```

#### 核心状态机

```typescript
type PumpMode = "stimulate" | "deep";
type ActiveSide = "L" | "R" | "SYNC";
type MockFlow = "off" | "high" | "low";

// 关键状态
running: boolean          // 吸乳是否运行中
paused: boolean           // 暂停状态
mode: PumpMode            // 当前模式
activeSide: ActiveSide    // 控制侧
gearL / gearR: number     // 左右档位 1-9
left.flow / right.flow    // 实时流速（模拟计算）
totalL / totalR           // 累计奶量 mL
isLetdown / letdownL / letdownR  // 奶阵检测
bottlePct: number         // 奶瓶填充百分比
elapsed: number           // 已运行秒数
```

#### 模拟流速算法

```typescript
computeFlow(prev: SideState, mock: MockFlow, tick: number, off: number): number
// mock === "high" → 基于 sin 波的高流速 + 随机抖动
// mock === "low"  → 衰减低流速
// mock === "off"  → 递减归零
// 奶阵检测: flow > highThreshold(3.0) → letdown = true
// 低流检测: flow < lowThreshold(0.8) → 自动切换 deep 模式
```

#### 触发器

| 行为 | 响应 |
|------|------|
| 点击 MockFlow 按钮 | 切换 `mockFlow` 为 "high"/"low"/"off" |
| 流速 > 3.0 持续 | `letdownL/R = true`，模式自动切 deep，BreastDrop 颜色变 orange |
| 流速 < 0.8 且为 stimulate | 10s 后自动切换 deep |
| 达到目标量 | confetti 动画 + MilkProgressBar 庆祝态 |
| 超过目标量 | 进入延长模式，MaiSessionBubble 提醒"是否继续" |
| 点击停止 | 弹出 ExitConfirmOverlay；确认 → `handleStopPump()` → 生成报告 → navigate("/") |
| M.ai 托管 | 锁定 mode/gear 控制面板，仅保留暂停/停止 |

#### 报告推送 payload

```typescript
// handleStopPump → pushSessionSummary()
const reportMsg: ChatMessage = {
  cardType: "report",
  cardData: {
    duration: elapsed,
    durationStr: "MM:SS",
    leftMl: totalL,
    rightMl: totalR,
    totalMl: total,
    pct: Math.round(bottlePct),
    hadLetdown: isLetdown,
    letdownL, letdownR,
  },
};
// → chatBus.push(reportMsg) + chatStore.setMessages(...)
```

---

### 3.3 妈妈点滴（`/records`）

**文件**：`src/pages/Records.tsx`（513 行）

#### UI 结构

```
Records
├── Header ("妈妈点滴" + 月份切换)
├── TodaySummary (3 指标卡片)
│   ├── 今日总奶量 (device + manual pump milk)
│   ├── 吸奶次数
│   └── 7日均奶量
├── 7DayTrendChart (AreaChart + Mai 批注)
├── RecordsList
│   ├── SectionHeader ("今日记录" + "补录" button)
│   └── SwipeRow × N (左滑编辑/删除)
│       ├── SourceBadge (📱设备 / ✍️手动 / ✨Mai记)
│       ├── MilkTypeBadge (🤱母乳 / 🧪配方奶)
│       ├── Volume display (mL/oz)
│       └── Duration + Time
├── ManualEntryDialog (补录背奶量)
├── InventoryEntryDialog (库存补录 + 瓶喂扣除)
├── ConfirmDialog (删除/编辑确认)
├── RecordAgentDrawer (半屏 M.ai 问答)
└── FloatingMaiButton
```

#### 数据流

- **Input**：`pumpRecords`（mock 数据）+ `inventoryRecordAdded` 事件（来自 BabyGrowth）
- **Output**：修改本地 `records` state（增删改）→ 三指标实时联动
- **单位**：所有 mL 值通过 `formatVol(ml, unit)` 动态显示

#### 边界处理

| 场景 | 处理 |
|------|------|
| 无今日记录 | 空态提示"暂无记录" |
| 左滑操作 | `PanInfo.offset.x < -80` 触发 delete icon 显示 |
| 设备记录 | 不可手动删除/编辑 (`canModify = source !== "device"`) |

---

### 3.4 宝宝陪伴（`/baby`）

**文件**：`src/pages/BabyGrowth.tsx`（680 行）

#### UI 结构

```
BabyGrowth
├── Header ("宝宝陪伴" + 出生天数 badge)
├── GrowthMetrics (折叠卷轴)
│   ├── CollapsedHeader (体重/身长/头围摘要 + "编辑↓")
│   └── ExpandedContent (AnimatePresence)
│       ├── MetricGrid (3-col: 体重/身长/头围)
│       │   └── PercentileBar (P25-P75 色带 + 指示器 + inline 编辑)
│       └── WeightCurve (ComposedChart: P25-P75 band + actual line)
│           └── "问问 M.ai →" → GrowthChatDrawer
├── SmartNotificationBanner (供需比驱动)
├── FeedingBalanceCard
│   ├── AvailableMilkColumn (可用母乳 + 配方奶)
│   │   └── 乳源 ≥ P50 → text-mai-warm
│   ├── BabyDemandColumn (P50 需求 + 少量~充足范围)
│   └── SubCards (瓶喂量 / 亲喂次数)
├── FeedingRecords (配方奶/亲喂/瓶喂列表 + "添加")
├── FeedingEntryDialog
├── GrowthChatDrawer
├── ChaseMilkDrawer
└── FloatingMaiButton
```

#### 核心计算公式

```typescript
// 宝宝每日需求估算（基于体重）
feedP50 = Math.round(babyWeight * 150);   // mL/天（中位）
feedP25 = Math.round(babyWeight * 120);   // mL/天（少量）
feedP75 = Math.round(babyWeight * 180);   // mL/天（充足）

// 今日可用乳源
breastMilkInventory = deviceMilkTotal + manualSupplementTotal;  // 来自妈妈页
totalAvailable = breastMilkInventory + formulaTotal;            // + 配方奶

// 供需比 → 通知 banner 触发
supplyRatio = totalAvailable / feedP50;
// < 0.7 → "偏少" (assess)
// < 0.9 → "差一点" (encourage)
// > 1.2 → "充足" (happy)
// > 1.5 → "很棒" (happy)
```

#### 跨模块写入

| 操作 | 目标 | 机制 |
|------|------|------|
| 追奶计划确认 | Schedule 页 | `localStorage.setItem("chaseMilkTasks", JSON.stringify([...]))` + `window.dispatchEvent(new Event("chaseMilkUpdated"))` |
| 补录库存 | Records 页 | `window.dispatchEvent(new CustomEvent("inventoryRecordAdded", { detail: record }))` |
| 智能评估 | AgentHub | `chatBus.push(...)` + `navigate("/")` |

---

### 3.5 日程计划（`/schedule`）

**文件**：`src/pages/Schedule.tsx`（454 行）

#### UI 结构

```
Schedule
├── Header ("日程规划" + ReminderToggle)
├── MilkyWayPhaseMap (4 节点: 初乳→建立→稳产→离乳)
├── LactationGoalCard (当前目标 + "调整 →")
├── TaskTimeline (垂直时间轴)
│   ├── BlockedSlot (红色条，⛔ 标记)
│   ├── TaskRow × N
│   │   ├── TimeBadge + TypeIcon + Title
│   │   ├── DoneBadge / AdjustedBadge / SourceBadge
│   │   └── [顺延30min] / [完成✓] / [删除]
│   └── AddTaskButton
├── ActionButtons (添加避让时段 / 截图识别 / 日结报告)
├── BlockedSlotDialog
├── ScheduleAgentDrawer (OCR/goal/avoidance 三种 context)
├── LactationGoalSheet
├── ReminderAlert (关闭提醒强挽留)
├── DayEndSummary (完成度 + 勋章动画)
└── FloatingMaiButton
```

#### 冲突检测逻辑

```typescript
// 添加 blocked slot 后自动调整冲突任务
if (timeInRange(task.time, slot.start, slot.end)) {
  task.time = slot.end;  // 顺延到屏蔽结束
  task.adjusted = `因「${slot.title}」顺延`;
}
```

---

### 3.6 设备管理（`/device`）

**文件**：`src/pages/DeviceManagement.tsx`（735 行）

#### UI 结构

```
DeviceManagement
├── Header ("智能设备")
├── DeviceCard × 2 (L/R 侧)
│   ├── BatteryBar + SignalIndicator
│   └── onClick → DeviceInfoSheet / BluetoothSearchDrawer
├── CurrentConfig (法兰尺寸 + 硅胶塞)
├── SmartManual (可搜索知识卡片列表)
│   └── CardClick → KnowledgeCardSheet
├── PhotoIdentifyCTA ("📷 AI 识别配件")
├── PhotoIdentifyDrawer
│   ├── Camera / Upload / Demo 样品
│   ├── AnimatedAnalysisSteps
│   └── ResultCard + Actions (查看知识 / 带去 Hub)
├── KnowledgeCardSheet
├── MaiChatDrawer (设备专属半屏对话)
├── DeviceInfoSheet
├── BluetoothSearchDrawer
└── FloatingMaiButton
```

---

### 3.7 InlineDeviceFlow（设备指导内联流程）

**文件**：`src/components/device/InlineDeviceFlow.tsx`（752 行）

#### 流程状态机

```
flowType: "unbox"
├── Step 0:   初始化 → 检测已知 BT 设备 → 确认/重新搜索/手动输入/拍照
├── Step 1.5: 拍照识别模式
├── Step 1.6: 手动输入型号
├── Step 2:   设备确认 → DeviceCard 渲染 → 选择引导方式（逐步/文档）
├── Step 3:   蓝牙连接确认
├── Step 3.5: BT 确认完毕 → 继续
├── Step 4:   配件认识（可拍照识别）
├── Step 4.5: 配件拍照识别中
├── Step 5:   组装指引
├── Step 6:   穿戴指引
├── Step 7:   尺寸测量（内嵌 measurement 流程）
├── Step 8:   耐受度测试提问
└── Complete:  InlineCalibration 渲染 或 结束

flowType: "measurement"
├── Step-by-step interactive (measurementSteps[0..4])
└── Complete → 可选启动 InlineCalibration

flowType: "photo-identify"
├── 拍照/上传/Demo → 识别结果 → 知识卡片/再拍
```

#### forwardRef 输入拦截

```typescript
useImperativeHandle(ref, () => ({
  handleExternalInput: (text: string) => handleTextInput(text),
}));
// 返回 true = 已消费（阻止 Hub 默认响应）
// 返回 false = 未消费（交给 Hub 处理）
```

---

### 3.8 InlineCalibration（力度滴定）

**文件**：`src/components/calibration/InlineCalibration.tsx`（296 行）

#### 流程

```
Phase: wear → explain → stimulate → rest → deep → result → askPump
```

| Phase | 交互 |
|-------|------|
| `wear` | 穿戴确认 pill |
| `explain` | 规则说明 → 开始 |
| `stimulate` | 档位从 1 递增，用户从 5 个 pill 中选择反馈（🌱刚有感/🌊舒适/💪很大/😣勉强/🛑疼） |
| `rest` | 10 秒倒计时过渡 |
| `deep` | 同 stimulate 流程 |
| `result` | 展示 maxSafeGear / cozyGear / minEffectiveGear + 保存 localStorage |
| `askPump` | 选择：去吸乳 / 返回 |

**停止条件**：选择 `🛑 疼！快停下` → 立即停止递增，`maxSafeGear = currentGear - 1`

---

### 3.9 FocusVoiceMode（全屏语音模式）

**文件**：`src/components/voice/FocusVoiceMode.tsx`（273 行）

#### 交互

| 状态 | 视觉 | 按钮文字 |
|------|------|---------|
| Mai 说话中 | 呼吸光晕快速脉动 + 字幕逐字显示 | "点击打断 Mai" (✋) |
| 用户说话中 | 麦克风涟漪扩散 + "正在聆听..." | destructive 色 |
| 空闲 | 光晕缓慢呼吸 | "点击开始说话" (🎙️) |

**Barge-in 机制**：用户在 Mai 说话时点击 → 打断 TTS → 切换到监听态

---

### 3.10 MusicPlayer（吸乳伴奏）

**文件**：`src/components/pump/MusicPlayer.tsx`（196 行）

```typescript
const PLAYLISTS = [
  { id: "calm",    name: "🌙 轻柔助眠", tracks: ["Moonlight Sonata", "River Flows", "Clair de Lune"] },
  { id: "nature",  name: "🌿 自然白噪音", tracks: ["雨声", "海浪", "森林鸟鸣"] },
  { id: "lullaby", name: "🍼 宝宝摇篮曲", tracks: ["Twinkle Star", "小星星", "摇篮曲"] },
];
```

波形可视化：24 根柱状条，高度受模式驱动：
- 奶阵：高振幅 + 快速更新（50ms）
- 低流速：低振幅 + 慢速更新（120ms）
- 标准：中等（80ms）

---

## 4. 待定技术方案与风险提示

### 4.1 需后端 API 替代的 Mock 接口

| 功能点 | 当前实现 | 所需 API |
|--------|----------|---------|
| 吸乳记录 CRUD | 内存 state + mock 数组 | `POST/GET/PUT/DELETE /api/pump-records` |
| 宝宝生长记录 | 硬编码 `babyData` | `GET/PUT /api/baby/growth` |
| 日程任务管理 | 内存 state + localStorage | `GET/POST/PUT/DELETE /api/schedule/tasks` |
| 设备信息 | 硬编码 `devices[]` | BLE SDK + `GET /api/devices` |
| 配件识别 | 固定 3 个 demo 结果 | 图像识别 API（CV 模型） |
| 力度标定结果 | localStorage | `POST /api/calibration/results` |
| 追奶计划同步 | localStorage + window event | 后端持久化 + WebSocket/SSE |
| Mai 对话 | 硬编码回复 + 模拟流式输出 | LLM API（流式 SSE） |
| 语音识别/TTS | 模拟文字显示 | Web Speech API / 第三方 ASR+TTS |
| 音乐播放 | 仅 UI 展示，无实际音频 | 音频文件 + Web Audio API |
| 通知/提醒 | 仅 UI banner | Push Notification API + 后端调度 |
| 用户认证 | 无 | Auth（OAuth / 手机号登录） |
| 多设备实时数据 | Mock flow 模拟 | BLE GATT 协议 + 实时数据通道 |

### 4.2 技术盲区与实现注意

| 风险项 | 说明 |
|--------|------|
| **chatStore 非响应式** | `chatStore` 是纯内存对象，非 React state。当前靠 `chatBus` subscribe 触发 `setMessages`。切换到后端持久化后需改为 React Query / SWR |
| **跨页面事件耦合** | `window.dispatchEvent` + `localStorage` 用于 Schedule ↔ BabyGrowth 同步。生产环境应替换为统一状态管理或后端同步 |
| **PumpSession 1370 行** | 单文件过大，建议拆分为 `usePumpSimulation` hook + `PumpVisuals` + `PumpControls` 子组件 |
| **AgentHub 758 行** | 建议将 inline flow 渲染逻辑拆为独立的 `ChatMessageRenderer` 组件 |
| **BabyGrowth 680 行** | 建议将 FeedingBalance 和 FeedingRecords 拆为独立组件 |
| **流速模拟算法** | `computeFlow()` 基于 sin 波 + 随机数，实际需替换为 BLE 实时数据流 |
| **日期硬编码** | 多处 `today = "2026-03-09"` 硬编码，需替换为 `new Date()` |
| **无错误边界** | 全局缺少 React ErrorBoundary，任一组件崩溃会白屏 |
| **无 loading 状态** | 所有数据为同步 mock，未实现 Skeleton / Spinner |
| **无国际化** | 全中文硬编码，如需多语言需引入 i18n 方案 |
| **无单元测试** | 仅存在空壳 `example.test.ts`，核心业务逻辑无测试覆盖 |
| **z-index 碎片化** | 多处 `z-[5]`, `z-[71]`, `z-[100]`, `z-[200]` 硬编码，建议抽取为 CSS 变量或常量 |

---

> **已完成模块**：全局架构、数据模型、AgentHub、PumpSession、Records、BabyGrowth、Schedule、DeviceManagement、InlineDeviceFlow、InlineCalibration、FocusVoiceMode、MusicPlayer  
>  
> **未展开的子组件**（如需可继续）：InlineScheduleFlow、InlineLactationFlow、ScheduleAgentDrawer、RecordAgentDrawer、GrowthChatDrawer、MaiChatDrawer、ChaseMilkDrawer、MaiSessionBubbles、MaiTargetExplainSheet、MilkProgressBar、FeedingEntryDialog、BlockedSlotDialog、DayEndSummary、LactationGoalSheet、ReminderAlert
