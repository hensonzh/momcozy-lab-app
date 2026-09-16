# 更多

稳定状态 ID：`07-me/notification-permission-current-education-more-return`

![当前运行界面](default.png)

- 状态：`notification-permission-current-education-more-return`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`notification permission education cancellation denial and settings false`
- 测试来源：[test/features/notifications/notification_permission_current_inventory_test.dart:190](../../../../test/features/notifications/notification_permission_current_inventory_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/notification-permission-current-education-more-return-393-1x.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/more`
- 触发：Notification center back → More; scroll More back to top
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：坐标 [28.0, 28.0] → [28.0, 28.0]
- drag：坐标 [196.5, 383.0] → [196.5, 8383.0]

## 其它尺寸与字号

- [notification-permission-current-education-more-return-320-2x.png](../../raw/test/goldens/ui_inventory/notification-permission-current-education-more-return-320-2x.png) · 320 × 844
- [notification-permission-current-education-more-return-393-1x.png](../../raw/test/goldens/ui_inventory/notification-permission-current-education-more-return-393-1x.png) · 393 × 844
