# 图片与视频资料：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

外层返回标题栏沿用统一主题；媒体舞台使用深色中性底以保证画面可见，工具按钮保持44触控。标题和失败说明不覆盖主体，播放/暂停/全屏遵从原生语义。

## 交互与状态验收

验证加载、成功、格式不支持、过期授权、重试、全屏返回及暂停恢复。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/media/presentation/media_viewer_page.dart`；入口：`/media-viewer`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
