# 附件菜单

- ID：`agent/attachments`
- 类型：popover
- 参考来源：original
- 设计源码：[AgentPage](../source/src/pages/UserApp.tsx#L2191)，第 2191–2987 行
- Flutter：`lib/features/agent_hub/agent_hub_page.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../agent/reference/attachments.png)

原始路径：`me-agent-style-sync/diary-followup/10-agent-attachments.png`；SHA-256：`51e6286954c45e1c93f8eb21130be278051debee902d281d6a680b646b180c4b`。


复核记录：Aligned attachment menu, shared pending image/file metadata, horizontal scrolling, 44px remove targets and sent-file rows to the current design. 399 regression tests plus Android 1x/2x and normal local App menu verification pass. Menu anchors to the whole composer and releases keyboard focus without losing the draft. PDF-only/10 MB native capability is stated explicitly; no Word/spreadsheet capability or provider success is claimed. See evidence/agent-attachments/verification.md.

- functional_evidence: [evidence/agent-attachments/verification.md](../evidence/agent-attachments/verification.md)
- functional_evidence: [evidence/agent-attachments/source-hashes.json](../evidence/agent-attachments/source-hashes.json)
- functional_evidence: [evidence/agent-attachments/regression.txt](../evidence/agent-attachments/regression.txt)
- functional_evidence: [evidence/agent-attachments/keyboard.txt](../evidence/agent-attachments/keyboard.txt)
- functional_evidence: [evidence/agent-attachments/native.txt](../evidence/agent-attachments/native.txt)
- functional_evidence: [evidence/agent-attachments/analyze.txt](../evidence/agent-attachments/analyze.txt)
- functional_evidence: [evidence/agent-attachments/build.txt](../evidence/agent-attachments/build.txt)
- functional_evidence: [evidence/agent-attachments/install.txt](../evidence/agent-attachments/install.txt)
- visual_evidence: [evidence/agent-attachments/native-attachment-menu-1x.png](../evidence/agent-attachments/native-attachment-menu-1x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-menu-2x.png](../evidence/agent-attachments/native-attachment-menu-2x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-pending-image-1x.png](../evidence/agent-attachments/native-attachment-pending-image-1x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-pending-image-2x.png](../evidence/agent-attachments/native-attachment-pending-image-2x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-pending-file-1x.png](../evidence/agent-attachments/native-attachment-pending-file-1x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-pending-file-2x.png](../evidence/agent-attachments/native-attachment-pending-file-2x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-uploading-1x.png](../evidence/agent-attachments/native-attachment-uploading-1x.png)
- visual_evidence: [evidence/agent-attachments/native-attachment-uploading-2x.png](../evidence/agent-attachments/native-attachment-uploading-2x.png)
- visual_evidence: [evidence/agent-attachments/native-app-menu.png](../evidence/agent-attachments/native-app-menu.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
