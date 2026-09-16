# Me首页-咨询准备与倒计时

- ID：`mom/state-43`
- 类型：state
- 参考来源：original
- 设计源码：[HomePage](../source/src/pages/UserApp.tsx#L587)，第 587–1309 行
- Flutter：`lib/modules/mom/presentation/mother_home_page.dart`
- Route / 入口：`/me`
- 触发：预约已确认且信息采集完成
- 状态：**Completed**

2026-09-06 状态结构参考；配色/日记/泌乳/导航可能已被 09-08 修订替代。当前 source 快照与专项新图优先，尚未进行逐页验收。

[查看参考图](../mom/reference/state-43.png)

原始路径：`me-ui-optimization/05-validation/images/43-Me首页-咨询准备与倒计时.png`；SHA-256：`5e0938fa59b7138c749d49ee7c971a515c9a0835a7beafd7e64049d4da642f89`。

[查看参考图](../mom/state-43-full.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`3ff84ccbd44a50d7b98499fa3d35f681eb064232f403a851876012e5d32fb3bc`。

[查看参考图](../mom/state-43-viewport.png)

原始路径：`Local design render; see capture-manifest.json`；SHA-256：`3ff84ccbd44a50d7b98499fa3d35f681eb064232f403a851876012e5d32fb3bc`。


复核记录：Home now opens the preparation overlay directly, sharing the existing room controller and preflight. Nested intake navigation, cancel/keep and leave return correctly. 268 regression tests and 1 Android integration test pass; native 1x/2x screenshots verified. Repository/media fixtures are not real backend or remote video E2E evidence; see the Chinese verification document.

- functional_evidence: [evidence/home-preparation/verification.md](../evidence/home-preparation/verification.md)
- functional_evidence: [evidence/home-preparation/regression.log](../evidence/home-preparation/regression.log)
- functional_evidence: [evidence/home-preparation/native.log](../evidence/home-preparation/native.log)
- functional_evidence: [evidence/home-preparation/analyze.log](../evidence/home-preparation/analyze.log)
- functional_evidence: [../../test/modules/consultation/home_consultation_dialog_test.dart](../../../test/modules/consultation/home_consultation_dialog_test.dart)
- functional_evidence: [../../integration_test/home_consultation_dialog_test.dart](../../../integration_test/home_consultation_dialog_test.dart)
- visual_evidence: [evidence/home-preparation/native-home-preparation-1x.png](../evidence/home-preparation/native-home-preparation-1x.png)
- visual_evidence: [evidence/home-preparation/native-home-preparation-2x.png](../evidence/home-preparation/native-home-preparation-2x.png)
- visual_evidence: [../../test/goldens/design_system/home-preparation-ready-390.png](../../../test/goldens/design_system/home-preparation-ready-390.png)
- visual_evidence: [../../test/goldens/design_system/home-preparation-cancel-390.png](../../../test/goldens/design_system/home-preparation-cancel-390.png)
- visual_evidence: [../../test/goldens/design_system/home-preparation-room-390.png](../../../test/goldens/design_system/home-preparation-room-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
