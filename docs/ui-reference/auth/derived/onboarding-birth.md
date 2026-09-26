# 分娩资料：衍生设计

用户 2026-09-12 确认：缺少独立稿件的页面按已确认的登录设计和统一组件规范补齐，并标为衍生设计。仅用户 App；IBCLC 单独登记。

## 可追踪依据

- [common/design-system.md](../../common/design-system.md)
- [source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md](../../source/me-ui-optimization/02-approved-system/生活陪伴型-design-system.md)
- [source/src/components/UI.tsx](../../source/src/components/UI.tsx)
- [auth/reference/user-approved-login.png](../../auth/reference/user-approved-login.png)

## 页面结构与视觉规则

同一步骤框架中以连续表单展示现有分娩方式、本次宝宝数量及按条件出现的既往剖宫产史；可选字段保持可跳过语义，Save and start 是唯一主按钮。 Step-purpose and long explanatory copy use the shared paragraph leading of 1.55; titles and controls keep their approved roles.

2026-09-25 用户口径补充：既往剖宫产仅指本次分娩之前。首次分娩不提问，提交时为 `false`；第二次及之后才显示“本次分娩之前是否曾剖宫产”的问题。本次分娩方式与既往史不得混同。

## 交互与状态验收

验证字段选择、暂不回答、保存中、服务端失败与返回编辑。

共同验收：320/390/430 宽度、字号放大、SafeArea、可滚动内容、键盘/焦点、错误恢复。保持既有 API 和业务条件。

原生实现：`lib/features/onboarding/presentation/onboarding_page.dart`；入口：`/onboarding`。业务字段以原生契约为准，视觉以本衍生规范及上列依据为准；Figma 嵌入图尚待替换。
