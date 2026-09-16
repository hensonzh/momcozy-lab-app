# 购买确认及付款状态复核 — 2026-09-12

重新读取设计工程 `src/pages/UserApp.tsx` 的 ServiceDetailPage（3313–3453 行）及 `src/styles.css` 的 eligibility / stripe / modal 样式，查看原始 state-25 至 state-30 图片。使用独立浏览器上下文重新运行设计稿的六个状态，清空该上下文的演示购买数据，阻断 API 和站外请求；新截图为 `services/state-{25..30}-viewport.png`，来源登记在 capture-manifest.json。

## 布局与状态

- 购买确认与付款共用 ProductFlowDialog：底部对齐，18 外边距、24 圆角、白色表面，固定标题和关闭入口，正文可滚动。保留 44 触摸目标；窄屏及大字号时有效期和安全码纵向排列。
- 购买确认采用浅灰方案卡、州选择、琥珀色未覆盖提示、确认复选框和全宽主按钮。未选择州、未确认、州不受支持时不能继续；实际适用范围来自 catalog 和已有服务端检查，不照搬设计演示中的默认 CA。
- 付款采用绿色测试说明、方案和金额、分组卡片输入、粉色拒付提示、紫色验证提示及绿色成功反馈。验证中保留本次输入并锁定，恢复既有验证订单不会凭空展示一张新卡。保留当前业务已有的取消付款和稍后预约动作。
- 测试卡只决定模拟结果，不向接口发送卡信息，因此文案明确标为模拟验证。真实 Stripe 订单使用原有 Checkout 跳转和订单查询，按订单自身 paymentMode 恢复，不用模拟表单收集真实卡信息。
- 已付款但权益尚未返回时仅查询结果，不重新支付；已取消订单不提供付款入口。购买成功返回实际 CareEpisode，交由原调用方继续预约。

## 必要的恢复修正

后端契约已包含 stripe，但 Dart paymentModeWire 原先缺少该值，导致现有真实订单不能解码；补齐映射并加回归。重新获取 Checkout 失败前清空旧地址，避免误开失效链接。打开外部页面失败给出可恢复提示，查询成功后清除过期的打开失败提示。上述缺陷均先由测试复现，再修正。未修改后端、价格、订单归属、API、支付核心协议。

## 自动验证

`test/modules/services/service_purchase_test.dart` 共 23 项：320/390/430 宽度与 1x/2x 字号完整走过确认、州不支持、支付、拒付、验证、成功及返回预约结果；320×568 和键盘验证错误、忙碌时硬件返回与关闭禁用、网络结果不确定时保留原卡及原付款结果重试；Stripe 打开失败/抛异常、旧链接失效、查询权益、已付无权益及两种模式的取消状态。

服务模块完整 87 项回归通过，`flutter analyze --no-pub` 无问题，本地 debug APK 构建及安装成功。日志和 APK 摘要在本目录。未验证生产 Stripe 扣款或银行真实 3D Secure 挑战。

视觉证据为 `test/goldens/design_system/purchase-{eligibility,unavailable,payment,failed,challenge,success}-{320,390,430}.png`、Stripe 打开失败截图，以及本目录原生 PNG/XML。查看截图后修正州选择未继承统一字体的问题。支付表单比设计稿多出的取消操作保留既有业务，小屏状态截图可能显示滚动下方；固定标题、滚动及动作可达性通过全流程检查。

## 原生本地环境边界

Mia 账号进入喂养安心详情，打开购买确认，选择 NY 并确认，显示未覆盖提示且继续按钮不可用；切换 CA 也不可用。读取同一本地服务端 catalog 确认 `payment_mode=sandbox`、`available_regions=[]`、`provider_count=0`（local-catalog.json）。这是当前没有可用测试专家导致的真实限制，UI 按契约阻止继续。支持州及所有付款分支由有 CA 测试专家的受控仓库验证，不能把它描述为原生付款链路已通过。

原生截图为 native-eligibility、native-unavailable、native-ca-unavailable；关闭后返回 Mia 首页，最后安装的 APK 包含最终验证操作布局。没有创建订单、产生扣款或更改专家/州配置。后续若要验证本地端到端预约与付款，需要另行准备合法的本地测试专家及可用时段，不能仅在 UI 放开按钮。
