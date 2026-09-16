# PDF 阅读：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

共享媒体页面的标题与返回结构，文档舞台保留实际 PDF 页面、缩放与分页；页间仅用弱阴影。页码/加载进度置工具区域，错误时保留返回与重试。

## 交互与状态验收

验证多页、长页、缩放、加载失败、授权失败及从文档回到原入口。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/media/presentation/media_viewer_page.dart`；入口：`/media-viewer`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
