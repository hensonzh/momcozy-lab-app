# More

- ID：`profile/more`
- 类型：page
- 参考来源：original
- 设计源码：[MorePage](../source/src/pages/UserApp.tsx#L3262)，第 3262–3275 行
- Flutter：`lib/modules/profile/presentation/more_page.dart`
- Route / 入口：`/more`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../profile/reference/more.png)

原始路径：`me-agent-style-sync/diary-followup/15-navigation-more.png`；SHA-256：`b9dfb2393e87ee3d878c9ad111d3b7f1ef6eab8032fd1f79fafd1c56abf55730`。

[查看参考图](../profile/more-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`df45758be1845c2bd537ea207c501222eb92599ac828fb57d214343b67418197`。

[查看参考图](../profile/more-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`16a92ca557273de3661ebcbf44f5c5751a96bafd5dbc4a9c0a057cb8e06e61e6`。


复核记录：账号卡按原稿尺寸与层级实现，昵称和邮箱来自真实 profile/auth；保留的账号设置、通知、专家支持、退出入口按 menu-list 规范衍生补齐。6 项测试覆盖 320/390/430 与 2x 字号、隐私提示和三处跳转；冷启动显示 Mia/dev@example.test，未显示内部 ID。隐私详情单独验收。

- functional_evidence: [evidence/profile/verification.txt](../evidence/profile/verification.txt)
- functional_evidence: [../../test/app/more_design_test.dart](../../../test/app/more_design_test.dart)
- functional_evidence: [evidence/final-regression/verification.md](../evidence/final-regression/verification.md)
- visual_evidence: [evidence/profile/more-native.png](../evidence/profile/more-native.png)
- visual_evidence: [../../test/goldens/design_system/more-320.png](../../../test/goldens/design_system/more-320.png)
- visual_evidence: [../../test/goldens/design_system/more-390.png](../../../test/goldens/design_system/more-390.png)
- visual_evidence: [../../test/goldens/design_system/more-430.png](../../../test/goldens/design_system/more-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
