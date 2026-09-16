# 邮箱验证

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`auth-verify`
- 范围：default
- 入口：注册或未验证账号登录
- 路由：/login
- 实现：[auth_page.dart](../../../../lib/features/auth/presentation/auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 待输入
- 验证码错误
- 重发等待与反馈
- 提交中
- 验证成功

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 待输入 | [auth-verify](../../01-auth/auth-verify/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 验证码错误 | [auth-journey-code-validation](../../01-auth/auth-journey-code-validation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 重发等待与反馈 | [auth-followup-verify-resend-pending](../../01-auth/auth-followup-verify-resend-pending/README.md) · [auth-followup-verify-resend-success](../../01-auth/auth-followup-verify-resend-success/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 提交中 | [auth-followup-verify-submit-pending](../../01-auth/auth-followup-verify-submit-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 验证成功 | [auth-followup-verify-more](../../01-auth/auth-followup-verify-more/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-followup-verify-submit-pending/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-submit-pending/README.md) | 1 | Submit → /v1/auth/verify-email request pending, form disabled |
| [图](../../01-auth/auth-journey-code-validation/default.png) · [入口及前驱](../../01-auth/auth-journey-code-validation/README.md) | 1 | Submit without eight-digit code → field validation |
| [图](../../01-auth/auth-followup-verify-resend-rate-limited/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-resend-rate-limited/README.md) | 1 | Resend code → server rate limit |
| [图](../../01-auth/auth-followup-verify-from-login/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-from-login/README.md) | 1 | Retry unverified login → code sent and verification form |
| [图](../../01-auth/auth-journey-verify/default.png) · [入口及前驱](../../01-auth/auth-journey-verify/README.md) | 1 | Submit registration → backend verification_required → verify form |
| [图](../../01-auth/auth-followup-verify-resend-pending/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-resend-pending/README.md) | 1 | Resend code → request pending and form disabled |
| [图](../../01-auth/auth-followup-verify-resend-email-required/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-resend-email-required/README.md) | 1 | Clear email and resend → required email feedback |
| [图](../../01-auth/auth-code-validation-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-code-validation-320-2x-short/README.md) | 1 | short large verification rejects invalid code and preserves cooldown and expired state |
| [图](../../01-auth/auth-resend-busy-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-resend-busy-320-2x-short/README.md) | 1 | short large resend keeps missing email guard and disables actions while pending |
| [图](../../01-auth/auth-resend-cooldown-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-resend-cooldown-320-2x-short/README.md) | 1 | short large verification rejects invalid code and preserves cooldown and expired state |
| [图](../../01-auth/auth-code-expired-320-2x-short/default.png) · [入口及前驱](../../01-auth/auth-code-expired-320-2x-short/README.md) | 1 | short large verification rejects invalid code and preserves cooldown and expired state |
| [图](../../01-auth/auth-journey-resend-cooldown/default.png) · [入口及前驱](../../01-auth/auth-journey-resend-cooldown/README.md) | 1 | Immediately resend → cooldown message |
| [图](../../01-auth/auth-verify/default.png) · [入口及前驱](../../01-auth/auth-verify/README.md) | 1 | email entry and registration at 390.0 / 1.0 |
| [图](../../01-auth/auth-journey-code-expired/default.png) · [入口及前驱](../../01-auth/auth-journey-code-expired/README.md) | 1 | Verify email → invalid_or_expired_code |
| [图](../../01-auth/auth-followup-verify-resend-success/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-resend-success/README.md) | 1 | Resend accepted → success message |

## 实际操作链与状态依据

[AUTH-CURRENT.md](../AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT.md](../AUTH-SUBMIT-FEEDBACK-CURRENT.md)

G04 五表单与本次注册／验证提交状态已核对，见 AUTH-SUBMIT-FEEDBACK-CURRENT.md。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
