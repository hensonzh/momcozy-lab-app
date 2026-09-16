# 登录恢复、验证码与辅助入口补验

新增 **33 个正常入口状态、48 张窗口图和 14 张完整纵向长图**，4 条严格采集测试通过。所有流程从未登录访问 More 触发正式路由守卫开始，不直接挂载找回密码或验证码子页面。生产行为没有修改。

## 完整链路

1. 登录 → Forgot password → 空邮箱校验 → 邮件请求离线 → 邮件服务不可用 → 请求等待 → Reset your password → 重发冷却提示 → 空验证码/密码校验 → 弱密码校验 → 验证码失效 → 请求限流 → 重置请求等待 → 登录页成功提示 → 使用新密码登录 → 正式会话保存并返回 More。这条链分别在 393 × 844 / 1x 和 320 × 844 / 2x 执行。
2. 未验证邮箱登录 → 自动发送验证邮件失败 → 重试进入验证页 → 清空邮箱后重发的必填提示 → 重发限流 → 重发请求等待 → 重发成功 → 验证并登录 → More。
3. 填写登录草稿 → Language 底部浮层 → 选择 English 后保留草稿 → 重新打开后点击遮罩关闭 → Terms of Use / Privacy Policy 外部打开失败 Snackbar → 找回密码往返 → 注册往返。

重置成功只返回登录，未建立会话且密码清空；后续再次提交登录才进入 More。请求等待时控件禁用和进度指示均有运行截图。重发验证邮件的无冷却入口来自现有 email_unverified 登录分支，没有修改生产时钟或私有页面状态。

## 证据与边界

- 使用正式 MomCozyFlutterApp、createMomCozyRouter、认证 API 和真实 runtime/session 转换；仅替换 HTTP、内存会话存储、设备 ID 和平台输入依赖。runtime 重建后继续绑定隔离 HTTP，避免合成登录成功触发远程业务请求。
- 邮箱、验证码及密码全为测试数据；没有发送真实邮件或修改用户本地账号密码。成功重置的证据证明 App 消费 API 响应及后续导航，不代表实际邮件送达或后端密码存储已验收。
- 法律链接实际点击调用原生 URL launcher 通道，本轮只模拟返回失败并验证 App Snackbar；请求目标严格断言为代码内两个链接。没有把通道返回值当成外部浏览器页面截图或官网可用性证明。
- 本轮没有安装 APK、退出当前模拟器账号或更改系统权限。原生系统输入、OAuth 选择及外部浏览器页不在这批截图的证据范围。

## 视觉审阅与产品观察

62 张原图全部分成 73 个连续片段、19 张审阅图查看：[原图清单与 SHA-256](auth-followup-visual-review/sources.json)。最终补齐测试中的一处 lint 大括号后严格重采，所有 62 张图的 SHA 一致。

14 张长图覆盖实际超高的登录、找回密码错误及大字验证码表单，从页头一直到提交、重发、返回或法律页脚。393 / 1x 大多数表单一屏可容纳；320 / 2x 的底部操作已通过滚动实际点击。横向单行输入框按当前光标位置显示部分邮箱或占位省略，不把纵向拼接称为展示了整个横向输入值。

当前视觉与反馈如实记录：

- 320 / 2x 登录页品牌名分成 `Momcoz` 和 `y` 两行；底部导航也会换行。本轮没有为了截图缩小字体。
- 重置表单先触发 60 秒冷却提示，再提交失败时，旧冷却提示与新失效/限流错误同时保留；等待重置响应时旧提示也仍在。
- 未验证邮箱登录进入验证页后，已有密码保留，而标签显示 Set password；这是现有组件行为。
- 393 宽重置后 More 截图中 Cozymate 导航头像仍为解码前占位；另一验证完成链已显示头像。两张均保留实际渲染时点，不能把前者解释为正式头像缺失。
- 法律链接失败 Snackbar 短暂遮挡页脚，表单草稿保留；语言浮层只有当前支持的 English 项。

| 审阅图 | 审阅图 | 审阅图 | 审阅图 |
| --- | --- | --- | --- |
| [分段 01](auth-followup-visual-review/sheet-01.png) | [分段 02](auth-followup-visual-review/sheet-02.png) | [分段 03](auth-followup-visual-review/sheet-03.png) | [分段 04](auth-followup-visual-review/sheet-04.png) |
| [分段 05](auth-followup-visual-review/sheet-05.png) | [分段 06](auth-followup-visual-review/sheet-06.png) | [分段 07](auth-followup-visual-review/sheet-07.png) | [分段 08](auth-followup-visual-review/sheet-08.png) |
| [分段 09](auth-followup-visual-review/sheet-09.png) | [分段 10](auth-followup-visual-review/sheet-10.png) | [分段 11](auth-followup-visual-review/sheet-11.png) | [分段 12](auth-followup-visual-review/sheet-12.png) |
| [分段 13](auth-followup-visual-review/sheet-13.png) | [分段 14](auth-followup-visual-review/sheet-14.png) | [分段 15](auth-followup-visual-review/sheet-15.png) | [分段 16](auth-followup-visual-review/sheet-16.png) |
| [分段 17](auth-followup-visual-review/sheet-17.png) | [分段 18](auth-followup-visual-review/sheet-18.png) | [分段 19](auth-followup-visual-review/sheet-19.png) |  |

## 验证结果

- 新测试 `test/features/auth/auth_followup_inventory_test.dart`：**4 PASS，0 失败**；正式采集没有更新 Golden 或放宽像素容差。[日志](runs/20260913T184941-targeted/capture.log)、[命令](runs/20260913T184941-targeted/capture-command.json)、[结果](runs/20260913T184941-targeted/capture-result.json)。
- 全仓 `flutter analyze --no-pub`：No issues found。[日志](auth-followup-analyze.log)。新测试格式只读检查 0 changed。
- 62 张复跑图片 SHA 与已审阅图片完全一致，全部状态包含实际路由、触发动作及同尺寸前驱关系。文件完整性检查另见 [结果](artifact-verification.json)，其 PASS 不代表全 App 覆盖完成。

```sh
flutter test --no-pub test/features/auth/auth_followup_inventory_test.dart --reporter expanded
python3 scripts/capture-app-ui-inventory.py --flutter /Users/lute/.local/share/momcozy-toolchains/flutter/bin/flutter --test test/features/auth/auth_followup_inventory_test.dart
```

## 逐状态索引

每状态 README 的变体表包含尺寸与字号；长图在其对应变体目录，不仅限于默认首屏。

| 状态 | 路由 | 实际操作 | 截图与前驱 |
| --- | --- | --- | --- |
| forgot-back-entry | `/login` | Login → forgot form with existing email | [状态证据](../01-auth/auth-followup-forgot-back-entry/README.md) |
| forgot-back-login | `/login` | Forgot form Back to sign in → draft retained | [状态证据](../01-auth/auth-followup-forgot-back-login/README.md) |
| forgot-email-unavailable | `/login` | Retry recovery → email service unavailable | [状态证据](../01-auth/auth-followup-forgot-email-unavailable/README.md) |
| forgot-empty | `/login` | Login forgot password → email recovery form | [状态证据](../01-auth/auth-followup-forgot-empty/README.md) |
| forgot-offline | `/login` | Recovery request offline → form retained and retry possible | [状态证据](../01-auth/auth-followup-forgot-offline/README.md) |
| forgot-pending | `/login` | Submit → /v1/auth/forgot-password request pending, form disabled | [状态证据](../01-auth/auth-followup-forgot-pending/README.md) |
| forgot-validation | `/login` | Submit empty recovery email → validation | [状态证据](../01-auth/auth-followup-forgot-validation/README.md) |
| language-dismissed | `/login` | Reopen language sheet → tap outside → login retained | [状态证据](../01-auth/auth-followup-language-dismissed/README.md) |
| language-entry | `/login` | Signed out login with synthetic form draft | [状态证据](../01-auth/auth-followup-language-entry/README.md) |
| language-selected | `/login` | Select English → close sheet and preserve email/password draft | [状态证据](../01-auth/auth-followup-language-selected/README.md) |
| language-sheet | `/login` | Language button → English selection sheet | [状态证据](../01-auth/auth-followup-language-sheet/README.md) |
| privacy-open-error | `/login` | Tap Privacy Policy. → external browser launch fails → Snackbar | [状态证据](../01-auth/auth-followup-privacy-open-error/README.md) |
| register-back-entry | `/login` | Login → registration form | [状态证据](../01-auth/auth-followup-register-back-entry/README.md) |
| register-back-login | `/login` | Register Back to sign in → login | [状态证据](../01-auth/auth-followup-register-back-login/README.md) |
| reset-code-form | `/login` | Recovery accepted → reset code and new password form | [状态证据](../01-auth/auth-followup-reset-code-form/README.md) |
| reset-complete | `/login` | Reset accepted → login with success message, password cleared, still signed out | [状态证据](../01-auth/auth-followup-reset-complete/README.md) |
| reset-empty-validation | `/login` | Submit empty code and new password → field errors | [状态证据](../01-auth/auth-followup-reset-empty-validation/README.md) |
| reset-entry | `/login` | Signed out More redirect → login | [状态证据](../01-auth/auth-followup-reset-entry/README.md) |
| reset-expired-code | `/login` | Reset submission → expired code and values retained | [状态证据](../01-auth/auth-followup-reset-expired-code/README.md) |
| reset-login-more | `/more` | Sign in with new password → real session transition restores More | [状态证据](../01-auth/auth-followup-reset-login-more/README.md) |
| reset-password-validation | `/login` | Eight digit code and weak new password → password rule error | [状态证据](../01-auth/auth-followup-reset-password-validation/README.md) |
| reset-pending | `/login` | Submit → /v1/auth/reset-password request pending, form disabled | [状态证据](../01-auth/auth-followup-reset-pending/README.md) |
| reset-rate-limited | `/login` | Retry reset → server rate limit | [状态证据](../01-auth/auth-followup-reset-rate-limited/README.md) |
| reset-resend-cooldown | `/login` | Immediate reset code resend → cooldown message | [状态证据](../01-auth/auth-followup-reset-resend-cooldown/README.md) |
| terms-open-error | `/login` | Tap Terms of Use → external browser launch fails → Snackbar | [状态证据](../01-auth/auth-followup-terms-open-error/README.md) |
| verify-entry | `/login` | Signed out More → login | [状态证据](../01-auth/auth-followup-verify-entry/README.md) |
| verify-from-login | `/login` | Retry unverified login → code sent and verification form | [状态证据](../01-auth/auth-followup-verify-from-login/README.md) |
| verify-initial-send-error | `/login` | Unverified login → automatic verification email send fails, login retained | [状态证据](../01-auth/auth-followup-verify-initial-send-error/README.md) |
| verify-more | `/more` | Verify email → authenticated intended More route | [状态证据](../01-auth/auth-followup-verify-more/README.md) |
| verify-resend-email-required | `/login` | Clear email and resend → required email feedback | [状态证据](../01-auth/auth-followup-verify-resend-email-required/README.md) |
| verify-resend-pending | `/login` | Resend code → request pending and form disabled | [状态证据](../01-auth/auth-followup-verify-resend-pending/README.md) |
| verify-resend-rate-limited | `/login` | Resend code → server rate limit | [状态证据](../01-auth/auth-followup-verify-resend-rate-limited/README.md) |
| verify-resend-success | `/login` | Resend accepted → success message | [状态证据](../01-auth/auth-followup-verify-resend-success/README.md) |

## 剩余范围

本轮补齐密码恢复主链及上述辅助入口。邮件实际投递属于这批证据的边界，不新增为 UI 盘点的后台验收条件。外部浏览器成功打开及返回、账号存储失败等尚未逐项对应的界面仍需审计；默认缺少配置的 OAuth、默认关闭的 onboarding/历史能力与默认构建分开列示。全 App 其他权限、条件交互和全体长图人工审阅仍未完成。
