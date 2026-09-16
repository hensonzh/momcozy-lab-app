# 独立日记编辑页：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

原生 /me/diary 是按 section 参数打开的当天日记编辑页，并非历史列表。将 HomePage 已确认的暖米白日记弹窗、深棕标题、三类切换、可滚动字段和保存区延伸为独立路由；沿用 mother_diary_editor，不复制另一套表单。具体组件参考：[休息日记](../../mom/diary-rest.md)、[身体日记](../../mom/diary-body.md)、[心情日记](../../mom/diary-mood.md)，源码 HomePage 见 source/src/pages/UserApp.tsx。

## 交互与状态验收

验证 rest/body/mood 参数、默认分类、返回首页、校验、保存失败草稿保留、键盘与短屏。日记历史入口由实际归档页面负责，不增设虚构历史列表。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/modules/mom/presentation/mother_diary_page.dart`；入口：`/me/diary`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准。
