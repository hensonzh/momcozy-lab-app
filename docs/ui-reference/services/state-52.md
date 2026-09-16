# 预约流程-取消预约确认

- ID：`services/state-52`
- 类型：state
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/appointment_detail_page.dart`
- Route / 入口：`/services/appointments/:appointmentId`
- 触发：预约详情 → 取消预约
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-52.png)

原始路径：`me-ui-optimization/05-validation/images/52-预约流程-取消预约确认.png`；SHA-256：`66325248167bbbf8963ed828c0c982d64daa9e12bdb2745a40563ab56c5bb2f3`。

[查看参考图](../services/state-52-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`16a0e7caef8ad21b8ded1de14b2c7a672a7d13cd0af23b0718e53e084e698d81`。


复核记录：2026-09-12 已按当前 AppointmentPage 与 state-51/52 新截图对齐用户端详情及取消确认，三宽/双倍字号/短屏安全区、同版本重试、状态核对及相关 213 项回归通过。原生额外入口和数据字段差异、真实预约链路未验证的边界见 evidence/appointment/verification.md。

- functional_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)
- functional_evidence: [evidence/appointment/regression.log](../evidence/appointment/regression.log)
- functional_evidence: [evidence/appointment/analyze.log](../evidence/appointment/analyze.log)
- visual_evidence: [../../test/goldens/design_system/appointment-cancel-390.png](../../../test/goldens/design_system/appointment-cancel-390.png)
- visual_evidence: [../../test/goldens/design_system/appointment-cancel-320-2x.png](../../../test/goldens/design_system/appointment-cancel-320-2x.png)
- visual_evidence: [evidence/appointment/verification.md](../evidence/appointment/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
