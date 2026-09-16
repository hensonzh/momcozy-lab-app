# 信息采集与授权

- ID：`services/intake`
- 类型：page
- 参考来源：original
- 设计源码：[IntakePage](../source/src/pages/UserApp.tsx#L3453)，第 3453–3542 行
- Flutter：`lib/modules/services/presentation/intake_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/intake`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**




复核记录：2026-09-12 按当前 IntakePage 源码与新截图对齐；三屏宽及双倍字号、授权、首次提交、修改返回与原快照重试通过，服务模块 107 项回归通过。Flutter 受控仓库渲染证据已复核；本地无专家和预约，真实后端全链路尚未验证，详见 evidence/intake/verification.md。 Empty-state start alignment updated to match the original EmptyState reference; see shared feedback evidence.

- functional_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)
- functional_evidence: [evidence/intake/regression.log](../evidence/intake/regression.log)
- functional_evidence: [evidence/intake/analyze.log](../evidence/intake/analyze.log)
- functional_evidence: [evidence/feedback/verification.md](../evidence/feedback/verification.md)
- visual_evidence: [../../test/goldens/design_system/intake-form-390.png](../../../test/goldens/design_system/intake-form-390.png)
- visual_evidence: [../../test/goldens/design_system/intake-form-320-2x.png](../../../test/goldens/design_system/intake-form-320-2x.png)
- visual_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
