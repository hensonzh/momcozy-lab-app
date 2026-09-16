# 预约详情

- ID：`services/appointment`
- 类型：page
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/appointment_detail_page.dart`
- Route / 入口：`/services/appointments/:appointmentId`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**




复核记录：2026-09-12 已按当前 AppointmentPage 与 state-51/52 新截图对齐用户端详情及取消确认，三宽/双倍字号/短屏安全区、同版本重试、状态核对及相关 213 项回归通过。原生额外入口和数据字段差异、真实预约链路未验证的边界见 evidence/appointment/verification.md。

- functional_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)
- functional_evidence: [evidence/appointment/regression.log](../evidence/appointment/regression.log)
- functional_evidence: [evidence/appointment/analyze.log](../evidence/appointment/analyze.log)
- visual_evidence: [../../test/goldens/design_system/appointment-detail-390.png](../../../test/goldens/design_system/appointment-detail-390.png)
- visual_evidence: [../../test/goldens/design_system/appointment-detail-320-2x.png](../../../test/goldens/design_system/appointment-detail-320-2x.png)
- visual_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
