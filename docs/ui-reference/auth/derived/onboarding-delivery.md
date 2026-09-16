# 分娩日期：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

复用基本资料步骤结构；日期选择是唯一主要字段，理由说明放在标题下。日期弹窗使用统一 Theme，主操作为 Continue。 Step-purpose and long explanatory copy use the shared paragraph leading of 1.55; titles and controls keep their approved roles.

## 交互与状态验收

验证未选日期、可选范围、取消选择、返回与已保存日期恢复。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/onboarding/presentation/onboarding_page.dart`；入口：`/onboarding /avatar/create /avatar/review`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
