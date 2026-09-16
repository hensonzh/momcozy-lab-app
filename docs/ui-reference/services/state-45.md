# 咨询准备-设备检测失败

- ID：`services/state-45`
- 类型：state
- 参考来源：original
- 设计源码：[DeviceCheckModal](../source/src/pages/UserApp.tsx#L502)，第 502–541 行
- Flutter：`lib/modules/consultation/presentation/device_check_dialog.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：设备检测 → 开始检测（无权限）
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-45.png)

原始路径：`me-ui-optimization/05-validation/images/45-咨询准备-设备检测失败.png`；SHA-256：`33ff70200fd48301fd1613be95d234ac28628fe2b0097f4b7f6fbcb863d4adf1`。

[查看参考图](../services/state-45-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`c30cef7ad4cd38000d0ee797d38aefee4419ef23d8ccf8319e599931fba38e18`。


复核记录：2026-09-12 对齐当前自动检测的 DeviceCheckModal 和 state-44/45/46 新截图；56 项咨询回归、真实 Android 摄像头/麦克风本机检查与重复检查通过。轨道立即释放，工作台保留手动预览。真实视频咨询完整链路不在该组件验收范围，详见 evidence/device/verification.md。

- functional_evidence: [evidence/device/verification.md](../evidence/device/verification.md)
- functional_evidence: [evidence/device/regression.log](../evidence/device/regression.log)
- functional_evidence: [evidence/device/native-test.log](../evidence/device/native-test.log)
- functional_evidence: [evidence/device/analyze.log](../evidence/device/analyze.log)
- visual_evidence: [../../test/goldens/design_system/device-error-390.png](../../../test/goldens/design_system/device-error-390.png)
- visual_evidence: [../../test/goldens/design_system/device-error-320-2x.png](../../../test/goldens/design_system/device-error-320-2x.png)
- visual_evidence: [evidence/device/native-ready.png](../evidence/device/native-ready.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
