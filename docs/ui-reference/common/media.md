# 图片与视频资料

- ID：`common/media`
- 类型：page
- 参考来源：derived-user-approved
- 设计源码：[图片与视频资料（衍生设计）](../common/derived/media.md#L1)，第 1–22 行
- Flutter：`lib/features/media/presentation/media_viewer_page.dart`
- Route / 入口：`/media-viewer`
- 触发：从对应页面或父页面进入，具体交互待逐页复核
- 状态：**Completed**

用户确认按统一规范补齐的衍生设计；不是设计工程原稿，不自动代表实现/验收完成。


复核记录：Approved derived design. Shared warm header and dark image/video stage with one video control group and safe-area controls. Verified image load/retry/zoom, stale-image removal, video playback/pause/fullscreen/return and interruption recovery at 320/390/430 and 1x/2x. Android native MP4 playback uses a local loopback fixture and verifies authorization headers. 93 related regression tests pass; see media verification for evidence limits.

- functional_evidence: [evidence/media/verification.md](../evidence/media/verification.md)
- functional_evidence: [evidence/media/regression.txt](../evidence/media/regression.txt)
- functional_evidence: [evidence/media/analyze.txt](../evidence/media/analyze.txt)
- functional_evidence: [evidence/media/native-video.txt](../evidence/media/native-video.txt)
- functional_evidence: [evidence/media/build.txt](../evidence/media/build.txt)
- functional_evidence: [evidence/theme-motion/preferences/verification.md](../evidence/theme-motion/preferences/verification.md)
- functional_evidence: [evidence/theme-motion/preferences/regression.txt](../evidence/theme-motion/preferences/regression.txt)
- functional_evidence: [evidence/theme-motion/preferences/native.txt](../evidence/theme-motion/preferences/native.txt)
- functional_evidence: [evidence/theme-motion/preferences/video-native.txt](../evidence/theme-motion/preferences/video-native.txt)
- functional_evidence: [evidence/theme-motion/preferences/analyze.txt](../evidence/theme-motion/preferences/analyze.txt)
- functional_evidence: [evidence/agent-images/verification.md](../evidence/agent-images/verification.md)
- functional_evidence: [evidence/agent-images/regression.txt](../evidence/agent-images/regression.txt)
- functional_evidence: [evidence/agent-images/analyze.txt](../evidence/agent-images/analyze.txt)
- visual_evidence: [evidence/media/native-media-video.png](../evidence/media/native-media-video.png)
- visual_evidence: [evidence/media/native-media-video-fullscreen.png](../evidence/media/native-media-video-fullscreen.png)
- visual_evidence: [../../test/goldens/design_system/media-image-loaded-320-2x.png](../../../test/goldens/design_system/media-image-loaded-320-2x.png)
- visual_evidence: [../../test/goldens/design_system/media-image-retry-390.png](../../../test/goldens/design_system/media-image-retry-390.png)
- visual_evidence: [../../test/goldens/design_system/media-video-320-2x.png](../../../test/goldens/design_system/media-video-320-2x.png)
- visual_evidence: [evidence/theme-motion/preferences/native-media-video-fullscreen-reduced.png](../evidence/theme-motion/preferences/native-media-video-fullscreen-reduced.png)

验收必须同时记录当前源码、行为验证、实际渲染和与参考的逐项差异。存在旧截图不代表本页已完成。
