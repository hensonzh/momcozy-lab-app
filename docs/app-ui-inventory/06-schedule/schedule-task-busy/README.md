# 2026年9月

稳定状态 ID：`06-schedule/schedule-task-busy`

![当前运行界面](default.png)

- 状态：`schedule-task-busy`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`task write disables competing changes and keeps server version`
- 测试来源：[test/modules/schedule/schedule_page_golden_test.dart:624](../../../../test/modules/schedule/schedule_page_golden_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/schedule-task-busy.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/schedule`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：坐标 [55.0, 242.0] → [55.0, 242.0]
- tap：坐标 [263.0, 242.0] → [263.0, 242.0]

## 其它尺寸与字号

- [schedule-task-busy.png](../../raw/test/goldens/design_system/schedule-task-busy.png) · 320 × 844
