# 邀请登录

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`invite`
- 范围：configured
- 入口：internalInviteOnly 配置
- 路由：/login
- 实现：[invite_auth_page.dart](../../../../lib/features/auth/presentation/invite_auth_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 输入
- 校验
- 提交
- 错误

## 归属弹窗／浮层

共享反馈／系统浮层按实际触发归属

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 输入 | [auth-invite](../../01-auth/auth-invite/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 校验 | [auth-invite-validation](../../01-auth/auth-invite-validation/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 提交 | [auth-invite-submit-pending](../../01-auth/auth-invite-submit-pending/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 错误 | [auth-invite-device-error](../../01-auth/auth-invite-device-error/README.md) · [auth-invite-storage-error](../../01-auth/auth-invite-storage-error/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../01-auth/auth-invite-validation/default.png) · [入口及前驱](../../01-auth/auth-invite-validation/README.md) | 1 | invite entry with short keyboard viewport at 390.0 / 1.0 |
| [图](../../01-auth/auth-invite-device-error/default.png) · [入口及前驱](../../01-auth/auth-invite-device-error/README.md) | 1 | Invite submit rejected → code retained and device message displayed |
| [图](../../01-auth/auth-invite-storage-error/default.png) · [入口及前驱](../../01-auth/auth-invite-storage-error/README.md) | 1 | Retry accepted by server → local session save fails; remains logged out |
| [图](../../01-auth/auth-invite/default.png) · [入口及前驱](../../01-auth/auth-invite/README.md) | 1 | invite entry with short keyboard viewport at 390.0 / 1.0 |
| [图](../../01-auth/auth-invite-submit-pending/default.png) · [入口及前驱](../../01-auth/auth-invite-submit-pending/README.md) | 1 | Configured invitation login → enter code → submit; response pending |

## 实际操作链与状态依据

[CONFIGURED-PAGES-CURRENT.md](../CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT.md](../CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT.md](../CONFIGURED-ERRORS-CURRENT.md)

CONFIGURED-PAGES-CURRENT.md：配置条件和当前代表图已核对；默认入口不计缺失，历史其它状态版本见 G11。 当前提交中、上传中和生成交接弹窗见 [具名缺图报告](../CONFIGURED-SUBMISSION-CURRENT.md)；失败反馈与最终状态对应仍待收尾。 [具名失败反馈已核对](../CONFIGURED-ERRORS-CURRENT.md)，最终全状态映射另行验收。

## 已有改版运行图，优先复用

- [20260914-auth](../../../ui-refactor/20260914-auth/HANDOFF.md)：14 张 Flutter 图；源码哈希匹配。需核对目标状态和长图范围。
