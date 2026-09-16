# 媒体查看器

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`media`
- 范围：default
- 入口：Agent 资源或图片 → 查看
- 路由：/media-viewer
- 实现：[media_viewer_page.dart](../../../../lib/features/media/presentation/media_viewer_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 图片
- PDF 多页与缩放
- 视频
- 加载
- 解码与网络错误
- 资源缺失

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 图片 | [agent-resource-journey-image-loaded](../../05-agent/agent-resource-journey-image-loaded/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| PDF 多页与缩放 | [pdf-loaded](../../00-overview/reused-state-evidence/pdf-loaded/README.md) · [pdf-page-2](../../00-overview/reused-state-evidence/pdf-page-2/README.md) · [pdf-zoomed](../../00-overview/reused-state-evidence/pdf-zoomed/README.md) · [native-resource-pdf-first](../../11-media/native-resource-pdf-first/README.md) · [native-resource-pdf-next](../../11-media/native-resource-pdf-next/README.md) · [native-resource-pdf-zoom](../../11-media/native-resource-pdf-zoom/README.md) | Current PDF controls rendered in PDFium tests; native earlier-version document/gesture evidence retained separately. |
| 视频 | [agent-resource-journey-video-playing](../../05-agent/agent-resource-journey-video-playing/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [agent-resource-journey-image-loading](../../05-agent/agent-resource-journey-image-loading/README.md) · [agent-resource-journey-pdf-loading](../../05-agent/agent-resource-journey-pdf-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 解码与网络错误 | [agent-resource-journey-image-error](../../05-agent/agent-resource-journey-image-error/README.md) · [agent-resource-journey-video-runtime-error](../../05-agent/agent-resource-journey-video-runtime-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 资源缺失 | [media-unavailable-missing](../../11-media/media-unavailable-missing/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../11-media/media-unavailable-missing/default.png) · [入口及前驱](../../11-media/media-unavailable-missing/README.md) | 1 | media missing unavailable and return 390.0 / 1.0 |
| [图](../../11-media/native-resource-image/default.png) · [入口及前驱](../../11-media/native-resource-image/README.md) | 1 | Image card → native decoded PNG |
| [图](../../05-agent/agent-resource-journey-image-loading/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-loading/README.md) | 1 | Tap stable image asset action → actual viewer waiting for authenticated bytes |
| [图](../../11-media/media-unavailable-image/default.png) · [入口及前驱](../../11-media/media-unavailable-image/README.md) | 1 | media image unavailable and return 390.0 / 1.0 |
| [图](../../11-media/media-unavailable-video/default.png) · [入口及前驱](../../11-media/media-unavailable-video/README.md) | 1 | media video unavailable and return 390.0 / 1.0 |
| [图](../../11-media/native-resource-pdf-first/default.png) · [入口及前驱](../../11-media/native-resource-pdf-first/README.md) | 3 | Tap PDF action → native PDFium displays first of two pages |
| [图](../../11-media/native-media-pdf-page-1/default.png) · [入口及前驱](../../11-media/native-media-pdf-page-1/README.md) | 2 | 实际 /media-viewer 路由，注入两页 PDF 资产 |
| [图](../../11-media/media-video-loading/default.png) · [入口及前驱](../../11-media/media-video-loading/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-image-panned/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-panned/README.md) | 1 | Drag zoomed image → translated content |
| [图](../../11-media/native-media-video-ready/default.png) · [入口及前驱](../../11-media/native-media-video-ready/README.md) | 1 | 实际 /media-viewer 路由，注入视频资产 |
| [图](../../11-media/media-video-playing/default.png) · [入口及前驱](../../11-media/media-video-playing/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../11-media/media-image-loading/default.png) · [入口及前驱](../../11-media/media-image-loading/README.md) | 1 | image loading failure retry and zoom 390.0 / 1.0 |
| [图](../../11-media/media-video-returned/default.png) · [入口及前驱](../../11-media/media-video-returned/README.md) | 2 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../11-media/media-video-recovered/default.png) · [入口及前驱](../../11-media/media-video-recovered/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../11-media/native-resource-video-playing/default.png) · [入口及前驱](../../11-media/native-resource-video-playing/README.md) | 1 | Play → native video position advances |
| [图](../../11-media/native-media-video/default.png) · [入口及前驱](../../11-media/native-media-video/README.md) | 1 | 点击暂停 |
| [图](../../05-agent/agent-resource-journey-video-playing/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-playing/README.md) | 1 | Tap play → controller playing state |
| [图](../../11-media/native-resource-image-zoom/default.png) · [入口及前驱](../../11-media/native-resource-image-zoom/README.md) | 1 | Double tap → 2.5x image zoom |
| [图](../../11-media/media-pdf-retry/default.png) · [入口及前驱](../../11-media/media-pdf-retry/README.md) | 1 | PDF loading failure retry and return 390.0 / 1.0 |
| [图](../../11-media/media-unavailable-pdf/default.png) · [入口及前驱](../../11-media/media-unavailable-pdf/README.md) | 1 | media pdf unavailable and return 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-video-exit-fullscreen/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-exit-fullscreen/README.md) | 2 | Exit immersive route → same inline controller and position |
| [图](../../11-media/native-resource-video-inline/default.png) · [入口及前驱](../../11-media/native-resource-video-inline/README.md) | 2 | Exit immersive player retains paused position |
| [图](../../05-agent/agent-resource-journey-video-paused/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-paused/README.md) | 3 | Tap pause → playback paused |
| [图](../../05-agent/agent-resource-journey-image-cached/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-cached/README.md) | 3 | Reopen same image → in-memory cache, no additional asset HTTP |
| [图](../../11-media/media-video/default.png) · [入口及前驱](../../11-media/media-video/README.md) | 2 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-video-seeked/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-seeked/README.md) | 1 | Tap progress → seek position updates |
| [图](../../11-media/native-resource-video-paused/default.png) · [入口及前驱](../../11-media/native-resource-video-paused/README.md) | 1 | Pause native playback |
| [图](../../11-media/native-media-pdf-zoomed/default.png) · [入口及前驱](../../11-media/native-media-pdf-zoomed/README.md) | 1 | 点击放大文档 |
| [图](../../11-media/media-pdf-loading/default.png) · [入口及前驱](../../11-media/media-pdf-loading/README.md) | 1 | PDF loading failure retry and return 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-pdf-error/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-pdf-error/README.md) | 2 | PDF HTTP 503 → actual retry control |
| [图](../../11-media/media-image-loaded/default.png) · [入口及前驱](../../11-media/media-image-loaded/README.md) | 1 | image loading failure retry and zoom 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-image-error/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-error/README.md) | 1 | Image HTTP 503 → retry state in actual viewer |
| [图](../../11-media/native-media-video-playing/default.png) · [入口及前驱](../../11-media/native-media-video-playing/README.md) | 1 | 点击播放 |
| [图](../../11-media/native-resource-video-ready/default.png) · [入口及前驱](../../11-media/native-resource-video-ready/README.md) | 1 | Tap video action → real Android decoder renders asset |
| [图](../../11-media/native-resource-video-fullscreen/default.png) · [入口及前驱](../../11-media/native-resource-video-fullscreen/README.md) | 1 | Open native immersive player |
| [图](../../11-media/native-resource-pdf-zoom/default.png) · [入口及前驱](../../11-media/native-resource-pdf-zoom/README.md) | 1 | Zoom PDF → actual rendered zoom and complete document |
| [图](../../11-media/media-image-retry/default.png) · [入口及前驱](../../11-media/media-image-retry/README.md) | 1 | image loading failure retry and zoom 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-image-zoomed/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-image-zoomed/README.md) | 1 | Double tap actual image → 2.5x zoom |
| [图](../../05-agent/agent-resource-journey-pdf-loading/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-pdf-loading/README.md) | 2 | Tap stable PDF action → viewer requests authenticated PDF |
| [图](../../11-media/media-video-error/default.png) · [入口及前驱](../../11-media/media-video-error/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-video-error/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-error/README.md) | 2 | Tap stable video action → actual player reports isolated platform initialization failure |

## 实际操作链与状态依据

[AGENT-RESOURCE-JOURNEYS.md](../AGENT-RESOURCE-JOURNEYS.md) · [NATIVE-RESOURCE-JOURNEYS.md](../NATIVE-RESOURCE-JOURNEYS.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md) · [SOURCE-VERSION-ACCEPTANCE.md](../SOURCE-VERSION-ACCEPTANCE.md)
