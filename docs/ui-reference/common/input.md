# 输入、选择与日期时间弹窗

- ID：`common/input`
- 类型：component
- 参考来源：derived-user-approved
- 设计源码：[输入、选择与日期时间弹窗（衍生设计）](../common/derived/input.md#L1)，第 1–22 行
- Flutter：`lib/shared/widgets/choice_field.dart`
- Route / 入口：`各表单`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：输入与日期时间弹窗按统一规范衍生补齐。12 处日期/时间入口使用共享组件；大字号时间改为可滚动表单，修复 SDK 校验后按钮溢出，并保留本地化、12/24 小时与取消行为。11 项组件检查、833 项回归、Android 1x/2x 实际交互与截图通过；键盘遮挡时可滚动编辑分钟。普通字号保留日历与钟面。

- functional_evidence: [evidence/input-confirmation/verification.md](../evidence/input-confirmation/verification.md)
- functional_evidence: [evidence/input-confirmation/component.txt](../evidence/input-confirmation/component.txt)
- functional_evidence: [evidence/input-confirmation/regression.txt](../evidence/input-confirmation/regression.txt)
- functional_evidence: [evidence/input-confirmation/keyboard.txt](../evidence/input-confirmation/keyboard.txt)
- functional_evidence: [evidence/input-confirmation/native.txt](../evidence/input-confirmation/native.txt)
- functional_evidence: [../../test/shared/input_confirmation_test.dart](../../../test/shared/input_confirmation_test.dart)
- functional_evidence: [evidence/theme-motion/pickers/verification.md](../evidence/theme-motion/pickers/verification.md)
- functional_evidence: [evidence/theme-motion/pickers/component.txt](../evidence/theme-motion/pickers/component.txt)
- functional_evidence: [evidence/theme-motion/pickers/regression.txt](../evidence/theme-motion/pickers/regression.txt)
- functional_evidence: [evidence/theme-motion/pickers/native.txt](../evidence/theme-motion/pickers/native.txt)
- functional_evidence: [evidence/theme-motion/pickers/analyze.txt](../evidence/theme-motion/pickers/analyze.txt)
- visual_evidence: [evidence/theme-motion/pickers/native-input-time-invalid-2x-reduced.png](../evidence/theme-motion/pickers/native-input-time-invalid-2x-reduced.png)
- visual_evidence: [evidence/theme-motion/pickers/native-input-time-2x-reduced.png](../evidence/theme-motion/pickers/native-input-time-2x-reduced.png)
- visual_evidence: [evidence/input-confirmation/verification.md](../evidence/input-confirmation/verification.md)
- visual_evidence: [evidence/input-confirmation/native-input-choices-warmTiles-2x.png](../evidence/input-confirmation/native-input-choices-warmTiles-2x.png)
- visual_evidence: [evidence/input-confirmation/native-input-date-2x.png](../evidence/input-confirmation/native-input-date-2x.png)
- visual_evidence: [evidence/input-confirmation/native-input-time-2x.png](../evidence/input-confirmation/native-input-time-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
