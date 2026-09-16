# IBCLC 专家团队服务

稳定状态 ID：`07-me/notification-followup-booking-package`

![当前运行界面](default.png)

- 状态：`notification-followup-booking-package`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`notification registration waiting failure pending and retry from booking`
- 测试来源：[test/features/notifications/notification_followup_inventory_test.dart:176](../../../../test/features/notifications/notification_followup_inventory_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/notification-followup-booking-package-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/services/feeding-confidence`
- 触发：My service → purchased package details
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：查看我的服务

## 其它尺寸与字号

- [notification-followup-booking-package-393.png](../../raw/test/goldens/ui_inventory/notification-followup-booking-package-393.png) · 393 × 844
