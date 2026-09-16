# 已确认 · IBCLC 咨询

稳定状态 ID：`07-me/notification-navigation-current-rejection-recovered-target`

![当前运行界面](default.png)

- 状态：`notification-navigation-current-rejection-recovered-target`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`notification unsafe target and forbidden not found requests false`
- 测试来源：[test/features/notifications/notification_navigation_current_inventory_test.dart:191](../../../../test/features/notifications/notification_navigation_current_inventory_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/notification-navigation-current-rejection-recovered-target-393-1x.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/services/appointments/11111111-1111-4111-8111-111111111111`
- 触发：Retry after access restoration → appointment detail
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：Service update 2

## 其它尺寸与字号

- [notification-navigation-current-rejection-recovered-target-320-2x.png](../../raw/test/goldens/ui_inventory/notification-navigation-current-rejection-recovered-target-320-2x.png) · 320 × 844
- [notification-navigation-current-rejection-recovered-target-393-1x.png](../../raw/test/goldens/ui_inventory/notification-navigation-current-rejection-recovered-target-393-1x.png) · 393 × 844
