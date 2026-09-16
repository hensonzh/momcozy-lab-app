# 预约流程-紧急风险提示

- ID：`services/state-34`
- 类型：state
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/booking_page.dart`
- Route / 入口：`/services/episodes/:episodeId/booking`
- 触发：预约前确认 → 有，或我不确定
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-34.png)

原始路径：`me-ui-optimization/05-validation/images/34-预约流程-紧急风险提示.png`；SHA-256：`44cc4950e3d1c359ce3c364cc23fe9c0e853d2007f32e459ad3d56d5adaaccbf`。

[查看参考图](../services/state-34-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`9a175d303beae3b67a4a78deb0950955796fd8832317f08bb54dc6118e6b18e9`。


复核记录：按最新 AppointmentPage、CSS 和新截六状态重构预约前确认/时间确认弹窗、日期/专家/时段列表；22 项预约专项及 98 项服务模块回归通过，320/390/430 与 2x 可滚动，慢请求/结果不确定/保留过期/后台恢复有覆盖。专家头像按 API 缺失情况显示真实姓名缩写。本地无可用测试专家和权益，完整链路使用受控仓库及 Flutter 渲染验证；未宣称原生后端预约完成。state-37 是确认后进入信息采集的过渡，采集页另行验收。

- functional_evidence: [evidence/booking/verification.md](../evidence/booking/verification.md)
- functional_evidence: [evidence/booking/regression.txt](../evidence/booking/regression.txt)
- functional_evidence: [evidence/booking/analyze.txt](../evidence/booking/analyze.txt)
- functional_evidence: [evidence/booking/local-context.json](../evidence/booking/local-context.json)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-320.png](../../../test/goldens/design_system/booking-emergency-320.png)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-390.png](../../../test/goldens/design_system/booking-emergency-390.png)
- visual_evidence: [../../test/goldens/design_system/booking-emergency-430.png](../../../test/goldens/design_system/booking-emergency-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
