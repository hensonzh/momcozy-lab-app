# 错误与重试：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

危险色仅标识错误；正文解释可恢复原因，提供与失败动作一致的重试。错误贴近字段或内容区域，不通过扩大空白分散布局。

## 交互与状态验收

验证网络、校验、权限、冲突和未知错误；重试成功后清除旧提示并保留有效输入。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/shared/widgets/product_feedback.dart`；入口：`各页面`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
