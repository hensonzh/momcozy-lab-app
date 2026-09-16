# 续购服务

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`service-renew`
- 范围：default
- 入口：服务进度或 Agent → 续购
- 路由：/services/renew / /services/episodes/:episodeId/renew
- 实现：[service_renew_page.dart](../../../../lib/modules/services/presentation/service_renew_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 可续购
- 暂停
- 到期
- 无套餐
- 加载
- 错误
- 购买入口

## 归属弹窗／浮层

purchase

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 可续购 | [renew-list](../../08-expert-service/renew-list/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 暂停 | [renew-short-owned-paused](../../08-expert-service/renew-short-owned-paused/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 到期 | [renew-journey-list](../../08-expert-service/renew-journey-list/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 无套餐 | [renew-empty](../../08-expert-service/renew-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [renew-short-loading](../../08-expert-service/renew-short-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [renew-offline](../../08-expert-service/renew-offline/README.md) · [renew-order-error](../../08-expert-service/renew-order-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 购买入口 | [renew-eligibility](../../08-expert-service/renew-eligibility/README.md) · [renew-pending-listed](../../08-expert-service/renew-pending-listed/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/renew-short-last-package/default.png) · [入口及前驱](../../08-expert-service/renew-short-last-package/README.md) | 1 | short large catalog loads, scrolls and returns without ordering |
| [图](../../08-expert-service/renew-short-loading/default.png) · [入口及前驱](../../08-expert-service/renew-short-loading/README.md) | 1 | short large catalog loads, scrolls and returns without ordering |
| [图](../../08-expert-service/renew-selected/default.png) · [入口及前驱](../../08-expert-service/renew-selected/README.md) | 1 | renew selection opens existing eligibility flow 390.0/1.0 |
| [图](../../08-expert-service/renew-journey-paid/default.png) · [入口及前驱](../../08-expert-service/renew-journey-paid/README.md) | 1 | Sandbox payment succeeds → new service; original remains completed |
| [图](../../08-expert-service/renew-order-loading/default.png) · [入口及前驱](../../08-expert-service/renew-order-loading/README.md) | 1 | pending order reopens without new purchase; retry locks duplicate taps |
| [图](../../08-expert-service/renew-short-owned-paused/default.png) · [入口及前驱](../../08-expert-service/renew-short-owned-paused/README.md) | 1 | owned service remains reachable with purchase disabled CareEpisodeStatus.paused |
| [图](../../08-expert-service/renew-eligibility/default.png) · [入口及前驱](../../08-expert-service/renew-eligibility/README.md) | 1 | renew selection opens existing eligibility flow 390.0/1.0 |
| [图](../../08-expert-service/renew-journey-loading/default.png) · [入口及前驱](../../08-expert-service/renew-journey-loading/README.md) | 1 | Continue support → catalog HTTP pending |
| [图](../../08-expert-service/renew-pending-listed/default.png) · [入口及前驱](../../08-expert-service/renew-pending-listed/README.md) | 1 | pending order reopens without new purchase; retry locks duplicate taps |
| [图](../../08-expert-service/renew-journey-pending-closed/default.png) · [入口及前驱](../../08-expert-service/renew-journey-pending-closed/README.md) | 2 | Close payment → pending order stays resumable |
| [图](../../08-expert-service/renew-journey-active-return/default.png) · [入口及前驱](../../08-expert-service/renew-journey-active-return/README.md) | 2 | New service progress back → renewal list |
| [图](../../08-expert-service/renew-journey-order-loading/default.png) · [入口及前驱](../../08-expert-service/renew-journey-order-loading/README.md) | 1 | Continue payment → order read pending, package buttons disabled |
| [图](../../08-expert-service/renew-journey-load-error/default.png) · [入口及前驱](../../08-expert-service/renew-journey-load-error/README.md) | 1 | Catalog error → retry |
| [图](../../08-expert-service/renew-journey-order-error/default.png) · [入口及前驱](../../08-expert-service/renew-journey-order-error/README.md) | 1 | Order read fails → scroll to top → inline open error and selectable packages |
| [图](../../08-expert-service/renew-journey-empty/default.png) · [入口及前驱](../../08-expert-service/renew-journey-empty/README.md) | 1 | Retry returns no packages → empty support list |
| [图](../../08-expert-service/renew-disabled/default.png) · [入口及前驱](../../08-expert-service/renew-disabled/README.md) | 1 | disabled purchase, empty catalog, offline retry are explicit |
| [图](../../08-expert-service/renew-journey-purchase-disabled/default.png) · [入口及前驱](../../08-expert-service/renew-journey-purchase-disabled/README.md) | 1 | Pull to refresh receives disabled payment mode → buttons disabled |
| [图](../../08-expert-service/progress-current-renew-purchase/default.png) · [入口及前驱](../../08-expert-service/progress-current-renew-purchase/README.md) | 1 | Select renewal plan → real eligibility dialog |
| [图](../../08-expert-service/progress-current-renew-options/default.png) · [入口及前驱](../../08-expert-service/progress-current-renew-options/README.md) | 5 | Ended service Continue support → renewal options |
| [图](../../08-expert-service/renew-order-error/default.png) · [入口及前驱](../../08-expert-service/renew-order-error/README.md) | 1 | pending order reopens without new purchase; retry locks duplicate taps |
| [图](../../08-expert-service/renew-short-owned-provisioningPending/default.png) · [入口及前驱](../../08-expert-service/renew-short-owned-provisioningPending/README.md) | 1 | owned service remains reachable with purchase disabled CareEpisodeStatus.provisioningPending |
| [图](../../08-expert-service/renew-offline/default.png) · [入口及前驱](../../08-expert-service/renew-offline/README.md) | 1 | disabled purchase, empty catalog, offline retry are explicit |
| [图](../../08-expert-service/renew-list/default.png) · [入口及前驱](../../08-expert-service/renew-list/README.md) | 1 | renew selection opens existing eligibility flow 390.0/1.0 |
| [图](../../08-expert-service/renew-journey-eligibility/default.png) · [入口及前驱](../../08-expert-service/renew-journey-eligibility/README.md) | 1 | Choose highlighted package → existing purchase eligibility dialog |
| [图](../../08-expert-service/renew-ongoing/default.png) · [入口及前驱](../../08-expert-service/renew-ongoing/README.md) | 1 | ongoing service navigates without making a new order |
| [图](../../08-expert-service/renew-empty/default.png) · [入口及前驱](../../08-expert-service/renew-empty/README.md) | 1 | disabled purchase, empty catalog, offline retry are explicit |
| [图](../../08-expert-service/renew-journey-order-resumed/default.png) · [入口及前驱](../../08-expert-service/renew-journey-order-resumed/README.md) | 2 | Retry package → existing payment dialog without creating duplicate order |

## 实际操作链与状态依据

[RENEW-CURRENT.md](../RENEW-CURRENT.md) · [RENEW-PENDING-CURRENT.md](../RENEW-PENDING-CURRENT.md) · [RENEW-JOURNEYS.md](../RENEW-JOURNEYS.md)

RENEW-PENDING-CURRENT.md：当前主要界面及具名旧反馈状态已核对，其它历史证据保留来源与最终映射边界。

## 有限收尾队列进度

- G06：已完成：当前代表图与完整长图归档，历史操作链保留。[版本、证据及下一动作](../VISUAL-GAPS.md)。

## 已有改版运行图，优先复用

- [20260914-service-renew](../../../ui-refactor/20260914-service-renew/HANDOFF.md)：27 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
