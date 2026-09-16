# 页面不存在：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

简洁标题、原因说明和返回首页按钮；以统一空状态布局承载，不输出内部 route/debug 参数作为产品文案。

## 交互与状态验收

验证未知路由、无历史可返回和已登录/未登录导航边界。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/app/momcozy_app.dart`；入口：`/404`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
