# 暂时离开咨询室

- ID：`services/room-leave`
- 类型：dialog
- 参考来源：original
- 设计源码：[VideoPage](../source/src/pages/UserApp.tsx#L3730)，第 3730–3810 行
- Flutter：`lib/modules/consultation/presentation/room_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**



[查看参考图](../services/room-leave-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`92fb046ac39576d0d3f58c8babd4e14f070e650b9f6aabb5d25142535d6e1641`。


复核记录：重新核对当前 VideoPage 和实际 Flutter 渲染，254 项整合回归通过。等待室统一摘要、舞台和控件，离开确认保留连接或调用 leave，未调用 end。三宽与 2x 字号验证。真实双端视频、远程轨道和结束交接不计入本条，services/room 仍待复核。 Disconnect failure recovery is now verified: same connection retained for retry, no old connection restored after disposal, visible persistent feedback, successful retry navigates only after disconnect. 109 regression tests and Android 1x/2x passed; see evidence/room-leave-recovery/verification.md.

- functional_evidence: [../../test/modules/consultation/user_video_test.dart](../../../test/modules/consultation/user_video_test.dart)
- functional_evidence: [evidence/video/regression.log](../evidence/video/regression.log)
- functional_evidence: [evidence/video/analyze.log](../evidence/video/analyze.log)
- functional_evidence: [evidence/video/verification.md](../evidence/video/verification.md)
- functional_evidence: [evidence/room-leave-recovery/verification.md](../evidence/room-leave-recovery/verification.md)
- functional_evidence: [../../test/modules/consultation/room_leave_recovery_test.dart](../../../test/modules/consultation/room_leave_recovery_test.dart)
- functional_evidence: [../../integration_test/room_leave_recovery_test.dart](../../../integration_test/room_leave_recovery_test.dart)
- visual_evidence: [../../test/goldens/design_system/video-leave-320.png](../../../test/goldens/design_system/video-leave-320.png)
- visual_evidence: [../../test/goldens/design_system/video-leave-390.png](../../../test/goldens/design_system/video-leave-390.png)
- visual_evidence: [../../test/goldens/design_system/video-leave-430.png](../../../test/goldens/design_system/video-leave-430.png)
- visual_evidence: [../../test/goldens/design_system/video-leave-320-2x.png](../../../test/goldens/design_system/video-leave-320-2x.png)
- visual_evidence: [evidence/video/verification.md](../evidence/video/verification.md)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-failure-1x.png](../evidence/room-leave-recovery/native-room-leave-failure-1x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-retry-confirmation-2x.png](../evidence/room-leave-recovery/native-room-leave-retry-confirmation-2x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-retry-confirmation-1x.png](../evidence/room-leave-recovery/native-room-leave-retry-confirmation-1x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-failure-2x.png](../evidence/room-leave-recovery/native-room-leave-failure-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
