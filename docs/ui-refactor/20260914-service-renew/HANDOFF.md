# 继续支持 / 续购

完成现有 32 个源截图条目对应的续购页面展示，覆盖 `/services/renew` 与带 episodeId 的续购入口。先完成并检查 [Figma](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=208-1108)，再修改 Flutter。[14 个画板](figma-nodes.json) 包含方案列表、选中、已有服务、待付款、订单读取与失败、购买禁用、空态、离线、首次加载、大字号、短屏及购买前确认。

页面采用妈妈页的奶油底色、玫瑰按钮和薄荷信息卡。方案卡复用 MomServicePackageFacts、MomServicePrice，显示现有方案说明、咨询次数、支持天数及明确币种。已有服务显示真实状态、当前阶段、剩余次数及匹配的专家身份；未分配时明确显示待分配专家。订单打开错误放在对应方案的按钮旁，便于长页面滚动后看到提示并重试。

购买和订单恢复逻辑未改。已有服务仍优先进入服务进度；可恢复订单沿用原订单；选择新方案仍先进行购买前确认。忙碌、刷新与未开放购买时保持原禁用条件，暂停或待开通服务在购买关闭时仍可查看。购买弹窗复用已完成的设计，不重复重构。

验证结果：

- [续购专项](design-tests.log) 14 项通过，覆盖 320/390/430 宽度、1×/2× 字号、320×568 短屏滚动、首次加载、已有服务身份与状态、付款恢复失败及重复点击保护、刷新期间禁用、购买成功后预约。
- [联测](joint-tests.log) 70 项通过，包含续购、购买、服务目录与服务进度。[静态分析](analyze.log) 两个文件无问题。
- [行为对比](behavior-checks.json) 确认 `_select`、按钮禁用与动作优先顺序、初始选中方案及刷新保护保持不变。
- 视觉检查 [Figma 列表](figma/list.png)、[已有服务](figma/ongoing.png)，以及 [Flutter 列表](verified/renew-list-390.png)、[已有服务](verified/renew-ongoing-390.png)、[大字号](verified/renew-list-320-2x.png)、[订单错误](verified/renew-order-error-390.png)、[短屏加载](verified/renew-short-loading-320-2x.png) 和 [短屏已有服务操作](verified/renew-short-owned-paused-320-2x.png)。部分截图保留测试实际滚动位置。

[源条目](source-inventory.json)、[源图指纹](source-image-hashes.json) 与 [实现指纹](implementation-hashes.json) 已保存。32 个条目包括购买弹窗下方的续购页面，付款弹窗继续使用已有验证结果；不代表重新采集了这 32 个原生入口。没有修改 Session A 截图，没有运行清单生成测试，未构建或发布 App。

当前观察到 2675 个截图状态，本轮未发现增量；增量队列仍有 42 个 pending 条目，未列入队列的其他页面也不据此视为完成。整体任务保持 active，后续继续咨询入口的首次加载与错误状态，以及各自有截图依据的未处理页面。
