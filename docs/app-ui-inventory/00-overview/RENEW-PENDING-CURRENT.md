# G11：续购待付款与恢复

补齐待付款列表、读取订单等待 2 张当前图，打开订单失败复用 G06 已有图。一个现有场景严格通过，3 张完整长图已逐段检查，均包含全部 4 个套餐和最后操作区。

续购列表已有待处理订单 → 继续付款 → 打开订单失败 → 再次继续付款，读取期间所有套餐按钮禁用 → 读取成功打开原订单支付页 → 关闭购买 → 返回原续购列表，上滚找到第一张卡的继续付款入口。确认未创建新订单。付款流程与关闭后的相同列表复用 [G06 与原路由链](RENEW-CURRENT.md)，本轮不另拍重复返回图。

| 具名状态 | 完整图 |
| --- | --- |
| renew-pending-listed-390.long | [查看](../raw/test/goldens/design_system/renew-pending-listed-390.long.png) |
| renew-order-loading-390.long | [查看](../raw/test/goldens/design_system/renew-order-loading-390.long.png) |
| renew-order-error-390.long | [查看](../raw/test/goldens/design_system/renew-order-error-390.long.png) |

本次实际点击生产页面及购买弹窗，仓储使用隔离实现；原路由来源继续由 RENEW-JOURNEYS 保留，不将回调测试冒充新 App 路由。首次新增返回断言未找到已滚出视口的第一张套餐卡；实际读取当前文本后改为向上滚动查找，再严格通过。原订单错误视口与 G06 相同。未修改产品代码或扩大套餐／错误码矩阵。

[严格运行](runs/20260914T084835-g11-renew/strict-capture.log) · [逐图与长图测量](runs/20260914T084835-g11-renew/reviewed-images.json) · [源码与范围](runs/20260914T084835-g11-renew/g11-audit.json) · [静态分析](runs/20260914T084835-g11-renew/analyze.log)。
