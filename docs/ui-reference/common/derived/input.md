# 输入、选择与日期时间弹窗：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

选项控件沿用设计工程 .form-card select、日记分组选项及统一表单规则。日期和时间弹窗缺少独立稿件，按统一主题衍生：普通字号保留日历和钟面；大字号日期采用输入模式，时间使用可滚动弹窗，小时与分钟纵向排列，按本地化保留上午/下午或24小时制。错误就近显示，取消和确认保持可见，不压缩用户字号。减少动态效果时弹窗直接显示。

## 交互与状态验收

验证320/390/430与1x/2x、短屏和键盘；检查日期边界、无效时间、12点与午夜、时区转换、取消和系统返回。日期范围与保存条件由原页面提供，不因组件适配改变。选项仍验证单选、多选、互斥与禁用状态。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/shared/widgets/choice_field.dart`；入口：`各表单`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
