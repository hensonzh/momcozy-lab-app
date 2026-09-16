# agent-history-journey-target-error

稳定状态 ID：`05-agent/agent-history-journey-target-error`

![当前运行界面](default.png)

- 状态：`agent-history-journey-target-error`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory notification conversation actual initialization error 393.0`
- 测试来源：[test/features/agent_hub/agent_history_inventory_journey_test.dart:176](../../../../test/features/agent_hub/agent_history_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/agent-history-journey-target-error-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More page。
- 当前路由：`/?conversationId=22222222-2222-4222-8222-222222222222`
- 触发：Open notification → default target route throws ArgumentError for string Expando key before history HTTP
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, notification coordinator and default Agent builder; isolated notification HTTP and push/permission boundaries. Target route crashes before history repository invocation; no page/feature flag override.

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：Conversation ready

## 其它尺寸与字号

- [agent-history-journey-target-error-320-2x.png](../../raw/test/goldens/ui_inventory/agent-history-journey-target-error-320-2x.png) · 320 × 844
- [agent-history-journey-target-error-393.png](../../raw/test/goldens/ui_inventory/agent-history-journey-target-error-393.png) · 393 × 844
