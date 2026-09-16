# 错误与重试

- ID：`common/error`
- 类型：state
- 参考来源：derived-user-approved
- 设计源码：[错误与重试（衍生设计）](../common/derived/error.md#L1)，第 1–22 行
- Flutter：`lib/shared/widgets/product_feedback.dart`
- Route / 入口：`各页面`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Shared feedback verified against the mapped reference and user-approved derived specs. 304 related regression tests, 47 follow-up alignment checks, 8 final component checks and Android 1x/2x fixture pass. Loading has accessible live status and scrolls in short regions. Original user empty states support start alignment without changing existing media/expert defaults. Success mapping points to actual Baby feedback and related lactation/theme implementations. Real local empty record navigation verified without writes; see evidence for fixture versus API boundaries. Follow-up: user shared feedback paragraphs now use 1.55 leading; controls and workbench retain inherited metrics. 1,348 normal-mode regression tests and Android 1x/2x pass; see evidence/typography/reading/verification.md. Local paragraph overrides remain under review.

- functional_evidence: [evidence/feedback/verification.md](../evidence/feedback/verification.md)
- functional_evidence: [evidence/feedback/component.txt](../evidence/feedback/component.txt)
- functional_evidence: [evidence/feedback/regression.txt](../evidence/feedback/regression.txt)
- functional_evidence: [evidence/feedback/alignment.txt](../evidence/feedback/alignment.txt)
- functional_evidence: [evidence/feedback/native.txt](../evidence/feedback/native.txt)
- functional_evidence: [evidence/feedback/analyze.txt](../evidence/feedback/analyze.txt)
- functional_evidence: [evidence/feedback/build.txt](../evidence/feedback/build.txt)
- functional_evidence: [evidence/typography/reading/verification.md](../evidence/typography/reading/verification.md)
- functional_evidence: [evidence/typography/reading/regression.txt](../evidence/typography/reading/regression.txt)
- functional_evidence: [evidence/typography/reading/scope.txt](../evidence/typography/reading/scope.txt)
- functional_evidence: [evidence/typography/reading/native.txt](../evidence/typography/reading/native.txt)
- functional_evidence: [evidence/typography/reading/analyze.txt](../evidence/typography/reading/analyze.txt)
- visual_evidence: [evidence/feedback/native-feedback-error-1x.png](../evidence/feedback/native-feedback-error-1x.png)
- visual_evidence: [evidence/feedback/native-feedback-error-2x.png](../evidence/feedback/native-feedback-error-2x.png)
- visual_evidence: [evidence/typography/reading/native-feedback-error-1x.png](../evidence/typography/reading/native-feedback-error-1x.png)
- visual_evidence: [evidence/typography/reading/native-feedback-error-2x.png](../evidence/typography/reading/native-feedback-error-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
