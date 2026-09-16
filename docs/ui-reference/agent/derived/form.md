# 结构化表单：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

入口复用 Agent 淡紫结果卡，标题14、说明11、图标18与34容器，长文可换行。弹窗沿用 UI.tsx Modal 与公共主题：暖白表面、18标题、右上关闭，中部显示真实用途说明和 schema 字段。标签与输入14、字段间16、组间24、控件圆角12，分组采用统一中性色。正常高度固定页头和底部取消/唯一主提交；短屏、键盘或大字号时整体可滚动，拖动收起键盘。日期和长下拉选项允许换行，保留字段类型、必填、校验和真实工具结果。

## 交互与状态验收

验证320/390/430×1x/2x、320×568短屏加键盘、必填、日期/枚举、多行输入、取消后草稿恢复、提交中关闭/返回门禁、异常失败重试及重复提交保护；失败说明自动滚入可见区域。成功关闭弹窗，入口标记已提交并支持只读查看。原生截图使用可控提交回调，只验证 UI 和提交边界，不宣称远程工具已完成。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart`；入口：`/`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
