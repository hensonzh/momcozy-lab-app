# G11：日程反馈与 Tooltip 当前图

已补齐固定清单中的 7 个当前状态：新增与下个月 Tooltip、新建校验、新建冲突、编辑冲突、删除结果未确认、任务状态未确认。一个标准窗口操作链严格通过，7 张完整图已目视检查，其中 4 张为完整长图。

真实 More → Schedule → 长按添加／下个月 → 新建失败并保留草稿 → 冲突 → 重试创建成功 → 修改失败保留备注 → 关闭并放弃修改 → 删除未确认仍保留事项 → 任务更新失败 → 刷新恢复。普通日历、编辑与删除、日期时间、保存等待、任务等待、加载与刷新及 100 条列表继续复用 [G05](SCHEDULE-CURRENT.md)，没有重采这些状态。

| 具名状态 | 完整图 |
| --- | --- |
| schedule-journey-current-add-tooltip-393.long | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-add-tooltip-393.long.png) |
| schedule-journey-current-next-tooltip-393.long | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-next-tooltip-393.long.png) |
| schedule-journey-current-create-invalid-393 | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-create-invalid-393.png) |
| schedule-journey-current-create-conflict-393 | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-create-conflict-393.png) |
| schedule-journey-current-edit-conflict-393 | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-edit-conflict-393.png) |
| schedule-journey-current-delete-error-393.long | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-delete-error-393.long.png) |
| schedule-journey-current-task-error-393.long | [查看](../raw/test/goldens/ui_inventory/schedule-journey-current-task-error-393.long.png) |

采集器原先会在拼接时重复画出长按 Tooltip，本轮已修正：固定添加按钮的提示随固定操作区只保留在末帧；日历按钮的提示在原文档位置保留一次，滚动前先完成其消失动画。两个提示长图已单独完整检查，提示、锚点及底部导航各只出现一次；修正后严格复验通过，无须更新视口金图。其它历史提示长图在最终映射时优先引用有效代表，不自动声称旧文件已修复。原用例的旧关闭文本已按当前关闭日程 Tooltip 操作。未修改产品代码。

[严格运行](runs/20260914T085237-g11-schedule/strict-capture.log) · [逐图与长图测量](runs/20260914T085237-g11-schedule/reviewed-images.json) · [源码与范围](runs/20260914T085237-g11-schedule/g11-audit.json) · [静态分析](runs/20260914T085237-g11-schedule/analyze.log)。
