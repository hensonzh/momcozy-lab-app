# 宝宝每日知识详情

- ID：`baby/knowledge`
- 类型：dialog
- 参考来源：original
- 设计源码：[DailyKnowledgeModal](../source/src/pages/UserApp.tsx#L456)，第 456–466 行
- Flutter：`lib/shared/widgets/knowledge_banner.dart`
- Route / 入口：`/baby`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../baby/reference/knowledge.png)

原始路径：`baby-me-style-sync/images/knowledge-article.png`；SHA-256：`b0bcc918678d0708461c6122165c4950af62aae90a457a3c8491a5a4189eb68b`。

[查看参考图](../baby/knowledge-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`6754e7e72e1f59f6047ad5f78858ec994491d46de27adb923c085181cd4ba6cd`。


复核记录：已对照 baby.css：紫色渐变页头、浅紫内容、序号/分隔线、来源链接和 Cozymate 入口。保留现有 CDC 等真实来源，因来源链接增加内容，原生最大高度扩为 700（仍受视口88%约束），正文滚动，CTA 固定；三宽/2x、关闭和问询回调已验证。 64 项相关回归通过；最终知识布局包含在后续 53 项页面回归中。原始设计新截图已登记 capture-manifest。

- functional_evidence: [evidence/modals/modal-check.txt](../evidence/modals/modal-check.txt)
- functional_evidence: [evidence/modals/latest-regression.txt](../evidence/modals/latest-regression.txt)
- functional_evidence: [evidence/modals/latest-analyze.txt](../evidence/modals/latest-analyze.txt)
- functional_evidence: [evidence/modals/build.json](../evidence/modals/build.json)
- visual_evidence: [evidence/modals/baby-knowledge-final.png](../evidence/modals/baby-knowledge-final.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
