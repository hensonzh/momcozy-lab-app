# G04：认证五表单当前图与长图归档

本项已完成：当前登录、注册、邮箱验证、找回与重置表单已有可用完整图；并归档已有错误、忙碌和重发状态。此次没有新增测试用例或尺寸组合，复用 9 个既有定向场景；仅在原找回密码路径中补一张“密码可见”状态。

找回密码图原本已存在于 `test/goldens/design_system/auth-forgot-390.png`，只是改版 verified 目录未单列。当前截图与已有金图严格一致，长图由实际滚动补全。

## 页面、实际入口与代表证据

| 页面／状态 | 从哪里进入 → 操作 → 去向 | 完整图 |
| --- | --- | --- |
| 登录 | 未登录进入 More → 路由重定向登录；密码眼睛点击后可见，再切回隐藏 | [reset-entry](../raw/test/goldens/ui_inventory/auth-followup-reset-entry-393-1x.png)、[login-password-visible](../raw/test/goldens/ui_inventory/auth-followup-login-password-visible-393-1x.png) |
| 注册 | 登录 → Create an account → 注册校验／提交后进入验证 | [register](../raw/test/goldens/ui_inventory/auth-journey-register-393.png)、[register-validation](../raw/test/goldens/design_system/auth-register-validation-390.png) |
| 邮箱验证 | 注册成功 → 输入验证码／重发 → 验证成功进入 More | [verify](../raw/test/goldens/ui_inventory/auth-journey-verify-393.png)、[code-validation](../raw/test/goldens/ui_inventory/auth-journey-code-validation-393.png)、[code-expired](../raw/test/goldens/ui_inventory/auth-journey-code-expired-393.png)、[resend-cooldown](../raw/test/goldens/ui_inventory/auth-journey-resend-cooldown-393.png) |
| 找回密码 | 登录 → Forgot password → 邮箱校验、请求忙碌、发送失败 | [forgot-empty](../raw/test/goldens/ui_inventory/auth-followup-forgot-empty-393-1x.png)、[forgot-validation](../raw/test/goldens/ui_inventory/auth-followup-forgot-validation-393-1x.png)、[forgot-pending](../raw/test/goldens/ui_inventory/auth-followup-forgot-pending-393-1x.png)、[forgot-offline](../raw/test/goldens/ui_inventory/auth-followup-forgot-offline-393-1x.png)、[forgot-email-unavailable](../raw/test/goldens/ui_inventory/auth-followup-forgot-email-unavailable-393-1x.png) |
| 重置密码 | 发送成功 → 验证码和新密码 → 校验、过期、限流与提交中 | [reset-code-form](../raw/test/goldens/ui_inventory/auth-followup-reset-code-form-393-1x.png)、[reset-empty-validation](../raw/test/goldens/ui_inventory/auth-followup-reset-empty-validation-393-1x.png)、[reset-password-validation](../raw/test/goldens/ui_inventory/auth-followup-reset-password-validation-393-1x.png)、[reset-expired-code](../raw/test/goldens/ui_inventory/auth-followup-reset-expired-code-393-1x.png)、[reset-rate-limited](../raw/test/goldens/ui_inventory/auth-followup-reset-rate-limited-393-1x.png)、[reset-pending](../raw/test/goldens/ui_inventory/auth-followup-reset-pending-393-1x.png) |
| 恢复完成 | 重置成功返回登录 → 新密码登录 → More | [reset-complete](../raw/test/goldens/ui_inventory/auth-followup-reset-complete-393-1x.png)、[reset-login-more](../raw/test/goldens/ui_inventory/auth-followup-reset-login-more-393-1x.png) |
| 验证与退出 | 验证成功 → More → Account → Sign out → 登录 | [account-journey-verified-more](../raw/test/goldens/ui_inventory/account-journey-verified-more-393.png)、[signed-out](../raw/test/goldens/ui_inventory/auth-journey-signed-out-393.png) |
| 登录请求与错误 | 现有状态用例：忙碌锁定、认证失败、Google 不可用、会话保存失败 | [busy-320-2x-short](../raw/test/goldens/design_system/auth-busy-320-2x-short.long.png)、[login-error-320-2x-short](../raw/test/goldens/design_system/auth-login-error-320-2x-short.long.png)、[google-error-320-2x-short](../raw/test/goldens/design_system/auth-google-error-320-2x-short.long.png)、[storage-error-320-2x-short](../raw/test/goldens/design_system/auth-storage-error-320-2x-short.long.png) |
| 验证码与重发 | 现有状态用例：校验、过期、重发等待和忙碌 | [code-validation-320-2x-short](../raw/test/goldens/design_system/auth-code-validation-320-2x-short.long.png)、[code-expired-320-2x-short](../raw/test/goldens/design_system/auth-code-expired-320-2x-short.long.png)、[resend-cooldown-320-2x-short](../raw/test/goldens/design_system/auth-resend-cooldown-320-2x-short.long.png)、[resend-busy-320-2x-short](../raw/test/goldens/design_system/auth-resend-busy-320-2x-short.long.png) |
| 附属交互 | 登录 → 语言选择／法律说明；复用现有场景 | [language](../raw/test/goldens/design_system/auth-language-390.png)、[legal](../raw/test/goldens/design_system/auth-legal-390.png) |

正常路径运行使用真实 MomCozyApp 路由与生产页面，HTTP、账号数据和平台通道使用隔离测试实现。逐状态 README 保留前驱、操作和路由记录；组件场景没有升级为正常入口证明。

## 长图和重复证据

检查了 40 个窗口的完整图，其中 8 张为短屏大字号滚动长图。长图包含标题、全部字段、错误说明、提交／重发／返回或法律页脚，没有只保留首屏。其余页面测量后无纵向溢出。新增密码可见图后，其余 39 张完整图指纹不变。

这些窗口有 37 个完整文件指纹；重复像素由总清单按宿主页面统一归并，保留每条进入和返回路径。不同错误文案、按钮禁用和验证码反馈不因共用组件被删除。

本报告关闭的是五表单当前视觉与完整图归档缺口。此前待核对的注册提交中／邮件服务失败、验证提交中已在 [G11 认证提交核对](AUTH-SUBMIT-FEEDBACK-CURRENT.md) 补齐；本报告本身的采集范围保持不变。两张 More 目的页仅证明登录／验证后的跳转，不作为 More 页面新版头像或视觉验收。

Widget 键盘占位不代表系统键盘；真实 Google 账号选择、系统浏览器和权限继续归属 G10。邀请入口归属 G12。本项没有扩大到这些测试组合。

## 记录

- [9 个既有场景严格验证](runs/20260914T075559-auth-current/capture.log)。
- [补密码可见后，仅复验找回链](runs/20260914T080136-auth-current/capture.log)：通过；密码切回隐藏并完成后续流程。
- [修改测试静态分析](runs/20260914T080136-auth-current/analyze.log)：通过。
- [全部 40 图、长图边界和源码指纹](runs/20260914T080136-auth-current/g04-audit.json)。
