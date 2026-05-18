# 原型功能开发及技术规范说明（续）

> **版本**：mai.agenticapp_v1.1alpha_FZD_20260316  
> **本文档承接** `TECH_SPEC.md`，详细展开其中列出的 15 个未展开子组件的技术规范。

---

## 目录

| # | 组件 | 文件 |
|---|------|------|
| S1 | InlineScheduleFlow | `src/components/schedule/InlineScheduleFlow.tsx` |
| S2 | InlineLactationFlow | `src/components/lactation/InlineLactationFlow.tsx` |
| S3 | MaiSessionBubbles | `src/components/pump/MaiSessionBubbles.tsx` |
| S4 | MilkProgressBar | `src/components/pump/MilkProgressBar.tsx` |
| S5 | MaiTargetExplainSheet | `src/components/pump/MaiTargetExplainSheet.tsx` |
| S6 | DayEndSummary | `src/components/schedule/DayEndSummary.tsx` |
| S7 | ReminderAlert | `src/components/schedule/ReminderAlert.tsx` |
| S8 | BlockedSlotDialog | `src/components/schedule/BlockedSlotDialog.tsx` |
| S9 | LactationGoalSheet | `src/components/schedule/LactationGoalSheet.tsx` |
| S10 | ScheduleAgentDrawer | `src/components/schedule/ScheduleAgentDrawer.tsx` |
| S11 | RecordAgentDrawer | `src/components/records/RecordAgentDrawer.tsx` |
| S12 | GrowthChatDrawer | `src/components/baby/GrowthChatDrawer.tsx` |
| S13 | ChaseMilkDrawer | `src/components/baby/ChaseMilkDrawer.tsx` |
| S14 | MaiChatDrawer | `src/components/device/MaiChatDrawer.tsx` |
| S15 | FeedingEntryDialog | `src/components/baby/FeedingEntryDialog.tsx` |
| S16 | InventoryEntryDialog | `src/components/records/InventoryEntryDialog.tsx` |
| S17 | ManualEntryDialog | `src/components/records/ManualEntryDialog.tsx` |
| S18 | ConfirmDialog | `src/components/records/ConfirmDialog.tsx` |
| S19 | BluetoothSearchDrawer | `src/components/device/BluetoothSearchDrawer.tsx` |
| S20 | DeviceInfoSheet | `src/components/device/DeviceInfoSheet.tsx` |
| S21 | KnowledgeCardSheet | `src/components/device/KnowledgeCardSheet.tsx` |
| S22 | FloatingMaiButton | `src/components/Mai/FloatingMaiButton.tsx` |
| S23 | MaiAvatar | `src/components/Mai/MaiAvatar.tsx` |
| S24 | MaiInputBar | `src/components/Mai/MaiInputBar.tsx` |
| S25 | PercentileGauge | `src/components/baby/PercentileGauge.tsx` |
| S26 | FocusVoiceMode | `src/components/voice/FocusVoiceMode.tsx` |
| S27 | VoiceChatHistory | `src/components/voice/VoiceChatHistory.tsx` |
| S28 | MusicPlayer | `src/components/pump/MusicPlayer.tsx` |

---

## S1. InlineScheduleFlow

**文件**：`src/components/schedule/InlineScheduleFlow.tsx`（550 行）  
**宿主**：嵌入 AgentHub 对话流中（`cardType: "schedule-flow"`）

### 内部数据模型

```typescript
interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  type?: "text" | "choice" | "task-list" | "phase-card" | "goal-card" | "summary-card" | "blocked-card";
  choiceOptions?: { label: string; action: string }[];
  tasks?: ScheduleTask[];
}
```

### forwardRef 接口

```typescript
export interface InlineScheduleFlowHandle {
  handleExternalInput: (text: string) => boolean;
}
```

父组件（AgentHub）通过 `ref.current.handleExternalInput(text)` 将 MaiInputBar 的文字输入转发进来。返回 `true` 表示已消费。

### 状态机（action 路由表）

| action | 触发方式 | 系统行为 |
|--------|----------|----------|
| `view-tasks` | 用户选择 | 展示 `localTasks` 任务列表（含已完成/冲突标记） |
| `add-avoidance` | 用户选择 | 进入 `awaitingInput="avoidance-text"` 等待文字输入 |
| `delay-next` | 用户选择 | 找到第一个未完成非会议任务 → `addMinutes(time, 30)` → 排序 |
| `screenshot-schedule` | 用户选择 | 进入 `awaitingInput="ocr-text"` 等待截图/文字 |
| `day-summary` | 用户选择 | 显示已完成率 + 产量 + 鼓励词 |
| `view-phase` | 用户选择 | 渲染 Milky.Way 4 阶段卡片 |
| `goal-adjust` | 用户选择 | 显示 7 日奶量 → 选择增量/维持/减量 |
| `goal-increase` | 用户选择 | 确认风险 → `goal-increase-confirm` |
| `goal-increase-confirm` | 用户确认 | 注入追奶任务到 `localTasks` |
| `goal-decrease` | 用户选择 | 确认风险 → `goal-decrease-confirm` |
| `goal-decrease-confirm` | 用户确认 | 移除一项 mai 来源 pump 任务 |
| `goal-maintain` | 用户选择 | 鼓励消息 |
| `goal-cancel` | 用户放弃 | 安慰消息 |
| `ocr-confirm` | 用户确认 OCR | 应用调整 |
| `ocr-adjust` | 用户再调 | 重新等待输入 |
| `done` | 用户完成 | 结束消息 → `onComplete?.()` |

### 文字输入处理

| `awaitingInput` 值 | 输入处理 |
|---------------------|----------|
| `"avoidance-text"` | 新增 `BlockedSlot`(title=输入, start="14:00", end="15:00")；遍历 `localTasks`，冲突任务 `time` 提前 30min |
| `"ocr-text"` | 显示识别结果（固定 14:00-15:00），提供确认/再调整选项 |
| `null` | 通用 fallback 回复 |

### 冲突调整算法

```typescript
const adjusted = localTasks.map((t) => {
  if (t.type === "pump" && t.time >= newSlot.start && t.time < newSlot.end) {
    return { ...t, time: addMinutes(newSlot.start, -30), adjusted: "因避开时段提前" };
  }
  return t;
}).sort((a, b) => a.time.localeCompare(b.time));
```

### 渲染特殊卡片

| type | 渲染内容 |
|------|----------|
| `task-list` | 任务行：`time` + `icon(pump/feed/meeting)` + `title` + done/adjusted/source badge |
| `phase-card` | Milky.Way 4 阶段横条，`active` 项高亮 `bg-primary/10` |
| `goal-card` | 7 日奶量表 + 日均值 |
| `summary-card` | 完成率 + 产量 |
| `choice` | 按钮组（最多 4 个选项） |

---

## S2. InlineLactationFlow

**文件**：`src/components/lactation/InlineLactationFlow.tsx`（567 行）  
**宿主**：嵌入 AgentHub 对话流中（`cardType: "lactation-flow"`）

### Props

```typescript
interface Props {
  onComplete?: () => void;
  initialAction?: string;     // "view-phase" | "goal-adjust" | "view-trend" | "growth-assess"
  assessContext?: {
    totalAvailable: number;   // 今日可用乳源 mL
    feedP50: number;          // 宝宝 P50 需求 mL
    bfCount: number;          // 亲喂次数
    bfTotalMin: number;       // 亲喂总时长 min
    babyName: string;
  };
}
```

### 状态机（action 路由表）

| action | 系统行为 |
|--------|----------|
| `view-phase` | 渲染 Milky.Way 周期卡片 + 当前阶段特征说明 |
| `view-trend` | 计算 7 日 max/min/trend → 显示趋势分析 |
| `goal-adjust` | 显示当前状态 → 三选项（增/维持/减） |
| `goal-increase` | 风险告知 → 确认 |
| `goal-increase-confirm` | 添加追奶任务建议 |
| `goal-decrease` | 减量风险告知 → 确认 |
| `goal-decrease-confirm` | 建议移除追奶任务 |
| `goal-maintain` | 鼓励保持 |
| `goal-cancel` | 安慰 |
| `done` | 结束 → `onComplete?.()` |

### 生长评估分支（`growth-assess`）

由 BabyGrowth 页面的"智能通知 banner"触发，携带 `assessContext`：

```
growth-assess
├── 展示供需比 (totalAvailable / feedP50 × 100%)
├── 如有亲喂(bfCount>0)，补充亲喂奶量不可计算的说明
├── 选择 → "有漏记" | "记录齐了"
│   ├── "有漏记" → 建议去补录 → done / 继续评估
│   └── "记录齐了" → assess-complete
│       ├── ratio < 0.85 → 偏少 → 感受确认
│       ├── ratio > 1.3  → 充裕 → 减量/保持
│       └── 0.85~1.3    → 匹配 → 满意/想多/想减
├── assess-not-enough / assess-want-more → 追奶方案
│   └── assess-confirm-chase → 注入 chaseTasks 到 localStorage
├── assess-want-reduce → 减量方案
│   └── assess-confirm-reduce → 移除 localStorage 中追奶任务
└── assess-keep / assess-enough → 鼓励 → done
```

### 跨模块副作用

| 操作 | 机制 |
|------|------|
| 注入追奶任务 | `localStorage.setItem("chaseMilkTasks", JSON.stringify(tasks))` + `window.dispatchEvent(new Event("chaseMilkUpdated"))` |
| 移除追奶任务 | `localStorage.setItem("chaseMilkTasks", "[]")` + `window.dispatchEvent(new Event("chaseMilkUpdated"))` |
| 跳转到日程页 | `window.dispatchEvent(new CustomEvent("navigate-to", { detail: "/schedule" }))` |

---

## S3. MaiSessionBubbles

**文件**：`src/components/pump/MaiSessionBubbles.tsx`（274 行）  
**宿主**：PumpSession 控制面板中 MaiAvatar 上方

### Props

```typescript
interface Props {
  mode: "stimulate" | "deep";
  running: boolean;
  paused: boolean;
  modeElapsed: number;        // 当前模式已运行秒数
  onPauseForCheck: () => void; // 暂停吸乳 + 穿戴检查
}
```

### 气泡策略

**Stimulate 模式：闲聊分散注意力**

| 条件 | 气泡内容 | 持续时间 |
|------|----------|----------|
| `modeElapsed ≥ 8s` 且未触发 | 固定文案："放松～ 乳汁正在路上..." | 6s |
| `modeElapsed ≥ 12s` 且未触发 | 固定文案 + `isAction=true`（穿戴检查 CTA）| 8s |
| 随机 (3-8s 间隔) | 从 `stimChattyLines[]`(10 条) 随机不重复选取 | 4-6s |
| 总计上限 | `bubbleCountRef.current >= 10` 后不再弹出 | — |

**Deep 模式：知识科普**

| 条件 | 气泡内容 | 持续时间 |
|------|----------|----------|
| 随机 (5-13s 间隔) | 从 `deepKnowledgeBubbles[]`(5 条) 随机不重复选取 | 7s |
| 总计上限 | `bubbleCountRef.current >= 5` 后不再弹出 | — |
| 点击行为 | 打开 `KnowledgeCardSheet`，展示内联知识卡片 | — |

### 知识气泡数据结构

```typescript
interface DeepBubbleData {
  text: string;                    // 气泡显示文案
  knowledge: KnowledgeCardData;    // 关联知识卡片
}
```

内置 5 个知识主题：初乳秘密、乳头护理、含乳姿势、营养搭配、夜间喂养。

### 气泡交互

| 点击行为 | 响应 |
|----------|------|
| `isAction=true` 的气泡 | 调用 `onPauseForCheck()` 暂停吸乳 |
| `knowledgeData` 存在的气泡 | 打开 `KnowledgeCardSheet` |
| 普通气泡 | 无响应（自动消失） |

---

## S4. MilkProgressBar

**文件**：`src/components/pump/MilkProgressBar.tsx`（138 行）  
**宿主**：PumpSession 页面

### Props

```typescript
interface Props {
  side: "L" | "R";
  label?: string;
  progress: number;          // 0-100，完成百分比
  target: number;            // 0-100，目标百分比
  flow: number;              // 实时流速
  isLetdown: boolean;        // 奶阵中
  inExtend: boolean;         // 延长模式中
  extendTime: number;        // 延长秒数
  onHelpClick?: () => void;  // 点击 ? 打开 MaiTargetExplainSheet
}
```

### 视觉结构

```
[======== 主段(90%) ========][延长段(10%)]
     ↑ target tick mark      ↑ orange色
     ↑ 25%/50%/75% 刻度线
     ↑ 动态游标（progress 驱动位置）
```

### 游标动画

| 状态 | 动画效果 |
|------|----------|
| 正常 | 静态，`bg-primary` |
| `isLetdown && !inExtend` | 脉冲 `scale: [1, 1.8, 1]`，`bg-orange-400` |
| `inExtend` | 呼吸 `scale: [1, breathScale, 1]`，`bg-orange-400` |

### 渐变色

```typescript
// 主段进度条渐变（基于 side 的色相微调）
background: `linear-gradient(90deg, 
  hsl(${baseHue} 30% 88%), 
  hsl(${baseHue} 40% 65%), 
  hsl(${baseHue} 45% 35%)
)`;
```

---

## S5. MaiTargetExplainSheet

**文件**：`src/components/pump/MaiTargetExplainSheet.tsx`（184 行）  
**宿主**：PumpSession 页面（点击 MilkProgressBar 上的 `?` 按钮触发）

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  currentTarget: number;       // 当前目标值 60-100
  onApplyTarget: (newTarget: number) => void;
}
```

### 流式消息机制

5 条预设文案 (`maiExplainSteps[]`)，逐字流式输出（每字 30ms），每条完成后 600ms 延迟开始下一条。

### 交互

| 阶段 | UI |
|------|------|
| 流式输出中 | 只读消息列表 + 光标闪烁 |
| 全部输出完毕 | 显示 `<input type="range" min=60 max=100>` 滑块 |
| 用户调整并确认 | 调用 `onApplyTarget(newTarget)` → 追加用户/Mai 确认消息 |

---

## S6. DayEndSummary

**文件**：`src/components/schedule/DayEndSummary.tsx`（170 行）  
**宿主**：Schedule 页面

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  tasks: ScheduleTask[];
}
```

### 动画流程（3 阶段）

```
Phase: list → striking → badge
```

| Phase | 时机 | 视觉 |
|-------|------|------|
| `list` | 打开后 0.8s | 显示所有已完成任务列表 |
| `striking` | 自动开始 | 逐项划线 (500ms/项) → 滑出 (350ms 后 x:300) |
| `badge` | 全部划完 500ms 后 | 🎉 勋章动画 (spring scale 0→1) + 随机鼓励语 |

### 鼓励语池

```typescript
const encourageTexts = [
  "今天辛苦了，你做得比你想象的更好！💕",
  "每一次坚持都是对宝宝最好的爱 🌟",
  "了不起的妈妈，Mai为你骄傲！✨",
];
```

---

## S7. ReminderAlert

**文件**：`src/components/schedule/ReminderAlert.tsx`（46 行）  
**宿主**：Schedule 页面（关闭提醒 toggle 时弹出）

### Props

```typescript
interface Props {
  open: boolean;
  onConfirm: () => void;    // 确认关闭提醒
  onCancel: () => void;     // 取消（保持开启）
}
```

### 交互

居中弹窗，`AlertTriangle` 警告图标 + 文案："关闭提醒后，Mai 将无法提供个性化排期优化和智能防冲突功能。"  
双按钮：`[保持开启]` (outline) + `[仍要关闭]` (destructive)

---

## S8. BlockedSlotDialog

**文件**：`src/components/schedule/BlockedSlotDialog.tsx`（103 行）  
**宿主**：Schedule 页面

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  onAdd: (slot: { title: string; start: string; end: string }) => void;
}
```

### 表单字段

| 字段 | 类型 | 默认值 | 校验 |
|------|------|--------|------|
| `title` | text Input | `""` | `trim()` 非空 |
| `start` | time Input | `"14:00"` | — |
| `end` | time Input | `"15:00"` | — |

提交后重置表单并关闭。

---

## S9. LactationGoalSheet

**文件**：`src/components/schedule/LactationGoalSheet.tsx`（117 行）  
**宿主**：Schedule 页面（点击泌乳目标卡片的"调整→"触发）

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  onAskMai: () => void;    // 跳转到 AgentHub 的泌乳管理流程
}
```

### 内容结构

```
LactationGoalSheet
├── MaiAvatar CTA → 关闭 sheet + 调用 onAskMai()
└── 4 策略卡片 (strategies[])
    ├── 初乳期 (0-3天): 尽早开奶
    ├── 建立期 (1-4周): 频繁排空
    ├── 稳产期 (1-6月): 维持奶量 ← active: true
    └── 离乳期 (6月+): 逐步减少
```

`active` 卡片使用 `bg-primary/5 border-primary/30` 高亮。

---

## S10. ScheduleAgentDrawer

**文件**：`src/components/schedule/ScheduleAgentDrawer.tsx`  
**宿主**：Schedule 页面

### Props

```typescript
type AgentContext = "ocr" | "goal" | "avoidance";

interface Props {
  open: boolean;
  onClose: () => void;
  context: AgentContext;
  onConfirmReschedule: () => void;
}
```

### 三种上下文模式

| context | 初始消息 | 核心流程 |
|---------|----------|----------|
| `ocr` | "收到日程截图，我来分析..." | 识别冲突 → 确认/取消重排 |
| `goal` | 泌乳目标讨论 | 3 阶段选择（increase/maintain/decrease） |
| `avoidance` | "请告诉我避开时段" | 文字输入 → 冲突检测 → 调整 |

---

## S11. RecordAgentDrawer

**文件**：`src/components/records/RecordAgentDrawer.tsx`  
**宿主**：Records 页面

### Props

```typescript
interface RecordAgentDrawerProps {
  open: boolean;
  onClose: () => void;
  todayRecords: PumpRecord[];
  todayTotal: number;
  onAddRecord: (record: PumpRecord) => void;
}
```

### 核心功能

| Pill | 行为 |
|------|------|
| "背奶补录" | 进入 `awaitingFlow="record"` → 等待用户输入 ml 数字 → 正则提取 → 调用 `onAddRecord(record)` |
| "趋势咨询" | 计算 device/manual 分布占比 → 展示 breakdown 卡片 |

### 输入解析

```typescript
// handleSend() 中，awaitingFlow === "record" 时
const match = input.match(/\d+/);
if (match) {
  const totalMl = parseInt(match[0]);
  onAddRecord({ ...newRecord, totalMl, source: "manual", subLabel: "补录" });
}
```

---

## S12. GrowthChatDrawer

**文件**：`src/components/baby/GrowthChatDrawer.tsx`  
**宿主**：BabyGrowth 页面

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  metrics: { weight: number; height: number; head: number };
  onMetricsUpdate: (m: { weight: number; height: number; head: number }) => void;
  onFeedingRecord: (r: PumpRecord) => void;
  onInventoryRecord: (r: PumpRecord) => void;
  babyName: string;
  ageDays: number;
}
```

### Pill 驱动的子流程

| Pill | 流程 |
|------|------|
| `record` | 依次询问体重/身长/头围 → "confirm" 确认 → `onMetricsUpdate()` |
| `feeding` | 选择喂养类型(亲喂/配方奶/瓶喂) → 输入量 → `onFeedingRecord()` |
| `inventory` | 输入补录量 → `onInventoryRecord()` |
| `weight-explain` | 展示体重百分位解读 |
| `feeding-advice` | 展示喂养建议 |

---

## S13. ChaseMilkDrawer

**文件**：`src/components/baby/ChaseMilkDrawer.tsx`  
**宿主**：BabyGrowth 页面

### Props

```typescript
interface Props {
  open: boolean;
  onClose: () => void;
  onConfirmPlan: () => void;
}
```

### 交互流程

1. 初始 Mai 消息介绍追奶方案
2. 用户可自由输入聊天
3. Pill：`[确认方案]` → 追加确认消息 + toast 提示 + `onConfirmPlan()`
4. 确认后 Pill 变为 `[去日程页查看→]`（navigate 到 `/schedule`）

---

## S14. MaiChatDrawer（设备专属）

**文件**：`src/components/device/MaiChatDrawer.tsx`  
**宿主**：DeviceManagement 页面

### 核心能力

半屏 Drawer 内的完整设备对话系统，包含：

| 功能 | 入口 | 子流程 |
|------|------|--------|
| 尺寸测量 | `initialTopic="measurement"` / pill 点击 | 5 步交互引导（`measurementSteps[]`） |
| 开箱引导 | `initialTopic="unbox"` / pill 点击 | BT → 配件 → 组装 → 穿戴 → 测量 → 标定 |
| 配件识别 | 拍照/上传/Demo | `PhotoIdentifyResult` → 知识卡片 |
| 舒适度标定 | 从开箱/测量流程末端触发 | 内联 `InlineCalibration` 组件 |

### 内部消息类型

```typescript
type ChatMsgType = 
  | "text" | "image" | "identify-result" | "choice" 
  | "device-card" | "doc-links" | "inline-calibration";
```

---

## S15. FeedingEntryDialog

**文件**：`src/components/baby/FeedingEntryDialog.tsx`  
**宿主**：BabyGrowth 页面

### 喂养类型

```typescript
type FeedingType = "Recipe" | "Pro feed" | "Bottle feed";

const feedingTypes = [
  { key: "Recipe",      label: "🧪 配方奶", subLabel: "配方奶" },
  { key: "Pro feed",    label: "🤱 亲喂",   subLabel: "亲喂" },
  { key: "Bottle feed", label: "🍼 瓶喂",   subLabel: "瓶喂" },
];
```

### 提交 Payload

```typescript
const record: PumpRecord = {
  id: `feeding-${Date.now()}`,
  date: "2026-03-09",
  time: HH:mm,
  durationMin: type === "Pro feed" ? value : 0,  // 亲喂用分钟
  totalMl: type !== "Pro feed" ? totalMl : 0,     // 非亲喂用 mL
  source: "manual",
  mode: "deep",
  subLabel: subLabelMap[type],
  category: "feeding",
};
```

### 单位转换

亲喂时输入单位为"分钟"，其他为 mL/oz（通过 `useVolumeUnit()` hook 全局同步）。

---

## S16. InventoryEntryDialog

**文件**：`src/components/records/InventoryEntryDialog.tsx`（153 行）  
**宿主**：Records 页面

### 库存类型

```typescript
type InventoryType = "补录" | "配方奶";
```

### 与 ManualEntryDialog 的区别

| 维度 | ManualEntryDialog | InventoryEntryDialog |
|------|-------------------|---------------------|
| 类型选择 | 无（固定"补录"） | 双选：补录 / 配方奶 |
| 配方奶标识 | 不支持 | `🧪 配方奶将以不同颜色标识` |
| 宿主页面 | Records | Records |
| category | `"inventory"` | `"inventory"` |

---

## S17. ManualEntryDialog

**文件**：`src/components/records/ManualEntryDialog.tsx`（126 行）

固定为"背奶补录"类型，单字段（mL/oz）输入，支持编辑模式（`editRecord` prop 非空时回填）。  
提交后 `category: "inventory"`, `subLabel: "补录"`, `source: "manual"`, `durationMin: 0`。

---

## S18. ConfirmDialog

**文件**：`src/components/records/ConfirmDialog.tsx`（52 行）

### Props

```typescript
interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  onConfirm: () => void;
  onCancel: () => void;
  confirmLabel?: string;       // default: "确认"
  destructive?: boolean;       // default: false → 确认按钮用 destructive variant
}
```

通用确认弹窗，居中 scale 动画。用于删除/编辑确认等场景。

---

## S19. BluetoothSearchDrawer

**文件**：`src/components/device/BluetoothSearchDrawer.tsx`（207 行）

### Props

```typescript
interface Props {
  open: boolean;
  side: "L" | "R";
  currentDeviceId: string;
  onClose: () => void;
  onConnect: (deviceId: string) => void;
}
```

### Mock 设备发现

```typescript
const mockScannedDevices: ScannedDevice[] = [
  { id: "bt1", name: "MaiPump Pro - L", rssi: -45, paired: true },
  { id: "bt2", name: "MaiPump Pro - R", rssi: -52, paired: true },
  { id: "bt3", name: "MaiPump Lite - L", rssi: -68, paired: false },
  { id: "bt4", name: "MaiPump Mini",     rssi: -75, paired: false },
];
```

打开时逐个发现（800ms + i×600ms），完毕后 `scanning=false`。

### 信号强度映射

| RSSI 范围 | 显示 | 颜色 |
|-----------|------|------|
| > -50 | 强 | `text-primary` |
| > -65 | 良 | `text-mai-warm` |
| ≤ -65 | 弱 | `text-muted-foreground` |

### 连接流程

点击"连接"按钮 → `connecting` 状态 1.5s → `onConnect(deviceId)` → `onClose()`

---

## S20. DeviceInfoSheet

**文件**：`src/components/device/DeviceInfoSheet.tsx`（139 行）

### Props

```typescript
interface Props {
  device: DeviceInfo | null;
  open: boolean;
  onClose: () => void;
}
```

### 内容区块

1. **设备信息** (2×2 Grid)：型号、固件版本、序列号、法兰尺寸
2. **产品亮点** (4 项)：智能双频吸力、医疗级硅胶、防回流设计、蓝牙智能记录
3. **穿戴安装步骤** (5 步)：安装法兰 → 放入硅胶塞 → 安装鸭嘴阀 → 连接奶瓶 → 穿戴就位

---

## S21. KnowledgeCardSheet

**文件**：`src/components/device/KnowledgeCardSheet.tsx`（96 行）

### Props

```typescript
interface Props {
  data: KnowledgeCardData | null;
  open: boolean;
  onClose: () => void;
  onAskMaiMeasure?: () => void;  // 法兰卡片专属 CTA
}
```

### 渲染逻辑

- 遍历 `data.sections[]` 渲染标题+内容
- 如有 `data.tip`，渲染 primary/5 高亮提示区
- 如 `title` 包含"法兰"且 `onAskMaiMeasure` 存在 → 追加"让 Mai 教你正确测量→"按钮

---

## S22. FloatingMaiButton

**文件**：`src/components/Mai/FloatingMaiButton.tsx`（34 行）

### 行为

- **可拖拽**：`framer-motion drag` + `dragConstraints={constraintsRef}`（整个视口）
- **点击打开** FocusVoiceMode（非拖拽时）
- **位置**：`absolute top-14 right-5`，`z-40`
- **防误触**：`onDragStart` 设 `dragging=true`，`onDragEnd` 100ms 后清除

### 宿主页面

Records、BabyGrowth、Schedule、DeviceManagement（不含 AgentHub 和 PumpSession）

---

## S23. MaiAvatar

**文件**：`src/components/Mai/MaiAvatar.tsx`（82 行）

### Props

```typescript
type MaiEmotion = "happy" | "encourage" | "alert" | "calm" | "thinking";

interface MaiAvatarProps {
  emotion?: MaiEmotion;          // default: "calm"
  size?: "sm" | "md" | "lg" | "xl";  // default: "md"
  animate?: boolean;             // default: true
  className?: string;
}
```

### 尺寸映射

| size | class |
|------|-------|
| sm | `w-10 h-10` |
| md | `w-16 h-16` |
| lg | `w-24 h-24` |
| xl | `w-40 h-40` |

### 情绪 → 图片 & 动画

| emotion | 图片资源 | CSS 动画 class | 光环色 |
|---------|----------|---------------|--------|
| calm | `mai-calm.png` | `mai-anim-breathe` | `bg-mai-blush/50` |
| happy | `mai-happy.png` | `mai-anim-bounce` | `bg-mai-blush` |
| encourage | `mai-encourage.png` | `mai-anim-nod` | `bg-mai-warm` |
| thinking | `mai-thinking.png` | `mai-anim-sway` | `bg-mai-blush/50` |
| alert | `mai-worry.png` | `mai-anim-tremble` | `bg-mai-warm animate-pulse` |

### 图片裁剪

```css
width: 140%; height: 140%;
object-fit: cover;
object-position: center 30%;  /* 显示上半身为主 */
```

---

## S24. MaiInputBar

**文件**：`src/components/Mai/MaiInputBar.tsx`（158 行）

### Props

```typescript
interface MaiInputBarProps {
  value: string;
  onChange: (val: string) => void;
  onSend: () => void;
  onVoice?: () => void;
  onFocusMode?: () => void;
  onPhotoFile?: (file: File) => void;
  onDemoIdentify?: (result: PhotoIdentifyResult) => void;
  disabled?: boolean;
  placeholder?: string;
  showPhotoMenu?: boolean;
  onTogglePhotoMenu?: (open: boolean) => void;
  className?: string;
  variant?: "main" | "drawer";  // "main" → pb-20, "drawer" → pb-6
}
```

### 功能按钮布局

```
[📷 ImagePlus] [   Input   ] [🎤 Mic] [🎧 Focus?] [➤ Send]
```

### 拍照菜单

展开后显示：
1. `[📷 拍照]` → `cameraInputRef`（`capture="environment"`）
2. `[📤 上传]` → `fileInputRef`
3. 演示样本：`arMockResults[]` 的 3 个配件缩略图 → `onDemoIdentify(item)`

---

## S25. PercentileGauge

**文件**：`src/components/baby/PercentileGauge.tsx`（135 行）  
**宿主**：BabyGrowth 页面的 GrowthMetrics 区域

### Props

```typescript
interface PercentileGaugeProps {
  label: string;             // "体重"
  icon: string;              // "⚖️"
  unit: string;              // "kg"
  value: number;
  p25: number; p50: number; p75: number;
  min: number; max: number;
  hint?: string;
  onValueChange?: (newValue: number) => void;
}
```

### 视觉元素

```
[===P25区间===|===P50区间===|===P75区间===]
              ↑                            ↑
         value 圆点                    P75 刻度线
```

- **P25-P75 区间**：`bg-primary/10` 填充
- **P25-P50 区间**：叠加 `bg-primary/20`
- **圆点颜色**：`value < P25` → `bg-destructive`，否则 → `bg-primary`

### 内联编辑

点击 ✏️ → 显示 `<input type="number">` → Enter 或 ✓ 确认 → `onValueChange(num)`

---

## S26. FocusVoiceMode

**文件**：`src/components/voice/FocusVoiceMode.tsx`（273 行）

### 视觉层次

```
FocusVoiceMode (fixed, z-[100])
├── Header: [↓ 收起] [📜 对话记录]
├── Center: Mai 全身像 + 呼吸光晕
│   ├── 光晕: radial-gradient(--mai-glow)
│   │   ├── Speaking: scale [1, 1.3, 1], opacity [0.4, 0.7, 0.4], 1.2s
│   │   └── Idle: scale [1, 1.1, 1], opacity [0.2, 0.35, 0.2], 3s
│   └── 身体: 随机 idle 动画 (4 variants, 3s 切换)
├── Subtitle: 逐字显示区 (80ms/字 for greeting, 60ms/字 for reply)
├── Mic Button: 三层涟漪 + 主按钮
│   ├── Listening: bg-destructive, 涟漪扩散 (micLevel 驱动)
│   ├── Mai Speaking: bg-secondary, Hand icon
│   └── Idle: bg-primary, Mic icon
└── VoiceChatHistory (侧滑抽屉)
```

### Barge-in 机制

```typescript
handleBargeIn() {
  if (isMaiSpeaking) {
    // 打断: 停止 TTS → 字幕显示"（已打断）"
    setIsMaiSpeaking(false);
    setSubtitle("（已打断）");
  }
  // 开始监听 → 2.5s 后模拟识别结果 → 0.8s 后 Mai 回复
}
```

### 模拟语音数据

```typescript
const maiReplies = [
  "嗯嗯，我听到了～根据你目前的情况...",
  "明白了！产后恢复是一个循序渐进的过程...",
  "好的，我来帮你分析一下...",
  "这个问题很好！让我想想...",
];
```

---

## S27. VoiceChatHistory

**文件**：`src/components/voice/VoiceChatHistory.tsx`（83 行）

### Props

```typescript
interface Props {
  open: boolean;
  messages: VoiceMessage[];    // { id, role, text }
  onClose: () => void;
}
```

右侧滑入抽屉（`w-[80vw] max-w-[320px]`，`z-[110]`），渲染消息气泡列表。空态显示"暂无对话记录"。

---

## S28. MusicPlayer

**文件**：`src/components/pump/MusicPlayer.tsx`（196 行）  
**宿主**：PumpSession 页面

### Props

```typescript
interface Props {
  isLetdown: boolean;
  isLowFlow: boolean;
  running: boolean;
}
```

### 播放列表

```typescript
const PLAYLISTS = [
  { id: "calm",    name: "🌙 轻柔助眠",    tracks: ["Moonlight Sonata", "River Flows", "Clair de Lune"] },
  { id: "nature",  name: "🌿 自然白噪音",  tracks: ["雨声", "海浪", "森林鸟鸣"] },
  { id: "lullaby", name: "🍼 宝宝摇篮曲",  tracks: ["Twinkle Star", "小星星", "摇篮曲"] },
];
```

### 波形可视化参数

| 模式 | 振幅范围 | 刷新间隔 | 渐变色 |
|------|----------|----------|--------|
| 奶阵 (`isLetdown`) | `0.4 + sin*0.35 + spike*0.3` | 50ms | `from-orange-400 to-orange-600` |
| 低流速 (`isLowFlow`) | `0.1 + sin*0.08 + rand*0.06` | 120ms | `from-primary/40 to-primary/60` |
| 标准 | `0.2 + sin*0.15 + rand*0.1` | 80ms | `from-primary/60 to-primary` |

24 根柱状条（`w-[2.5px]`），使用 `requestAnimationFrame` + `setInterval` 双驱动平滑过渡。

### 交互

| 操作 | 响应 |
|------|------|
| 点击 ▶/⏸ | 切换播放/暂停（仅控制波形动画，无实际音频） |
| 点击 ⏭ | 下一曲（循环） |
| 点击歌名区域 | 切换播放列表选择视图 ↔ 波形视图 |
| 选择播放列表 | 切换到新列表第 1 首 + 自动播放 |

---

## 附录：组件依赖关系图

```
AgentHub
├── MaiAvatar
├── MaiInputBar
├── FocusVoiceMode ←── VoiceChatHistory
├── InlineCalibration
├── InlineDeviceFlow
│   ├── KnowledgeCardSheet
│   ├── BluetoothSearchDrawer
│   └── InlineCalibration
├── InlineScheduleFlow
└── InlineLactationFlow

PumpSession
├── MilkProgressBar
├── MusicPlayer
├── MaiSessionBubbles ←── KnowledgeCardSheet
├── MaiTargetExplainSheet
└── MaiChatDrawer
    ├── MaiInputBar
    ├── KnowledgeCardSheet
    ├── BluetoothSearchDrawer
    └── InlineCalibration

Records
├── SwipeRow
├── ManualEntryDialog
├── InventoryEntryDialog
├── ConfirmDialog
├── RecordAgentDrawer
└── FloatingMaiButton ←── FocusVoiceMode

BabyGrowth
├── PercentileGauge
├── FeedingEntryDialog
├── GrowthChatDrawer
├── ChaseMilkDrawer
└── FloatingMaiButton

Schedule
├── BlockedSlotDialog
├── ScheduleAgentDrawer
├── LactationGoalSheet
├── ReminderAlert
├── DayEndSummary
└── FloatingMaiButton

DeviceManagement
├── DeviceCard
├── SmartManual
├── PhotoIdentifyDrawer
├── KnowledgeCardSheet
├── MaiChatDrawer
├── DeviceInfoSheet
├── BluetoothSearchDrawer
└── FloatingMaiButton
```

---

> **文档完成**。本文档覆盖 TECH_SPEC.md 中列出的全部 15+ 未展开子组件，共计 28 个组件的详细技术规范。
