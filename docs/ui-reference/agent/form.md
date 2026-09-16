# 结构化表单

- ID：`agent/form`
- 类型：dialog
- 参考来源：derived-user-approved
- 设计源码：[结构化表单（衍生设计）](../agent/derived/form.md#L1)，第 1–22 行
- Flutter：`lib/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Aligned entry, dialog, grouping and inputs with the approved derived specification. Fixed 278px short-screen keyboard overflow, long selected-option clipping and duplicate submit calls. 578 regression tests, 48 state goldens, a short-keyboard golden and Android 1x/2x flows with 16 screenshots pass. Restored the ordinary authenticated Mia App. Controlled callbacks verify UI and serialization, not remote tool completion.

- functional_evidence: [evidence/agent-form/verification.md](../evidence/agent-form/verification.md)
- functional_evidence: [evidence/agent-form/before.txt](../evidence/agent-form/before.txt)
- functional_evidence: [evidence/agent-form/component.txt](../evidence/agent-form/component.txt)
- functional_evidence: [evidence/agent-form/regression.txt](../evidence/agent-form/regression.txt)
- functional_evidence: [evidence/agent-form/analyze.txt](../evidence/agent-form/analyze.txt)
- functional_evidence: [evidence/agent-form/native.txt](../evidence/agent-form/native.txt)
- functional_evidence: [evidence/agent-form/build.txt](../evidence/agent-form/build.txt)
- functional_evidence: [evidence/agent-form/install.txt](../evidence/agent-form/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_form_design_test.dart](../../../test/features/agent_hub/agent_form_design_test.dart)
- functional_evidence: [../../test/support/agent_form_scenarios.dart](../../../test/support/agent_form_scenarios.dart)
- functional_evidence: [../../integration_test/agent_form_design_test.dart](../../../integration_test/agent_form_design_test.dart)
- visual_evidence: [evidence/agent-form/native-agent-form-choices-1x.png](../evidence/agent-form/native-agent-form-choices-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-choices-2x.png](../evidence/agent-form/native-agent-form-choices-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-entry-1x.png](../evidence/agent-form/native-agent-form-entry-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-entry-2x.png](../evidence/agent-form/native-agent-form-entry-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-failed-1x.png](../evidence/agent-form/native-agent-form-failed-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-failed-2x.png](../evidence/agent-form/native-agent-form-failed-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-pending-1x.png](../evidence/agent-form/native-agent-form-pending-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-pending-2x.png](../evidence/agent-form/native-agent-form-pending-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-submitted-detail-1x.png](../evidence/agent-form/native-agent-form-submitted-detail-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-submitted-detail-2x.png](../evidence/agent-form/native-agent-form-submitted-detail-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-submitted-entry-1x.png](../evidence/agent-form/native-agent-form-submitted-entry-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-submitted-entry-2x.png](../evidence/agent-form/native-agent-form-submitted-entry-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-top-1x.png](../evidence/agent-form/native-agent-form-top-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-top-2x.png](../evidence/agent-form/native-agent-form-top-2x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-validation-1x.png](../evidence/agent-form/native-agent-form-validation-1x.png)
- visual_evidence: [evidence/agent-form/native-agent-form-validation-2x.png](../evidence/agent-form/native-agent-form-validation-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
