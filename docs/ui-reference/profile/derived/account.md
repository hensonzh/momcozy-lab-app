# 账号管理与删除：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

返回标题栏，下方按账号信息、关联方式、退出和删除账号分组；暖白卡片18圆角。危险操作单独置底，不与一般操作使用相同强调色。密码二次验证和删除确认使用统一弹窗。

## 交互与状态验收

验证读取失败、关联 Google、退出、重新认证、取消删除和删除请求结果；不将测试删除实际发送至真实账号。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/auth/presentation/account_page.dart`；入口：`/account`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
