# 无正常入口代码与函数式弹窗核对

原目标要求单列“代码存在、暂无正常用户入口”。以下结合当前调用点、正式路由、用户角色分支及实际点击证据核对；没有为不可达代码添加入口。

## 当前用户 App 无正常入口

| 代码 | 结论 | 证据 |
| --- | --- | --- |
| `MotionAssessmentPage` | 代码存在，但当前 `/motion-assessment` 没有注册。卡片可达，目的页不可达 | [头颈卡实际点击](../05-agent/agent-entry-journey-forward_head-no-navigation/README.md)、[体态卡实际点击](../05-agent/agent-entry-journey-posture_screen-no-navigation/README.md)；`momcozy_app.dart` 的 route 列表与 dispatcher |
| `MotionPosePreview` | 只由 MotionAssessmentPage 创建，随其不可达 | `motion_assessment_page.dart` 的预览调用、上方路由断点 |
| `ServicePackageFacts`、`ProviderTeamTile` | 旧服务事实/团队组件，当前生产引用仅剩定义；新版使用 MomServicePackageFacts、MomProviderTeamCard | `service_catalog_page.dart` 定义与全仓调用搜索；[当前四套餐及团队实际链](SERVICE-CURRENT.md)。这是类级别结论，不把整个目录页面标为不可达 |
| `MotherStatusCard` | 旧妈妈状态卡，正式首页使用 MomRecoveryStatus | 全仓引用只有定义和 `status_card_accessibility_test.dart`；现有妈妈首页实际截图与新组件 |
| `ConsultationDevicePreviewDialog` | 专家准备区域使用，用户准备走 ConsultationPreparation / ConsultationDeviceCheckView；本次用户 App 范围不纳入专家工作台 | `room_page.dart` build 按 `!isExpert && data != null && !ended && !inRoom` 先返回用户准备组件；`_expertPreparation` 中才有该预览按钮 |
| `AppointmentSummary` | 同上，仅出现在专家准备区域 | `room_page.dart` 的 `_expertPreparation` 调用点；工作台单列，不当成遗漏用户页面 |

指定会话通知入口当前已恢复，合法 conversationId 可加载会话并打开历史抽屉；详见 [当前入口核验](AGENT-ENTRY-CURRENT.md)。旧初始化异常只保留为历史版本证据。这不是对整个仓库所有不可达代码的最终证明，功能开关和其它既有组件仍需继续核验。

## 已实际出现的函数式弹窗

这些文件没有独立 StatefulWidget/StatelessWidget 类型，自动类型扫描不会将它们记为 observed。它们不是因此缺少页面截图。

| 文件 / 函数 | 正常路径与证据 |
| --- | --- |
| `notification_permission_dialogs.dart` / explainNotifications | 通知设置提醒开关 → [权限教育弹窗](../07-me/notification-journey-reminder-education/README.md) → [暂不开启](../07-me/notification-journey-reminder-education-declined/README.md)。这仍不等于操作系统权限弹窗 |
| `home_consultation_dialog.dart` / showHomeConsultationDialog | 妈妈已购计划“查看预约” → [首页预约浮层](../08-expert-service/home-consultation-journey-preparation/README.md) → [取消确认](../08-expert-service/home-consultation-journey-cancel-confirm/README.md)；本轮实际链路在 [补验报告](ENTRY-FOLLOWUP.md) |
| `confirm_discard.dart` / confirmDiscard | 修改记录后离开 → [妈妈记录放弃确认](../03-mom/mom-journey-diary-discard-confirm/README.md)，保存结果未知时 → [日程离开确认](../06-schedule/schedule-journey-uncertain-discard/README.md) |

`source-audit.json` 保留自动类型观察值；`entry-audit-overrides.json` 添加状态引用与源码哈希。不能把“7 个未被类型扫描匹配的文件”解释为“还缺 7 张截图”，也不能据此声称其它页面已全部覆盖。
