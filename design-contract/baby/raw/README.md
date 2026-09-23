# Baby：Figma → Flutter 视觉校准

日期：2026-09-21。基准为 [Baby 最终设计页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl/?node-id=370-1022)，以最新确认需求覆盖旧画板状态。此报告对应本轮视觉校准；此前功能、动效及本地后端部署记录见 [App 交付文档](../../../docs/product/baby-app-uiux-20260920.md)。

**底栏补正：** 第一轮仅复用了 App 现有底栏，遗漏了 Me 最终导航的视觉同步。下文原有 21 个对比不包含底栏，不能代表完整页面验收。现已另外按 `483:1058` / `691:116` 更新共享底栏，完成独立比对及回归，见 [底栏补正记录](../evidence-assets/navigation/README.md)。

## 本轮修正

- 原始头像、图标、必填符号和卡片装饰共 30 份资源本地化；来源、尺寸和校验值见 [assets.json](assets.json)。文字、输入、选择项、图表仍由原生 Flutter 组件和真实数据驱动。
- 校准首页卡片、资料页、切换宝宝、记录表单及知识弹窗的内边距、行高、控件高度、描边、圆角和选中颜色；底栏继续复用 Me 的 App shell。
- 统一表单标题 20/28、标签 15/22、数值 16/24；使用随包 Noto Sans SC 可变字体及明确字重。日期、时间和关闭符号使用设计原始字形资源，避免设备缺字。
- 表单卡片使用内描边，不让边框额外扩大内容间距。修正共享日期控件的样式覆盖顺序，默认使用者行为保持不变。
- 修正资料保存后的标题更新、长标题截断宽度，以及保存中仅输入和选择项失活的视觉；保留点击时快照、草稿跨页签保留、统一保存和失败重试逻辑。
- 弹窗位于根导航之上，外部点击可关闭。首页保留底栏突出头像所需间距，没有把设计长内容高度当作设备视口或补入大段滚动空白。

## 可复查的截图证据

设计参考和 App 渲染独立保存。每个对比目录包含 `side-by-side.png`（左 Figma、右 App）、`overlay.png`、`difference.png` 和参数 `comparison.json`。

| 范围 | 已完成同尺寸比对的状态 |
|---|---|
| 首页 | 已记录长内容、真实绘制的体重趋势容器 |
| 资料 | 未修改、新建、已修改、保存中、已保存、再次修改、长称呼 |
| 喂养 | 瓶喂、亲喂、未完成必填、保存中、保存失败 |
| 今日状态 | 精神状态未选/已选、其他页签有草稿、尿湿、便便 |
| 其他 | 生长记录、切换宝宝、饥饱知识弹窗 |

合计 21 个视图/状态，见 [comparison-cases.json](comparison-cases.json)。完整节点目录见 [manifest.json](manifest.json)，目录存在不代表每个节点都完成像素核验。

本轮通过官方 Figma MCP 补齐了 manifest 中此前未落地的 11 个首页/生长节点参考图，存放在 `../references/figma-*.png`；对应 Flutter 同尺寸截图存放在 `../comparisons/actual-home-states/`，逐状态索引见 [home-state-captures.json](../comparisons/home-state-captures.json)。

- [首页并排图](../comparisons/comparison-current-final/home/side-by-side.png)
- [喂养并排图](../comparisons/comparison-current-final/feeding/side-by-side.png)
- [便便并排图](../comparisons/comparison-current-final/stool/side-by-side.png)
- [生长记录并排图](../comparisons/comparison-current-final/growth/side-by-side.png)
- [资料保存中并排图](../comparisons/comparison-current-final/profile-saving/side-by-side.png)
- [知识弹窗并排图](../comparisons/comparison-current-final/knowledge/side-by-side.png)
- [切换宝宝并排图](../comparisons/comparison-current-final/switcher/side-by-side.png)

表单/资料使用 393×844 逻辑视口、DPR 1、顶部 24 / 底部 34 的固定安全区；首页长内容使用 390px 宽。隔离仓库固定 Luna、出生日期 2026-08-22、2026-09-13 日期及亚洲上海时区，未向真实账号写入这些示例。

弹窗只裁切前景内容，并排除参考中的 34px 模拟系统手势区；资料排除相同底部区域。App 不绘制假的系统条。首页去掉额外 20px 的底栏突出头像避让空间，再与 1216px 长内容比较。所有裁切坐标已记录，未进行任意拉伸。

复现：在 `app` 中运行 `flutter test test/modules/baby/baby_figma_capture_test.dart`，得到 `build/figma-comparison/*.png` 和前景边界；按 cases 清单调用 skill 的 `scripts/compare_screens.py`。比较脚本拒绝尺寸不一致，差异均值只是诊断数据，不是“还原度百分比”。

## 验证和边界

- `flutter analyze`：无问题，见 [日志](../evidence-assets/flutter-analyze.log)。
- `flutter test test/modules/baby test/app/baby_route_refresh_test.dart test/app/navigation_figma_capture_test.dart test/shared/route_motion_test.dart test/app/status_card_accessibility_test.dart`：116 项通过。包含 320/393/430px、大文字、键盘、根导航浮层、草稿、保存锁定、失败、动效和 11 个新增同尺寸状态夹具。
- 30 份资源均非空，可解析；运行代码不引用 Figma 临时下载 URL。
- `figma-to-app` skill 结构校验通过；脚本验证了相同图零差异、尺寸不一致拒绝、显式 DPR、裁切和越界拒绝。

已对齐所列页面的主要几何、颜色及资源；未宣称所有像素完全一致。仍有文字栅格化及部分字形基线的小幅差异。资料标题在宝宝称呼后统一保留空格，部分旧参考标题没有该空格。

首页实际年龄显示到天（参考为整周）；这与当前数据规则一致。曲线使用实际 WHO 参考数据与真实测量日期，形状/点位不会机械复制设计示意。无资料首页的导航图片首帧和长名称末字裁切仍按夹具限制记录在 `evidence.json`，没有冒充像素验收通过。Android 原生复核使用现有本地账号，数据与隔离截图不同。

## 可复用 skill

已安装到 `$CODEX_HOME/skills/figma-to-app/`。包括 `SKILL.md`、Flutter 注意事项、截图对比脚本和 Codex skill 元数据。后续可使用 `$figma-to-app`；流程要求最终节点清单、原始素材、原生交互、同尺寸比对、状态回归、设备复核及如实记录差异。

## 本地安装复核

已通过项目现有入口 `MOMCOZY_RESET_INVITE_APP=0 node scripts/run-flutter-invite-dev.mjs --no-resident` 构建并更新 Android `emulator-5554`，版本 `1.0.0+57`、`local/debug`。现有登录和账号数据保留，未提交任何测试记录；未发布云端或公开 APK。

原生界面复核通过：喂养必填禁用/补全激活、瓶喂二级选项、弹窗外部关闭、知识弹窗头像、切换宝宝、资料页返回、首页滚动末端。最终小图标已用 SVG 轮廓替换 1× PNG，设备上清晰显示。页面末端只保留底栏头像避让间距。

见 [原生检查结果](../evidence-assets/native/verification.json)、[构建元数据及 SHA256](../evidence-assets/native/build.json)、[首页](../evidence-assets/native/home.png)、[喂养](../evidence-assets/native/feeding-selected.png)、[知识弹窗](../evidence-assets/native/knowledge.png)、[资料页](../evidence-assets/native/profile.png)、[滚动末端](../evidence-assets/native/home-bottom.png)。本次是 Android 模拟器检查，未进行 iOS/物理真机或帧率测量。构建通过，已有插件的 KGP 迁移提示为非阻断警告。
