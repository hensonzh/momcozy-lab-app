# 当前通知权限与设备注册链

从正式 More → 通知 → 通知设置进入，操作当前页面、授权说明弹窗及业务控制器。393 px / 1x、320 px / 2x 各运行三条链。权限平台、推送网关、HTTP 和会话存储为隔离依赖，没有改真实账号偏好、预约、系统权限或推送设备绑定。

## 实际执行

- 开启预约分类 → Receive reminders?。分别点击弹窗外部、Not now、框架返回；均关闭弹窗，不调用平台授权，分类保持关闭，并出现通知关闭提示。记录提示到时消失。
- 再次开启 → Continue → 测试平台拒绝；页面显示 Off in system settings，分类保持关闭。再次开启 → Notifications are off 引导，分别取消与 Open settings；后者调用平台但不直接把分类改为开启。模拟系统授权恢复后，通过 Refresh status 读取允许状态，再次开启分类才保存成功；随后关闭并两级返回 More。
- 平台请求抛错 → 分类保持关闭及提示；再试 Continue → 授权与注册成功，分类保存。Settings 按钮调用平台抛错时显示专属 Snackbar；提示消失后重试成功，分类保持原值。
- Refresh status → 设备注册请求挂起，开关和刷新按钮禁用；503 后显示同步失败并恢复原偏好值。之后依次模拟服务端 token 绑定未完成、SDK token 抛错、SDK 无 token、服务端推送不可用、SDK 不可用；每次通过真实刷新按钮触发。
- token 绑定未完成时实际尝试开启分类：页面提示注册待完成，未发出偏好修改请求。恢复网关与服务端后刷新成功，再开启分类保存成功，并经通知列表返回 More。

## 视觉核验

49 个状态、98 份窗口截图、64 张完整长图，29 个状态以长图为主图。162 张原图按完整宽度连续审阅，共 372 段、108 个唯一片段；75 个新片段组成 13 张审阅页，均已查看，33 个片段与此前已审阅图像逐像素一致。[审阅映射](notification-permission-current-visual-review/sources.json)、[证据审计](notification-permission-current-evidence-audit.json)、[源码快照](notification-permission-current-capture-source-snapshot.json)。

- 两类弹窗在窄屏大字号下增高，但标题、完整说明与两个动作仍在当前窗口内；没有将弹窗背后的设置页错误拼成长图。
- 设置长图保留四分类、营销说明、恢复权限说明和最底部 Refresh status；固定页头只出现一次。窗口因点击动作停在分类或刷新位置的情况如实保存，并附完整长图。
- 注册错误与权限错误分别保留对应文案；系统显示 Allowed 时仍可能存在 Background delivery unavailable，表示系统权限与后台投递准备是不同状态。
- 取消首次授权说明后出现“去系统设置开启”的提示，但系统状态仍是 Not requested；这是当前行为，不是测试假设。
- 从通知设置触发拒绝引导也显示“Your appointment is still saved”，沿用预约文案；大字号的 Appointments/Consultations 单词内换行继续保留为视觉问题。
- Snackbar 只保留一次；遮挡底部正文是提示存在时的实际表现，提示消失状态和完整正文证据另存。

## 逐状态入口与返回

| 实际触发 | 截图、长图、前驱 |
| --- | --- |
| Direct Settings → platform opening error and Snackbar | [运行证据](../07-me/notification-permission-current-direct-settings-error/README.md) |
| Settings error timeout → page and enabled category preserved | [运行证据](../07-me/notification-permission-current-direct-settings-error-dismissed/README.md) |
| Direct Settings retry → platform invoked successfully | [运行证据](../07-me/notification-permission-current-direct-settings-retry/README.md) |
| Framework back → education dismissed with off feedback | [运行证据](../07-me/notification-permission-current-education-back-dismissed/README.md) |
| Tap outside education → dismissed, preference unchanged and feedback | [运行证据](../07-me/notification-permission-current-education-barrier-dismissed/README.md) |
| Enable again → education before back | [运行证据](../07-me/notification-permission-current-education-before-back/README.md) |
| Enable again → education before platform denial | [运行证据](../07-me/notification-permission-current-education-before-denial/README.md) |
| Continue → simulated native denial, settings off and Snackbar | [运行证据](../07-me/notification-permission-current-education-denied/README.md) |
| Enable appointments → pre-permission education | [运行证据](../07-me/notification-permission-current-education-dialog/README.md) |
| Feedback timeout → original settings | [运行证据](../07-me/notification-permission-current-education-feedback-dismissed/README.md) |
| More → notification center | [运行证据](../07-me/notification-permission-current-education-inbox/README.md) |
| Settings back → notification center | [运行证据](../07-me/notification-permission-current-education-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-permission-current-education-more/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-permission-current-education-more-return/README.md) |
| Not now → no native permission request, preference stays off | [运行证据](../07-me/notification-permission-current-education-not-now/README.md) |
| Notification center settings → preferences | [运行证据](../07-me/notification-permission-current-education-ready/README.md) |
| Retry enable → education again | [运行证据](../07-me/notification-permission-current-education-reopened/README.md) |
| Enable after denial → system-settings explanation | [运行证据](../07-me/notification-permission-current-offer-settings-dialog/README.md) |
| Not now → do not open system settings, keep preference off | [运行证据](../07-me/notification-permission-current-offer-settings-not-now/README.md) |
| Open settings → fake platform invoked; preference remains off, no OS-window claim | [运行证据](../07-me/notification-permission-current-offer-settings-opened/README.md) |
| Retry after denied permission → settings explanation again | [运行证据](../07-me/notification-permission-current-offer-settings-reopened/README.md) |
| Refresh after simulated system authorization → allowed, preference still off | [运行证据](../07-me/notification-permission-current-permission-restored/README.md) |
| Disable appointments → false persisted | [运行证据](../07-me/notification-permission-current-permission-restored-disabled/README.md) |
| Enable after authorization → true persisted without re-request | [运行证据](../07-me/notification-permission-current-permission-restored-enabled/README.md) |
| Registration 503 → settings error, category values retained | [运行证据](../07-me/notification-permission-current-registration-http-error/README.md) |
| More → notification center | [运行证据](../07-me/notification-permission-current-registration-inbox/README.md) |
| Settings back → notification center | [运行证据](../07-me/notification-permission-current-registration-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-permission-current-registration-more/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-permission-current-registration-more-return/README.md) |
| Refresh → SDK returns no token, registration pending | [运行证据](../07-me/notification-permission-current-registration-null-token/README.md) |
| Refresh → server returns token binding pending | [运行证据](../07-me/notification-permission-current-registration-pending/README.md) |
| Enable while token registration pending → Snackbar, no preference write | [运行证据](../07-me/notification-permission-current-registration-pending-enable/README.md) |
| Notification center settings → preferences | [运行证据](../07-me/notification-permission-current-registration-ready/README.md) |
| Refresh → registration succeeds, error clears | [运行证据](../07-me/notification-permission-current-registration-recovered/README.md) |
| Enable after recovery → preference saved true | [运行证据](../07-me/notification-permission-current-registration-recovered-enabled/README.md) |
| Refresh → SDK unavailable, in-app inbox remains | [运行证据](../07-me/notification-permission-current-registration-sdk-unavailable/README.md) |
| Refresh → server push unavailable, in-app inbox remains | [运行证据](../07-me/notification-permission-current-registration-server-unavailable/README.md) |
| Refresh → SDK token exception | [运行证据](../07-me/notification-permission-current-registration-token-error/README.md) |
| Refresh status → installation request pending, categories disabled | [运行证据](../07-me/notification-permission-current-registration-waiting/README.md) |
| Continue → fake platform grants permission, registration and preference save succeed | [运行证据](../07-me/notification-permission-current-request-authorized/README.md) |
| Continue → platform request throws, preference remains off with feedback | [运行证据](../07-me/notification-permission-current-request-error/README.md) |
| Request-error feedback timeout → no permission change | [运行证据](../07-me/notification-permission-current-request-error-dismissed/README.md) |
| Enable → education before platform exception | [运行证据](../07-me/notification-permission-current-request-error-education/README.md) |
| More → notification center | [运行证据](../07-me/notification-permission-current-request-inbox/README.md) |
| Settings back → notification center | [运行证据](../07-me/notification-permission-current-request-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-permission-current-request-more/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-permission-current-request-more-return/README.md) |
| Notification center settings → preferences | [运行证据](../07-me/notification-permission-current-request-ready/README.md) |
| Retry enable → repeat permission education | [运行证据](../07-me/notification-permission-current-request-retry-education/README.md) |

## 验证及范围

- [最终严格采集](runs/20260914T001956-targeted/capture.log)：6 项通过，未更新基线。建立新场景基线后，仅修正测试替身的一处 if 大括号 lint，再次严格通过。
- [通知模块及新增测试静态检查](notification-permission-current-scoped-analyze.log)：No issues found；新增测试只读格式检查 0 changed。全仓检查另发现 `service_catalog_redesign_test.dart:9` 存在未使用 import（同期服务目录修改），退出码 1，见 [全仓日志](notification-permission-current-analyze.log)；本批未改动该文件。
- [完整性检查](notification-permission-current-final-verify.log) 核验文件、哈希、测量和前驱，不等于全 App 完成。
- 新增文件：`test/features/notifications/notification_permission_current_inventory_test.dart`，及本批金图、采集元数据、审阅图和报告；未修改产品业务代码。
- `handlePopRoute` 只证明框架返回处理；FakePlatform 的拒绝/允许/异常只证明 App 反应，不作为真实 OS 权限窗口证据。原生历史链见 [Android 权限](NATIVE-NOTIFICATION-PERMISSIONS.md)。
- 当前缺省客户端未验证真实推送投递；原生系统层、其他消息目标和交互重叠等剩余范围见 [逐控件清单](NOTIFICATION-CONTROL-COVERAGE.md)。

全 App 完成状态仍为 **NOT_PROVEN**。
