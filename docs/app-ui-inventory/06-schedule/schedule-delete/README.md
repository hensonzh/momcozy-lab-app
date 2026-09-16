# 日程

稳定状态 ID：`06-schedule/schedule-delete`

![当前运行界面](default.png)

- 状态：`schedule-delete`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`personal schedule create edit delete at 390.0/1.0`
- 测试来源：[test/modules/schedule/personal_schedule_editor_test.dart:254](../../../../test/modules/schedule/personal_schedule_editor_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/schedule-delete-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/schedule`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：20
- tap：9月12日 · 当天安排 / 日期 / 继续填写
- tap：保存修改
- tap：坐标 [333.0, 540.0] → [333.0, 540.0]
- tap：宝宝体检调整 / 删除

## 其它尺寸与字号

- [schedule-delete-320.png](../../raw/test/goldens/design_system/schedule-delete-320.png) · 320 × 844
- [schedule-delete-390.png](../../raw/test/goldens/design_system/schedule-delete-390.png) · 390 × 844
- [schedule-delete-430.png](../../raw/test/goldens/design_system/schedule-delete-430.png) · 430 × 844
