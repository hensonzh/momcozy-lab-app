# 当前服务目录、套餐详情与已购入口

从正式 App 的 More → Me → 专家陪伴计划实际进入，使用真实 GoRouter、页面、控制器、Repository 和接口编解码；HTTP、账号存储和业务数据为隔离夹具。393 px / 1x 与 320 px / 2x 各执行五条链，未向真实用户创建订单、付款或预约。

## 已执行的路径

- 服务总入口 → 四个套餐（喂养安心、亲喂改善、奶量管理、舒适哺乳支持）→ 查看方案 → 了解团队 → 关闭 → 购买确认 → 关闭购买 → 返回目录及首页。四种详情均含完整 IBCLC 和 AI / App 服务说明，价格与购买按钮在页面底部固定。
- 目录团队卡：打开、按钮关闭、点击外部关闭、框架返回关闭均实际执行。目录的服务方向只是说明标签，没有筛选回调，不将其当成遗漏 Tab。
- 目录 GET 等待 → 503 → 重试空目录 → 空团队弹窗 → 下拉刷新恢复 → 保留旧数据的刷新中/503 → 重试恢复。首次首页截图中服务区加载是实际挂起请求造成的状态，非伪造白屏。
- 套餐 GET 等待 → 503 → 重试返回目录中无此套餐 → 缺失提示 → 返回 → 恢复并关闭支付能力 → 显示“暂未开放购买”，断言按钮不可用。
- 已购目录 → 查看我的服务 → 套餐中的专家身份、次数 → 服务进度真实时间线 → 返回 → 开始预约 → 预约前确认 → 关闭 → 返回。时间线没有已预约专家时显示 IBCLC 专家团队，与套餐卡取目录身份的数据来源不同。
- 将隔离服务数据设为暂停且剩余次数为零后重新进入：套餐“开始预约”仍可点击，预约页随后显示“当前没有可用的咨询次数”。这个限制发生在目标页；没有把套餐按钮描述成已禁用。返回首页后对应服务入口反映更新状态。
- 待付款分组 → 继续付款 → 套餐继续付款 → 正在打开 → GET 503 Snackbar → 提示消失 → 重试打开已有订单 → 本地模拟卡片表单 → 关闭 → 保留可继续付款的套餐 → 返回。未点击支付；此链证明已有订单恢复入口，不代表完整支付链。

## 视觉检查及采集修正

本批 61 个状态、122 份窗口、97 张完整长图，42 个状态使用长图作为主图。最终 219 张原图共 545 个连续全宽片段、229 个唯一片段，均已审阅：初版 37 张审阅页完整查看；更新版的 9 个新增片段分为 2 页，其余 220 个片段逐像素引用已审阅内容。[最终审阅映射](service-current-visual-review-update/sources.json)、[证据审计](service-current-evidence-audit.json)、[采集源码快照](service-current-capture-source-snapshot.json)。旧审阅页保留修正前证据，最终图片以更新映射为准。

- 团队与购买弹窗展开到完整正文/表单底部，背景保留实际窗口，不把背景页面拼进弹窗正文。固定价格栏及 Snackbar 只保留一次。
- 发现并修正服务进度大字长图的边框错位：滚动后底部“回到最近记录”会缩小滚动区域，旧采集器固定使用首次高度，把页脚边框拼入正文。现在逐帧测量滚动区域，并记录 `frame_scroll_bounds`。该页实际高度从 672 变为 748，正文仍为 1024 px。修正后已查看完整长图。
- 采集测试增加像素断言：实际窗口中时间线事件的内部区域必须与长图中对应位置逐像素相同（排除滚动时可能产生 1 级色值差的圆角外缘），防止动态页脚再次混入正文。该断言仅在长图采集模式执行。
- 本批采集期间预约页面已改版，重跑后更新了 6 张变化图片，关闭动作改用当前“关闭预约前确认”按钮。没有为了维持旧基线修改产品页面。

## 逐状态入口与前驱

| 实际操作 | 窗口、长图和前驱证据 |
| --- | --- |
| Home expert plan → current catalog | [运行证据](../08-expert-service/service-current-catalog/README.md) |
| Four package Back paths → catalog | [运行证据](../08-expert-service/service-current-catalog-all-return/README.md) |
| Retry → no available packages | [运行证据](../08-expert-service/service-current-catalog-empty/README.md) |
| Catalog 503 → retry | [运行证据](../08-expert-service/service-current-catalog-error/README.md) |
| Catalog Back → mother home | [运行证据](../08-expert-service/service-current-catalog-home-return/README.md) |
| Enter catalog with GET pending | [运行证据](../08-expert-service/service-current-catalog-loading/README.md) |
| Authenticated More → Me before service entry | [运行证据](../08-expert-service/service-current-catalog-recovery-home/README.md) |
| Catalog recovery Back → home | [运行证据](../08-expert-service/service-current-catalog-recovery-home-return/README.md) |
| Refresh 503 → retained catalog and retry | [运行证据](../08-expert-service/service-current-catalog-refresh-error/README.md) |
| Pull refresh after catalog restored → available packages | [运行证据](../08-expert-service/service-current-catalog-refresh-filled/README.md) |
| Pull refresh pending → retained catalog with progress | [运行证据](../08-expert-service/service-current-catalog-refresh-pending/README.md) |
| Retry refresh → error removed and catalog restored | [运行证据](../08-expert-service/service-current-catalog-refresh-recovered/README.md) |
| Catalog team action → provider dialog | [运行证据](../08-expert-service/service-current-catalog-team/README.md) |
| Team Flutter back → catalog | [运行证据](../08-expert-service/service-current-catalog-team-back-dismissed/README.md) |
| Team outside tap → catalog | [运行证据](../08-expert-service/service-current-catalog-team-barrier-dismissed/README.md) |
| Team Close → catalog | [运行证据](../08-expert-service/service-current-catalog-team-closed/README.md) |
| Empty catalog team → no available experts | [运行证据](../08-expert-service/service-current-catalog-team-empty/README.md) |
| Authenticated More → Me before service entry | [运行证据](../08-expert-service/service-current-discovery-home/README.md) |
| Owned package booking → actual booking preparation | [运行证据](../08-expert-service/service-current-owned-booking/README.md) |
| Booking cancel/back → owned package | [运行证据](../08-expert-service/service-current-owned-booking-return/README.md) |
| Owned service grouped above available packages | [运行证据](../08-expert-service/service-current-owned-catalog/README.md) |
| Authenticated More → Me before service entry | [运行证据](../08-expert-service/service-current-owned-home/README.md) |
| Return through package and catalog → home | [运行证据](../08-expert-service/service-current-owned-home-return/README.md) |
| Owned package → expert identity, remaining sessions, progress and booking | [运行证据](../08-expert-service/service-current-owned-package/README.md) |
| Package progress action → actual service timeline | [运行证据](../08-expert-service/service-current-owned-progress/README.md) |
| Timeline Back → owned package | [运行证据](../08-expert-service/service-current-owned-progress-return/README.md) |
| Catalog 亲喂改善 → current package | [运行证据](../08-expert-service/service-current-package-better-breastfeeding/README.md) |
| Package purchase → eligibility flow | [运行证据](../08-expert-service/service-current-package-buy-better-breastfeeding/README.md) |
| Close before submitting eligibility → package | [运行证据](../08-expert-service/service-current-package-buy-cancel-better-breastfeeding/README.md) |
| Close before submitting eligibility → package | [运行证据](../08-expert-service/service-current-package-buy-cancel-comfortable-feeding/README.md) |
| Close before submitting eligibility → package | [运行证据](../08-expert-service/service-current-package-buy-cancel-feeding-confidence/README.md) |
| Close before submitting eligibility → package | [运行证据](../08-expert-service/service-current-package-buy-cancel-milk-supply-care/README.md) |
| Package purchase → eligibility flow | [运行证据](../08-expert-service/service-current-package-buy-comfortable-feeding/README.md) |
| Package purchase → eligibility flow | [运行证据](../08-expert-service/service-current-package-buy-feeding-confidence/README.md) |
| Package purchase → eligibility flow | [运行证据](../08-expert-service/service-current-package-buy-milk-supply-care/README.md) |
| Catalog 舒适哺乳支持 → current package | [运行证据](../08-expert-service/service-current-package-comfortable-feeding/README.md) |
| Package catalog GET 503 → retry | [运行证据](../08-expert-service/service-current-package-error/README.md) |
| Catalog 喂养安心 → current package | [运行证据](../08-expert-service/service-current-package-feeding-confidence/README.md) |
| Select package with GET pending | [运行证据](../08-expert-service/service-current-package-loading/README.md) |
| Catalog 奶量管理 → current package | [运行证据](../08-expert-service/service-current-package-milk-supply-care/README.md) |
| Retry returns removed package → unavailable page | [运行证据](../08-expert-service/service-current-package-missing/README.md) |
| Reenter package when payment disabled | [运行证据](../08-expert-service/service-current-package-purchase-disabled/README.md) |
| Catalog before opening package | [运行证据](../08-expert-service/service-current-package-recovery-catalog/README.md) |
| Authenticated More → Me before service entry | [运行证据](../08-expert-service/service-current-package-recovery-home/README.md) |
| Package and catalog Back → home | [运行证据](../08-expert-service/service-current-package-recovery-home-return/README.md) |
| Package learn team → provider dialog | [运行证据](../08-expert-service/service-current-package-team-better-breastfeeding/README.md) |
| Package learn team → provider dialog | [运行证据](../08-expert-service/service-current-package-team-comfortable-feeding/README.md) |
| Package learn team → provider dialog | [运行证据](../08-expert-service/service-current-package-team-feeding-confidence/README.md) |
| Package learn team → provider dialog | [运行证据](../08-expert-service/service-current-package-team-milk-supply-care/README.md) |
| Package booking action on paused plan → actual eligibility block | [运行证据](../08-expert-service/service-current-paused-booking/README.md) |
| Reenter paused zero-session plan → existing package state | [运行证据](../08-expert-service/service-current-paused-package/README.md) |
| Pending order grouped before available packages | [运行证据](../08-expert-service/service-current-pending-catalog/README.md) |
| Pending package Back → catalog | [运行证据](../08-expert-service/service-current-pending-catalog-return/README.md) |
| Authenticated More → Me before service entry | [运行证据](../08-expert-service/service-current-pending-home/README.md) |
| Catalog Back → home | [运行证据](../08-expert-service/service-current-pending-home-return/README.md) |
| Close payment form without paying → order remains resumable | [运行证据](../08-expert-service/service-current-pending-order-closed/README.md) |
| Existing order GET 503 → package Snackbar | [运行证据](../08-expert-service/service-current-pending-order-error/README.md) |
| Open order feedback timeout → resume available | [运行证据](../08-expert-service/service-current-pending-order-error-dismissed/README.md) |
| Resume existing order with GET pending → opening label | [运行证据](../08-expert-service/service-current-pending-order-opening/README.md) |
| Retry existing order → sandbox card form | [运行证据](../08-expert-service/service-current-pending-order-resumed/README.md) |
| Pending order → package resume footer | [运行证据](../08-expert-service/service-current-pending-package/README.md) |

## 验证与后续

10 项严格采集通过（不更新 Golden），包含时间线事件像素回归断言；全仓静态检查通过。[严格运行](runs/20260914T010127-targeted/capture.log)、[静态检查](service-current-analyze.log)、[完整性检查](service-current-final-verify.log)。测试文件为 `test/modules/services/service_current_inventory_test.dart`。

采集器补充回归使用妈妈休息、宝宝发育日期与当前通知权限三组实际链，共 7 项通过、3 项失败。所有成功采集的 216 份窗口及 135 张长图（合计 351 张）与原证据逐像素一致。3 项失败均发生在回到已改版 More 时对比旧窗口基线，发生于长图处理之前；未更新旧基线或覆盖原报告，不能记为整组通过。[回归日志](scroll-geometry-regression.log)、[逐项统计](scroll-geometry-regression-summary.json)。

新建购买的资格判断、卡片校验、验证/拒付/成功、时间线各种事件与内部动作、当前预约和信息采集的完整状态仍见 [服务逐控件清单](SERVICE-CONTROL-COVERAGE.md)。历史截图存在不等于当前新布局已完整覆盖；全 App 仍为 **NOT_PROVEN**。
