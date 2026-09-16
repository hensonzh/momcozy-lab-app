# 今日泌乳-新增泵奶

- ID：`mom/state-13`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/lactation_panel.dart`
- Route / 入口：`/me /me/lactation`
- 触发：今日泌乳 → 记录
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-13.png)

原始路径：`me-ui-optimization/05-validation/images/13-今日泌乳-新增泵奶.png`；SHA-256：`e1b58fcaaeb1c5b9db5c6bfb93958f2035b4880cf551e9019325e237eafb1506`。


复核记录：新增泵奶保留时间、侧别和可选奶量，真实 80 ml 保存验证通过。 六组屏宽/字号全流程通过；80 项妈妈模块与路由回归通过，原稿和最新 me-milk.css 已逐项对照。

- functional_evidence: [evidence/milk-states/verification.md](../evidence/milk-states/verification.md)
- functional_evidence: [evidence/milk-states/regression.log](../evidence/milk-states/regression.log)
- functional_evidence: [evidence/milk-states/final-visual.log](../evidence/milk-states/final-visual.log)
- functional_evidence: [../../test/modules/mom/lactation_states_test.dart](../../../test/modules/mom/lactation_states_test.dart)
- visual_evidence: [mom/milk-pump-full.png](../mom/milk-pump-full.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-pump-390.png](../../../test/goldens/design_system/milk-state-pump-390.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-pump-320-2x.png](../../../test/goldens/design_system/milk-state-pump-320-2x.png)
- visual_evidence: [evidence/milk-states/native-pump.png](../evidence/milk-states/native-pump.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
