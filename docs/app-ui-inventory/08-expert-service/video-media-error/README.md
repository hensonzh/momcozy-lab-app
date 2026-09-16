# TI

稳定状态 ID：`08-expert-service/video-media-error`

![当前运行界面](default.png)

- 状态：`video-media-error`
- 范围：full-measured-scroll-stitch
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`user waiting media controls and leave 390.0 x 844.0 / 1.0`
- 测试来源：[test/modules/consultation/user_video_test.dart:73](../../../../test/modules/consultation/user_video_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/design_system/video-media-error-390.png.json)
- 正常用户入口：**待逐项核实**；下方是当前组件与既有映射推导的候选入口，不视为已遍历。

候选入口：`/services/appointments/:appointmentId/room`

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：已静音
- tap：重新连接
- tap：返回咨询准备

## 其它尺寸与字号

- [video-media-error-320-2x.png](../../raw/test/goldens/design_system/video-media-error-320-2x.png) · 320 × 844
- [video-media-error-320.png](../../raw/test/goldens/design_system/video-media-error-320.png) · 320 × 844
- [video-media-error-390.png](../../raw/test/goldens/design_system/video-media-error-390.png) · 390 × 844
- [video-media-error-430.png](../../raw/test/goldens/design_system/video-media-error-430.png) · 430 × 844
