# 购买流程-购买前确认

- ID：`services/state-25`
- 类型：state
- 参考来源：original
- 设计源码：[ServiceDetailPage](../source/src/pages/UserApp.tsx#L3313)，第 3313–3453 行
- Flutter：`lib/modules/services/presentation/service_purchase_dialog.dart`
- Route / 入口：`/services/:packageId`
- 触发：服务详情 → 购买
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-25.png)

原始路径：`me-ui-optimization/05-validation/images/25-购买流程-购买前确认.png`；SHA-256：`30f2f1685caa650fa3326e480a5e2d0075b9aafe7737beabf0fc5882d779469a`。

[查看参考图](../services/state-25-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`1d84b0c92e47b920ddeec1de4cc221c3712954fd6cdf858751260f6a1322f618`。


复核记录：按 ServiceDetailPage 及现行 CSS 重构底部购买/付款布局、银行卡分组及拒付/验证/成功提示，保留现有取消和预约协议。87 项服务模块回归、三屏宽/2x/键盘/不确定重试、Stripe 恢复通过，静态分析与本地 APK 构建通过。原生确认弹窗已核对；本地 catalog 无测试专家及支持州，故原生不能继续购买，付款分支使用受控仓库与实际 Flutter 渲染验收，未验证真实扣款。详见 purchase/verification.md。

- functional_evidence: [evidence/purchase/verification.md](../evidence/purchase/verification.md)
- functional_evidence: [evidence/purchase/regression.txt](../evidence/purchase/regression.txt)
- functional_evidence: [evidence/purchase/analyze.txt](../evidence/purchase/analyze.txt)
- functional_evidence: [evidence/purchase/local-catalog.json](../evidence/purchase/local-catalog.json)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-320.png](../../../test/goldens/design_system/purchase-eligibility-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-390.png](../../../test/goldens/design_system/purchase-eligibility-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-eligibility-430.png](../../../test/goldens/design_system/purchase-eligibility-430.png)
- visual_evidence: [evidence/purchase/native-eligibility.png](../evidence/purchase/native-eligibility.png)
- visual_evidence: [evidence/purchase/native-unavailable.png](../evidence/purchase/native-unavailable.png)
- visual_evidence: [evidence/purchase/native-ca-unavailable.png](../evidence/purchase/native-ca-unavailable.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
