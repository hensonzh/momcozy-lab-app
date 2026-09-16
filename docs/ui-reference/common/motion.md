# 动作评估

- ID：`common/motion`
- 类型：page
- 参考来源：derived-user-approved
- 设计源码：[动作评估（衍生设计）](../common/derived/motion.md#L1)，第 1–22 行
- Flutter：`lib/features/motion_assessment/presentation/motion_assessment_page.dart`
- Route / 入口：`Agent 动作入口`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Approved derived user-App design. Warm header and one end control outside the camera stage; 2x phrase wrapping, proportional guide on short viewports, scrollable failure recovery. 131 related tests and final 37 layout/controller checks pass. Android isolated fixtures verify denial, camera failure, retry, guide, end/return and teardown in 1x/2x. No live camera, microphone, remote voice or measurement-accuracy claim; result-card presentation remains tracked under Agent.

- functional_evidence: [evidence/motion/verification.md](../evidence/motion/verification.md)
- functional_evidence: [evidence/motion/regression.txt](../evidence/motion/regression.txt)
- functional_evidence: [evidence/motion/layout.txt](../evidence/motion/layout.txt)
- functional_evidence: [evidence/motion/native.txt](../evidence/motion/native.txt)
- functional_evidence: [evidence/motion/analyze.txt](../evidence/motion/analyze.txt)
- functional_evidence: [evidence/motion/build.txt](../evidence/motion/build.txt)
- visual_evidence: [evidence/motion/native-motion-guide-1x.png](../evidence/motion/native-motion-guide-1x.png)
- visual_evidence: [evidence/motion/native-motion-guide-2x.png](../evidence/motion/native-motion-guide-2x.png)
- visual_evidence: [evidence/motion/native-motion-permission-2x.png](../evidence/motion/native-motion-permission-2x.png)
- visual_evidence: [evidence/motion/native-motion-camera-error-1x.png](../evidence/motion/native-motion-camera-error-1x.png)
- visual_evidence: [../../test/goldens/design_system/motion-guide-320-2x.png](../../../test/goldens/design_system/motion-guide-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/motion-failure-320-2x.png](../../../test/goldens/design_system/motion-failure-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
