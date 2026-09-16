# Baby 首页区块顺序

2026-09-15：按用户要求，Figma 和 App 均将「今日吃奶」整段移到「今日状态」上方。

- Figma：独立页面「Baby · 宝宝」内 7 个包含这两个区块的首页状态全部同步（recorded、empty、loading、error、missing、active、long-name）。保留节点 ID、卡片尺寸和内容，错误提示随原状态区块移动。后续生长发育等区块位置不变。`figma-changes.json` 保存移动前后坐标与顺序。
- App：`baby_home_page.dart` 互换标题、卡片及操作入口的整体顺序，沿用原有卡片样式与交互。
- 验证：现有首页回归测试 6 项通过（390/1x、320/2x），更新对应 design_system 截图后重新运行比对通过；两文件静态分析无问题。未更新 ui_inventory 基线。
- 本地测试 App 热刷新成功，已进入 Baby 首页，`app-live.png` 和 `figma-home.png` 均确认吃奶区块在前。

[Figma Baby 首页](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=326-1086)
