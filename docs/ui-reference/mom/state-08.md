# 今日状态-如厕与盆底展开

- ID：`mom/state-08`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：身体与精力 → 如厕与盆底
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-08.png)

原始路径：`me-ui-optimization/05-validation/images/08-今日状态-如厕与盆底展开.png`；SHA-256：`1b506fdd35bca3f01c149a41e4eeed09d337f05811d07672a6d28e22015c70b3`。


复核记录：如厕与盆底补齐可选提示，排尿与排便沿用暖色卡片；展开、保存及大字号滚动可达验证通过。 320/390/430 与 2x 字号均覆盖，77 项相关回归通过；模拟器检查不保存既有记录。

- functional_evidence: [evidence/diary-states/verification.md](../evidence/diary-states/verification.md)
- functional_evidence: [evidence/diary-states/regression.log](../evidence/diary-states/regression.log)
- functional_evidence: [../../test/modules/mom/mother_diary_states_test.dart](../../../test/modules/mom/mother_diary_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/diary-state-body-bowel-390.png](../../../test/goldens/design_system/diary-state-body-bowel-390.png)
- visual_evidence: [../../test/goldens/design_system/diary-state-body-bowel-320-2x.png](../../../test/goldens/design_system/diary-state-body-bowel-320-2x.png)
- visual_evidence: [evidence/diary-states/native-body-pelvic.png](../evidence/diary-states/native-body-pelvic.png)
- visual_evidence: [mom/diary-body-pelvic-full.png](../mom/diary-body-pelvic-full.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
