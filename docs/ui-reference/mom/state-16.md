# 今日泌乳-输入校验失败

- ID：`mom/state-16`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/lactation_panel.dart`
- Route / 入口：`/me /me/lactation`
- 触发：输入超范围奶量 → 保存
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-16.png)

原始路径：`me-ui-optimization/05-validation/images/16-今日泌乳-输入校验失败.png`；SHA-256：`083d00bf06c4bbdedda8639520fe0514f8d481ad7be208d2d838567e3270d551`。


复核记录：非法输入无请求，校验提示自动滚动可见；模拟器 3000 ml 被拦截后修改成功，受控仓储验证 241 分钟被拦截。 六组屏宽/字号全流程通过；80 项妈妈模块与路由回归通过，原稿和最新 me-milk.css 已逐项对照。

- functional_evidence: [evidence/milk-states/verification.md](../evidence/milk-states/verification.md)
- functional_evidence: [evidence/milk-states/regression.log](../evidence/milk-states/regression.log)
- functional_evidence: [evidence/milk-states/final-visual.log](../evidence/milk-states/final-visual.log)
- functional_evidence: [../../test/modules/mom/lactation_states_test.dart](../../../test/modules/mom/lactation_states_test.dart)
- visual_evidence: [mom/milk-validation-full.png](../mom/milk-validation-full.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-validation-390.png](../../../test/goldens/design_system/milk-state-validation-390.png)
- visual_evidence: [../../test/goldens/design_system/milk-state-validation-320-2x.png](../../../test/goldens/design_system/milk-state-validation-320-2x.png)
- visual_evidence: [evidence/milk-states/native-validation.png](../evidence/milk-states/native-validation.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
