# 首次使用加载与重试：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

沿用首次使用的暖白全屏容器与统一加载反馈；失败显示简短说明和重试，不新增独立欢迎页或改变 onboarding 门禁。

## 交互与状态验收

验证首次请求、失败重试、已有资料用户进入正确阶段。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/onboarding/presentation/onboarding_page.dart`；入口：`/onboarding /avatar/create /avatar/review`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
