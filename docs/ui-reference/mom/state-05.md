# 今日状态-休息补充展开

- ID：`mom/state-05`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：休息 → 补充休息情况
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-05.png)

原始路径：`me-ui-optimization/05-validation/images/05-今日状态-休息补充展开.png`；SHA-256：`3e7ce6fb462f47d2fac85a90726cf8cee2cf5f05c8071c03fe0864af6ac55eae`。


复核记录：休息补充含可选／已填写提示，再次入睡分段选项和响应式休息网格；展开折叠、单选、多选与具体字段保存通过。 320/390/430 与 2x 字号均覆盖，77 项相关回归通过；模拟器检查不保存既有记录。

- functional_evidence: [evidence/diary-states/verification.md](../evidence/diary-states/verification.md)
- functional_evidence: [evidence/diary-states/regression.log](../evidence/diary-states/regression.log)
- functional_evidence: [../../test/modules/mom/mother_diary_states_test.dart](../../../test/modules/mom/mother_diary_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/diary-state-rest-day-390.png](../../../test/goldens/design_system/diary-state-rest-day-390.png)
- visual_evidence: [../../test/goldens/design_system/diary-state-rest-day-320-2x.png](../../../test/goldens/design_system/diary-state-rest-day-320-2x.png)
- visual_evidence: [evidence/diary-states/native-rest-expanded.png](../evidence/diary-states/native-rest-expanded.png)
- visual_evidence: [mom/diary-rest-expanded-full.png](../mom/diary-rest-expanded-full.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
