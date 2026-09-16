# 续购

- ID：`services/renew`
- 类型：page
- 参考来源：original
- 设计源码：[RenewPage](../source/src/pages/UserApp.tsx#L3899)，第 3899–3905 行
- Flutter：`lib/modules/services/presentation/service_renew_page.dart`
- Route / 入口：`/services/renew /services/episodes/:episodeId/renew`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/renew-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`0cabfae4aab03286ebdf49298851c3ac7ea2719667e257a4c59e3eca20c641dd`。

[查看参考图](../services/renew-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`f06679a09dc840b89050648ce1593291ae2d7080cf5c68aa6a957d6e3b1f1797`。


复核记录：新增独立继续支持页面及两个路由，已结束服务时间线入口已接通；现有订单继续付款、ongoing 服务进入原服务、选择复用既有真实购买控制器。价格、天数和次数来自 API。10 项续购测试及 1 项时间线入口测试；整合 305 项通过。未进行真实扣款，详见 evidence/renew/verification.md。

- functional_evidence: [../../test/modules/services/service_renew_test.dart](../../../test/modules/services/service_renew_test.dart)
- functional_evidence: [../../test/modules/services/service_progress_test.dart](../../../test/modules/services/service_progress_test.dart)
- functional_evidence: [evidence/renew/regression.log](../evidence/renew/regression.log)
- functional_evidence: [evidence/renew/focused.log](../evidence/renew/focused.log)
- functional_evidence: [evidence/renew/analyze.log](../evidence/renew/analyze.log)
- functional_evidence: [evidence/renew/verification.md](../evidence/renew/verification.md)
- functional_evidence: [evidence/renew/build.json](../evidence/renew/build.json)
- visual_evidence: [services/renew-full.png](../services/renew-full.png)
- visual_evidence: [services/renew-viewport.png](../services/renew-viewport.png)
- visual_evidence: [../../test/goldens/design_system/renew-list-390.png](../../../test/goldens/design_system/renew-list-390.png)
- visual_evidence: [../../test/goldens/design_system/renew-selected-390.png](../../../test/goldens/design_system/renew-selected-390.png)
- visual_evidence: [../../test/goldens/design_system/renew-list-320-2x.png](../../../test/goldens/design_system/renew-list-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/renew-order-error-390.png](../../../test/goldens/design_system/renew-order-error-390.png)
- visual_evidence: [../../test/goldens/design_system/progress-completed-renewal-390.png](../../../test/goldens/design_system/progress-completed-renewal-390.png)
- visual_evidence: [evidence/renew/native-list.png](../evidence/renew/native-list.png)
- visual_evidence: [evidence/renew/native-eligibility.png](../evidence/renew/native-eligibility.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
