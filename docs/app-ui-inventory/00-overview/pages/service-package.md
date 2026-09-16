# 服务套餐详情

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`service-package`
- 范围：default
- 入口：服务目录 → 查看方案
- 路由：/services/:packageId
- 实现：[service_package_page.dart](../../../../lib/modules/services/presentation/service_package_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 四套餐内容
- 未购
- 待付
- 已购
- 不可购买
- 缺失
- 加载
- 错误

## 归属弹窗／浮层

provider-team、purchase

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 四套餐内容 | [service-current-package-better-breastfeeding](../../08-expert-service/service-current-package-better-breastfeeding/README.md) · [service-current-package-comfortable-feeding](../../08-expert-service/service-current-package-comfortable-feeding/README.md) · [service-current-package-feeding-confidence](../../08-expert-service/service-current-package-feeding-confidence/README.md) · [service-current-package-milk-supply-care](../../08-expert-service/service-current-package-milk-supply-care/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 未购 | [service-current-package-feeding-confidence](../../08-expert-service/service-current-package-feeding-confidence/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 待付 | [service-current-pending-package](../../08-expert-service/service-current-pending-package/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 已购 | [service-current-owned-package](../../08-expert-service/service-current-owned-package/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 不可购买 | [service-current-package-purchase-disabled](../../08-expert-service/service-current-package-purchase-disabled/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 缺失 | [service-current-package-missing](../../08-expert-service/service-current-package-missing/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [service-current-package-loading](../../08-expert-service/service-current-package-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [service-current-package-error](../../08-expert-service/service-current-package-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../08-expert-service/service-journey-package-payment-disabled/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-payment-disabled/README.md) | 1 | Package with disabled payment mode → purchase unavailable |
| [图](../../08-expert-service/purchase-branches-current-payment-409/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-payment-409/README.md) | 1 | Payment HTTP 409 → specific error and query action |
| [图](../../08-expert-service/purchase-branches-current-stripe-cancelled/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-cancelled/README.md) | 1 | Query cancelled external payment → no service benefits |
| [图](../../08-expert-service/catalog-state-milk-supply-care-bottom/default.png) · [入口及前驱](../../08-expert-service/catalog-state-milk-supply-care-bottom/README.md) | 2 | four catalog packages open the matching detail and purchase confirmation 390.0/1.0 |
| [图](../../08-expert-service/service-journey-purchase-payment-pending/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-payment-pending/README.md) | 1 | Payment response pending → controls and close disabled |
| [图](../../08-expert-service/service-journey-purchase-eligibility-ready/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-eligibility-ready/README.md) | 1 | Supported state → eligibility can be submitted |
| [图](../../08-expert-service/service-current-package-better-breastfeeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-better-breastfeeding/README.md) | 2 | Catalog 亲喂改善 → current package |
| [图](../../08-expert-service/service-journey-package-comfortable-feeding/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-comfortable-feeding/README.md) | 1 | Catalog 舒适哺乳支持 → detail and purchase CTA |
| [图](../../08-expert-service/purchase-success/default.png) · [入口及前驱](../../08-expert-service/purchase-success/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/purchase-branches-current-challenge-back-dismissed/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-challenge-back-dismissed/README.md) | 6 | Idle framework Back → resumable package |
| [图](../../08-expert-service/purchase-branches-current-launch-accepted/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-launch-accepted/README.md) | 3 | Platform reports URL opened → App ready for query, no payment inferred |
| [图](../../08-expert-service/service-journey-package-team-milk-supply-care/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-team-milk-supply-care/README.md) | 1 | Package detail → team information |
| [图](../../08-expert-service/purchase-branches-current-payment-401/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-payment-401/README.md) | 1 | Payment HTTP 401 → specific error and query action |
| [图](../../08-expert-service/purchase-branches-current-stripe-syncing/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-syncing/README.md) | 1 | Stripe paid without episode → entitlement sync |
| [图](../../08-expert-service/service-current-package-buy-feeding-confidence/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-feeding-confidence/README.md) | 1 | Package purchase → eligibility flow |
| [图](../../08-expert-service/purchase-current-eligibility-back-blocked/default.png) · [入口及前驱](../../08-expert-service/purchase-current-eligibility-back-blocked/README.md) | 2 | Framework back during confirmation → dialog retained |
| [图](../../08-expert-service/service-journey-package-better-breastfeeding/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-better-breastfeeding/README.md) | 1 | Catalog 亲喂改善 → detail and purchase CTA |
| [图](../../08-expert-service/purchase-branches-current-eligibility-back-dismissed/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-eligibility-back-dismissed/README.md) | 14 | Framework Back while idle → package |
| [图](../../08-expert-service/service-journey-package-feeding-confidence/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-feeding-confidence/README.md) | 3 | Catalog 喂养安心 → detail and purchase CTA |
| [图](../../08-expert-service/service-current-package-buy-milk-supply-care/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-milk-supply-care/README.md) | 1 | Package purchase → eligibility flow |
| [图](../../08-expert-service/purchase-current-fields-invalid/default.png) · [入口及前驱](../../08-expert-service/purchase-current-fields-invalid/README.md) | 1 | Submit four empty fields → four inline errors |
| [图](../../08-expert-service/purchase-branches-current-checkout-error/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-checkout-error/README.md) | 2 | Checkout POST 503 → order notice and retry |
| [图](../../08-expert-service/purchase-current-unknown-test-card/default.png) · [入口及前驱](../../08-expert-service/purchase-current-unknown-test-card/README.md) | 1 | Valid field formats but unrecognized sandbox card → guidance |
| [图](../../08-expert-service/purchase-current-unsupported-acknowledged/default.png) · [入口及前驱](../../08-expert-service/purchase-current-unsupported-acknowledged/README.md) | 1 | Acknowledge unsupported state → still disabled |
| [图](../../08-expert-service/service-journey-purchase-unsupported-region/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-unsupported-region/README.md) | 1 | Unsupported state and acknowledgment → blocked CTA |
| [图](../../08-expert-service/purchase-challenge/default.png) · [入口及前驱](../../08-expert-service/purchase-challenge/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/service-current-package-error/default.png) · [入口及前驱](../../08-expert-service/service-current-package-error/README.md) | 1 | Package catalog GET 503 → retry |
| [图](../../08-expert-service/catalog-state-comfortable-feeding-bottom/default.png) · [入口及前驱](../../08-expert-service/catalog-state-comfortable-feeding-bottom/README.md) | 2 | four catalog packages open the matching detail and purchase confirmation 390.0/1.0 |
| [图](../../08-expert-service/service-journey-purchase-bank-challenge/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-bank-challenge/README.md) | 1 | Challenge test card → bank verification |
| [图](../../08-expert-service/service-current-pending-order-error/default.png) · [入口及前驱](../../08-expert-service/service-current-pending-order-error/README.md) | 1 | Existing order GET 503 → package Snackbar |
| [图](../../08-expert-service/service-journey-purchase-eligibility-empty/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-eligibility-empty/README.md) | 1 | Purchase → eligibility dialog |
| [图](../../08-expert-service/purchase-stripe-launch-error/default.png) · [入口及前驱](../../08-expert-service/purchase-stripe-launch-error/README.md) | 1 | Stripe uses order mode, reports launch failure and queries returned benefits |
| [图](../../08-expert-service/purchase-branches-current-business-query-recovered/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-business-query-recovered/README.md) | 10 | Query actual pending order → error cleared |
| [图](../../08-expert-service/service-current-package-team-comfortable-feeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-team-comfortable-feeding/README.md) | 1 | Package learn team → provider dialog |
| [图](../../08-expert-service/service-journey-purchase-card-form/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-card-form/README.md) | 2 | Eligibility and order API responses → sandbox card form |
| [图](../../08-expert-service/purchase-current-paid-awaiting-benefits/default.png) · [入口及前驱](../../08-expert-service/purchase-current-paid-awaiting-benefits/README.md) | 1 | Paid but no episode → synchronizing benefits |
| [图](../../08-expert-service/service-journey-purchase-declined/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-declined/README.md) | 1 | Declined test card → retryable payment failure |
| [图](../../08-expert-service/service-journey-purchase-query-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-query-error/README.md) | 1 | Query reconciling payment fails → recoverable order error |
| [图](../../08-expert-service/purchase-branches-current-payment-422/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-payment-422/README.md) | 1 | Payment HTTP 422 → specific error and query action |
| [图](../../08-expert-service/service-journey-purchase-reconciling/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-reconciling/README.md) | 1 | Server payment reconciliation → query instead of duplicate payment |
| [图](../../08-expert-service/purchase-current-server-ineligible/default.png) · [入口及前驱](../../08-expert-service/purchase-current-server-ineligible/README.md) | 1 | Server rejects otherwise supported state → no order |
| [图](../../08-expert-service/service-current-package-team-feeding-confidence/default.png) · [入口及前驱](../../08-expert-service/service-current-package-team-feeding-confidence/README.md) | 1 | Package learn team → provider dialog |
| [图](../../08-expert-service/service-current-package-buy-better-breastfeeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-better-breastfeeding/README.md) | 1 | Package purchase → eligibility flow |
| [图](../../08-expert-service/purchase-branches-current-checkout-back-blocked/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-checkout-back-blocked/README.md) | 5 | Framework Back during checkout preparation → retained |
| [图](../../08-expert-service/purchase-current-challenge-pending/default.png) · [入口及前驱](../../08-expert-service/purchase-current-challenge-pending/README.md) | 1 | Confirm challenge → verification response pending |
| [图](../../08-expert-service/purchase-branches-current-payment-403/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-payment-403/README.md) | 1 | Payment HTTP 403 → specific error and query action |
| [图](../../08-expert-service/purchase-payment/default.png) · [入口及前驱](../../08-expert-service/purchase-payment/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/purchase-branches-current-business-cancelled/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-business-cancelled/README.md) | 3 | Cancel recovered pending order → no benefits |
| [图](../../08-expert-service/purchase-eligibility/default.png) · [入口及前驱](../../08-expert-service/purchase-eligibility/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/purchase-current-acknowledgement-removed/default.png) · [入口及前驱](../../08-expert-service/purchase-current-acknowledgement-removed/README.md) | 1 | Uncheck acknowledgement → continue disabled |
| [图](../../08-expert-service/service-current-paused-package/default.png) · [入口及前驱](../../08-expert-service/service-current-paused-package/README.md) | 1 | Reenter paused zero-session plan → existing package state |
| [图](../../08-expert-service/purchase-unavailable/default.png) · [入口及前驱](../../08-expert-service/purchase-unavailable/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/service-journey-package-read-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-read-error/README.md) | 1 | Enter package while API unavailable → detail error |
| [图](../../08-expert-service/service-journey-package-team-feeding-confidence/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-team-feeding-confidence/README.md) | 1 | Package detail → team information |
| [图](../../05-agent/agent-resource-journey-renew-list/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-renew-list/README.md) | 1 | Tap supported internal artifact link → real renewal route without episode parameter |
| [图](../../08-expert-service/service-current-package-buy-cancel-milk-supply-care/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-cancel-milk-supply-care/README.md) | 2 | Close before submitting eligibility → package |
| [图](../../08-expert-service/service-journey-package-milk-supply-care/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-milk-supply-care/README.md) | 1 | Catalog 奶量管理 → detail and purchase CTA |
| [图](../../08-expert-service/purchase-branches-current-stripe-success/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-success/README.md) | 1 | Query paid episode → success and booking actions |
| [图](../../08-expert-service/service-current-package-buy-cancel-comfortable-feeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-cancel-comfortable-feeding/README.md) | 2 | Close before submitting eligibility → package |
| [图](../../08-expert-service/purchase-branches-current-challenge-reopened/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-challenge-reopened/README.md) | 1 | Reopen requiresAction order → verification without card fields |
| [图](../../08-expert-service/service-journey-purchase-reconciliation-complete/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-reconciliation-complete/README.md) | 3 | Complete pending sandbox payment → purchased benefits |
| [图](../../08-expert-service/catalog-state-better-breastfeeding-bottom/default.png) · [入口及前驱](../../08-expert-service/catalog-state-better-breastfeeding-bottom/README.md) | 2 | four catalog packages open the matching detail and purchase confirmation 390.0/1.0 |
| [图](../../08-expert-service/purchase-current-declined/default.png) · [入口及前驱](../../08-expert-service/purchase-current-declined/README.md) | 1 | Declined test card → payment failure and editable form |
| [图](../../08-expert-service/service-journey-purchase-pending-detail/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-pending-detail/README.md) | 2 | Close unpaid order → continue payment on package |
| [图](../../08-expert-service/service-current-package-buy-comfortable-feeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-buy-comfortable-feeding/README.md) | 1 | Package purchase → eligibility flow |
| [图](../../08-expert-service/purchase-branches-current-create-403/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-create-403/README.md) | 1 | Create HTTP 403 → specific business error |
| [图](../../08-expert-service/purchase-current-processing/default.png) · [入口及前驱](../../08-expert-service/purchase-current-processing/README.md) | 3 | Server processing → query instead of duplicate payment |
| [图](../../07-me/more-current-expert-package/default.png) · [入口及前驱](../../07-me/more-current-expert-package/README.md) | 5 | My service → purchased package details |
| [图](../../08-expert-service/service-journey-purchase-region-menu/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-region-menu/README.md) | 1 | Open current state selector |
| [图](../../08-expert-service/purchase-branches-current-create-409/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-create-409/README.md) | 1 | Create HTTP 409 → specific business error |
| [图](../../08-expert-service/purchase-branches-current-create-401/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-create-401/README.md) | 1 | Create HTTP 401 → specific business error |
| [图](../../08-expert-service/purchase-branches-current-stripe-processing/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-processing/README.md) | 1 | Query processing → only query, no sandbox completion |
| [图](../../08-expert-service/service-current-package-team-milk-supply-care/default.png) · [入口及前驱](../../08-expert-service/service-current-package-team-milk-supply-care/README.md) | 1 | Package learn team → provider dialog |
| [图](../../08-expert-service/purchase-branches-current-stripe-owned/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-owned/README.md) | 9 | Book later → owned package |
| [图](../../08-expert-service/service-current-pending-order-opening/default.png) · [入口及前驱](../../08-expert-service/service-current-pending-order-opening/README.md) | 1 | Resume existing order with GET pending → opening label |
| [图](../../08-expert-service/service-journey-purchase-resume-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-resume-error/README.md) | 1 | Resume order read fails → snackbar on package |
| [图](../../08-expert-service/purchase-branches-current-launch-rejected/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-launch-rejected/README.md) | 1 | Checkout URL returned, platform refuses launch → explicit opening error |
| [图](../../08-expert-service/purchase-current-eligibility-ready/default.png) · [入口及前驱](../../08-expert-service/purchase-current-eligibility-ready/README.md) | 1 | Supported CA retains acknowledgement → can continue |
| [图](../../08-expert-service/service-current-package-missing/default.png) · [入口及前驱](../../08-expert-service/service-current-package-missing/README.md) | 1 | Retry returns removed package → unavailable page |
| [图](../../08-expert-service/purchase-branches-current-create-422/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-create-422/README.md) | 1 | Create HTTP 422 → specific business error |
| [图](../../08-expert-service/service-journey-package-team-better-breastfeeding/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-team-better-breastfeeding/README.md) | 1 | Package detail → team information |
| [图](../../05-agent/agent-resource-journey-renew-closed/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-renew-closed/README.md) | 1 | Close eligibility → selected package retained |
| [图](../../08-expert-service/purchase-current-payment-uncertain/default.png) · [入口及前驱](../../08-expert-service/purchase-current-payment-uncertain/README.md) | 2 | Payment POST 503 → uncertain outcome and retry/query |
| [图](../../08-expert-service/service-current-package-purchase-disabled/default.png) · [入口及前驱](../../08-expert-service/service-current-package-purchase-disabled/README.md) | 1 | Reenter package when payment disabled |
| [图](../../08-expert-service/service-journey-purchase-order-error/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-order-error/README.md) | 1 | Order creation unavailable → retry retains eligibility |
| [图](../../08-expert-service/purchase-current-unsupported-state/default.png) · [入口及前驱](../../08-expert-service/purchase-current-unsupported-state/README.md) | 1 | Select NY → local unsupported state notice |
| [图](../../08-expert-service/service-current-package-loading/default.png) · [入口及前驱](../../08-expert-service/service-current-package-loading/README.md) | 1 | Select package with GET pending |
| [图](../../08-expert-service/purchase-failed/default.png) · [入口及前驱](../../08-expert-service/purchase-failed/README.md) | 1 | purchase states and booking result at 390.0 / 1.0 |
| [图](../../08-expert-service/service-journey-purchase-payment-uncertain/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-payment-uncertain/README.md) | 1 | Payment unavailable → pending outcome retained for retry |
| [图](../../08-expert-service/purchase-branches-current-eligibility-idle/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-eligibility-idle/README.md) | 3 | Untouched eligibility before dismissal |
| [图](../../08-expert-service/purchase-branches-current-stripe-failed/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-stripe-failed/README.md) | 1 | Query returns failed → reopen checkout or query |
| [图](../../08-expert-service/native-resource-renew/default.png) · [入口及前驱](../../08-expert-service/native-resource-renew/README.md) | 1 | Native artifact internal link → generic renewal route |
| [图](../../05-agent/agent-resource-journey-renew-eligibility/default.png) · [入口及前驱](../../05-agent/agent-resource-journey-renew-eligibility/README.md) | 1 | Choose first package → real purchase eligibility |
| [图](../../08-expert-service/purchase-current-region-menu/default.png) · [入口及前驱](../../08-expert-service/purchase-current-region-menu/README.md) | 1 | Open available state choices |
| [图](../../08-expert-service/catalog-state-feeding-confidence-bottom/default.png) · [入口及前驱](../../08-expert-service/catalog-state-feeding-confidence-bottom/README.md) | 3 | four catalog packages open the matching detail and purchase confirmation 390.0/1.0 |
| [图](../../08-expert-service/service-journey-purchase-invalid-card/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-invalid-card/README.md) | 1 | Submit short card number → inline validation |
| [图](../../08-expert-service/service-journey-package-team-comfortable-feeding/default.png) · [入口及前驱](../../08-expert-service/service-journey-package-team-comfortable-feeding/README.md) | 1 | Package detail → team information |
| [图](../../08-expert-service/service-current-package-team-better-breastfeeding/default.png) · [入口及前驱](../../08-expert-service/service-current-package-team-better-breastfeeding/README.md) | 1 | Package learn team → provider dialog |
| [图](../../08-expert-service/purchase-branches-current-reopened-challenge-success/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-reopened-challenge-success/README.md) | 5 | Confirm reopened challenge → paid episode |
| [图](../../08-expert-service/purchase-current-create-error/default.png) · [入口及前驱](../../08-expert-service/purchase-current-create-error/README.md) | 2 | Eligibility accepted, create order POST 503 → retained form |
| [图](../../08-expert-service/service-journey-purchase-challenge-cancelled/default.png) · [入口及前驱](../../08-expert-service/service-journey-purchase-challenge-cancelled/README.md) | 1 | Cancel bank verification → cancelled order with no entitlement |
| [图](../../08-expert-service/purchase/default.png) · [入口及前驱](../../08-expert-service/purchase/README.md) | 1 | sandbox checkout renders at 390.0 / 1.0 |
| [图](../../08-expert-service/purchase-branches-current-submitted-challenge/default.png) · [入口及前驱](../../08-expert-service/purchase-branches-current-submitted-challenge/README.md) | 3 | Submitted card → challenge with locked fields |
| [图](../../08-expert-service/purchase-current-payment-back-blocked/default.png) · [入口及前驱](../../08-expert-service/purchase-current-payment-back-blocked/README.md) | 3 | Framework Back during payment → dialog retained |

## 实际操作链与状态依据

[SERVICE-CURRENT.md](../SERVICE-CURRENT.md) · [PURCHASE-CURRENT.md](../PURCHASE-CURRENT.md) · [PURCHASE-BRANCHES-CURRENT.md](../PURCHASE-BRANCHES-CURRENT.md)
