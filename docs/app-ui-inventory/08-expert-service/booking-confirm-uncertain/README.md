# 网络未连接，请连接后重试

稳定状态 ID：`08-expert-service/booking-confirm-uncertain`

![当前运行界面](default.png)

- 状态：`booking-confirm-uncertain`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`held confirmation blocks back, retries original version then opens intake once`
- 测试来源：[test/modules/services/booking_test.dart:91](../../../../test/modules/services/booking_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/booking-confirm-uncertain-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/services/episodes/:episodeId/booking`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：确认预约

## 其它尺寸与字号

- [booking-confirm-uncertain-390.png](../../raw/test/goldens/design_system/booking-confirm-uncertain-390.png) · 390 × 844
