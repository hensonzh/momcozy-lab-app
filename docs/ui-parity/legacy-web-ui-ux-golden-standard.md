# 旧 Web UI/UX Golden 标准

> 路径说明：本文档中的旧 Web 源码路径现在以 `legacy_web/` 为根，例如 `src/pages/Status.tsx` 表示 `legacy_web/src/pages/Status.tsx`。
> 状态：评审稿 v0.1  
> 范围：以当前旧版 Vite + React + Capacitor Web App 为 UI/UX 基线，约束 Flutter 原生重构的视觉、交互和 golden 验收。  
> 结论：Flutter 可以使用原生实现方式，但默认不得重设计旧 Web 的信息架构、页面层级、关键控件、文案和主要视觉比例。

---

## 1. 目的

这份文档定义 MomCozyApp Flutter 重构期间的 UI/UX golden 标准。

旧 Web 不是“参考灵感”，而是替换前的产品基线。Flutter 页面需要先证明与旧 Web 在以下层面一致：

- 信息架构一致：入口、页面顺序、主次信息、底部导航归属一致。
- 视觉结构一致：标题、卡片、按钮、输入栏、底栏、浮层、空态和错误态的位置与层级一致。
- 关键交互一致：可点击入口、状态切换、返回路径、提醒开关、补录/编辑/删除、上传/发送等行为一致。
- 移动端体验一致：安全区、底栏、滚动区域、全屏流程、内容不裁切、不露半张卡、不隐藏旧版可见控件。

Flutter 允许因平台字体渲染、原生控件和像素密度带来轻微视觉差异，但不允许引入新的产品风格或省略旧 Web 中用户可见、可操作的元素。

---

## 2. Source Of Truth

旧 Web 基线来自以下文件：

| 类别 | 文件 |
|---|---|
| 主题 token | `src/index.css` |
| 应用外壳 | `src/components/layout/AppLayout.tsx` |
| Tab 顶部安全区 | `src/components/layout/TabPageTopReserve.tsx` |
| Tab 中间滚动区 | `src/components/layout/TabPageScrollRegion.tsx` |
| 嵌入/固定底栏 | `src/components/layout/BottomNav.tsx` |
| 主聊天 | `src/pages/AgentHub.tsx`、`src/components/Mai/*`、`src/pages/agentHub/*` |
| 宝宝和我 | `src/pages/Status.tsx`、`src/pages/status/StatusOverviewBody.tsx` |
| 计划 | `src/pages/Schedule.tsx` |
| 设备 | `src/pages/DeviceManagement.tsx`、`src/pages/DeviceManageActions.tsx`、`src/pages/UserParameterConfig.tsx` |
| 泵奶/校准 | `src/pages/PumpSession.tsx`、`src/pages/ComfortCalibration.tsx`、`src/pages/pumpSession/*` |
| 媒体 | `src/pages/MediaViewer.tsx`、`src/components/media/*` |
| IBCLC | `src/pages/IbclcChat.tsx` |
| 待产包 | `src/pages/HospitalBagCart.tsx`、`src/pages/hospitalBagCartModel.ts` |
| W1 / 社区 | `src/pages/W1Promo.tsx`、`src/pages/Community.tsx` |

Flutter 当前已有 golden 图片位于：

```text
flutter_app/test/goldens/feature_pages/
flutter_app/test/goldens/agent_hub/
```

这些 Flutter golden 只能作为“当前实现快照”。真正的判断标准仍然是旧 Web 的页面结构和交互契约。

---

## 3. 全局视觉标准

### 3.1 画布与安全区

- App 主内容最大宽度沿用旧 Web `max-w-lg`，即约 `512px`；IBCLC 独立咨询页沿用 `max-w-[390px]` 的窄屏容器。
- 背景基色为温柔 rose/cocoa 调性：`--background: 23 50% 97%`，文字主色为 `--foreground: 325 18% 19%`。
- 顶部安全区遵循 `--top-safe: max(env(safe-area-inset-top, 0px), 20px)`。
- Tab 页采用三段式纵向结构：顶部安全区、中间唯一滚动区域、底部嵌入式导航。
- Pump、Calibration、Media Viewer、IBCLC 等专注流程在首屏内必须呈现独立全屏体验，不能露出普通 Tab 内容或底栏。

### 3.2 字体与文字

- 旧 Web 字体栈为 `"Quicksand", "Noto Sans SC", sans-serif`。
- 标题通常为 `font-bold` / `font-black`，正文为 `font-medium` / `font-semibold`。
- 中文文案必须以旧 Web 为准；除非产品明确改文案，不得随 Flutter 迁移自行改写。
- 长文本必须保持旧 Web 的信息密度：普通描述可 1-2 行省略，用户 ID、媒体标题等可截断，但主按钮文字和页面标题不得被裁切。

### 3.3 色彩与材质

核心 token：

| Token | 旧 Web 值 | 用途 |
|---|---|---|
| `primary` | `346 29% 52%` | 主操作、选中态、底栏 active |
| `secondary` | `348 31% 90%` | 柔和背景、分组块 |
| `muted` | `24 28% 94%` | 弱背景 |
| `muted-foreground` | `330 12% 46%` | 次级文字 |
| `border` | `348 22% 86%` | 卡片/输入边框 |
| `mai-warm` | `26 58% 67%` | 温暖提示、图表辅助 |
| `mai-glow` | `346 38% 68%` | M.ai 高亮 |

材质要求：

- 卡片背景以 `card`、`card/80`、`bg-white`、`bg-card/70` 为主。
- 常用卡片半径为 `16px` 到 `24px`，按钮/控件半径为 `12px` 到 `999px`。
- 阴影应轻，旧 Web 常用 `shadow-sm`、`shadow-lg`、`0 8px 22px -14px`、`0 10px 26px -18px`。
- 不得改成新的强烈渐变、深色科技感、过度玻璃拟态或营销落地页风格。

### 3.4 图标与头像

- 图标风格以 Lucide 线性图标为准，stroke 通常为 `1.8` 到 `2.5`。
- 底部 Agent 使用 `momcozy-agent.png`，中心浮动头像按钮必须为圆形，旧 Web 尺寸为 `68px`。
- Avatar、产品图、待产包商品图、W1 装饰图形必须保留语义位置，不得替换成无关插画。

---

## 4. 全局 UX 标准

### 4.1 底部导航

底栏标准来自 `BottomNav.tsx`：

- Tab 顺序固定为：`宝宝和我`、`计划`、`智能体`、`社区`、`设备`。
- 底栏高度为 `4.5rem`，背景为 `card/88` 加轻 blur 和顶部边框。
- 中心 Agent Tab 是 68px 浮动圆形头像按钮，不显示独立文字标签。
- 普通 Tab 选中态必须有淡 `primary/8` 背景、`primary` 文本和 active icon。
- 状态页和计划页 badge 必须可见，红色小胶囊浮在对应 Tab 右上。
- 专注流程不显示底栏：Pump、Calibration、Media Viewer；IBCLC 首屏也应保持独立咨询页，不暴露底栏。

### 4.2 滚动与布局

- Tab 页只有中间区域滚动，底栏不能跟着内容滚走。
- 主内容不能横向溢出。除非旧 Web 明确使用横向滚动预览，否则不允许用户看到被截断的右侧卡片。
- 不允许用透明、`Opacity(0)`、`Visibility(false)`、空占位等方式隐藏旧 Web 中可见的操作入口。
- 弹窗、底部抽屉、固定输入栏必须避开系统安全区。
- 内容底部必须留出底栏空间，不能被底栏遮挡。

### 4.3 控件与交互

- 图标按钮最小触达区域约 `36-44px`。
- 输入栏、发送按钮、提醒按钮、返回按钮、加号菜单、删除/编辑等操作必须可见且可点。
- 旧 Web 中 disabled 但可见的按钮，在 Flutter 中也必须可见并呈 disabled 态，而不是直接移除。
- 支持 loading、empty、error、permission denied、offline/retry 等状态；错误文案需用户可理解。
- 动效可以用 Flutter 实现，但必须尊重 `prefers-reduced-motion` 对应的可降级原则。

---

## 5. 逐页 Golden 标准

### 5.1 Agent Hub `/`

旧 Web 基线：`src/pages/AgentHub.tsx`。

必须保留：

- 顶部右侧两个圆形入口：语音模式开关、新建会话。
- 聊天区域独立滚动，上方有淡入 fade，底部有回到最新消息按钮条件展示。
- M.ai 助手消息默认透明文本泡样式，用户消息为淡粉背景圆角泡。
- 上传图片后底部输入区上方显示横向图片预览、上传中、失败和删除入口。
- 底部输入栏固定在聊天视口底部，含图片入口、输入提示、语音/发送相关操作。
- 底部导航保留，中心 Agent Tab 处于 active。

关键 UX：

- 历史消息、新会话、取消/重试、流式输出、工具进度和 rich artifact 不得破坏滚动位置。
- Agent 文本流实现可以是 SSE 或 WebSocket，但 UI 只消费 transport-agnostic event。

### 5.2 宝宝和我 `/status`

旧 Web 基线：`Status.tsx` + `StatusOverviewBody.tsx`。

必须保留：

- 顶部 care stage 切换：`孕期` / `哺乳期`。
- 妈妈/宝宝两个身份卡，选中卡左侧有竖向 primary 标记。
- 哺乳期妈妈视图为 2 列模块卡：母乳产出、乳房健康、产后恢复、补能与休息等。
- 趋势图卡位于模块区下方，包含 legend 和坐标网格。
- 孕期视图不再包含已退役的“下一步/补写孕期日记/今日待办”操作。
- 底部导航 active 在 `宝宝和我`。

关键 UX：

- 孕期状态下宝宝 tab 的 disabled 行为必须可见。
- 状态同步失败时显示重试入口，不能空白。
- 通知 badge 从底栏转入状态卡后要有明确视觉提示。

### 5.3 计划 `/schedule`

旧 Web 基线：`src/pages/Schedule.tsx`。

必须保留：

- 顶部月份文本，如 `2026年7月`。
- 周日期条：左右切周按钮、7 日按钮、今天标记、选中日期 primary 胶囊。
- 计划概览卡：标题、阶段副标题、右上圆形提醒按钮、今日任务完成数、进度条。
- 今日 Agent 提示卡：头像、提醒开关按钮、对话按钮。
- 下一任务卡/空态卡。
- 今日任务标题行：说明 `?`、右侧媒体/添加两个圆形按钮。
- 任务列表支持完成、删除、手动任务 badge、跨天倒计时。

关键 UX：

- 未来日期无计划时使用旧 Web 的“待规划/空态”结构。
- 任务说明弹窗居中显示，背景遮罩。
- 任务计数如 `1/3`、`0/0` 是旧 Web 可见扫描信息，不能隐藏。

### 5.4 设备 `/device`

旧 Web 基线：`src/pages/DeviceManagement.tsx`。

必须保留：

- 顶部标题 `设备连接`，右上圆形 `+` 快捷菜单。
- 快捷菜单包含 `添加设备`、`用户管理`、`设备提醒`。
- W1 横幅：深玫瑰背景、圆形 sparkles icon、文案 `Momcozy W1 · 全新上市`。
- Air One 卡片：标题、右侧 `开始吸奶` 按钮，即使无设备也以 disabled 态显示。
- 左/右两个设备卡完整显示，不允许右侧卡片被裁切。
- 连接设备按钮、权限拒绝/永久拒绝/扫描空结果/连接结果状态。

关键 UX：

- 左右设备必须并列且等宽；小屏也不能水平溢出。
- 连接后显示设备状态和断开/详情入口。

### 5.5 设备提醒 `/device/manage`

旧 Web 基线：`src/pages/DeviceManageActions.tsx`。

必须保留：

- 顶部安全区、返回圆按钮、标题 `设备提醒`。
- 操作按钮列表：任务提醒、每日奶量总结、每日泌乳建议、奶量分析、宝宝生长发育指标更新、健康问题通知。
- 点击后按钮进入处理中状态，并显示同步/记录反馈。
- 底部导航 active 在 `设备`。

### 5.6 用户参数配置 `/device/user`

旧 Web 基线：`src/pages/UserParameterConfig.tsx`。

必须保留：

- 返回按钮、标题 `用户参数配置`、来源副标题。
- 用户名输入框，右侧有展开用户列表箭头。
- 用户列表弹层：已知用户列表或 `暂无已保存用户`。
- 用户类型 Select，右侧下拉箭头可见。
- 删除用户按钮、切换用户按钮。
- 底部导航 active 在 `设备`。

关键 UX：

- 长 user ID 必须截断或横向容错，不能挤出输入框。
- Debug/QA 属性可以由环境控制，但 UI 基线入口在旧 Web 存在，Flutter 迁移阶段不得直接省略。

### 5.7 W1 `/w1`

旧 Web 基线：`src/pages/W1Promo.tsx`。

必须保留：

- 顶部深玫瑰 hero，左上返回圆按钮。
- Eyebrow：`Momcozy · New`，主标题 `W1`。
- 副标题 `Wellness & Well-being` 与中文说明。
- 中央 W1 圆形装饰。
- 下压的产品摘要卡，含重量、噪音、续航三列。
- 核心亮点列表和教程入口。
- 底部导航 active 在 `设备`。

### 5.8 泵奶 `/pump`

旧 Web 基线：`src/pages/PumpSession.tsx`。

必须保留：

- 全屏沉浸式页面，不显示底部导航。
- 顶部返回、居中标题 `沉浸式吸乳`、状态胶囊。
- 指标卡：吸乳量、时间、本次吸乳进度条。
- 中间吸乳舞台：左右侧指标、左右杯体、中央奶瓶、左右曲线面板。
- 设备控制区：自动托管/手动调整、刺激模式/吸乳模式、左右档位控制。
- 底部主操作：开始、暂停、结束。
- 首次/未校准时显示个性化舒适档位弹窗。
- 后台上传/记录同步状态条。

关键 UX：

- 所有内容必须在小屏内可理解，主操作不得被系统导航条或底部遮挡。
- 结束、上传、Agent context 只触发一次。

### 5.9 舒适校准 `/calibration`

旧 Web 基线：`src/pages/ComfortCalibration.tsx`。

必须保留：

- 全屏流程，不显示底部导航。
- 顶部返回、标题 `舒适负压调节`、进度条。
- 步骤卡左对齐，旧 Web 采用较宽卡片视觉；Flutter 小屏可缩放/适配，但内容不能被裁切。
- 穿戴确认、左右设备状态、左右档位、保存并进入泵奶、退出校准、恢复默认。
- 未连接设备、权限失败、保存失败、恢复中断校准状态。

### 5.10 记录 `/records`

已退出旧 Web golden 基线。

原因：

- 旧 Web `/records` 是早期 mock 数据页面，已不属于 active legacy reference capture。
- Flutter `/records` UI 路由已退役；仅保留 records API/repository 契约测试。
- 后续如恢复 Records 页面，需要重新建立 Flutter 产品规格，而不是复用旧 Web mock 截图。

### 5.11 媒体查看 `/media-viewer`

旧 Web 基线：`src/pages/MediaViewer.tsx`。

必须保留：

- 独立 fixed 全屏层，从 `var(--top-safe)` 起算。
- 顶部 header：返回按钮、标题。
- PDF/Image/Video 三种内容区，内容区不显示底部导航。
- 缺少资源参数时显示居中文案 `缺少资源参数，请从资料卡片进入。`。

### 5.12 IBCLC `/ibclc-chat.html`

旧 Web 基线：`src/pages/IbclcChat.tsx`。

必须保留：

- 独立咨询页，白色窄容器，最大宽度约 `390px`。
- Header：标题 `IBCLC 在线咨询`，右侧红色 `结束咨询`。
- 连接中状态：中心浅绿色卡片、pulse dot、连接文案。
- 聊天状态：左侧咨询师消息泡。
- Footer composer 始终存在：上传图片、输入消息、语音输入、发送。
- 结束后返回 `/status`。

关键 UX：

- 连接中也必须显示底部输入栏，旧 Web 没有把 composer 延后隐藏。
- 首屏不能出现普通 Tab 底栏。

### 5.13 待产包 `/hospital-bag-cart`

旧 Web 基线：`src/pages/HospitalBagCart.tsx`。

必须保留：

- 全屏购物车容器，背景 `#fff9fb`。
- Header：返回、标题 `待产包一键打包`、副标题、右侧数量胶囊如 `18 件`。
- 分组：妈妈护理、宝宝出院等；每组右侧数量胶囊。
- 商品行：56px 图片/图标、标题、两行描述、数量、价格、删除按钮。
- 购物车清空空态和恢复默认清单。
- 订单摘要与底部固定结算栏，显示预计合计和 `去结算`。

关键 UX：

- 底部固定结算栏不能遮挡最后一组内容；主列表需要足够底部 padding。
- 商品数量变化后 header 数量胶囊必须同步。

### 5.14 社区 `/community`

旧 Web 基线：`src/pages/Community.tsx`。

必须保留：

- Tab shell 页面，底部导航 active 在 `社区`。
- 中心空态：Agent 头像圆形背景、标题 `社区功能还在建设中哦～`、说明文案。
- 视觉重心居中，不能上移成普通信息列表。

### 5.15 404 `*`

已退出旧 Web golden 基线。

说明：Not Found 仍可作为 Flutter route fallback regression 测试，但不再采集旧 Web `not_found.png`，也不作为 active UI parity 页面。

---

## 6. Golden 验收矩阵

### 6.1 必测视口

Flutter UI golden 至少覆盖：

| 视口 | 用途 |
|---|---|
| `390x844` | 当前 compact mobile 主基线 |
| `360x800` | 小屏溢出检查 |
| `430x932` | 大屏 Android 常见比例 |

如果测试成本受限，首轮至少保留 `390x844`，但小屏截图必须纳入人工评审。

### 6.2 自动化 Golden 覆盖

每个页面至少保留一个静态 golden：

```text
agent_hub_mobile.png
status_page_mobile.png
schedule_page_mobile.png
device_page_mobile.png
device_manage_page_mobile.png
device_user_page_mobile.png
w1_page_mobile.png
pump_page_mobile.png
calibration_page_mobile.png
media_viewer_page_mobile.png
ibclc_page_mobile.png
hospital_bag_page_mobile.png
community_page_mobile.png
```

重点交互还需要 state golden 或 widget assertions：

- Agent：rich state、图片上传、streaming、error/retry。
- Status：孕期/哺乳期、妈妈/宝宝、失败态。
- Schedule：有任务、无任务、跨天、提醒开关、任务说明弹窗。
- Device：无权限、扫描中、空结果、左右设备连接。
- Pump：idle/running/paused、校准弹窗、上传失败。
- IBCLC：连接中、聊天中、结束中。
- Hospital Bag：删除后、清空后、恢复默认。

### 6.3 截图人工评审清单

每张页面截图都必须检查：

- [ ] 首屏是否出现旧 Web 中相同的主标题和主入口。
- [ ] 底栏顺序、active 态、Agent 中心头像是否正确。
- [ ] 页面是否有横向裁切、半张卡片、内容露出异常。
- [ ] 旧 Web 可见控件是否全部存在。
- [ ] disabled 控件是否可见而非消失。
- [ ] 输入栏、固定 footer、底栏是否互相遮挡。
- [ ] 长文本、长 ID、中文按钮是否溢出。
- [ ] loading/empty/error/permission 状态是否有用户可理解文案。
- [ ] 返回路径是否与旧 Web 一致。

---

## 7. 差异处理规则

发现 Flutter 与旧 Web 不一致时，按以下规则处理：

| 类型 | 处理 |
|---|---|
| 控件缺失 | P0/P1 修复，不进入评审豁免。 |
| 裁切/溢出/遮挡 | P0 修复。 |
| 文案不同 | 默认修回旧 Web；如产品要改，登记为文案变更。 |
| Flutter 原生控件导致轻微像素差异 | 可接受，但截图评审要确认信息层级一致。 |
| 旧 Web 存在明显 bug | 不直接复制，登记为 legacy bug，由产品/设计确认新行为。 |
| Debug/内部入口 | 默认保留迁移期可访问性，production 是否隐藏需单独决策。 |
| 新增视觉风格 | 默认拒绝，除非有设计稿或产品决策。 |

---

## 8. UI/UX 变更准入

任何 Flutter UI/UX 变更合入前必须满足：

- 对照本标准确认不破坏旧 Web 信息架构。
- 更新或新增对应 Flutter golden。
- 至少有一个 widget test 保护关键可见控件。
- 运行：

```text
flutter analyze
flutter test
```

- 如果变更 intentionally diverges from 旧 Web，需要补充：

```text
页面：
旧 Web 行为：
新 Flutter 行为：
差异原因：
产品/设计确认人：
是否需要迁移文档更新：
```

---

## 9. 待评审问题

请产品/设计/工程评审以下决策：

1. 是否要求 pixel-perfect，还是接受“结构/信息/交互一致 + 原生轻微像素差异”。
2. `/device/user` 这类 debug 用户入口在 production 是否继续可见，还是用 internal flavor gate 隐藏。
3. IBCLC 是否长期保持外部 vendor/H5 handoff，Flutter 只承载事件写回和返回恢复。
4. Pump/Calibration 的旧 Web 宽卡视觉在极小屏上是否允许缩放，还是必须保持固定宽并裁出旧版视觉。
5. W1 页面是否仍以旧 Web 营销内容为基线，后续是否由产品运营单独维护内容配置。

---

## 10. 当前评审结论模板

评审时可使用以下结论之一：

```text
[ ] 通过：可作为 Flutter UI/UX golden 标准。
[ ] 有条件通过：按评审意见补充后作为标准。
[ ] 不通过：需要设计/产品先重新定义目标体验。
```

评审意见：

```text
1.
2.
3.
```
