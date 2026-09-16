# 消息操作：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

依附选中消息的轻量菜单；沿用 Agent 的淡紫表面、深紫文字与细线图标，14 圆角，至少44触控。长按、右键、辅助功能消息操作或 Shift+F10 打开。复制保留正文原始换行与 Markdown，只有现有运行状态允许时显示重试；当前没有删除接口，不展示删除。

## 交互与状态验收

核对用户正文、历史及当前回复；生成、停止请求和等待确认期间不开放菜单。无正文的附件或系统状态提示不提供复制。菜单关闭后回到消息焦点，复制成功或失败均反馈；会话内容变化后旧菜单不能执行复制或重试。验证320/390/430与1x/2x、短屏滚动、系统返回及键盘入口。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/agent_hub/agent_hub_page.dart`；入口：`/`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
