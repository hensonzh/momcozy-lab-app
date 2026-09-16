# 今日状态-身体与精力

- ID：`mom/state-06`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：今日状态 → 身体与精力
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-06.png)

原始路径：`me-ui-optimization/05-validation/images/06-今日状态-身体与精力.png`；SHA-256：`46b67f03ca83a8e93e0bd058d17113bdaf4cb37d71ac08346e91bcd7f76f358e`。


复核记录：已独立重新查看 2026-09-06 历史状态稿；该状态的功能语义继续保留，视觉按 2026-09-08 me-agent.css / me-diary.css 更新，不保留旧版布局。身体主面板、区域选择及跨分类保存通过；条件项另列。 证据复用已覆盖该明确状态的原生截图与测试，不从父页面批量推定其它未验证状态。

- functional_evidence: [evidence/diary/verification.txt](../evidence/diary/verification.txt)
- functional_evidence: [evidence/diary/interaction-results.json](../evidence/diary/interaction-results.json)
- functional_evidence: [evidence/diary/diary-saved.xml](../evidence/diary/diary-saved.xml)
- visual_evidence: [evidence/diary/diary-body.png](../evidence/diary/diary-body.png)
- visual_evidence: [evidence/diary/diary-body-selected.png](../evidence/diary/diary-body-selected.png)
- visual_evidence: [evidence/diary/mom-after-diary.png](../evidence/diary/mom-after-diary.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
