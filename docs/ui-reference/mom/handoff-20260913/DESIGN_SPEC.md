# 妈妈首页开发规格

## 1. 页面职责

妈妈首页用于完成三件事：

1. 让用户快速理解今天最重要的恢复建议。
2. 以低操作成本记录泌乳、身体、休息和心情。
3. 展示专家服务入口，并在购买后管理当前陪伴计划。

## 2. 组件层级

```text
MomHomeScreen
├── Header
├── AiInsightCard
├── LactationSection
│   ├── SectionHeader
│   └── LactationCard
├── RecoverySection
│   ├── SectionHeader
│   └── RecoveryStatus
│       ├── BodyStatusCard
│       ├── SleepStatusCard
│       └── MoodSelector
├── ExpertCompanionSection
│   ├── ExpertPlanEntry
│   └── [已购买]
│       ├── MyCompanionPlanHeader
│       └── ActivePlanCard
└── MomBottomNavigation
```

## 3. 核心尺寸

| 项目 | 数值 |
| --- | ---: |
| Figma 基准宽度 | 393 px |
| 页面水平边距 | 16 px |
| 模块垂直间距 | 14 px |
| AI 建议卡高度 | 138 px |
| 泌乳卡高度 | 132 px |
| 双列状态卡高度 | 106 px |
| 心情卡高度 | 64 px |
| 专家服务入口高度 | 84 px |
| 进行中服务卡高度 | 210 px |
| 底部导航高度 | 74 px + SafeArea |
| 主卡圆角 | 22 px |

Flutter 中不锁定页面宽度。组件以屏幕宽度减去左右 16 px 自适应；当屏幕宽度小于 360 dp 时，应对标题与阶段文案进行真机回归。

## 4. 色彩 Tokens

| Token | 色值 | 用途 |
| --- | --- | --- |
| `background` | `#FBF8F4` | 页面背景 |
| `surface` | `#FFFDFC` | 通用卡片 |
| `textPrimary` | `#2B2826` | 标题与关键数据 |
| `textSecondary` | `#776E69` | 正文 |
| `textMuted` | `#958A84` | 辅助说明 |
| `rose` | `#B94C77` | 主要记录动作 |
| `roseDeep` | `#8A607F` | 专家服务主动作 |
| `roseSoft` | `#F7E7E7` | 泌乳与心情背景 |
| `cream` | `#F6EFE3` | 身体与休息背景 |
| `mint` | `#E8F3EF` | 专家状态背景 |
| `teal` | `#3E7180` | 专家状态文字与图标 |
| `border` | `#E9E1DC` | 卡片描边 |

## 5. 状态切换

### 初始态

- AI 卡展示“等待首次记录”。
- 泌乳、身体、休息均展示未记录状态。
- 心情模块直接提供三个轻量选项。
- 仅展示专家陪伴计划入口。

### 有数据态

- AI 卡根据当天数据展示重点建议。
- 泌乳展示总量与记录次数。
- 身体、休息和心情展示最新结果。
- 仍仅展示专家陪伴计划入口。

### 已购服务态

- 保留专家陪伴计划入口。
- 新增“我的陪伴计划”和进行中的服务数量。
- 服务卡展示具体 IBCLC、支持天数、剩余咨询次数、服务进度和预约动作。

## 6. 交互与埋点建议

| 组件 | 回调 | 建议事件名 |
| --- | --- | --- |
| AI 建议卡 | `onAiInsight` | `mom_home_ai_insight_click` |
| 记录一次泌乳 | `onRecordLactation` | `mom_home_lactation_record_click` |
| 查看泌乳趋势 | `onLactationDetails` | `mom_home_lactation_trend_click` |
| 今日状态 | `onRecoveryDetails` / `onRecordRecovery` | `mom_home_recovery_click` |
| 专家陪伴计划 | `onExpertPlans` | `mom_home_expert_plan_click` |
| 服务进度 | `onServiceProgress` | `mom_home_service_progress_click` |
| 预约咨询 | `onBookConsultation` | `mom_home_consultation_book_click` |

## 7. 图片资源说明

- `cozymate_avatar.png`：顶部 AI 建议卡与 Cozymate 导航头像。
- `expert_group.png`：专家陪伴计划入口。
- `ibclc_jamie_lee.png`：已购服务包的单个 IBCLC 头像。
- `assets/icons/*.png`：从 Figma 节点按 2x/4x 导出的透明背景图标和装饰。

所有资源均已本地化，不依赖会过期的 Figma 下载地址。
