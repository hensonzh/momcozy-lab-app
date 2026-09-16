# 专家支持-喂养安心服务详情

- ID：`services/state-21`
- 类型：state
- 参考来源：original
- 设计源码：[ServiceDetailPage](../source/src/pages/UserApp.tsx#L3313)，第 3313–3453 行
- Flutter：`lib/modules/services/presentation/service_package_page.dart`
- Route / 入口：`/services/:packageId`
- 触发：服务列表 → 喂养安心 → 查看方案
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-21.png)

原始路径：`me-ui-optimization/05-validation/images/21-专家支持-喂养安心服务详情.png`；SHA-256：`091bb41166c8f79b2e83ba70f843aaec8fa8ca3abfc49b924e71c3bead538a1c`。


复核记录：喂养安心已对照最新设计和实际目录单独验收：320/390/430、2x 字号、四类详情的说明/价格/交付内容/返回与购买前确认均通过。补齐刷新错误、空目录、订单读取忙碌反馈并修复返回文字裁切。171 项相关回归及最后 9 项入口契约测试通过；本地仅查看确认页，未创建订单或支付。

- functional_evidence: [evidence/catalog-states/verification.md](../evidence/catalog-states/verification.md)
- functional_evidence: [evidence/catalog-states/regression.log](../evidence/catalog-states/regression.log)
- functional_evidence: [evidence/catalog-states/final-contract.log](../evidence/catalog-states/final-contract.log)
- functional_evidence: [../../test/modules/services/service_catalog_states_test.dart](../../../test/modules/services/service_catalog_states_test.dart)
- visual_evidence: [services/package-feeding-confidence-full.png](../services/package-feeding-confidence-full.png)
- visual_evidence: [evidence/catalog-states/native-feeding-confidence-top.png](../evidence/catalog-states/native-feeding-confidence-top.png)
- visual_evidence: [evidence/catalog-states/native-feeding-confidence-bottom.png](../evidence/catalog-states/native-feeding-confidence-bottom.png)
- visual_evidence: [evidence/catalog-states/native-feeding-confidence-confirm.png](../evidence/catalog-states/native-feeding-confidence-confirm.png)
- visual_evidence: [../../test/goldens/design_system/catalog-state-feeding-confidence-top-320-2x.png](../../../test/goldens/design_system/catalog-state-feeding-confidence-top-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/catalog-state-feeding-confidence-bottom-390.png](../../../test/goldens/design_system/catalog-state-feeding-confidence-bottom-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
