# More UI 对齐审查 · 2026-09-15

结论：**尚未与当前 Figma 完全对齐，不通过逐像素一致性验收。** 页面结构、主要文案、底色及入口基本一致；存在明确的布局、导航、加载态按钮和退出失败提示差异，部分状态缺少在线设计依据。

本次范围为 More 首页及其身份、加载、未读、退出状态；检查账号、隐私、通知、专家支持的入口与返回。子模块完整页面的逐项视觉审查不计入本次结论。退出失败因发生在登录页，附带检查该终点截图。

## 证据与比较条件

- [并排截图浏览](comparison.html)：默认、加载、退出失败，以及其它状态截图。
- Figma 当前在线：[默认 122:9](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=122-9)、[加载 122:105](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=122-105)、[More 退出失败 228:1150](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=228-1150)。前两张为 More 首页画板，最后一张属于 Auth。
- 当前 Flutter 代码以 **393×844、字号 1×、无系统安全区**渲染，与 Figma 使用相同视口及默认身份 Mia Chen / mia@example.test。图片预先解码，避免测试假缺图。
- [Figma 节点测量](figma-metrics.json)、[Flutter 默认测量](flutter-default.json)、其它 `flutter-*.json` 保留布局原始数据。表中 px 为同尺寸 Figma 单位与 Flutter 逻辑像素，不是 Android 物理像素。
- [Android 当前 App](app-live.png)：emulator-5554，1280×2856、density 480（DPR 3），逻辑宽约 426.67，含系统安全区。真实账号内容与设计示例不同，不计为设计缺陷；不能将整张设备截图直接拉伸到 393×844 作像素判断。

## 明确差异

### 1. P1 — 页面纵向布局持续偏低

默认和加载态均存在。不是仅有文字抗锯齿差异。

| 元素 | Figma | 当前 Flutter | 差异 |
|---|---:|---:|---|
| 顶部副标题 y / 高 | 82 / 14 | 86 / 17 | 下移 4，高 3 |
| 账号卡片 y / 高 | 110 / 99 | 117 / 101 | 下移 7，高 2 |
| 日常管理 y | 223 | 232 | 下移 9 |
| 设置分组 y / 高 | 267 / 169 | 276 / 169 | 下移 9，组高一致 |
| 专家陪伴 y | 450 | 459 | 下移 9 |
| 专家支持卡片 y / 高 | 494 / 88 | 503 / 90 | 下移 9，高 2 |
| 退出文字 y / 高 | 610 / 16 | 622 / 18 | 下移 12，高 2 |

原因定位：[more_page.dart](../../../lib/modules/profile/presentation/more_page.dart) 的 TextButton 实际布局受 Material 最小触控区域影响；顶部行实际占 48，而 Figma 为 44。Flutter 默认文字行高 1.4，Figma 部分文字使用 AUTO：例如页标题文本框 26 对 31、副标题 14 对 17。账号名文本高 25 对 27，继续累积下移。修复时应分别处理可见布局和触控区域，不能直接缩小可点击面积。

### 2. P1 — 底部导航规格不同

| 项目 | Figma | 当前 Flutter |
|---|---|---|
| 导航高 / 顶部 y | 74 / 770 | 78 / 766 |
| 顶部两角 | 圆角 22 | 无对应圆角 |
| Cozymate 头像尺寸 | 36×36 | 42×42 |
| More 选中底块 | 44×38 | 42×34 |
| 五项中心 x | 35 / 115.75 / 196.5 / 277.25 / 358 | 45.7 / 121.1 / 196.5 / 271.9 / 347.3 |
| 标签字体 / 行高 | Noto Sans SC / 文本框 16 | 继承 DMSans / 14 |

定位：[mom_bottom_navigation.dart](../../../lib/app/mom_bottom_navigation.dart)、[momcozy_design_system.dart](../../../lib/shared/design_system/momcozy_design_system.dart)。这是共享导航的差异，修复会影响其它主 Tab，应一起核对。

### 3. P1 — 加载态退出按钮外观与运行条件不一致

Figma 122:105 的“退出登录”为置灰外观；当前真实路由只根据是否存在 runtimeController 提供退出回调，与账号请求是否完成无关。因此账号加载中，退出按钮仍正常着色且可点击。

证据：[Figma 加载](figma-loading.png)、[真实路由加载](runtime-identity-pending.png)、[同数据加载](flutter-loading.png)。定位：`more_page.dart` 的 onLogout 判断、`momcozy_app.dart` 的路由回调。两端需明确统一该状态约定；本次没有擅自禁用退出或改设计。

### 4. P2 — 专家卡片细节仍有差异

- 文本起点 x：Figma 90，Flutter 91；可用文本宽 237 对 235。
- 标题行高 20 对 22；两行说明高 28 对 26。
- 说明文字颜色：Figma `#776E69`，Flutter `#80736E`。
- 卡片外高 88 对 90，Flutter 边框占据布局空间。

定位：[mom_companion_widgets.dart](../../../lib/shared/widgets/mom_companion_widgets.dart)，特别是 `MomExpertPlanEntry` 的边框、文字样式与最小高度。

### 5. P1 — More 退出失败终点未完全对齐

真实运行链：本机会话立即清除并进入 `/login`，远端撤销仍等待；远端失败时仍停留登录页，并显示 `Sign-out could not finish. Reconnect and try again.`。行为与 More 对应设计的错误文案一致。

但 [Figma](figma-logout-error.png) 与 [当前运行截图](runtime-logout-error-message.png) 的提示条位置、圆角、字形及登录表单布局不同。Figma 提示框为 x16/y778/w361/h50；Flutter 使用共享浮动 SnackBar 默认布局，测得 **SnackBar 外布局框** x0/y783/w393/h61（包括外部留白，不能直接当作可见深色背景尺寸）。登录表单还可见分隔线、密码眼睛图标和纵向间距差异。

225:1400 的较长错误文案对应另一 Auth 退出入口，More 应对照 228:1150，不能混用。此项按登录页与共享提示组件的联动问题记录。

## 状态覆盖结果

| 状态 | 当前 App 结果 | 与在线 Figma 的结论 |
|---|---|---|
| 身份完整、零未读 | Mia Chen、邮箱、头像缩写及入口显示 | 有 122:9；存在上述布局差异 |
| 两接口加载 | 我的账号、…、正在加载账号… | 有 122:105；布局及退出按钮不同 |
| 姓名先返回、邮箱仍等待 | 仍显示合并加载态，等两个请求结束 | 可对照加载外观；无独立中间态设计 |
| 姓名失败、邮箱成功 | 我的账号 / M，加实际邮箱 | 仅能复用默认结构，缺少独立状态依据 |
| 邮箱失败、姓名成功 | 姓名及缩写，加“管理你的账号信息” | 同上 |
| 两接口失败 | 我的账号 / M / 管理你的账号信息 | 原引用 122:185 当前不存在，无法在线确认该状态设计 |
| 长姓名、长邮箱 | 正常换行、卡片增高，本轮 393 普通字号无溢出 | 当前缺少独立普通字号长内容画板 |
| 未读 3、超过 99 | 显示 3 / 99+；全部已读返回 More 后数字消失 | 当前默认画板未展示数字变体，不能宣称全部视觉状态已验收 |
| 退出远端等待、完成 | 立即进入登录页；完成后保留登录页 | 行为复现；未见独立等待态设计 |
| 退出远端失败 | 登录页提示失败，随后提示消失 | 228:1150 文案一致，视觉不一致 |
| 320/390/430、字号 1×/2× | 现有 More 测试通过，无测试捕获的溢出 | 适配通过不等于与当前 Figma 一致；不恢复用户已删除的大字号画板 |

当前 More 首页只有默认、加载两张在线画板；`122:185`、`124:68` 已无法读取。设计依据缺失与 App 实现错误分开记录，不把已删除的画板算成在线验收证据。

## 验证与边界

- 当前原有 `more_design_test.dart` + `more_redesign_states_test.dart`：10 个用例通过，未更新原 golden。
- 独立审查采集：8 个受控状态通过；复用真实 App 路由及模拟仓储的 6 个身份/错误状态通过；聚焦 More 入口、通知已读返回、退出等待的链路单独通过。
- 首次复用旧完整链路，在通知子页面寻找 `Notification settings` 的测试定位步骤失败，详见 [capture.log](capture.log)。本轮不据此认定产品缺陷；去掉通知设置/购买详情内部流程，保留本次 More 范围后，[routes-focused.log](routes-focused.log) 通过。[logout-focused.log](logout-focused.log) 单独验证退出错误及提示位置。
- 审查采集使用 `--update-goldens` **仅写入本目录**，不更新 `test/goldens` 或原始盘点清单。采集源码保留为 `.dart.source` 文件，临时测试入口已移除。
- 旧 `more_redesign_states_test.dart` 没有显式等待图片解码，因此部分 golden 缺头像/专家照片。当前真实 App 与本次预解码截图均有图片，不将旧测试截图缺图误报为产品问题。
- 本次只新增审查材料，未修改生产 UI、Figma 或原盘点结果。没有对真实已登录 App 执行退出；退出链路均在隔离测试中复现。

建议处理顺序：先统一导航规格与页面行高/卡片布局，再明确加载态退出按钮约定，随后校准专家卡片、共享失败提示；对剩余状态补足普通字号设计约定后再作完全一致性验收。
