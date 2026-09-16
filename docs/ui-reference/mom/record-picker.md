# 记录入口选择

- ID：`mom/record-picker`
- 类型：dialog
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_home_page.dart`
- Route / 入口：`/me`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../mom/reference/record-picker.png)

原始路径：`me-agent-style-sync/diary-followup/03-record-chooser.png`；SHA-256：`e1cad3d0c13eb4da124930babab217297fbd19a2984ee01ddcb184e99fe057ba`。


复核记录：按 me-agent.css 记录选择稿实现 340 最大宽、22 圆角、暖色按钮、标题与 44 关闭控件；小屏/2x 可滚动。模拟器两个入口均打开既有编辑器，测试草稿已放弃，无额外记录。 64 项相关回归通过；最终知识布局包含在后续 53 项页面回归中。原始设计新截图已登记 capture-manifest。

- functional_evidence: [evidence/modals/modal-check.txt](../evidence/modals/modal-check.txt)
- functional_evidence: [evidence/modals/latest-regression.txt](../evidence/modals/latest-regression.txt)
- functional_evidence: [evidence/modals/latest-analyze.txt](../evidence/modals/latest-analyze.txt)
- functional_evidence: [evidence/modals/build.json](../evidence/modals/build.json)
- visual_evidence: [evidence/modals/record-picker-native.png](../evidence/modals/record-picker-native.png)
- visual_evidence: [evidence/modals/record-picker-diary.png](../evidence/modals/record-picker-diary.png)
- visual_evidence: [evidence/modals/record-picker-milk.png](../evidence/modals/record-picker-milk.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
