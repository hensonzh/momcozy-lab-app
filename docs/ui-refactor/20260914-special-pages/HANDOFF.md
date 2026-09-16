# 无效路由与动作评估已有界面交付

无效链接提示和动作评估已有预览／失败界面已完成 Figma 与 Flutter 更新。输入仅为最终盘点的三张既有代表图；动作评估仍无正常入口。本轮未增加路由，也不把失败画面视为成功评估结果。

## Figma 与实现

[无效路由](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=336-1086)采用居中恢复卡片：薄荷色搜索图标、清晰标题、次级说明和全宽玫瑰色返回按钮。[大字号](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=336-1096)保持完整文本与返回操作，页面可滚动。返回仍执行 `/me`，认证守卫沿用原逻辑。

[动作预览](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=336-1106)统一 Mom 字体、标题栏和结束操作。[失败恢复](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=336-1118)使用 MomSettingsCard、18 号标题和现有主题按钮；重试与退出原回调保留。深色相机背景、姿态轮廓、骨架及采样提示保留其功能表达。短屏大字号在标题下滚动恢复卡片，见[完整滚动参考](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=336-1170)。

7 个 Figma 画板包括普通／大字和一次滚动参考，不是 7 个页面。[设计读取](design-context-336-1086.json)、[失败设计读取](design-context-336-1118.json)、[实时节点](figma-live-verification.json)和[导出指纹](figma-artifacts.json)保留证据。初次生成后修正了图标居中及结束按钮宽度；最终实时节点与导出为准。Flutter 复用 MomHomeTokens、momSettingsTheme、MomSettingsCard，没有改动评估模型与生命周期。

## 验收与边界

[最终回归](final-tests.log)为两个测试文件、44 项通过，未更新截图基准。无效路由覆盖 320／390／430 和 1x／2x、返回首页及未登录守卫；动作评估测试覆盖控制器、资源释放、重试、更换控制器与退出，并在短屏大字下滚动到恢复操作。[静态分析](analyze.log)覆盖两个生产文件与两个测试文件。

[17 张运行截图](app-artifacts.json)包含 15 张受影响既有基准及无效页大字、动作失败操作末端两张补充视口。已查看 Figma 与 Flutter 普通、大字、短屏及滚动末端画面。姿态预览使用测试注入背景及真实绘制组件，不能据此声称真机摄像头或线上评估已验收。

[保留项核对](preservation-check.json)确认 App 路由、动作控制器、评估生命周期及轮廓绘制未改；三张原图与盘点 manifest 未改。[本轮差异](implementation.diff)相对 before/，旧截图保留在 before-goldens/。

最终 motion 清单的“评估”没有已有图且无正常入口，按用户“只处理已有截图”范围保留为不适用；“结果”所附证据是失败恢复界面，本轮只验证该已有界面，不声明成功结果设计或执行。后续进入最终有限页面／浮层状态与既有交付的对照。
