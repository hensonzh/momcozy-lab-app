# 按最终页面清单推进 UI 重构

Session A 盘点已完成。此表使用最终页面 ID；原 progress.json 的条目是交付范围，不能作为独立页面数量。全部有限状态已完成最终对照，复用及无入口边界分别记录。见 [最终验收](20260914-final-audit/README.md)。

| 页面 | 分类 | 当前重构位置 | 已有交付 |
| --- | --- | --- | --- |
| 登录 | default | Figma 与 Flutter 已交付，6 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 注册 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 邮箱验证 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 找回密码 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 重置密码 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 妈妈首页 | default | 已批准妈妈页基准，6 条状态已完成最终对照 | [handoff-20260913](../ui-reference/mom/handoff-20260913/HANDOFF.md)、[20260914-destination-review](20260914-destination-review/REVIEW.md) |
| 今日状态记录页 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-mother-diary](20260914-mother-diary/HANDOFF.md) |
| 泌乳记录与趋势 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-lactation](20260914-lactation/HANDOFF.md) |
| 宝宝首页 | default | Figma 与 Flutter 已交付，6 类页面状态已验证 | [20260914-baby-home](20260914-baby-home/HANDOFF.md) |
| 宝宝记录历史 | default | Figma 与 Flutter 已交付，6 类页面状态及共享编辑器已验证 | [20260914-baby-records](20260914-baby-records/HANDOFF.md) |
| Cozymate 对话 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-agent-actions-results](20260914-agent-actions-results/HANDOFF.md)、[20260914-agent-attachments-menus](20260914-agent-attachments-menus/HANDOFF.md)、[20260914-agent-conversation](20260914-agent-conversation/HANDOFF.md)、[20260914-agent-form-dialogs](20260914-agent-form-dialogs/HANDOFF.md)、[20260914-agent-history](20260914-agent-history/HANDOFF.md)、[20260914-agent-reading-cards](20260914-agent-reading-cards/HANDOFF.md)、[20260914-agent-voice-notices](20260914-agent-voice-notices/HANDOFF.md) |
| 日程 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-schedule](20260914-schedule/HANDOFF.md) |
| More | default | Figma 与 Flutter 已交付，4 条状态已完成最终对照（含明确复用边界） | [20260914-more](20260914-more/HANDOFF.md) |
| 账号设置 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-account](20260914-account/HANDOFF.md) |
| 隐私与授权 | default | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-privacy](20260914-privacy/HANDOFF.md) |
| 通知中心 | default | Figma 与 Flutter 已交付，7 条状态已完成最终对照（含明确复用边界） | [20260914-notifications](20260914-notifications/HANDOFF.md) |
| 通知设置 | default | Figma 与 Flutter 已交付，7 条状态已完成最终对照（含明确复用边界） | [20260914-notifications](20260914-notifications/HANDOFF.md) |
| 专家服务目录 | default | Figma 与 Flutter 已交付，4 条状态已完成最终对照（含明确复用边界） | [20260914-service-catalog](20260914-service-catalog/HANDOFF.md) |
| 服务套餐详情 | default | Figma 与 Flutter 已交付，8 条状态已完成最终对照（含明确复用边界） | [20260914-service-package](20260914-service-package/HANDOFF.md) |
| 服务详情与时间线 | default | Figma 与 Flutter 已交付，7 条状态已完成最终对照（含明确复用边界） | [20260914-service-progress](20260914-service-progress/HANDOFF.md) |
| 续购服务 | default | Figma 与 Flutter 已交付，7 条状态已完成最终对照（含明确复用边界） | [20260914-service-renew](20260914-service-renew/HANDOFF.md) |
| 预约与预约内详情 | default | Figma 与 Flutter 已交付，8 条状态已完成最终对照（含明确复用边界） | [20260914-booking](20260914-booking/HANDOFF.md) |
| 独立预约详情 | default | Figma 与 Flutter 已交付，8 条状态已完成最终对照（含明确复用边界） | [20260914-appointment-detail](20260914-appointment-detail/HANDOFF.md) |
| 咨询信息采集表 | default | Figma 与 Flutter 已交付，9 条状态已完成最终对照（含明确复用边界） | [20260914-intake](20260914-intake/HANDOFF.md) |
| 咨询准备、通话与结束 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-consultation-entry](20260914-consultation-entry/HANDOFF.md)、[20260914-consultation-live-room](20260914-consultation-live-room/HANDOFF.md)、[20260914-consultation-outcomes](20260914-consultation-outcomes/HANDOFF.md)、[20260914-consultation-preflight](20260914-consultation-preflight/HANDOFF.md)、[20260914-consultation-preparation](20260914-consultation-preparation/HANDOFF.md) |
| 咨询总结与后续任务 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-consultation-summary](20260914-consultation-summary/HANDOFF.md) |
| 媒体查看器 | default | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-media-controls](20260914-media-controls/HANDOFF.md)、[20260914-media-viewer](20260914-media-viewer/HANDOFF.md) |
| 视频全屏 | navigator | Figma 与 Flutter 已交付，有限状态已完成最终对照 | [20260914-media-controls](20260914-media-controls/HANDOFF.md) |
| 邀请登录 | configured | Figma 与 Flutter 已交付，4 条状态已完成最终对照（含明确复用边界） | [20260914-auth](20260914-auth/HANDOFF.md) |
| 首次使用资料 | configured | Figma 与 Flutter 已交付，6 条状态已完成最终对照（含明确复用边界） | [20260914-onboarding-avatar](20260914-onboarding-avatar/HANDOFF.md)、[20260914-onboarding-profile](20260914-onboarding-profile/HANDOFF.md) |
| 数字形象创建 | configured | Figma 与 Flutter 已交付，6 条状态已完成最终对照（含明确复用边界） | [20260914-onboarding-avatar](20260914-onboarding-avatar/HANDOFF.md) |
| 数字形象确认 | configured | Figma 与 Flutter 已交付，5 条状态已完成最终对照（含明确复用边界） | [20260914-onboarding-avatar](20260914-onboarding-avatar/HANDOFF.md) |
| 无效路由提示 | fallback | Figma 与 Flutter 已交付，返回及认证守卫已验证 | [20260914-special-pages](20260914-special-pages/HANDOFF.md) |
| 动作评估 | unreachable | 已有预览／失败画面已交付；维持无正常入口边界 | [20260914-special-pages](20260914-special-pages/HANDOFF.md) |

完整有限状态列表见 [页面状态](canonical-page-progress.json) 与 [浮层状态](canonical-overlay-progress.json)。此表建立证据关联，不把关联本身当作验收通过。
