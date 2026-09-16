# 当前购买分支：退出、验证恢复、业务拒绝与 Stripe

本批使用正式 MomCozyFlutterApp、GoRouter、购买页面与控制器，从 More → Me → 专家陪伴计划 → 查看方案 → 购买逐级点击。HTTP、会话、订单与平台 URL 启动回执采用隔离依赖，不创建真实订单、不发起扣款。393 px / 1x 与 320 px / 2x 各运行三条链。

## 已实际执行

| 入口与操作链 | 实际界面与断言 |
| --- | --- |
| 资格表单退出 | 未填写 → 点击外部保留弹窗 → 空闲时框架 Back 关闭 → 套餐；没有创建订单 |
| 验证关闭与恢复 | 购买 → 提交挑战卡 → 只读卡片与验证动作 → X 关闭 → 继续付款 → 重新打开验证，不再显示卡片字段 → Back 关闭 → 再次继续付款 → 确认验证 → 成功 → X 关闭 → 已购套餐；无预约写入 |
| 创建业务拒绝 | 确认州及声明 → 创建分别返回 401/403/409/422 → 对应登录过期、无权限、订单冲突、填写信息提示；没有订单 → 重试创建 → 卡片表单 |
| 付款业务拒绝 | 支付分别返回 401/403/409/422 → 错误提示和查询按钮，卡片仍可编辑 → 查询真实 pending 状态清除错误 → 取消付款 → 已取消 → 返回方案 |
| Stripe 准备 | Stripe 配置不显示卡片字段；打开 Checkout → POST 挂起、Back 被阻止 → 503 提示且未调用平台启动；重试得到 URL |
| 外部启动边界 | 平台拒绝返回 false → 未打开支付页面；平台抛异常也显示相同提示并断言第二次调用。启动挂起时 Back 被阻止 → 平台返回 true → App 恢复查询入口，订单仍为 pending，不能推断付款成功 |
| Stripe 查询 | 查询等待 → 503 → 重试 cancelled → 已取消、无权益 → 返回方案 → 重新购买；新订单查询 failed → 可重新打开支付页；processing → 仅查询；paid 但无 episode → 正在同步权益；查询得到 episode → 成功 → 稍后预约 → 已购套餐 |
| 返回 | 三条链均继续返回服务目录和 Me，路由及逐状态前驱有记录 |

平台替身仅位于 `plugins.flutter.io/url_launcher` MethodChannel。正式 PlatformExternalUrlLauncher 与 URL 校验仍执行，断言目标为隔离的 Stripe 测试 URL；未真的打开外部浏览器。Stripe 链断言没有调用 sandbox-payment。401 用于证明购买 UI 对该 HTTP 响应的提示，测试关闭自动刷新，不能证明真实凭证过期后的完整重新认证链。

## 视觉审核与证据

54 个状态、108 份窗口、87 张完整长图，33 个状态以长图为主图。195 张 PNG 共 455 个连续全宽片段，165 个唯一片段；81 个新片段组成 14 张审阅页，均已查看，84 个引用此前已审阅且像素完全相同的片段。所有片段与源图逐像素交叉核验，连续覆盖到原图底部。

- 保留操作后的真实滚动位置，窗口可能从支付表单中段开始；另附从固定标题到全部提示与底部动作的纵向长图。
- 窄屏 2x 的长错误提示可换行，关闭标题保持固定；单行输入框保留其真实内部滚动位置。没有修改或美化产品的实际画面。
- 重新打开 requiresAction 时只保留订单概况和验证区域；与刚提交卡片的只读表单分别收录。
- Stripe 已取消、失败、处理中、已付款未同步、同步成功分开截图；未将外部启动成功画成付款成功。

[审阅映射](purchase-branches-current-visual-review/sources.json) · [证据审计](purchase-branches-current-evidence-audit.json) · [源码快照](purchase-branches-current-capture-source-snapshot.json)。重采后 14 份已被替代的旧观察记录归档在 `runs/20260914T012753-targeted/superseded-observations/`，当前观察时间与截图元数据一致。

## 逐状态路径

| 实际操作 | 截图与前驱证据 |
| --- | --- |
| Cancel recovered pending order → no benefits | [运行证据](../08-expert-service/purchase-branches-current-business-cancelled/README.md) |
| Query actual pending order → error cleared | [运行证据](../08-expert-service/purchase-branches-current-business-query-recovered/README.md) |
| Idle framework Back → resumable package | [运行证据](../08-expert-service/purchase-branches-current-challenge-back-dismissed/README.md) |
| Close challenge → resumable package | [运行证据](../08-expert-service/purchase-branches-current-challenge-closed/README.md) |
| Reopen requiresAction order → verification without card fields | [运行证据](../08-expert-service/purchase-branches-current-challenge-reopened/README.md) |
| Framework Back during checkout preparation → retained | [运行证据](../08-expert-service/purchase-branches-current-checkout-back-blocked/README.md) |
| Checkout POST 503 → order notice and retry | [运行证据](../08-expert-service/purchase-branches-current-checkout-error/README.md) |
| Checkout POST pending → preparing and close disabled | [运行证据](../08-expert-service/purchase-branches-current-checkout-pending/README.md) |
| Create HTTP 401 → specific business error | [运行证据](../08-expert-service/purchase-branches-current-create-401/README.md) |
| Create HTTP 403 → specific business error | [运行证据](../08-expert-service/purchase-branches-current-create-403/README.md) |
| Create HTTP 409 → specific business error | [运行证据](../08-expert-service/purchase-branches-current-create-409/README.md) |
| Create HTTP 422 → specific business error | [运行证据](../08-expert-service/purchase-branches-current-create-422/README.md) |
| Retry creation after rejected responses → same order form | [运行证据](../08-expert-service/purchase-branches-current-create-business-recovered/README.md) |
| Framework Back while idle → package | [运行证据](../08-expert-service/purchase-branches-current-eligibility-back-dismissed/README.md) |
| Untouched eligibility before dismissal | [运行证据](../08-expert-service/purchase-branches-current-eligibility-idle/README.md) |
| Outside click → non-dismissible purchase remains | [运行证据](../08-expert-service/purchase-branches-current-eligibility-outside-retained/README.md) |
| Home expert plan → catalog | [运行证据](../08-expert-service/purchase-branches-current-errors-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-branches-current-errors-catalog-return/README.md) |
| More → Me before conditional purchase | [运行证据](../08-expert-service/purchase-branches-current-errors-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-branches-current-errors-home-return/README.md) |
| Catalog → package | [运行证据](../08-expert-service/purchase-branches-current-errors-package/README.md) |
| Platform reports URL opened → App ready for query, no payment inferred | [运行证据](../08-expert-service/purchase-branches-current-launch-accepted/README.md) |
| Framework Back while opening external URL → retained | [运行证据](../08-expert-service/purchase-branches-current-launch-back-blocked/README.md) |
| Platform launch request pending → processing controls | [运行证据](../08-expert-service/purchase-branches-current-launch-pending/README.md) |
| Checkout URL returned, platform refuses launch → explicit opening error | [运行证据](../08-expert-service/purchase-branches-current-launch-rejected/README.md) |
| Create order → editable sandbox form | [运行证据](../08-expert-service/purchase-branches-current-new-card/README.md) |
| Payment HTTP 401 → specific error and query action | [运行证据](../08-expert-service/purchase-branches-current-payment-401/README.md) |
| Payment HTTP 403 → specific error and query action | [运行证据](../08-expert-service/purchase-branches-current-payment-403/README.md) |
| Payment HTTP 409 → specific error and query action | [运行证据](../08-expert-service/purchase-branches-current-payment-409/README.md) |
| Payment HTTP 422 → specific error and query action | [运行证据](../08-expert-service/purchase-branches-current-payment-422/README.md) |
| Confirm reopened challenge → paid episode | [运行证据](../08-expert-service/purchase-branches-current-reopened-challenge-success/README.md) |
| Home expert plan → catalog | [运行证据](../08-expert-service/purchase-branches-current-resume-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-branches-current-resume-catalog-return/README.md) |
| More → Me before conditional purchase | [运行证据](../08-expert-service/purchase-branches-current-resume-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-branches-current-resume-home-return/README.md) |
| Catalog → package | [运行证据](../08-expert-service/purchase-branches-current-resume-package/README.md) |
| Cancelled Stripe order → package | [运行证据](../08-expert-service/purchase-branches-current-stripe-cancel-return/README.md) |
| Query cancelled external payment → no service benefits | [运行证据](../08-expert-service/purchase-branches-current-stripe-cancelled/README.md) |
| Home expert plan → catalog | [运行证据](../08-expert-service/purchase-branches-current-stripe-catalog/README.md) |
| Package Back → catalog | [运行证据](../08-expert-service/purchase-branches-current-stripe-catalog-return/README.md) |
| Query returns failed → reopen checkout or query | [运行证据](../08-expert-service/purchase-branches-current-stripe-failed/README.md) |
| More → Me before conditional purchase | [运行证据](../08-expert-service/purchase-branches-current-stripe-home/README.md) |
| Catalog Back → Me | [运行证据](../08-expert-service/purchase-branches-current-stripe-home-return/README.md) |
| Book later → owned package | [运行证据](../08-expert-service/purchase-branches-current-stripe-owned/README.md) |
| Catalog → package | [运行证据](../08-expert-service/purchase-branches-current-stripe-package/README.md) |
| Eligibility → configured payment mode | [运行证据](../08-expert-service/purchase-branches-current-stripe-payment/README.md) |
| Query processing → only query, no sandbox completion | [运行证据](../08-expert-service/purchase-branches-current-stripe-processing/README.md) |
| Order query 503 → retry retained | [运行证据](../08-expert-service/purchase-branches-current-stripe-query-error/README.md) |
| Return/query from external payment → order GET pending | [运行证据](../08-expert-service/purchase-branches-current-stripe-query-pending/README.md) |
| Repurchase after cancellation → new Stripe order | [运行证据](../08-expert-service/purchase-branches-current-stripe-repurchase/README.md) |
| Query paid episode → success and booking actions | [运行证据](../08-expert-service/purchase-branches-current-stripe-success/README.md) |
| Stripe paid without episode → entitlement sync | [运行证据](../08-expert-service/purchase-branches-current-stripe-syncing/README.md) |
| Submitted card → challenge with locked fields | [运行证据](../08-expert-service/purchase-branches-current-submitted-challenge/README.md) |
| Success Close → owned package | [运行证据](../08-expert-service/purchase-branches-current-success-close/README.md) |

## 验证与未覆盖范围

6 项严格采集通过，未更新 Golden 基线；全仓静态检查 No issues found，退出码 0。本批源码及渲染组件与采集前 SHA-256 快照匹配。测试文件 `test/modules/services/purchase_branches_current_inventory_test.dart`。

- [严格运行](runs/20260914T012931-targeted/capture.log)
- [全仓静态检查](purchase-branches-current-analyze.log)
- [完整性检查](purchase-branches-current-final-verify.log)

本批完成 App 自有的 Stripe 购买状态，**未验证外部 Stripe 网页、真实浏览器返回或收单交易**。当前服务时间线、预约、信息采集及咨询内部动作仍须继续与现有代码/截图逐项核对，见 [服务控件清单](SERVICE-CONTROL-COVERAGE.md)。全 App 完成状态仍为 **NOT_PROVEN**；截图数量与完整性 PASS 均不是全部覆盖的证明。
