# 今日状态记录页

[总清单](../PAGE-CATALOG.md)

- 稳定页面 ID：`mom-diary`
- 范围：default
- 入口：妈妈首页 → 今日状态
- 路由：/me/diary
- 实现：[mother_diary_page.dart](../../../../lib/modules/mom/presentation/mother_diary_page.dart)
- 当前结论：盘点验收完成；当前图与历史证据按页内版本说明阅读。下列证据并不自动证明所有必需状态完成。

## 本页需覆盖的独立状态

- 身体
- 休息
- 心情
- 加载
- 空记录
- 保存与失败

## 归属弹窗／浮层

mom-diary-editor

## 逐状态对应

| 状态 | 截图及前后操作 | 证据边界 |
| --- | --- | --- |
| 身体 | [mom-journey-diary-detail-body](../../03-mom/mom-journey-diary-detail-body/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 休息 | [mom-journey-diary-detail-rest](../../03-mom/mom-journey-diary-detail-rest/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 心情 | [mom-journey-diary-detail-mood](../../03-mom/mom-journey-diary-detail-mood/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 加载 | [mom-diary-loading](../../03-mom/mom-diary-loading/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 空记录 | [diary-page-rest](../../03-mom/diary-page-rest/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |
| 保存与失败 | [diary-page-saved](../../03-mom/diary-page-saved/README.md) · [diary-page-offline](../../03-mom/diary-page-offline/README.md) | STATE_TO_EXISTING_EVIDENCE_MAPPED; source and interaction limits retained |

## 已有图：相同像素仅列一次

| 代表图与完整上下文 | 合并条目 | 实际触发 |
| --- | ---: | --- |
| [图](../../03-mom/diary-state-empty-validation/default.png) · [入口及前驱](../../03-mom/diary-state-empty-validation/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/mom-diary-loading/default.png) · [入口及前驱](../../03-mom/mom-diary-loading/README.md) | 1 | inventory independent diary loading then ready |
| [图](../../03-mom/mom-journey-diary-detail-updated/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-detail-updated/README.md) | 1 | Save changed mood → updated standalone diary |
| [图](../../03-mom/diary-keyboard-error/default.png) · [入口及前驱](../../03-mom/diary-keyboard-error/README.md) | 1 | diary body dialog at 320.0 / 2.0 |
| [图](../../03-mom/mom-journey-diary-detail-mood/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-detail-mood/README.md) | 1 | Standalone diary → Mood tab |
| [图](../../03-mom/diary-body/default.png) · [入口及前驱](../../03-mom/diary-body/README.md) | 1 | diary body dialog at 390.0 / 1.0 |
| [图](../../03-mom/diary-state-rest-disruptions/default.png) · [入口及前驱](../../03-mom/diary-state-rest-disruptions/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/diary-rest/default.png) · [入口及前驱](../../03-mom/diary-rest/README.md) | 1 | diary rest dialog at 390.0 / 1.0 |
| [图](../../03-mom/diary-rest-selected/default.png) · [入口及前驱](../../03-mom/diary-rest-selected/README.md) | 1 | diary rest dialog at 390.0 / 1.0 |
| [图](../../03-mom/diary-page-body/default.png) · [入口及前驱](../../03-mom/diary-page-body/README.md) | 1 | independent diary uses shared sections, preserves draft and saves 390.0/1.0 |
| [图](../../03-mom/diary-page-mood/default.png) · [入口及前驱](../../03-mom/diary-page-mood/README.md) | 1 | independent diary uses shared sections, preserves draft and saves 390.0/1.0 |
| [图](../../03-mom/diary-page-offline/default.png) · [入口及前驱](../../03-mom/diary-page-offline/README.md) | 1 | independent diary uses shared sections, preserves draft and saves 390.0/1.0 |
| [图](../../03-mom/diary-mood/default.png) · [入口及前驱](../../03-mom/diary-mood/README.md) | 1 | diary mood dialog at 390.0 / 1.0 |
| [图](../../03-mom/mom-journey-diary-detail-body/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-detail-body/README.md) | 1 | Standalone diary → Body tab |
| [图](../../03-mom/diary-page-keyboard/default.png) · [入口及前驱](../../03-mom/diary-page-keyboard/README.md) | 1 | short diary keeps note and save reachable with keyboard and large text |
| [图](../../03-mom/diary-page-rest/default.png) · [入口及前驱](../../03-mom/diary-page-rest/README.md) | 1 | independent diary uses shared sections, preserves draft and saves 390.0/1.0 |
| [图](../../03-mom/diary-state-rest-day/default.png) · [入口及前驱](../../03-mom/diary-state-rest-day/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/diary-state-rest-stretch/default.png) · [入口及前驱](../../03-mom/diary-state-rest-stretch/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/diary-body-selected/default.png) · [入口及前驱](../../03-mom/diary-body-selected/README.md) | 1 | diary body dialog at 390.0 / 1.0 |
| [图](../../03-mom/diary-page-saved/default.png) · [入口及前驱](../../03-mom/diary-page-saved/README.md) | 1 | independent diary uses shared sections, preserves draft and saves 390.0/1.0 |
| [图](../../03-mom/diary/default.png) · [入口及前驱](../../03-mom/diary/README.md) | 1 | diary renders at 390px |
| [图](../../05-agent/agent-workflow-journey-diary-history/default.png) · [入口及前驱](../../05-agent/agent-workflow-journey-diary-history/README.md) | 1 | Tap artifact link → actual mother diary |
| [图](../../03-mom/diary-state-body-discomfort/default.png) · [入口及前驱](../../03-mom/diary-state-body-discomfort/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/mom-journey-diary-detail-rest/default.png) · [入口及前驱](../../03-mom/mom-journey-diary-detail-rest/README.md) | 1 | Completed daily status → standalone diary detail |
| [图](../../03-mom/diary-state-body-bowel/default.png) · [入口及前驱](../../03-mom/diary-state-body-bowel/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/diary-state-body-urination/default.png) · [入口及前驱](../../03-mom/diary-state-body-urination/README.md) | 1 | diary optional and conditional fields save without stale values 390.0/1.0 |
| [图](../../03-mom/diary-mood-selected/default.png) · [入口及前驱](../../03-mom/diary-mood-selected/README.md) | 1 | diary mood dialog at 390.0 / 1.0 |

## 实际操作链与状态依据

[MOM-JOURNEYS.md](../MOM-JOURNEYS.md) · [MOM-BODY-CONTROLS.md](../MOM-BODY-CONTROLS.md) · [MOM-REST-CONTROLS.md](../MOM-REST-CONTROLS.md) · [MOM-MOOD-CONTROLS.md](../MOM-MOOD-CONTROLS.md) · [STATE-MAP-FINAL.md](../STATE-MAP-FINAL.md)
