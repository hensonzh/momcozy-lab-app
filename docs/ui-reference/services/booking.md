# 预约专家时间

- ID：`services/booking`
- 类型：page
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/booking_page.dart`
- Route / 入口：`/services/episodes/:episodeId/booking`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**




复核记录：按最新 AppointmentPage、CSS 和新截六状态重构预约前确认/时间确认弹窗、日期/专家/时段列表；22 项预约专项及 98 项服务模块回归通过，320/390/430 与 2x 可滚动，慢请求/结果不确定/保留过期/后台恢复有覆盖。专家头像按 API 缺失情况显示真实姓名缩写。本地无可用测试专家和权益，完整链路使用受控仓库及 Flutter 渲染验证；未宣称原生后端预约完成。state-37 是确认后进入信息采集的过渡，采集页另行验收。

- functional_evidence: [evidence/booking/verification.md](../evidence/booking/verification.md)
- functional_evidence: [evidence/booking/regression.txt](../evidence/booking/regression.txt)
- functional_evidence: [evidence/booking/analyze.txt](../evidence/booking/analyze.txt)
- functional_evidence: [evidence/booking/local-context.json](../evidence/booking/local-context.json)
- visual_evidence: [../../test/goldens/design_system/booking-precheck-320.png](../../../test/goldens/design_system/booking-precheck-320.png)
- visual_evidence: [../../test/goldens/design_system/booking-precheck-390.png](../../../test/goldens/design_system/booking-precheck-390.png)
- visual_evidence: [../../test/goldens/design_system/booking-precheck-430.png](../../../test/goldens/design_system/booking-precheck-430.png)
- visual_evidence: [../../test/goldens/design_system/booking-unavailable-320.png](../../../test/goldens/design_system/booking-unavailable-320.png)
- visual_evidence: [../../test/goldens/design_system/booking-unavailable-390.png](../../../test/goldens/design_system/booking-unavailable-390.png)
- visual_evidence: [../../test/goldens/design_system/booking-unavailable-430.png](../../../test/goldens/design_system/booking-unavailable-430.png)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-320.png](../../../test/goldens/design_system/booking-emergency-320.png)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-390.png](../../../test/goldens/design_system/booking-emergency-390.png)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-430.png](../../../test/goldens/design_system/booking-emergency-430.png)
- visual_evidence: [../../test/goldens/design_system/booking-held-320.png](../../../test/goldens/design_system/booking-held-320.png)
- visual_evidence: [../../test/goldens/design_system/booking-held-390.png](../../../test/goldens/design_system/booking-held-390.png)
- visual_evidence: [../../test/goldens/design_system/booking-held-430.png](../../../test/goldens/design_system/booking-held-430.png)
- visual_evidence: [../../test/goldens/product_baseline/booking-320.png](../../../test/goldens/product_baseline/booking-320.png)
- visual_evidence: [../../test/goldens/product_baseline/booking-390.png](../../../test/goldens/product_baseline/booking-390.png)
- visual_evidence: [../../test/goldens/product_baseline/booking-430.png](../../../test/goldens/product_baseline/booking-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
