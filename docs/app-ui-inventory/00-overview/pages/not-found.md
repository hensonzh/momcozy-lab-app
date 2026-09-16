# 无效路由提示

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`not-found`
- 范围：fallback
- 入口：无效深链 / errorBuilder
- 路由：Navigator／条件入口，见来源
- 实现：[momcozy_app.dart](../../../../lib/app/momcozy_app.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 未找到页面
- 返回

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 未找到页面 | [not-found](../../10-global-modals/not-found/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 返回 | [not-found](../../10-global-modals/not-found/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../10-global-modals/not-found/default.png) · [入口及前驱](../../10-global-modals/not-found/README.md) | 1 | unknown route shows a recoverable page at 390.0/1.0 |

## 实际操作链与状态依据

[ENTRY-STATUS.md](../ENTRY-STATUS.md)
