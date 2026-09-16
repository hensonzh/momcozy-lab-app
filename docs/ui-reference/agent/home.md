# Cozymate 会话

- ID：`agent/home`
- 类型：page
- 参考来源：original
- 设计源码：[AgentPage](../source/src/pages/UserApp.tsx#L2191)，第 2191–2987 行
- Flutter：`lib/features/agent_hub/agent_hub_page.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../agent/reference/home.png)

原始路径：`me-agent-style-sync/diary-followup/09-agent-home.png`；SHA-256：`7650b3e98faaca40db6d43457a472fda6498c49a7ae863d9373c2cf5cdb7ecac`。

[查看参考图](../agent/home-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`70f56163913585fc95cc5c4e9d5ba1d164bd2685ca2f80a6bf5516ee350fbc23`。

[查看参考图](../agent/home-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`654e5a481436106a74a6563f979f44259407e9a244ac214358b5419810aacf22`。


复核记录：Reviewed against current AgentPage and CSS: distinct failure fallback, normal-colored retained reply, retry styling and safe visible-prompt draft restoration. 593 regression tests, 42 state goldens and Android 1x/2x (14 captures) pass. Native resume/terminal-run rules and capability gates preserved. This completes UI/client interaction verification using controlled protocol events, not remote model/TTS/history service validation; see evidence/agent-conversation/verification.md for limitations. Markdown override audit: preserve 16/1.65 reading style, 17/1.5 headings and underlined purple links; 544 related regression tests, 12 new goldens and Android 1x/2x passed. See evidence/agent-markdown/verification.md.

- functional_evidence: [evidence/theme-motion/verification.md](../evidence/theme-motion/verification.md)
- functional_evidence: [evidence/theme-motion/regression.txt](../evidence/theme-motion/regression.txt)
- functional_evidence: [evidence/theme-motion/native.txt](../evidence/theme-motion/native.txt)
- functional_evidence: [evidence/theme-motion/analyze.txt](../evidence/theme-motion/analyze.txt)
- functional_evidence: [evidence/agent-conversation/verification.md](../evidence/agent-conversation/verification.md)
- functional_evidence: [evidence/agent-conversation/regression.log](../evidence/agent-conversation/regression.log)
- functional_evidence: [evidence/agent-conversation/component-final.log](../evidence/agent-conversation/component-final.log)
- functional_evidence: [evidence/agent-conversation/analyze.log](../evidence/agent-conversation/analyze.log)
- functional_evidence: [evidence/agent-conversation/native.log](../evidence/agent-conversation/native.log)
- functional_evidence: [evidence/agent-markdown/verification.md](../evidence/agent-markdown/verification.md)
- functional_evidence: [evidence/agent-markdown/regression.log](../evidence/agent-markdown/regression.log)
- functional_evidence: [../../test/features/agent_hub/agent_markdown_design_test.dart](../../../test/features/agent_hub/agent_markdown_design_test.dart)
- functional_evidence: [../../integration_test/agent_markdown_design_test.dart](../../../integration_test/agent_markdown_design_test.dart)
- visual_evidence: [evidence/theme-motion/native-agent-reduced-thinking-2x.png](../evidence/theme-motion/native-agent-reduced-thinking-2x.png)
- visual_evidence: [evidence/theme-motion/native-agent-reduced-status-2x.png](../evidence/theme-motion/native-agent-reduced-status-2x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-home-1x.png](../evidence/agent-conversation/native-agent-conversation-home-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-disconnected-empty-1x.png](../evidence/agent-conversation/native-agent-conversation-disconnected-empty-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-reply-1x.png](../evidence/agent-conversation/native-agent-conversation-reply-1x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-terminal-error-2x.png](../evidence/agent-conversation/native-agent-conversation-terminal-error-2x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-disconnected-partial-2x.png](../evidence/agent-conversation/native-agent-conversation-disconnected-partial-2x.png)
- visual_evidence: [evidence/agent-conversation/native-agent-conversation-resumed-2x.png](../evidence/agent-conversation/native-agent-conversation-resumed-2x.png)
- visual_evidence: [evidence/agent-markdown/design-markdown.png](../evidence/agent-markdown/design-markdown.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-top-2x.png](../evidence/agent-markdown/native-agent-markdown-top-2x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-link-1x.png](../evidence/agent-markdown/native-agent-markdown-link-1x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-link-2x.png](../evidence/agent-markdown/native-agent-markdown-link-2x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-top-1x.png](../evidence/agent-markdown/native-agent-markdown-top-1x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
