# 购买流程-3D-Secure验证

- ID：`services/state-29`
- 类型：state
- 参考来源：original
- 设计源码：[ServiceDetailPage](../source/src/pages/UserApp.tsx#L3313)，第 3313–3453 行
- Flutter：`lib/modules/services/presentation/service_purchase_dialog.dart`
- Route / 入口：`/services/:packageId`
- 触发：测试验证卡 → 支付
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-29.png)

原始路径：`me-ui-optimization/05-validation/images/29-购买流程-3D-Secure验证.png`；SHA-256：`51238dd8086f76128265845cee58015f8cb4c48392ee06714be180c4b950ca03`。

[查看参考图](../services/state-29-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`549f3632fe0fec40362c8640f88337ddcc7c5e47373b4e909aec0dd3416dc15e`。


复核记录：按 ServiceDetailPage 及现行 CSS 重构底部购买/付款布局、银行卡分组及拒付/验证/成功提示，保留现有取消和预约协议。87 项服务模块回归、三屏宽/2x/键盘/不确定重试、Stripe 恢复通过，静态分析与本地 APK 构建通过。原生确认弹窗已核对；本地 catalog 无测试专家及支持州，故原生不能继续购买，付款分支使用受控仓库与实际 Flutter 渲染验收，未验证真实扣款。详见 purchase/verification.md。

- functional_evidence: [evidence/purchase/verification.md](../evidence/purchase/verification.md)
- functional_evidence: [evidence/purchase/regression.txt](../evidence/purchase/regression.txt)
- functional_evidence: [evidence/purchase/analyze.txt](../evidence/purchase/analyze.txt)
- functional_evidence: [evidence/purchase/local-catalog.json](../evidence/purchase/local-catalog.json)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-320.png](../../../test/goldens/design_system/purchase-challenge-320.png)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-390.png](../../../test/goldens/design_system/purchase-challenge-390.png)
- visual_evidence: [../../test/goldens/design_system/purchase-challenge-430.png](../../../test/goldens/design_system/purchase-challenge-430.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
