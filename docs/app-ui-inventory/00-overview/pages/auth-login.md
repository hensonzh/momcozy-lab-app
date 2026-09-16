# 登录

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`auth-login`
- 范围：default
- 入口：未登录打开受保护页面
- 路由：/login
- 实现：[auth_page.dart](../../../../lib/features/auth/presentation/auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 密码可见
- 提交中
- 认证错误
- 成功跳转
- Google 不可用

## 归属弹窗／浮层

auth-language

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [auth-journey-login](../../01-auth/auth-journey-login/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 密码可见 | [auth-followup-login-password-visible](../../01-auth/auth-followup-login-password-visible/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 提交中 | [auth-journey-login-busy](../../01-auth/auth-journey-login-busy/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 认证错误 | [auth-journey-invalid-credentials](../../01-auth/auth-journey-invalid-credentials/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 成功跳转 | [auth-followup-reset-login-more](../../01-auth/auth-followup-reset-login-more/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| Google 不可用 | [auth-journey-google-unavailable](../../01-auth/auth-journey-google-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-google-error-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-google-error-320-2x-short/README.md) | 1 | short large Google pending and failure leaves email recovery available |
| [图](../../01-auth/auth-journey-deleted/default.png) · [入口及前驱](../../01-auth/auth-journey-deleted/README.md) | 2 | Confirm delete → fixture success → session cleared → login plus deletion Snackbar |
| [图](../../07-me/account-current-logout-error-result/default.png) · [入口及前驱](../../07-me/account-current-logout-error-result/README.md) | 1 | Remote revoke 503 → Account-specific sign-out Snackbar |
| [图](../../07-me/more-current-logout-error-message/default.png) · [入口及前驱](../../07-me/more-current-logout-error-message/README.md) | 1 | Remote revoke returns 503 → login with sign-out failure Snackbar |
| [图](../../01-auth/auth-reset-complete/default.png) · [入口及前驱](../../01-auth/auth-reset-complete/README.md) | 1 | reset form with keyboard at 390.0 / 1.0 |
| [图](../../01-auth/auth-followup-language-entry/default.png) · [入口及前驱](../../01-auth/auth-followup-language-entry/README.md) | 1 | Signed out login with synthetic form draft |
| [图](../../01-auth/auth-legal/default.png) · [入口及前驱](../../01-auth/auth-legal/README.md) | 2 | email entry and registration at 390.0 / 1.0 |
| [图](../../01-auth/auth-busy-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-busy-320-2x-short/README.md) | 1 | short large login locks pending request then retries retained fields |
| [图](../../01-auth/auth-followup-verify-entry/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-entry/README.md) | 10 | Signed out More → login |
| [图](../../01-auth/auth-followup-privacy-open-error/default.png) · [入口及前驱](../../01-auth/auth-followup-privacy-open-error/README.md) | 1 | Tap Privacy Policy. → external browser launch fails → Snackbar |
| [图](../../01-auth/auth-followup-reset-entry/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-entry/README.md) | 2 | Signed out More redirect → login |
| [图](../../01-auth/auth-journey-password-tooltip/default.png) · [入口及前驱](../../01-auth/auth-journey-password-tooltip/README.md) | 1 | Long press password eye → native Flutter Tooltip |
| [图](../../01-auth/auth-followup-language-dismissed/default.png) · [入口及前驱](../../01-auth/auth-followup-language-dismissed/README.md) | 2 | Reopen language sheet → tap outside → login retained |
| [图](../../01-auth/auth-followup-verify-initial-send-error/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-initial-send-error/README.md) | 1 | Unverified login → automatic verification email send fails, login retained |
| [图](../../01-auth/auth-language/default.png) · [入口及前驱](../../01-auth/auth-language/README.md) | 1 | email entry and registration at 390.0 / 1.0 |
| [图](../../01-auth/auth-storage-error-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-storage-error-320-2x-short/README.md) | 1 | session persistence failure revokes issued token and keeps retry form |
| [图](../../01-auth/auth-followup-forgot-back-login/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-back-login/README.md) | 2 | Forgot form Back to sign in → draft retained |
| [图](../../01-auth/auth-followup-login-password-visible/default.png) · [入口及前驱](../../01-auth/auth-followup-login-password-visible/README.md) | 1 | Login password eye → visible synthetic password; shared field behavior |
| [图](../../01-auth/auth-journey-rate-limit/default.png) · [入口及前驱](../../01-auth/auth-journey-rate-limit/README.md) | 1 | Retry sign in; backend returns HTTP 429 |
| [图](../../01-auth/auth-journey-invalid-credentials/default.png) · [入口及前驱](../../01-auth/auth-journey-invalid-credentials/README.md) | 1 | Sign in; backend returns authentication_required |
| [图](../../01-auth/auth-journey-password-visible/default.png) · [入口及前驱](../../01-auth/auth-journey-password-visible/README.md) | 1 | Tap password eye; synthetic password is visible |
| [图](../../01-auth/auth-journey-google-unavailable/default.png) · [入口及前驱](../../01-auth/auth-journey-google-unavailable/README.md) | 1 | Continue with Google; current build has no client ID |
| [图](../../01-auth/auth-followup-reset-complete/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-complete/README.md) | 1 | Reset accepted → login with success message, password cleared, still signed out |
| [图](../../01-auth/auth-journey-login-busy/default.png) · [入口及前驱](../../01-auth/auth-journey-login-busy/README.md) | 1 | Sign in; HTTP response is still pending |
| [图](../../01-auth/auth-journey-empty-validation/default.png) · [入口及前驱](../../01-auth/auth-journey-empty-validation/README.md) | 1 | Submit empty email and password |
| [图](../../01-auth/auth-followup-language-sheet/default.png) · [入口及前驱](../../01-auth/auth-followup-language-sheet/README.md) | 1 | Language button → English selection sheet |
| [图](../../01-auth/auth-followup-terms-open-error/default.png) · [入口及前驱](../../01-auth/auth-followup-terms-open-error/README.md) | 1 | Tap Terms of Use → external browser launch fails → Snackbar |
| [图](../../01-auth/auth-login-error-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-login-error-320-2x-short/README.md) | 1 | short large login locks pending request then retries retained fields |

## 实际操作链与状态依据

[AUTH-CURRENT.md](../AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT.md](../AUTH-SUBMIT-FEEDBACK-CURRENT.md)

当前表单、完整图与操作证据见 [G04 报告](../AUTH-CURRENT.md)；注册／验证剩余共用状态按 G11 核对，系统窗口按 G10 单列。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
