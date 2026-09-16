# 认证五表单：逐状态截图与去向

将既有定义中的 26 个状态逐项接到已存在的截图和操作链，没有新增截图。成功状态使用实际目的页，发送验证码和重置完成按到达的表单归属，不为同一个返回页面制造新图。

| 页面／状态 | 图与前后操作 | 实际路由 |
| --- | --- | --- |
| auth-login / 初始 | [auth-journey-login](../01-auth/auth-journey-login/README.md) | /login |
| auth-login / 密码可见 | [auth-followup-login-password-visible](../01-auth/auth-followup-login-password-visible/README.md) | /login |
| auth-login / 提交中 | [auth-journey-login-busy](../01-auth/auth-journey-login-busy/README.md) | /login |
| auth-login / 认证错误 | [auth-journey-invalid-credentials](../01-auth/auth-journey-invalid-credentials/README.md) | /login |
| auth-login / 成功跳转 | [auth-followup-reset-login-more](../01-auth/auth-followup-reset-login-more/README.md) | /more |
| auth-login / Google 不可用 | [auth-journey-google-unavailable](../01-auth/auth-journey-google-unavailable/README.md) | /login |
| auth-register / 空表单 | [auth-register](../01-auth/auth-register/README.md) | 组件表单；入口由报告另证 |
| auth-register / 校验错误 | [auth-register-validation](../01-auth/auth-register-validation/README.md) | 组件表单；入口由报告另证 |
| auth-register / 提交中 | [auth-followup-register-pending](../01-auth/auth-followup-register-pending/README.md) | /login |
| auth-register / 发送验证码 | [auth-journey-verify](../01-auth/auth-journey-verify/README.md) | /login |
| auth-register / 服务错误 | [auth-followup-register-email-unavailable](../01-auth/auth-followup-register-email-unavailable/README.md) | /login |
| auth-verify / 待输入 | [auth-verify](../01-auth/auth-verify/README.md) | 组件表单；入口由报告另证 |
| auth-verify / 验证码错误 | [auth-journey-code-validation](../01-auth/auth-journey-code-validation/README.md) | /login |
| auth-verify / 重发等待与反馈 | [auth-followup-verify-resend-pending](../01-auth/auth-followup-verify-resend-pending/README.md) · [auth-followup-verify-resend-success](../01-auth/auth-followup-verify-resend-success/README.md) | /login / /login |
| auth-verify / 提交中 | [auth-followup-verify-submit-pending](../01-auth/auth-followup-verify-submit-pending/README.md) | /login |
| auth-verify / 验证成功 | [auth-followup-verify-more](../01-auth/auth-followup-verify-more/README.md) | /more |
| auth-forgot / 初始 | [auth-forgot](../01-auth/auth-forgot/README.md) | 组件表单；入口由报告另证 |
| auth-forgot / 校验错误 | [auth-followup-forgot-validation](../01-auth/auth-followup-forgot-validation/README.md) | /login |
| auth-forgot / 提交中 | [auth-followup-forgot-pending](../01-auth/auth-followup-forgot-pending/README.md) | /login |
| auth-forgot / 发送失败 | [auth-followup-forgot-email-unavailable](../01-auth/auth-followup-forgot-email-unavailable/README.md) | /login |
| auth-forgot / 进入重置 | [auth-followup-reset-code-form](../01-auth/auth-followup-reset-code-form/README.md) | /login |
| auth-reset / 初始 | [auth-reset](../01-auth/auth-reset/README.md) | 组件表单；入口由报告另证 |
| auth-reset / 密码和验证码校验 | [auth-followup-reset-empty-validation](../01-auth/auth-followup-reset-empty-validation/README.md) · [auth-followup-reset-password-validation](../01-auth/auth-followup-reset-password-validation/README.md) | /login / /login |
| auth-reset / 提交中 | [auth-followup-reset-pending](../01-auth/auth-followup-reset-pending/README.md) | /login |
| auth-reset / 失败 | [auth-followup-reset-expired-code](../01-auth/auth-followup-reset-expired-code/README.md) | /login |
| auth-reset / 成功返回登录 | [auth-followup-reset-complete](../01-auth/auth-followup-reset-complete/README.md) | /login |

找回密码提交中因按钮显示进度而不再出现 Send reset code，旧归类规则误归登录页；现根据该表单独有说明文字归入找回密码页。重置入口和验证入口的前驱截图仍是登录页，已读取实际画面文本确认，不按测试名称机械改归属。

原图、长图和真实交互范围分别见 [五表单核验](AUTH-CURRENT.md)、[注册及验证提交反馈](AUTH-SUBMIT-FEEDBACK-CURRENT.md)、[系统窗口](NATIVE-WINDOWS-CATALOG.md)。这里只确认状态对应，不扩展错误码、输入值或尺寸组合。
