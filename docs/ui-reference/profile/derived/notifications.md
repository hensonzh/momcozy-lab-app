# 通知收件箱：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

返回标题栏与明确的设置入口，通知按时间排列为轻量列表。标题14、摘要13、时间11；未读同时用形态和字重区分。空、加载、失败复用公共反馈，底部不保留一级导航。

## 交互与状态验收

验证未读/已读、跳转目标、无效目标、分页/刷新、空列表和权限提示。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/notifications/presentation/notifications_page.dart`；入口：`/notifications`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
