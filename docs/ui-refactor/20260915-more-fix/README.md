# More 与 Figma 对齐修复 · 2026-09-15

已修复上一轮定位的布局、导航、专家卡片、加载态退出按钮和退出失败提示差异，并热更新到本地 Android App。**主要控件的位置、尺寸和状态约定已对齐；Figma 与 Flutter 的导出图片仍非逐像素完全相同。**

查看 [修复后并排截图](comparison.html)、[本地 App 截图](app-live.png)、[修复前审查](../20260915-more-review/README.md)。

## 已修复

在相同 393×844、字号 1×、不含系统安全区的条件下：

| 项目 | 修复前 | 修复后 / Figma |
|---|---|---|
| 账号卡片 y / 高 | 117 / 101 | **110 / 99** |
| 日常管理标题 y | 232 | **223** |
| 设置分组 y / 高 | 276 / 169 | **267 / 169** |
| 专家陪伴标题 y | 459 | **450** |
| 专家卡片 y / 高 | 503 / 90 | **494 / 88** |
| 专家文字 x | 91 | **90** |
| 专家标题行高 / 说明两行高 | 22 / 26 | **20 / 28** |
| 退出按钮 y / 高 | 607 / 48 | **596 / 44** |
| 导航 y / 高 | 766 / 78 | **770 / 74** |
| 五个导航中心 x | 45.7 / 121.1 / 196.5 / 271.9 / 347.3 | **35 / 115.75 / 196.5 / 277.25 / 358** |
| 导航头像 / More 选中块 | 42×42 / 42×34 | **36×36 / 44×38** |
| 退出失败可见提示背景 | 共享默认样式 | **x16 / y778 / w361 / h50，圆角 22** |

导航改用对应 Figma 的 SVG 和头像资源，恢复圆角和文字样式。专家卡片改为不占内容空间的内部描边，并校准说明颜色为 `#776E69`。

账号身份请求未完成时，退出按钮置灰禁用；请求成功或失败后恢复。姓名先返回、邮箱仍等待时维持加载态。退出仍先清除本机会话、立即转到登录页，再等待远端撤销；远端失败保留登录页并显示原错误文案。

More 退出失败终点的登录页同步校准了品牌行、介绍卡、Google 按钮、输入框、注册入口和条款链接。空密码不显示眼睛图标，输入后仍可切换显示；使用原有提交、验证、Google 登录及路由逻辑。

## 修改范围

- `lib/modules/profile/presentation/more_page.dart`：页面行高、账号卡、加载状态、退出提示。
- `lib/app/mom_bottom_navigation.dart`：仅 `/more` 使用该画板的导航布局，其它主 Tab 保留原规格。
- `lib/shared/widgets/mom_companion_widgets.dart`、`mom_settings_widgets.dart`：增加可选的内部描边布局，More 专家卡片和登录卡启用，其它调用默认不变。
- `lib/features/auth/presentation/auth_page.dart`、`auth_login_chrome.dart`：登录页及 More 退出终点的外观；注册、找回等原交互保留。
- `assets/images/more/nav_{me,baby,schedule,more}.svg`、`cozymate.png`：来自 Figma More 默认画板 122:74、122:80、122:94、122:100、122:90 的导出资源。

未修改 Figma、后端或原始 `ui_inventory` 盘点文件；未恢复已删除的大字号画板。真实 App 保留登录，本地退出测试均使用隔离仓储和会话。

## 验证

- [51 项测试通过](tests.log)：More、登录/注册/找回密码、Google 等待与失败、密码显示、会话生命周期；包含 320/390/430 和字号 1×/2×。
- [精确布局回归](alignment-test.log)：新增 `test/app/more_figma_alignment_test.dart`，直接断言 Figma 控件坐标、尺寸、导航中心，并验证加载禁用及失败恢复退出。
- [真实路由状态链 7 项通过](runtime.log)：身份加载/部分完成/单接口失败/双接口失败/长内容、入口和返回、未读清除、退出等待与错误。
- [静态检查通过](analyze.log)：本轮 11 个生产及测试文件，无问题。
- 既有 More 截图测试现在等待头像和专家照片解码，避免把未解码图片写成缺图基线。
- 更新本次改动涉及的 More/Auth 截图基线后，最终 `tests.log` 使用**不带 `--update-goldens`**的命令复测通过。
- 已对运行中的 Android 本地 App 热更新，重新进入 More 并截屏验证，未清除用户会话。

复跑命令（在 `app/` 下，使用项目 Flutter 工具链）：

```sh
flutter test test/app/more_figma_alignment_test.dart test/app/more_design_test.dart test/app/more_redesign_states_test.dart test/features/auth/auth_design_test.dart test/features/auth/auth_redesign_states_test.dart test/features/auth/consumer_auth_page_test.dart test/core/auth/account_session_lifecycle_test.dart
```

## 尚不能称为“逐像素完全相同”的部分

相同坐标和字号下，两种渲染器仍有部分文字约 1px 的基线舍入差异、字形抗锯齿差异，以及渐变/半透明颜色约 1 个通道值的量化差异。例如 Figma 的 `#FFFDFC` 导出区域部分像素为 `(255,252,252)`，Flutter 为 `(255,253,252)`；实现保留设计定义的颜色，不为适配一次 PNG 导出而改错设计色值。语言菜单箭头使用可显示的图标，避免字体缺少 `⌄` 产生方框。

[原始图像比较数据](image-comparison.json)中，默认态平均通道差由 7.5664 降至 1.8491，加载态由 7.4697 降至 1.8195，退出失败由 15.9923 降至 1.9393（单通道范围 0–255）。这些是图片误差，不是任务完成率。

身份缺失、长内容等状态仍缺少独立在线 Figma 画板。本次已验证实现的恢复行为和布局适配，但没有将这些状态描述为已有完整视觉设计验收。当前可明确确认的是：**已修复本轮列出的实现差异，并对齐现存画板的布局和交互状态；剩余渲染差异及设计依据缺口仍如实保留。**

采集源码以 `.dart.source` 保存在本目录，临时测试入口已删除；不会加入日常测试自动写审查文件。
