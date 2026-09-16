# 消息操作

- ID：`agent/message-menu`
- 类型：popover
- 参考来源：derived-user-approved
- 设计源码：[消息操作（衍生设计）](../agent/derived/message-menu.md#L1)，第 1–22 行
- Flutter：`lib/features/agent_hub/agent_hub_page.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Approved derived popover: long press, secondary tap, accessibility action and keyboard entry. Copies the selected original text/Markdown, reuses existing retry conditions, excludes active generation and empty content. 508 related regression tests, 14 final component tests, 18 golden views and Android 1x/2x clipboard/reopen/retry/back verification pass. Live-test device event propagation is enabled only in the integration fixture to deliver Navigator pointer cancellation. No server API or retry policy changes; remote model availability remains a separate open item. Markdown override audit: preserve 16/1.65 reading style, 17/1.5 headings and underlined purple links; 544 related regression tests, 12 new goldens and Android 1x/2x passed. See evidence/agent-markdown/verification.md.

- functional_evidence: [evidence/agent-message-menu/verification.md](../evidence/agent-message-menu/verification.md)
- functional_evidence: [evidence/agent-message-menu/regression.txt](../evidence/agent-message-menu/regression.txt)
- functional_evidence: [evidence/agent-message-menu/component.txt](../evidence/agent-message-menu/component.txt)
- functional_evidence: [evidence/agent-message-menu/analyze.txt](../evidence/agent-message-menu/analyze.txt)
- functional_evidence: [evidence/agent-message-menu/native.txt](../evidence/agent-message-menu/native.txt)
- functional_evidence: [evidence/agent-message-menu/build.txt](../evidence/agent-message-menu/build.txt)
- functional_evidence: [evidence/agent-message-menu/install.txt](../evidence/agent-message-menu/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_message_menu_test.dart](../../../test/features/agent_hub/agent_message_menu_test.dart)
- functional_evidence: [../../test/features/agent_hub/agent_message_menu_design_test.dart](../../../test/features/agent_hub/agent_message_menu_design_test.dart)
- functional_evidence: [../../integration_test/agent_message_menu_design_test.dart](../../../integration_test/agent_message_menu_design_test.dart)
- functional_evidence: [evidence/agent-markdown/verification.md](../evidence/agent-markdown/verification.md)
- functional_evidence: [evidence/agent-markdown/regression.log](../evidence/agent-markdown/regression.log)
- functional_evidence: [../../test/features/agent_hub/agent_markdown_design_test.dart](../../../test/features/agent_hub/agent_markdown_design_test.dart)
- functional_evidence: [../../integration_test/agent_markdown_design_test.dart](../../../integration_test/agent_markdown_design_test.dart)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-user-1x.png](../evidence/agent-message-menu/native-agent-menu-user-1x.png)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-assistant-1x.png](../evidence/agent-message-menu/native-agent-menu-assistant-1x.png)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-retry-1x.png](../evidence/agent-message-menu/native-agent-menu-retry-1x.png)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-user-2x.png](../evidence/agent-message-menu/native-agent-menu-user-2x.png)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-assistant-2x.png](../evidence/agent-message-menu/native-agent-menu-assistant-2x.png)
- visual_evidence: [evidence/agent-message-menu/native-agent-menu-retry-2x.png](../evidence/agent-message-menu/native-agent-menu-retry-2x.png)
- visual_evidence: [evidence/agent-markdown/design-markdown.png](../evidence/agent-markdown/design-markdown.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-top-2x.png](../evidence/agent-markdown/native-agent-markdown-top-2x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-link-1x.png](../evidence/agent-markdown/native-agent-markdown-link-1x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-link-2x.png](../evidence/agent-markdown/native-agent-markdown-link-2x.png)
- visual_evidence: [evidence/agent-markdown/native-agent-markdown-top-1x.png](../evidence/agent-markdown/native-agent-markdown-top-1x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
