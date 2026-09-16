# 专家服务目录

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`service-catalog`
- 范围：default
- 入口：妈妈首页 → 专家陪伴计划
- 路由：/services
- 实现：[service_catalog_page.dart](../../../../lib/modules/services/presentation/service_catalog_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 四套餐
- 空
- 加载
- 错误

## 归属弹窗／浮层

provider-team

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 四套餐 | [service-current-catalog](../../08-expert-service/service-current-catalog/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 空 | [service-current-catalog-empty](../../08-expert-service/service-current-catalog-empty/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [service-current-catalog-loading](../../08-expert-service/service-current-catalog-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [service-current-catalog-error](../../08-expert-service/service-current-catalog-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/service-current-catalog-empty/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-empty/README.md) | 1 | Retry → no available packages |
| [图](../../08-expert-service/service-journey-catalog-team/default.png) · [入口及前驱](../../08-expert-service/service-journey-catalog-team/README.md) | 1 | Learn about team → provider modal |
| [图](../../08-expert-service/catalog-state-list-top/default.png) · [入口及前驱](../../08-expert-service/catalog-state-list-top/README.md) | 2 | four catalog packages open the matching detail and purchase confirmation 390.0/1.0 |
| [图](../../07-me/more-current-expert-catalog/default.png) · [入口及前驱](../../07-me/more-current-expert-catalog/README.md) | 4 | Expert support card → real service catalog |
| [图](../../08-expert-service/service-journey-catalog-read-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-catalog-read-error/README.md) | 1 | Catalog unavailable → full-page error |
| [图](../../08-expert-service/service-team/default.png) · [入口及前驱](../../08-expert-service/service-team/README.md) | 1 | service catalog at 390.0 / 1.0 |
| [图](../../08-expert-service/service-current-catalog-team-empty/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-team-empty/README.md) | 1 | Empty catalog team → no available experts |
| [图](../../08-expert-service/service-journey-purchase-pending-catalog-refreshed/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-pending-catalog-refreshed/README.md) | 1 | Pull refresh → pending order resume action |
| [图](../../08-expert-service/service-current-catalog-refresh-pending/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-refresh-pending/README.md) | 1 | Pull refresh pending → retained catalog with progress |
| [图](../../08-expert-service/service-current-catalog-loading/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-loading/README.md) | 1 | Enter catalog with GET pending |
| [图](../../03-mom/mom-journey-service-catalog/default.png) · [入口及前驱](../../03-mom/mom-journey-service-catalog/README.md) | 6 | Home expert companionship entry → real service catalog |
| [图](../../08-expert-service/service-journey-catalog-empty/default.png) · [入口及前驱](../../08-expert-service/service-journey-catalog-empty/README.md) | 1 | Retry returns no packages → empty catalog |
| [图](../../08-expert-service/service-current-owned-catalog/default.png) · [入口及前驱](../../08-expert-service/service-current-owned-catalog/README.md) | 1 | Owned service grouped above available packages |
| [图](../../08-expert-service/service-current-pending-catalog/default.png) · [入口及前驱](../../08-expert-service/service-current-pending-catalog/README.md) | 2 | Pending order grouped before available packages |
| [图](../../08-expert-service/service-journey-catalog-loading/default.png) · [入口及前驱](../../08-expert-service/service-journey-catalog-loading/README.md) | 1 | Catalog navigation with requests pending |
| [图](../../08-expert-service/purchase-branches-current-errors-catalog/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-errors-catalog/README.md) | 24 | Home expert plan → catalog |
| [图](../../08-expert-service/services-owned/default.png) · [入口及前驱](../../08-expert-service/services-owned/README.md) | 1 | catalog owned and pending actions at 390.0 / 1.0 |
| [图](../../08-expert-service/service-current-catalog-refresh-error/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-refresh-error/README.md) | 1 | Refresh 503 → retained catalog and retry |
| [图](../../08-expert-service/service-current-catalog-team/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-team/README.md) | 1 | Catalog team action → provider dialog |
| [图](../../08-expert-service/service-team-populated/default.png) · [入口及前驱](../../08-expert-service/service-team-populated/README.md) | 1 | catalog owned and pending actions at 390.0 / 1.0 |
| [图](../../08-expert-service/service-current-catalog-error/default.png) · [入口及前驱](../../08-expert-service/service-current-catalog-error/README.md) | 1 | Catalog 503 → retry |

## 实际操作链与状态依据

[SERVICE-CURRENT.md](../SERVICE-CURRENT.md)
