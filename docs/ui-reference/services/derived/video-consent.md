# 本次服务的视频咨询授权：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

复用 ProductFlowDialog 底部白色弹窗、18 标题、固定关闭与可滚动正文。解释授权用途，默认未勾选的明确同意选项和唯一确认主按钮；失败紧邻操作。只调整既有本次服务 video scope，完整全局隐私管理仍单列。

## 交互与状态验收

验证未勾选禁用、主动确认、请求中禁止关闭和重复提交、失败重试保持原版本、只写 video 授权、成功返回位置确认、不自动进入咨询室。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/modules/consultation/presentation/consultation_start_dialog.dart`；入口：`/services/appointments/:appointmentId/room`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
