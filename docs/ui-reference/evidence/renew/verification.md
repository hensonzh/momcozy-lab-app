# 继续支持与续购

2026-09-12，用户 App。续购原稿为 UserApp.tsx 的 RenewPage（3899–3904 行），公共 PageIntro、package-list / package-card / package-top 见 UI.tsx 与 styles.css。开始前已重新读取当前源码，捕获 renew-viewport.png 和展开内部滚动区的 renew-full.png。自主管理与转介也各自补捕 viewport/full 参考，未执行任何购买或转介提交。

## 实现

新增 ServiceRenewPage，以设计中的返回、继续支持标题、纵向方案卡、右侧价格、支持天数与次数、小型选择按钮组成。关联服务的 packageId 或本次选择决定强调卡，不凭空标注推荐方案。价格使用当前目录货币及金额。按钮保留 44 最小触控高度，因此卡片比设计原始 34 高按钮略高；大字号变为名称/价格纵向，内容滚动。首次视觉检查发现价格位于中间，已修改约束并重新生成截图，现靠右显示。

新增 /services/renew 和 /services/episodes/:episodeId/renew。已结束（非 ongoing）服务时间线显示“继续支持”，不修改原服务状态与额度。ongoing 服务仍使用现有预约入口。

选择方案复用 showServicePurchase 和 ServicePurchaseController：未创建订单时打开购买前确认，不自动创建订单；待付款订单读取同一 orderId 后继续付款，不重复创建；已有 ongoing 服务进入原服务进度，不改变原生购买规则。购买成功使用服务端返回的新 episode 进入预约流程。关闭弹窗后刷新目录与订单，打开期间禁用其它选择，异步失败显示可重试提示。PaymentMode.disabled 禁止新购买，目录空、载入错误与刷新分别有明确状态。

## 验证与边界

新续购测试 10 项覆盖 320/390/430 和 1x/2x 字号、选择与关闭不创建订单、已选视觉、真实生产购买控制器通过受控仓储完成沙盒支付及预约回调、待付款恢复、读取失败重试、等待读取时禁止重复选择、已有服务跳转、未开放/空目录/离线恢复。服务进度测试另增 1 项，验证已结束服务的续购入口，路由契约补上两个新路径。

整合回归 305 项通过；最后的返回文字对齐调整另跑续购 10 项，更新截图。flutter analyze 无问题。实际 Flutter 图片为 test/goldens/design_system/renew-{list,selected,eligibility,ongoing,order-error,disabled,empty,offline}-*.png。目视检查 390 列表/已选、320 双倍字号和读取订单错误；300 多项测试仅证明所覆盖行为，不代表支付平台或真实咨询链路端到端验收。

新页面使用既有购买协议和生产控制器；测试仓储不会向外部支付平台扣款。原生模拟器读取本地 API 的真实目录，只进入购买前确认，不提交确认、创建订单或付款。构建、安装、截图与 UI 树记录见同目录。

## 仍未实现的相邻流程

自主管理：原稿中“Care Plan 已保留”和“保存下一步”没有实际读取或保存逻辑；原生有日程、咨询总结和授权入口，但没有与该操作对应的转换/保存契约。
转介：原稿通过 setSubmitted(true) 切换文案；当前后端和 App 没有可用的转介提交接口/仓储，无法证明请求真正保存和送达。
这两项保留独立参考与 Need Review，不新增模拟成功页面，也不把它们算作续购完成内容。后续需要产品契约与后端接入才能关闭缺口。

原生验证完成：普通 APK 构建 9.0 秒、安装成功；/services/renew 显示本地 API 四个方案及金额，选择首个方案打开“购买前确认”，未选择州、未勾选确认、未创建或支付订单。关闭后返回 Mia 主页，登录保持。证据为 native-list、native-eligibility、native-restored-home 的 PNG/XML。
