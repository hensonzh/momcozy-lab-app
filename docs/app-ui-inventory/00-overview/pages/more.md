# More

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`more`
- 范围：default
- 入口：More Tab
- 路由：/more
- 实现：[more_page.dart](../../../../lib/modules/profile/presentation/more_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 身份完整与缺失
- 加载
- 未读变化
- 退出等待与错误

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 身份完整与缺失 | [more-current-identity-resolved](../../07-me/more-current-identity-resolved/README.md) · [more-current-identity-name-only-arrived](../../07-me/more-current-identity-name-only-arrived/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [more-current-identity-pending](../../07-me/more-current-identity-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 未读变化 | [more-current-inbox-return](../../07-me/more-current-inbox-return/README.md) · [notification-current-archive-final-more](../../07-me/notification-current-archive-final-more/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 退出等待与错误 | [more-current-logout-remote-pending](../../07-me/more-current-logout-remote-pending/README.md) · [more-current-logout-error-message](../../07-me/more-current-logout-error-message/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../07-me/account-current-disabled-empty-more/default.png) · [入口及前驱](../../07-me/account-current-disabled-empty-more/README.md) | 3 | More before Account settings |
| [图](../../07-me/account-journey-more/default.png) · [入口及前驱](../../07-me/account-journey-more/README.md) | 1 | Successful login saves session; guard restores More |
| [图](../../07-me/native-device-more/default.png) · [入口及前驱](../../07-me/native-device-more/README.md) | 2 | Authenticated More entry |
| [图](../../07-me/more-current-catalog-return/default.png) · [入口及前驱](../../07-me/more-current-catalog-return/README.md) | 3 | Tap page Back → /more |
| [图](../../03-mom/mom-body-control-more-return/default.png) · [入口及前驱](../../03-mom/mom-body-control-more-return/README.md) | 24 | Bottom More → original tab |
| [图](../../07-me/more-current-identity-name-only-arrived/default.png) · [入口及前驱](../../07-me/more-current-identity-name-only-arrived/README.md) | 2 | Name response arrived, email pending → combined identity still loading |
| [图](../../01-auth/auth-followup-reset-login-more/default.png) · [入口及前驱](../../01-auth/auth-followup-reset-login-more/README.md) | 2 | Sign in with new password → real session transition restores More |
| [图](../../07-me/privacy-journey-empty-back/default.png) · [入口及前驱](../../07-me/privacy-journey-empty-back/README.md) | 2 | Empty page back → More |
| [图](../../07-me/notification-current-inbox-to-more/default.png) · [入口及前驱](../../07-me/notification-current-inbox-to-more/README.md) | 8 | Inbox back → More with updated unread badge; scroll More back to top |
| [图](../../01-auth/auth-followup-verify-more/default.png) · [入口及前驱](../../01-auth/auth-followup-verify-more/README.md) | 1 | Verify email → authenticated intended More route |
| [图](../../04-baby/baby-development-boundaries-more-return/default.png) · [入口及前驱](../../04-baby/baby-development-boundaries-more-return/README.md) | 18 | Close unchanged editor → More |
| [图](../../04-baby/baby-development-date-more-return/default.png) · [入口及前驱](../../04-baby/baby-development-date-more-return/README.md) | 1 | Baby → More after date navigation; only isolated profile fixture changed |
| [图](../../07-me/more/default.png) · [入口及前驱](../../07-me/more/README.md) | 1 | More navigation and privacy at 390.0 / 1.0 |
| [图](../../07-me/account-current-delete-more/default.png) · [入口及前驱](../../07-me/account-current-delete-more/README.md) | 14 | More before Account settings |
| [图](../../07-me/notification-followup-tooltip-more/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-more/README.md) | 2 | Authenticated More entry |
| [图](../../07-me/account-current-long-pending-other-more/default.png) · [入口及前驱](../../07-me/account-current-long-pending-other-more/README.md) | 2 | More before Account settings |
| [图](../../07-me/more-current-identity-long/default.png) · [入口及前驱](../../07-me/more-current-identity-long/README.md) | 1 | More identity long from independent HTTP responses |
| [图](../../07-me/more-current-identity-both-unavailable/default.png) · [入口及前驱](../../07-me/more-current-identity-both-unavailable/README.md) | 1 | More identity both-unavailable from independent HTTP responses |
| [图](../../07-me/native-permission-allow-more/default.png) · [入口及前驱](../../07-me/native-permission-allow-more/README.md) | 4 | Authenticated More entry |
| [图](../../07-me/notification-current-archive-final-more/default.png) · [入口及前驱](../../07-me/notification-current-archive-final-more/README.md) | 20 | Back More → no unread badge; scroll More back to top |
| [图](../../07-me/notification-current-mutation-more/default.png) · [入口及前驱](../../07-me/notification-current-mutation-more/README.md) | 1 | Authenticated More before notifications; scroll More back to top |
| [图](../../07-me/notification-current-open-more/default.png) · [入口及前驱](../../07-me/notification-current-open-more/README.md) | 2 | Authenticated More before notifications; scroll More back to top |
| [图](../../07-me/more-current-identity-name-unavailable/default.png) · [入口及前驱](../../07-me/more-current-identity-name-unavailable/README.md) | 1 | More identity name-unavailable from independent HTTP responses |
| [图](../../05-agent/agent-voice-journey-new-greeting-off-away/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-new-greeting-off-away/README.md) | 1 | Tap More during voice journey |

## 实际操作链与状态依据

[MORE-CURRENT.md](../MORE-CURRENT.md)
