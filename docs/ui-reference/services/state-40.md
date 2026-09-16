# 信息采集表-补充情况展开

- ID：`services/state-40`
- 类型：state
- 参考来源：original
- 设计源码：[IntakePage](../source/src/pages/UserApp.tsx#L3453)，第 3453–3542 行
- Flutter：`lib/modules/services/presentation/intake_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/intake`
- 触发：信息采集表 → 补充情况
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-40.png)

原始路径：`me-ui-optimization/05-validation/images/40-信息采集表-补充情况展开.png`；SHA-256：`0bcead9942f71b8dd38a869e2d447092360dee53df7ceb61a68e390459865c79`。

[查看参考图](../services/state-40-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`1606b7343f91a3d9f981d8c3dc11fcc41d9057389c3e687be188c5280f64f7f8`。


复核记录：2026-09-12 按当前 IntakePage 源码与新截图对齐；三屏宽及双倍字号、授权、首次提交、修改返回与原快照重试通过，服务模块 107 项回归通过。Flutter 受控仓库渲染证据已复核；本地无专家和预约，真实后端全链路尚未验证，详见 evidence/intake/verification.md。

- functional_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)
- functional_evidence: [evidence/intake/regression.log](../evidence/intake/regression.log)
- functional_evidence: [evidence/intake/analyze.log](../evidence/intake/analyze.log)
- visual_evidence: [../../test/goldens/design_system/intake-optional-390.png](../../../test/goldens/design_system/intake-optional-390.png)
- visual_evidence: [../../test/goldens/design_system/intake-optional-320-2x.png](../../../test/goldens/design_system/intake-optional-320-2x.png)
- visual_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
