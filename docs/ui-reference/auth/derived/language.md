# 语言选择：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

从已确认登录稿右上角地球图标与语言文本进入；菜单采用统一浅色表面和选中标记，当前语言必须与实际支持范围相符。

## 交互与状态验收

验证打开/关闭、选中态、实际语言切换和不可用语言的明确反馈。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/auth/presentation/auth_page.dart`；入口：`/login`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
