# 已确认 · IBCLC 咨询

稳定状态 ID：`07-me/notification-journey-push-unavailable`

![当前运行界面](default.png)

- 状态：`notification-journey-push-unavailable`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory notification reminder failures and unavailable push`
- 测试来源：[test/features/notifications/notification_inventory_journey_test.dart:178](../../../../test/features/notifications/notification_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/notification-journey-push-unavailable-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/services/episodes/service-episode/booking`
- 触发：Server push delivery unavailable → no reminder write and explanation
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production notification coordinator/repository/controller; isolated HTTP, push gateway and permission platform; real router.go and ScaffoldMessenger callbacks, no native OS dialog or remote push

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：预约提醒 / 此设备尚未开启提醒，预约已保存。

## 其它尺寸与字号

- [notification-journey-push-unavailable-393.png](../../raw/test/goldens/ui_inventory/notification-journey-push-unavailable-393.png) · 393 × 844
