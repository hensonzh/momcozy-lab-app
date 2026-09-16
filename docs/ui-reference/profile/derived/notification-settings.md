# 通知设置：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

返回标题栏；权限状态卡和系统设置入口在上方，服务通知偏好使用暖白分组卡与开关；类别标题14、说明13。营销说明单独弱化，不新增勾选或更改默认偏好。

## 交互与状态验收

验证加载、读取失败重试、权限未请求/拒绝/允许、偏好开关保存与失败、系统设置回跳、不支持设备、无营销默认订阅。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/notifications/presentation/notification_settings_page.dart`；入口：`/notifications/settings`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
