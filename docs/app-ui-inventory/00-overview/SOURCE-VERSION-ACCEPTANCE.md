# 具名源码版本差异验收

此前遗留的 9 个源码待审项现已逐项处理：7 个文件与已有定向采集快照完全一致，Agent 按已核对的代码边界及改版交付复用，泌乳页按实际新布局完成单尺寸严格采集与长图检查。

这里关闭的是已经登记的源码差异，不声称 2,800 多个历史截图都来自同一时刻。旧截图作为原操作轨迹保留，当前代表图及替换范围由下表报告说明。不得因重新生成索引而把旧图改记成当前版。

| 文件 | 匹配证据 | 当前图与操作范围 |
| --- | --- | --- |
| lib/features/agent_hub/agent_hub_page.dart | [指纹／代码边界](runs/20260914T091638-g11-agent-markdown/reuse-audit.json) | [AGENT-CURRENT-REUSE.md](AGENT-CURRENT-REUSE.md) |
| lib/features/auth/presentation/invite_auth_page.dart | [指纹／代码边界](runs/20260914T092346-g11-configured-final/source-snapshot.json) | [CONFIGURED-PAGES-CURRENT.md](CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT.md](CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT.md](CONFIGURED-ERRORS-CURRENT.md) |
| lib/features/onboarding/presentation/onboarding_page.dart | [指纹／代码边界](runs/20260914T092346-g11-configured-final/source-snapshot.json) | [CONFIGURED-PAGES-CURRENT.md](CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT.md](CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT.md](CONFIGURED-ERRORS-CURRENT.md) |
| lib/modules/consultation/presentation/room_page.dart | [指纹／代码边界](runs/20260914T083932-g11-consultation-feedback/source-snapshot.json) | [CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT.md](CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT.md) · [CONSULTATION-LIVE-CURRENT.md](CONSULTATION-LIVE-CURRENT.md) · [CONSULTATION-OUTCOME-CURRENT.md](CONSULTATION-OUTCOME-CURRENT.md) |
| lib/modules/mom/presentation/lactation_panel.dart | [指纹／代码边界](runs/20260914-lactation-version-final/source-hashes.json) | [LACTATION-VERSION-CURRENT.md](LACTATION-VERSION-CURRENT.md) |
| lib/modules/schedule/presentation/personal_schedule_editor.dart | [指纹／代码边界](runs/20260914T085237-g11-schedule/source-snapshot.json) | [SCHEDULE-CURRENT.md](SCHEDULE-CURRENT.md) · [SCHEDULE-FEEDBACK-CURRENT.md](SCHEDULE-FEEDBACK-CURRENT.md) |
| lib/modules/schedule/presentation/schedule_page.dart | [指纹／代码边界](runs/20260914T085237-g11-schedule/source-snapshot.json) | [SCHEDULE-CURRENT.md](SCHEDULE-CURRENT.md) · [SCHEDULE-FEEDBACK-CURRENT.md](SCHEDULE-FEEDBACK-CURRENT.md) |
| lib/modules/services/presentation/service_renew_page.dart | [指纹／代码边界](runs/20260914T084835-g11-renew/source-snapshot.json) | [RENEW-CURRENT.md](RENEW-CURRENT.md) · [RENEW-PENDING-CURRENT.md](RENEW-PENDING-CURRENT.md) |
| lib/shared/widgets/product_feedback.dart | [指纹／代码边界](runs/20260914T083633-g11-auth-feedback/source-snapshot.json) | [AUTH-SUBMIT-FEEDBACK-CURRENT.md](AUTH-SUBMIT-FEEDBACK-CURRENT.md) · [SCHEDULE-CURRENT.md](SCHEDULE-CURRENT.md) · [INTAKE-FEEDBACK-CURRENT.md](INTAKE-FEEDBACK-CURRENT.md) · [STATE-MAP-FINAL.md](STATE-MAP-FINAL.md) · [LACTATION-VERSION-CURRENT.md](LACTATION-VERSION-CURRENT.md) |

共享反馈已检查实际实现：Error 只有普通／Mom 两种布局，草稿说明和重试按钮为显式参数；Empty 由对齐、图标、正文、动作控制；Loading 由可选标签控制。两种错误样式及相关参数已有运行图，宿主的布局和滚动范围由页面证据承担；不再因为每个宿主引用同一组件而重复生成组合。

[逐项当前指纹](source-version-acceptance.json) · [原队列状态](pending-source-reviews.json)。本表不代替页面／浮层／点击链的逐项验收。
