# 找回密码

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`auth-forgot`
- 范围：default
- 入口：登录 → Forgot password
- 路由：/login
- 实现：[auth_page.dart](../../../../lib/features/auth/presentation/auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 校验错误
- 提交中
- 发送失败
- 进入重置

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [auth-forgot](../../01-auth/auth-forgot/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 校验错误 | [auth-followup-forgot-validation](../../01-auth/auth-followup-forgot-validation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 提交中 | [auth-followup-forgot-pending](../../01-auth/auth-followup-forgot-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 发送失败 | [auth-followup-forgot-email-unavailable](../../01-auth/auth-followup-forgot-email-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |
| 进入重置 | [auth-followup-reset-code-form](../../01-auth/auth-followup-reset-code-form/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source limits retained in reports |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-followup-forgot-empty/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-empty/README.md) | 1 | Login forgot password → email recovery form |
| [图](../../01-auth/auth-followup-forgot-email-unavailable/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-email-unavailable/README.md) | 1 | Retry recovery → email service unavailable |
| [图](../../01-auth/auth-followup-forgot-offline/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-offline/README.md) | 1 | Recovery request offline → form retained and retry possible |
| [图](../../01-auth/auth-followup-forgot-validation/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-validation/README.md) | 1 | Submit empty recovery email → validation |
| [图](../../01-auth/auth-followup-forgot-pending/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-pending/README.md) | 1 | Submit → /v1/auth/forgot-password request pending, form disabled |
| [图](../../01-auth/auth-followup-forgot-back-entry/default.png) · [入口及前驱](../../01-auth/auth-followup-forgot-back-entry/README.md) | 1 | Login → forgot form with existing email |
| [图](../../01-auth/auth-forgot/default.png) · [入口及前驱](../../01-auth/auth-forgot/README.md) | 1 | reset form with keyboard at 390.0 / 1.0 |

## 实际操作链与状态依据

[AUTH-CURRENT.md](../AUTH-CURRENT.md)

当前表单、完整图与操作证据见 [G04 报告](../AUTH-CURRENT.md)；注册／验证剩余共用状态按 G11 核对，系统窗口按 G10 单列。

## 有限收尾队列进度

- G04：已完成：五表单当前图、认证操作链和完整长图已归档。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
