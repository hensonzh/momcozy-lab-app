# 打开购买

稳定状态 ID：`08-expert-service/purchase-stripe-launch-error`

![当前运行界面](default.png)

- 状态：`purchase-stripe-launch-error`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`Stripe uses order mode, reports launch failure and queries returned benefits`
- 测试来源：[test/modules/services/service_purchase_test.dart:723](../../../../test/modules/services/service_purchase_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/purchase-stripe-launch-error-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/services/:packageId`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：打开购买
- tap：打开 Stripe Checkout

## 其它尺寸与字号

- [purchase-stripe-launch-error-390.png](../../raw/test/goldens/design_system/purchase-stripe-launch-error-390.png) · 390 × 844
