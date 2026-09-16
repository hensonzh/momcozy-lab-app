# 视频咨询

- ID：`services/room`
- 类型：page
- 参考来源：original
- 设计源码：[VideoPage](../source/src/pages/UserApp.tsx#L3730)，第 3730–3810 行
- Flutter：`lib/modules/consultation/presentation/room_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Need Review**




复核记录：Waiting, controls and leave confirmation reviewed; unsuccessful outcomes now prioritize rebooking and explicit /me return, with 101 regression checks, 12 goldens and 4 Android captures. Normal-end Cozymate handoff has no implemented consultation context contract. controlled UI evidence does not validate remote video or charging. Disconnect failure recovery is now verified: same connection retained for retry, no old connection restored after disposal, visible persistent feedback, successful retry navigates only after disconnect. 109 regression tests and Android 1x/2x passed; see evidence/room-leave-recovery/verification.md.

- functional_evidence: [evidence/video/verification.md](../evidence/video/verification.md)
- functional_evidence: [evidence/room-outcomes/verification.md](../evidence/room-outcomes/verification.md)
- functional_evidence: [../../test/modules/consultation/room_outcome_design_test.dart](../../../test/modules/consultation/room_outcome_design_test.dart)
- functional_evidence: [../../integration_test/room_outcome_design_test.dart](../../../integration_test/room_outcome_design_test.dart)
- functional_evidence: [evidence/room-leave-recovery/verification.md](../evidence/room-leave-recovery/verification.md)
- functional_evidence: [../../test/modules/consultation/room_leave_recovery_test.dart](../../../test/modules/consultation/room_leave_recovery_test.dart)
- functional_evidence: [../../integration_test/room_leave_recovery_test.dart](../../../integration_test/room_leave_recovery_test.dart)
- visual_evidence: [services/state-53-viewport.png](../services/state-53-viewport.png)
- visual_evidence: [services/room-leave-viewport.png](../services/room-leave-viewport.png)
- visual_evidence: [evidence/room-outcomes/design-user_no_show.png](../evidence/room-outcomes/design-user_no_show.png)
- visual_evidence: [evidence/room-outcomes/design-technical_failure.png](../evidence/room-outcomes/design-technical_failure.png)
- visual_evidence: [evidence/room-outcomes/native-room-no-show-1x.png](../evidence/room-outcomes/native-room-no-show-1x.png)
- visual_evidence: [evidence/room-outcomes/native-room-no-show-2x.png](../evidence/room-outcomes/native-room-no-show-2x.png)
- visual_evidence: [evidence/room-outcomes/native-room-technical-failure-1x.png](../evidence/room-outcomes/native-room-technical-failure-1x.png)
- visual_evidence: [evidence/room-outcomes/native-room-technical-failure-2x.png](../evidence/room-outcomes/native-room-technical-failure-2x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-failure-1x.png](../evidence/room-leave-recovery/native-room-leave-failure-1x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-retry-confirmation-2x.png](../evidence/room-leave-recovery/native-room-leave-retry-confirmation-2x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-retry-confirmation-1x.png](../evidence/room-leave-recovery/native-room-leave-retry-confirmation-1x.png)
- visual_evidence: [evidence/room-leave-recovery/native-room-leave-failure-2x.png](../evidence/room-leave-recovery/native-room-leave-failure-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
