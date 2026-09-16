# 当前通知目标跳转、拒绝与恢复

使用正式 MomCozyFlutterApp、GoRouter、通知协调器及各目标业务控制器，从 More → 通知实际点击进入。HTTP、推送网关、权限平台和会话存储为隔离依赖；393 px / 1x 与 320 px / 2x 各运行六条链。未修改真实账号、预约、权限或推送设备绑定。

## 实际执行与发现

- 通知 → 信息采集、咨询房间、服务进度：通知标为已读并进入对应 UUID 路由。房间当前处于预约前等待，显示预约详情及倒计时；不是已连接的视频会话。
- 通知 → 已结束咨询总结：先模拟 GET 503，出现重新加载；恢复接口后点击重试，显示已发布正文、行动和服务信息。已断言正文加载成功。采集准备时纠正了夹具中不受接口支持的 ended 状态，最终使用 closed，未将无效夹具造成的失败当作产品问题。
- 四个服务目标点击返回或关闭均到妈妈首页，因为通知以 router.go 替换路径；之后实际点击 More → 通知 → 返回，验证已读及徽标变化。独立预约详情目标有自己的返回通知行为，见拒绝恢复链。
- 指定 conversationId 的通知目标通过路由校验，但默认 Agent 初始化把字符串传给 Expando，抛出 ArgumentError 并显示 ErrorWidget。测试断言错误类型、Cannot be a string 文本、会话参数及未出现历史正文；通知此时已读。底部 More 仍可操作，并能重新进入通知。与此前 [指定会话入口](AGENT-TARGET-ENTRY.md) 一致。
- 服务端返回不在通知允许列表内的 /privacy：留在通知页，显示不可用提示，该条通知已读。打开请求返回 403 或 404：显示打开失败，仍为未读；提示到时消失后重试，恢复有效预约详情，再返回通知和 More。

## 视觉审核与证明边界

45 个状态、90 份窗口、55 张完整长图，12 个状态以长图为主图。145 张原图共 309 个连续全宽片段；96 个唯一片段中 41 个新片段组成 7 张审阅页，均已查看，其余 55 个逐像素引用此前已审阅片段。[审阅映射](notification-navigation-current-visual-review/sources.json)、[证据审计](notification-navigation-current-evidence-audit.json)、[采集前源码快照](notification-navigation-current-capture-source-snapshot.json)。

- 信息采集长图包含信息使用与保存；服务进度长图包含完整时间线及底部预约入口；总结长图包含正文、行动、帮助提示和折叠服务信息。固定页头、导航和 Snackbar 不重复拼接。
- 点击后窗口按实际滚动位置保留，完整页面另附测量长图。大字下通知正文较长，Snackbar 会遮挡底部内容，保留其到时消失状态；没有将遮挡修饰掉。
- ErrorWidget 的黄色错误文本在宿主测试字体中呈块状；这是调试错误渲染的限制，不能据此验收实体设备的错误字体。错误类型及原因由实际异常断言证明，不能称为会话成功加载。
- 本批核验通知入口、目标到达、总结重试及返回，目标页内部的全部业务动作并未在本批重复执行。已有 [服务流程](SERVICE-JOURNEYS.md)、[咨询流程](CONSULTATION-JOURNEYS.md) 单列；其布局如有源码变化仍须更新。

## 逐状态路径

| 实际操作 | 窗口、长图及前驱证据 |
| --- | --- |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-conversation-final-more/README.md) |
| Notification center before conversation target | [运行证据](../07-me/notification-navigation-current-conversation-inbox/README.md) |
| Target return → notification center with read item | [运行证据](../07-me/notification-navigation-current-conversation-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-conversation-more/README.md) |
| Conversation More tab → no unread badge; scroll More back to top | [运行证据](../07-me/notification-navigation-current-conversation-more-return/README.md) |
| Tap notification → conversation route throws Expando string-key ArgumentError and renders ErrorWidget; item is read | [运行证据](../07-me/notification-navigation-current-conversation-opened/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-episode-final-more/README.md) |
| Target Back/Close → mother home (notification route was replaced) | [运行证据](../07-me/notification-navigation-current-episode-home-return/README.md) |
| Notification center before episode target | [运行证据](../07-me/notification-navigation-current-episode-inbox/README.md) |
| Target return → notification center with read item | [运行证据](../07-me/notification-navigation-current-episode-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-episode-more/README.md) |
| Mother home More tab → updated unread badge; scroll More back to top | [运行证据](../07-me/notification-navigation-current-episode-more-return/README.md) |
| Tap notification → validated episode target, notification marked read | [运行证据](../07-me/notification-navigation-current-episode-opened/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-intake-final-more/README.md) |
| Target Back/Close → mother home (notification route was replaced) | [运行证据](../07-me/notification-navigation-current-intake-home-return/README.md) |
| Notification center before intake target | [运行证据](../07-me/notification-navigation-current-intake-inbox/README.md) |
| Target return → notification center with read item | [运行证据](../07-me/notification-navigation-current-intake-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-intake-more/README.md) |
| Mother home More tab → updated unread badge; scroll More back to top | [运行证据](../07-me/notification-navigation-current-intake-more-return/README.md) |
| Tap notification → validated intake target, notification marked read | [运行证据](../07-me/notification-navigation-current-intake-opened/README.md) |
| Open notification returns 403 → retained unread item and open-error Snackbar | [运行证据](../07-me/notification-navigation-current-rejection-403/README.md) |
| Open-error feedback timeout → retained notification center | [运行证据](../07-me/notification-navigation-current-rejection-403-dismissed/README.md) |
| Open notification returns 404 → retained unread item and open-error Snackbar | [运行证据](../07-me/notification-navigation-current-rejection-404/README.md) |
| Open-error feedback timeout → retained notification center | [运行证据](../07-me/notification-navigation-current-rejection-404-dismissed/README.md) |
| Three unread updates before route validation | [运行证据](../07-me/notification-navigation-current-rejection-inbox/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-rejection-more-return/README.md) |
| Appointment return → unread count updated | [运行证据](../07-me/notification-navigation-current-rejection-recovered-inbox/README.md) |
| Retry after access restoration → appointment detail | [运行证据](../07-me/notification-navigation-current-rejection-recovered-target/README.md) |
| Server target outside allowed notification routes → no navigation, unavailable Snackbar | [运行证据](../07-me/notification-navigation-current-rejection-unsafe-route/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-rejections-more/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-room-final-more/README.md) |
| Target Back/Close → mother home (notification route was replaced) | [运行证据](../07-me/notification-navigation-current-room-home-return/README.md) |
| Notification center before room target | [运行证据](../07-me/notification-navigation-current-room-inbox/README.md) |
| Target return → notification center with read item | [运行证据](../07-me/notification-navigation-current-room-inbox-return/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-room-more/README.md) |
| Mother home More tab → updated unread badge; scroll More back to top | [运行证据](../07-me/notification-navigation-current-room-more-return/README.md) |
| Tap notification → validated room target, notification marked read | [运行证据](../07-me/notification-navigation-current-room-opened/README.md) |
| Notification center back → More; scroll More back to top | [运行证据](../07-me/notification-navigation-current-summary-final-more/README.md) |
| Target Back/Close → mother home (notification route was replaced) | [运行证据](../07-me/notification-navigation-current-summary-home-return/README.md) |
| Notification center before summary target | [运行证据](../07-me/notification-navigation-current-summary-inbox/README.md) |
| Target return → notification center with read item | [运行证据](../07-me/notification-navigation-current-summary-inbox-return/README.md) |
| Notification → summary GET 503 → unavailable card with retry | [运行证据](../07-me/notification-navigation-current-summary-load-error/README.md) |
| Authenticated More before notifications; scroll More back to top | [运行证据](../07-me/notification-navigation-current-summary-more/README.md) |
| Mother home More tab → updated unread badge; scroll More back to top | [运行证据](../07-me/notification-navigation-current-summary-more-return/README.md) |
| Tap notification → validated summary target, notification marked read | [运行证据](../07-me/notification-navigation-current-summary-opened/README.md) |

## 验证与剩余范围

12 项严格采集通过，未在严格运行中更新 Golden；通知代码和本批测试静态检查通过。全仓静态检查当前有服务套餐改版测试第 23 行 use_null_aware_elements 的 1 项 info，退出码 1，不能记为全仓通过。日志见 [严格运行](runs/20260914T003614-targeted/capture.log)、[专项静态检查](notification-navigation-current-scoped-analyze.log)、[全仓检查](notification-navigation-current-analyze.log)、[完整性校验](notification-navigation-current-final-verify.log)。测试文件为 `test/features/notifications/notification_navigation_current_inventory_test.dart`，本批未修改产品业务代码。

通知系统层当前布局衔接、推送/会话变化、请求中离页及其它有意义并发状态仍见 [逐控件清单](NOTIFICATION-CONTROL-COVERAGE.md)。新增服务组件当前已有源码入口、尚未按新布局运行，列入后续更新；全体历史长图审阅和全 App 完成状态仍为 **NOT_PROVEN**。
