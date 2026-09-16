# 陪伴形象选择

- ID：`auth/onboarding-avatar-choice`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[陪伴形象选择（衍生设计）](../auth/derived/onboarding-avatar-choice.md#L1)，第 1–22 行
- Flutter：`lib/features/onboarding/presentation/onboarding_page.dart`
- Route / 入口：`/onboarding /avatar/create /avatar/review`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：按本页衍生规范统一首次使用样式；48 项设计状态测试、85 项 onboarding 回归通过，三宽及 2x、键盘、校验、草稿返回、错误重试、选择与回跳覆盖。保存失败提示遗漏已修复并有先失败再通过证据。验证使用实际 Flutter widget 与受控数据；未运行真实云端形象生成或系统相机授权，默认能力门禁保持原值。

- functional_evidence: [evidence/onboarding/verification.md](../evidence/onboarding/verification.md)
- functional_evidence: [evidence/onboarding/design-tests.txt](../evidence/onboarding/design-tests.txt)
- functional_evidence: [evidence/onboarding/regression.txt](../evidence/onboarding/regression.txt)
- functional_evidence: [evidence/onboarding/analyze.txt](../evidence/onboarding/analyze.txt)
- functional_evidence: [evidence/onboarding/build.txt](../evidence/onboarding/build.txt)
- functional_evidence: [evidence/onboarding-reading/verification.md](../evidence/onboarding-reading/verification.md)
- functional_evidence: [evidence/onboarding-reading/regression.log](../evidence/onboarding-reading/regression.log)
- functional_evidence: [../../test/features/onboarding/onboarding_reading_test.dart](../../../test/features/onboarding/onboarding_reading_test.dart)
- functional_evidence: [../../integration_test/onboarding_reading_test.dart](../../../integration_test/onboarding_reading_test.dart)
- visual_evidence: [../../test/goldens/design_system/onboarding-required-390.png](../../../test/goldens/design_system/onboarding-required-390.png)
- visual_evidence: [../../test/goldens/design_system/onboarding-failed-390.png](../../../test/goldens/design_system/onboarding-failed-390.png)
- visual_evidence: [../../test/goldens/design_system/onboarding-photo-error-390.png](../../../test/goldens/design_system/onboarding-photo-error-390.png)
- visual_evidence: [../../test/goldens/design_system/onboarding-default-confirm-390.png](../../../test/goldens/design_system/onboarding-default-confirm-390.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-photo-privacy-1x.png](../evidence/onboarding-reading/native-onboarding-reading-photo-privacy-1x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-generation-wait-2x.png](../evidence/onboarding-reading/native-onboarding-reading-generation-wait-2x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-generation-stage-1x.png](../evidence/onboarding-reading/native-onboarding-reading-generation-stage-1x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-activation-2x.png](../evidence/onboarding-reading/native-onboarding-reading-activation-2x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-activation-1x.png](../evidence/onboarding-reading/native-onboarding-reading-activation-1x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-generation-stage-2x.png](../evidence/onboarding-reading/native-onboarding-reading-generation-stage-2x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-generation-wait-1x.png](../evidence/onboarding-reading/native-onboarding-reading-generation-wait-1x.png)
- visual_evidence: [evidence/onboarding-reading/native-onboarding-reading-photo-privacy-2x.png](../evidence/onboarding-reading/native-onboarding-reading-photo-privacy-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
