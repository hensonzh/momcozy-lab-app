# 日期

稳定状态 ID：`08-expert-service/service-journey-booking-provider-menu`

![当前运行界面](default.png)

- 状态：`service-journey-booking-provider-menu`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory Services booking availability error empty picker and hold recovery`
- 测试来源：[test/modules/services/service_inventory_journey_test.dart:150](../../../../test/modules/services/service_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/service-journey-booking-provider-menu-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Me bottom navigation。
- 当前路由：`/services/episodes/service-episode/booking`
- 触发：Open provider selector
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：Me
- tap：让专业的人，陪你把问题解决 / 专家 + AI 持续服务，从分析问题到跟进改善，全程有人陪
- tap：查看我的服务
- tap：开始预约
- tap：坐标 [196.5, 374.0] → [196.5, 374.0]
- tap：请选择当前所在州 / California (CA)
- tap：我需要的是哺乳或喂养相关的 IBCLC 咨询
- tap：目前没有上述紧急情况
- tap：继续选择时间
- tap：坐标 [196.5, 307.0] → [196.5, 307.0]

## 其它尺寸与字号

- [service-journey-booking-provider-menu-393.png](../../raw/test/goldens/ui_inventory/service-journey-booking-provider-menu-393.png) · 393 × 844
