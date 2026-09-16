# 条款与隐私链接

- ID：`auth/legal`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[条款与隐私链接（衍生设计）](../auth/derived/legal.md#L1)，第 1–22 行
- Flutter：`lib/features/auth/presentation/auth_page.dart`
- Route / 入口：`/login`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：24 项设计测试及 70 项认证回归通过，三宽/2x/键盘覆盖。语言仅 English；条款及隐私链接在模拟器实际打开官方页面并返回，测试账号已恢复登录。邀请码仅受控测试，未消耗真实邀请码。

- functional_evidence: [evidence/auth-secondary/verification.md](../evidence/auth-secondary/verification.md)
- functional_evidence: [evidence/auth-secondary/design-tests.txt](../evidence/auth-secondary/design-tests.txt)
- functional_evidence: [evidence/auth-secondary/regression.txt](../evidence/auth-secondary/regression.txt)
- functional_evidence: [evidence/auth-secondary/analyze.txt](../evidence/auth-secondary/analyze.txt)
- functional_evidence: [evidence/auth-secondary/build.txt](../evidence/auth-secondary/build.txt)
- functional_evidence: [evidence/auth-secondary/legal-links.json](../evidence/auth-secondary/legal-links.json)
- visual_evidence: [../../test/goldens/design_system/auth-legal-390.png](../../../test/goldens/design_system/auth-legal-390.png)
- visual_evidence: [evidence/auth-secondary/auth-legal-return-privacy-security.png](../evidence/auth-secondary/auth-legal-return-privacy-security.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
