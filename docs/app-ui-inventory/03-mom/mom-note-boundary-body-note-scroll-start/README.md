# 下午好，Mia

稳定状态 ID：`03-mom/mom-note-boundary-body-note-scroll-start`

![当前运行界面](default.png)

- 状态：`mom-note-boundary-body-note-scroll-start`
- 范围：full-measured-scroll-stitch
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory note boundaries 393/1x`
- 测试来源：[test/modules/mom/mom_note_boundary_inventory_test.dart:146](../../../../test/modules/mom/mom_note_boundary_inventory_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/mom-note-boundary-body-note-scroll-start-393-1x.png.json)
- 长图范围：完整外层表单；内部备注输入框保持实际高度和当前滚动位置，没有将输入框内容展开为页面。输入框首尾状态需查看对应交互截图。
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Me bottom navigation。
- 当前路由：`/me`
- 触发：Drag body note to start → 开始
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- drag：让专业的人，陪你把问题解决

## 其它尺寸与字号

- [mom-note-boundary-body-note-scroll-start-320-2x.png](../../raw/test/goldens/ui_inventory/mom-note-boundary-body-note-scroll-start-320-2x.png) · 320 × 844
- [mom-note-boundary-body-note-scroll-start-393-1x.png](../../raw/test/goldens/ui_inventory/mom-note-boundary-body-note-scroll-start-393-1x.png) · 393 × 844
