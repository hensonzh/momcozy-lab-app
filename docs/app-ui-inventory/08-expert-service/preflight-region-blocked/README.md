# 预约详情

稳定状态 ID：`08-expert-service/preflight-region-blocked`

![当前运行界面](default.png)

- 状态：`preflight-region-blocked`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`device consent region and enter 390.0 / 1.0`
- 测试来源：[test/modules/consultation/consultation_start_test.dart:152](../../../../test/modules/consultation/consultation_start_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/preflight-region-blocked-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/services/appointments/:appointmentId/room`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：坐标 [195.0, 718.0] → [195.0, 718.0]
- tap：California (CA) / New York (NY)
- tap：确认并进入咨询室

## 其它尺寸与字号

- [preflight-region-blocked-320-2x.png](../../raw/test/goldens/design_system/preflight-region-blocked-320-2x.png) · 320 × 844
- [preflight-region-blocked-320.png](../../raw/test/goldens/design_system/preflight-region-blocked-320.png) · 320 × 844
- [preflight-region-blocked-390.png](../../raw/test/goldens/design_system/preflight-region-blocked-390.png) · 390 × 844
- [preflight-region-blocked-430.png](../../raw/test/goldens/design_system/preflight-region-blocked-430.png) · 430 × 844
