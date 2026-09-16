# 公共确认与丢弃：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

从设计工程 Modal 与统一主题衍生未保存修改确认：暖色弹窗包含离开标题、明确的丢弃后果说明、继续填写与确认离开两个动作。弹窗内容可滚动，大字号时按钮可纵向排列。日记保留放弃修改文案；其它入口沿用离开。保存结果不确定时明确提醒返回后刷新核对。

## 交互与状态验收

验证取消、系统返回和确认结果；取消必须保留草稿，只有确认才能继续离开。检查 320/390/430 与 1x/2x 的标题、说明、按钮和焦点。弹窗只返回用户选择，不自行保存或删除记录。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/shared/widgets/confirm_discard.dart`；入口：`各表单`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
