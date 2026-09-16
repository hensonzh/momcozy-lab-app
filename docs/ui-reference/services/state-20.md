# 专家支持-服务方案列表

- ID：`services/state-20`
- 类型：state
- 参考来源：original
- 设计源码：[ServicesPage](../source/src/pages/UserApp.tsx#L3275)，第 3275–3304 行
- Flutter：`lib/modules/services/presentation/service_catalog_page.dart`
- Route / 入口：`/services`
- 触发：专家支持 → 按需选择专家支持
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-20.png)

原始路径：`me-ui-optimization/05-validation/images/20-专家支持-服务方案列表.png`；SHA-256：`081d7b6d30eb92d079dc1837d4005d422b81ab78978ddddcbbb6744c8c1d9718`。


复核记录：服务方案列表已对照最新设计和实际目录单独验收：320/390/430、2x 字号、四类详情的说明/价格/交付内容/返回与购买前确认均通过。补齐刷新错误、空目录、订单读取忙碌反馈并修复返回文字裁切。171 项相关回归及最后 9 项入口契约测试通过；本地仅查看确认页，未创建订单或支付。

- functional_evidence: [evidence/catalog-states/verification.md](../evidence/catalog-states/verification.md)
- functional_evidence: [evidence/catalog-states/regression.log](../evidence/catalog-states/regression.log)
- functional_evidence: [evidence/catalog-states/final-contract.log](../evidence/catalog-states/final-contract.log)
- functional_evidence: [../../test/modules/services/service_catalog_states_test.dart](../../../test/modules/services/service_catalog_states_test.dart)
- visual_evidence: [services/catalog-current-full.png](../services/catalog-current-full.png)
- visual_evidence: [evidence/catalog-states/native-list-top.png](../evidence/catalog-states/native-list-top.png)
- visual_evidence: [evidence/catalog-states/native-list-lower.png](../evidence/catalog-states/native-list-lower.png)
- visual_evidence: [../../test/goldens/design_system/catalog-state-list-top-320-2x.png](../../../test/goldens/design_system/catalog-state-list-top-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
