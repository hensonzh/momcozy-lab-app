# 原生资料卡与中文按钮

![当前原生界面](default.png)

- 入口：`/`
- 触发：Actual native Agent reply with four Chinese action labels
- 数据：本地合成数据与媒体资产；实际原生渲染。
- 验证范围：实际 Android App 路由；从 More 点击 Cozymate，发送问题并消费隔离 SSE；卡片按钮执行正式 dispatcher。业务/会话为测试依赖，媒体通过本地 HTTP 与实际 PDFium、Android 视频插件、图片解码器。
- 测试：`integration_test/agent_resource_inventory_test.dart`
- [原生截图元数据](../../native/resource-manifest.json)
- [当前交互窗口](../../native/resource-journey/native-resource-card.png)
- 起点：More → Cozymate → send question → SSE artifact card → actual action button

默认图由实际纵向滚动拼接，页头与固定底部各保留一次；当前交互窗口单独保留。PDF 放大后保留当前横向视窗，完整页宽请查看适配宽度的 PDF 第一页长图。[测量数据](../../native/resource-journey/native-resource-card-long.json)。
