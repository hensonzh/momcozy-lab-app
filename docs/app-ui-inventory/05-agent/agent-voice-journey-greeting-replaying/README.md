# 嗨 Mia，  /  / 今天想聊点什么呢？  /  / 把你现在最关心的事情告诉我就好，我会陪你一起梳理。

稳定状态 ID：`05-agent/agent-voice-journey-greeting-replaying`

![当前运行界面](default.png)

- 状态：`agent-voice-journey-greeting-replaying`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory voice greeting recovery 393/1`
- 测试来源：[test/features/agent_hub/agent_voice_inventory_journey_test.dart:219](../../../../test/features/agent_hub/agent_voice_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/agent-voice-journey-greeting-replaying-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Cozymate bottom navigation。
- 当前路由：`/`
- 触发：Tap replay → greeting restarts without a chat request
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage via public agentHubBuilder; production SSE parser, runner with default retries, cancel client and profile repository; isolated SSE/control HTTP and controllable playback player at public runtime boundary. Voice coordinator, error notice, speaking avatar and replay handlers are production components; no sound output or provider latency measured. History disabled as in default local build; no remote model request.

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：播放回复

## 其它尺寸与字号

- [agent-voice-journey-greeting-replaying-320-2x.png](../../raw/test/goldens/ui_inventory/agent-voice-journey-greeting-replaying-320-2x.png) · 320 × 844
- [agent-voice-journey-greeting-replaying-393.png](../../raw/test/goldens/ui_inventory/agent-voice-journey-greeting-replaying-393.png) · 393 × 844
