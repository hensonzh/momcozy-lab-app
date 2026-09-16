# 请求失败和重试

- ID：`agent/12-agent-error`
- 类型：state
- 参考来源：original
- 设计源码：[AgentPage](../source/src/pages/UserApp.tsx#L2191)，第 2191–2987 行
- Flutter：`lib/features/agent_hub/agent_hub_page.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../agent/reference/12-agent-error.png)

原始路径：`me-agent-style-sync/diary-followup/12-agent-error.png`；SHA-256：`bfb9a797692e3d99019a6ea4848f6bfce8ac874cd7f797b6d69abd38b4764c3d`。


复核记录：Reviewed against current AgentPage and CSS: distinct failure fallback, normal-colored retained reply, retry styling and safe visible-prompt draft restoration. 593 regression tests, 42 state goldens and Android 1x/2x (14 captures) pass. Native resume/terminal-run rules and capability gates preserved. This completes UI/client interaction verification using controlled protocol events, not remote model/TTS/history service validation; see evidence/agent-conversation/verification.md for limitations.

- functional_evidence: [evidence/agent-conversation/verification.md](../evidence/agent-conversation/verification.md)
- functional_evidence: [evidence/agent-conversation/regression.log](../evidence/agent-conversation/regression.log)
- functional_evidence: [evidence/agent-conversation/component-final.log](../evidence/agent-conversation/component-final.log)
- functional_evidence: [evidence/agent-conversation/analyze.log](../evidence/agent-conversation/analyze.log)
- functional_evidence: [evidence/agent-conversation/native.log](../evidence/agent-conversation/native.log)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-home-1x.png](../evidence/agent-conversation/native-agent-conversation-home-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-disconnected-empty-1x.png](../evidence/agent-conversation/native-agent-conversation-disconnected-empty-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-reply-1x.png](../evidence/agent-conversation/native-agent-conversation-reply-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-terminal-error-2x.png](../evidence/agent-conversation/native-agent-conversation-terminal-error-2x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-disconnected-partial-2x.png](../evidence/agent-conversation/native-agent-conversation-disconnected-partial-2x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-resumed-2x.png](../evidence/agent-conversation/native-agent-conversation-resumed-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
