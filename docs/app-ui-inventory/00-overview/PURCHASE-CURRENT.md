# 当前服务购买：资格、支付、取消与权益同步

使用正式 App、GoRouter、服务目录/套餐页、购买弹窗和 ServicePurchaseController，从 More → Me → 专家陪伴计划 → 查看方案 → 购买逐级点击。HTTP、会话和订单数据为隔离替身；所有付款均为本地 sandbox outcome，不连接收单服务或修改真实账号权益。常规 393 px / 1x 与窄屏 320 px / 2x 各执行五条链。

## 已实际执行

| 链路 | 可见状态和后续行为 |
| --- | --- |
| 购买前资格 | 空表单 → 所在州菜单 → NY 本地未覆盖 → 勾选确认仍不可继续 → CA 可继续 → 取消勾选后禁用；服务端仍可拒绝 CA，显示红色资格提示且不创建订单 |
| 资格及订单失败 | 改州重新校验 → 请求挂起 → 框架 Back 被阻止 → 资格 503 → 重试后订单创建 503 → 再重试进入卡片表单；断言两次创建请求的幂等头相同 |
| 卡片校验及验证 | 四字段清空 → 同时显示卡号、日期、安全码、邮编错误；格式合法但不支持的测试卡 → 指引；两种校验均没有发出付款请求。拒付卡 → 可编辑重试 → 挑战卡 → 字段只读、银行验证 → 请求等待 → 成功 |
| 成功后的两个入口 | “开始预约”进入正式预约前确认，关闭再返回已购套餐；“稍后预约”直接返回已购套餐。测试断言这些入口没有自行创建预约 |
| 未知付款结果 | 付款 POST 挂起、字段禁用、框架 Back 被阻止 → 503 后结果未知 → 订单查询挂起 → GET 503 → 重试原付款 → 成功。断言两次付款请求 body 完全相同，保留原订单版本与 outcome |
| 取消与重新购买 | 验证阶段取消、直接在卡片表单取消均显示“付款已取消”和“没有创建服务权益”；返回方案后可重新购买，新订单 ID 与已取消订单不同 |
| 处理中和权益同步 | 付款返回 processing → 查询返回 reconciling → 查询返回 paid 但 episode 缺失 → 显示权益同步提示且无开始预约按钮 → 查询返回 episode → 成功；独立链还实际点击“完成模拟付款”后成功 |
| 返回 | 每条链最终返回套餐、目录、Me。目录沿用原已加载状态，返回不自动刷新购买标记；不能将它描述为即时同步。目录主动刷新见先前服务链 |

以上均由真实按钮操作、顶层路由断言和请求记录证明，逐状态前驱见下表。仅改变隔离服务响应来重现合法服务状态，不调用控制器私有方法切换页面。

## 视觉审核

71 个状态、142 份窗口、121 张完整长图，51 个状态以长图为主图。263 张原图共 624 个连续全宽片段；182 个唯一片段中，128 个新增片段组成 22 张审阅页，全部查看；54 个引用此前已审阅的相同像素。[审阅映射](purchase-current-visual-review/sources.json)、[证据审计](purchase-current-evidence-audit.json)、[采集源码快照](purchase-current-capture-source-snapshot.json)。

- 支付长图从购买方案、卡片表单一直覆盖到错误提示、验证/重试/查询/取消按钮和底部说明；固定标题及关闭按钮只出现一次，背景保持弹窗打开时的真实页面。
- 大字号下四项错误换行完整；验证的两个按钮自动换行，均实际可点击。未知结果时取消付款禁用，关闭按钮在请求结束后重新可用，截图保留当前真实样式。
- 卡号为单行可横向滚动输入控件，长图保留编辑后的实际内部偏移，部分大字截图显示号码尾段；不把单行输入控件虚构成长文本。安全码保持遮蔽。
- 付款成功但权益未同步和已有 episode 的成功状态分别保留；前者不能提前展示预约动作。窗口保留点击后的实际滚动位置，完整弹窗另有长图。
- 本批没有修改产品代码或通用采集器，没有重新执行原生支付/浏览器跳转。

## 逐状态路径

| 实际操作 | 截图和前驱证据 |
| --- | --- |
| Uncheck acknowledgement → continue disabled | [运行证据](../08-expert-service/purchase-current-acknowledgement-removed/README.md) |
| Query returns episode → success | [运行证据](../08-expert-service/purchase-current-benefits-synced/README.md) |
| Eligibility confirmed → sandbox card form | [运行证据](../08-expert-service/purchase-current-cancel-card/README.md) |
| Home expert support → catalog | [运行证据](../08-expert-service/purchase-current-cancel-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-current-cancel-catalog-return/README.md) |
| More → Me before purchase | [运行证据](../08-expert-service/purchase-current-cancel-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-current-cancel-home-return/README.md) |
| Catalog → feeding confidence package | [运行证据](../08-expert-service/purchase-current-cancel-package/README.md) |
| Cancelled order → purchase available again | [运行证据](../08-expert-service/purchase-current-cancelled-package/README.md) |
| Challenge card → locked fields and 3D Secure actions | [运行证据](../08-expert-service/purchase-current-challenge/README.md) |
| Cancel challenge → cancelled order without benefits | [运行证据](../08-expert-service/purchase-current-challenge-cancelled/README.md) |
| Confirm challenge → verification response pending | [运行证据](../08-expert-service/purchase-current-challenge-pending/README.md) |
| Bank challenge before cancellation | [运行证据](../08-expert-service/purchase-current-challenge-to-cancel/README.md) |
| Eligibility accepted, create order POST 503 → retained form | [运行证据](../08-expert-service/purchase-current-create-error/README.md) |
| Retry same create key → card form | [运行证据](../08-expert-service/purchase-current-create-recovered/README.md) |
| Declined test card → payment failure and editable form | [运行证据](../08-expert-service/purchase-current-declined/README.md) |
| Framework back during confirmation → dialog retained | [运行证据](../08-expert-service/purchase-current-eligibility-back-blocked/README.md) |
| Home expert support → catalog | [运行证据](../08-expert-service/purchase-current-eligibility-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-current-eligibility-catalog-return/README.md) |
| Purchase → untouched eligibility | [运行证据](../08-expert-service/purchase-current-eligibility-empty/README.md) |
| Eligibility POST 503 → retry notice | [运行证据](../08-expert-service/purchase-current-eligibility-error/README.md) |
| More → Me before purchase | [运行证据](../08-expert-service/purchase-current-eligibility-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-current-eligibility-home-return/README.md) |
| Catalog → feeding confidence package | [运行证据](../08-expert-service/purchase-current-eligibility-package/README.md) |
| Eligibility POST held → confirmation busy | [运行证据](../08-expert-service/purchase-current-eligibility-pending/README.md) |
| Supported CA retains acknowledgement → can continue | [运行证据](../08-expert-service/purchase-current-eligibility-ready/README.md) |
| Submit four empty fields → four inline errors | [运行证据](../08-expert-service/purchase-current-fields-invalid/README.md) |
| Book later → owned package without appointment | [运行证据](../08-expert-service/purchase-current-later-booking/README.md) |
| Paid but no episode → synchronizing benefits | [运行证据](../08-expert-service/purchase-current-paid-awaiting-benefits/README.md) |
| Framework Back during payment → dialog retained | [运行证据](../08-expert-service/purchase-current-payment-back-blocked/README.md) |
| Payment POST held → processing and disabled fields | [运行证据](../08-expert-service/purchase-current-payment-pending/README.md) |
| Payment POST 503 → uncertain outcome and retry/query | [运行证据](../08-expert-service/purchase-current-payment-uncertain/README.md) |
| Cancelled payment Back → package | [运行证据](../08-expert-service/purchase-current-plain-cancel-return/README.md) |
| Cancel before submitting card → cancelled order | [运行证据](../08-expert-service/purchase-current-plain-cancelled/README.md) |
| Server processing → query instead of duplicate payment | [运行证据](../08-expert-service/purchase-current-processing/README.md) |
| Order GET 503 → preserve uncertain outcome | [运行证据](../08-expert-service/purchase-current-query-error/README.md) |
| Query uncertain order → GET pending | [运行证据](../08-expert-service/purchase-current-query-pending/README.md) |
| Eligibility confirmed → sandbox card form | [运行证据](../08-expert-service/purchase-current-reconcile-card/README.md) |
| Home expert support → catalog | [运行证据](../08-expert-service/purchase-current-reconcile-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-current-reconcile-catalog-return/README.md) |
| More → Me before purchase | [运行证据](../08-expert-service/purchase-current-reconcile-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-current-reconcile-home-return/README.md) |
| Catalog → feeding confidence package | [运行证据](../08-expert-service/purchase-current-reconcile-package/README.md) |
| Query returns reconciliation → confirmation notice | [运行证据](../08-expert-service/purchase-current-reconciling/README.md) |
| Open available state choices | [运行证据](../08-expert-service/purchase-current-region-menu/README.md) |
| New purchase after cancellation → distinct order | [运行证据](../08-expert-service/purchase-current-replacement-card/README.md) |
| Retry retained payment outcome → paid benefits | [运行证据](../08-expert-service/purchase-current-same-payment-recovered/README.md) |
| Server rejects otherwise supported state → no order | [运行证据](../08-expert-service/purchase-current-server-ineligible/README.md) |
| Complete simulated payment → success | [运行证据](../08-expert-service/purchase-current-simulation-completed/README.md) |
| Sandbox reconciliation before explicit completion | [运行证据](../08-expert-service/purchase-current-simulation-incomplete/README.md) |
| Close success → owned package | [运行证据](../08-expert-service/purchase-current-simulation-package/README.md) |
| Success CTA → booking precheck | [运行证据](../08-expert-service/purchase-current-success-booking/README.md) |
| Close precheck and Back → owned package | [运行证据](../08-expert-service/purchase-current-success-booking-return/README.md) |
| Book later → owned package | [运行证据](../08-expert-service/purchase-current-synced-package/README.md) |
| Eligibility confirmed → sandbox card form | [运行证据](../08-expert-service/purchase-current-uncertain-card/README.md) |
| Home expert support → catalog | [运行证据](../08-expert-service/purchase-current-uncertain-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-current-uncertain-catalog-return/README.md) |
| More → Me before purchase | [运行证据](../08-expert-service/purchase-current-uncertain-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-current-uncertain-home-return/README.md) |
| Catalog → feeding confidence package | [运行证据](../08-expert-service/purchase-current-uncertain-package/README.md) |
| Valid field formats but unrecognized sandbox card → guidance | [运行证据](../08-expert-service/purchase-current-unknown-test-card/README.md) |
| Close card form → resumable package | [运行证据](../08-expert-service/purchase-current-unpaid-closed/README.md) |
| Acknowledge unsupported state → still disabled | [运行证据](../08-expert-service/purchase-current-unsupported-acknowledged/README.md) |
| Select NY → local unsupported state notice | [运行证据](../08-expert-service/purchase-current-unsupported-state/README.md) |
| Eligibility confirmed → sandbox card form | [运行证据](../08-expert-service/purchase-current-validation-card/README.md) |
| Home expert support → catalog | [运行证据](../08-expert-service/purchase-current-validation-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-current-validation-catalog-return/README.md) |
| More → Me before purchase | [运行证据](../08-expert-service/purchase-current-validation-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-current-validation-home-return/README.md) |
| Catalog → feeding confidence package | [运行证据](../08-expert-service/purchase-current-validation-package/README.md) |
| Verification succeeds → benefits and booking actions | [运行证据](../08-expert-service/purchase-current-verified-success/README.md) |

## 验证与剩余范围

10 项严格采集通过，严格运行不更新 Golden；本批测试、购买页面/控制器及采集辅助代码专项静态检查通过。测试文件：`test/modules/services/purchase_current_inventory_test.dart`。日志：[严格运行](runs/20260914T010801-targeted/capture.log)、[专项检查](purchase-current-scoped-analyze.log)、[最终全仓检查](purchase-current-analyze-final.log)、[完整性检查](purchase-current-final-verify.log)。

最终全仓静态检查 **No issues found，退出码 0**。本轮较早曾遇到 Flutter 遥测连接异常（退出码 255），以及独立 `intake_test.dart` 读取不存在 getter 的错误（退出码 1）。重新检查时该文件已被同步修正，本批未改动它；使用 `--suppress-analytics` 复跑全仓后通过。保留 [较早的静态错误](purchase-current-analyze.log) 与 [遥测异常](purchase-current-analyze-telemetry-error.log)，不将它们混同为成功执行。

本批覆盖当前 sandbox 主要购买链。Stripe 配置下的外部支付、401/403/409 等不同业务错误文案、非忙碌时退出及重新进入待验证订单的差异仍列在 [服务逐控件清单](SERVICE-CONTROL-COVERAGE.md)。完整预约、信息采集和服务时间线内部动作须按当前改版继续补齐。全 App 完成状态仍为 **NOT_PROVEN**。
