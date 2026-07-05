# Flutter Widget Parity 测试用例

本文把已采用的旧 Web UI/UX 黄金标准落成 Flutter widget test 断言，聚焦三个高频 tab 页面：宝宝和我、计划、智能体主页。

对应测试文件：

```text
flutter_app/test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart
```

## 宝宝和我 `/status`

| 旧 Web widget | Flutter 断言目标 |
|---|---|
| `孕期` / `哺乳期` 阶段切换 | `status-care-stage-pregnancy`, `status-care-stage-postpartum` |
| 妈妈 / 宝宝身份卡 | `status-identity-tab-mom`, `status-identity-tab-baby` |
| 孕期下宝宝卡禁用 | 孕期点击宝宝卡后仍停留在孕期日记视图 |
| 哺乳期妈妈模块宫格 | `status-postpartum-mom-module-grid`，并覆盖母乳产出、乳房健康、产后恢复、补能与休息 |
| 母乳趋势卡 | `status-milk-trend-preview` 与图例文案 |
| 孕期下一步行动 | 孕期日记、孕期计划、补写孕期日记、今日待办 |
| 状态同步失败卡 | 状态同步失败、错误说明、重试 tooltip |
| 底部导航当前项 | `bottom-nav-status`，可见 tab 文案，中心 `bottom-nav-agent` |

## 计划 `/schedule`

| 旧 Web widget | Flutter 断言目标 |
|---|---|
| 月份标题 | `2026年7月` |
| 周日期条 | `schedule-date-strip`、上一周/下一周图标、选中日 `今 3` |
| 计划摘要卡 | 稳奶计划执行中、产后第29周、提醒按钮、任务计数 `1/3`、进度条 |
| Agent 建议卡 | `schedule-agent-card`、提醒开关、对话 |
| 下一条任务 / 空态卡 | 待执行任务或 `schedule-empty-task-card` |
| 今日任务工具栏 | `schedule-list-toolbar`、`schedule-task-help-button`、调整日程、添加任务 |
| 任务说明弹窗 | `schedule-task-explanation-dialog` |
| 任务行操作 | checkbox 完成态、删除 tooltip、本地新增任务文案 |
| 空态 / 失败态 | `0/0`、今天还没有计划任务、当天暂无执行内容、计划同步失败 |
| 底部导航当前项 | `bottom-nav-schedule`，中心 `bottom-nav-agent` |

## 智能体主页 `/`

| 旧 Web widget | Flutter 断言目标 |
|---|---|
| 右上圆形控制按钮 | `agent-auto-voice-button`, `agent-new-session-button` |
| 聊天滚动区与顶部 fade | `agent-chat-scroll-view`, `agent-top-fade` |
| 助手透明消息样式 | 助手文本以 transcript 直接展示，不进入用户气泡 |
| 用户历史消息气泡 | `agent-history-panel` 内用户消息 |
| 图片附件预览与移除 | `agent-image-attachment-chip`, `agent-remove-image-button` |
| 固定输入栏 | `agent-composer-bar`、图片、输入框、语音、发送控件 |
| 回到最新消息按钮 | 长历史且不在底部时显示 `agent-scroll-latest-button`，点击后滚到底部并隐藏 |
| 流式停止 / 重试 / work / artifact / action 状态 | 由既有 Agent Hub widget tests 与本页 parity suite 共同覆盖 |
| 底部导航中心当前项 | 根路由显示 `bottom-nav-agent` |

## 验证命令

聚焦运行 parity suite：

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart
```

进入 release gate 时，仍纳入常规 Flutter 测试：

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test
```
