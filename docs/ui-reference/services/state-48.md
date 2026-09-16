# 咨询准备-当前州不支持

- ID：`services/state-48`
- 类型：state
- 参考来源：original
- 设计源码：[StartConsultModal](../source/src/pages/UserApp.tsx#L541)，第 541–554 行
- Flutter：`lib/modules/consultation/presentation/consultation_start_dialog.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：开始视频咨询 → 选择 Texas
- 状态：**Completed**

当前 StartConsultModal 为底部位置确认；原生地区能力由既有后端校验，不复制演示端仅支持 CA 的硬编码。未授权时进入本次服务的视频授权衍生弹窗；完整全局隐私页仍单列待复核。

[查看参考图](../services/reference/state-48.png)

原始路径：`me-ui-optimization/05-validation/images/48-咨询准备-当前州不支持.png`；SHA-256：`c8f25cab018a079a085feebc878d5073247caece72980ec675b74311d6f8b966`。

[查看参考图](../services/state-48-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`4bad11a132c182827df95d0ca2767b42a48f62dab3f141bf68b32dcf71458fdf`。


复核记录：已重新核对当前 StartConsultModal 与实际 Flutter 渲染，69 项咨询测试通过，三宽和 2x 字号、320×568 短屏验证。地区由既有 API 判断；视频授权仅处理本次服务 video scope，独立标为衍生设计。准备页背景、全局 PrivacyPage（state-50）和真实后端咨询 E2E 不计入完成范围。

- functional_evidence: [../../test/modules/consultation/consultation_start_test.dart](../../../test/modules/consultation/consultation_start_test.dart)
- functional_evidence: [evidence/preflight/regression.log](../evidence/preflight/regression.log)
- functional_evidence: [evidence/preflight/analyze.log](../evidence/preflight/analyze.log)
- functional_evidence: [evidence/preflight/verification.md](../evidence/preflight/verification.md)
- visual_evidence: [../../test/goldens/design_system/preflight-region-blocked-320.png](../../../test/goldens/design_system/preflight-region-blocked-320.png)
- visual_evidence: [../../test/goldens/design_system/preflight-region-blocked-390.png](../../../test/goldens/design_system/preflight-region-blocked-390.png)
- visual_evidence: [../../test/goldens/design_system/preflight-region-blocked-430.png](../../../test/goldens/design_system/preflight-region-blocked-430.png)
- visual_evidence: [evidence/preflight/verification.md](../evidence/preflight/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
