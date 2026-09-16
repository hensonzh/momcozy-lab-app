# 数字形象创建

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`avatar-create`
- 范围：configured
- 入口：开启 onboarding 后按引导进入
- 路由：/avatar/create
- 实现：[onboarding_page.dart](../../../../lib/features/onboarding/presentation/onboarding_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 默认选择
- 照片
- 上传
- 生成中
- 失败
- 重试

## 归属弹窗／浮层

avatar-dialogs

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 默认选择 | [onboarding-required](../../01-auth/onboarding-required/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 照片 | [onboarding-required-source](../../01-auth/onboarding-required-source/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 上传 | [onboarding-upload-pending](../../01-auth/onboarding-upload-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 生成中 | [onboarding-generating](../../01-auth/onboarding-generating/README.md) · [onboarding-generation-handoff](../../01-auth/onboarding-generation-handoff/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 失败 | [onboarding-photo-error](../../01-auth/onboarding-photo-error/README.md) · [onboarding-request-error](../../01-auth/onboarding-request-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 重试 | [onboarding-generation-handoff](../../01-auth/onboarding-generation-handoff/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/onboarding-default-confirm/default.png) · [入口及前驱](../../01-auth/onboarding-default-confirm/README.md) | 1 | avatar photo failure and default confirmation at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-failed/default.png) · [入口及前驱](../../01-auth/onboarding-failed/README.md) | 1 | onboarding avatar failed at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-required/default.png) · [入口及前驱](../../01-auth/onboarding-required/README.md) | 1 | onboarding avatar required at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-failed-source/default.png) · [入口及前驱](../../01-auth/onboarding-failed-source/README.md) | 1 | onboarding avatar failed at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-photo-error/default.png) · [入口及前驱](../../01-auth/onboarding-photo-error/README.md) | 1 | avatar photo failure and default confirmation at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-upload-pending/default.png) · [入口及前驱](../../01-auth/onboarding-upload-pending/README.md) | 1 | Configured onboarding → Upload a photo → Choose from library → upload pending |
| [图](../../01-auth/onboarding-reading-generation-wait/default.png) · [入口及前驱](../../01-auth/onboarding-reading-generation-wait/README.md) | 1 | onboarding reading 390.0/1.0 |
| [图](../../01-auth/onboarding-reading-photo-privacy/default.png) · [入口及前驱](../../01-auth/onboarding-reading-photo-privacy/README.md) | 1 | onboarding reading 390.0/1.0 |
| [图](../../01-auth/onboarding-generating/default.png) · [入口及前驱](../../01-auth/onboarding-generating/README.md) | 1 | onboarding avatar generating at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-banners/default.png) · [入口及前驱](../../01-auth/onboarding-banners/README.md) | 1 | avatar task banners at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-required-source/default.png) · [入口及前驱](../../01-auth/onboarding-required-source/README.md) | 1 | onboarding avatar required at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-generation-handoff/default.png) · [入口及前驱](../../01-auth/onboarding-generation-handoff/README.md) | 1 | Portrait accepted and generation queued → handoff dialog |
| [图](../../01-auth/onboarding-reading-generation-stage/default.png) · [入口及前驱](../../01-auth/onboarding-reading-generation-stage/README.md) | 1 | onboarding reading 390.0/1.0 |
| [图](../../10-global-modals/reduced-banner/default.png) · [入口及前驱](../../10-global-modals/reduced-banner/README.md) | 1 | reduced motion flows 390.0 / 1.0 |
| [图](../../01-auth/onboarding-request-error/default.png) · [入口及前驱](../../01-auth/onboarding-request-error/README.md) | 1 | Default-avatar confirmation also fails → same inline error and available retry/default buttons; shared with upload failure |

## 实际操作链与状态依据

[CONFIGURED-PAGES-CURRENT.md](../CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT.md](../CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT.md](../CONFIGURED-ERRORS-CURRENT.md)

CONFIGURED-PAGES-CURRENT.md：配置条件和当前代表图已核对；默认入口不计缺失，历史其它状态版本见 G11。 当前提交中、上传中和生成交接弹窗见 [具名缺图报告](../CONFIGURED-SUBMISSION-CURRENT.md)；失败反馈与最终状态对应仍待收尾。 [具名失败反馈已核对](../CONFIGURED-ERRORS-CURRENT.md)，最终全状态映射另行验收。

## 已有改版运行图，优先复用

- [20260914-onboarding-avatar](../../../ui-refactor/20260914-onboarding-avatar/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
