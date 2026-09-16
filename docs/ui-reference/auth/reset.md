# 重置密码

- ID：`auth/reset`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[重置密码（衍生设计）](../auth/derived/reset.md#L1)，第 1–22 行
- Flutter：`lib/features/auth/presentation/auth_page.dart`
- Route / 入口：`/login`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：沿用用户确认登录稿的母婴图、Libre Caslon 品牌/任务标题、暖白背景、玫瑰按钮与白色描边输入；注册/验证/找回/重置使用同一紧凑页头并保持真实邮箱密码与 8 位代码流程。注册补条款入口；步骤切换收键盘并回到顶部。53 项页面/知识回归、28 项认证核心测试通过，三宽及 2x、键盘、注册进入验证与密码重置路径有 fixture 覆盖。模拟器核对登录/注册/找回及输入校验，真实本地账号密码登录通过且已恢复登录。验证/重置页面通过实际 Flutter 金图和 API fixture 验证；未发送新的验证邮件，也不据此声称邮件投递或 Google 提供商可用。

- functional_evidence: [evidence/auth/latest-regression.txt](../evidence/auth/latest-regression.txt)
- functional_evidence: [evidence/auth/core-auth-check.txt](../evidence/auth/core-auth-check.txt)
- functional_evidence: [evidence/auth/latest-analyze.txt](../evidence/auth/latest-analyze.txt)
- functional_evidence: [evidence/auth/build.json](../evidence/auth/build.json)
- visual_evidence: [../../test/goldens/design_system/auth-reset-390.png](../../../test/goldens/design_system/auth-reset-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
