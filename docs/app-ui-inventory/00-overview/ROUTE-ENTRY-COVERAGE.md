# 默认构建路由入口证据复核

最新复核：已运行当前路由导出，默认与开启首次使用两份路由表均与原导出完全一致。沿用原路径的真实操作证据；指定会话入口见 AGENT-ENTRY-CURRENT.md。[导出日志](runs/20260914-overlay-final/routes.log)。

当前默认导出的 24 条路由中，24 条已有至少一个正式 App 操作链观察点，共 2289 个状态。这些是路由入口证明，不是页面数量或完整交互覆盖率。动态参数按具体路由优先匹配，查询参数归入路径；条件分支仍需单列。

[逐条证据及源 SHA-256](route-entry-coverage.json)。本轮重新核验三个路由定义 Dart 文件 SHA 与原运行导出时一致，复用该导出并刷新当前 manifest 的匹配结果；没有把直接组件挂载或 route 注入媒体截图升级为正常来源证明。

| 注册路径 | 实际观察状态数 | 示例 |
| --- | ---: | --- |
| `/services/appointments/:appointmentId/intake` | 28 | [状态证据](../06-schedule/schedule-journey-appointment-expired-intake/README.md) |
| `/services/appointments/:appointmentId/room` | 51 | [状态证据](../06-schedule/schedule-journey-appointment-cancelled-route/README.md) |
| `/services/appointments/:appointmentId/summary` | 14 | [状态证据](../06-schedule/schedule-journey-consultation-summary-route/README.md) |
| `/services/episodes/:episodeId/booking` | 147 | [状态证据](../03-mom/mom-journey-purchased-booking-cancel-precheck/README.md) |
| `/services/episodes/:episodeId/renew` | 20 | [状态证据](../08-expert-service/renew-journey-active-return/README.md) |
| `/babies/:babyId/records` | 112 | [状态证据](../04-baby/baby-journey-delete-cancelled/README.md) |
| `/services/appointments/:appointmentId` | 3 | [状态证据](../07-me/notification-journey-notification-to-appointment/README.md) |
| `/services/episodes/:episodeId` | 40 | [状态证据](../03-mom/mom-journey-purchased-progress/README.md) |
| `/me/diary` | 5 | [状态证据](../03-mom/mom-journey-diary-detail-body/README.md) |
| `/me/lactation` | 35 | [状态证据](../03-mom/mom-journey-milk-conflict/README.md) |
| `/notifications/settings` | 99 | [状态证据](../07-me/notification-followup-settings-ready/README.md) |
| `/services/renew` | 4 | [状态证据](../05-agent/agent-resource-journey-renew-closed/README.md) |
| `/services/:packageId` | 160 | [状态证据](../07-me/notification-followup-booking-package/README.md) |
| `/` | 197 | [状态证据](../03-mom/mom-journey-ai-context-draft/README.md) |
| `/account` | 36 | [状态证据](../07-me/account-journey-delete-cancelled/README.md) |
| `/baby` | 406 | [状态证据](../04-baby/baby-journey-development-editor/README.md) |
| `/login` | 57 | [状态证据](../01-auth/auth-followup-forgot-back-entry/README.md) |
| `/me` | 453 | [状态证据](../03-mom/mom-journey-body-discomfort-expanded/README.md) |
| `/media-viewer` | 33 | [状态证据](../05-agent/agent-resource-journey-image-cached/README.md) |
| `/more` | 116 | [状态证据](../01-auth/auth-followup-reset-login-more/README.md) |
| `/notifications` | 104 | [状态证据](../05-agent/agent-history-journey-external-target/README.md) |
| `/privacy` | 35 | [状态证据](../04-baby/baby-journey-history-privacy/README.md) |
| `/schedule` | 85 | [状态证据](../06-schedule/schedule-journey-add-tooltip/README.md) |
| `/services` | 49 | [状态证据](../03-mom/mom-journey-service-catalog/README.md) |

## 当前边界与下一步

- 原生 Agent 资料卡 → PDF 正文/视频帧连续链已补齐，见 [原生媒体报告](NATIVE-RESOURCE-JOURNEYS.md)。
- Android 首次通知授权与拒绝恢复已补齐，见 [原生权限报告](NATIVE-NOTIFICATION-PERMISSIONS.md)。不代表通知真实投递或其他系统权限分支完成。
- 登录恢复和验证码辅助链见 [登录后续报告](AUTH-FOLLOWUP.md)。
- 指定 conversationId 进入默认 Agent 的初始化异常仍见 [条件入口报告](AGENT-TARGET-ENTRY.md)。路由已观察不等于历史成功加载。
- 开启特性的额外入口、深链参数、其余状态及全体长图审阅仍待完整验收。正常路由总数不能代替原目标的 Page × State × Interaction 清单。
