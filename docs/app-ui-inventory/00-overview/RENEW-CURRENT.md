# G06：续购当前图与长图归档

本项完成：12 张现有设计状态：四个方案、选中、购买前确认、已有服务、暂停／待开通、购买未开放、空态、首次加载、离线及打开订单失败。共核对 12 张完整图，其中 8 张为测量滚动生成的完整长图。原有金图严格匹配，没有修改产品、测试用例或截图基线，没有增加尺寸／字号组合。

两个路由 `/services/renew` 与 `/services/episodes/:episodeId/renew` 共享同一页面；带服务 ID 时原套餐可预选，不增加独立页面数。正常路径沿用 [已结束服务 → 继续支持 → 购买／恢复付款 → 新服务与返回](RENEW-JOURNEYS.md) 的历史实际路由证据，不把本次回调测试冒充重新走完全部交易。

本次现有场景实际选择方案、关闭购买前确认、恢复已有订单、重试失败读取，以及点击已有服务入口。完整长图包含四张方案卡及最后按钮，暂停与待开通服务仍保留查看入口；购买未开放时其它方案禁用。购买和付款共享弹窗继续引用既有证据，不为两个续购路由复制一套图。

## 当前代表图

| 状态 | 完整图与上下文 | 范围 |
| --- | --- | --- |
| 尚未开放购买 | [图](../raw/test/goldens/design_system/renew-disabled-390.long.png) · [索引](../08-expert-service/renew-disabled/README.md) | 完整长图 |
| 购买前确认 | [图](../raw/test/goldens/design_system/renew-eligibility-390.png) · [索引](../08-expert-service/renew-eligibility/README.md) | 当前窗口完整 |
| 无可选方案 | [图](../raw/test/goldens/design_system/renew-empty-390.png) · [索引](../08-expert-service/renew-empty/README.md) | 当前窗口完整 |
| 全部续购方案 | [图](../raw/test/goldens/design_system/renew-list-390.long.png) · [索引](../08-expert-service/renew-list/README.md) | 完整长图 |
| 离线重试 | [图](../raw/test/goldens/design_system/renew-offline-390.png) · [索引](../08-expert-service/renew-offline/README.md) | 当前窗口完整 |
| 已有服务／待分配专家 | [图](../raw/test/goldens/design_system/renew-ongoing-390.long.png) · [索引](../08-expert-service/renew-ongoing/README.md) | 完整长图 |
| 继续付款读取失败 | [图](../raw/test/goldens/design_system/renew-order-error-390.long.png) · [索引](../08-expert-service/renew-order-error/README.md) | 完整长图 |
| 已选方案 | [图](../raw/test/goldens/design_system/renew-selected-390.long.png) · [索引](../08-expert-service/renew-selected/README.md) | 完整长图 |
| 四个方案完整长图 | [图](../raw/test/goldens/design_system/renew-short-last-package-320-2x.long.png) · [索引](../08-expert-service/renew-short-last-package/README.md) | 完整长图 |
| 首次加载 | [图](../raw/test/goldens/design_system/renew-short-loading-320-2x.png) · [索引](../08-expert-service/renew-short-loading/README.md) | 当前窗口完整 |
| 服务已暂停、仍可查看 | [图](../raw/test/goldens/design_system/renew-short-owned-paused-320-2x.long.png) · [索引](../08-expert-service/renew-short-owned-paused/README.md) | 完整长图 |
| 服务待开通、仍可查看 | [图](../raw/test/goldens/design_system/renew-short-owned-provisioningPending-320-2x.long.png) · [索引](../08-expert-service/renew-short-owned-provisioningPending/README.md) | 完整长图 |

## 证据边界与验证

- [共同定向验证](runs/20260914T080457-schedule-renew-current/capture.log)：18 个现有场景通过；[精确命令](runs/20260914T080457-schedule-renew-current/capture-command.json)。没有重跑全仓测试。
- [逐图范围与相关源码指纹](runs/20260914T080457-schedule-renew-current/g06-audit.json)：当前源码与改版实现指纹一致；全部本项图已目视检查。
- 当前页面以隔离仓储运行；系统键盘、真实支付和原生窗口不由本项证明。没有创建真实账号、订单或服务。
- G05／G06 关闭新版图归档与长图缺口，未宣称所有历史条目已变为当前版本。其它旧状态和共用组件差异仍在固定 G11 核对，不另增测试矩阵。
