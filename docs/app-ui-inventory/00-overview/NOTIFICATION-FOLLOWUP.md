# 通知注册、重试与 Tooltip 后续盘点

新增 **33 个正常入口状态、33 张窗口图和 5 张完整纵向长图**，3 条正式 App 路由测试通过。此次仅增加采集测试和视觉资产，未修改生产 UI、通知协调器或实际账号数据。

## 实际运行链路

1. More → Me → 专家陪伴计划 → 服务目录 → 查看我的服务 → 已购套餐详情 → 开始预约 → 已有预约详情。开启预约提醒后，依次观察设备注册等待、服务端 token 绑定尚未完成、注册 HTTP 失败、推送 SDK token 获取失败，最后重试成功并关闭提醒。每次错误有明确 Snackbar；失败期间没有向预约提醒接口提交开启写入。
2. More → 通知 → Notification settings → Refresh status。注册等待时显示进度条并禁用分类编辑；注册 HTTP 失败、token 绑定待完成、SDK token 错误分别显示对应说明。恢复后 Service notifications 可用，再返回消息中心及 More。
3. More → 有一条未读消息的通知中心。分别实际长按 Refresh notifications、Notification settings、Archive notification、Back，采集 Tooltip 及超时消失后的状态；长按没有打开设置、归档或返回。之后短按归档，观察空消息中心及返回 More 后角标清除。

第一条入口中的“查看我的服务”实际进入 `/services/feeding-confidence` 套餐详情，并非直接进入 episode 时间线；初次测试的路由断言据运行结果纠正。保留产品现有路径，不为测试新增入口。

## 数据与证据边界

使用正式 MomCozyFlutterApp、createMomCozyRouter、NotificationCoordinator、NotificationsApiRepository、预约与通知页面。隔离层仅控制 HTTP 注册响应、请求等待门闩、推送 token、权限平台与存储。注册失败和 pending 是客户端已经支持的真实状态，不将本次隔离结果视为真实 FCM 投递或原生权限验证；原生系统权限另见 [原生权限报告](NATIVE-NOTIFICATION-PERMISSIONS.md)。

测试时钟与数据固定；没有写入本地实际账号的预约、健康或通知偏好。四个 Tooltip 均通过真实 longPress 显示，未直接创建 Tooltip 组件或调用 ensureTooltipVisible。

## 视觉检查

38 张原图已全部通过 11 张分段图人工查看，覆盖 43 个连续片段：[原图清单及 SHA-256](notification-followup-visual-review/sources.json)。最终仅补齐测试清理代码的 lint 大括号后重新严格采集，38 张图片的 SHA 完全一致。

5 张长图分别是服务目录、妈妈已购无记录首页，以及设置页的注册 HTTP 错误、绑定 pending、SDK token 错误态。长图从顶部覆盖到完整底部；妈妈页保留一次固定导航，服务目录包含最后一张服务卡。错误设置页因提示文案增加而略微超出一屏，长图补齐底部 Refresh status，未将中途滚动窗口当成完整页面。

Tooltip 可见且未裁切；其对未读数量、全部已读按钮和消息正文的暂时遮挡按实际界面保留。错误 Snackbar 完整显示，预约详情的通知开关及其他操作也在同一窗口内。

| 审阅图 | 审阅图 | 审阅图 |
| --- | --- | --- |
| [分段 01](notification-followup-visual-review/sheet-01.png) | [分段 02](notification-followup-visual-review/sheet-02.png) | [分段 03](notification-followup-visual-review/sheet-03.png) |
| [分段 04](notification-followup-visual-review/sheet-04.png) | [分段 05](notification-followup-visual-review/sheet-05.png) | [分段 06](notification-followup-visual-review/sheet-06.png) |
| [分段 07](notification-followup-visual-review/sheet-07.png) | [分段 08](notification-followup-visual-review/sheet-08.png) | [分段 09](notification-followup-visual-review/sheet-09.png) |
| [分段 10](notification-followup-visual-review/sheet-10.png) | [分段 11](notification-followup-visual-review/sheet-11.png) |  |

## 验证结果

- 最终严格采集：**3 PASS，0 失败**。未放宽像素容差，未在严格采集中更新 Golden。[执行日志](runs/20260913T183615-targeted/capture.log)、[命令](runs/20260913T183615-targeted/capture-command.json)、[结果](runs/20260913T183615-targeted/capture-result.json)。
- 全仓 `flutter analyze --no-pub`：No issues found。[日志](notification-followup-analyze.log)。新测试格式只读检查 0 changed。
- 新测试：`test/features/notifications/notification_followup_inventory_test.dart`。测试专用传输层及 Gateway 扩展在同文件内，未改变共用的其他流程夹具。
- 本轮完整性验证另见 [验证结果](artifact-verification.json)；它验证文件、哈希、引用和测量边界，不能证明全 App 交互均已覆盖。

```sh
flutter test --no-pub test/features/notifications/notification_followup_inventory_test.dart --reporter expanded
python3 scripts/capture-app-ui-inventory.py --flutter /Users/lute/.local/share/momcozy-toolchains/flutter/bin/flutter --test test/features/notifications/notification_followup_inventory_test.dart
```

## 逐状态索引

| 状态 | 实际路由 | 触发方式 | 截图、长图与前驱 |
| --- | --- | --- | --- |
| booking-catalog | `/services` | Expert plan entry → service catalog | [状态证据](../07-me/notification-followup-booking-catalog/README.md) |
| booking-mom | `/me` | More bottom Me → mother home | [状态证据](../07-me/notification-followup-booking-mom/README.md) |
| booking-more | `/more` | Authenticated More entry | [状态证据](../07-me/notification-followup-booking-more/README.md) |
| booking-package | `/services/feeding-confidence` | My service → purchased package details | [状态证据](../07-me/notification-followup-booking-package/README.md) |
| registration-disabled | `/services/episodes/service-episode/booking` | Turn reminder off → saved disabled | [状态证据](../07-me/notification-followup-registration-disabled/README.md) |
| registration-http-error | `/services/episodes/service-episode/booking` | Retry reminder → installation HTTP error and feedback | [状态证据](../07-me/notification-followup-registration-http-error/README.md) |
| registration-pending | `/services/episodes/service-episode/booking` | Registration returned no token binding → reminder remains off with Snackbar | [状态证据](../07-me/notification-followup-registration-pending/README.md) |
| registration-retry-enabled | `/services/episodes/service-episode/booking` | Retry after token recovery → reminder saved and enabled | [状态证据](../07-me/notification-followup-registration-retry-enabled/README.md) |
| registration-token-error | `/services/episodes/service-episode/booking` | Retry reminder → push token error and feedback | [状态证据](../07-me/notification-followup-registration-token-error/README.md) |
| registration-waiting | `/services/episodes/service-episode/booking` | Enable reminder → device registration request pending | [状态证据](../07-me/notification-followup-registration-waiting/README.md) |
| reminder-ready | `/services/episodes/service-episode/booking` | Appointment booking → reminder off | [状态证据](../07-me/notification-followup-reminder-ready/README.md) |
| settings-inbox | `/notifications` | More notifications → inbox | [状态证据](../07-me/notification-followup-settings-inbox/README.md) |
| settings-inbox-return | `/notifications` | Settings back → inbox | [状态证据](../07-me/notification-followup-settings-inbox-return/README.md) |
| settings-more | `/more` | Authenticated More entry | [状态证据](../07-me/notification-followup-settings-more/README.md) |
| settings-more-return | `/more` | Inbox back → original More | [状态证据](../07-me/notification-followup-settings-more-return/README.md) |
| settings-ready | `/notifications/settings` | Inbox settings → registered device | [状态证据](../07-me/notification-followup-settings-ready/README.md) |
| settings-recovered | `/notifications/settings` | Refresh → device registered and service notifications available | [状态证据](../07-me/notification-followup-settings-recovered/README.md) |
| settings-refresh-waiting | `/notifications/settings` | Refresh status → registration pending and categories disabled | [状态证据](../07-me/notification-followup-settings-refresh-waiting/README.md) |
| settings-registration-error | `/notifications/settings` | Registration HTTP failure → settings error and unavailable delivery | [状态证据](../07-me/notification-followup-settings-registration-error/README.md) |
| settings-registration-pending | `/notifications/settings` | Refresh → server token registration pending | [状态证据](../07-me/notification-followup-settings-registration-pending/README.md) |
| settings-token-error | `/notifications/settings` | Refresh → SDK token unavailable | [状态证据](../07-me/notification-followup-settings-token-error/README.md) |
| tooltip-archive-clicked | `/notifications` | Short tap Archive notification → row removed and empty inbox | [状态证据](../07-me/notification-followup-tooltip-archive-clicked/README.md) |
| tooltip-archive-notification | `/notifications` | Long press Archive notification → actual Tooltip overlay | [状态证据](../07-me/notification-followup-tooltip-archive-notification/README.md) |
| tooltip-archive-notification-dismissed | `/notifications` | Tooltip timeout → inbox retained, action not invoked | [状态证据](../07-me/notification-followup-tooltip-archive-notification-dismissed/README.md) |
| tooltip-back | `/notifications` | Long press Back → actual Tooltip overlay | [状态证据](../07-me/notification-followup-tooltip-back/README.md) |
| tooltip-back-dismissed | `/notifications` | Tooltip timeout → inbox retained, action not invoked | [状态证据](../07-me/notification-followup-tooltip-back-dismissed/README.md) |
| tooltip-inbox | `/notifications` | More notifications → one unread notification | [状态证据](../07-me/notification-followup-tooltip-inbox/README.md) |
| tooltip-more | `/more` | Authenticated More entry | [状态证据](../07-me/notification-followup-tooltip-more/README.md) |
| tooltip-more-return | `/more` | Back button short tap → More | [状态证据](../07-me/notification-followup-tooltip-more-return/README.md) |
| tooltip-notification-settings | `/notifications` | Long press Notification settings → actual Tooltip overlay | [状态证据](../07-me/notification-followup-tooltip-notification-settings/README.md) |
| tooltip-notification-settings-dismissed | `/notifications` | Tooltip timeout → inbox retained, action not invoked | [状态证据](../07-me/notification-followup-tooltip-notification-settings-dismissed/README.md) |
| tooltip-refresh-notifications | `/notifications` | Long press Refresh notifications → actual Tooltip overlay | [状态证据](../07-me/notification-followup-tooltip-refresh-notifications/README.md) |
| tooltip-refresh-notifications-dismissed | `/notifications` | Tooltip timeout → inbox retained, action not invoked | [状态证据](../07-me/notification-followup-tooltip-refresh-notifications-dismissed/README.md) |

## 待办校正与剩余范围

隐私页“管理通知与提醒”入口此前已由隐私专项实际点击并返回，未保存的隐私草稿仍保留：[进入通知设置](../07-me/privacy-journey-notification-settings/README.md)、[返回隐私页](../07-me/privacy-journey-notifications-return/README.md)。旧通知报告把该入口列为待办属于跨报告同步遗漏，本次已纠正，不重复计入新增状态。

通知专项仍有真实推送投递、前台提示、系统通知点击和冷启动、跨账号延迟消息及其他合法目标完整链等范围。iOS 系统层、其他权限分支和全 App 长图审核仍未完成。本次 33 状态与原生权限报告均只是完整目标的增量证据，不将全部目标标记为完成。
