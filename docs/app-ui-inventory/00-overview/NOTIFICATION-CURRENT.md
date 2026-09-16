# 当前通知中心：列表、偏好与操作反馈

使用正式 More → 通知 → 通知设置，以及通知卡 → 预约详情 → 返回链。运行当前 App、GoRouter、NotificationCoordinator、Repository 与页面控制器；HTTP、权限平台和推送网关使用隔离测试数据。393 px / 1x 与 320 px / 2x 分别操作。

## 实际链路

- 空列表 → 刷新挂起 → 503 → Retry → 首批 3 条 → 第二批 6 条 → 最后 7 条；归档末条 → 未读 6 条 → 全部已读后重新加载第一页。归档失败保留项目，重试后删除；另记录唯一消息归档后空列表及 More 徽标清空。
- 分页挂起/失败保留已加载条目，再次 Load more 成功；全部已读挂起/503/重试成功；单条归档挂起时显示行内进度，回执成功后移除。
- 打开消息失败显示 Snackbar 并保留未读；目标已失效时提示不可用，同时该条变已读；有效消息进入正式预约详情，再返回通知及 More，未读数同步。
- 偏好首次加载挂起/503/刷新恢复；四种分类分别关闭与开启。写入挂起禁用开关，失败保留原值并显示 Snackbar，再次切换成功。
- 刷新权限分别呈现未申请、允许、系统关闭、静默允许、设备不可用；Settings 按钮实际调用测试平台方法。这里证明 App 展示及平台调用，不证明出现真实系统窗口或收到推送。
- 长按 Refresh notifications、Notification settings、Archive notification、Back，分别记录 Tooltip 及到时消失。长按不执行短按业务操作；最后短按归档并返回 More。

## 视觉核验

62 个状态、124 份窗口截图、92 张完整长图，36 个状态以长图为主图。216 张原图拆成 503 个连续全宽片段，其中 261 个唯一片段；255 个新片段组成 43 张审阅页，均已查看，其余 6 个与已审阅图片逐像素一致。原图、分段、前驱、时间戳及当前源码哈希均校验。

- 7 条通知的完整长图覆盖全部条目和最后一项操作；固定页头只保留一次。当前窗口可能因实际点击处于滚动中部，完整内容以对应长图查看。
- 大字号设置页保留所有分类、营销说明和恢复权限说明；Appointments/Consultations 会在单词中间换行，作为当前视觉问题保留。
- 列表失败标题中的弯撇号间距不自然；归档及全部已读失败复用“刷新失败”标题，文案不够贴合操作。
- 偏好写入失败沿用预约提醒错误文案，含“Your appointment is still saved”，即使从设置页切换分类也如此，已如实截图。
- 返回按钮 Tooltip 横跨固定页头与滚动正文。原采集从非零位置拼图会出现一条重复边缘；本批改为实际滚回顶部后长按，重新严格采集并查看，重复边缘已消除。未修改通用采集器或产品业务代码。
- 最新源码重采后仅上述测试操作导致部分 Tooltip 图片改变；其余当前图片与审阅版本哈希一致。

[分段审阅映射](notification-current-visual-review/sources.json) · [证据审计](notification-current-evidence-audit.json) · [源码快照](notification-current-capture-source-snapshot.json) · [逐控件清单](NOTIFICATION-CONTROL-COVERAGE.md)

## 逐状态入口

| 实际操作 | 截图、长图与前驱 |
| --- | --- |
| Appointment back → notification center with read state | [运行证据](../07-me/notification-current-appointment-to-inbox/README.md) |
| Disable appointments → saved false | [运行证据](../07-me/notification-current-appointments-off/README.md) |
| Enable appointments → saved true | [运行证据](../07-me/notification-current-appointments-on/README.md) |
| Archive request fails → row retained and error banner | [运行证据](../07-me/notification-current-archive-error/README.md) |
| Archive only notification → empty inbox and count zero | [运行证据](../07-me/notification-current-archive-final-empty/README.md) |
| Back More → no unread badge; scroll More back to top | [运行证据](../07-me/notification-current-archive-final-more/README.md) |
| Archive update → row spinner while request pending | [运行证据](../07-me/notification-current-archive-pending/README.md) |
| Archive response → row removed and count refreshed | [运行证据](../07-me/notification-current-archive-pending-completed/README.md) |
| Retry archive same update → row removed | [运行证据](../07-me/notification-current-archive-retry/README.md) |
| Disable consultations → saved false | [运行证据](../07-me/notification-current-consultations-off/README.md) |
| Enable consultations → saved true | [运行证据](../07-me/notification-current-consultations-on/README.md) |
| Disable expert_feedback → saved false | [运行证据](../07-me/notification-current-expert_feedback-off/README.md) |
| Enable expert_feedback → saved true | [运行证据](../07-me/notification-current-expert_feedback-on/README.md) |
| Mark all read → server state refreshed, unread badge cleared | [运行证据](../07-me/notification-current-inbox-all-read/README.md) |
| Archive last update → removed immediately, unread count refreshed | [运行证据](../07-me/notification-current-inbox-archived/README.md) |
| More notifications entry → empty inbox | [运行证据](../07-me/notification-current-inbox-empty/README.md) |
| Retry → first three updates with unread count and load more | [运行证据](../07-me/notification-current-inbox-first-page/README.md) |
| Load final page → full list, no load-more CTA | [运行证据](../07-me/notification-current-inbox-last-page/README.md) |
| Refresh empty inbox → pending response | [运行证据](../07-me/notification-current-inbox-loading/README.md) |
| More → unread service updates | [运行证据](../07-me/notification-current-inbox-open-entry/README.md) |
| Empty inbox read fails → error and retry | [运行证据](../07-me/notification-current-inbox-read-error/README.md) |
| Load more → append second page | [运行证据](../07-me/notification-current-inbox-second-page/README.md) |
| Inbox back → More with updated unread badge; scroll More back to top | [运行证据](../07-me/notification-current-inbox-to-more/README.md) |
| Inbox settings toolbar → notification preferences | [运行证据](../07-me/notification-current-inbox-to-settings/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-current-list-more/README.md) |
| Mark-all request fails → unread updates and retry banner retained | [运行证据](../07-me/notification-current-mark-all-error/README.md) |
| Mark all read pending → action disabled, unread count preserved | [运行证据](../07-me/notification-current-mark-all-pending/README.md) |
| Retry mark all read → read state refreshed | [运行证据](../07-me/notification-current-mark-all-retry/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-current-mutation-more/README.md) |
| Open update request fails → inbox retained with Snackbar | [运行证据](../07-me/notification-current-notification-open-error/README.md) |
| Retry open → server reports resource unavailable, item read, no navigation | [运行证据](../07-me/notification-current-notification-target-unavailable/README.md) |
| Open available update → validated UUID appointment route | [运行证据](../07-me/notification-current-notification-to-appointment/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-current-open-more/README.md) |
| Next page read fails → first page and error banner retained | [运行证据](../07-me/notification-current-pagination-error/README.md) |
| Load more → pending next page with first page retained | [运行证据](../07-me/notification-current-pagination-loading/README.md) |
| Retry load more with same cursor → append second page | [运行证据](../07-me/notification-current-pagination-retry/README.md) |
| Write 503 → prior switch value plus Snackbar | [运行证据](../07-me/notification-current-preference-write-error/README.md) |
| Disable consultations → pending write, all switches disabled | [运行证据](../07-me/notification-current-preference-write-pending/README.md) |
| Retry disable → saved false | [运行证据](../07-me/notification-current-preference-write-retry/README.md) |
| Initial preferences 503 → error and no editable values | [运行证据](../07-me/notification-current-preferences-initial-error/README.md) |
| Open settings → preference request pending, switches disabled | [运行证据](../07-me/notification-current-preferences-initial-loading/README.md) |
| Disable service_updates → saved false | [运行证据](../07-me/notification-current-service_updates-off/README.md) |
| Enable service_updates → saved true | [运行证据](../07-me/notification-current-service_updates-on/README.md) |
| Retry → system allowed and preference values loaded | [运行证据](../07-me/notification-current-settings-authorized/README.md) |
| Refresh after simulated system denial → unavailable delivery labels | [运行证据](../07-me/notification-current-settings-denied/README.md) |
| More → empty inbox before settings | [运行证据](../07-me/notification-current-settings-inbox/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-current-settings-more/README.md) |
| Inbox Back → More; scroll More back to top | [运行证据](../07-me/notification-current-settings-more-return/README.md) |
| Settings calls fake platform, page remains; no OS screenshot claim | [运行证据](../07-me/notification-current-settings-open-platform/README.md) |
| Refresh after quiet authorization → delivery available | [运行证据](../07-me/notification-current-settings-provisional/README.md) |
| Settings Back → inbox | [运行证据](../07-me/notification-current-settings-return/README.md) |
| Unavailable platform and SDK → delivery unavailable | [运行证据](../07-me/notification-current-settings-unavailable/README.md) |
| Long press Archive notification → tooltip, action not invoked | [运行证据](../07-me/notification-current-tooltip-archive-notification/README.md) |
| Tooltip timeout → same inbox | [运行证据](../07-me/notification-current-tooltip-archive-notification-dismissed/README.md) |
| Scroll inbox to top; Long press Back → tooltip, action not invoked | [运行证据](../07-me/notification-current-tooltip-back/README.md) |
| Tooltip timeout → same inbox | [运行证据](../07-me/notification-current-tooltip-back-dismissed/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-current-tooltip-more/README.md) |
| Long press Notification settings → tooltip, action not invoked | [运行证据](../07-me/notification-current-tooltip-notification-settings/README.md) |
| Tooltip timeout → same inbox | [运行证据](../07-me/notification-current-tooltip-notification-settings-dismissed/README.md) |
| One unread notification | [运行证据](../07-me/notification-current-tooltip-ready/README.md) |
| Long press Refresh notifications → tooltip, action not invoked | [运行证据](../07-me/notification-current-tooltip-refresh-notifications/README.md) |
| Tooltip timeout → same inbox | [运行证据](../07-me/notification-current-tooltip-refresh-notifications-dismissed/README.md) |

## 验证及边界

- [最终严格采集](runs/20260914T001139-targeted/capture.log)：10 项通过，未更新基线；此前仅为新增场景和修正后的返回 Tooltip 操作生成基线。
- [静态检查](notification-current-analyze.log)：No issues found；测试格式检查通过。
- [完整性检查](notification-current-final-verify.log) 仅核验文件、测量和引用，不等于全 App 覆盖率。
- 测试：`test/features/notifications/notification_current_inventory_test.dart`。
- 本批没有真实系统申请、推送投递、实际预约变更或真实账号写入；预约只打开及返回。原生历史证据见 [Android 权限](NATIVE-NOTIFICATION-PERMISSIONS.md)，不能直接当作当前新布局验证。
- 当前授权说明、拒绝后引导、设备注册失败与恢复已见 [后续运行报告](NOTIFICATION-PERMISSION-CURRENT.md)；其它目标类型、系统层及请求中离页等继续核验。

全 App 的完成状态仍为 **NOT_PROVEN**。
