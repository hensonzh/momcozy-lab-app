# 今日状态-保存前校验

- ID：`mom/state-10`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_diary_editor.dart`
- Route / 入口：`/me`
- 触发：未填任何项 → 保存今天的记录
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-10.png)

原始路径：`me-ui-optimization/05-validation/images/10-今日状态-保存前校验.png`；SHA-256：`b2b6f97cc02c0e191981296ac7a03b27e6d13c7bab32751d8aa5788a9a5b562b`。


复核记录：空表点击保存显示与当前设计源码一致的提示并滚动至反馈，仓储零写入；原控制器非空限制保留。设计加载会强制重填示例数据，最新浏览器空表图不可取得，依据原稿与当前源码对照 Flutter 实际渲染验收。 320/390/430 与 2x 字号均覆盖，77 项相关回归通过；模拟器检查不保存既有记录。

- functional_evidence: [evidence/diary-states/verification.md](../evidence/diary-states/verification.md)
- functional_evidence: [evidence/diary-states/regression.log](../evidence/diary-states/regression.log)
- functional_evidence: [../../test/modules/mom/mother_diary_states_test.dart](../../../test/modules/mom/mother_diary_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/diary-state-empty-validation-390.png](../../../test/goldens/design_system/diary-state-empty-validation-390.png)
- visual_evidence: [../../test/goldens/design_system/diary-state-empty-validation-320-2x.png](../../../test/goldens/design_system/diary-state-empty-validation-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
