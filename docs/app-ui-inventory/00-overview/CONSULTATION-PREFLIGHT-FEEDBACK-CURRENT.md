# G11：咨询准备与入室反馈当前图

固定清单所列 5 个状态已按当前版本补齐；另复用 4 张现有整页／浮层加载与错误图。3 个定向场景严格通过，9 个完整窗口均已目视检查，所拍状态没有纵向溢出。

## 实际操作与复用

真实 More → Me → 我的服务 → 预约 → 咨询前准备：初始读取等待／失败 → 重试 → 开始咨询 → 设备检测通过 → 视频授权提交失败并重试 → 所在位置确认失败 → 重试后加入失败 → 轮询恢复成功入室。失败界面保留当前选择与按钮状态，入室后的相同画面沿用 [G02](CONSULTATION-LIVE-CURRENT.md)。整页与 overHome 浮层的加载／重试分别复用既有场景，不增加尺寸组合。

| 具名状态 | 完整图 |
| --- | --- |
| consultation-journey-current-room-loading-393 | [查看](../raw/test/goldens/ui_inventory/consultation-journey-current-room-loading-393.png) |
| consultation-journey-current-room-load-error-393 | [查看](../raw/test/goldens/ui_inventory/consultation-journey-current-room-load-error-393.png) |
| consultation-journey-current-video-consent-error-393 | [查看](../raw/test/goldens/ui_inventory/consultation-journey-current-video-consent-error-393.png) |
| consultation-journey-current-location-request-error-393 | [查看](../raw/test/goldens/ui_inventory/consultation-journey-current-location-request-error-393.png) |
| consultation-journey-current-join-request-error-393 | [查看](../raw/test/goldens/ui_inventory/consultation-journey-current-join-request-error-393.png) |
| room-entry-page-loading-390 | [查看](../raw/test/goldens/design_system/room-entry-page-loading-390.png) |
| room-entry-page-error-390 | [查看](../raw/test/goldens/design_system/room-entry-page-error-390.png) |
| room-entry-modal-loading-390 | [查看](../raw/test/goldens/design_system/room-entry-modal-loading-390.png) |
| room-entry-modal-error-390 | [查看](../raw/test/goldens/design_system/room-entry-modal-error-390.png) |

本报告关闭 G11 已列出的加载、载入失败、视频授权提交失败、位置确认失败与入室失败的版本缺口。咨询结果和通话按 G01/G02 报告复用；准备页其它已有控件状态保留原条目，最终全状态映射审计仍需逐项记录。系统权限与真实双端媒体不由本次替身链证明。未修改产品代码。

[运行记录](runs/20260914T083932-g11-consultation-feedback/strict-capture.log) · [逐图指纹和长图测量](runs/20260914T083932-g11-consultation-feedback/reviewed-images.json) · [范围与源码版本](runs/20260914T083932-g11-consultation-feedback/g11-audit.json)。
