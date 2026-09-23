# 共享底部导航补正

上一轮把“复用 App 中 Me 的现有导航”误当成了“对齐 Figma 中 Me 的最终导航”，因此保留了旧线框图标和紫色选中态。本轮纠正这一遗漏，直接修改五个主入口共用的 `MomCozyBottomNavigation`。

基准：[Me 483:1058](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl/?node-id=483-1058)、[Baby 691:116](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl/?node-id=691-116)。

- 使用 Figma 原始 Me/Baby 立体头像、彩色 Schedule/More 图标和 Cozymate 导航头像；保留原色，无统一着色滤镜。
- 主体 82px，普通图标 28px，图标槽 42×34、圆角 14，选中背景 `#F8E8EF`、文字 `#A14D72`，未选文字 `#786D77`，底色 `#FFFCFA`。
- DM Sans 12/16，五等分；Cozymate 58px 外框、54px 头像，较导航顶边凸起 14px。额外预留 18px 容纳头像及阴影，且让凸出部分处于真实可点击范围。系统底部安全区另计，大字体时随标签增高。
- 五个入口的路由保持原有行为，所有主页面共享此次更新。

独立截图包括整个底栏及凸起头像，没有裁掉 App shell。参考透明区域和 App 都合成到白色，对照尺寸为 Me 393×100、Baby 390×100：

- [Me 并排图（左设计、右 App）](me/side-by-side.png) · [叠图](me/overlay.png)
- [Baby 并排图（左设计、右 App）](baby/side-by-side.png) · [叠图](baby/overlay.png)
- [5 份原始资源校验](assets.json)

`flutter analyze` 无问题；共享导航、More 页面、根路由和 Baby 等相关测试共 133 项通过。覆盖三个宽度、2× 大字、五入口切换以及凸起头像上半部分点击。仅更新受本次底栏影响的导航/More golden，Figma 参考独立保留。字体栅格化存在小幅差异，差异均值不是还原度百分比。

已将“完整页面必须单独核验公共导航，复用不等于设计一致”补入 `figma-to-app` skill，避免再次遗漏。

本地 `1.0.0+57 local/debug` 已重新安装到 `emulator-5554`，保留登录和数据。原生验证了 Me/Baby 选中态、页面切换及凸起头像上半部分点击跳转，并停留在 Baby 页面。见 [Me 实机渲染](native-me-bar.png)、[Baby 实机渲染](native-baby-bar.png)、[验证记录及 APK 校验值](native-verification.json)。这里只是 Android 模拟器核验，未发布云端。
