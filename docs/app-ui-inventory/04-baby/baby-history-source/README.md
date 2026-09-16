# Luna 的记录

稳定状态 ID：`04-baby/baby-history-source`

![当前运行界面](default.png)

- 状态：`baby-history-source`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`history edits and restores the same baby record at 390.0 / 1.0`
- 测试来源：[test/modules/baby/baby_pages_test.dart:247](../../../../test/modules/baby/baby_pages_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/baby-history-source-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/babies/:babyId/records`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：数据来源
- tap：隐私与授权

## 其它尺寸与字号

- [baby-history-source-390.png](../../raw/test/goldens/design_system/baby-history-source-390.png) · 390 × 844
