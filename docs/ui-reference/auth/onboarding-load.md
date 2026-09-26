# 通用加载与重试（历史 onboarding 画板已停用）

2026-09-25：onboarding 不再定义独立的加载中和加载失败画板或截图。
运行时直接复用 `lib/shared/widgets/product_feedback.dart` 中的
`ProductLoadingView` 与 `ProductErrorView`；失败时保留「Try again」操作，
重新请求 `GET /v1/onboarding/me`，成功后进入资料表单。

回归测试：`test/features/onboarding/onboarding_generic_feedback_test.dart`。
Figma 01/02 画板已于 2026-09-25 在线删除，并在新标签页重新打开后确认不存在。过往截图仅作旧版本资料，不是当前验收基线。
