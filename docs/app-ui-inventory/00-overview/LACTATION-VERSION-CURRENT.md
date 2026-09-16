# 泌乳页实际改版的版本复核

当前 `lactation_panel.dart` 与前轮采集版本有实际布局差异。已复用当前改版基线，只运行既有两项 390 / 1× 场景；严格比较通过，没有更新基线，没有扩展尺寸或错误组合。通过实际点击覆盖读取恢复、7/30 天趋势、编辑长备注、保存冲突、放弃、删除及撤销、时间输入与校验、保存等待及未知结果离开。

17 个运行状态中 9 张需要长图；全部已生成并检查。概览和长备注首尾是同一份完整内容，交给像素归并保留多个操作前驱，不计为不同页面。底部操作、后续记录和反馈条均在完整图中。

当前图用于渲染版本；正常 App 入口继续沿用 [妈妈模块真实路由链](MOM-JOURNEYS.md)，不会把独立仓储测试称为原生完整 App 实测。详情与首页弹窗共用的记录行为还保留 [控件轨迹](MOM-MILK-CONTROLS.md) 和 [校验报告](MOM-MILK-VALIDATION.md)。

| 现有状态 | 当前完整图与操作 |
| --- | --- |
| lactation-current-30-days | [完整图](../03-mom/lactation-current-30-days/default.png) · [轨迹](../03-mom/lactation-current-30-days/README.md) |
| lactation-current-delete-error | [完整图](../03-mom/lactation-current-delete-error/default.png) · [轨迹](../03-mom/lactation-current-delete-error/README.md) |
| lactation-current-leave-confirm | [完整图](../03-mom/lactation-current-leave-confirm/default.png) · [轨迹](../03-mom/lactation-current-leave-confirm/README.md) |
| lactation-current-loading | [完整图](../03-mom/lactation-current-loading/default.png) · [轨迹](../03-mom/lactation-current-loading/README.md) |
| lactation-current-long-note-end | [完整图](../03-mom/lactation-current-long-note-end/default.png) · [轨迹](../03-mom/lactation-current-long-note-end/README.md) |
| lactation-current-long-note-start | [完整图](../03-mom/lactation-current-long-note-start/default.png) · [轨迹](../03-mom/lactation-current-long-note-start/README.md) |
| lactation-current-overview | [完整图](../03-mom/lactation-current-overview/default.png) · [轨迹](../03-mom/lactation-current-overview/README.md) |
| lactation-current-read-error | [完整图](../03-mom/lactation-current-read-error/default.png) · [轨迹](../03-mom/lactation-current-read-error/README.md) |
| lactation-current-restore-error | [完整图](../03-mom/lactation-current-restore-error/default.png) · [轨迹](../03-mom/lactation-current-restore-error/README.md) |
| lactation-current-restored | [完整图](../03-mom/lactation-current-restored/default.png) · [轨迹](../03-mom/lactation-current-restored/README.md) |
| lactation-current-save-conflict | [完整图](../03-mom/lactation-current-save-conflict/default.png) · [轨迹](../03-mom/lactation-current-save-conflict/README.md) |
| lactation-current-saved-zero | [完整图](../03-mom/lactation-current-saved-zero/default.png) · [轨迹](../03-mom/lactation-current-saved-zero/README.md) |
| lactation-current-saving | [完整图](../03-mom/lactation-current-saving/default.png) · [轨迹](../03-mom/lactation-current-saving/README.md) |
| lactation-current-time-dial | [完整图](../03-mom/lactation-current-time-dial/default.png) · [轨迹](../03-mom/lactation-current-time-dial/README.md) |
| lactation-current-time-input | [完整图](../03-mom/lactation-current-time-input/default.png) · [轨迹](../03-mom/lactation-current-time-input/README.md) |
| lactation-current-time-invalid | [完整图](../03-mom/lactation-current-time-invalid/default.png) · [轨迹](../03-mom/lactation-current-time-invalid/README.md) |
| lactation-current-uncertain-leave | [完整图](../03-mom/lactation-current-uncertain-leave/default.png) · [轨迹](../03-mom/lactation-current-uncertain-leave/README.md) |

[严格运行](runs/20260914-lactation-version-final/strict.log) · [源码指纹](runs/20260914-lactation-version-final/source-hashes.json) · [完整图检查](runs/20260914-lactation-version-final/reviewed-images.json)。
