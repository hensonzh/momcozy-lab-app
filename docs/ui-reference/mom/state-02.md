# 每日知识-详情弹窗

- ID：`mom/state-02`
- 类型：state
- 参考来源：original
- 设计源码：[DailyKnowledgeModal](../source/src/pages/UserApp.tsx#L456)，第 456–466 行
- Flutter：`lib/shared/widgets/knowledge_banner.dart`
- Route / 入口：`/me`
- 触发：点击顶部知识卡片
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-02.png)

原始路径：`me-ui-optimization/05-validation/images/02-每日知识-详情弹窗.png`；SHA-256：`61c8c3a3b326a834bc4194553f9d57df76ffda358f166b5bb6b007ca34a779b4`。


复核记录：2026-09-12: Current-source review and native Mia journey verified: article opens/closes, Ask navigates to Cozymate with the article title prefilled, and Me returns correctly. 17 targeted tests passed, including no automatic request on prefill. See knowledge-journey/verification.md for current visual references and service limitations; Agent home and conversation remain separately under review.

- functional_evidence: [evidence/knowledge-journey/verification.md](../evidence/knowledge-journey/verification.md)
- functional_evidence: [evidence/knowledge-journey/regression.log](../evidence/knowledge-journey/regression.log)
- functional_evidence: [evidence/knowledge-journey/prefill-test.log](../evidence/knowledge-journey/prefill-test.log)
- visual_evidence: [evidence/knowledge-journey/native-article.png](../evidence/knowledge-journey/native-article.png)
- visual_evidence: [evidence/knowledge-journey/native-agent-prefill.png](../evidence/knowledge-journey/native-agent-prefill.png)
- visual_evidence: [evidence/knowledge-journey/native-closed.png](../evidence/knowledge-journey/native-closed.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
