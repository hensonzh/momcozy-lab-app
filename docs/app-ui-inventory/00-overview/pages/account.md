# 账号设置

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`account`
- 范围：default
- 入口：More → Account
- 路由：/account
- 实现：[account_page.dart](../../../../lib/features/auth/presentation/account_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 身份
- 密码确认
- Google 绑定反馈
- 删除账号
- 退出

## 归属弹窗／浮层

account-confirm

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 身份 | [account-current-password-ready](../../07-me/account-current-password-ready/README.md) · [account-current-google-only-ready](../../07-me/account-current-google-only-ready/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 密码确认 | [account-current-password-entered](../../07-me/account-current-password-entered/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| Google 绑定反馈 | [account-current-google-unavailable](../../07-me/account-current-google-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 删除账号 | [account-current-delete-confirm](../../07-me/account-current-delete-confirm/README.md) · [account-current-delete-pending](../../07-me/account-current-delete-pending/README.md) · [account-current-delete-error](../../07-me/account-current-delete-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 退出 | [account-current-logout-success-result](../../07-me/account-current-logout-success-result/README.md) · [account-current-logout-error-result](../../07-me/account-current-logout-error-result/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../07-me/account-link-password-keyboard/default.png) · [入口及前驱](../../07-me/account-link-password-keyboard/README.md) | 1 | account and confirmations at 390.0 / 1.0 |
| [图](../../07-me/account-journey-link-confirm/default.png) · [入口及前驱](../../07-me/account-journey-link-confirm/README.md) | 1 | Link Google account → password confirmation dialog |
| [图](../../07-me/account-current-delete-cancelled/default.png) · [入口及前驱](../../07-me/account-current-delete-cancelled/README.md) | 11 | Cancel deletion → no mutation |
| [图](../../07-me/account-journey-load-error/default.png) · [入口及前驱](../../07-me/account-journey-load-error/README.md) | 1 | More → Account settings; account request fails |
| [图](../../07-me/account-current-delete-retry-confirm/default.png) · [入口及前驱](../../07-me/account-current-delete-retry-confirm/README.md) | 1 | Retry deletion → confirmation again |
| [图](../../07-me/account-current-loading/default.png) · [入口及前驱](../../07-me/account-current-loading/README.md) | 2 | Account GET pending → loading |
| [图](../../07-me/account-journey-loaded/default.png) · [入口及前驱](../../07-me/account-journey-loaded/README.md) | 1 | Retry → actual account details |
| [图](../../07-me/account-journey-delete-cancelled/default.png) · [入口及前驱](../../07-me/account-journey-delete-cancelled/README.md) | 2 | Cancel → account remains available |
| [图](../../07-me/account-current-delete-error/default.png) · [入口及前驱](../../07-me/account-current-delete-error/README.md) | 1 | DELETE 503 → account retained with inline error |
| [图](../../07-me/account-current-delete-confirm/default.png) · [入口及前驱](../../07-me/account-current-delete-confirm/README.md) | 2 | Request deletion → confirmation |
| [图](../../07-me/account/default.png) · [入口及前驱](../../07-me/account/README.md) | 1 | account and confirmations at 390.0 / 1.0 |
| [图](../../07-me/account-current-password-empty/default.png) · [入口及前驱](../../07-me/account-current-password-empty/README.md) | 2 | Link Google → empty password confirmation |
| [图](../../07-me/account-current-google-only-ready/default.png) · [入口及前驱](../../07-me/account-current-google-only-ready/README.md) | 1 | Account GET google-only → real identity status and provider layout |
| [图](../../07-me/account-current-password-entered/default.png) · [入口及前驱](../../07-me/account-current-password-entered/README.md) | 1 | Enter password → obscured input |
| [图](../../07-me/account-current-delete-pending/default.png) · [入口及前驱](../../07-me/account-current-delete-pending/README.md) | 2 | Confirm → DELETE pending, account actions disabled |
| [图](../../07-me/account-current-long-pending-other-ready/default.png) · [入口及前驱](../../07-me/account-current-long-pending-other-ready/README.md) | 1 | Account GET long-pending-other → real identity status and provider layout |
| [图](../../07-me/account-current-read-error/default.png) · [入口及前驱](../../07-me/account-current-read-error/README.md) | 1 | GET 503 → account error and Retry |
| [图](../../07-me/account-current-google-reopen/default.png) · [入口及前驱](../../07-me/account-current-google-reopen/README.md) | 1 | Retry Link Google → password dialog reopens |
| [图](../../07-me/account-link-password/default.png) · [入口及前驱](../../07-me/account-link-password/README.md) | 1 | account and confirmations at 390.0 / 1.0 |
| [图](../../07-me/account-journey-delete-error/default.png) · [入口及前驱](../../07-me/account-journey-delete-error/README.md) | 1 | Confirm delete → isolated HTTP failure, session retained |
| [图](../../07-me/account-current-disabled-empty-ready/default.png) · [入口及前驱](../../07-me/account-current-disabled-empty-ready/README.md) | 1 | Account GET disabled-empty → real identity status and provider layout |
| [图](../../07-me/account-journey-delete-confirm/default.png) · [入口及前驱](../../07-me/account-journey-delete-confirm/README.md) | 1 | Request account deletion → confirmation |
| [图](../../07-me/account-delete/default.png) · [入口及前驱](../../07-me/account-delete/README.md) | 1 | account and confirmations at 390.0 / 1.0 |
| [图](../../07-me/account-current-google-retry-cancelled/default.png) · [入口及前驱](../../07-me/account-current-google-retry-cancelled/README.md) | 2 | Cancel retry → previous error remains |

## 实际操作链与状态依据

[ACCOUNT-CURRENT.md](../ACCOUNT-CURRENT.md)
