# 预约确认后进入信息采集

- ID：`services/state-37`
- 类型：transition
- 参考来源：original
- 设计源码：[AppointmentPage](../source/src/pages/UserApp.tsx#L3542)，第 3542–3716 行
- Flutter：`lib/modules/services/presentation/booking_page.dart`
- Route / 入口：`/services/episodes/:episodeId/booking`
- 触发：确认预约时间 → 确认预约
- 状态：**Completed**

09-06 的预约成功弹窗已被当前 AppointmentPage.confirm 直接进入 IntakePage 取代；旧图保留追踪，最新状态见 state-37-viewport.png。本项只验收预约确认及进入采集的边界，采集页面单独验收。

[查看参考图](../services/reference/state-37.png)

原始路径：`me-ui-optimization/05-validation/images/37-预约流程-预约成功.png`；SHA-256：`5ae9818babaf372d3a2d34dc8b32ced70f57c0abad708b6c40601635fa46d176`。

[查看参考图](../services/state-37-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`2fd6292901a1a2fbb6f3a5a53af27e1a31cb1b8b1e4ade8d92c4b8e8d13d22ae`。


复核记录：2026-09-12 按当前 IntakePage 源码与新截图对齐；三屏宽及双倍字号、授权、首次提交、修改返回与原快照重试通过，服务模块 107 项回归通过。Flutter 受控仓库渲染证据已复核；本地无专家和预约，真实后端全链路尚未验证，详见 evidence/intake/verification.md。

- functional_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)
- functional_evidence: [evidence/intake/regression.log](../evidence/intake/regression.log)
- functional_evidence: [evidence/intake/analyze.log](../evidence/intake/analyze.log)
- visual_evidence: [../../test/goldens/design_system/intake-form-390.png](../../../test/goldens/design_system/intake-form-390.png)
- visual_evidence: [../../test/goldens/design_system/intake-form-320-2x.png](../../../test/goldens/design_system/intake-form-320-2x.png)
- visual_evidence: [evidence/intake/verification.md](../evidence/intake/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
