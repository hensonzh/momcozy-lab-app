# 入口断点与首页预约弹窗补验

新增 **27 个实际路由状态、50 个尺寸/字号变体、11 张主长图、32 个长图变体**。Cozymate 卡片 14 个状态，妈妈首页预约浮层及信息采集 13 个状态。393/1x 与 320/2x 均执行主要链路；首页首次加载/失败/重试使用 393/1x。

## 入口断点

从 More 点击 Cozymate，经正式 SSE parser 收到受支持的 `motion_assessment_card`，分别展示“头颈姿态动态评估”和“体态动态评估”。实际点击“开始评估”后路由仍为 `/`，卡片保留，未出现 Snackbar，也未调用外部链接启动器；Tab 往返后仍然如此。

源码 `dispatchAgentArtifactAction` 只允许 `_knownFlutterRoutePaths` 中的路径；`/motion-assessment` 不在当前注册集合。它没有外部 URL fallback，所以直接返回。**这是可见卡片按钮的无响应断点；不是已到达评估页，也不会在此链路出现评估相机/麦克风权限弹窗。** 评估页面和原生预览代码单列于 [无正常入口与函数弹窗核对](ENTRY-STATUS.md)，已有 motion-guide/failure 图仍是组件预览。

外部资料卡使用真实 action mapper 与 dispatcher，公开 `ExternalUrlLauncher` 注入可控结果。按钮等待时没有进度指示；返回 false 或抛错都会显示“无法打开链接，请稍后重试”。下滑关闭 Snackbar 后可再次点击；成功由启动器返回 true，当前 App 仍保留卡片。**未打开真实浏览器，也未把启动器成功返回当成外部网页截图。**

卡片的中文 CTA 在 Widget 截图仍有缺字方块，和先前结果卡问题一致；真实 Text 标签、命中点击及派发参数均已断言。没有将标签替换为英文或绘图修补，原生字体表现仍需另验。

## 首页预约浮层

从 More → Me → 已购计划“查看预约”打开正式 `showHomeConsultationDialog`，保留妈妈页为实际背景，路由仍是 `/me`。本轮使用真实 RoomController、Repository、生产浮层和内存 HTTP 数据；没有强行直接 mount 弹窗。

- 点击外部遮罩不关闭预约详情；点关闭按钮返回原首页滚动位置。
- 点“取消预约”打开第二层确认；点“保留预约”会关闭取消确认与预约详情两层，返回首页，且没有取消接口请求。该行为来自 home dialog 在子弹窗返回后无条件 finish，不能按独立预约页推断返回到详情。
- Room context 要求补充信息时，点“查看信息采集表”会先关闭首页浮层，再 push 正式 intake 路由。返回后是妈妈首页，不自动重开详情；这次路由返回让首页滚动位置回到顶部，和仅关闭浮层不同。
- 首次 room 请求等待、失败和重试成功均在首页浮层内部呈现。所有上述流程没有触发 `getUserMedia`，未进入音视频咨询。

本轮没有取消真实预约或修改账号记录。首页弹窗的正式入会、结束、改约及确认取消的更多组合仍待覆盖；独立 room route 的既有记录不能自动替代 over-home 的背景和返回链路。

## 验证与视觉检查

- 两个新增测试文件，**11 项通过，0 失败**：[最终定向日志](runs/20260913T134634-targeted/capture.log)、[命令](runs/20260913T134634-targeted/capture-command.json)、[结果](runs/20260913T134634-targeted/capture-result.json)。采集严格比较，无容差、无更新基线。
- 两个文件静态检查无问题：[分析日志](entry-followup-analyze.log)；格式检查 0 changed。
- 本轮未修改采集器或业务代码，未重跑全部测试或构建 APK；上一轮全量 79 文件/1003 通过/6 跳过仍为历史全量记录。
- 已查看 27 个主窗口、11 张主长图及全部 320/2x 原窗口和长图的 64 个连续分段。审阅图位于 `entry-followup-visual-review/overview-1…3.jpg`、`long-1…2.jpg`、`narrow-1…8.jpg`，来源哈希与分段区间在对应 JSON 中。
- 大字号下取消确认和缺信息提示需要滚动才能看到底部按钮，已采完整长图。原始窗口保留当时实际滚动位置；固定背景渐变拼接色带及捕获期间控件瞬时颜色差异仍不作为静态设计样式。

## 逐状态入口

| 状态 | 路由 | 触发 | 截图及前驱 |
| --- | --- | --- | --- |
| agent-entry-journey-external-accepted | `/` | Tap again, launcher accepts → App remains on card; browser outside fixture scope | [状态](../05-agent/agent-entry-journey-external-accepted/README.md) |
| agent-entry-journey-external-card | `/` | External artifact link appears in the completed reply | [状态](../05-agent/agent-entry-journey-external-card/README.md) |
| agent-entry-journey-external-dismissed | `/` | Dismiss Snackbar → card remains actionable | [状态](../05-agent/agent-entry-journey-external-dismissed/README.md) |
| agent-entry-journey-external-failed | `/` | Launcher returns false → real Snackbar | [状态](../05-agent/agent-entry-journey-external-failed/README.md) |
| agent-entry-journey-external-pending | `/` | Tap external link → launcher pending; card has no progress UI | [状态](../05-agent/agent-entry-journey-external-pending/README.md) |
| agent-entry-journey-external-thrown | `/` | Tap again, launcher throws → same safe Snackbar | [状态](../05-agent/agent-entry-journey-external-thrown/README.md) |
| agent-entry-journey-forward_head-away | `/more` | More tab after unhandled motion CTA | [状态](../05-agent/agent-entry-journey-forward_head-away/README.md) |
| agent-entry-journey-forward_head-card | `/` | Supported motion artifact arrives → normal card with start CTA | [状态](../05-agent/agent-entry-journey-forward_head-card/README.md) |
| agent-entry-journey-forward_head-no-navigation | `/` | Tap start assessment → dispatcher ignores unregistered /motion-assessment, no notice | [状态](../05-agent/agent-entry-journey-forward_head-no-navigation/README.md) |
| agent-entry-journey-forward_head-return | `/` | Cozymate tab → card retained, still no assessment page | [状态](../05-agent/agent-entry-journey-forward_head-return/README.md) |
| agent-entry-journey-posture_screen-away | `/more` | More tab after unhandled motion CTA | [状态](../05-agent/agent-entry-journey-posture_screen-away/README.md) |
| agent-entry-journey-posture_screen-card | `/` | Supported motion artifact arrives → normal card with start CTA | [状态](../05-agent/agent-entry-journey-posture_screen-card/README.md) |
| agent-entry-journey-posture_screen-no-navigation | `/` | Tap start assessment → dispatcher ignores unregistered /motion-assessment, no notice | [状态](../05-agent/agent-entry-journey-posture_screen-no-navigation/README.md) |
| agent-entry-journey-posture_screen-return | `/` | Cozymate tab → card retained, still no assessment page | [状态](../05-agent/agent-entry-journey-posture_screen-return/README.md) |
| home-consultation-journey-cancel-confirm | `/me` | Cancel appointment → nested confirmation dialog | [状态](../08-expert-service/home-consultation-journey-cancel-confirm/README.md) |
| home-consultation-journey-cancel-kept-home | `/me` | Keep appointment → nested dialog and preparation close; no cancellation mutation | [状态](../08-expert-service/home-consultation-journey-cancel-kept-home/README.md) |
| home-consultation-journey-closed-home | `/me` | Close preparation → original Mom page | [状态](../08-expert-service/home-consultation-journey-closed-home/README.md) |
| home-consultation-journey-intake | `/services/appointments/service-appointment/intake` | Preparation View intake → dismiss home modal then push actual intake page | [状态](../08-expert-service/home-consultation-journey-intake/README.md) |
| home-consultation-journey-intake-required | `/me` | Home preparation room context requires intake before joining | [状态](../08-expert-service/home-consultation-journey-intake-required/README.md) |
| home-consultation-journey-intake-return-home | `/me` | Close intake → Mom home; preparation does not auto-reopen | [状态](../08-expert-service/home-consultation-journey-intake-return-home/README.md) |
| home-consultation-journey-load-error | `/me` | Room context fails → error and retry within home modal | [状态](../08-expert-service/home-consultation-journey-load-error/README.md) |
| home-consultation-journey-load-recovered | `/me` | Retry room context → appointment preparation | [状态](../08-expert-service/home-consultation-journey-load-recovered/README.md) |
| home-consultation-journey-load-return-home | `/me` | Close recovered modal → same home scroll position | [状态](../08-expert-service/home-consultation-journey-load-return-home/README.md) |
| home-consultation-journey-loading | `/me` | View appointment → room context pending in modal above home | [状态](../08-expert-service/home-consultation-journey-loading/README.md) |
| home-consultation-journey-outside-dismiss-blocked | `/me` | Tap outside appointment dialog → modal remains open | [状态](../08-expert-service/home-consultation-journey-outside-dismiss-blocked/README.md) |
| home-consultation-journey-preparation | `/me` | Mom owned plan → View appointment → actual preparation dialog over home | [状态](../08-expert-service/home-consultation-journey-preparation/README.md) |
| home-consultation-journey-reopened | `/me` | View appointment again → preparation reopens | [状态](../08-expert-service/home-consultation-journey-reopened/README.md) |
