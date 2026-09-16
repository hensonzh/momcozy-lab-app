# 结构化工具结果：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

衍生自 UserApp.tsx 推荐服务卡与 styles.css recommendation-card：12 内边距、12 圆角、细边框、34 图标容器、18 图标、14 标题、11/1.45 正文、44 最小按钮触控。统一 Agent 淡紫表面与强调色。原稿仅覆盖服务推荐；原生咨询、动作评估、通用结果、不支持内容按同一组件扩展。咨询保留真实顾问信息、说明、用户同意及服务入口；没有价格、天数和次数字段时不补造。通用状态置标题下方并允许换行，多动作纵向排列；不支持内容提供可理解说明。

## 交互与状态验收

验证320/390/430及1x/2x、对话窄列与滚动；无回调时禁用操作，咨询同意前禁用且 consultId 变化后清除同意；保留 /services 与 motion-assessment 路由及查询参数。截图和可控回调只验证 UI 边界，不代表咨询已创建或远程工具完成。原稿截图与计算样式位于 evidence/agent-cards/design-recommendation.png、design-metrics.json。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/agent_hub/artifacts/agent_artifact_panel.dart`；入口：`/`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
