# 语音操作

- ID：`agent/voice`
- 类型：state
- 参考来源：original
- 设计源码：[AgentPage](../source/src/pages/UserApp.tsx#L2191)，第 2191–2987 行
- Flutter：`lib/features/agent_hub/agent_hub_page.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**




复核记录：Rechecked source and captured original voice switch references. Added neutral failure/replay/dismiss UI and switch/live-region semantics. Retry preserves playback priority and never resends a question; active runs disable replay, new turns clear stale errors. Fixed constrained-height error/composer overflow. 587 related tests, 9 targeted tests and Android 1x/2x recovery/control flows pass; 36 state goldens, one keyboard golden and 12 native screenshots. Ordinary Mia App restored. Controlled audio/event providers verify UI boundaries, not remote synthesis or model authentication.

- functional_evidence: [evidence/agent-voice/verification.md](../evidence/agent-voice/verification.md)
- functional_evidence: [evidence/agent-voice/before.txt](../evidence/agent-voice/before.txt)
- functional_evidence: [evidence/agent-voice/component.txt](../evidence/agent-voice/component.txt)
- functional_evidence: [evidence/agent-voice/regression.txt](../evidence/agent-voice/regression.txt)
- functional_evidence: [evidence/agent-voice/analyze.txt](../evidence/agent-voice/analyze.txt)
- functional_evidence: [evidence/agent-voice/native.txt](../evidence/agent-voice/native.txt)
- functional_evidence: [evidence/agent-voice/build.txt](../evidence/agent-voice/build.txt)
- functional_evidence: [evidence/agent-voice/install.txt](../evidence/agent-voice/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_voice_design_test.dart](../../../test/features/agent_hub/agent_voice_design_test.dart)
- functional_evidence: [../../test/support/agent_voice_scenarios.dart](../../../test/support/agent_voice_scenarios.dart)
- functional_evidence: [../../integration_test/agent_voice_design_test.dart](../../../integration_test/agent_voice_design_test.dart)
- visual_evidence: [evidence/agent-voice/native-agent-voice-dismissed-1x.png](../evidence/agent-voice/native-agent-voice-dismissed-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-dismissed-2x.png](../evidence/agent-voice/native-agent-voice-dismissed-2x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-greeting-error-1x.png](../evidence/agent-voice/native-agent-voice-greeting-error-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-greeting-error-2x.png](../evidence/agent-voice/native-agent-voice-greeting-error-2x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-off-1x.png](../evidence/agent-voice/native-agent-voice-off-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-off-2x.png](../evidence/agent-voice/native-agent-voice-off-2x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-on-1x.png](../evidence/agent-voice/native-agent-voice-on-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-on-2x.png](../evidence/agent-voice/native-agent-voice-on-2x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-reply-error-1x.png](../evidence/agent-voice/native-agent-voice-reply-error-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-reply-error-2x.png](../evidence/agent-voice/native-agent-voice-reply-error-2x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-stream-error-1x.png](../evidence/agent-voice/native-agent-voice-stream-error-1x.png)
- visual_evidence: [evidence/agent-voice/native-agent-voice-stream-error-2x.png](../evidence/agent-voice/native-agent-voice-stream-error-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
