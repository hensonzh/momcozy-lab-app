# History for 22222222-2222-4222-8222-222222222222

稳定状态 ID：`10-global-modals/notification-conversation`

![当前运行界面](default.png)

- 状态：`notification-conversation`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`notification conversation opens and keeps drafts scoped to its runtime and thread 393.0 / 1.0`
- 测试来源：[test/app/notification_conversation_route_test.dart:130](../../../../test/app/notification_conversation_route_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/notification-conversation-393-1x.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated notification list。
- 当前路由：`/?conversationId=22222222-2222-4222-8222-222222222222`
- 触发：Notification list → Service update 1 → target history loads → message menu → system Back dismisses menu
- 证据边界：Actual default MomCozyFlutterApp/createMomCozyRouter; isolated HTTP and native channels; global history capability remains disabled; target conversation enables repository and history drawer

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：Service update 1

## 其它尺寸与字号

- [notification-conversation-393-1x.png](../../raw/test/goldens/design_system/notification-conversation-393-1x.png) · 393 × 844
