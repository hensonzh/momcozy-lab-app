# 适用性和购买支付

- ID：`services/purchase`
- 类型：dialog
- 参考来源：original
- 设计源码：[ServiceDetailPage](../source/src/pages/UserApp.tsx#L3313)，第 3313–3453 行
- Flutter：`lib/modules/services/presentation/service_purchase_dialog.dart`
- Route / 入口：`/services/:packageId`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**




复核记录：按 ServiceDetailPage 及现行 CSS 重构底部购买/付款布局、银行卡分组及拒付/验证/成功提示，保留现有取消和预约协议。87 项服务模块回归、三屏宽/2x/键盘/不确定重试、Stripe 恢复通过，静态分析与本地 APK 构建通过。原生确认弹窗已核对；本地 catalog 无测试专家及支持州，故原生不能继续购买，付款分支使用受控仓库与实际 Flutter 渲染验收，未验证真实扣款。详见 purchase/verification.md。

- functional_evidence: [evidence/purchase/verification.md](../evidence/purchase/verification.md)
- functional_evidence: [evidence/purchase/regression.txt](../evidence/purchase/regression.txt)
- functional_evidence: [evidence/purchase/analyze.txt](../evidence/purchase/analyze.txt)
- functional_evidence: [evidence/purchase/local-catalog.json](../evidence/purchase/local-catalog.json)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-320.png](../../../test/goldens/design_system/purchase-eligibility-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-390.png](../../../test/goldens/design_system/purchase-eligibility-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-430.png](../../../test/goldens/design_system/purchase-eligibility-430.png)
- visual_evidence: [../../test/goldens/design_system/purchase-unavailable-320.png](../../../test/goldens/design_system/purchase-unavailable-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-unavailable-390.png](../../../test/goldens/design_system/purchase-unavailable-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-unavailable-430.png](../../../test/goldens/design_system/purchase-unavailable-430.png)
- visual_evidence: [../../test/goldens/design_system/purchase-payment-320.png](../../../test/goldens/design_system/purchase-payment-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-payment-390.png](../../../test/goldens/design_system/purchase-payment-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-payment-430.png](../../../test/goldens/design_system/purchase-payment-430.png)
- visual_evidence: [../../test/goldens/design_system/purchase-failed-320.png](../../../test/goldens/design_system/purchase-failed-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-failed-390.png](../../../test/goldens/design_system/purchase-failed-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-failed-430.png](../../../test/goldens/design_system/purchase-failed-430.png)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-320.png](../../../test/goldens/design_system/purchase-challenge-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-390.png](../../../test/goldens/design_system/purchase-challenge-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-430.png](../../../test/goldens/design_system/purchase-challenge-430.png)
- visual_evidence: [../../test/goldens/design_system/purchase-success-320.png](../../../test/goldens/design_system/purchase-success-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-success-390.png](../../../test/goldens/design_system/purchase-success-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-success-430.png](../../../test/goldens/design_system/purchase-success-430.png)
- visual_evidence: [evidence/purchase/native-eligibility.png](../evidence/purchase/native-eligibility.png)
- visual_evidence: [evidence/purchase/native-unavailable.png](../evidence/purchase/native-unavailable.png)
- visual_evidence: [evidence/purchase/native-ca-unavailable.png](../evidence/purchase/native-ca-unavailable.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
