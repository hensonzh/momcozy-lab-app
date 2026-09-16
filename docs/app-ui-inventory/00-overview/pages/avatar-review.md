# 数字形象确认

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`avatar-review`
- 范围：configured
- 入口：开启 onboarding 后按引导进入
- 路由：/avatar/review
- 实现：[onboarding_page.dart](../../../../lib/features/onboarding/presentation/onboarding_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 候选选择
- 默认确认
- 激活中
- 失败
- 完成

## 归属弹窗／浮层

avatar-dialogs

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 候选选择 | [onboarding-review-selected](../../01-auth/onboarding-review-selected/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 默认确认 | [onboarding-default-confirm](../../01-auth/onboarding-default-confirm/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 激活中 | [onboarding-avatar-short-confirm-busy](../../01-auth/onboarding-avatar-short-confirm-busy/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 失败 | [onboarding-avatar-short-confirm-error](../../01-auth/onboarding-avatar-short-confirm-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 完成 | [onboarding-reading-activation](../../01-auth/onboarding-reading-activation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/onboarding-review-selected/default.png) · [入口及前驱](../../01-auth/onboarding-review-selected/README.md) | 1 | onboarding avatar review at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-review-footer/default.png) · [入口及前驱](../../01-auth/onboarding-review-footer/README.md) | 1 | onboarding avatar review at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-avatar-short-confirm-error/default.png) · [入口及前驱](../../01-auth/onboarding-avatar-short-confirm-error/README.md) | 1 | avatar short screen retries thumbnail and locks confirmation |
| [图](../../01-auth/onboarding-avatar-short-confirm-busy/default.png) · [入口及前驱](../../01-auth/onboarding-avatar-short-confirm-busy/README.md) | 1 | avatar short screen retries thumbnail and locks confirmation |
| [图](../../01-auth/onboarding-reading-activation/default.png) · [入口及前驱](../../01-auth/onboarding-reading-activation/README.md) | 1 | onboarding reading 390.0/1.0 |
| [图](../../01-auth/onboarding-avatar-short-image-error/default.png) · [入口及前驱](../../01-auth/onboarding-avatar-short-image-error/README.md) | 1 | avatar short screen retries thumbnail and locks confirmation |
| [图](../../01-auth/onboarding-review/default.png) · [入口及前驱](../../01-auth/onboarding-review/README.md) | 1 | onboarding avatar review at 390.0 / 1.0 |

## 实际操作链与状态依据

[CONFIGURED-PAGES-CURRENT.md](../CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT.md](../CONFIGURED-SUBMISSION-CURRENT.md)

CONFIGURED-PAGES-CURRENT.md：配置条件和当前代表图已核对；默认入口不计缺失，历史其它状态版本见 G11。

## 已有改版运行图，优先复用

- [20260914-onboarding-avatar](../../../ui-refactor/20260914-onboarding-avatar/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
