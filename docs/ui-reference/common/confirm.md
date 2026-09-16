# 公共确认与丢弃

- ID：`common/confirm`
- 类型：dialog
- 参考来源：derived-user-approved
- 设计源码：[公共确认与丢弃（衍生设计）](../common/derived/confirm.md#L1)，第 1–22 行
- Flutter：`lib/shared/widgets/confirm_discard.dart`
- Route / 入口：`各表单`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：缺少独立丢弃稿，已标记用户确认的衍生设计。日记复用公共确认弹窗并保留放弃修改文案；默认离开标签不变。取消和系统返回保留草稿，确认只返回选择；保存结果不确定时保留刷新核对提示。三种宽度/两种字号、短键盘、原生组件及实际日记入口通过，见input-confirmation证据。

- functional_evidence: [evidence/input-confirmation/verification.md](../evidence/input-confirmation/verification.md)
- functional_evidence: [evidence/input-confirmation/component.txt](../evidence/input-confirmation/component.txt)
- functional_evidence: [evidence/input-confirmation/regression.txt](../evidence/input-confirmation/regression.txt)
- functional_evidence: [evidence/input-confirmation/keyboard.txt](../evidence/input-confirmation/keyboard.txt)
- functional_evidence: [evidence/input-confirmation/native.txt](../evidence/input-confirmation/native.txt)
- functional_evidence: [../../test/shared/input_confirmation_test.dart](../../../test/shared/input_confirmation_test.dart)
- visual_evidence: [evidence/input-confirmation/verification.md](../evidence/input-confirmation/verification.md)
- visual_evidence: [evidence/input-confirmation/native-input-confirm-2x.png](../evidence/input-confirmation/native-input-confirm-2x.png)
- visual_evidence: [evidence/input-confirmation/native-input-uncertain-2x.png](../evidence/input-confirmation/native-input-uncertain-2x.png)
- visual_evidence: [evidence/input-confirmation/native-diary-confirm.png](../evidence/input-confirmation/native-diary-confirm.png)
- visual_evidence: [evidence/input-confirmation/native-diary-preserved.png](../evidence/input-confirmation/native-diary-preserved.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
