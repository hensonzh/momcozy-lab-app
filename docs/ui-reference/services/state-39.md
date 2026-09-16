# 预约流程-信息采集表

- ID：`services/state-39`
- 类型：state
- 参考来源：original
- 设计源码：[IntakePage](../source/src/pages/UserApp.tsx#L3453)，第 3453–3542 行
- Flutter：`lib/modules/services/presentation/intake_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/intake`
- 触发：Me 待填表卡片 → 填写信息
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-39.png)

原始路径：`me-ui-optimization/05-validation/images/39-预约流程-信息采集表.png`；SHA-256：`af43007fc73c24c17dfa66975622de222d10871fb730272a136fea57d22fc646`。

[查看参考图](../services/state-39-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`02aac21f15ee0d1eca75946a72c6c652b60d287ea272a8e78cabcf2371cda01d`。


复核记录：2026-09-12 按当前 IntakePage 源码与新截图对齐；三屏宽及双倍字号、授权、首次提交、修改返回与原快照重试通过，服务模块 107 项回归通过。Flutter 受控仓库渲染证据已复核；本地无专家和预约，真实后端全链路尚未验证，详见 evidence/intake/verification.md。

- functional_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)
- functional_evidence: [evidence/intake/regression.log](../evidence/intake/regression.log)
- functional_evidence: [evidence/intake/analyze.log](../evidence/intake/analyze.log)
- visual_evidence: [../../test/goldens/design_system/intake-form-390.png](../../../test/goldens/design_system/intake-form-390.png)
- visual_evidence: [../../test/goldens/design_system/intake-form-320-2x.png](../../../test/goldens/design_system/intake-form-320-2x.png)
- visual_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
