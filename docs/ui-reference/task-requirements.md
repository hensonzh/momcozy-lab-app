# Goal

以项目中的 **`momcozy-lab产品设计`** 作为当前 App UI/UX 的主要设计基准，对 App 全部页面进行系统性梳理和重构，使实际 App 与设计方案保持高度一致。

## 1. 建立 UI 参考库

首先完整梳理 `momcozy-lab产品设计` 中所有 App 页面，包括一级页面、二三级页面、弹窗、Bottom Sheet、空状态、加载状态等。

将每个页面整理为独立的**完整页面长图或可追踪的设计参考**，统一放入例如：

```text
docs/ui-reference/
```

建议按模块分类：

```text
auth/
mom/
baby/
agent/
schedule/
services/
profile/
common/
```

尽量保证一个页面对应一份完整参考，滚动页面优先整理成长图。

## 2. 建立页面映射

梳理当前 App 的所有页面和路由，并建立：

```text
设计页面 → 当前 App 页面 → Route
```

的对应关系。

在开始大规模修改前，先明确：

* 哪些页面已有对应设计；
* 哪些当前页面需要重构；
* 哪些页面缺失；
* 哪些旧页面已经废弃。

建议维护：

```text
docs/ui-reference/page-map.md
```

作为整个 UI 重构任务的进度和事实来源。

## 3. 提取统一 Design System

分析 `momcozy-lab产品设计` 中的公共视觉规则，并优先沉淀到项目现有 Theme / Design Token / Shared Component 中，包括：

* Color
* Typography
* Spacing
* Radius
* Shadow
* Icon
* Button
* Card
* Input
* Navigation
* Bottom Tab

避免每个页面独立硬编码样式。

## 4. 逐页对比并重构

按照页面映射逐一检查当前 App。

每个页面都需要对比：

* 页面结构；
* Header / Navigation；
* Padding / Gap；
* 字体；
* 颜色；
* 卡片；
* 圆角；
* 图标；
* 图片；
* Button；
* Bottom Tab；
* 各种交互状态。

执行流程：

```text
设计参考
→ 当前页面
→ 找出差异
→ 修改
→ 运行验证
→ 再次对比
```

不要只修改颜色和圆角，要保证整体布局和视觉层级一致。

优先顺序：

```text
Global Theme
→ Navigation / Bottom Tab
→ 一级页面
→ 公共组件
→ 二三级页面
→ Modal / Sheet / 各种状态
```

## 5. 工程约束

本任务以 **UI/UX 重构** 为主。

原则：

* `momcozy-lab产品设计` 优先于当前旧 UI；
* 不随意修改 Backend/API/核心业务逻辑；
* 新设计需要不同展示结构时，可调整 ViewModel/UI Model；
* 重复 UI 优先抽成共享组件；
* 新版本完成后，不长期保留 `Old / New / V2 / Copy` 双版本代码；
* 清理确认无引用的旧 Component、Style、Asset、Mock Data；
* 保证 Safe Area、键盘、滚动、小屏和不同设备尺寸正常。

## 6. 验证要求

每完成一个页面，都要同时验证：

```text
功能正确
+
视觉正确
```

不能只以 Build Passed 作为完成标准。

应尽可能通过：

```text
设计参考
vs
实际 App Screenshot
```

进行视觉对比并继续修正。

## 7. 最终验收

完成后应满足：

* 当前 App 主要页面均有对应设计参考；
* 页面映射完整；
* App 使用统一 Design System；
* 公共组件风格统一；
* 当前页面与 `momcozy-lab产品设计` 高度一致；
* 原有核心业务功能正常；
* 无明显旧 UI / 新 UI 混用；
* Build 正常，无新增明显运行错误。

最终输出：

```text
Total Pages
Completed
Need Review
Missing Reference
```

并列出仍无法自动解决的问题。

## 核心原则

不要凭记忆批量重构。

**每开始重构一个页面，都重新查看该页面对应的 `momcozy-lab产品设计` 参考，再修改当前实现。**

最终目标是：

> 当前 App 的每个页面都能找到明确的设计参考，并在布局、组件、视觉语言和交互体验上与 `momcozy-lab产品设计` 保持一致。
