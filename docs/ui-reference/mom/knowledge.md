# 每日知识详情

- ID：`mom/knowledge`
- 类型：dialog
- 参考来源：original
- 设计源码：[DailyKnowledgeModal](../source/src/pages/UserApp.tsx#L456)，第 456–466 行
- Flutter：`lib/shared/widgets/knowledge_banner.dart`
- Route / 入口：`/me`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../mom/knowledge-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`5b916b7936409bb29fddc3e7c3abd8ad99175085f3c08d8c8e93cbe8770051b2`。


复核记录：已对照当前 DailyKnowledgeModal：底部浅色弹窗、序号/分隔线、正文层级、说明与带头像的 Cozymate 按钮。模拟器点击后跳转 Agent 并预填当前文章标题；没有自动发送新请求。 64 项相关回归通过；最终知识布局包含在后续 53 项页面回归中。原始设计新截图已登记 capture-manifest。

- functional_evidence: [evidence/modals/modal-check.txt](../evidence/modals/modal-check.txt)
- functional_evidence: [evidence/modals/latest-regression.txt](../evidence/modals/latest-regression.txt)
- functional_evidence: [evidence/modals/latest-analyze.txt](../evidence/modals/latest-analyze.txt)
- functional_evidence: [evidence/modals/build.json](../evidence/modals/build.json)
- visual_evidence: [evidence/modals/mom-knowledge-native.png](../evidence/modals/mom-knowledge-native.png)
- visual_evidence: [evidence/modals/knowledge-agent-native.png](../evidence/modals/knowledge-agent-native.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
