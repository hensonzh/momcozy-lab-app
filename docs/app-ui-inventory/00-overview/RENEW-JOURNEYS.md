# 继续支持：已结束服务到续购的正式入口链

从已登录 More 页点击 Me，在妈妈首页的已结束服务卡中进入“服务进度”，再点击“继续支持”。使用正式 App、GoRouter、MotherHomePage、ServiceTimeline、ServiceRenewPage、购买弹窗和 Care Repository；仅 HTTP、会话与原生依赖隔离。原服务与新购买服务使用不同订单及 episode，原服务购买日期早于结束日期，未发起远端订单、支付或预约。

本轮新增 **21 个状态、37 个尺寸/字号窗口、12 张完整长图变体**，5 项严格测试通过。主购买/返回和待付款/错误重试同时覆盖 393/1x、320/2x；加载、空态、刷新和禁购在 393 上验证。常规宽度的主图均能一屏容纳内容，12 张长图属于窄屏大字号变体。没有修改生产代码或采集器。

## 实际操作结果

1. 已结束服务仍显示在妈妈首页；服务进度页显示已使用全部咨询次数，出现“继续支持”。点击进入 `/services/episodes/completed-episode/renew`，原套餐被默认高亮，四个方案按实际目录展示。
2. 选择原套餐打开购买前确认；关闭弹窗不创建订单，已选卡片高亮保留。重新选择、填写所在州并确认后创建隔离测试订单，进入现有付款表单。
3. 模拟支付成功只创建新服务，原服务保持 completed；点击“开始预约”进入新服务实际 booking 路由和预约前确认。关闭确认后返回续购列表，原套餐 CTA 已变为“查看我的服务”。
4. “查看我的服务”进入新服务进度；依次返回续购列表和原已结束服务进度页。截图和路由断言区分两个 episode，不把新服务覆盖成原服务。
5. 存在同套餐待付款订单时显示“继续付款”；订单读取挂起时全部方案按钮禁用。读取失败后恢复操作并显示顶部错误。重试进入同一订单的支付表单，关闭后仍可续付，测试断言未重复调用创建订单接口。
6. 首次目录加载、读取失败、重试后无方案、刷新恢复方案、下拉刷新为购买未开放均有截图。未开放时四个购买按钮禁用；没有用静态预览替代正式入口。

## 状态与前驱

| 状态 | 实际操作 / 条件 | 截图、入口与长图 |
| --- | --- | --- |
| active-progress | View current service → actual newly purchased progress | [证据](../08-expert-service/renew-journey-active-progress/README.md) |
| active-return | New service progress back → renewal list | [证据](../08-expert-service/renew-journey-active-return/README.md) |
| booking | Purchase success → actual new service booking/precheck | [证据](../08-expert-service/renew-journey-booking/README.md) |
| completed-progress | More → Me → completed service progress; continue support CTA | [证据](../08-expert-service/renew-journey-completed-progress/README.md) |
| completed-return | Renewal back → original completed service timeline | [证据](../08-expert-service/renew-journey-completed-return/README.md) |
| eligibility | Choose highlighted package → existing purchase eligibility dialog | [证据](../08-expert-service/renew-journey-eligibility/README.md) |
| empty | Retry returns no packages → empty support list | [证据](../08-expert-service/renew-journey-empty/README.md) |
| empty-refreshed | Refresh plans → catalog restored | [证据](../08-expert-service/renew-journey-empty-refreshed/README.md) |
| list | Completed timeline continue support → original package highlighted in actual renewal route | [证据](../08-expert-service/renew-journey-list/README.md) |
| load-error | Catalog error → retry | [证据](../08-expert-service/renew-journey-load-error/README.md) |
| loading | Continue support → catalog HTTP pending | [证据](../08-expert-service/renew-journey-loading/README.md) |
| order-error | Order read fails → scroll to top → inline open error and selectable packages | [证据](../08-expert-service/renew-journey-order-error/README.md) |
| order-loading | Continue payment → order read pending, package buttons disabled | [证据](../08-expert-service/renew-journey-order-loading/README.md) |
| order-resumed | Retry package → existing payment dialog without creating duplicate order | [证据](../08-expert-service/renew-journey-order-resumed/README.md) |
| paid | Sandbox payment succeeds → new service; original remains completed | [证据](../08-expert-service/renew-journey-paid/README.md) |
| payment | Choose state and confirm → new sandbox order and card form | [证据](../08-expert-service/renew-journey-payment/README.md) |
| pending-closed | Close payment → pending order stays resumable | [证据](../08-expert-service/renew-journey-pending-closed/README.md) |
| pending-listed | Completed service renew → pending matching order exposes continue payment | [证据](../08-expert-service/renew-journey-pending-listed/README.md) |
| purchase-disabled | Pull to refresh receives disabled payment mode → buttons disabled | [证据](../08-expert-service/renew-journey-purchase-disabled/README.md) |
| purchase-return | Booking back → renewal list now offers view current service | [证据](../08-expert-service/renew-journey-purchase-return/README.md) |
| selection-cancelled | Close eligibility → selected card retained without creating an order | [证据](../08-expert-service/renew-journey-selection-cancelled/README.md) |

## 验证与视觉检查

- [最终严格采集](runs/20260913T150638-targeted/capture.log)：5 PASS；采集时没有更新 Golden 或使用容差。
- [静态检查](renew-journey-analyze.log)：两个测试/fixture 文件 No issues found；两文件格式检查无变化。
- [逐图 SHA-256](renew-visual-review/sources.json)：49 张原始图片，分成 60 个连续片段、7 张联系表逐项查看。复采只改变原服务日期对应的 4 张进度窗口，这 4 张已单独重新查看，其余 45 张哈希不变。
- 窄屏长图完整保留四个方案、付款的银行卡/有效期/安全码/邮编/支付与取消按钮、预约前确认的紧急风险选项和继续按钮。浮层长图只展开前景内容，保留原背景和弹窗标题。
- 窄屏从“继续付款”触发的订单错误出现在列表顶部，按钮所在窗口未必可见该错误；需向上滚动查看。本轮实际执行了该滚动，没有将不存在于当前窗口的提示标为即时可见。
- 卡号输入框使用横向滚动呈现内容；320/2x 未聚焦窗口只显示部分卡号，保留客户端原状，不当作纵向长图遗漏。
- 本轮未重新执行原生设备或外部支付验证。此前支付取消、拒绝、3DS、异步确认与预约后续的独立操作证据见 [服务流程](SERVICE-JOURNEYS.md)、[咨询流程](CONSULTATION-JOURNEYS.md)，不据此宣称续购中每个共享分支均已重复执行。

[联系表 01](renew-visual-review/sheet-01.png) · [联系表 02](renew-visual-review/sheet-02.png) · [联系表 03](renew-visual-review/sheet-03.png) · [联系表 04](renew-visual-review/sheet-04.png) · [联系表 05](renew-visual-review/sheet-05.png) · [联系表 06](renew-visual-review/sheet-06.png) · [联系表 07](renew-visual-review/sheet-07.png)

## 仍需继续的范围

本轮证明带 episode 参数的续购入口。无参数 `/services/renew` 已注册，并可被 Agent 通用内部链接映射和 dispatcher 识别；但还没有发布实际 artifact 并点击来源按钮的运行证据，仍保留为待遍历。`/media-viewer` 同样需要从实际 Agent 资料卡进入。续购选择其他方案、读取中返回、刷新失败后的恢复等剩余交互也未以本轮截图声称完成。全 App 的权限层、其它分支及全部长图最终审核继续按原目标执行。
