# 本次服务的视频咨询授权

- ID：`services/video-consent`
- 类型：dialog
- 参考来源：derived-user-approved
- 设计源码：[本次服务的视频咨询授权（衍生设计）](../services/derived/video-consent.md#L1)，第 1–22 行
- Flutter：`lib/modules/consultation/presentation/consultation_start_dialog.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：已重新核对当前 StartConsultModal 与实际 Flutter 渲染，69 项咨询测试通过，三宽和 2x 字号、320×568 短屏验证。地区由既有 API 判断；视频授权仅处理本次服务 video scope，独立标为衍生设计。准备页背景、全局 PrivacyPage（state-50）和真实后端咨询 E2E 不计入完成范围。

- functional_evidence: [../../test/modules/consultation/consultation_start_test.dart](../../../test/modules/consultation/consultation_start_test.dart)
- functional_evidence: [evidence/preflight/regression.log](../evidence/preflight/regression.log)
- functional_evidence: [evidence/preflight/analyze.log](../evidence/preflight/analyze.log)
- functional_evidence: [evidence/preflight/verification.md](../evidence/preflight/verification.md)
- visual_evidence: [../../test/goldens/design_system/preflight-consent-320.png](../../../test/goldens/design_system/preflight-consent-320.png)
- visual_evidence: [../../test/goldens/design_system/preflight-consent-390.png](../../../test/goldens/design_system/preflight-consent-390.png)
- visual_evidence: [../../test/goldens/design_system/preflight-consent-430.png](../../../test/goldens/design_system/preflight-consent-430.png)
- visual_evidence: [evidence/preflight/verification.md](../evidence/preflight/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
