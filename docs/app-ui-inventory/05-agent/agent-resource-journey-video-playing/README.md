# 播放指导视频

稳定状态 ID：`05-agent/agent-resource-journey-video-playing`

![当前运行界面](default.png)

- 状态：`agent-resource-journey-video-playing`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory agent video entry retry controls and return 393.0`
- 测试来源：[test/features/agent_hub/agent_resource_inventory_journey_test.dart:260](../../../../test/features/agent_hub/agent_resource_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/agent-resource-journey-video-playing-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Cozymate bottom navigation。
- 当前路由：`/media-viewer`
- 触发：Tap play → controller playing state
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage through public builder; real SSE parser, runner, artifact mapper and dispatcher, media and Care repositories; only SSE/HTTP bytes, voice, session and video platform isolated. Real image bytes decoded; video texture/native decoder is a platform stub. Default local history flag; no remote requests.

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：坐标 [28.0, 820.0] → [28.0, 820.0]

## 其它尺寸与字号

- [agent-resource-journey-video-playing-320-2x.png](../../raw/test/goldens/ui_inventory/agent-resource-journey-video-playing-320-2x.png) · 320 × 844
- [agent-resource-journey-video-playing-393.png](../../raw/test/goldens/ui_inventory/agent-resource-journey-video-playing-393.png) · 393 × 844
