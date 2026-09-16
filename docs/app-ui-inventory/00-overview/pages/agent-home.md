# Cozymate 对话

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`agent-home`
- 范围：default
- 入口：Cozymate Tab
- 路由：/
- 实现：[agent_hub_page.dart](../../../../lib/features/agent_hub/agent_hub_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 初始
- 对话
- 生成中
- 结构化卡片
- 输入及附件
- 语音
- 失败与重试
- 会话恢复

## 归属弹窗／浮层

agent-history、agent-menu、agent-form、agent-image

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 初始 | [agent-home](../../05-agent/agent-home/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 对话 | [agent-journey-reply](../../05-agent/agent-journey-reply/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 生成中 | [agent-journey-streaming](../../05-agent/agent-journey-streaming/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 结构化卡片 | [agent-cards](../../05-agent/agent-cards/README.md) · [agent-cards-ready](../../05-agent/agent-cards-ready/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 输入及附件 | [agent-journey-draft](../../05-agent/agent-journey-draft/README.md) · [agent-journey-attachment-menu](../../05-agent/agent-journey-attachment-menu/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 语音 | [agent-voice-off](../../05-agent/agent-voice-off/README.md) · [agent-voice-on](../../05-agent/agent-voice-on/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 失败与重试 | [agent-journey-terminal-error](../../05-agent/agent-journey-terminal-error/README.md) · [agent-journey-manual-retry](../../05-agent/agent-journey-manual-retry/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 会话恢复 | [agent-journey-resumed](../../05-agent/agent-journey-resumed/README.md) · [agent-history-list](../../05-agent/agent-history-list/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../05-agent/agent-attachment-journey-image-upload-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-upload-failed/README.md) | 1 | Image upload HTTP 503 → no attachment and retry feedback |
| [图](../../05-agent/agent-form-short-keyboard/default.png) · [入口及前驱](../../05-agent/agent-form-short-keyboard/README.md) | 1 | short screen keyboard leaves form content and actions reachable |
| [图](../../05-agent/agent-attachment-journey-camera-pick-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-camera-pick-failed/README.md) | 1 | Camera picker reports failure → image upload failure snackbar |
| [图](../../05-agent/agent-voice-journey-greeting-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-greeting-failed/README.md) | 1 | Greeting player fails → safe notice and replay |
| [图](../../05-agent/agent-journey-sent-waiting/default.png) · [入口及前驱](../../05-agent/agent-journey-sent-waiting/README.md) | 1 | Send message → waiting for first SSE event |
| [图](../../05-agent/agent-attachment-journey-image-zoomed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-zoomed/README.md) | 1 | Two-finger pinch → enlarged image |
| [图](../../05-agent/agent-image-loading/default.png) · [入口及前驱](../../05-agent/agent-image-loading/README.md) | 2 | image metadata, empty response, retry and zoom 390.0/1.0 |
| [图](../../05-agent/agent-menu-user/default.png) · [入口及前驱](../../05-agent/agent-menu-user/README.md) | 1 | message menu 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-ticket-auto-open/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-auto-open/README.md) | 1 | Production one-second presentation timer → form dialog |
| [图](../../05-agent/agent-journey-disconnected-empty/default.png) · [入口及前驱](../../05-agent/agent-journey-disconnected-empty/README.md) | 1 | Connection fails through three automatic retries → retry UI |
| [图](../../05-agent/agent-attachment-journey-mixed-ready-image/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-mixed-ready-image/README.md) | 1 | Camera result and PDF selected → both uploaded in composer |
| [图](../../05-agent/agent-resource-journey-renew-card/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-renew-card/README.md) | 2 | More → Cozymate → send request → real SSE artifact presents 继续查看支持方案 |
| [图](../../05-agent/agent-journey-terminal-error/default.png) · [入口及前驱](../../05-agent/agent-journey-terminal-error/README.md) | 1 | Terminal run failure → safe feedback and editable input |
| [图](../../05-agent/agent-journey-long-followup-sent/default.png) · [入口及前驱](../../05-agent/agent-journey-long-followup-sent/README.md) | 1 | Type and send a follow-up → second message in the same conversation |
| [图](../../05-agent/agent-attachment-journey-image-remote-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remote-failed/README.md) | 2 | Reload original via authenticated content repository → HTTP error |
| [图](../../05-agent/agent-voice-journey-reply-stream-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-stream-failed/README.md) | 1 | Player fails during reply → replay disabled until run ends |
| [图](../../05-agent/agent-journey-voice-off/default.png) · [入口及前驱](../../05-agent/agent-journey-voice-off/README.md) | 1 | Toggle automatic voice off |
| [图](../../05-agent/agent-workflow-journey-milk-request/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-milk-request/README.md) | 1 | Tap milk analysis shortcut → preset question sent |
| [图](../../05-agent/agent-form-failed/default.png) · [入口及前驱](../../05-agent/agent-form-failed/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-greeting-playing/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-greeting-playing/README.md) | 2 | More → Cozymate automatically starts greeting playback |
| [图](../../05-agent/agent-history-load-error/default.png) · [入口及前驱](../../05-agent/agent-history-load-error/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-journey-partial-menu/default.png) · [入口及前驱](../../05-agent/agent-journey-partial-menu/README.md) | 1 | Long press disconnected answer → copy and retry menu |
| [图](../../05-agent/agent-journey-menu-dismissed/default.png) · [入口及前驱](../../05-agent/agent-journey-menu-dismissed/README.md) | 1 | Tap outside message menu → same conversation |
| [图](../../05-agent/agent-journey-user-menu/default.png) · [入口及前驱](../../05-agent/agent-journey-user-menu/README.md) | 1 | Long press submitted user message → copy menu |
| [图](../../05-agent/agent-journey-cancel-finished/default.png) · [入口及前驱](../../05-agent/agent-journey-cancel-finished/README.md) | 1 | Cancellation status 200 → local result |
| [图](../../05-agent/agent-resource-actions/default.png) · [入口及前驱](../../05-agent/agent-resource-actions/README.md) | 2 | resource card reading and original actions 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-reject-failure-pending/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-reject-failure-pending/README.md) | 2 | Tap action reject → HTTP pending |
| [图](../../05-agent/agent-workflow-journey-confirm-failure-pending/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-confirm-failure-pending/README.md) | 2 | Tap action confirm → HTTP pending |
| [图](../../05-agent/agent-workflow-journey-intake-date-selected/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-date-selected/README.md) | 1 | Select day 20 in September 2026 |
| [图](../../05-agent/native-resource-card/default.png) · [入口及前驱](../../05-agent/native-resource-card/README.md) | 5 | Actual native Agent reply with four Chinese action labels |
| [图](../../08-expert-service/service-journey-intake-to-cozymate/default.png) · [入口及前驱](../../08-expert-service/service-journey-intake-to-cozymate/README.md) | 1 | Preconsult CTA → actual Cozymate route with context draft |
| [图](../../05-agent/agent-attachment-journey-image-remote-recovered/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remote-recovered/README.md) | 2 | Valid remote original received → image available |
| [图](../../05-agent/agent-home/default.png) · [入口及前驱](../../05-agent/agent-home/README.md) | 1 | Agent home and keyboard at 390.0 / 1.0 |
| [图](../../05-agent/agent-voice-journey-reply-replaying/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-replaying/README.md) | 1 | Tap replay → read completed reply without regenerating |
| [图](../../05-agent/agent-attachment-notice-too-large/default.png) · [入口及前驱](../../05-agent/agent-attachment-notice-too-large/README.md) | 1 | attachment too-large preserves draft 390.0/1.0 |
| [图](../../05-agent/agent-journey-cancel-pending/default.png) · [入口及前驱](../../05-agent/agent-journey-cancel-pending/README.md) | 2 | Stop response → cancellation HTTP pending |
| [图](../../05-agent/agent-attachment-pending-image/default.png) · [入口及前驱](../../05-agent/agent-attachment-pending-image/README.md) | 1 | attachment layout and draft actions 390.0/1.0 |
| [图](../../05-agent/agent-journey-profile-fallback/default.png) · [入口及前驱](../../05-agent/agent-journey-profile-fallback/README.md) | 1 | Profile request fails → usable generic greeting and composer |
| [图](../../05-agent/agent-workflow-journey-intake-readonly/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-readonly/README.md) | 1 | Open submitted form → read-only values |
| [图](../../05-agent/agent-voice-greeting-playing/default.png) · [入口及前驱](../../05-agent/agent-voice-greeting-playing/README.md) | 2 | greeting playback and replay indicator 390.0/1.0 |
| [图](../../05-agent/agent-attachment-uploading/default.png) · [入口及前驱](../../05-agent/agent-attachment-uploading/README.md) | 1 | attachment layout and draft actions 390.0/1.0 |
| [图](../../05-agent/agent-menu-retry/default.png) · [入口及前驱](../../05-agent/agent-menu-retry/README.md) | 1 | message menu 390.0/1.0 |
| [图](../../05-agent/agent-result-unsupported/default.png) · [入口及前驱](../../05-agent/agent-result-unsupported/README.md) | 1 | result cards 390.0/1.0 |
| [图](../../05-agent/agent-voice-stream-error/default.png) · [入口及前驱](../../05-agent/agent-voice-stream-error/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-ticket-failed/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-failed/README.md) | 1 | HTTP 503 → error with form draft retained |
| [图](../../05-agent/agent-workflow-journey-retry-intake-completed/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-retry-intake-completed/README.md) | 1 | Retried response completes |
| [图](../../05-agent/agent-history-empty/default.png) · [入口及前驱](../../05-agent/agent-history-empty/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-mixed-ready-file/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-mixed-ready-file/README.md) | 1 | Scroll attachment strip → PDF and removal control visible |
| [图](../../05-agent/agent-entry-journey-forward_head-card/default.png) · [入口及前驱](../../05-agent/agent-entry-journey-forward_head-card/README.md) | 3 | Supported motion artifact arrives → normal card with start CTA |
| [图](../../05-agent/agent-result-disabled/default.png) · [入口及前驱](../../05-agent/agent-result-disabled/README.md) | 1 | result cards 390.0/1.0 |
| [图](../../05-agent/agent-chat/default.png) · [入口及前驱](../../05-agent/agent-chat/README.md) | 1 | Agent transcript at 390.0 |
| [图](../../05-agent/agent-attachment-pending-file/default.png) · [入口及前驱](../../05-agent/agent-attachment-pending-file/README.md) | 1 | attachment layout and draft actions 390.0/1.0 |
| [图](../../05-agent/agent-journey-stop-before-run-id/default.png) · [入口及前驱](../../05-agent/agent-journey-stop-before-run-id/README.md) | 1 | Stop before server run identifier → local stop |
| [图](../../05-agent/agent-voice-greeting-error/default.png) · [入口及前驱](../../05-agent/agent-voice-greeting-error/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-history-switching/default.png) · [入口及前驱](../../05-agent/agent-history-switching/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-ticket-return/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-return/README.md) | 2 | Close ticket detail → retained conversation |
| [图](../../05-agent/agent-attachment-journey-new-cleanup-notice-dismissed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-new-cleanup-notice-dismissed/README.md) | 1 | Swipe failure snackbar away → attachment controls visible again |
| [图](../../05-agent/agent-journey-long-reply/default.png) · [入口及前驱](../../05-agent/agent-journey-long-reply/README.md) | 1 | Receive long Markdown and quick-reply payload; current page omits quick-reply controls |
| [图](../../05-agent/agent-voice-journey-later-text-full-finished/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-later-text-full-finished/README.md) | 1 | Replayed audio completes successfully |
| [图](../../05-agent/agent-voice-journey-later-text-full-replay/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-later-text-full-replay/README.md) | 1 | Tap replay → both paragraphs submitted to playback |
| [图](../../05-agent/agent-attachment-journey-file-pick-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-file-pick-failed/README.md) | 1 | Document picker reports failure → file upload failure snackbar |
| [图](../../05-agent/agent-workflow-journey-confirm-success-result/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-confirm-success-result/README.md) | 2 | HTTP 200 → authoritative applied state |
| [图](../../05-agent/agent-workflow-journey-intake-auto-open/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-auto-open/README.md) | 2 | Production one-second presentation timer → form dialog |
| [图](../../05-agent/agent-journey-copy-failed/default.png) · [入口及前驱](../../05-agent/agent-journey-copy-failed/README.md) | 1 | Copy with unavailable platform clipboard → failure snackbar |
| [图](../../05-agent/agent-conversation-disconnected-partial/default.png) · [入口及前驱](../../05-agent/agent-conversation-disconnected-partial/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-pdf-oversized/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-pdf-oversized/README.md) | 1 | Real document picker validates oversized selected bytes before upload |
| [图](../../10-global-modals/notification-conversation/default.png) · [入口及前驱](../../10-global-modals/notification-conversation/README.md) | 1 | Notification list → Service update 1 → target history loads → message menu → system Back dismisses menu |
| [图](../../05-agent/agent-workflow-journey-intake-request/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-request/README.md) | 2 | Tap recovery assessment shortcut → actual preset request sent |
| [图](../../05-agent/agent-form-validation/default.png) · [入口及前驱](../../05-agent/agent-form-validation/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-image-remote-loading/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remote-loading/README.md) | 1 | Retry original image → loading indicator |
| [图](../../05-agent/agent-voice-journey-later-text-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-later-text-failed/README.md) | 1 | Realtime player fails after first paragraph |
| [图](../../05-agent/agent-attachment-journey-pdf-unsupported/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-pdf-unsupported/README.md) | 1 | Real document picker validates unsupported selected bytes before upload |
| [图](../../05-agent/agent-attachment-journey-pdf-only-completed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-pdf-only-completed/README.md) | 1 | Send without text → default file prompt and final reply |
| [图](../../03-mom/mom-journey-ai-context-draft/default.png) · [入口及前驱](../../03-mom/mom-journey-ai-context-draft/README.md) | 1 | Home AI card → Cozymate with prefilled prompt, not sent |
| [图](../../05-agent/agent-attachment-journey-image-removed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-removed/README.md) | 1 | Remove again → same idempotency key, image deleted, text draft preserved |
| [图](../../05-agent/agent-cards-ready/default.png) · [入口及前驱](../../05-agent/agent-cards-ready/README.md) | 1 | Agent cards and dialog at 390.0 / 1.0 |
| [图](../../05-agent/agent-attachment-journey-image-ready/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-ready/README.md) | 3 | Upload succeeds → removable local image preview |
| [图](../../05-agent/agent-workflow-journey-intake-submitting/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-submitting/README.md) | 1 | Submit → synthetic SSE request awaits server run signal |
| [图](../../05-agent/agent-attachment-journey-pdf-upload-recovered/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-pdf-upload-recovered/README.md) | 1 | Select PDF again → successful upload |
| [图](../../05-agent/agent-conversation-streaming/default.png) · [入口及前驱](../../05-agent/agent-conversation-streaming/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-intake-accepted/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-accepted/README.md) | 1 | Server run starts → dialog closes and submitted entry retained |
| [图](../../05-agent/agent-workflow-journey-confirm-failure-preview/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-confirm-failure-preview/README.md) | 4 | Receive authoritative action preview → controls available |
| [图](../../05-agent/agent-voice-on/default.png) · [入口及前驱](../../05-agent/agent-voice-on/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-reply-audio-completed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-audio-completed/README.md) | 1 | Original audio session completes after tab return → speaking indicator stops |
| [图](../../05-agent/agent-attachment-journey-image-viewer-return/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-viewer-return/README.md) | 3 | Viewer return button → same conversation |
| [图](../../05-agent/agent-attachment-notice-image-error/default.png) · [入口及前驱](../../05-agent/agent-attachment-notice-image-error/README.md) | 1 | attachment image-error preserves draft 390.0/1.0 |
| [图](../../05-agent/agent-attachment-menu/default.png) · [入口及前驱](../../05-agent/agent-attachment-menu/README.md) | 1 | attachment layout and draft actions 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-later-text-terminal-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-later-text-terminal-failed/README.md) | 1 | Playback fails after reply finishes → replay entire reply is available |
| [图](../../05-agent/agent-form-entry/default.png) · [入口及前驱](../../05-agent/agent-form-entry/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-image-remove-pending/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remove-pending/README.md) | 1 | Remove image → deletion pending and input locked |
| [图](../../05-agent/agent-conversation-reply/default.png) · [入口及前驱](../../05-agent/agent-conversation-reply/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-intake-draft-return/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-draft-return/README.md) | 1 | Reopen form → draft values retained |
| [图](../../05-agent/agent-journey-cancel-unconfirmed-finished/default.png) · [入口及前驱](../../05-agent/agent-journey-cancel-unconfirmed-finished/README.md) | 1 | Cancellation status 503 → local result |
| [图](../../05-agent/agent-journey-disconnected-partial/default.png) · [入口及前驱](../../05-agent/agent-journey-disconnected-partial/README.md) | 1 | Retry exhaustion after delta → partial answer and next draft retained |
| [图](../../05-agent/agent-journey-draft-reset/default.png) · [入口及前驱](../../05-agent/agent-journey-draft-reset/README.md) | 1 | New conversation → unsent draft cleared without prompt |
| [图](../../05-agent/agent-conversation-resumed/default.png) · [入口及前驱](../../05-agent/agent-conversation-resumed/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-voice-dismissed/default.png) · [入口及前驱](../../05-agent/agent-voice-dismissed/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-image-empty-response/default.png) · [入口及前驱](../../05-agent/agent-image-empty-response/README.md) | 1 | image metadata, empty response, retry and zoom 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-retry-intake-pending/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-retry-intake-pending/README.md) | 1 | Retry form → same data and idempotency key |
| [图](../../05-agent/agent-workflow-journey-intake-validation/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-validation/README.md) | 1 | Submit empty required notes → inline validation |
| [图](../../05-agent/agent-result-summary/default.png) · [入口及前驱](../../05-agent/agent-result-summary/README.md) | 1 | result cards 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-ticket-retrying/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-retrying/README.md) | 2 | Retry same ticket body and idempotency key |
| [图](../../05-agent/agent-attachment-journey-image-remove-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remove-failed/README.md) | 1 | Deletion fails → image and draft retained with snackbar |
| [图](../../05-agent/agent-voice-journey-reply-ended-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-ended-failed/README.md) | 1 | SSE reply completes → replay becomes available |
| [图](../../05-agent/agent-workflow-journey-intake-readonly-return/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-readonly-return/README.md) | 2 | Close read-only form → same conversation |
| [图](../../05-agent/agent-voice-journey-reply-waiting/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-waiting/README.md) | 1 | Send typed message → waiting for first reply |
| [图](../../05-agent/agent-voice-journey-later-text-recovered/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-later-text-recovered/README.md) | 1 | Next SSE delta automatically starts a new player with only the new suffix |
| [图](../../05-agent/agent-journey-draft/default.png) · [入口及前驱](../../05-agent/agent-journey-draft/README.md) | 1 | Enter unsent composer draft |
| [图](../../05-agent/agent-history-journey-target-error/default.png) · [入口及前驱](../../05-agent/agent-history-journey-target-error/README.md) | 2 | Open notification → default target route throws ArgumentError for string Expando key before history HTTP |
| [图](../../05-agent/agent-attachment-journey-camera-pick-pending/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-camera-pick-pending/README.md) | 3 | Open camera picker boundary → input locked while result pending; not an OS screenshot |
| [图](../../05-agent/agent-journey-reply/default.png) · [入口及前驱](../../05-agent/agent-journey-reply/README.md) | 2 | SSE completion → final Markdown response |
| [图](../../05-agent/agent-markdown-link/default.png) · [入口及前驱](../../05-agent/agent-markdown-link/README.md) | 2 | markdown reading 390.0/1.0 |
| [图](../../05-agent/agent-result-motion/default.png) · [入口及前驱](../../05-agent/agent-result-motion/README.md) | 1 | result cards 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-intake-dropdown/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-dropdown/README.md) | 1 | Open follow-up dropdown |
| [图](../../05-agent/agent-workflow-journey-ticket-auto-loading/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-auto-loading/README.md) | 1 | Assistant completes → live form entry waiting to auto-open |
| [图](../../05-agent/agent-conversation-terminal-error/default.png) · [入口及前驱](../../05-agent/agent-conversation-terminal-error/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-image-unavailable/default.png) · [入口及前驱](../../05-agent/agent-image-unavailable/README.md) | 1 | image metadata, empty response, retry and zoom 390.0/1.0 |
| [图](../../05-agent/agent-attachment-notice-cleanup-error/default.png) · [入口及前驱](../../05-agent/agent-attachment-notice-cleanup-error/README.md) | 1 | attachment cleanup-error preserves draft 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-new-cleanup-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-new-cleanup-failed/README.md) | 1 | New conversation → server cleanup failure retains PDF and draft |
| [图](../../05-agent/agent-voice-off/default.png) · [入口及前驱](../../05-agent/agent-voice-off/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-journey-menu-system-back-failed/default.png) · [入口及前驱](../../05-agent/agent-journey-menu-system-back-failed/README.md) | 1 | System back → GoRouter null NavigatorState error; message menu remains |
| [图](../../05-agent/agent-attachment-notice-unsupported/default.png) · [入口及前驱](../../05-agent/agent-attachment-notice-unsupported/README.md) | 1 | attachment unsupported preserves draft 390.0/1.0 |
| [图](../../05-agent/agent-history-list/default.png) · [入口及前驱](../../05-agent/agent-history-list/README.md) | 2 | history states 390.0/1.0 |
| [图](../../05-agent/agent-resource-journey-image-card/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-card/README.md) | 6 | More → Cozymate → send request → real SSE artifact presents 查看示意图片 |
| [图](../../05-agent/agent-voice-journey-new-greeting-off/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-new-greeting-off/README.md) | 2 | Turn voice off during fresh greeting → stop |
| [图](../../05-agent/agent-form-submitted-entry/default.png) · [入口及前驱](../../05-agent/agent-form-submitted-entry/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-reduced-motion-thinking/default.png) · [入口及前驱](../../05-agent/agent-reduced-motion-thinking/README.md) | 1 | reduced motion keeps reply and status changes readable |
| [图](../../05-agent/agent-attachment-journey-image-panned/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-panned/README.md) | 1 | Drag enlarged image → panned view |
| [图](../../05-agent/agent-entry-journey-external-failed/default.png) · [入口及前驱](../../05-agent/agent-entry-journey-external-failed/README.md) | 2 | Launcher returns false → real Snackbar |
| [图](../../05-agent/agent-menu-assistant/default.png) · [入口及前驱](../../05-agent/agent-menu-assistant/README.md) | 1 | message menu 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-retry-intake-accepted/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-retry-intake-accepted/README.md) | 1 | Retried run accepted → form closes |
| [图](../../05-agent/agent-image-zoomed/default.png) · [入口及前驱](../../05-agent/agent-image-zoomed/README.md) | 1 | image metadata, empty response, retry and zoom 390.0/1.0 |
| [图](../../05-agent/agent-journey-assistant-copied/default.png) · [入口及前驱](../../05-agent/agent-journey-assistant-copied/README.md) | 2 | Copy answer → raw Markdown retained in clipboard |
| [图](../../05-agent/agent-voice-journey-reply-stream-playing/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-stream-playing/README.md) | 1 | First SSE delta → realtime voice session and speaking avatar |
| [图](../../05-agent/agent-journey-manual-retry/default.png) · [入口及前驱](../../05-agent/agent-journey-manual-retry/README.md) | 1 | Manual retry → same idempotency key |
| [图](../../05-agent/agent-voice-keyboard/default.png) · [入口及前驱](../../05-agent/agent-voice-keyboard/README.md) | 1 | voice error remains usable above a keyboard at 2x |
| [图](../../05-agent/agent-voice-reply-error/default.png) · [入口及前驱](../../05-agent/agent-voice-reply-error/README.md) | 1 | voice states 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-keyboard-dismissed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-keyboard-dismissed/README.md) | 1 | Dismiss voice notice → draft remains and composer expands |
| [图](../../05-agent/agent-history-locked/default.png) · [入口及前驱](../../05-agent/agent-history-locked/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-ticket-request/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-request/README.md) | 1 | Type and send a support request |
| [图](../../05-agent/agent-workflow-journey-intake-auto-loading/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-auto-loading/README.md) | 2 | Assistant completes → live form entry waiting to auto-open |
| [图](../../05-agent/agent-form-submitted-detail/default.png) · [入口及前驱](../../05-agent/agent-form-submitted-detail/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-entry-journey-external-accepted/default.png) · [入口及前驱](../../05-agent/agent-entry-journey-external-accepted/README.md) | 4 | Tap again, launcher accepts → App remains on card; browser outside fixture scope |
| [图](../../05-agent/agent-voice-journey-active-audio-return/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-active-audio-return/README.md) | 1 | Tap Cozymate → restored conversation |
| [图](../../05-agent/agent-journey-streaming/default.png) · [入口及前驱](../../05-agent/agent-journey-streaming/README.md) | 1 | Receive SSE delta → live response |
| [图](../../05-agent/agent-conversation-disconnected-empty/default.png) · [入口及前驱](../../05-agent/agent-conversation-disconnected-empty/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-resource-journey-pdf-card/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-pdf-card/README.md) | 2 | More → Cozymate → send request → real SSE artifact presents 阅读资料 PDF |
| [图](../../05-agent/agent-form/default.png) · [入口及前驱](../../05-agent/agent-form/README.md) | 1 | Agent cards and dialog at 390.0 / 1.0 |
| [图](../../05-agent/agent-attachment-journey-new-cleanup-pending/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-new-cleanup-pending/README.md) | 1 | Retry new conversation → deletion pending and controls disabled |
| [图](../../05-agent/agent-history/default.png) · [入口及前驱](../../05-agent/agent-history/README.md) | 1 | conversation drawer long titles at 390.0 |
| [图](../../05-agent/agent-journey-assistant-menu/default.png) · [入口及前驱](../../05-agent/agent-journey-assistant-menu/README.md) | 1 | Long press final answer → message menu |
| [图](../../05-agent/agent-voice-journey-new-greeting-playing/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-new-greeting-playing/README.md) | 1 | New conversation clears draft and starts fresh greeting |
| [图](../../05-agent/agent-workflow-journey-confirm-failure-result/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-confirm-failure-result/README.md) | 4 | HTTP 503 → failed action; confirm/reject controls disappear, no retry entry |
| [图](../../05-agent/agent-journey-long-followup-completed/default.png) · [入口及前驱](../../05-agent/agent-journey-long-followup-completed/README.md) | 1 | Second response completes → two exchanges retained |
| [图](../../05-agent/agent-journey-new-tooltip/default.png) · [入口及前驱](../../05-agent/agent-journey-new-tooltip/README.md) | 1 | Long press new conversation → tooltip |
| [图](../../05-agent/agent-attachment-notice-file-error/default.png) · [入口及前驱](../../05-agent/agent-attachment-notice-file-error/README.md) | 1 | attachment file-error preserves draft 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-diary-return/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-diary-return/README.md) | 5 | Cozymate tab → original conversation retained |
| [图](../../05-agent/agent-result-consent-accepted/default.png) · [入口及前驱](../../05-agent/agent-result-consent-accepted/README.md) | 1 | result cards 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-pdf-upload-failed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-pdf-upload-failed/README.md) | 1 | Valid PDF upload HTTP 503 → feedback and no pending file |
| [图](../../05-agent/agent-entry-journey-posture_screen-card/default.png) · [入口及前驱](../../05-agent/agent-entry-journey-posture_screen-card/README.md) | 3 | Supported motion artifact arrives → normal card with start CTA |
| [图](../../05-agent/agent-form-choices/default.png) · [入口及前驱](../../05-agent/agent-form-choices/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-journey-after-early-stop/default.png) · [入口及前驱](../../05-agent/agent-journey-after-early-stop/README.md) | 1 | Send again after early stop → completed response |
| [图](../../05-agent/agent-workflow-journey-reject-success-result/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-reject-success-result/README.md) | 2 | HTTP 200 → authoritative rejected state |
| [图](../../05-agent/agent-attachment-journey-camera-failure-dismissed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-camera-failure-dismissed/README.md) | 4 | Swipe failure snackbar away → attachment controls visible again |
| [图](../../05-agent/agent-voice-journey-reply-off/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-off/README.md) | 1 | Turn voice off → active session cancelled |
| [图](../../05-agent/agent-journey-copy-recovered/default.png) · [入口及前驱](../../05-agent/agent-journey-copy-recovered/README.md) | 1 | Reopen message menu and copy → success snackbar |
| [图](../../05-agent/agent-history-switch-error/default.png) · [入口及前驱](../../05-agent/agent-history-switch-error/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-image-upload-failure-dismissed/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-upload-failure-dismissed/README.md) | 15 | Swipe failure snackbar away → attachment controls visible again |
| [图](../../05-agent/agent-attachment-journey-image-uploading/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-uploading/README.md) | 1 | Photo result → multipart upload at 50%, composer locked |
| [图](../../05-agent/agent-journey-attachment-menu/default.png) · [入口及前驱](../../05-agent/agent-journey-attachment-menu/README.md) | 1 | Composer add → supported attachment sources |
| [图](../../05-agent/agent-workflow-journey-retry-intake-failed/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-retry-intake-failed/README.md) | 1 | Three SSE retries exhausted before acceptance → editable form failure |
| [图](../../05-agent/agent-workflow-journey-ticket-readonly/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-ticket-readonly/README.md) | 1 | Open submitted ticket form → read-only |
| [图](../../05-agent/agent-attachment-journey-image-remote-return/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-remote-return/README.md) | 1 | Return after remote recovery → original transcript |
| [图](../../05-agent/agent-workflow-journey-intake-date-picker/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-date-picker/README.md) | 1 | Open form date picker |
| [图](../../05-agent/agent-conversation-home/default.png) · [入口及前驱](../../05-agent/agent-conversation-home/README.md) | 1 | conversation recovery 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-reply-on/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-reply-on/README.md) | 2 | Turn voice back on → no automatic restart of completed reply |
| [图](../../05-agent/agent-form-top/default.png) · [入口及前驱](../../05-agent/agent-form-top/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-intake-filled/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-filled/README.md) | 1 | Enter notes, radio, dropdown, date and other concern |
| [图](../../05-agent/agent-attachment-journey-image-decode-fallback/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-image-decode-fallback/README.md) | 1 | Uploaded image cannot decode locally → fallback thumbnail |
| [图](../../05-agent/agent-voice-journey-keyboard-failed/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-keyboard-failed/README.md) | 1 | Focus input with unsent draft → 300dp keyboard inset and voice notice |
| [图](../../05-agent/agent-cards/default.png) · [入口及前驱](../../05-agent/agent-cards/README.md) | 1 | Agent cards and dialog at 390.0 / 1.0 |
| [图](../../04-baby/baby-profile-controls-knowledge-agent-prefill/default.png) · [入口及前驱](../../04-baby/baby-profile-controls-knowledge-agent-prefill/README.md) | 1 | Ask Cozymate → normal Agent route with article title prefilled, not sent |
| [图](../../05-agent/agent-image-loaded/default.png) · [入口及前驱](../../05-agent/agent-image-loaded/README.md) | 1 | image metadata, empty response, retry and zoom 390.0/1.0 |
| [图](../../05-agent/agent-voice-journey-completed-text-playing/default.png) · [入口及前驱](../../05-agent/agent-voice-journey-completed-text-playing/README.md) | 1 | Reply text completes while audio remains active |
| [图](../../05-agent/agent-form-pending/default.png) · [入口及前驱](../../05-agent/agent-form-pending/README.md) | 1 | form states 390.0/1.0 |
| [图](../../05-agent/agent-attachment-journey-mixed-sent/default.png) · [入口及前驱](../../05-agent/agent-attachment-journey-mixed-sent/README.md) | 1 | Send text and two uploaded file IDs → waiting response |
| [图](../../05-agent/agent-history-loading/default.png) · [入口及前驱](../../05-agent/agent-history-loading/README.md) | 1 | history states 390.0/1.0 |
| [图](../../05-agent/agent-workflow-journey-intake-cancelled/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-intake-cancelled/README.md) | 1 | Cancel form → entry remains in conversation |
| [图](../../05-agent/agent-journey-resumed/default.png) · [入口及前驱](../../05-agent/agent-journey-resumed/README.md) | 1 | Retry from message menu → resume cursor and final answer |
| [图](../../10-global-modals/reduced-history/default.png) · [入口及前驱](../../10-global-modals/reduced-history/README.md) | 1 | reduced motion flows 390.0 / 1.0 |
| [图](../../05-agent/agent-attachment-sent-files/default.png) · [入口及前驱](../../05-agent/agent-attachment-sent-files/README.md) | 1 | attachment layout and draft actions 390.0/1.0 |
| [图](../../05-agent/agent-result-consult/default.png) · [入口及前驱](../../05-agent/agent-result-consult/README.md) | 1 | result cards 390.0/1.0 |

## 实际操作链与状态依据

[AGENT-CURRENT-REUSE.md](../AGENT-CURRENT-REUSE.md) · [AGENT-JOURNEYS.md](../AGENT-JOURNEYS.md) · [AGENT-RESOURCE-JOURNEYS.md](../AGENT-RESOURCE-JOURNEYS.md) · [AGENT-ENTRY-CURRENT.md](../AGENT-ENTRY-CURRENT.md)

[G11 当前版本复用](../AGENT-CURRENT-REUSE.md)：Markdown 原金图已严格通过，行动与表单引用已有当前交付，历史抽屉及普通入口保留 G08 条件；最终全状态映射待验收。

## 有限收尾队列进度

- G08：已完成：当前指定会话成功入口及历史抽屉条件已核对。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-agent-actions-results](../../../ui-refactor/20260914-agent-actions-results/HANDOFF.md)：96 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
- [20260914-agent-attachments-menus](../../../ui-refactor/20260914-agent-attachments-menus/HANDOFF.md)：58 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
- [20260914-agent-conversation](../../../ui-refactor/20260914-agent-conversation/HANDOFF.md)：48 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
- [20260914-agent-form-dialogs](../../../ui-refactor/20260914-agent-form-dialogs/HANDOFF.md)：72 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
- [20260914-agent-history](../../../ui-refactor/20260914-agent-history/HANDOFF.md)：48 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
- [20260914-agent-reading-cards](../../../ui-refactor/20260914-agent-reading-cards/HANDOFF.md)：36 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
- [20260914-agent-voice-notices](../../../ui-refactor/20260914-agent-voice-notices/HANDOFF.md)：51 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
