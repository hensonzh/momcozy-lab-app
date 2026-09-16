# 通知、预约提醒及系统设置入口补验

新增 **57 个实际 App 路由状态、9 张完整长图**，以及 **6 张 Android 当前安装 App/系统层截图**。本轮未修改生产页面，也没有把隔离测试的推送就绪状态当成当前本地推送配置已开通。

## 已执行的 7 条隔离流程

1. More → Me → 专家计划 → 我的服务 → 预约提醒：未申请 → 授权说明 → 暂不 → Snackbar → 重新说明/平台允许 → 提醒开启/关闭 → 设置 → 预约分类关闭/开启。
2. 提醒申请被平台拒绝 → 系统设置说明/暂不/打开设置调用 → App 设置拒绝态 → 平台权限恢复后刷新 → 三类通知关闭 → 分类保存失败/重试 → 偏好读取失败/加载/恢复。
3. More 的“通知”入口 → 空消息中心 → 刷新 Loading/Error/Retry → 分页 3/6/7 条 → 归档最后一条 → 全部已读 → 归档失败/重试 → 消息中心设置按钮。
4. 预约提醒读取失败/重试 → 通知分类关闭错误 → 提醒过期错误 → 服务端推送不可用 → 设置中的后台不可用提示 → 恢复推送就绪。
5. 点击消息 → 请求失败 Snackbar → 重试后目标失效/标为已读 → 点击另一条可用消息 → 通过 UUID 路由白名单进入真实预约详情 → 返回消息中心 → 返回 More，未读角标更新。
6. 分页加载中/失败/同游标重试 → 全部已读提交中/失败/原按钮重试 → 归档提交中/完成。
7. 临时授权（quiet/provisional）设置 → 专家反馈/服务更新关闭后重新开启 → 平台和推送 SDK 不可用 → 打开设置的平台调用。

## 原生入口

在当前 Android 模拟器中实际点击 Baby → More → 通知 → Notification settings → Settings，进入 Android 应用通知总开关页面，再返回 App 和原 Baby 页。系统开关原为关闭，App 显示 Not requested，四类通知偏好为开启；返回后值保持一致。没有修改真实偏好、申请权限、登出或发送通知。

六步截图、UI XML、系统版本、PNG 哈希及恢复断言见[原生操作记录](../native/notifications/README.md)。这是当前已安装版本的观察，未重新构建或宣称等同本轮全部隔离场景。系统首次申请弹窗、通知真实投递/点击和 iOS 系统层仍待验证。

## 证据边界与验证

- 使用正式 MomCozyFlutterApp、GoRouter、NotificationCoordinator、NotificationsApiRepository 和 controller。仅 HTTP、推送 Gateway、PermissionPlatform、安装存储为隔离依赖；通过 App 的公开 coordinator 注入点接入，导航和 Snackbar 使用真实 router.go/ScaffoldMessenger。没有替换页面回调为计数器来冒充导航。
- 消息正文、预约和状态均为隔离数据。服务端错误码用于覆盖客户端支持的实际反馈；不是远程推送成功、真实预约变更或后台定时任务的证明。
- 授权教育层打开时，背景提醒组件继续处于 busy；测试等待弹窗动画结束，不无限等待背景进度条停止。
- 测试传输层的异常类最初通过文件相对路径导入，导致专用错误被识别成另一库类型并显示通用反馈。已统一 package 导入，增加两条明确文案断言并重新严格采集，未修改生产错误处理。
- 最终严格截图采集 **7 项通过，0 失败**：[日志](runs/20260913T122103-targeted/capture.log)、[命令](runs/20260913T122103-targeted/capture-command.json)、[结果](runs/20260913T122103-targeted/capture-result.json)。没有像素容差放宽。
- 全仓静态检查：No issues found，[日志](notification-journey-analyze.log)。本轮两个测试文件格式检查通过。
- 已查看覆盖全部 57 状态的 5 张窗口汇总图、9 张长图的 2 张汇总图；单独检查完整七条消息、推送不可用设置全长、两条专用错误及 Android 设置原图。源路径与 SHA-256 见[窗口清单](notification-visual-review/overview-sources.json)、[长图清单](notification-visual-review/long-sources.json)。

## 当前产品观察

- 消息中心归档和“全部已读”失败共用“Couldn’t refresh notifications”错误标题，不区分原操作，保留当前真实 UI。
- 分类开关值代表服务端偏好，系统通知关闭时这些开关仍可为开启，并显示 Background delivery unavailable；不能把开关值误当权限已授予。
- 消息目标失效仍可标为已读，并提示不可用。点击有效消息由服务端返回目标后，通过路由白名单进入预约详情。
- 当前本地构建的后台推送不可用：原生设置页明确展示该说明，消息中心仍可打开。

## 剩余范围

通知专项尚需：首次申请的原生 Allow/Don't allow 弹窗、系统通知投递/点击与前台提示、冷启动/跨账号延迟消息、隐私页的通知入口、提醒注册等待/失败和更多可达目标的完整链路、相关 Tooltip。不能以现有组件金图代替这些运行操作证据。

全 App 仍有其他模块入口、关键分支和全体长图审阅未完成。文件完整性 PASS 只证明已有文件和引用一致，不是目标完成证明。

## 逐状态索引

| 状态 | 实际路由 | 操作 | 截图与前驱关系 |
| --- | --- | --- | --- |
| appointment-to-inbox | `/notifications` | Appointment back → notification center with read state | [状态证据](../07-me/notification-journey-appointment-to-inbox/README.md) |
| appointments-disabled | `/notifications/settings` | Disable appointment notifications category | [状态证据](../07-me/notification-journey-appointments-disabled/README.md) |
| appointments-enabled | `/notifications/settings` | Enable appointment notifications category with permission already granted | [状态证据](../07-me/notification-journey-appointments-enabled/README.md) |
| archive-error | `/notifications` | Archive request fails → row retained and error banner | [状态证据](../07-me/notification-journey-archive-error/README.md) |
| archive-pending | `/notifications` | Archive update → row spinner while request pending | [状态证据](../07-me/notification-journey-archive-pending/README.md) |
| archive-pending-completed | `/notifications` | Archive response → row removed and count refreshed | [状态证据](../07-me/notification-journey-archive-pending-completed/README.md) |
| archive-retry | `/notifications` | Retry archive same update → row removed | [状态证据](../07-me/notification-journey-archive-retry/README.md) |
| category-consultations-off | `/notifications/settings` | Disable Consultations notifications | [状态证据](../07-me/notification-journey-category-consultations-off/README.md) |
| category-expert-feedback-off | `/notifications/settings` | Disable Expert feedback notifications | [状态证据](../07-me/notification-journey-category-expert-feedback-off/README.md) |
| category-expert-feedback-on | `/notifications/settings` | Re-enable Expert feedback → persisted preference | [状态证据](../07-me/notification-journey-category-expert-feedback-on/README.md) |
| category-service-updates-off | `/notifications/settings` | Disable Service updates notifications | [状态证据](../07-me/notification-journey-category-service-updates-off/README.md) |
| category-service-updates-on | `/notifications/settings` | Re-enable Service updates → persisted preference | [状态证据](../07-me/notification-journey-category-service-updates-on/README.md) |
| inbox-all-read | `/notifications` | Mark all read → server state refreshed, unread badge cleared | [状态证据](../07-me/notification-journey-inbox-all-read/README.md) |
| inbox-archived | `/notifications` | Archive last update → removed immediately, unread count refreshed | [状态证据](../07-me/notification-journey-inbox-archived/README.md) |
| inbox-empty | `/notifications` | More notifications entry → empty inbox | [状态证据](../07-me/notification-journey-inbox-empty/README.md) |
| inbox-first-page | `/notifications` | Retry → first three updates with unread count and load more | [状态证据](../07-me/notification-journey-inbox-first-page/README.md) |
| inbox-last-page | `/notifications` | Load final page → full list, no load-more CTA | [状态证据](../07-me/notification-journey-inbox-last-page/README.md) |
| inbox-loading | `/notifications` | Refresh empty inbox → pending response | [状态证据](../07-me/notification-journey-inbox-loading/README.md) |
| inbox-open-entry | `/notifications` | More → unread service updates | [状态证据](../07-me/notification-journey-inbox-open-entry/README.md) |
| inbox-read-error | `/notifications` | Empty inbox read fails → error and retry | [状态证据](../07-me/notification-journey-inbox-read-error/README.md) |
| inbox-second-page | `/notifications` | Load more → append second page | [状态证据](../07-me/notification-journey-inbox-second-page/README.md) |
| inbox-to-more | `/more` | Inbox back → More with updated unread badge | [状态证据](../07-me/notification-journey-inbox-to-more/README.md) |
| inbox-to-settings | `/notifications/settings` | Inbox settings toolbar → notification preferences | [状态证据](../07-me/notification-journey-inbox-to-settings/README.md) |
| mark-all-error | `/notifications` | Mark-all request fails → unread updates and retry banner retained | [状态证据](../07-me/notification-journey-mark-all-error/README.md) |
| mark-all-pending | `/notifications` | Mark all read pending → action disabled, unread count preserved | [状态证据](../07-me/notification-journey-mark-all-pending/README.md) |
| mark-all-retry | `/notifications` | Retry mark all read → read state refreshed | [状态证据](../07-me/notification-journey-mark-all-retry/README.md) |
| notification-open-error | `/notifications` | Open update request fails → inbox retained with Snackbar | [状态证据](../07-me/notification-journey-notification-open-error/README.md) |
| notification-preference-disabled | `/services/episodes/service-episode/booking` | Reminder rejected by server: notification_preference_disabled | [状态证据](../07-me/notification-journey-notification-preference-disabled/README.md) |
| notification-target-unavailable | `/notifications` | Retry open → server reports resource unavailable, item read, no navigation | [状态证据](../07-me/notification-journey-notification-target-unavailable/README.md) |
| notification-to-appointment | `/services/appointments/11111111-1111-4111-8111-111111111111` | Open available update → validated UUID appointment route | [状态证据](../07-me/notification-journey-notification-to-appointment/README.md) |
| pagination-error | `/notifications` | Next page read fails → first page and error banner retained | [状态证据](../07-me/notification-journey-pagination-error/README.md) |
| pagination-loading | `/notifications` | Load more → pending next page with first page retained | [状态证据](../07-me/notification-journey-pagination-loading/README.md) |
| pagination-retry | `/notifications` | Retry load more with same cursor → append second page | [状态证据](../07-me/notification-journey-pagination-retry/README.md) |
| permission-denied | `/services/episodes/service-episode/booking` | Platform denies permission → reminder stays off with feedback | [状态证据](../07-me/notification-journey-permission-denied/README.md) |
| permission-platform-unavailable | `/notifications/settings` | Platform reports unavailable and push SDK unavailable → settings explain delivery boundary | [状态证据](../07-me/notification-journey-permission-platform-unavailable/README.md) |
| permission-provisional | `/notifications/settings` | Inbox settings → platform quiet notification authorization | [状态证据](../07-me/notification-journey-permission-provisional/README.md) |
| permission-settings-offer | `/services/episodes/service-episode/booking` | Enable after denial → offer system settings | [状态证据](../07-me/notification-journey-permission-settings-offer/README.md) |
| permission-settings-requested | `/services/episodes/service-episode/booking` | Open settings invokes isolated platform → reminder remains off until permission restored | [状态证据](../07-me/notification-journey-permission-settings-requested/README.md) |
| preference-write-error | `/notifications/settings` | Enable consultation category fails → previous switch value and Snackbar retained | [状态证据](../07-me/notification-journey-preference-write-error/README.md) |
| preference-write-retry | `/notifications/settings` | Retry enabling consultation category → saved | [状态证据](../07-me/notification-journey-preference-write-retry/README.md) |
| preferences-loading | `/notifications/settings` | Retry preferences → loading and switches disabled | [状态证据](../07-me/notification-journey-preferences-loading/README.md) |
| preferences-read-error | `/notifications/settings` | Refresh preferences fails → inline error | [状态证据](../07-me/notification-journey-preferences-read-error/README.md) |
| preferences-recovered | `/notifications/settings` | Preferences response arrives → error cleared and values restored | [状态证据](../07-me/notification-journey-preferences-recovered/README.md) |
| push-restored | `/notifications/settings` | Refresh after push available → device ready | [状态证据](../07-me/notification-journey-push-restored/README.md) |
| push-unavailable | `/services/episodes/service-episode/booking` | Server push delivery unavailable → no reminder write and explanation | [状态证据](../07-me/notification-journey-push-unavailable/README.md) |
| reminder-disabled | `/services/episodes/service-episode/booking` | Turn reminder off → persisted disabled state | [状态证据](../07-me/notification-journey-reminder-disabled/README.md) |
| reminder-education | `/services/episodes/service-episode/booking` | Enable appointment reminder → permission education | [状态证据](../07-me/notification-journey-reminder-education/README.md) |
| reminder-education-declined | `/services/episodes/service-episode/booking` | Decline education → reminder off and Snackbar | [状态证据](../07-me/notification-journey-reminder-education-declined/README.md) |
| reminder-enabled | `/services/episodes/service-episode/booking` | Continue education → isolated platform grants permission and reminder persists | [状态证据](../07-me/notification-journey-reminder-enabled/README.md) |
| reminder-expired | `/services/episodes/service-episode/booking` | Reminder rejected by server: reminder_expired | [状态证据](../07-me/notification-journey-reminder-expired/README.md) |
| reminder-not-requested | `/services/episodes/service-episode/booking` | Booking → reminder not requested | [状态证据](../07-me/notification-journey-reminder-not-requested/README.md) |
| reminder-read-error | `/services/episodes/service-episode/booking` | Booking reminder read fails → localized retry | [状态证据](../07-me/notification-journey-reminder-read-error/README.md) |
| reminder-read-retry | `/services/episodes/service-episode/booking` | Retry reminder read → off and available | [状态证据](../07-me/notification-journey-reminder-read-retry/README.md) |
| settings-allowed | `/notifications/settings` | Booking notification settings → system allowed and category preferences | [状态证据](../07-me/notification-journey-settings-allowed/README.md) |
| settings-denied | `/notifications/settings` | Notification settings after denial → system permission off | [状态证据](../07-me/notification-journey-settings-denied/README.md) |
| settings-permission-restored | `/notifications/settings` | Return from simulated system change and refresh → allowed; no new permission request | [状态证据](../07-me/notification-journey-settings-permission-restored/README.md) |
| settings-push-unavailable | `/notifications/settings` | Settings retains preferences while background push unavailable | [状态证据](../07-me/notification-journey-settings-push-unavailable/README.md) |


## 后续原生首次权限补验

上文“首次系统申请弹窗待验证”已由后续两条真实 Android 流程补齐：允许，以及拒绝后系统设置恢复，共 23 个状态。详见 [原生权限报告](NATIVE-NOTIFICATION-PERMISSIONS.md)。真实推送投递、冷启动及其他剩余范围仍保留；本报告原 57 个隔离状态证据不作追溯升级。


## 后续注册与 Tooltip 补验

设备注册等待、HTTP 与 token 错误及重试、四个消息中心 Tooltip 已补采；隐私通知入口亦核对到已有实际运行截图。详见 [后续报告](NOTIFICATION-FOLLOWUP.md)。上文这些已补齐项目不再列为当前待办，真实投递及其他目标链仍未完成。
