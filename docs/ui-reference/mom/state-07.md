# 今日状态-身体不适条件项

- ID：`mom/state-07`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：身体与精力 → 选择不适部位
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-07.png)

原始路径：`me-ui-optimization/05-validation/images/07-今日状态-身体不适条件项.png`；SHA-256：`4352ecc89ce72f58d3c37613c90ddb3125f64d8eca001906b0544aae943c25e4`。


复核记录：不适部位显示程度和影响，影响使用当前设计的卡片网格；取消所有部位后清理程度和影响，保留如厕字段。 320/390/430 与 2x 字号均覆盖，77 项相关回归通过；模拟器检查不保存既有记录。

- functional_evidence: [evidence/diary-states/verification.md](../evidence/diary-states/verification.md)
- functional_evidence: [evidence/diary-states/regression.log](../evidence/diary-states/regression.log)
- functional_evidence: [../../test/modules/mom/mother_diary_states_test.dart](../../../test/modules/mom/mother_diary_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/diary-state-body-discomfort-390.png](../../../test/goldens/design_system/diary-state-body-discomfort-390.png)
- visual_evidence: [../../test/goldens/design_system/diary-state-body-discomfort-320-2x.png](../../../test/goldens/design_system/diary-state-body-discomfort-320-2x.png)
- visual_evidence: [evidence/diary-states/native-body-conditional.png](../evidence/diary-states/native-body-conditional.png)
- visual_evidence: [mom/diary-body-conditional-full.png](../mom/diary-body-conditional-full.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
