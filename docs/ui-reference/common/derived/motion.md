# 动作评估：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

外层标题、说明、操作按钮使用统一暖色主题；相机舞台及骨架颜色保留辨识语义。准备、权限、进行中、结果和失败各有单一主操作，操作栏不遮挡关键人体画面。

## 交互与状态验收

验证权限拒绝与恢复、相机不可用、评估中断、结果、语音冲突和小屏底部安全区。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/motion_assessment/presentation/motion_assessment_page.dart`；入口：`Agent 动作入口`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
