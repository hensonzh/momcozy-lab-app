# 验证邮箱：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

认证页同一内容列内展示说明、邮箱、真实8位邮件验证码及流程所需密码；提交与重发分清主次，反馈紧邻表单。返回可修改邮箱，不展示固定测试验证码。

## 交互与状态验收

验证错误/过期代码、重发冷却、提交禁用、邮件确认与成功登录。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/auth/presentation/auth_page.dart`；入口：`/login`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
