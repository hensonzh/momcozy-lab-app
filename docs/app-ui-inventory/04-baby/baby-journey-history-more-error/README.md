# 瓶喂母乳 · 96 ml

稳定状态 ID：`04-baby/baby-journey-history-more-error`

![当前运行界面](default.png)

- 状态：`baby-journey-history-more-error`
- 范围：full-measured-scroll-stitch
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory Baby history pagination loading failure recovery`
- 测试来源：[test/modules/baby/baby_inventory_journey_test.dart:150](../../../../test/modules/baby/baby_inventory_journey_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/baby-journey-history-more-error-393.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Baby bottom navigation。
- 当前路由：`/babies/inventory-baby/records`
- 触发：Load more → page failure keeps first page visible
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- drag：瓶喂母乳 · 51 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：备注：记录 5
- drag：2026-09-12 22:00 CST / 备注：记录 7
- drag：瓶喂母乳 · 58 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：备注：记录 14
- drag：2026-09-11 19:00 CST
- drag：瓶喂母乳 · 67 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：备注：记录 21
- drag：2026-09-10 22:00 CST
- drag：瓶喂母乳 · 74 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：2026-09-10 01:00 CST / 备注：记录 30
- drag：瓶喂母乳 · 81 ml / 2026-09-09 19:00 CST
- drag：瓶喂母乳 · 83 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：备注：记录 37
- drag：2026-09-08 22:00 CST
- drag：瓶喂母乳 · 90 ml
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：坐标 [196.5, 444.0] → [196.5, 144.0]
- drag：2026-09-08 01:00 CST / 备注：记录 46
- drag：瓶喂母乳 · 97 ml
- tap：加载更多

## 其它尺寸与字号

- [baby-journey-history-more-error-393.png](../../raw/test/goldens/ui_inventory/baby-journey-history-more-error-393.png) · 393 × 844
