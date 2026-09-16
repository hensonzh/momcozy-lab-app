# 2026年9月

稳定状态 ID：`06-schedule/schedule-journey-delete-confirm`

![当前运行界面](default.png)

- 状态：`schedule-journey-delete-confirm`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory schedule calendar create edit delete`
- 测试来源：[test/modules/schedule/schedule_inventory_journey_test.dart:153](../../../../test/modules/schedule/schedule_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/schedule-journey-delete-confirm-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Schedule bottom navigation。
- 当前路由：`/schedule`
- 触发：Delete → confirmation
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：坐标 [353.0, 405.0] → [353.0, 405.0]
- tap：删除

## 其它尺寸与字号

- [schedule-journey-delete-confirm-393.png](../../raw/test/goldens/ui_inventory/schedule-journey-delete-confirm-393.png) · 393 × 844
