# 咨询行动详情与反馈：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

沿用统一底部 ProductFlowDialog，固定行动标题和关闭，下方显示已发布行动说明、分类、时限与实际安排日期。我的进度用现有四项单选 chip；只在用户明确选择后调用真实反馈 API。窄屏自动换行，长内容滚动。

## 交互与状态验收

验证打开不自动更新、状态切换、提交中禁止关闭和重复选择、结果未确认保留原版本重试、方案被替代后重新载入、完成状态由真实响应更新。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/modules/services/presentation/consultation_summary_page.dart`；入口：`/services/appointments/:appointmentId/summary`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
