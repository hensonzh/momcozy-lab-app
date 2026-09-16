# 内部邀请码入口：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

仅在现有内部渠道条件下显示；使用通用认证标题、邀请码输入、单一主按钮及失败反馈。不把内部入口加入普通消费者登录页。

## 交互与状态验收

验证渠道门禁、空码/错误码、请求中、成功会话和恢复登录状态。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/auth/presentation/invite_auth_page.dart`；入口：`/login (internalInviteOnly)`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
