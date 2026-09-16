# 重置密码：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

认证内容列中依次为邮箱、8位邮件验证码、新密码；密码眼睛按钮与登录一致，主按钮说明重置任务。成功后明确返回登录，不伪造会话。

## 交互与状态验收

验证过期验证码、密码规则、密码显示切换、提交失败/成功和键盘滚动。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/auth/presentation/auth_page.dart`；入口：`/login`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
