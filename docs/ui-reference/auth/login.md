# 邮箱和 Google 登录

- ID：`auth/login`
- 类型：page
- 参考来源：user-approved-image
- 设计源码：[AuthPage](../source/src/pages/UserApp.tsx#L175)，第 175–190 行
- Flutter：`lib/features/auth/presentation/auth_page.dart`
- Route / 入口：`/login`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

设计工程为演示邮箱 OTP；当前真实邮箱密码/Google 流程和用户 2026-09-12 已确认稿优先保留，按统一视觉复核，禁止改回固定验证码。

[查看参考图](../auth/reference/user-approved-login.png)

原始路径：`/Users/lute/Downloads/ChatGPT Image 2026年9月12日 10_24_17.png`；SHA-256：`8c845ddbdb3d3ef097c75580594032f97f61680aa4813dc42ebe161715b81024`。


复核记录：沿用用户确认登录稿的母婴图、Libre Caslon 品牌/任务标题、暖白背景、玫瑰按钮与白色描边输入；注册/验证/找回/重置使用同一紧凑页头并保持真实邮箱密码与 8 位代码流程。注册补条款入口；步骤切换收键盘并回到顶部。53 项页面/知识回归、28 项认证核心测试通过，三宽及 2x、键盘、注册进入验证与密码重置路径有 fixture 覆盖。模拟器核对登录/注册/找回及输入校验，真实本地账号密码登录通过且已恢复登录。验证/重置页面通过实际 Flutter 金图和 API fixture 验证；未发送新的验证邮件，也不据此声称邮件投递或 Google 提供商可用。

- functional_evidence: [evidence/auth/latest-regression.txt](../evidence/auth/latest-regression.txt)
- functional_evidence: [evidence/auth/core-auth-check.txt](../evidence/auth/core-auth-check.txt)
- functional_evidence: [evidence/auth/latest-analyze.txt](../evidence/auth/latest-analyze.txt)
- functional_evidence: [evidence/auth/build.json](../evidence/auth/build.json)
- visual_evidence: [../../test/goldens/design_system/auth-login-390.png](../../../test/goldens/design_system/auth-login-390.png)
- visual_evidence: [evidence/auth/auth-login-native.png](../evidence/auth/auth-login-native.png)
- visual_evidence: [evidence/auth/auth-login-restored.png](../evidence/auth/auth-login-restored.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
