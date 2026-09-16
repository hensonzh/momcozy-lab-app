# 咨询准备-设备检测中

- ID：`services/state-44`
- 类型：state
- 参考来源：original
- 设计源码：[DeviceCheckModal](../source/src/pages/UserApp.tsx#L502)，第 502–541 行
- Flutter：`lib/modules/consultation/presentation/device_check_dialog.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：Me 咨询准备 → 检测摄像头与麦克风
- 状态：**Completed**

旧图为手动开始检测；当前 DeviceCheckModal 在用户打开弹窗后自动开始，按钮在请求中禁用。最新状态见 state-44-viewport.png，关闭必须释放迟到的设备。

[查看参考图](../services/reference/state-44.png)

原始路径：`me-ui-optimization/05-validation/images/44-咨询准备-设备检测初始态.png`；SHA-256：`4e6f0636acd3997cfd41fd2791df2e75576dbf5a5731f7b9353a7355582f3394`。

[查看参考图](../services/state-44-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`7340ac30bab4ff9b551b7f57db72c1ddc2623f2a640414c3951e76d332b85cf9`。


复核记录：2026-09-12 对齐当前自动检测的 DeviceCheckModal 和 state-44/45/46 新截图；56 项咨询回归、真实 Android 摄像头/麦克风本机检查与重复检查通过。轨道立即释放，工作台保留手动预览。真实视频咨询完整链路不在该组件验收范围，详见 evidence/device/verification.md。

- functional_evidence: [evidence/device/verification.md](../evidence/device/verification.md)
- functional_evidence: [evidence/device/regression.log](../evidence/device/regression.log)
- functional_evidence: [evidence/device/native-test.log](../evidence/device/native-test.log)
- functional_evidence: [evidence/device/analyze.log](../evidence/device/analyze.log)
- visual_evidence: [../../test/goldens/design_system/device-checking-390.png](../../../test/goldens/design_system/device-checking-390.png)
- visual_evidence: [../../test/goldens/design_system/device-checking-320-2x.png](../../../test/goldens/design_system/device-checking-320-2x.png)
- visual_evidence: [evidence/device/native-ready.png](../evidence/device/native-ready.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
