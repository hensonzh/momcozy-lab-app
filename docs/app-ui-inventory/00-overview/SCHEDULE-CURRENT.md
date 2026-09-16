# G05：日程当前图与长图归档

本项完成：19 张现有设计状态：日历、当天安排、照护方案、编辑与删除、日期时间选择、加载、保存与刷新反馈。共核对 19 张完整图，其中 6 张为测量滚动生成的完整长图。原有金图严格匹配，没有修改产品、测试用例或截图基线，没有增加尺寸／字号组合。

入口归属：底部 Schedule → 日历／当天安排；添加按钮 → 日程表单 → 日期与时间选择 → 保存；安排菜单 → 修改／删除。任务菜单提供进度、跳过、恢复及查看服务计划；展开当前照护方案可查看已发布内容。

正常路径沿用 [日程操作链](SCHEDULE-JOURNEYS.md) 及各条目 README；其截图版本仍保留，不宣称这次重新运行了全部旧入口。近期真实路由进入日程并返回的证据见 [G03 总结 → 完整行动计划](CONSULTATION-SUMMARY-CURRENT.md)。本次现有页面测试实际点击新增、修改、删除、选择器、任务状态和方案入口；目的页回调断言不冒充新路由截图。

100 条列表长图从标题、月历、安排 0 到安排 99 完整覆盖。原有场景已滚动点击末条菜单；添加按钮保留在末尾，没有在拼接中重复。当前产品仍只读取首批 100 条，未支持的第 101 条不虚构成可达状态。

## 当前代表图

| 状态 | 完整图与上下文 | 范围 |
| --- | --- | --- |
| 日历与个人安排 | [图](../raw/test/goldens/product_baseline/schedule-390.png) · [索引](../06-schedule/schedule/README.md) | 当前窗口完整 |
| 当天咨询、行动和个人安排 | [图](../raw/test/goldens/design_system/schedule-care-390.long.png) · [索引](../06-schedule/schedule-care/README.md) | 完整长图 |
| 新增日程：未填写 | [图](../raw/test/goldens/design_system/schedule-create-390.png) · [索引](../06-schedule/schedule-create/README.md) | 当前窗口完整 |
| 日期选择 | [图](../raw/test/goldens/design_system/schedule-date-picker.png) · [索引](../06-schedule/schedule-date-picker/README.md) | 当前窗口完整 |
| 日期输入越界 | [图](../raw/test/goldens/design_system/schedule-date-range-error-320-2x-short.png) · [索引](../06-schedule/schedule-date-range-error-320-2x-short/README.md) | 当前窗口完整 |
| 删除确认 | [图](../raw/test/goldens/design_system/schedule-delete-390.png) · [索引](../06-schedule/schedule-delete/README.md) | 当前窗口完整 |
| 编辑已有日程 | [图](../raw/test/goldens/design_system/schedule-edit-390.png) · [索引](../06-schedule/schedule-edit/README.md) | 当前窗口完整 |
| 100 条已加载安排完整长图 | [图](../raw/test/goldens/design_system/schedule-long-agenda-end.long.png) · [索引](../06-schedule/schedule-long-agenda-end/README.md) | 完整长图 |
| 月历与当前方案概览 | [图](../raw/test/goldens/design_system/schedule-overview-390-1x.long.png) · [索引](../06-schedule/schedule-overview/README.md) | 完整长图 |
| 展开照护方案 | [图](../raw/test/goldens/design_system/schedule-plan-390.long.png) · [索引](../06-schedule/schedule-plan/README.md) | 完整长图 |
| 保存中、字段锁定 | [图](../raw/test/goldens/design_system/schedule-save-busy-320-2x.long.png) · [索引](../06-schedule/schedule-save-busy/README.md) | 完整长图 |
| 保存结果未确认与重试 | [图](../raw/test/goldens/design_system/schedule-save-uncertain-390.png) · [索引](../06-schedule/schedule-save-uncertain/README.md) | 当前窗口完整 |
| 首次加载 | [图](../raw/test/goldens/design_system/schedule-short-loading.png) · [索引](../06-schedule/schedule-short-loading/README.md) | 当前窗口完整 |
| 离线与重试 | [图](../raw/test/goldens/design_system/schedule-short-offline.png) · [索引](../06-schedule/schedule-short-offline/README.md) | 当前窗口完整 |
| 刷新失败、保留原安排 | [图](../raw/test/goldens/design_system/schedule-short-refresh-error.long.png) · [索引](../06-schedule/schedule-short-refresh-error/README.md) | 完整长图 |
| 任务更新中、竞争操作禁用 | [图](../raw/test/goldens/design_system/schedule-task-busy.png) · [索引](../06-schedule/schedule-task-busy/README.md) | 当前窗口完整 |
| 任务操作菜单 | [图](../raw/test/goldens/design_system/schedule-task-menu-390.png) · [索引](../06-schedule/schedule-task-menu/README.md) | 当前窗口完整 |
| 时间输入错误 | [图](../raw/test/goldens/design_system/schedule-time-error-320-2x-short.png) · [索引](../06-schedule/schedule-time-error-320-2x-short/README.md) | 当前窗口完整 |
| 时间选择 | [图](../raw/test/goldens/design_system/schedule-time-picker.png) · [索引](../06-schedule/schedule-time-picker/README.md) | 当前窗口完整 |

## 证据边界与验证

- [共同定向验证](runs/20260914T080457-schedule-renew-current/capture.log)：18 个现有场景通过；[精确命令](runs/20260914T080457-schedule-renew-current/capture-command.json)。没有重跑全仓测试。
- [逐图范围与相关源码指纹](runs/20260914T080457-schedule-renew-current/g05-audit.json)：当前源码与改版实现指纹一致；全部本项图已目视检查。
- 当前页面以隔离仓储运行；系统键盘、真实支付和原生窗口不由本项证明。没有创建真实账号、订单或服务。
- G05／G06 关闭新版图归档与长图缺口，未宣称所有历史条目已变为当前版本。其它旧状态和共用组件差异仍在固定 G11 核对，不另增测试矩阵。
