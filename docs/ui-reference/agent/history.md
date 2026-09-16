# 会话历史

- ID：`agent/history`
- 类型：drawer
- 参考来源：original
- 设计源码：[AgentPage](../source/src/pages/UserApp.tsx#L2191)，第 2191–2987 行
- Flutter：`lib/features/agent_hub/presentation/agent_conversation_panel.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../agent/reference/history.png)

原始路径：`me-agent-style-sync/diary-followup/11-agent-history.png`；SHA-256：`ba666c6e4c8cf51f3c80517906f4da0fb12353704677e9b9f1771f857b8a8a5d`。

[查看参考图](../agent/history-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`8d5ecd78d4fa7629cc6b4922ee3052488468fba9bfe74d6fadde5c67c1eee058`。


复核记录：Rechecked live design and captured complete empty/list references; the old image omitted the drawer. Aligned surface, selected lavender, line icon, 18px header, 62px rows, 14/11px type and local date format. Fixed duplicate dismissal notification while preserving immediate stale-load invalidation. 516 related tests, 15 targeted tests and Android 1x/2x state, scrolling and recovery verification pass. Current local history capability remains off; native uses controlled repository/callbacks and does not claim remote history activation. See agent-history evidence.

- functional_evidence: [evidence/theme-motion/preferences/verification.md](../evidence/theme-motion/preferences/verification.md)
- functional_evidence: [evidence/theme-motion/preferences/regression.txt](../evidence/theme-motion/preferences/regression.txt)
- functional_evidence: [evidence/theme-motion/preferences/native.txt](../evidence/theme-motion/preferences/native.txt)
- functional_evidence: [evidence/theme-motion/preferences/video-native.txt](../evidence/theme-motion/preferences/video-native.txt)
- functional_evidence: [evidence/theme-motion/preferences/analyze.txt](../evidence/theme-motion/preferences/analyze.txt)
- functional_evidence: [evidence/agent-history/verification.md](../evidence/agent-history/verification.md)
- functional_evidence: [evidence/agent-history/regression.txt](../evidence/agent-history/regression.txt)
- functional_evidence: [evidence/agent-history/component.txt](../evidence/agent-history/component.txt)
- functional_evidence: [evidence/agent-history/analyze.txt](../evidence/agent-history/analyze.txt)
- functional_evidence: [evidence/agent-history/native.txt](../evidence/agent-history/native.txt)
- functional_evidence: [evidence/agent-history/build.txt](../evidence/agent-history/build.txt)
- functional_evidence: [evidence/agent-history/install.txt](../evidence/agent-history/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_conversation_panel_test.dart](../../../test/features/agent_hub/agent_conversation_panel_test.dart)
- functional_evidence: [../../test/features/agent_hub/agent_history_design_test.dart](../../../test/features/agent_hub/agent_history_design_test.dart)
- functional_evidence: [../../integration_test/agent_history_design_test.dart](../../../integration_test/agent_history_design_test.dart)
- visual_evidence: [evidence/theme-motion/preferences/native-reduced-history-1x.png](../evidence/theme-motion/preferences/native-reduced-history-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-loading-1x.png](../evidence/agent-history/native-agent-history-loading-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-load-error-1x.png](../evidence/agent-history/native-agent-history-load-error-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-locked-1x.png](../evidence/agent-history/native-agent-history-locked-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-list-1x.png](../evidence/agent-history/native-agent-history-list-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-list-end-1x.png](../evidence/agent-history/native-agent-history-list-end-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-switching-1x.png](../evidence/agent-history/native-agent-history-switching-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-switch-error-1x.png](../evidence/agent-history/native-agent-history-switch-error-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-empty-1x.png](../evidence/agent-history/native-agent-history-empty-1x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-loading-2x.png](../evidence/agent-history/native-agent-history-loading-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-load-error-2x.png](../evidence/agent-history/native-agent-history-load-error-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-locked-2x.png](../evidence/agent-history/native-agent-history-locked-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-list-2x.png](../evidence/agent-history/native-agent-history-list-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-list-end-2x.png](../evidence/agent-history/native-agent-history-list-end-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-switching-2x.png](../evidence/agent-history/native-agent-history-switching-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-switch-error-2x.png](../evidence/agent-history/native-agent-history-switch-error-2x.png)
- visual_evidence: [evidence/agent-history/native-agent-history-empty-2x.png](../evidence/agent-history/native-agent-history-empty-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
