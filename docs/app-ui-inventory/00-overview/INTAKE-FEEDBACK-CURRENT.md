# G11：信息采集错误、选择器与离开确认

9 张当前既有图均严格复用，4 个现有场景通过；没有新增用例、截图基线或尺寸组合。全部 9 个完整窗口已目视检查，其中保存结果未确认页面提供 966 像素完整长图，包含底部重试保存按钮。

## 实际操作与复用

载入失败 → 重试回表单；保存等待后失败 → 字段锁定且草稿保留 → 返回触发未确认结果提示 → 继续填写 → 重试成功 → 查看预约回调；撤销共享后不能保存 → 返回放弃确认 → 继续保留编辑 → 再次离开；基础信息展开 → 所在州、宝宝性别、喂养方式下拉选择 → 出生日期选择器并取消。初始表单、补充信息、共享说明和首次保存成功仍复用 [G09](INTAKE-CURRENT.md)。

| 具名状态 | 完整图 |
| --- | --- |
| intake-uncertain-390.long | [查看](../raw/test/goldens/design_system/intake-uncertain-390.long.png) |
| intake-uncertain-leave-390 | [查看](../raw/test/goldens/design_system/intake-uncertain-leave-390.png) |
| intake-loading-390 | [查看](../raw/test/goldens/design_system/intake-loading-390.png) |
| intake-load-error-390 | [查看](../raw/test/goldens/design_system/intake-load-error-390.png) |
| intake-discard-320 | [查看](../raw/test/goldens/design_system/intake-discard-320.png) |
| intake-region-menu-320 | [查看](../raw/test/goldens/design_system/intake-region-menu-320.png) |
| intake-sex-menu-320 | [查看](../raw/test/goldens/design_system/intake-sex-menu-320.png) |
| intake-feeding-menu-320 | [查看](../raw/test/goldens/design_system/intake-feeding-menu-320.png) |
| intake-birth-picker-320 | [查看](../raw/test/goldens/design_system/intake-birth-picker-320.png) |

本报告关闭 G11 所列载入／保存失败、字段选择器与保留草稿反馈的版本核对。回调证明页面控件行为；正常路由来源和返回链引用原 SERVICE-JOURNEYS 及逐状态 README，未把本次单页面场景冒充新路由截图。长表单背景复用 G09 全长图，覆盖层自身完整显示。其它未列状态在最终总映射中核对，不因重复入口新增截图。

[运行记录](runs/20260914T084042-g11-intake/capture.log) · [逐图指纹和长图测量](runs/20260914T084042-g11-intake/reviewed-images.json) · [范围与源码版本](runs/20260914T084042-g11-intake/g11-audit.json)。
