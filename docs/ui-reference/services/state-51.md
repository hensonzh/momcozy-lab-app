# 预约流程-预约详情

- ID：`services/state-51`
- 类型：state
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/appointment_detail_page.dart`
- Route / 入口：`/services/appointments/:appointmentId`
- 触发：Me 已确认预约 → 查看
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-51.png)

原始路径：`me-ui-optimization/05-validation/images/51-预约流程-预约详情.png`；SHA-256：`70c219fb24a4b6b32ecbd346ce0a79f93e78f81074146b55781b1159c38096b8`。

[查看参考图](../services/state-51-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`4d85bafdd7991b9ed285c168e05f4ab8acbb352d6da1a88282677553b4a8ce98`。


复核记录：2026-09-12 已按当前 AppointmentPage 与 state-51/52 新截图对齐用户端详情及取消确认，三宽/双倍字号/短屏安全区、同版本重试、状态核对及相关 213 项回归通过。原生额外入口和数据字段差异、真实预约链路未验证的边界见 evidence/appointment/verification.md。

- functional_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)
- functional_evidence: [evidence/appointment/regression.log](../evidence/appointment/regression.log)
- functional_evidence: [evidence/appointment/analyze.log](../evidence/appointment/analyze.log)
- visual_evidence: [../../test/goldens/design_system/appointment-detail-390.png](../../../test/goldens/design_system/appointment-detail-390.png)
- visual_evidence: [../../test/goldens/design_system/appointment-detail-320-2x.png](../../../test/goldens/design_system/appointment-detail-320-2x.png)
- visual_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
