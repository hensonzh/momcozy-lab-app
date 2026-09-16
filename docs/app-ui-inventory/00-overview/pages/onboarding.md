# 首次使用资料

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`onboarding`
- 范围：configured
- 入口：开启 onboarding 后按引导进入
- 路由：/onboarding
- 实现：[onboarding_page.dart](../../../../lib/features/onboarding/presentation/onboarding_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 加载
- 错误
- 基本资料
- 分娩资料
- 宝宝资料
- 校验与保存

## 归属弹窗／浮层

avatar-dialogs

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 加载 | [onboarding-loading](../../01-auth/onboarding-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [onboarding-load-error](../../01-auth/onboarding-load-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 基本资料 | [onboarding-basics](../../01-auth/onboarding-basics/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 分娩资料 | [onboarding-delivery](../../01-auth/onboarding-delivery/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 宝宝资料 | [onboarding-birth](../../01-auth/onboarding-birth/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 校验与保存 | [onboarding-birth-error](../../01-auth/onboarding-birth-error/README.md) · [onboarding-short-busy](../../01-auth/onboarding-short-busy/README.md) · [onboarding-short-error](../../01-auth/onboarding-short-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/onboarding-birth/default.png) · [入口及前驱](../../01-auth/onboarding-birth/README.md) | 1 | onboarding profile forms at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-birth-error/default.png) · [入口及前驱](../../01-auth/onboarding-birth-error/README.md) | 1 | onboarding profile forms at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-delivery/default.png) · [入口及前驱](../../01-auth/onboarding-delivery/README.md) | 1 | onboarding profile forms at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-short-error/default.png) · [入口及前驱](../../01-auth/onboarding-short-error/README.md) | 1 | profile short viewport keeps save pending and recovers draft |
| [图](../../01-auth/onboarding-load-error/default.png) · [入口及前驱](../../01-auth/onboarding-load-error/README.md) | 1 | onboarding load failure retries at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-short-date-input/default.png) · [入口及前驱](../../01-auth/onboarding-short-date-input/README.md) | 1 | profile short viewport keeps save pending and recovers draft |
| [图](../../10-global-modals/reduced-selected/default.png) · [入口及前驱](../../10-global-modals/reduced-selected/README.md) | 1 | reduced motion flows 390.0 / 1.0 |
| [图](../../01-auth/onboarding-basics/default.png) · [入口及前驱](../../01-auth/onboarding-basics/README.md) | 1 | onboarding profile forms at 390.0 / 1.0 |
| [图](../../01-auth/onboarding-short-busy/default.png) · [入口及前驱](../../01-auth/onboarding-short-busy/README.md) | 1 | profile short viewport keeps save pending and recovers draft |
| [图](../../01-auth/onboarding-loading/default.png) · [入口及前驱](../../01-auth/onboarding-loading/README.md) | 1 | onboarding load failure retries at 390.0 / 1.0 |

## 实际操作链与状态依据

[CONFIGURED-PAGES-CURRENT.md](../CONFIGURED-PAGES-CURRENT.md)

CONFIGURED-PAGES-CURRENT.md：配置条件和当前代表图已核对；默认入口不计缺失，历史其它状态版本见 G11。

## 已有改版运行图，优先复用

- [20260914-onboarding-profile](../../../ui-refactor/20260914-onboarding-profile/HANDOFF.md)：9 张 Flutter 图；源码哈希尚不能确认匹配。需核对目标状态和长图范围。
