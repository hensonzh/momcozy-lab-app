# 通知中心

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`notifications`
- 范围：default
- 入口：More → Notifications
- 路由：/notifications
- 实现：[notifications_page.dart](../../../../lib/features/notifications/presentation/notifications_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 空
- 未读与已读
- 分页
- 归档
- 加载
- 错误
- 跳转反馈

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 空 | [notification-current-inbox-empty](../../07-me/notification-current-inbox-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 未读与已读 | [notification-current-inbox-first-page](../../07-me/notification-current-inbox-first-page/README.md) · [notification-current-inbox-all-read](../../07-me/notification-current-inbox-all-read/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 分页 | [notification-current-inbox-second-page](../../07-me/notification-current-inbox-second-page/README.md) · [notification-current-inbox-last-page](../../07-me/notification-current-inbox-last-page/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 归档 | [notification-current-inbox-archived](../../07-me/notification-current-inbox-archived/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [notification-current-inbox-loading](../../07-me/notification-current-inbox-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [notification-current-inbox-read-error](../../07-me/notification-current-inbox-read-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 跳转反馈 | [notification-current-notification-open-error](../../07-me/notification-current-notification-open-error/README.md) · [notification-current-notification-target-unavailable](../../07-me/notification-current-notification-target-unavailable/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../07-me/notification-journey-pagination-loading/default.png) · [入口及前驱](../../07-me/notification-journey-pagination-loading/README.md) | 1 | Load more → pending next page with first page retained |
| [图](../../07-me/notification-current-inbox-last-page/default.png) · [入口及前驱](../../07-me/notification-current-inbox-last-page/README.md) | 1 | Load final page → full list, no load-more CTA |
| [图](../../07-me/notification-current-tooltip-notification-settings/default.png) · [入口及前驱](../../07-me/notification-current-tooltip-notification-settings/README.md) | 1 | Long press Notification settings → tooltip, action not invoked |
| [图](../../07-me/notification-navigation-current-rejection-403/default.png) · [入口及前驱](../../07-me/notification-navigation-current-rejection-403/README.md) | 2 | Open notification returns 403 → retained unread item and open-error Snackbar |
| [图](../../07-me/more-current-inbox-read/default.png) · [入口及前驱](../../07-me/more-current-inbox-read/README.md) | 2 | Mark all read → inbox read and count zero |
| [图](../../07-me/notification-journey-notification-target-unavailable/default.png) · [入口及前驱](../../07-me/notification-journey-notification-target-unavailable/README.md) | 1 | Retry open → server reports resource unavailable, item read, no navigation |
| [图](../../07-me/more-current-inbox-unread/default.png) · [入口及前驱](../../07-me/more-current-inbox-unread/README.md) | 2 | Notifications row → real inbox preserving from=/more |
| [图](../../07-me/notification-current-inbox-second-page/default.png) · [入口及前驱](../../07-me/notification-current-inbox-second-page/README.md) | 2 | Load more → append second page |
| [图](../../07-me/notification-current-pagination-loading/default.png) · [入口及前驱](../../07-me/notification-current-pagination-loading/README.md) | 1 | Load more → pending next page with first page retained |
| [图](../../07-me/notification-journey-archive-pending/default.png) · [入口及前驱](../../07-me/notification-journey-archive-pending/README.md) | 1 | Archive update → row spinner while request pending |
| [图](../../07-me/notification-journey-appointment-to-inbox/default.png) · [入口及前驱](../../07-me/notification-journey-appointment-to-inbox/README.md) | 1 | Appointment back → notification center with read state |
| [图](../../07-me/notification-current-notification-target-unavailable/default.png) · [入口及前驱](../../07-me/notification-current-notification-target-unavailable/README.md) | 2 | Retry open → server reports resource unavailable, item read, no navigation |
| [图](../../07-me/notification-current-inbox-read-error/default.png) · [入口及前驱](../../07-me/notification-current-inbox-read-error/README.md) | 1 | Empty inbox read fails → error and retry |
| [图](../../07-me/native-permission-allow-inbox/default.png) · [入口及前驱](../../07-me/native-permission-allow-inbox/README.md) | 4 | Tap notifications → actual empty inbox |
| [图](../../07-me/notification-journey-inbox-second-page/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-second-page/README.md) | 2 | Load more → append second page |
| [图](../../07-me/notification-current-inbox-archived/default.png) · [入口及前驱](../../07-me/notification-current-inbox-archived/README.md) | 1 | Archive last update → removed immediately, unread count refreshed |
| [图](../../07-me/notification-current-inbox-loading/default.png) · [入口及前驱](../../07-me/notification-current-inbox-loading/README.md) | 1 | Refresh empty inbox → pending response |
| [图](../../07-me/notifications-empty/default.png) · [入口及前驱](../../07-me/notifications-empty/README.md) | 1 | inbox and retained-content error at 390.0 / 1.0 |
| [图](../../07-me/notification-navigation-current-rejection-403-dismissed/default.png) · [入口及前驱](../../07-me/notification-navigation-current-rejection-403-dismissed/README.md) | 2 | Open-error feedback timeout → retained notification center |
| [图](../../07-me/notification-current-archive-final-empty/default.png) · [入口及前驱](../../07-me/notification-current-archive-final-empty/README.md) | 10 | Archive only notification → empty inbox and count zero |
| [图](../../05-agent/agent-history-journey-external-target/default.png) · [入口及前驱](../../05-agent/agent-history-journey-external-target/README.md) | 3 | Open notification → route allowlist rejects external-target; inbox and message retained |
| [图](../../05-agent/agent-history-journey-read-notification/default.png) · [入口及前驱](../../05-agent/agent-history-journey-read-notification/README.md) | 2 | Return to inbox → conversation notification marked read despite target initialization error |
| [图](../../07-me/notification-journey-mark-all-error/default.png) · [入口及前驱](../../07-me/notification-journey-mark-all-error/README.md) | 1 | Mark-all request fails → unread updates and retry banner retained |
| [图](../../07-me/notification-current-archive-pending/default.png) · [入口及前驱](../../07-me/notification-current-archive-pending/README.md) | 1 | Archive update → row spinner while request pending |
| [图](../../07-me/notification-navigation-current-conversation-inbox-return/default.png) · [入口及前驱](../../07-me/notification-navigation-current-conversation-inbox-return/README.md) | 5 | Target return → notification center with read item |
| [图](../../07-me/notification-journey-pagination-error/default.png) · [入口及前驱](../../07-me/notification-journey-pagination-error/README.md) | 1 | Next page read fails → first page and error banner retained |
| [图](../../07-me/notification-followup-tooltip-refresh-notifications/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-refresh-notifications/README.md) | 1 | Long press Refresh notifications → actual Tooltip overlay |
| [图](../../07-me/notifications-read/default.png) · [入口及前驱](../../07-me/notifications-read/README.md) | 1 | inbox and retained-content error at 390.0 / 1.0 |
| [图](../../07-me/notification-journey-inbox-loading/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-loading/README.md) | 1 | Refresh empty inbox → pending response |
| [图](../../07-me/notification-current-inbox-open-entry/default.png) · [入口及前驱](../../07-me/notification-current-inbox-open-entry/README.md) | 2 | More → unread service updates |
| [图](../../07-me/notification-journey-archive-pending-completed/default.png) · [入口及前驱](../../07-me/notification-journey-archive-pending-completed/README.md) | 2 | Archive response → row removed and count refreshed |
| [图](../../07-me/notification-journey-inbox-read-error/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-read-error/README.md) | 1 | Empty inbox read fails → error and retry |
| [图](../../07-me/notification-current-mark-all-error/default.png) · [入口及前驱](../../07-me/notification-current-mark-all-error/README.md) | 1 | Mark-all request fails → unread updates and retry banner retained |
| [图](../../07-me/notification-current-tooltip-archive-notification-dismissed/default.png) · [入口及前驱](../../07-me/notification-current-tooltip-archive-notification-dismissed/README.md) | 10 | Tooltip timeout → same inbox |
| [图](../../07-me/notification-journey-inbox-first-page/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-first-page/README.md) | 1 | Retry → first three updates with unread count and load more |
| [图](../../07-me/notification-journey-archive-error/default.png) · [入口及前驱](../../07-me/notification-journey-archive-error/README.md) | 1 | Archive request fails → row retained and error banner |
| [图](../../07-me/notification-current-appointment-to-inbox/default.png) · [入口及前驱](../../07-me/notification-current-appointment-to-inbox/README.md) | 2 | Appointment back → notification center with read state |
| [图](../../07-me/notification-current-pagination-error/default.png) · [入口及前驱](../../07-me/notification-current-pagination-error/README.md) | 1 | Next page read fails → first page and error banner retained |
| [图](../../07-me/notification-journey-notification-open-error/default.png) · [入口及前驱](../../07-me/notification-journey-notification-open-error/README.md) | 1 | Open update request fails → inbox retained with Snackbar |
| [图](../../07-me/notification-journey-inbox-archived/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-archived/README.md) | 1 | Archive last update → removed immediately, unread count refreshed |
| [图](../../07-me/notification-followup-tooltip-archive-notification/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-archive-notification/README.md) | 1 | Long press Archive notification → actual Tooltip overlay |
| [图](../../07-me/notification-current-notification-open-error/default.png) · [入口及前驱](../../07-me/notification-current-notification-open-error/README.md) | 1 | Open update request fails → inbox retained with Snackbar |
| [图](../../07-me/notification-current-archive-error/default.png) · [入口及前驱](../../07-me/notification-current-archive-error/README.md) | 1 | Archive request fails → row retained and error banner |
| [图](../../07-me/notification-current-tooltip-refresh-notifications/default.png) · [入口及前驱](../../07-me/notification-current-tooltip-refresh-notifications/README.md) | 1 | Long press Refresh notifications → tooltip, action not invoked |
| [图](../../07-me/notification-current-inbox-all-read/default.png) · [入口及前驱](../../07-me/notification-current-inbox-all-read/README.md) | 2 | Mark all read → server state refreshed, unread badge cleared |
| [图](../../05-agent/agent-history-journey-notification-entry/default.png) · [入口及前驱](../../05-agent/agent-history-journey-notification-entry/README.md) | 1 | More → notification inbox with conversation update |
| [图](../../07-me/notification-current-mark-all-pending/default.png) · [入口及前驱](../../07-me/notification-current-mark-all-pending/README.md) | 1 | Mark all read pending → action disabled, unread count preserved |
| [图](../../07-me/notification-journey-inbox-all-read/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-all-read/README.md) | 2 | Mark all read → server state refreshed, unread badge cleared |
| [图](../../07-me/notification-journey-inbox-last-page/default.png) · [入口及前驱](../../07-me/notification-journey-inbox-last-page/README.md) | 1 | Load final page → full list, no load-more CTA |
| [图](../../07-me/notification-current-tooltip-archive-notification/default.png) · [入口及前驱](../../07-me/notification-current-tooltip-archive-notification/README.md) | 1 | Long press Archive notification → tooltip, action not invoked |
| [图](../../07-me/notification-current-tooltip-back/default.png) · [入口及前驱](../../07-me/notification-current-tooltip-back/README.md) | 1 | Scroll inbox to top; Long press Back → tooltip, action not invoked |
| [图](../../07-me/notification-journey-mark-all-pending/default.png) · [入口及前驱](../../07-me/notification-journey-mark-all-pending/README.md) | 1 | Mark all read pending → action disabled, unread count preserved |
| [图](../../07-me/notification-followup-tooltip-back/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-back/README.md) | 1 | Long press Back → actual Tooltip overlay |
| [图](../../07-me/notification-followup-tooltip-archive-notification-dismissed/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-archive-notification-dismissed/README.md) | 5 | Tooltip timeout → inbox retained, action not invoked |
| [图](../../07-me/notifications-error/default.png) · [入口及前驱](../../07-me/notifications-error/README.md) | 1 | inbox and retained-content error at 390.0 / 1.0 |
| [图](../../07-me/notification-followup-tooltip-notification-settings/default.png) · [入口及前驱](../../07-me/notification-followup-tooltip-notification-settings/README.md) | 1 | Long press Notification settings → actual Tooltip overlay |
| [图](../../07-me/notification-current-archive-pending-completed/default.png) · [入口及前驱](../../07-me/notification-current-archive-pending-completed/README.md) | 2 | Archive response → row removed and count refreshed |
| [图](../../07-me/notification-current-inbox-first-page/default.png) · [入口及前驱](../../07-me/notification-current-inbox-first-page/README.md) | 1 | Retry → first three updates with unread count and load more |
| [图](../../07-me/notification-followup-settings-inbox/default.png) · [入口及前驱](../../07-me/notification-followup-settings-inbox/README.md) | 4 | More notifications → inbox |
| [图](../../07-me/notifications-inbox/default.png) · [入口及前驱](../../07-me/notifications-inbox/README.md) | 1 | inbox and retained-content error at 390.0 / 1.0 |

## 实际操作链与状态依据

[NOTIFICATION-CURRENT.md](../NOTIFICATION-CURRENT.md) · [NOTIFICATION-NAVIGATION-CURRENT.md](../NOTIFICATION-NAVIGATION-CURRENT.md) · [AGENT-ENTRY-CURRENT.md](../AGENT-ENTRY-CURRENT.md)
