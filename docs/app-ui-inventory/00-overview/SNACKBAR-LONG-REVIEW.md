# 历史固定 Snackbar 长图复核

Baby 知识来源发现了固定提示重复拼接，采集器已补充 SnackBar 测量。随后对含 SnackBar 的其余 6 张旧长图逐一重采和视觉审阅：本批六张均没有重复提示条。它们原先已有足够的固定底部保护区，或提示条在被拼接滚动区之外，因此不受该缺陷影响。

- 重跑三个正式 App 交互测试文件，严格采集 **30 项通过**，没有更新 Golden 基线。见 [运行日志](runs/20260913T213311-targeted/capture.log)、[命令](runs/20260913T213311-targeted/capture-command.json)。
- 这三个测试涉及的 **249 张视口/长图 SHA-256 全部保持一致**；更新运行元数据与观察链，旧观察归档在 [重采前快照](snackbar-recapture-before/image-hashes.json) 附近。
- 本次专项视觉审阅 6 个视口及 6 张长图，共 26 个连续全宽片段、17 个唯一片段，3 页全部查看；其它 237 张不以此次重采作为新增视觉验收。见 [分段来源](snackbar-visual-review/sources.json) 和 [审计](snackbar-evidence-audit.json)。

| 原始状态 | 当前证据 | 审阅结果 |
| --- | --- | --- |
| `test/goldens/ui_inventory/agent-attachment-journey-image-remove-failed-320-2x.png` | [视口](../raw/test/goldens/ui_inventory/agent-attachment-journey-image-remove-failed-320-2x.png) · [长图](../raw/test/goldens/ui_inventory/agent-attachment-journey-image-remove-failed-320-2x.long.png) | 提示保留一次，正文连续 |
| `test/goldens/ui_inventory/schedule-journey-delete-conflict-393.png` | [视口](../raw/test/goldens/ui_inventory/schedule-journey-delete-conflict-393.png) · [长图](../raw/test/goldens/ui_inventory/schedule-journey-delete-conflict-393.long.png) | 提示保留一次，正文连续 |
| `test/goldens/ui_inventory/agent-entry-journey-external-thrown-393.png` | [视口](../raw/test/goldens/ui_inventory/agent-entry-journey-external-thrown-393.png) · [长图](../raw/test/goldens/ui_inventory/agent-entry-journey-external-thrown-393.long.png) | 提示保留一次，正文连续 |
| `test/goldens/ui_inventory/agent-entry-journey-external-failed-393.png` | [视口](../raw/test/goldens/ui_inventory/agent-entry-journey-external-failed-393.png) · [长图](../raw/test/goldens/ui_inventory/agent-entry-journey-external-failed-393.long.png) | 提示保留一次，正文连续 |
| `test/goldens/ui_inventory/agent-entry-journey-external-failed-320-2x.png` | [视口](../raw/test/goldens/ui_inventory/agent-entry-journey-external-failed-320-2x.png) · [长图](../raw/test/goldens/ui_inventory/agent-entry-journey-external-failed-320-2x.long.png) | 提示保留一次，正文连续 |
| `test/goldens/ui_inventory/agent-entry-journey-external-thrown-320-2x.png` | [视口](../raw/test/goldens/ui_inventory/agent-entry-journey-external-thrown-320-2x.png) · [长图](../raw/test/goldens/ui_inventory/agent-entry-journey-external-thrown-320-2x.long.png) | 提示保留一次，正文连续 |

附件清理失败时图片附件与原草稿仍在，提示位于底部；日程删除未确认时旧条目保持，并提示刷新核对。来源打开失败和抛异常呈现相同提示。

Cozymate 宿主截图中“参考资料”卡的按钮文字出现方块字形；这是当前宿主渲染证据中的缺字现象，不把它解释成正常可读文案。该缺字是否同样出现在当前设备，以及所有历史图片的整体视觉验收，仍需后续核对。

本次完成固定提示条的已知候选复核；不等于全 App UI / UX 盘点完成。
