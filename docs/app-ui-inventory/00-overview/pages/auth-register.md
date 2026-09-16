# 注册

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`auth-register`
- 范围：default
- 入口：登录 → Create an account
- 路由：/login
- 实现：[auth_page.dart](../../../../lib/features/auth/presentation/auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 空表单
- 校验错误
- 提交中
- 发送验证码
- 服务错误

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 空表单 | [auth-register](../../01-auth/auth-register/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 校验错误 | [auth-register-validation](../../01-auth/auth-register-validation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 提交中 | [auth-followup-register-pending](../../01-auth/auth-followup-register-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 发送验证码 | [auth-journey-verify](../../01-auth/auth-journey-verify/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 服务错误 | [auth-followup-register-email-unavailable](../../01-auth/auth-followup-register-email-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-followup-register-back-entry/default.png) · [入口及前驱](../../01-auth/auth-followup-register-back-entry/README.md) | 1 | Login → registration form |
| [图](../../01-auth/auth-journey-register/default.png) · [入口及前驱](../../01-auth/auth-journey-register/README.md) | 1 | Login → Create an account |
| [图](../../01-auth/auth-followup-register-email-unavailable/default.png) · [入口及前驱](../../01-auth/auth-followup-register-email-unavailable/README.md) | 1 | Registration email service fails → form and draft retained → retry enabled |
| [图](../../01-auth/auth-register/default.png) · [入口及前驱](../../01-auth/auth-register/README.md) | 1 | email entry and registration at 390.0 / 1.0 |
| [图](../../01-auth/auth-register-validation/default.png) · [入口及前驱](../../01-auth/auth-register-validation/README.md) | 1 | email entry and registration at 390.0 / 1.0 |
| [图](../../01-auth/auth-followup-register-pending/default.png) · [入口及前驱](../../01-auth/auth-followup-register-pending/README.md) | 1 | Submit → /v1/auth/register request pending, form disabled |

## 实际操作链与状态依据

[AUTH-CURRENT.md](../AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT.md](../AUTH-SUBMIT-FEEDBACK-CURRENT.md)

G04 五表单与本次注册／验证提交状态已核对，见 AUTH-SUBMIT-FEEDBACK-CURRENT.md。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
