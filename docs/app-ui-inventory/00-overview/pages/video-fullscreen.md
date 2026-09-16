# 视频全屏

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`video-fullscreen`
- 范围：navigator
- 入口：媒体视频 → 全屏
- 路由：Navigator／条件入口，见来源
- 实现：[product_asset_video_player.dart](../../../../lib/features/media/presentation/product_asset_video_player.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 播放
- 暂停
- 进度
- 控件显示与隐藏
- 返回

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 播放 | [media-fullscreen-playing](../../11-media/media-fullscreen-playing/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 暂停 | [media-fullscreen](../../11-media/media-fullscreen/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 进度 | [media-fullscreen](../../11-media/media-fullscreen/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 控件显示与隐藏 | [media-fullscreen](../../11-media/media-fullscreen/README.md) | SUPPORTED_STATE_BOUNDARY: 控件在正常播放/暂停时常驻；当前没有自动隐藏或点击隐藏的实现，不制造隐藏态截图。 |
| 返回 | [native-resource-video-inline](../../11-media/native-resource-video-inline/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../11-media/media-fullscreen/default.png) · [入口及前驱](../../11-media/media-fullscreen/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../11-media/media-video-interrupted/default.png) · [入口及前驱](../../11-media/media-video-interrupted/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../11-media/media-fullscreen-playing/default.png) · [入口及前驱](../../11-media/media-fullscreen-playing/README.md) | 1 | video long duration, controls and fullscreen 390.0 / 1.0 |
| [图](../../05-agent/agent-resource-journey-video-fullscreen/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-video-fullscreen/README.md) | 1 | Fullscreen button → actual immersive route; platform orientation request isolated |
| [图](../../11-media/native-media-video-fullscreen/default.png) · [入口及前驱](../../11-media/native-media-video-fullscreen/README.md) | 1 | 点击全屏 |

## 实际操作链与状态依据

[AGENT-RESOURCE-JOURNEYS.md](../AGENT-RESOURCE-JOURNEYS.md) · [NATIVE-RESOURCE-JOURNEYS.md](../NATIVE-RESOURCE-JOURNEYS.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)
