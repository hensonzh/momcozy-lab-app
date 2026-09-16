# 视频咨询-等待专家进入

- ID：`services/state-53`
- 类型：state
- 参考来源：original
- 设计源码：[VideoPage](../source/src/pages/UserApp.tsx#L3730)，第 3730–3810 行
- Flutter：`lib/modules/consultation/presentation/room_page.dart`
- Route / 入口：`/services/appointments/:appointmentId/room`
- 触发：开始视频咨询 → 确认并进入咨询室
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../services/reference/state-53.png)

原始路径：`me-ui-optimization/05-validation/images/53-视频咨询-等待专家进入.png`；SHA-256：`1cf4a88e44c5d223d3932f1ddd249124782a1f39b7ff284cca88e7641af91da0`。

[查看参考图](../services/state-53-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`172ba8d8e3ab5a0880792579d7bf129805a3cc0dec990f73817e7dd0f38bd54c`。


复核记录：重新核对当前 VideoPage 和实际 Flutter 渲染，254 项整合回归通过。等待室统一摘要、舞台和控件，离开确认保留连接或调用 leave，未调用 end。三宽与 2x 字号验证。真实双端视频、远程轨道和结束交接不计入本条，services/room 仍待复核。

- functional_evidence: [../../test/modules/consultation/user_video_test.dart](../../../test/modules/consultation/user_video_test.dart)
- functional_evidence: [evidence/video/regression.log](../evidence/video/regression.log)
- functional_evidence: [evidence/video/analyze.log](../evidence/video/analyze.log)
- functional_evidence: [evidence/video/verification.md](../evidence/video/verification.md)
- visual_evidence: [../../test/goldens/design_system/video-waiting-320.png](../../../test/goldens/design_system/video-waiting-320.png)
- visual_evidence: [../../test/goldens/design_system/video-waiting-390.png](../../../test/goldens/design_system/video-waiting-390.png)
- visual_evidence: [../../test/goldens/design_system/video-waiting-430.png](../../../test/goldens/design_system/video-waiting-430.png)
- visual_evidence: [../../test/goldens/design_system/video-waiting-320-2x.png](../../../test/goldens/design_system/video-waiting-320-2x.png)
- visual_evidence: [evidence/video/verification.md](../evidence/video/verification.md)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
