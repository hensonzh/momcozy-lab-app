# 泌乳支持

稳定状态 ID：`03-mom/mom-journey-service-catalog`

![当前运行界面](default.png)

- 状态：`mom-journey-service-catalog`
- 范围：full-measured-scroll-stitch
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory Mom AI card to Cozymate draft and service catalog`
- 测试来源：[test/modules/mom/mom_inventory_journey_test.dart:138](../../../../test/modules/mom/mom_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/mom-journey-service-catalog-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Me bottom navigation。
- 当前路由：`/services`
- 触发：Home expert companionship entry → real service catalog
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：Me
- tap：让专业的人，陪你把问题解决 / 专家 + AI 持续服务，从分析问题到跟进改善，全程有人陪

## 其它尺寸与字号

- [mom-journey-service-catalog-393.png](../../raw/test/goldens/ui_inventory/mom-journey-service-catalog-393.png) · 393 × 844
