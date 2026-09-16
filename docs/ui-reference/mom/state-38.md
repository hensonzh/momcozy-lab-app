# Me首页-预约已确认待填表

- ID：`mom/state-38`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_home_page.dart`
- Route / 入口：`/me`
- 触发：预约成功但未提交信息采集表
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-38.png)

原始路径：`me-ui-optimization/05-validation/images/38-Me首页-预约已确认待填表.png`；SHA-256：`4e8db4213eaeeed32d887ecb012142f4a2111fa4e422941903ede7bd17623558`。

[查看参考图](../mom/state-38-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`662af832da096e2982e83f63ce9f205a1d632ce033fbcbad76fca3f77cef701f`。

[查看参考图](../mom/state-38-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`589bf98784788683d2a304a4a6b612b8109f4736a2fca495e59911b10e870998`。


复核记录：重新核对 HomePage、MeExpertServiceCard 及当前浏览器截图。首页已购、待填表、已填表分别完成三宽/两倍字号渲染与回调验证；待填表接现有 intake 路由，返回刷新，预约按其时区显示，倒计时每秒更新。177 项相关回归通过。本地无有效预约，预约状态为 Flutter 仓储替身验证，不是后端端到端。

- functional_evidence: [evidence/home-service-states/verification.md](../evidence/home-service-states/verification.md)
- functional_evidence: [evidence/home-service-states/regression.log](../evidence/home-service-states/regression.log)
- functional_evidence: [evidence/home-service-states/final.log](../evidence/home-service-states/final.log)
- functional_evidence: [evidence/home-service-states/analyze.log](../evidence/home-service-states/analyze.log)
- functional_evidence: [../../test/modules/services/expert_home_states_test.dart](../../../test/modules/services/expert_home_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/home-service-intake-390.png](../../../test/goldens/design_system/home-service-intake-390.png)
- visual_evidence: [../../test/goldens/design_system/home-service-intake-320-2x.png](../../../test/goldens/design_system/home-service-intake-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/home-service-intake-430.png](../../../test/goldens/design_system/home-service-intake-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
