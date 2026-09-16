# 今日泌乳-新增亲喂

- ID：`mom/state-14`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/lactation_panel.dart`
- Route / 入口：`/me /me/lactation`
- 触发：新增记录 → 亲喂
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-14.png)

原始路径：`me-ui-optimization/05-validation/images/14-今日泌乳-新增亲喂.png`；SHA-256：`56e6074f560dd2aeb821562655b0e1628270e84a0d623047ddfe9dd54fa7d1bc`。


复核记录：亲喂独立时长字段，切换方法不携带泵奶数值；12 分钟及备注保存通过受控仓储验证。 六组屏宽/字号全流程通过；80 项妈妈模块与路由回归通过，原稿和最新 me-milk.css 已逐项对照。

- functional_evidence: [evidence/milk-states/verification.md](../evidence/milk-states/verification.md)
- functional_evidence: [evidence/milk-states/regression.log](../evidence/milk-states/regression.log)
- functional_evidence: [evidence/milk-states/final-visual.log](../evidence/milk-states/final-visual.log)
- functional_evidence: [../../test/modules/mom/lactation_states_test.dart](../../../test/modules/mom/lactation_states_test.dart)
- visual_evidence: [mom/milk-nurse-full.png](../mom/milk-nurse-full.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-nurse-390.png](../../../test/goldens/design_system/milk-state-nurse-390.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-nurse-320-2x.png](../../../test/goldens/design_system/milk-state-nurse-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
