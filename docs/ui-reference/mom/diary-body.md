# 身体与精力

- ID：`mom/diary-body`
- 类型：dialog
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../mom/reference/diary-body.png)

原始路径：`me-agent-style-sync/diary-followup/02-diary-comfort.png`；SHA-256：`d37b7137f9735ef1621a2f880a49558789c621ac05fcc8e236c2b811c9837131`。


复核记录：按最新 me-diary.css 重建深棕页头、真实产后阶段/日期、完成计数和分类标记、奶油底、网格/分段选项与固定保存按钮。320/390/430、2x 字号、键盘、保存失败保留草稿、离开确认、互斥选择均有回归覆盖；134 项相关测试通过。模拟器跨三个分类填写并保存，首页正确回显。当前验收为各主面板，补充项展开和条件分支等历史细分状态另列。

- functional_evidence: [evidence/diary/verification.txt](../evidence/diary/verification.txt)
- functional_evidence: [evidence/diary/interaction-results.json](../evidence/diary/interaction-results.json)
- functional_evidence: [evidence/diary/diary-saved.xml](../evidence/diary/diary-saved.xml)
- visual_evidence: [evidence/diary/diary-body.png](../evidence/diary/diary-body.png)
- visual_evidence: [evidence/diary/diary-body-selected.png](../evidence/diary/diary-body-selected.png)
- visual_evidence: [evidence/diary/mom-after-diary.png](../evidence/diary/mom-after-diary.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
