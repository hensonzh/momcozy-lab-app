# 对话图片与全屏预览

- ID：`agent/image-preview`
- 类型：dialog
- 参考来源：derived-user-approved
- 设计源码：[对话图片与全屏预览（衍生设计）](../agent/derived/image-preview.md#L1)，第 1–22 行
- Flutter：`lib/features/agent_hub/presentation/agent_image_previews.dart`
- Route / 入口：`/`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Approved derived design: message metadata follows the original attachment row; authenticated thumbnails remain. Fullscreen reuses the shared media header and feedback with zoom limited to decoded images. 494 related tests and Android 1x/2x recovery, zoom and return pass; 320/390/430 golden coverage. Empty thumbnails, empty/corrupt originals, sync/async failures, retry and late completion covered. Native uses in-memory loaders; remote model/image service availability is not claimed.

- functional_evidence: [evidence/agent-images/verification.md](../evidence/agent-images/verification.md)
- functional_evidence: [evidence/agent-images/regression.txt](../evidence/agent-images/regression.txt)
- functional_evidence: [evidence/agent-images/analyze.txt](../evidence/agent-images/analyze.txt)
- functional_evidence: [evidence/agent-images/native.txt](../evidence/agent-images/native.txt)
- functional_evidence: [evidence/agent-images/build.txt](../evidence/agent-images/build.txt)
- functional_evidence: [evidence/agent-images/install.txt](../evidence/agent-images/install.txt)
- functional_evidence: [../../test/features/agent_hub/agent_image_previews_test.dart](../../../test/features/agent_hub/agent_image_previews_test.dart)
- functional_evidence: [../../test/features/agent_hub/agent_image_design_test.dart](../../../test/features/agent_hub/agent_image_design_test.dart)
- functional_evidence: [../../integration_test/agent_image_design_test.dart](../../../integration_test/agent_image_design_test.dart)
- visual_evidence: [evidence/agent-images/native-agent-image-metadata-1x.png](../evidence/agent-images/native-agent-image-metadata-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-loading-1x.png](../evidence/agent-images/native-agent-image-loading-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-empty-response-1x.png](../evidence/agent-images/native-agent-image-empty-response-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-loaded-1x.png](../evidence/agent-images/native-agent-image-loaded-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-zoomed-1x.png](../evidence/agent-images/native-agent-image-zoomed-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-unavailable-1x.png](../evidence/agent-images/native-agent-image-unavailable-1x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-metadata-2x.png](../evidence/agent-images/native-agent-image-metadata-2x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-loading-2x.png](../evidence/agent-images/native-agent-image-loading-2x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-empty-response-2x.png](../evidence/agent-images/native-agent-image-empty-response-2x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-loaded-2x.png](../evidence/agent-images/native-agent-image-loaded-2x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-zoomed-2x.png](../evidence/agent-images/native-agent-image-zoomed-2x.png)
- visual_evidence: [evidence/agent-images/native-agent-image-unavailable-2x.png](../evidence/agent-images/native-agent-image-unavailable-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
