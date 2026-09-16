# UI / UX 盘点交付验收

页面、浮层、状态和版本核对已完成；最终文件与链接检查通过。以下按原要求列出证据，运行环境边界不等于新增待办。

| 原要求 | 核对结果 | 可复查证据 |
| --- | --- | --- |
| 全部当前用户 App 一级至深层页面；配置与无正常入口分列 | 24 个默认注册路径与原导出一致；别名归并、登录五步骤及 Navigator 全屏拆分后为 28 常规页面，另 4 配置、1 兜底、1 无入口。工作台单列。 | [PAGE-CATALOG.md](PAGE-CATALOG.md) · [page-catalog-definition.json](page-catalog-definition.json) · [ROUTE-ENTRY-COVERAGE.md](ROUTE-ENTRY-COVERAGE.md) · [runs/20260914-overlay-final/routes.log](runs/20260914-overlay-final/routes.log) |
| 弹窗、浮层、选择器、提示及系统权限 | 35 类、166 条状态逐项对应实际图；同画面关闭/取消返回共用图。图片预览误配及首页过期窗口已修正。 | [OVERLAY-STATE-MAP.md](OVERLAY-STATE-MAP.md) · [overlay-state-evidence-map.json](overlay-state-evidence-map.json) · [NATIVE-WINDOWS-CATALOG.md](NATIVE-WINDOWS-CATALOG.md) |
| 实际点击并继续到后续页面与状态 | 各页面及浮层的入口、操作、结果引用已有生产路由 journey 与专项操作报告；相同目标图共享引用，不新增重复截图。 | [PAGE-INTERACTION-MAP.md](PAGE-INTERACTION-MAP.md) · [VERIFIED-JOURNEYS.md](VERIFIED-JOURNEYS.md) · [verified-journeys.json](verified-journeys.json) · [observed-transitions.json](observed-transitions.json) · [OVERLAY-STATE-MAP.md](OVERLAY-STATE-MAP.md) |
| 当前支持且具有产品意义的页面主要数据状态 | 34 定义的 213 条页面状态已有处置，212 条有图，1 条为无正常入口的动作评估；不存在的隐藏控制条和禁用提交分支明确标注。 | [STATE-MAP-FINAL.md](STATE-MAP-FINAL.md) · [page-catalog-definition.json](page-catalog-definition.json) · [OVERLAY-STATE-MAP.md](OVERLAY-STATE-MAP.md) |
| 普通窗口完整；纵向长页包含顶部、中部、底部 | 没有 needs_long_review 条目；完整滚动图保留实际测量与逐图检查。Tooltip/固定操作区重复已修正，PDF 分页画布保留各页和缩放窗口。 | [artifact-verification.json](artifact-verification.json) · [SNACKBAR-LONG-REVIEW.md](SNACKBAR-LONG-REVIEW.md) · [SCHEDULE-FEEDBACK-CURRENT.md](SCHEDULE-FEEDBACK-CURRENT.md) · [LACTATION-VERSION-CURRENT.md](LACTATION-VERSION-CURRENT.md) |
| 统一结构、命名与可追溯页面索引 | 用户 App 总索引、34 个页面子索引、原始状态 README 和前驱轨迹互相对应；相同像素归并且原证据保留。 | [PAGE-CATALOG.md](PAGE-CATALOG.md) · [EVIDENCE-GROUPS.md](EVIDENCE-GROUPS.md) · [PAGE-INTERACTION-MAP.md](PAGE-INTERACTION-MAP.md) · [OVERLAY-STATE-MAP.md](OVERLAY-STATE-MAP.md) |
| 以实际运行结果为准，代码辅助查漏 | Flutter 实际渲染与点击使用隔离数据和平台接口；Android 系统窗口来自模拟器实际操作。未用设计画板代替运行截图。 | [verified-journeys.json](verified-journeys.json) · [NATIVE-RESOURCE-JOURNEYS.md](NATIVE-RESOURCE-JOURNEYS.md) · [NATIVE-WINDOWS-CATALOG.md](NATIVE-WINDOWS-CATALOG.md) · [runs/20260914-overlay-final/strict.log](runs/20260914-overlay-final/strict.log) · [runs/20260914-overlay-final/home-expired-strict.log](runs/20260914-overlay-final/home-expired-strict.log) |
| 代码存在但无正常入口单列；仅用户 App | 动作评估、工作台以及尚未实现的设计流程分别说明；未冒充当前正常入口或自行实现新业务。 | [ENTRY-STATUS.md](ENTRY-STATUS.md) · [PAGE-CATALOG.md](PAGE-CATALOG.md) · [NATIVE-WINDOWS-CATALOG.md](NATIVE-WINDOWS-CATALOG.md) |
| 当前 App 可复用视觉资产、限定补图 | 9 个已登记源码差异闭环；当前代表图与历史操作轨迹区分。最后仅补实际不同窗口和泌乳改版长图，无扩大测试矩阵。 | [SOURCE-VERSION-ACCEPTANCE.md](SOURCE-VERSION-ACCEPTANCE.md) · [source-version-acceptance.json](source-version-acceptance.json) · [LACTATION-VERSION-CURRENT.md](LACTATION-VERSION-CURRENT.md) · [STATE-MAP-FINAL.md](STATE-MAP-FINAL.md) |

## 运行与版本边界

- 默认本地配置；开启能力的页面另列。
- 网络业务数据与多数媒体测试使用隔离实现；不代表生产支付、真实专家通话或推送投递验收。
- 原生系统证据来自 Android，未扩展为 iOS 平台矩阵。
- 历史图保留原版本，当前布局以各页面标注的最新代表及改版复用资料为准。

[本次验收指纹和要求清单](final-acceptance.json) · [保留的历史审计](AUDIT-HISTORY.md)。自动校验仅验证文件、哈希、长图测量和链接；页面/状态/操作覆盖依据上表对应的实际运行与人工复核报告。
