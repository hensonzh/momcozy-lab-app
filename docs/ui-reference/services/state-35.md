# 预约流程-选择日期与专家时间

- ID：`services/state-35`
- 类型：state
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/booking_page.dart`
- Route / 入口：`/services/episodes/:episodeId/booking`
- 触发：预约前确认通过 → 继续选择时间
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-35.png)

原始路径：`me-ui-optimization/05-validation/images/35-预约流程-选择日期与专家时间.png`；SHA-256：`136a82234e9ed8621c8a7a780ad4b8f058dc8915f28e81e5f7e68563efddf58c`。

[查看参考图](../services/state-35-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`6c325d88c82f0848b3abb89c00faa934a5844d9fe68624be7635c5d3db88732a`。


复核记录：按最新 AppointmentPage、CSS 和新截六状态重构预约前确认/时间确认弹窗、日期/专家/时段列表；22 项预约专项及 98 项服务模块回归通过，320/390/430 与 2x 可滚动，慢请求/结果不确定/保留过期/后台恢复有覆盖。专家头像按 API 缺失情况显示真实姓名缩写。本地无可用测试专家和权益，完整链路使用受控仓库及 Flutter 渲染验证；未宣称原生后端预约完成。state-37 是确认后进入信息采集的过渡，采集页另行验收。

- functional_evidence: [evidence/booking/verification.md](../evidence/booking/verification.md)
- functional_evidence: [evidence/booking/regression.txt](../evidence/booking/regression.txt)
- functional_evidence: [evidence/booking/analyze.txt](../evidence/booking/analyze.txt)
- functional_evidence: [evidence/booking/local-context.json](../evidence/booking/local-context.json)
- visual_evidence: [../../test/goldens/product_baseline/booking-320.png](../../../test/goldens/product_baseline/booking-320.png)
- visual_evidence: [../../test/goldens/product_baseline/booking-390.png](../../../test/goldens/product_baseline/booking-390.png)
- visual_evidence: [../../test/goldens/product_baseline/booking-430.png](../../../test/goldens/product_baseline/booking-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
