# 重置密码

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`auth-reset`
- 范围：default
- 入口：找回密码发送验证码成功
- 路由：/login
- 实现：[auth_page.dart](../../../../lib/features/auth/presentation/auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 密码和验证码校验
- 提交中
- 失败
- 成功返回登录

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [auth-reset](../../01-auth/auth-reset/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 密码和验证码校验 | [auth-followup-reset-empty-validation](../../01-auth/auth-followup-reset-empty-validation/README.md) · [auth-followup-reset-password-validation](../../01-auth/auth-followup-reset-password-validation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 提交中 | [auth-followup-reset-pending](../../01-auth/auth-followup-reset-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 失败 | [auth-followup-reset-expired-code](../../01-auth/auth-followup-reset-expired-code/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 成功返回登录 | [auth-followup-reset-complete](../../01-auth/auth-followup-reset-complete/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-followup-reset-empty-validation/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-empty-validation/README.md) | 1 | Submit empty code and new password → field errors |
| [图](../../01-auth/auth-followup-reset-password-validation/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-password-validation/README.md) | 1 | Eight digit code and weak new password → password rule error |
| [图](../../01-auth/auth-followup-reset-resend-cooldown/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-resend-cooldown/README.md) | 1 | Immediate reset code resend → cooldown message |
| [图](../../01-auth/auth-followup-reset-rate-limited/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-rate-limited/README.md) | 1 | Retry reset → server rate limit |
| [图](../../01-auth/auth-followup-reset-pending/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-pending/README.md) | 1 | Submit → /v1/auth/reset-password request pending, form disabled |
| [图](../../01-auth/auth-reset/default.png) · [入口及前驱](../../01-auth/auth-reset/README.md) | 1 | reset form with keyboard at 390.0 / 1.0 |
| [图](../../01-auth/auth-followup-reset-code-form/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-code-form/README.md) | 1 | Recovery accepted → reset code and new password form |
| [图](../../01-auth/auth-followup-reset-expired-code/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-expired-code/README.md) | 1 | Reset submission → expired code and values retained |

## 实际操作链与状态依据

[AUTH-CURRENT.md](../AUTH-CURRENT.md)

当前表单、完整图与操作证据见 [G04 报告](../AUTH-CURRENT.md)；注册／验证剩余共用状态按 G11 核对，系统窗口按 G10 单列。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
