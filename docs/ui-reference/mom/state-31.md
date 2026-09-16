# Me首页-服务已购买待预约

- ID：`mom/state-31`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_home_page.dart`
- Route / 入口：`/me`
- 触发：购买成功后的 Me 首页状态
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-31.png)

原始路径：`me-ui-optimization/05-validation/images/31-Me首页-服务已购买待预约.png`；SHA-256：`24cedcfd928fc8af20fcb3e6b00bc5552faab081bfa128b8dbb5dd141d3911bd`。

[查看参考图](../mom/state-31-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`708fc5b2a982e8259c6b7be48a375d74fee7ed3afc812c9c3ee643a36083f772`。

[查看参考图](../mom/state-31-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`ad7663fbdc7caa164312e5f167951a2257b1af5d3023ba68c3d2c808d744692f`。


复核记录：重新核对 HomePage、MeExpertServiceCard 及当前浏览器截图。首页已购、待填表、已填表分别完成三宽/两倍字号渲染与回调验证；待填表接现有 intake 路由，返回刷新，预约按其时区显示，倒计时每秒更新。177 项相关回归通过。本地无有效预约，预约状态为 Flutter 仓储替身验证，不是后端端到端。

- functional_evidence: [evidence/home-service-states/verification.md](../evidence/home-service-states/verification.md)
- functional_evidence: [evidence/home-service-states/regression.log](../evidence/home-service-states/regression.log)
- functional_evidence: [evidence/home-service-states/final.log](../evidence/home-service-states/final.log)
- functional_evidence: [evidence/home-service-states/analyze.log](../evidence/home-service-states/analyze.log)
- functional_evidence: [../../test/modules/services/expert_home_states_test.dart](../../../test/modules/services/expert_home_states_test.dart)
- visual_evidence: [../../test/goldens/design_system/home-service-paid-390.png](../../../test/goldens/design_system/home-service-paid-390.png)
- visual_evidence: [../../test/goldens/design_system/home-service-paid-320-2x.png](../../../test/goldens/design_system/home-service-paid-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/home-service-paid-430.png](../../../test/goldens/design_system/home-service-paid-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
