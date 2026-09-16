# PDF 阅读

- ID：`common/pdf`
- 类型：page
- 参考来源：derived-user-approved
- 设计源码：[PDF 阅读（衍生设计）](../common/derived/pdf.md#L1)，第 1–22 行
- Flutter：`lib/features/media/presentation/media_viewer_page.dart`
- Route / 入口：`/media-viewer`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Approved derived design. Shared header, actual PDF pages, page count, previous/next and zoom toolbar; 2x tools wrap to two rows. Real PDFium verifies content paint, paging, zoom, dragging and double tap; Android PDF test verifies both rendered pages, toolbar and return. Loading, failed/expired authorization, unsupported content and retry are covered. Local fixtures only; see media verification for evidence limits.

- functional_evidence: [evidence/media/verification.md](../evidence/media/verification.md)
- functional_evidence: [evidence/media/regression.txt](../evidence/media/regression.txt)
- functional_evidence: [evidence/media/analyze.txt](../evidence/media/analyze.txt)
- functional_evidence: [evidence/media/native-pdf.txt](../evidence/media/native-pdf.txt)
- functional_evidence: [evidence/media/build.txt](../evidence/media/build.txt)
- visual_evidence: [evidence/media/native-media-pdf-page-1.png](../evidence/media/native-media-pdf-page-1.png)
- visual_evidence: [evidence/media/native-media-pdf-page-2.png](../evidence/media/native-media-pdf-page-2.png)
- visual_evidence: [../../test/goldens/design_system/media-pdf-loaded-320-2x.png](../../../test/goldens/design_system/media-pdf-loaded-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/media-pdf-retry-320-2x.png](../../../test/goldens/design_system/media-pdf-retry-320-2x.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
