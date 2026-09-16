# 体重

稳定状态 ID：`04-baby/baby-development-date-known-birth-years`

![当前运行界面](default.png)

- 状态：`baby-development-date-known-birth-years`
- 范围：viewport
- 数据：组件测试的合成数据，不代表生产账户业务状态。
- 实际执行：`inventory development date 393/1x`
- 测试来源：[test/modules/baby/baby_development_date_inventory_test.dart:161](../../../../test/modules/baby/baby_development_date_inventory_test.dart)
- [运行元数据、点击轨迹与滚动范围](../../raw/test/goldens/ui_inventory/baby-development-date-known-birth-years-393-1x.png.json)
- 正常路由链：**已在实际 App 路由中执行**；Authenticated More → tap Baby bottom navigation。
- 当前路由：`/baby`
- 触发：Tap calendar header → only birth/current year selectable
- 证据边界：Actual MomCozyFlutterApp/createMomCozyRouter, production repositories and codecs, isolated in-memory HTTP data, fixed clock and timezone

业务写操作均只请求测试传输层；不表示生产账号的数据被修改，也不代表外部服务交易已验收。

前一个已截图状态之后实际发生的指针操作（文字仅为起点附近的几何匹配，可能包含遮挡背景，不等于命中控件；实际目标以测试定位、断言和上述触发说明为准）：

- tap：记录后会显示Luna的变化，浅绿色为 WHO 同龄参考范围。适合观察长期变化，不能根据单次测量下结论。 / 观察到 / 2026年9月

## 其它尺寸与字号

- [baby-development-date-known-birth-years-393-1x.png](../../raw/test/goldens/ui_inventory/baby-development-date-known-birth-years-393-1x.png) · 393 × 844
