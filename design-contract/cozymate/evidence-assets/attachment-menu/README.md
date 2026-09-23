# Cozymate 附件菜单：Figma → Flutter 校准

基准：[Figma 259:1108](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=259-1108)，所在完整对话画板 259:1097，Cozymate Page 567:1132。

本次只验收附件来源菜单。完整对话页面、输入框、附件缩略图、导航等未在本次重新进行全面视觉验收，不应标记为全部对齐。

| 项目 | 设计 / 实现 |
| --- | --- |
| 默认菜单 | 220 × 156，圆角 18，内边距 6，无投影 |
| 选项 | 208 × 48，内边距 6，图文间距 10 |
| 图标底块 | 32 × 32，圆角 10，#F5E7ED |
| 图标 | 18 × 18，Figma 原始资源，#A14D72 |
| 标题 | Noto Sans SC Bold，14 / 18 |
| 说明 | Noto Sans SC Regular，11 / 14，标题间距 2 |
| 菜单表面 / 边框 | #FFFDFC / #E9DFE4 |
| 定位 | 左侧与输入框对齐，向上展开时距输入框 8 |

实现：`lib/features/agent_hub/agent_hub_page.dart` 的 `_attachmentMenuItem` 和 MenuAnchor。相机、照片、文件入口及选择回调保留。大字体下允许菜单宽高自然增加，仍检查 320 / 390 / 430 宽、1× / 2× 字号。

资源映射：259:1111 → `assets/images/cozymate_attachment_camera.png`（54×54，以 18×18 渲染）；259:1118 → `cozymate_attachment_photo.svg`；259:1125 → `cozymate_attachment_file.svg`。相机的 MCP SVG 导出缺少镜头细节，改用同节点完整 3× 透明 PNG；另两个 SVG 原样保存，未重绘。

证据：`figma-menu.png` 是 Figma 独立导出，`app-capture.png` 是 393×844、DPR 1、文字缩放 1 的 Flutter 实际 Overlay 截图。按 `app-menu-bounds.json` 裁出 `app-menu.png`，组件尺寸保持 220×156，未缩放对齐。`comparison/` 含并排、50% 叠图、差异图。菜单外圆角区域底色和平台字体抗锯齿存在渲染差异；差异指标不作为像素一致性通过率。

验证：菜单几何与操作回归、6 组尺寸/字号布局检查、Agent Hub 相关测试、静态分析。先按独立 Figma 图校准，再更新涉及菜单的 App golden。

设备复核完成：已更新 Android emulator-5554 的 local debug App，打开 Cozymate 附件菜单，三个图标均加载正常，浅粉色、紧凑尺寸、无投影及输入框上方定位已生效；完整设备截图见 `native-menu.png`。保留设备原有登录和聊天数据。196 项 Agent Hub 相关测试通过，涉及文件静态分析无问题。
