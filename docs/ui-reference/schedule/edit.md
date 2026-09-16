# 编辑与删除个人日程

- ID：`schedule/edit`
- 类型：dialog
- 参考来源：original
- 设计源码：[PlanPage](../source/src/pages/UserApp.tsx#L3042)，第 3042–3262 行
- Flutter：`lib/modules/schedule/presentation/schedule_page.dart`
- Route / 入口：`/schedule`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../schedule/edit-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`1d6cd80143b7d6ccad94089d6e53d2defd817eb4e3a07173eae473af0deebc8b`。


复核记录：按 PlanPage 原稿逐页复核；三宽/双倍字号与矮屏键盘回归通过，个人日程真实本地新增编辑删除已闭环。专业任务菜单及版本写入以受控仓库验证，测试账号没有真实已购任务。详见 schedule-forms/verification.md。

- functional_evidence: [evidence/schedule-forms/verification.md](../evidence/schedule-forms/verification.md)
- functional_evidence: [evidence/schedule-forms/regression.txt](../evidence/schedule-forms/regression.txt)
- functional_evidence: [evidence/schedule-forms/analyze.txt](../evidence/schedule-forms/analyze.txt)
- functional_evidence: [evidence/schedule-forms/build.json](../evidence/schedule-forms/build.json)
- visual_evidence: [evidence/schedule-forms/edit.png](../evidence/schedule-forms/edit.png)
- visual_evidence: [evidence/schedule-forms/updated.png](../evidence/schedule-forms/updated.png)
- visual_evidence: [evidence/schedule-forms/delete.png](../evidence/schedule-forms/delete.png)
- visual_evidence: [evidence/schedule-forms/retained.png](../evidence/schedule-forms/retained.png)
- visual_evidence: [evidence/schedule-forms/deleted.png](../evidence/schedule-forms/deleted.png)
- visual_evidence: [../../test/goldens/design_system/schedule-edit-390.png](../../../test/goldens/design_system/schedule-edit-390.png)
- visual_evidence: [../../test/goldens/design_system/schedule-delete-390.png](../../../test/goldens/design_system/schedule-delete-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
