# 保存与撤销反馈：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

轻量成功说明或短时 snackbar；使用绿/中性色，撤销为清晰文字按钮。反馈不遮挡表单主操作，重要结果不能只依赖短时提示。

## 交互与状态验收

验证保存成功、撤销有效/失效、重复操作、屏幕阅读器播报和页面离开。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/modules/baby/presentation/baby_saved_feedback.dart`；入口：`各表单`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
