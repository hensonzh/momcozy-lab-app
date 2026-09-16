# 隐私与数据

稳定状态 ID：`07-me/privacy-journey-partial-uncertain`

![当前运行界面](default.png)

- 状态：`privacy-journey-partial-uncertain`
- 范围：full-measured-scroll-stitch
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory privacy pending uncertain retry and partial save 393.0`
- 测试来源：[test/modules/profile/privacy_inventory_journey_test.dart:181](../../../../test/modules/profile/privacy_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/privacy-journey-partial-uncertain-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/privacy`
- 触发：Required revocation succeeds; optional write 503 → unresolved change and retry
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production privacy page/controllers and Care/Intake API repositories; isolated HTTP with versioned per-service consent storage; actual More/privacy/notification routes and notification coordinator, no real user permissions mutated

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- 此观察点前没有指针操作记录；可能为直接挂载、异步状态变化或输入事件，需结合测试源码核实。

## 其它尺寸与字号

- [privacy-journey-partial-uncertain-320-2x.png](../../raw/test/goldens/ui_inventory/privacy-journey-partial-uncertain-320-2x.png) · 320 × 844
- [privacy-journey-partial-uncertain-393.png](../../raw/test/goldens/ui_inventory/privacy-journey-partial-uncertain-393.png) · 393 × 844
