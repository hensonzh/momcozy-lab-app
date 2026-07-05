# Flutter Interaction Widget Test Plan

> Status: execution plan v0.1  
> Date: 2026-07-05  
> Scope: use legacy Web behavior as the acceptance standard for `宝宝和我`, `计划`, and `智能体主页`.

This plan complements the visual golden standard. A Flutter widget is not considered parity-complete when it only looks right; it must also preserve the same local state, navigation intent, button feedback, and input behavior as the legacy Web implementation.

Primary references:

| Area | Legacy Web source | Flutter target | Test target |
|---|---|---|---|
| 宝宝和我 | `legacy_web/src/pages/status/StatusOverviewBody.tsx` | `flutter_app/lib/features/app_pages/momcozy_feature_pages.dart` | `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` |
| 计划 | `legacy_web/src/pages/Schedule.tsx` | `flutter_app/lib/features/app_pages/momcozy_feature_pages.dart` | `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` |
| 智能体主页 | `legacy_web/src/pages/AgentHub.tsx`, `legacy_web/src/components/Mai/MaiInputBar.tsx` | `flutter_app/lib/features/agent_hub/agent_hub_page.dart`, `flutter_app/lib/app/momcozy_app.dart` | `flutter_app/test/features/agent_hub/agent_hub_page_test.dart`, `flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart` |

## 宝宝和我

| Priority | Case | Acceptance |
|---|---|---|
| P0 | 哺乳期妈妈页母乳趋势周/月切换 | Tap `周` and `月`; selected pill changes, chart label/data mode changes, no layout overflow. |
| P0 | 乳房健康 action | Tap `查看《乳房健康日记》`; card expands or opens a local detail panel with breast-health timeline and a visible close/back affordance. |
| P0 | 产后恢复 action | Tap `查看计划`; card expands or opens a local detail panel with recovery plan steps and a visible close/back affordance. |
| P1 | 补能与休息 action | If no product feature exists, tap shows a non-blocking unavailable state instead of doing nothing. |
| P0 | 宝宝页成长发育 action | Tap `记录成长事件`; growth state changes visibly and remains after switching away and back. |
| P0 | 宝宝成长曲线体重/身高切换 | Tap `体重` and `身高`; selected pill changes and the empty/data copy remains legible. |
| P1 | 宝宝健康 / 宝宝睡眠 action | Tap action buttons; show local detail or unavailable state instead of no-op. |
| P0 | 阶段和身份状态保持 | Switch to baby/postpartum, navigate to another bottom tab, return to `宝宝和我`; selected stage and identity remain unchanged. |

## 计划

| Priority | Case | Acceptance |
|---|---|---|
| P0 | 日期条选中标签 | Only the real today displays `今`; selecting another date shows its weekday label and date. |
| P0 | 日期切换刷新页面状态 | Tap adjacent day and week arrows; month header, selected pill, plan title, task count, empty/past/future text, and local task list match the selected day. |
| P0 | 回到今天 | When selected date is not today, show `今天`; tapping it returns selected date and week offset to today. |
| P0 | 提醒开关 | Tap header bell and Agent card `提醒开关`; icon/tooltip/semantic state changes and stays consistent across both controls. |
| P0 | 调整日程 | Tap `调整日程`; show upload/adjusting feedback or a local queued state. It must not be a silent no-op. |
| P0 | 添加任务 | Tap `添加任务`; a new local task appears for the selected day only. It persists across bottom-tab navigation and can be completed/deleted. |
| P1 | 空态快捷入口 | Tap `吸奶补录` and `喂养记录`; show local queued/detail feedback or navigate to the corresponding lightweight entry flow. |
| P0 | 任务完成/删除 | Row tap, checkbox, `手动完成`, and delete all update counts/progress immediately. |
| P0 | 跨 tab 状态保持 | Select a non-today date, add/toggle a task, navigate away and back; selected date and local task state remain unchanged. |

## 智能体主页

| Priority | Case | Acceptance |
|---|---|---|
| P0 | App shell enables photo and voice | In the real `/` route, photo and voice buttons are enabled with local/native fallbacks; they are not disabled because dependencies were not injected. |
| P0 | 图片附件 | Tap photo, show image chip; remove hides it; sending includes image payload and clears chip. |
| P0 | 语音输入 | Tap voice, show listening/transcribing state, fill composer text, do not auto-send. Permission denial is visible and retryable. |
| P0 | 多行输入 | Enter multi-line text; composer grows to four lines, text remains visible, send button stays aligned. |
| P0 | 发送消息显示 | Tap send; user message appears immediately as a right-side bubble, input clears, assistant stream follows. |
| P0 | 停止 / 重试 | While streaming, send button becomes stop; after disconnect, retry resends the last request. |
| P1 | 最新消息按钮 | Long history shows `回到最新消息`; tapping it scrolls to bottom and hides the button. |
| P0 | 跨 tab 会话状态保持 | Type draft or send a message, navigate away and back; draft/history/current run state remain. |
| P1 | 从其他模块回到智能体 | Center avatar plays attention animation when entering `/` from another bottom tab and remains visually stable after animation. |

## Execution Order

1. Add failing widget tests for the highest-risk no-op interactions in each area.
2. Fix `宝宝和我` local card/chart state and persistence.
3. Fix `计划` date strip, selected-day state, reminders, toolbar and empty quick actions.
4. Fix `智能体主页` App-shell injection, optimistic user bubbles, multi-line composer, draft/history preservation, and entry animation.
5. Run focused tests after each page-level slice, then `flutter test` for the touched suites.
6. Commit one completed page or tightly related interaction slice at a time.

Focused command:

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test \
  test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart \
  test/features/agent_hub/agent_hub_page_test.dart
```
