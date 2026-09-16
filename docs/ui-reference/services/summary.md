# 咨询总结

- ID：`services/summary`
- 类型：page
- 参考来源：original
- 设计源码：[SummaryPage](../source/src/pages/UserApp.tsx#L3810)，第 3810–3865 行
- Flutter：`lib/modules/services/presentation/consultation_summary_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/summary`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/summary-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`c16711db6dbe3eb4a5bdd942249f81913b1894916c192657bf68dffd819dea53`。

[查看参考图](../services/summary-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`be1de521b0ab6bf410fa2101dc4a39ce0016783b1bf1b7b63f5dfb47db90b8d0`。


复核记录：重新读取 SummaryPage 当前源码、捕获完整长图并核对 Flutter 三宽和 2x 字号；279 项整合回归通过，加载、未发布、读取失败、任务反馈不确定重试与方案替换均验证。任务详情按批准的衍生规范补齐。仅展示用户已发布内容，保留原 API；本地没有真实发布咨询，未声称临床发布 E2E。

- functional_evidence: [../../test/modules/services/consultation_summary_test.dart](../../../test/modules/services/consultation_summary_test.dart)
- functional_evidence: [evidence/summary/regression.log](../evidence/summary/regression.log)
- functional_evidence: [evidence/summary/analyze.log](../evidence/summary/analyze.log)
- functional_evidence: [evidence/summary/verification.md](../evidence/summary/verification.md)
- visual_evidence: [../../test/goldens/design_system/summary-published-320.png](../../../test/goldens/design_system/summary-published-320.png)
- visual_evidence: [../../test/goldens/design_system/summary-published-390.png](../../../test/goldens/design_system/summary-published-390.png)
- visual_evidence: [../../test/goldens/design_system/summary-published-430.png](../../../test/goldens/design_system/summary-published-430.png)
- visual_evidence: [../../test/goldens/design_system/summary-published-320-2x.png](../../../test/goldens/design_system/summary-published-320-2x.png)
- visual_evidence: [evidence/summary/verification.md](../evidence/summary/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
