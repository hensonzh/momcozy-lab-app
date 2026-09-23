# Schedule：Figma → Flutter 同步（2026-09-20）

本轮按用户确认的范围实现 UI，并复用现有业务入口。设计源是 [Schedule Page 567:1133](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=567-1133)，不是 deprecated 或 More 中的落点副本。执行依据：本机 `figma-to-app` skill、其 Flutter / data-refresh 说明，以及官方 Figma design-to-code 指引。

## 实现范围

- 月历默认展开；收起后显示选中日所在周。周/月左右箭头保持日期关系，标题可返回今天。圆点来自实际日程；同月选日和展开/收起不重新请求。
- 标题下移除副标题；日期标题不再带「当天安排」。照护任务按全天置前，其余条目按开始时间排列，同时间保持稳定顺序。卡片只展示任务名称、时间和操作菜单。
- 三类卡片分别采用浅绿、浅杏、浅紫渐变、时间标签和细色条。加号为 48×48 独立圆形悬浮按钮，位于底栏上方 48px；没有覆盖任务的横向底色带。滚动末端保留 112px 空间。
- 个人日程继续调用现有 create / update / delete；咨询使用现有预约准备页或咨询总结；照护任务使用状态更新和照护方案入口。未新增三类统一编辑/删除接口，未修改后端。
- 首次加载、空状态、离线重试、保留内容的刷新失败、个人编辑/删除、表单校验与保存失败均接到真实控制器。保存中禁止重复提交；失败保留可编辑草稿。创建重试复用原始请求和幂等键，修改过的草稿在恢复创建后更新同一条记录。
- 保存使用接口返回的权威对象更新当前列表，删除和任务状态更新定向应用结果；过期读请求不能覆盖新状态。未修改的编辑保存直接关闭，取消不刷新。

## 对应关系与证据

参考与实测均为完整 **393×844** 逻辑视口、DPR 1、文字缩放 1、系统安全区 0，包含公共底部导航。所有示例数据只存在于测试仓库。没有缩放或裁掉导航；原始参考在 `../references/`，Flutter 实际渲染在 `../actual/`，逐状态并排图、50% 叠图和差异图在 `../comparisons/`。结构化设计契约在 [contract.json](../contract.json)，验证记录在 [evidence.json](../evidence.json)。

| 状态 | Figma 节点 | 对比目录 | 核验 |
|---|---|---|---|
| 月历展开 | `214:1108` | [month](../comparisons/month/side-by-side.png) | 完整视口视觉检查 |
| 所选周 / 日历收起 | `788:8` | [week](../comparisons/week/side-by-side.png) | 完整视口视觉检查 |
| 空日程 | `214:1243` | [empty-month](../comparisons/empty-month/side-by-side.png) | 完整视口视觉检查 |
| 首次加载 | `214:2037` | [loading](../comparisons/loading/side-by-side.png) | 完整视口检查；进度为真实动画 |
| 离线 | `214:2045` | [offline](../comparisons/offline/side-by-side.png) | 完整视口视觉检查与重试 |
| 个人日程菜单 | `216:2742` | [personal-menu](../comparisons/personal-menu/side-by-side.png) | 位置、尺寸、圆角和操作检查 |
| 新增 | `214:3241` | [create](../comparisons/create/side-by-side.png) | 完整弹窗及底层页面检查 |
| 编辑 | `214:3499` | [edit](../comparisons/edit/side-by-side.png) | 完整弹窗及底层页面检查 |
| 删除确认 | `214:4150` | [delete](../comparisons/delete/side-by-side.png) | 完整弹窗及底层页面检查 |
| 刷新失败 | `214:2728`（长内容参考） | [实测](../actual/refresh-failure.png) | 行为检查；未把 1262px 长图当作设备高度 |
| 填写 / 保存中 / 保存失败 / 校验 | `214:3370` / `214:3628` / `214:3757` / `214:4019` | App 中 Schedule 表单 golden 与交互测试 | 行为、多尺寸检查；未逐张与 Figma 叠图验收 |
| 日期 / 时间 / 放弃草稿 | `216:1108` 等共享选择器状态 | App 中 Schedule 表单测试 | 复用现有原生选择器；键盘、大字、日期范围和时间校验已测；未逐张叠图 |
| 咨询 / 照护任务编辑删除画板 | `791:1853` / `791:2051` / `791:1292` / `791:1490` | 现有业务路由测试 | 按用户决定复用现有入口，不新增对应业务接口 |

## 参数与资源

生产实现位于 `lib/modules/schedule/`：`schedule_design.dart` 集中视觉参数，`schedule_calendar.dart` 和 `schedule_agenda.dart` 负责日历与卡片，`schedule_page.dart` 负责状态和悬浮入口。沿用现有仓库、控制器和数据模型。

- 页面背景：`#F4F0FB → #FBF5F6 → #FBF8F4`；日历：`#FBECF1 → #EEE9F9`，26px 圆角。卡片圆角 20px、间距 14px、标准高度 84px；长标题和大字模式允许增高。
- 字体复用 `NotoSansSCHome`（项目现有 Noto Sans CJK SC Regular / Bold）及底栏 DM Sans。主标题 24/34，日历标题 20/28，卡片标题 16/24，时间 12/18。
- 完整页面底栏使用 `MomCozyBottomNavigation` 原始导航资源；标准色块高 82px，另保留 18px 凸起头像命中区域。仅 Schedule shell 开启 `extendBody`，内容延伸到头像透明区，滚动区止于底栏色块顶部。
- `schedule_chevron.svg` ← `788:163` 切换按钮内的 Figma 箭头；`schedule_more.svg` ← `791:744` 原始三点字形转轮廓；`schedule_offline.svg` ← `797:5`；`schedule_date.svg` ← `219:1108`。这些均为导出资产，未手工描摹。空状态装饰、底栏图标和头像复用现有对应资产。
- `MomSettingsFlowDialog` 新增可选 `closeIcon`，Schedule 使用设计中的 ×；其他调用者保持原有默认关闭图标及尺寸。

## 验证与可复现方式

在 App 仓库根目录执行：

```sh
flutter analyze --no-pub lib/modules/schedule lib/shared/widgets/mom_settings_widgets.dart lib/app/momcozy_app.dart test/modules/schedule
flutter test --no-pub test/modules/schedule test/app/momcozy_route_shell_contract_test.dart test/app/mom_navigation_test.dart
```

静态检查无问题；**51 项相关测试通过**。覆盖生产 router + HTTP repository 边界、三种屏宽（320 / 393 或 390 / 430）、2 倍文字、320×568 短屏和键盘、100 条任务滚动末端、任务并发保护、CRUD、取消/未改动保存不请求、失败重试与幂等、跨月乱序响应、未读取月份不误报空日程，以及主导航回归。

`test/modules/schedule/schedule_page_golden_test.dart` 可重新生成 `build/schedule-figma/` 实际截图。用 skill 的 `scripts/compare_screens.py` 与此目录的 Figma 原图生成对比。App 自身 golden 已随本轮 UI 更新；视觉依据仍是独立 Figma 原图，而不是更新 golden 后的通过结果。旧盘点测试中的服务包筛选、复选框、结果未知等已删除界面，已迁移为本轮 UI 的实际操作与路由回归。

## 差异与交付边界

- 已检查上述九组完整视口，但不声明所有画板严格像素一致：字体版本和抗锯齿、部分文字基线/行高存在约 1px 差异；原生菜单阴影与 Figma 阴影算法略有差异。
- Figma 的部分弹窗底图仍保留旧的较小日历箭头、非选中「今天」的粗体；App 使用统一的最新日历组件。不会为了某张静态底图恢复旧组件。
- 首次加载显示真实不定进度动画，Figma 为静态轨道；刷新失败、保存中、失败/校验及原生日期时间选择器没有逐张完成 Figma 叠图验收，不能归入全部状态视觉通过。
- 本轮完成源码、原生 Flutter 渲染检查和自动化回归。随后按用户要求，已用箭头字号修正后的代码构建 local debug 版并覆盖安装到 Android 模拟器 `emulator-5554`，保留原有数据，复核 Schedule、日历收起、空状态和新增入口。见 [安装记录](native/README.md)。未构建公开发布包、未云端发布；未改造预约与照护任务后端业务能力。
