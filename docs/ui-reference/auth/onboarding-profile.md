# 基本资料

- ID：`auth/onboarding-profile`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[基本资料（衍生设计）](../auth/derived/onboarding-profile.md#L1)，第 1–22 行
- Flutter：`lib/features/onboarding/presentation/onboarding_page.dart`
- Route / 入口：`/onboarding`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**已实现，Figma 新截图待同步**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


2026-09-25 更新：头像创建阶段已移除。当前 onboarding 为 3 步，保存分娩资料后直接进入 App；本页旧的头像截图/验收记录仅供历史追溯，不代表当前流程。新的 App 截图见下列 onboarding-* golden，Figma 画板尚待同步。

- functional_evidence: [evidence/onboarding/verification.md](../evidence/onboarding/verification.md)
- functional_evidence: [evidence/onboarding/design-tests.txt](../evidence/onboarding/design-tests.txt)
- functional_evidence: [evidence/onboarding/regression.txt](../evidence/onboarding/regression.txt)
- functional_evidence: [evidence/onboarding/analyze.txt](../evidence/onboarding/analyze.txt)
- functional_evidence: [evidence/onboarding/build.txt](../evidence/onboarding/build.txt)
- functional_evidence: [evidence/onboarding-reading/verification.md](../evidence/onboarding-reading/verification.md)
- functional_evidence: [evidence/onboarding-reading/regression.log](../evidence/onboarding-reading/regression.log)
- functional_evidence: [../../test/features/onboarding/onboarding_reading_test.dart](../../../test/features/onboarding/onboarding_reading_test.dart)
- functional_evidence: [../../integration_test/onboarding_reading_test.dart](../../../integration_test/onboarding_reading_test.dart)
- visual_evidence: [../../test/goldens/design_system/onboarding-basics-390.png](../../../test/goldens/design_system/onboarding-basics-390.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
