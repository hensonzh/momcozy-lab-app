# 结构化工具结果

- ID：`agent/structured-card`
- 类型：component
- 参考来源：derived-user-approved
- 设计源码：[结构化工具结果（衍生设计）](../agent/derived/structured-card.md#L1)，第 1–22 行
- Flutter：`lib/features/agent_hub/artifacts/agent_artifact_panel.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：依据原推荐卡补齐原生咨询、动作评估、通用及不支持结果的衍生规范，共享淡紫结果组件。保留同意门禁和真实路由；无回调按钮禁用，删除不可达导出 UI。570 项相关测试及 Android 1x/2x 验证通过，36 张组件与12张原生状态图；恢复 Mia 登录 App。可控回调仅验证 UI 边界，远程 Agent 限制仍单列。

- functional_evidence: [evidence/agent-cards/verification.md](../evidence/agent-cards/verification.md)
- functional_evidence: [evidence/agent-cards/component.txt](../evidence/agent-cards/component.txt)
- functional_evidence: [evidence/agent-cards/actions.txt](../evidence/agent-cards/actions.txt)
- functional_evidence: [evidence/agent-cards/regression.txt](../evidence/agent-cards/regression.txt)
- functional_evidence: [evidence/agent-cards/analyze.txt](../evidence/agent-cards/analyze.txt)
- functional_evidence: [evidence/agent-cards/native.txt](../evidence/agent-cards/native.txt)
- functional_evidence: [evidence/agent-cards/build.txt](../evidence/agent-cards/build.txt)
- functional_evidence: [evidence/agent-cards/install.txt](../evidence/agent-cards/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_result_design_test.dart](../../../test/features/agent_hub/agent_result_design_test.dart)
- functional_evidence: [../../test/features/agent_hub/artifacts/agent_result_card_test.dart](../../../test/features/agent_hub/artifacts/agent_result_card_test.dart)
- functional_evidence: [../../integration_test/agent_result_design_test.dart](../../../integration_test/agent_result_design_test.dart)
- visual_evidence: [evidence/agent-cards/native-agent-result-consent-accepted-1x.png](../evidence/agent-cards/native-agent-result-consent-accepted-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-consent-accepted-2x.png](../evidence/agent-cards/native-agent-result-consent-accepted-2x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-consult-1x.png](../evidence/agent-cards/native-agent-result-consult-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-consult-2x.png](../evidence/agent-cards/native-agent-result-consult-2x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-disabled-1x.png](../evidence/agent-cards/native-agent-result-disabled-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-disabled-2x.png](../evidence/agent-cards/native-agent-result-disabled-2x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-motion-1x.png](../evidence/agent-cards/native-agent-result-motion-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-motion-2x.png](../evidence/agent-cards/native-agent-result-motion-2x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-summary-1x.png](../evidence/agent-cards/native-agent-result-summary-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-summary-2x.png](../evidence/agent-cards/native-agent-result-summary-2x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-unsupported-1x.png](../evidence/agent-cards/native-agent-result-unsupported-1x.png)
- visual_evidence: [evidence/agent-cards/native-agent-result-unsupported-2x.png](../evidence/agent-cards/native-agent-result-unsupported-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
