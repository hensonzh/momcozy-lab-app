# 对话图片与全屏预览：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

消息内图片依据 UserApp.tsx 的 AgentMessageAttachments 元信息行：文件名11、大小9、间距6、圆角11；保留原生已支持的鉴权缩略图，作为20px预览替代通用图片图标，整行至少44可点击。全屏缺少独立原稿，沿用 common/derived/media.md：暖色返回标题栏、完整标题语义、深色舞台，缩放与平移只作用于图片；加载和失败不能覆盖标题。

## 交互与状态验收

验证320/390/430与1x/2x，长名称、缩略图鉴权、点击后读取原图、空响应、拒绝/离线、损坏图片、重试、缩放、系统返回和关闭。没有原图读取能力时给出返回重选说明，不伪造成功。保留现有图片读取 API 和账号隔离。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/agent_hub/presentation/agent_image_previews.dart`；入口：`/`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
