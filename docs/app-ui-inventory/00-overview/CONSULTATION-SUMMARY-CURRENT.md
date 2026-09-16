# G03：咨询总结、行动详情与目标页

**本项已完成（本报告记录的源码版本）**。复用 16 张现有金图，并补齐 10 张当前 App 路由与操作证据；已核对全部 26 张完整画面。原有状态场景仅选择一次代表运行，不增加尺寸、字号或 HTTP 组合。

当前实现与改版交付的总结页、内容组件、控制器和共用错误组件指纹一致。保留原有任务语义和内容，测试只补真实入口追踪与长图。

## 实际入口、操作与完整截图

入口：More → Me → 专家陪伴计划 → 查看我的服务 → 开始预约 → 咨询前准备 → 设备检查／确认入室 → 咨询结束 → 查看咨询总结。等待画面复用 [G01 待发布图](../08-expert-service/consultation-journey-current-outcome-summary/default.png)。

| 状态／操作 | 当前完整图 | 证据 |
| --- | --- | --- |
| 完整行动计划 → 日程 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-full-plan-393.long.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-full-plan/README.md) | 正常显示同一条已跳过行动；系统返回总结通过 |
| 正式路由：已发布总结 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-published-393.long.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-published/README.md) | 待发布轮询取得已确认方案；正文长图 |
| 展开咨询与服务信息 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-service-information-393.long.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-service-information/README.md) | 时间、服务周期、次数、确认日期与进度入口完整 |
| 行动详情：待完成 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-detail-393.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-detail/README.md) | 查看怎么做 → 描述及四种进度 |
| 行动详情：进行中 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-in-progress-393.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-in-progress/README.md) | 点击进行中 → 服务层更新后选中 |
| 行动详情：已完成 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-recovered-393.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-recovered/README.md) | 重试原更新 → 已完成选中 |
| 关闭详情后的总结 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-return-393.long.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-return/README.md) | 保留已更新行动；完整长图 |
| 行动详情：暂时跳过 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-skipped-393.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-skipped/README.md) | 点击跳过 → 已跳过选中 |
| 行动详情：结果不确定 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-task-uncertain-393.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-task-uncertain/README.md) | 提交失败 → 保留原进度并要求重试 |
| 查看服务进度 → 服务时间线 | [图](../raw/test/goldens/ui_inventory/consultation-journey-current-summary-to-progress-393.long.png) · [实际入口轨迹](../08-expert-service/consultation-journey-current-summary-to-progress/README.md) | 显示已结束咨询及剩余次数；完整长图 |

完整行动计划按钮实际进入 `/schedule`。最初的咨询测试传输层未覆盖 `/v1/schedule`，只显示读取失败；本轮复用既有 ScheduleInventoryTransport 后，日程正常显示同一条已跳过行动。已检查目标长图，且系统返回总结与后续服务进度跳转都通过。这里只调整测试数据接入，没有修改产品或后端。

## 已有设计状态的复用与长图补齐

以下使用生产页面、内容组件和控制器，仓储为隔离测试数据。加载、错误及方案变更由现有场景触发，回调验证的边界保持原样，正常路由由上表独立证明。

| 状态 | 完整图 | 核对结果 |
| --- | --- | --- |
| 尚未产生总结 | [图](../raw/test/goldens/design_system/summary-empty-390.png) · [索引](../08-expert-service/summary-empty/README.md) | 咨询尚未结束；提供服务进度入口 |
| 咨询未完成 | [图](../raw/test/goldens/design_system/summary-failed-320-2x-short.png) · [索引](../08-expert-service/summary-failed-320-2x-short/README.md) | 不显示整理中；可进入服务进度 |
| 首次加载中 | [图](../raw/test/goldens/design_system/summary-loading-390.png) · [索引](../08-expert-service/summary-loading/README.md) | 受控请求完成 → 待发布 → 轮询发布 |
| 完整服务信息 | [图](../raw/test/goldens/design_system/summary-metadata-390.long.png) · [索引](../08-expert-service/summary-metadata/README.md) | 复用已有设计图；展开状态长图 |
| 已发布但无行动 | [图](../raw/test/goldens/design_system/summary-no-actions-information-320-2x-short.long.png) · [索引](../08-expert-service/summary-no-actions-information-320-2x-short/README.md) | 无任务卡；仍显示正文、目标和服务信息 |
| 首次读取失败 | [图](../raw/test/goldens/design_system/summary-offline-390.png) · [索引](../08-expert-service/summary-offline/README.md) | 重新加载后恢复到待发布 |
| 总结整理中 | [图](../raw/test/goldens/design_system/summary-pending-390.png) · [索引](../08-expert-service/summary-pending/README.md) | 复用已有等待状态 |
| 已发布：后续行动与目标 | [图](../raw/test/goldens/design_system/summary-published-390.long.png) · [索引](../08-expert-service/summary-published/README.md) | 复用已有中文设计图；补全到折叠服务信息 |
| 刷新失败，正文保留 | [图](../raw/test/goldens/design_system/summary-refresh-error-390.long.png) · [索引](../08-expert-service/summary-refresh-error/README.md) | 保留原总结；重试恢复，未写入任务 |
| 重新载入后行动已移除 | [图](../raw/test/goldens/design_system/summary-removed-action-320-2x.png) · [索引](../08-expert-service/summary-removed-action/README.md) | 显示方案已更新，可关闭，旧进度项消失 |
| 行动含安排日期与进度 | [图](../raw/test/goldens/design_system/summary-short-progress-320-2x-short.long.png) · [索引](../08-expert-service/summary-short-progress-320-2x-short/README.md) | 复用唯一现有该状态图；完整滚动弹窗 |
| 更新结果不确定：完整长弹窗 | [图](../raw/test/goldens/design_system/summary-short-uncertain-320-2x-short.long.png) · [索引](../08-expert-service/summary-short-uncertain-320-2x-short/README.md) | 说明、日期、进度、失败提示和重试均完整 |
| 更新中 | [图](../raw/test/goldens/design_system/summary-short-updating-320-2x-short.long.png) · [索引](../08-expert-service/summary-short-updating-320-2x-short/README.md) | 进度和关闭禁用，系统返回被拦截 |
| 方案已替换 | [图](../raw/test/goldens/design_system/summary-superseded-320-2x.long.png) · [索引](../08-expert-service/summary-superseded/README.md) | 冻结竞争操作，要求重新载入 |
| 中文行动详情 | [图](../raw/test/goldens/design_system/summary-task-390.png) · [索引](../08-expert-service/summary-task/README.md) | 复用已有详情图 |
| 原版本更新重试 | [图](../raw/test/goldens/design_system/summary-uncertain-390.png) · [索引](../08-expert-service/summary-uncertain/README.md) | 竞争提交锁定；原参数重试 |

已目视核对：总结正文从专家信息到最后的服务信息；后续行动、观察目标与更多帮助没有缺段；行动长弹窗包含说明、安排日期、全部进度选项、失败／重新载入操作。固定标题和弹窗顶部没有重复拼接。首屏无法展示的内容使用实际滚动拼接图。

## 清单修正

- 补录已经存在的“咨询行动详情”弹窗，归属总结页，以生产弹窗类型加“我的进度／方案已更新”文本筛选候选证据，避免把其他同组件弹窗混入。浮层清单从 34 类修正为 35 类。
- 将总结页的泛化状态名改为上述实际产品分支。“未授权”没有总结页独立界面，按共享登录／错误流程归档，不人为创建总结页面。
- 没有新增测试组合；仅使用原有状态场景和一条当前正常路径。其他页面仍按固定缺口队列继续。

## 验证

- [原有状态与当前链首次验证](runs/20260914T074520-summary-current/capture.log)：9 个定向场景通过。
- [日程数据补齐后的实际链验证](runs/20260914T074839-summary-current/capture.log)：1 条链通过；其余 25 张完整图指纹未变。
- [静态分析](runs/20260914T074839-summary-current/analyze.log)：修改测试文件无问题。
- [逐图、长图范围与源码审计](runs/20260914T074839-summary-current/g03-audit.json)、[源码快照](runs/20260914T074839-summary-current/source-snapshot.json)。
