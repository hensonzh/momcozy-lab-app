# M.ai 智能母乳管理助手 — 全量产品需求文档 (PRD)

> **版本**: PRD_mai.agenticapp_v1.2alpha_FZD_20260320  
> **日期**: 2026-03-20  
> **状态**: 原型阶段（前端 Mock 数据驱动）  
> **基线对比**: v1.1alpha_FZD_20260316

---

## 目录

1. [项目概述](#1-项目概述)
2. [总功能流转用户旅程](#2-总功能流转用户旅程)
3. [功能模块清单与路由](#3-功能模块清单与路由)
4. [各模块用户旅程与功能详述](#4-各模块用户旅程与功能详述)
5. [数据接口与变量要求](#5-数据接口与变量要求)
6. [功能实现逻辑](#6-功能实现逻辑)
7. [跨模块数据联动](#7-跨模块数据联动)
8. [UI/UX 规范](#8-uiux-规范)
9. [外部集成与环境变量](#9-外部集成与环境变量)

---

## 1. 项目概述

### 1.1 核心目标

M.ai 是一款面向产后哺乳期妈妈的智能母乳管理 App，通过 AI 助手 "M.ai"（拟人化虚拟角色）提供全程陪伴式的泌乳管理、设备控制、日程编排和情绪支持。

### 1.2 目标用户

- **主要用户**: 产后 0–12 个月的母乳喂养/混合喂养妈妈
- **次要用户**: 围产期女性（孕前准备至产后恢复全程）
- **扩展用户**: 返工背奶妈妈（职场哺乳场景）

### 1.3 解决的关键痛点

| 痛点 | 方案 |
|------|------|
| 吸乳频率和时间难以科学规划 | AI 智能排程 + 冲突检测 + 追奶/减奶策略 |
| 吸奶器档位选择凭感觉、缺乏个性化 | 舒适负压滴定（力度滴定）自动校准 |
| 产量数据分散、趋势难以追踪 | 多来源（设备/手动/语音）统一记录 + 7 日趋势图 |
| 工作/生活与泌乳节奏冲突 | 日程 OCR 识别会议 + 自动顺延吸乳安排 |
| 产后情绪支持缺失 | M.ai 拟人化陪伴 + 语音模式 + 鼓励话术 |
| 宝宝生长监测与喂养关联不直观 | 百分位仪表盘 + 奶量-体重联动图 |
| 返工后哺乳节奏被打断 | 返工计划 + 背奶装备清单 + 工作日排程 |
| 围产期准备不充分 | 待产计划 + 待产包清单 + 阶段性提醒 |

### 1.4 v1.2 版本新增功能摘要

| 新增/变更 | 描述 |
|-----------|------|
| **计划体系重构** | 从单一泌乳目标升级为 5 计划并行体系（维持/追奶/减奶/待产/返工），支持互斥和并行规则 |
| **返工计划流程** | 全新 InlineWorkFlow 内联对话流，收集返工时间/工作模式/吸奶环境/关注点，生成专属方案+装备清单 |
| **待产计划流程** | 全新 InlineMaternityFlow 内联对话流，收集预产期/分娩方式/身体状况/关注点，生成待产方案+待产包清单 |
| **呵护计划三视图** | Schedule 页面重构为"今日/Milestone/月历"三 Tab 视图 |
| **Milestone 时间轴** | 新增 MilestoneTimeline 组件，按计划展示里程碑进度和循环任务 |
| **月历视图** | 新增 PlanCalendarView 组件，按月展示计划覆盖区间和里程碑起点 |
| **动态任务生成** | 今日任务从活跃计划的当前里程碑自动生成，支持按间隔过滤 |
| **计划互斥规则** | 泌乳计划（维持/追奶/减奶/待产）互斥；返工计划可与泌乳计划并行但与待产互斥 |
| **Pill 分组重构** | 操作药丸改为分组折叠式：独立入口 + "设备使用"组 + "泌乳管理"组（含返工计划入口） |
| **LactationGoalSheet 扩展** | 泌乳目标半屏增加"我想制定返工计划"入口，跳转 Hub 触发返工流程 |
| **月历里程碑标记修复** | 修复同一计划多里程碑重叠日期时起点标记丢失的问题 |

---

## 2. 总功能流转用户旅程

### 2.1 首次使用旅程

```
首次打开 App
  ↓
M.ai 中枢（Agent Hub）首页
  ↓
点击 [设备使用] → [开箱指引]
  ↓
内联设备引导流程开始
  ├── 蓝牙配对
  ├── 配件识别（拍照/Demo）
  ├── 组装指引
  ├── 穿戴指引
  ├── 法兰尺寸测量
  └── 力度滴定（舒适度校准）
  ↓
力度滴定完成 → 保存 cozyGear / maxSafeGear / minEffectiveGear
  ↓
可选：立即开始首次吸乳 → 跳转 /pump
  ↓
吸乳结束 → 自动生成报告推送到 Hub
```

### 2.2 日常循环旅程

```
打开 App → Hub 首页
  ↓
查看速记板 → 了解今日状态
  ↓
┌─────────────────────────────────────────────────────────────┐
│  吸乳循环                                                    │
│  ┌─ Hub 点击 [开始吸乳] ──→ /pump 沉浸式吸乳              │
│  │    ├── AI 托管自动调控档位                                │
│  │    ├── 检测奶阵 → 自动切换模式                           │
│  │    ├── 达标庆祝 / 延长模式                               │
│  │    └── 停止 → 生成报告 → 返回 Hub                        │
│  │                                                           │
│  ├─ 报告自动同步到 Records（妈妈点滴）                      │
│  │    ├── 今日概览三指标实时更新                             │
│  │    └── 7日趋势图联动                                      │
│  │                                                           │
│  ├─ 宝宝陪伴 → 供需平衡检查                                │
│  │    ├── 供需比 < 0.9 → 智能通知 Banner                    │
│  │    └── 点击 → Hub 触发泌乳评估流程                       │
│  │                                                           │
│  ├─ 追奶决策 → 注入追奶任务到日程                            │
│  │                                                           │
│  └─ 呵护计划 → 查看今日/Milestone/月历                      │
│       ├── 任务完成标记                                        │
│       ├── 冲突检测 + 自动调整                                │
│       └── 日结总结 + 勋章                                    │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 计划制定旅程

```
场景 A：追奶/减奶/维持
  Hub → [泌乳管理] → [追奶/减奶] → InlineLactationFlow
  → 查看泌乳阶段 / 7日趋势 / 调整目标
  → 确认追奶方案 → 注入任务到日程
  → 呵护计划自动切换到对应计划（维持/追奶/减奶）

场景 B：返工计划
  入口1: Hub → [泌乳管理] → [返工计划] → InlineWorkFlow
  入口2: Schedule → 泌乳目标卡片 → [我想制定返工计划] → 跳转Hub → InlineWorkFlow
  → 收集：返工时间 → 工作模式 → 吸奶环境 → 主要关注点
  → 生成：专属返工计划卡片 + 背奶装备清单
  → 确认启用 → 同步到呵护计划
  → 冲突检测：与待产计划互斥

场景 C：待产计划
  Hub → [泌乳管理] → [准妈妈计划] → InlineMaternityFlow
  → 收集：预产期 → 分娩方式 → 身体状况 → 主要关注点
  → 生成：专属待产计划卡片 + 待产包清单
  → 确认启用 → 同步到呵护计划
  → 冲突检测：与返工计划互斥；替换当前泌乳计划
```

### 2.4 设备管理旅程

```
Tab [设备] → /device
  ├── 查看双侧设备状态（电量/信号/连接）
  ├── 蓝牙重新配对
  ├── 智能说明书搜索 → 知识卡片
  ├── 配件拍照识别 → 结果 + 知识卡片
  └── 识别结果推送到 Hub 继续对话
```

---

## 3. 功能模块清单与路由

| 模块 | 路由 | 页面组件 | 底部 Tab | 描述 |
|------|------|---------|---------|------|
| AI 对话中心 (Agent Hub) | `/` | `AgentHub.tsx` | M.ai | 对话即中枢，所有内联工作流宿主 |
| 沉浸式吸乳 | `/pump` | `PumpSession.tsx` | *(隐藏)* | 全屏实时吸乳控制与可视化 |
| 妈妈点滴 | `/records` | `Records.tsx` | 妈妈 | 吸乳记录 + 库存管理 |
| 宝宝陪伴 | `/baby` | `BabyGrowth.tsx` | 宝宝 | 生长追踪 + 喂养平衡 |
| 呵护计划 | `/schedule` | `Schedule.tsx` | 计划 | 三视图日程规划（今日/Milestone/月历） |
| 智能设备 | `/device` | `DeviceManagement.tsx` | 设备 | 蓝牙配对 + 配件识别 + 说明书 |
| 舒适校准 | `/calibration` | `ComfortCalibration.tsx` | *(隐藏)* | 独立版力度滴定（备用入口） |

---

## 4. 各模块用户旅程与功能详述

### 4.1 Agent Hub（AI 对话中心）

**路由**: `/`  
**文件**: `src/pages/AgentHub.tsx`（870 行）

#### 4.1.1 用户旅程

```
用户打开 App
  ↓
顶部 Banner 展示：Mai 头像 + 实时速记 + 力度滴定状态
  ↓
中部对话区：消息列表（支持折叠/展开）
  ↓
底部操作区：
  ├── [开始吸乳] → 鼓励卡片 → "准备好了" → /pump
  ├── [力度滴定] → 内联 InlineCalibration 组件
  ├── [设备使用 ▲] → popover 展开 4 子项（开箱/上身/调整/保养）
  └── [泌乳管理 ▲] → popover 展开 4 子项（日程/追奶减奶/准妈妈/返工）
  ↓
底部输入栏：文字/语音/拍照 → 输入拦截路由到活跃内联流
```

#### 4.1.2 功能点

| 功能点 | 交互逻辑 |
|--------|----------|
| M.ai 头像情绪拨盘 | 点击循环切换 5 种情绪（happy/encourage/calm/thinking/alert），外圈 conic-gradient 渐变环 |
| 语音自动播报开关 | 右下角 badge 切换 `autoVoice` |
| 实时速记板 | 显示当前对话话题 + 摘要，右侧 topic link pills（最多 3 个） |
| 力度滴定状态行 | 从 `localStorage.calibration` 读取，显示左/右侧舒适档/安全限 |
| 对话折叠/展开 | 超 5 条默认折叠显示最近 3 条 |
| 消息 TTS 播放 | 每条消息右下角播放按钮，模拟 3 秒语音播放 |
| 内联工作流 | 6 种 cardType 对应 6 种内联组件（见下表） |
| Pill 分组操作 | PillGroups 组件：独立 pill（开始吸乳/力度滴定）+ 折叠组（设备使用/泌乳管理） |
| 全屏语音模式 | 麦克风按钮打开 FocusVoiceMode |
| 拍照识别 | MaiInputBar 触发配件识别 demo 流程 |

#### 4.1.3 内联工作流路由表

| cardType | 组件 | ref 变量 | 输入拦截 | 触发入口 |
|----------|------|---------|---------|---------|
| `device-flow` | `InlineDeviceFlow` | `deviceFlowRef` | `handleExternalInput(text): boolean` | 设备使用组子项 |
| `schedule-flow` | `InlineScheduleFlow` | `scheduleFlowRef` | `handleExternalInput(text): boolean` | 日程规划 pill |
| `lactation-flow` | `InlineLactationFlow` | `lactationFlowRef` | `handleExternalInput(text): boolean` | 追奶/减奶 pill / BabyGrowth 评估 |
| `maternity-flow` | `InlineMaternityFlow` | `maternityFlowRef` | `handleExternalInput(text): boolean` | 准妈妈计划 pill |
| `work-flow` | `InlineWorkFlow` | `workFlowRef` | `handleExternalInput(text): boolean` | 返工计划 pill / LactationGoalSheet |
| `calibration` | `InlineCalibration` | *(none)* | 自包含 | 力度滴定 pill |

#### 4.1.4 输入拦截优先级

```
用户输入 →
  1. deviceFlowActive? → deviceFlowRef.handleExternalInput(text)
  2. scheduleFlowActive? → scheduleFlowRef.handleExternalInput(text)
  3. lactationFlowActive? → lactationFlowRef.handleExternalInput(text)
  4. maternityFlowActive? → maternityFlowRef.handleExternalInput(text)
  5. workFlowActive? → workFlowRef.handleExternalInput(text)
  6. 以上均返回 false → 通用 Mai 回复
```

#### 4.1.5 Pill 分组结构

```
PillGroups
├── 独立 Pill：[开始吸乳] (primary) + [力度滴定] (outline)
├── 折叠组 [设备使用 ▲]
│   ├── 开箱指引 → InlineDeviceFlow(unbox)
│   ├── 上身指引 → InlineDeviceFlow(wearing-guide)
│   ├── 法兰/硅胶塞调整 → InlineDeviceFlow(measurement)
│   └── 设备保养 → InlineDeviceFlow(maintenance)
└── 折叠组 [泌乳管理 ▲]
    ├── 日程规划 → InlineScheduleFlow
    ├── 追奶/减奶 → InlineLactationFlow
    ├── 准妈妈计划 → InlineMaternityFlow
    └── 返工计划 → InlineWorkFlow
```

#### 4.1.6 跨页面事件监听

| 事件 | 来源 | 行为 |
|------|------|------|
| `navigate-to` | 各内联流程完成后 | `navigate(detail)` 跳转目标页面 |
| `hub-start-work-flow` | Schedule → LactationGoalSheet | 自动触发 `handleSceneClick("work")` 启动返工流程 |
| `chatBus.subscribe` | PumpSession / BabyGrowth | 接收报告/评估消息并追加到对话流 |

---

### 4.2 沉浸式吸乳 (PumpSession)

**路由**: `/pump`（底部导航隐藏）  
**文件**: `src/pages/PumpSession.tsx`

#### 4.2.1 用户旅程

```
从 Hub 点击 [开始吸乳] → 鼓励卡片 → "准备好了" → /pump
  ↓
选择侧别（L/R/SYNC）
  ↓
开始吸乳 → 实时流速图表 + 动画 + 进度条
  ├── 检测奶阵 → 自动切换 deep 模式
  ├── AI 托管模式可选
  ├── Mai 气泡陪伴（刺激模式=闲聊/深度模式=知识）
  ├── 音乐播放器
  └── 达标 → 庆祝动画 / 延长模式
  ↓
停止 → 退出确认 → 生成报告
  ↓
报告通过 chatBus + chatStore 推送到 Hub → 返回首页
```

#### 4.2.2 功能点

| 功能 | 描述 |
|------|------|
| 侧别选择 | L / R / SYNC 三种模式 |
| 档位控制 | 1-9 档，+/- 按钮 |
| 模式切换 | 刺激(stimulate) ↔ 深度(deep)，支持自动切换 |
| AI 托管 | 锁定控制面板，AI 自动调节档位（基于 calibration 结果） |
| 双轨流速图 | AreaChart 分别绘制 L/R 流速曲线，奶阵段 orange 高亮 |
| 拟真可视化 | BreastDrop(SVG乳房) + PumpRing(旋转环) + FlowPipes(管道) + Bottle(奶瓶) |
| MilkProgressBar | 主段(90%) + 延长段(10%)，动态游标 |
| MaiSessionBubbles | 刺激模式=闲聊(上限10条) / 深度模式=知识(上限5条) |
| MusicPlayer | 3 歌单 × 3 曲目，波形与流速状态联动 |
| 目标量解释 | MaiTargetExplainSheet 流式解释 + 滑块调整(60-100) |
| 报告生成 | 含时长/L-R 产量/完成度/奶阵信息的 ChatMessage |

#### 4.2.3 核心状态变量

```typescript
running: boolean          // 吸乳运行中
paused: boolean           // 暂停
mode: "stimulate" | "deep"  // 当前模式
activeSide: "L" | "R" | "SYNC"  // 侧别
gearL / gearR: number     // 左右档位 1-9
totalL / totalR: number    // 累计奶量 mL
isLetdown: boolean         // 奶阵检测
bottlePct: number          // 完成百分比
elapsed: number            // 已运行秒数
```

#### 4.2.4 关键阈值

| 阈值 | 值 | 用途 |
|------|---|------|
| 奶阵流速 | > 3.0 mL/min | 触发奶阵判定 |
| 低流速 | < 0.8 mL/min | 10s 后自动切 deep |
| 目标量范围 | 60-100 mL | 用户可调 |

---

### 4.3 妈妈点滴 (Records)

**路由**: `/records`  
**文件**: `src/pages/Records.tsx`

#### 4.3.1 用户旅程

```
Tab [妈妈] → /records
  ↓
今日概览三指标：总奶量 / 吸奶次数 / 7日均量
  ↓
7日趋势面积图 + Mai 批注
  ↓
记录列表：
  ├── 设备记录（不可编辑/删除）
  ├── 手动/语音记录（左滑编辑/删除）
  └── [补录] → ManualEntryDialog
  ↓
FloatingMaiButton → 语音模式 / RecordAgentDrawer → 补录/趋势分析
```

#### 4.3.2 功能点

| 功能 | 交互逻辑 |
|------|----------|
| 今日三指标 | 实时联动：增删记录后自动更新 |
| 7日趋势图 | AreaChart 平滑面积图 + Mai 情绪批注 |
| 来源徽标 | 📱设备 / ✍️手动 / ✨Mai记 |
| 手动补录 | ManualEntryDialog：mL/oz 输入，支持编辑模式 |
| 库存补录 | InventoryEntryDialog：补录 / 配方奶 双选 |
| 左滑操作 | `PanInfo.offset.x < -80` 显示编辑/删除 |
| Agent 问答 | RecordAgentDrawer：补录 / 趋势咨询 |
| 单位切换 | 全局 mL ↔ oz（volumeUnitStore） |

#### 4.3.3 数据筛选规则

| 指标 | 纳入条件 (`isPumpMilk`) |
|------|------------------------|
| 今日总奶量 | `source === "device"` 或 `(非亲喂且非配方奶且非瓶喂)` |
| 吸奶次数 | 同上 |
| 7日均奶量 | 过去7天同上条件的总量 ÷ 7 |

---

### 4.4 宝宝陪伴 (BabyGrowth)

**路由**: `/baby`  
**文件**: `src/pages/BabyGrowth.tsx`

#### 4.4.1 用户旅程

```
Tab [宝宝] → /baby
  ↓
宝宝基本信息（昵称 + 日龄/周龄）
  ↓
生长指标折叠卷轴：
  ├── 折叠态：体重/身长/头围摘要
  └── 展开态：百分位标尺(可编辑) + WHO体重曲线
  ↓
智能通知 Banner（供需比 < 0.9 时显示）
  → 点击 → 跳转 Hub → 触发泌乳评估流程
  ↓
今日喂养平衡卡片：
  ├── 左列：可用乳源（母乳库存 + 配方奶）
  └── 右列：宝宝需求估计（P25-P50-P75）
  ↓
喂养记录列表：添加配方奶/亲喂/瓶喂
  ↓
FloatingMaiButton → 语音模式 / GrowthChatDrawer
```

#### 4.4.2 供需平衡计算

```
供给侧：
  设备产出 = Σ(totalMl) where source="device" AND date=today
  手动补录 = Σ(totalMl) where subLabel="补录" AND source≠"device" AND date=today
  可用母乳库存 = 设备产出 + 手动补录
  配方奶 = Σ(totalMl) where subLabel="配方奶" AND date=today
  今日总可用 = 可用母乳库存 + 配方奶

需求侧：
  P50 = 宝宝体重(kg) × 150
  P25 = 宝宝体重(kg) × 120
  P75 = 宝宝体重(kg) × 180

供需比 = 今日总可用 / P50
```

#### 4.4.3 供需比判定

| 供需比 | 文案 | 触发 |
|--------|------|------|
| < 0.7 | "今日供给偏少" | Banner → 评估流程 |
| 0.7~0.9 | "还差一点点" | Banner → 评估流程 |
| 0.9~1.2 | "供需匹配" | 无 |
| > 1.2 | "供给充足" | 无 |
| > 1.5 | "非常充足" | 无 |

---

### 4.5 呵护计划 (Schedule) ⭐ v1.2 重构

**路由**: `/schedule`  
**文件**: `src/pages/Schedule.tsx`（603 行）

#### 4.5.1 用户旅程

```
Tab [计划] → /schedule
  ↓
页面标题：📅 呵护计划 + 日结按钮 + 提醒开关
  ↓
Milky.Way 泌乳周期进度条（待产模式时半透明）
  ↓
泌乳目标卡片：
  ├── 当前目标（维持/追奶/减奶/待产/返工）+ 摘要
  ├── [问问Mai] → ScheduleAgentDrawer
  ├── [调整→] → LactationGoalSheet
  │   ├── [询问M.ai设定奶量目标] → Agent
  │   └── [我想制定返工计划] → 跳转Hub → InlineWorkFlow  ⭐新增
  ↓
三 Tab 视图切换：[今日] [Milestone] [月历]  ⭐新增
  ↓
今日 Tab：
  ├── 活跃计划横条（点击→切到Milestone）
  ├── 任务列表（折叠/展开）
  │   ├── 任务行：时间 + 图标 + 标题 + 状态标签
  │   └── 操作：完成/顺延/来源标记
  └── 底部操作组（添加避让/截图识别/Mai协助）
  ↓
Milestone Tab：
  └── MilestoneTimeline 组件
      ├── 计划选择器下拉（显示所有计划，标记进行中/互斥/可并行）
      ├── 垂直时间轴：每个里程碑
      │   ├── 时间节点（已过/当前/未来）
      │   ├── 当前里程碑 Mai 鼓励语
      │   └── 循环任务列表（按间隔展开前5天）
      └── 并行计划数量标记
  ↓
月历 Tab：
  └── PlanCalendarView 组件
      ├── 年/月导航
      ├── 图例（活跃计划颜色 + 里程碑起点标记）
      ├── 7×N 日历网格
      │   ├── 计划覆盖色带（多计划垂直堆叠）
      │   ├── 里程碑起点高亮色块
      │   └── 底部彩色圆点标记
      └── 点击日期 → tooltip 展示关联计划详情
```

#### 4.5.2 计划体系 ⭐ v1.2 核心新增

##### 计划清单

| Plan ID | 名称 | Emoji | 类型 | 互斥规则 |
|---------|------|-------|------|---------|
| `maintain` | 维持奶量 | 🥛 | 泌乳计划 | 与 chase/wean/fertility 互斥 |
| `chase` | 安心追奶 | 🚀 | 泌乳计划 | 与 maintain/wean/fertility 互斥 |
| `wean` | 稳步减奶 | 🌿 | 泌乳计划 | 与 maintain/chase/fertility 互斥 |
| `fertility` | 待产计划 | 🤰 | 泌乳计划 | 与 maintain/chase/wean 互斥，与 work 互斥 |
| `work` | 返工计划 | 💼 | 并行计划 | 可与 maintain/chase/wean 并行，与 fertility 互斥 |

##### 互斥规则实现

```typescript
// LACTATION_PLAN_IDS = ["maintain", "chase", "wean", "fertility"]
// PARALLEL_PLAN_IDS = ["work"]

activateLactationPlan(planId):
  1. 移除当前泌乳计划
  2. 保留并行计划
  3. 若 planId === "fertility" → 同时移除 work
  4. 设置新计划 → 持久化 → 派发 activePlansUpdated 事件

toggleWorkPlan(active):
  1. 若 active 且当前有 fertility → 静默拒绝
  2. 否则添加/移除 work → 持久化 → 派发事件
```

##### 每个计划的里程碑结构

```typescript
interface Plan {
  id: string;
  name: string;
  emoji: string;
  currentMilestoneIndex: number;
  maiSummary: string;           // 当前里程碑 Mai 鼓励语
  milestones: Milestone[];
}

interface Milestone {
  id: string;
  label: string;
  startDate: string;           // "YYYY-MM-DD"
  durationWeeks: number;
  tasks: MilestoneTask[];
}

interface MilestoneTask {
  title: string;
  icon: string;                // emoji 图标
  intervalDays: number;        // 任务循环间隔（1=每日）
}
```

##### 各计划里程碑详情

| 计划 | 里程碑 | 开始日期 | 周数 | 核心任务 |
|------|--------|---------|------|---------|
| 维持奶量 | 建立基础 | 01/03 | 4 | 双侧吸奶20min + 亲喂练习 + 记录 |
| | 稳定产量 | 01/31 | 6 | 5次/天 + 夜间1次 + 称量检查 |
| | 自如维持 ← 当前 | 03/10 | 8 | 4-5次/天 + 体重监测 + 营养补充 |
| | 长期平稳 | 05/09 | 12 | 按需吸奶 + 月度回顾 |
| 安心追奶 | 频率提升 | 03/01 | 2 | 7次/天 + Power Pumping + 饮水2L |
| | 巩固增量 ← 当前 | 03/15 | 3 | 6-7次/天 + 夜间加吸 + 趋势分析 |
| | 达标评估 | 04/05 | 2 | 回调至5次 + 目标检查 |
| 稳步减奶 | 缓慢起步 ← 当前 | 03/20 | 2 | 减至4次/天 + 缩短时长 + 舒适检查 |
| | 持续递减 | 04/03 | 3 | 减至3次 + 乳腺监测 |
| | 安全离乳 | 04/24 | 2 | 减至1-2次 + 完全停止评估 |
| 待产计划 | 营养储备 ← 当前 | 04/01 | 4 | 叶酸 + 铁钙检测 + 调整频率 |
| | 身体调适 | 04/29 | 4 | 产检 + 体温监测 + 泌乳渐减 |
| | 待产就绪 | 05/27 | 4 | 产前检查 + 运动休息 |
| 返工计划 | 返工准备 | 02/15 | 2 | 储奶练习 + 背奶包 + 模拟排程 |
| | 适应期 ← 当前 | 03/01 | 3 | 工位吸奶 + 午休提醒 + 储奶记录 |
| | 游刃有余 | 03/22 | 4 | 弹性节奏 + 周末亲喂 + 月度回顾 |

##### 今日任务生成算法

```typescript
generateTodayTasks():
  1. 获取 activePlanIds
  2. 对每个活跃计划，找到覆盖今天的里程碑
  3. 计算 dayInMilestone（今天是该里程碑的第几天）
  4. 对每个任务，检查 intervalDays：
     - intervalDays === 1 → 使用所有时间槽
     - intervalDays > 1 且 dayInMs % interval !== 0 → 跳过
  5. 合并所有计划任务，按 time 排序去重
```

#### 4.5.3 原有功能（保留）

| 功能 | 描述 |
|------|------|
| Milky.Way 泌乳周期 | 4阶段进度条，待产模式时半透明 |
| 任务顺延 | 单条 +30min，级联后续任务 |
| 避让时段 | BlockedSlotDialog 添加，冲突任务自动调整 |
| OCR 日程识别 | ScheduleAgentDrawer(context: "ocr") 识别冲突 |
| 追奶任务注入 | localStorage + chaseMilkUpdated 事件 |
| 日结总结 | DayEndSummary 动画（列表→划线→勋章） |
| 提醒开关 | ReminderAlert 强挽留弹窗 |

---

### 4.6 InlineWorkFlow（返工计划内联流程）⭐ v1.2 新增

**文件**: `src/components/work/InlineWorkFlow.tsx`（466 行）  
**宿主**: AgentHub 对话流（`cardType: "work-flow"`）

#### 状态机

```
greeting → ask-return-date → ask-work-mode → ask-pump-env → ask-concern
  → assessing → [plan-card + pack-card] → ask-adjust
  → accept → syncPlanToSchedule → done
  → adjust → adjust-confirm (文字输入) → confirm-adjusted → done
```

#### 收集的用户数据

| 字段 | 选项 |
|------|------|
| 返工时间 | 已经返工 / 1-2周内 / 1个月内 / 还没确定 |
| 工作模式 | 全天坐班 / 居家办公 / 混合办公 / 弹性兼职 |
| 吸奶环境 | 有母婴室 / 有独立办公室 / 需要找空间 / 还不确定 |
| 主要关注 | 奶量下降 / 时间不够用 / 储奶和运输 / 同事的眼光 |

#### 输出产物

| 产物 | 内容 |
|------|------|
| 专属返工计划卡片 | 展示 work plan 的 3 个里程碑及其任务 |
| 背奶装备清单 | 4 大类：背奶装备 / 办公室必备 / 妈妈能量 / 储存方案 |

#### 互斥检测

```typescript
// 启动时检查 fertility 冲突
if (hasFertilityConflict()) {
  // 展示冲突提示 → 直接进入 done
  // "返工计划与待产计划互斥，无法同时进行"
}
```

#### 同步到计划体系

```typescript
syncPlanToSchedule():
  1. toggleWorkPlan(true)  // 激活 work 计划
  2. setCurrentGoal({ planId: "work", label: "返工计划", summary: "..." })
  3. refreshTodayTasks()   // 重新生成今日任务
```

---

### 4.7 InlineMaternityFlow（待产计划内联流程）⭐ v1.2 新增

**文件**: `src/components/maternity/InlineMaternityFlow.tsx`（424 行）  
**宿主**: AgentHub 对话流（`cardType: "maternity-flow"`）

#### 状态机

```
greeting → ask-due-date → ask-delivery → ask-condition → ask-concern
  → assessing → [plan-card + bag-card] → ask-adjust
  → accept → syncPlanToSchedule → done
  → adjust → adjust-confirm (文字输入) → confirm-adjusted → done
```

#### 收集的用户数据

| 字段 | 选项 |
|------|------|
| 预产期 | 2026年7月 / 8月 / 9月 / 还不确定 |
| 分娩方式 | 顺产 / 剖宫产 / 还在考虑中 |
| 身体状况 | 状态很好 / 有些疲劳 / 有孕期不适 / 有医生特别嘱咐 |
| 主要关注 | 产后母乳喂养 / 分娩过程 / 产后恢复 / 新生儿护理 |

#### 输出产物

| 产物 | 内容 |
|------|------|
| 专属待产计划卡片 | 展示 fertility plan 的 3 个里程碑及其任务 |
| 待产包清单 | 4 大类：妈妈用品 / 宝宝用品 / 证件资料 / 吸乳相关 |

#### 同步到计划体系

```typescript
syncPlanToSchedule():
  1. activateLactationPlan("fertility")  // 替换泌乳计划，移除 work
  2. setCurrentGoal({ planId: "fertility", label: "待产计划", summary: "..." })
  3. refreshTodayTasks()
```

---

### 4.8 InlineDeviceFlow（设备指导内联流程）

**文件**: `src/components/device/InlineDeviceFlow.tsx`（752 行）

#### 流程类型

| flowType | 描述 | 触发入口 |
|----------|------|---------|
| `unbox` | 完整开箱引导（BT→配件→组装→穿戴→测量→标定） | 设备使用组 - 开箱指引 |
| `wearing-guide` | 上身穿戴指引 | 设备使用组 - 上身指引 |
| `measurement` | 法兰/硅胶塞尺寸测量 | 设备使用组 - 法兰调整 |
| `maintenance` | 设备保养指引 | 设备使用组 - 设备保养 |
| `photo-identify` | 拍照识别配件 | 拍照菜单 |

---

### 4.9 InlineLactationFlow（泌乳管理内联流程）

**文件**: `src/components/lactation/InlineLactationFlow.tsx`（567 行）

#### 功能分支

| initialAction | 描述 |
|---------------|------|
| `view-phase` | 展示 Milky.Way 周期卡片 + 阶段说明 |
| `view-trend` | 7日产量 max/min/trend 趋势分析 |
| `goal-adjust` | 三选目标（增/维持/减）+ 风险告知 + 确认 |
| `growth-assess` | 从 BabyGrowth 触发的供需评估决策树 |

#### 生长评估决策树

```
growth-assess
  ├── 展示供需比 + 亲喂说明
  ├── "有漏记" → 建议补录
  └── "记录齐了" → 量化评估
      ├── ratio < 0.85 → 偏少 → 追奶方案
      ├── 0.85~1.3 → 匹配 → 满意/想多/想减
      └── ratio > 1.3 → 充裕 → 减量/保持
```

---

### 4.10 InlineCalibration（力度滴定）

**文件**: `src/components/calibration/InlineCalibration.tsx`（296 行）

#### 流程

```
wear → explain → stimulate(档位递增+反馈) → rest(10s) → deep(同上) → result → askPump
```

#### 反馈 Pill → 结果计算

```
🌱 "刚有感觉" → minEffective 候选
🌊 "很舒适"   → cozy 候选
💪 "吸力很大" → 继续
😣 "有点勉强" → 接近上限
🛑 "疼！快停下" → maxSafe = 当前档位 - 1

最终：cozyGear / maxSafeGear / minEffectiveGear
存储：localStorage("calibration")
```

---

### 4.11 InlineScheduleFlow（日程规划内联流程）

**文件**: `src/components/schedule/InlineScheduleFlow.tsx`（550 行）

#### Action 路由表

| action | 行为 |
|--------|------|
| `view-tasks` | 展示任务列表 |
| `add-avoidance` | 等待输入 → 添加避让 → 冲突调整 |
| `delay-next` | 顺延第一个未完成非会议任务 30min |
| `screenshot-schedule` | OCR 识别 → 确认重排 |
| `day-summary` | 完成率+产量+鼓励 |
| `view-phase` | Milky.Way 阶段卡片 |
| `goal-adjust` | 目标三选 |
| `goal-increase/decrease` | 风险告知 → 确认注入/移除任务 |

---

### 4.12 全屏语音模式 (FocusVoiceMode)

**文件**: `src/components/voice/FocusVoiceMode.tsx`（273 行）

| 状态 | 视觉 | 交互 |
|------|------|------|
| Mai 说话 | 光晕快速脉动 + 逐字字幕 | 点击 → Barge-in 打断 |
| 用户说话 | 麦克风涟漪 + "正在聆听..." | 等待识别 |
| 空闲 | 光晕缓慢呼吸 | 点击开始说话 |

---

### 4.13 设备管理 (DeviceManagement)

**路由**: `/device`  
**文件**: `src/pages/DeviceManagement.tsx`

| 功能 | 描述 |
|------|------|
| 双侧设备卡 | L/R 各自显示型号/电量/信号/连接 |
| 蓝牙搜索 | BluetoothSearchDrawer 模拟搜索配对 |
| 智能说明书 | 可搜索知识卡片列表 |
| 配件识别 | 拍照/上传/Demo → 识别结果 → 推送Hub |
| 设备详情 | DeviceInfoSheet 固件/序列号等 |
| 设备问答 | MaiChatDrawer 半屏对话 |

---

## 5. 数据接口与变量要求

### 5.1 核心数据模型

#### 5.1.1 PumpRecord（统一记录模型）

```typescript
interface PumpRecord {
  id: string;
  date: string;                                        // "YYYY-MM-DD"
  time: string;                                        // "HH:mm"
  durationMin: number;
  leftMl: number;
  rightMl: number;
  totalMl: number;
  source: "device" | "manual" | "voice";
  mode: "stimulate" | "deep";
  subLabel?: "补录" | "亲喂" | "配方奶" | "瓶喂";
  category?: "inventory" | "feeding";
}
```

**分类规则：**

| source | subLabel | category | 归属模块 |
|--------|----------|----------|---------|
| `device` | *(空)* | `inventory` | 妈妈点滴 |
| `manual` | `补录` | `inventory` | 妈妈点滴 |
| `voice` | `补录` | `inventory` | 妈妈点滴 |
| `manual` | `配方奶` | `feeding` | 宝宝陪伴 |
| `manual` | `亲喂` | `feeding` | 宝宝陪伴 |
| `manual` | `瓶喂` | `feeding` | 宝宝陪伴 |

#### 5.1.2 ScheduleTask（日程任务）

```typescript
interface ScheduleTask {
  id: string;
  time: string;                                // "HH:mm"
  type: "pump" | "feed" | "meeting";
  title: string;
  done: boolean;
  adjusted?: string;
  source?: "mai" | "manual" | "device";
  reason?: string;                             // 所属计划名称
}
```

#### 5.1.3 Plan（计划模型）⭐ v1.2 新增

```typescript
interface Plan {
  id: string;                                  // "maintain" | "chase" | "wean" | "fertility" | "work"
  name: string;
  emoji: string;
  currentMilestoneIndex: number;
  maiSummary: string;
  milestones: Milestone[];
}

interface Milestone {
  id: string;
  label: string;
  startDate: string;                           // "YYYY-MM-DD"
  durationWeeks: number;
  tasks: MilestoneTask[];
}

interface MilestoneTask {
  title: string;
  icon: string;
  intervalDays: number;                        // 1=每日, 2=隔日, 7=每周, etc.
}
```

#### 5.1.4 ChatMessage（对话消息）

```typescript
interface ChatMessage {
  id: string;
  role: "mai" | "user";
  content: string;
  timestamp: string;
  cardType?: CardType;
  cardData?: Record<string, unknown>;
  links?: ChatMessageLink[];
}

type CardType =
  | "report" | "data" | "tutorial" | "plan" | "encourage"
  | "calibration" | "device-flow" | "schedule-flow"
  | "lactation-flow" | "maternity-flow" | "work-flow";    // ⭐ 新增2种
```

#### 5.1.5 其他数据模型（保持不变）

- `BabyData` / `GrowthRecord` — 宝宝生长数据
- `DeviceInfo` — 设备信息
- `CalibrationResult` — 力度标定结果
- `KnowledgeCardData` — 知识卡片
- `PhotoIdentifyResult` — 配件识别结果
- `VolumeUnit` — mL/oz 单位

### 5.2 全局状态管理

| 模块 | 文件 | 机制 | 用途 |
|------|------|------|------|
| `chatStore` | `src/lib/chatStore.ts` | 内存单例 + getter/setter | Hub 消息/情绪/速记 |
| `chatBus` | `src/lib/chatBus.ts` | pub/sub + pending queue | 跨页面消息推送 |
| `volumeUnitStore` | `src/lib/volumeUnit.ts` | localStorage + pub/sub | mL ↔ oz 同步 |
| `planMockData` | `src/data/planMockData.ts` | localStorage + CustomEvent | 计划状态 + 任务生成 ⭐ |

### 5.3 localStorage 持久化键表

| Key | 类型 | 用途 |
|-----|------|------|
| `calibration` | `{ L?: CalibResult, R?: CalibResult } \| CalibResult` | 力度标定结果 |
| `volume-unit` | `"mL" \| "oz"` | 全局单位 |
| `chaseMilkTasks` | `ScheduleTask[]` | 追奶任务 |
| `activePlanIds` | `string[]` | 当前活跃计划 ID 列表 ⭐ |
| `currentLactationGoal` | `{ planId, label, summary }` | 当前泌乳目标 ⭐ |

### 5.4 CustomEvent 事件表

| 事件名 | Payload | 用途 |
|--------|---------|------|
| `chaseMilkUpdated` | *(none)* | 追奶任务变更 → Schedule 重载 |
| `inventoryRecordAdded` | `{ detail: PumpRecord }` | BabyGrowth → Records 补录同步 |
| `navigate-to` | `{ detail: string(route) }` | 内联流程 → 页面跳转 |
| `hub-start-work-flow` | *(none)* | Schedule → Hub 启动返工流程 ⭐ |
| `activePlansUpdated` | `{ detail: string[] }` | 计划变更 → 各组件刷新 ⭐ |
| `goalUpdated` | `{ detail: { planId, label, summary } }` | 目标变更 → Schedule 刷新 ⭐ |
| `todayTasksRefresh` | *(none)* | 触发今日任务重新生成 ⭐ |

---

## 6. 功能实现逻辑

### 6.1 计划切换逻辑 ⭐ v1.2

```
用户在 InlineLactationFlow 中确认"追奶"
  → activateLactationPlan("chase")
    → 移除当前泌乳计划(maintain)
    → 保留并行计划(work)
    → localStorage 持久化 ["chase", "work"]
    → 派发 activePlansUpdated 事件
  → setCurrentGoal({ planId: "chase", label: "安心追奶", summary: "..." })
    → localStorage 持久化
    → 派发 goalUpdated 事件
  → refreshTodayTasks()
    → 派发 todayTasksRefresh 事件
    → Schedule 监听 → generateTodayTasks() 重新生成

用户在 InlineMaternityFlow 中确认"待产计划"
  → activateLactationPlan("fertility")
    → 移除当前泌乳计划(chase)
    → fertility 时同时移除 work
    → localStorage 持久化 ["fertility"]
    → 派发 activePlansUpdated 事件
  → ...同上
```

### 6.2 今日任务动态生成 ⭐ v1.2

```typescript
// 时间槽模板
timeSlotsByType = {
  "🍼": ["06:30", "10:00", "14:00", "18:00", "21:00"],  // 每日多槽
  "🤱": ["08:00", "11:30", "17:00"],
  "🌙": ["03:00"],
  // ... 每种 icon 有预设时间槽
}

// 生成逻辑
for (planId of activePlanIds):
  plan = findPlan(planId)
  currentMs = findCoveringMilestone(plan, today)
  dayInMs = daysSince(currentMs.startDate)
  
  for (task of currentMs.tasks):
    if (task.intervalDays > 1 && dayInMs % intervalDays !== 0): skip
    slots = intervalDays === 1 ? allSlots : [firstSlot]
    for (slot of slots):
      tasks.push(ScheduleTask)

tasks.sort(byTime).deduplicate()
```

### 6.3 月历视图渲染 ⭐ v1.2

```
for each day in month:
  for each active plan:
    for each milestone in plan:
      if day in [startDate, startDate + durationWeeks*7):
        add color band to day cell
        if day === startDate:
          mark as milestone start (vibrant dot)

deduplication:
  per planId per day, prefer isMilestoneStart = true
```

### 6.4 吸乳报告推送

```
用户点击停止 → 确认退出
  → pushSessionSummary():
      reportMsg = { cardType: "report", cardData: { duration, leftMl, rightMl, totalMl, pct, letdown... } }
      encourageMsg = { cardType: "encourage", content: 个性化分析 }
      chatStore.setMessages([...existing, reportMsg, encourageMsg])
  → 100ms 后 navigate("/")
  → AgentHub 从 chatStore 恢复渲染
```

### 6.5 供需评估 → 追奶干预

```
BabyGrowth 计算 supplyRatio < 0.9
  → Banner 显示
  → 用户点击
  → chatBus.push({ cardData: { triggerFlow: "lactation", initialAction: "growth-assess", assessContext } })
  → navigate("/")
  → AgentHub subscribe → 800ms 后注入 lactation-flow 卡片
  → InlineLactationFlow 展示供需分析 → 追奶方案 → 注入任务到 localStorage
```

### 6.6 冲突检测与任务调整

```
添加避让时段 { start, end, title }:
  for task in tasks:
    if task.type === "pump" && task.time ∈ [start, end):
      task.time = start - 30min
      task.adjusted = "因避开时段提前"
  sort by time

手动顺延:
  task.time += 30min
  for 后续任务 where time <= 当前任务.time:
    级联顺延 30min
  设置 adjusted 标记
```

---

## 7. 跨模块数据联动

### 7.1 联动全景图

```
PumpSession ──(chatBus.push)───────→ AgentHub (报告卡片)
BabyGrowth  ──(chatBus.push)───────→ AgentHub (供需评估)

InlineLactationFlow ──(localStorage "chaseMilkTasks")──→ Schedule (追奶任务注入)
InlineWorkFlow      ──(toggleWorkPlan + refreshTodayTasks)──→ Schedule (返工任务)
InlineMaternityFlow ──(activateLactationPlan + refreshTodayTasks)──→ Schedule (待产任务)

Schedule.LactationGoalSheet ──(hub-start-work-flow)──→ AgentHub (启动返工流程)

BabyGrowth ──(inventoryRecordAdded)──→ Records (库存同步)
Calibration ──(localStorage "calibration")──→ PumpSession (档位默认值)

activePlansUpdated ──→ MilestoneTimeline + PlanCalendarView (刷新视图)
goalUpdated ──→ Schedule (刷新目标卡片)
todayTasksRefresh ──→ Schedule (重新生成任务)
```

### 7.2 关键链路

| 链路 | 流程 |
|------|------|
| A: 宝宝供需不足→追奶 | BabyGrowth(ratio<0.9) → Banner → chatBus → Hub → InlineLactationFlow → chaseMilkTasks → Schedule |
| B: 吸乳→报告→记录 | PumpSession(stop) → chatBus → Hub(报告卡) → Records(数据同步) |
| C: 返工计划→日程同步 | Hub(InlineWorkFlow) → toggleWorkPlan → activePlansUpdated → Schedule(三视图刷新) |
| D: 待产计划→全局切换 | Hub(InlineMaternityFlow) → activateLactationPlan("fertility") → 移除work → Schedule刷新 |
| E: 力度标定→吸乳 | InlineCalibration → localStorage → PumpSession(AI托管默认值) |
| F: 设备识别→Hub对话 | DeviceManagement → chatBus → Hub(教程卡片) |

---

## 8. UI/UX 规范

### 8.1 色彩系统

#### 基础 Token（HSL）

| Token | 亮色 HSL | 用途 |
|-------|---------|------|
| `--background` | `30 25% 97%` | 温暖米白背景 |
| `--foreground` | `343 35% 18%` | 深酒红文字 |
| `--primary` | `343 40% 27%` | 勃艮第主色 |
| `--secondary` | `340 25% 92%` | 浅玫瑰粉 |
| `--accent` | `340 35% 85%` | 粉色强调 |
| `--destructive` | `0 72% 51%` | 危险色 |
| `--mai-felt` | `343 40% 27%` | 毛毡质感 |
| `--mai-blush` | `350 60% 80%` | 腮红粉 |
| `--mai-warm` | `25 80% 70%` | 暖橘色 |
| `--mai-glow` | `340 45% 65%` | 发光色 |

#### 计划专属色 ⭐ v1.2

| 计划 | 背景 | 边框 | 文字 | 里程碑标记 |
|------|------|------|------|-----------|
| maintain | `teal-200` | `teal-400` | `teal-800` | `bg-teal-500` |
| chase | `amber-100` | `amber-300` | `amber-700` | `bg-orange-500` |
| wean | `emerald-100` | `emerald-300` | `emerald-700` | `bg-sky-500` |
| fertility | `pink-100` | `pink-300` | `pink-700` | `bg-pink-500` |
| work | `violet-100` | `violet-300` | `violet-700` | `bg-violet-500` |

### 8.2 字体规范

| 层级 | 尺寸 | 用途 |
|------|------|------|
| 极小标签 | `8-9px` | 版本号、里程碑标记、计划标签 |
| 辅助 | `10-11px` | 时间戳、pill、状态行 |
| 正文 | `12-13px` | 对话气泡、卡片内容 |
| 小标题 | `14px` | 卡片标题 |
| 标题 | `18px` | 页面标题 |

### 8.3 全局组件

| 组件 | 功能 |
|------|------|
| `AppLayout` | 安全区顶栏 + max-width 430px + 版本号 `mai.agenticapp_v1.2alpha_FZD_20260320` |
| `BottomNav` | 5 Tab（M.ai/妈妈/宝宝/计划/设备），`/pump` 时隐藏 |
| `FloatingMaiButton` | 非首页可拖拽悬浮按钮 → 语音模式 |
| `MaiAvatar` | 5 情绪 + 5 尺寸(xs/sm/md/lg/xl) + 动画 |
| `MaiInputBar` | 文字/语音/拍照统一输入栏 |
| `PillGroups` | 分组折叠式操作药丸（独立+设备使用组+泌乳管理组） |

### 8.4 动画系统

| 名称 | 时长 | 用途 |
|------|------|------|
| `mai-anim-breathe` | 3s | 平静呼吸 |
| `mai-anim-bounce` | 1.8s | 开心弹跳 |
| `mai-anim-nod` | 2.2s | 鼓励点头 |
| `mai-anim-sway` | 2.5s | 思考摇摆 |
| `mai-anim-tremble` | 1.5s | 担忧颤抖 |
| `mai-anim-pulse` | 1s | 警示脉冲 |

---

## 9. 外部集成与环境变量

### 9.1 当前状态

当前为**纯前端 Mock 数据驱动**原型，无后端服务、无外部 API。

### 9.2 需后端 API 替代的 Mock

| 功能 | 当前实现 | 所需 API |
|------|---------|---------|
| 计划管理 | localStorage + 内存 | `CRUD /api/plans` + `POST /api/plans/activate` |
| 吸乳记录 | 内存 state + mock | `CRUD /api/pump-records` |
| 宝宝生长 | 硬编码 babyData | `GET/PUT /api/baby/growth` |
| 日程任务 | 内存 + localStorage | `CRUD /api/schedule/tasks` |
| 设备信息 | 硬编码 | BLE SDK + `GET /api/devices` |
| 配件识别 | 3 个 demo 结果 | CV 模型 API |
| 力度标定 | localStorage | `POST /api/calibration/results` |
| Mai 对话 | 硬编码回复 | LLM API（流式 SSE） |
| 语音 TTS/STT | 模拟 | Web Speech API / 第三方 |
| 音乐播放 | 仅 UI | 音频文件 + Web Audio API |
| 通知 | 仅 Banner | Push Notification API |

### 9.3 数据库 Schema（建议 PostgreSQL）

保持 v1.0 定义的 10 张表不变（users, babies, baby_growth_records, pump_records, schedule_tasks, blocked_slots, devices, calibration_results, chat_messages, lactation_goals），新增：

#### plans 表 ⭐

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `text` PK | 计划 ID（maintain/chase/wean/fertility/work） |
| `user_id` | `uuid` FK → users | 所属用户 |
| `active` | `boolean` | 是否激活 |
| `current_milestone_index` | `integer` | 当前里程碑索引 |
| `custom_data` | `jsonb` | 自定义数据（返工时间/预产期等） |
| `activated_at` | `timestamptz` | 激活时间 |

### 9.4 环境变量

| 变量名 | 用途 | 类型 |
|--------|------|------|
| `VITE_SUPABASE_URL` | 数据库 URL | 公开 |
| `VITE_SUPABASE_ANON_KEY` | 匿名密钥 | 公开 |
| `OPENAI_API_KEY` | LLM 对话 | 私密 |
| `TTS_API_KEY` | 语音合成 | 私密 |
| `STT_API_KEY` | 语音识别 | 私密 |
| `OCR_API_KEY` | 日程识别 | 私密 |
| `PUSH_VAPID_KEY` | Web Push | 私密 |

---

## 附录 A：完整文件清单

```
src/pages/
├── AgentHub.tsx              — Hub 主页（870 行）
├── BabyGrowth.tsx            — 宝宝陪伴
├── PumpSession.tsx           — 沉浸吸乳
├── Records.tsx               — 妈妈点滴
├── Schedule.tsx              — 呵护计划（603 行）⭐ v1.2 重构
├── DeviceManagement.tsx      — 设备管理
├── ComfortCalibration.tsx    — 舒适度测试页
├── MomDigitalTwin.tsx        — 妈妈数字孪生
├── Index.tsx                 — 路由入口
└── NotFound.tsx

src/components/
├── Mai/
│   ├── MaiAvatar.tsx         — 多情绪头像
│   ├── MaiInputBar.tsx       — 统一输入栏
│   └── FloatingMaiButton.tsx — 悬浮按钮
├── baby/
│   ├── ChaseMilkDrawer.tsx   — 追奶计划
│   ├── FeedingEntryDialog.tsx — 喂养记录
│   ├── FeedingMatchDrawer.tsx — 喂养匹配
│   ├── GrowthChatDrawer.tsx  — 生长问答
│   └── PercentileGauge.tsx   — 百分位标尺
├── calibration/
│   └── InlineCalibration.tsx — 内联力度滴定
├── device/
│   ├── BluetoothSearchDrawer.tsx
│   ├── DeviceInfoSheet.tsx
│   ├── InlineDeviceFlow.tsx
│   ├── KnowledgeCardSheet.tsx
│   └── MaiChatDrawer.tsx
├── lactation/
│   └── InlineLactationFlow.tsx
├── layout/
│   ├── AppLayout.tsx         — 全局布局
│   └── BottomNav.tsx         — 底部导航
├── maternity/
│   └── InlineMaternityFlow.tsx — 待产计划 ⭐ v1.2
├── mom/
│   ├── BreastModel.tsx
│   ├── LactationChatDrawer.tsx
│   ├── MilkIcons.tsx
│   └── TrendRecordChatDrawer.tsx
├── pills/
│   └── PillGroups.tsx        — Pill 分组组件 ⭐ v1.2
├── pump/
│   ├── MaiSessionBubbles.tsx
│   ├── MaiTargetExplainSheet.tsx
│   ├── MilkProgressBar.tsx
│   └── MusicPlayer.tsx
├── records/
│   ├── ConfirmDialog.tsx
│   ├── InventoryEntryDialog.tsx
│   ├── ManualEntryDialog.tsx
│   └── RecordAgentDrawer.tsx
├── schedule/
│   ├── BlockedSlotDialog.tsx
│   ├── DayEndSummary.tsx
│   ├── InlineScheduleFlow.tsx
│   ├── LactationGoalSheet.tsx — 增加返工入口 ⭐ v1.2
│   ├── MilestoneTimeline.tsx  — 里程碑时间轴 ⭐ v1.2
│   ├── PlanCalendarView.tsx   — 月历视图 ⭐ v1.2
│   ├── ReminderAlert.tsx
│   └── ScheduleAgentDrawer.tsx
├── voice/
│   ├── FocusVoiceMode.tsx
│   └── VoiceChatHistory.tsx
└── work/
    └── InlineWorkFlow.tsx     — 返工计划 ⭐ v1.2

src/data/
├── mockData.ts               — 核心 Mock 数据
├── deviceMockData.ts         — 设备 Mock 数据
└── planMockData.ts           — 计划体系数据 ⭐ v1.2

src/lib/
├── chatBus.ts
├── chatStore.ts
├── volumeUnit.ts
└── utils.ts
```

## 附录 B：v1.2 vs v1.1 变更对照表

| 模块 | v1.1 实现 | v1.2 变更 |
|------|----------|----------|
| 计划体系 | 单一泌乳目标（追奶/维持/减奶） | 5 计划并行体系 + 互斥/并行规则 |
| 日程页面 | 单一任务列表 | 三 Tab 视图（今日/Milestone/月历） |
| 任务来源 | 硬编码 mockData + localStorage | 从活跃计划的当前里程碑动态生成 |
| Agent Hub Pills | 两行固定布局 | 分组折叠式 Popover |
| 返工计划 | 无 | InlineWorkFlow 完整流程 + 装备清单 |
| 待产计划 | 场景卡片展示 | InlineMaternityFlow 完整流程 + 待产包清单 |
| 泌乳目标 Sheet | 仅策略展示 + 问Mai | 增加"我想制定返工计划"入口 |
| 月历里程碑标记 | 标记可能因去重丢失 | 去重逻辑修正，优先保留 isMilestoneStart |
| Hub cardType | 6 种 | 8 种（+maternity-flow, +work-flow） |
| Hub 事件监听 | navigate-to | +hub-start-work-flow |
| 版本号 | v1.1alpha_FZD_20260316 | v1.2alpha_FZD_20260320 |

---

## 附录 C：关键业务公式与阈值表

### 公式

| 公式 | 表达式 | 用途 |
|------|--------|------|
| P50 日需求 | `weight_kg × 150` | 宝宝中位日需奶量 |
| P25 日需求 | `weight_kg × 120` | 少量端 |
| P75 日需求 | `weight_kg × 180` | 充足端 |
| 供需比 | `totalAvailable / feedP50` | 供需平衡 |
| 奶瓶完成度 | `(totalL + totalR) / targetMl × 100` | 吸乳进度 |
| mL → oz | `mL × 0.033814` | 单位转换 |

### 阈值

| 名称 | 值 | 用途 |
|------|---|------|
| 奶阵流速 | 3.0 mL/min | 奶阵判定 |
| 低流速 | 0.8 mL/min | 自动切 deep |
| 低流速延迟 | 10s | 切换等待 |
| 供需比-偏少 | < 0.7 | 告警 |
| 供需比-差一点 | 0.7~0.9 | 提示 |
| 评估-偏少 | < 0.85 | 追奶建议 |
| 评估-充裕 | > 1.3 | 减量建议 |
| 标定档位 | 1-9 | 吸力范围 |
| 目标量 | 60-100 mL | 可调范围 |
| BT 信号-强 | > -50 dBm | 绿色 |
| BT 信号-良 | -50~-65 | 橙色 |
| BT 信号-弱 | < -65 | 灰色 |
| 左滑删除 | offset.x < -80px | 触发删除 |
| 气泡上限-闲聊 | 10 | stimulate |
| 气泡上限-知识 | 5 | deep |

---

> **文档标识**: PRD_mai.agenticapp_v1.2alpha_FZD_20260320  
> **生成日期**: 2026-03-20  
> **基于代码版本**: mai.agenticapp_v1.2alpha_FZD_20260320  
> **涵盖范围**: 全量功能模块、用户旅程、数据接口、实现逻辑、跨模块联动
