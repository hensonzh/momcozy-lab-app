# 旧 Web 按钮交互态矩阵

状态：source-derived v0.1  
范围：宝宝和我、计划、智能体主页  
用途：作为 Flutter widget test 与交互重绘的按钮级黄金标准。

## 基准来源

- `legacy_web/src/pages/status/StatusOverviewBody.tsx`
- `legacy_web/src/pages/Schedule.tsx`
- `legacy_web/src/pages/AgentHub.tsx`
- `legacy_web/src/components/Mai/MaiInputBar.tsx`
- `legacy_web/src/pages/status/StatusOverviewBody.test.ts`
- `legacy_web/src/pages/status/StatusOverviewBody.render.test.tsx`
- `legacy_web/src/pages/Schedule.test.ts`
- `legacy_web/src/components/Mai/MaiInputBar.test.tsx`
- `legacy_web/src/hooks/useAgentHubSpeechInput.test.tsx`

## 判定口径

| 状态 | 判定 |
| --- | --- |
| 默认态 | 控件可见、可点，点击触发旧 Web 同名业务反馈。 |
| 选中态 | `aria-selected=true`、视觉高亮、内容区随选中项切换。 |
| 禁用态 | `disabled` 或 `aria-disabled=true`，点击不改变页面状态。 |
| 忙碌态 | 按钮禁用、显示 spinner/loading/运行中提示，重复点击不会重复提交。 |
| 确认态 | 点击后先出现确认弹层，确认后才改变持久状态。 |
| 导航态 | 点击后进入指定路由或把 `agentPrefill` 写入智能体输入框。 |
| 保持态 | 切换底部 Tab 后，页面内已选择状态、草稿、附件、局部任务保持。 |

## 宝宝和我

| 控件 | 旧 Web 状态机 | 点击结果 | Flutter 测试覆盖 | 缺口 |
| --- | --- | --- | --- | --- |
| 孕期/哺乳期切换 | `role=tab`，选中项高亮；点击调用 `handleCareStageChange` 并写入偏好。 | 切换妈妈/宝宝档案文案与模块集合；孕期强制回到妈妈视图。 | 已覆盖孕期、哺乳期、宝宝禁用。 | 需补持久化偏好恢复断言。 |
| 妈妈/宝宝卡片 | `role=tab`；孕期宝宝卡 `disabled`、`aria-disabled=true`、透明禁用。 | 哺乳期可切换妈妈/宝宝内容；孕期点击宝宝无变化。 | 已覆盖禁用和 tab state retention。 | 需补视觉 selected/disabled key 的 golden 断言。 |
| 母乳产出信息按钮 | 指标旁问号按钮，`aria-label="今日产出说明"`。 | 打开 `milk-info` 详情 sheet。 | 未覆盖。 | P1 补 `milk-info` sheet 打开/关闭。 |
| 母乳趋势展开头 | `Expandable` 头部按钮。 | 展开/收起趋势图；默认展开。 | 只覆盖图存在。 | P1 补收起/展开状态。 |
| 母乳趋势 周/月 | 两个小按钮；`windowSize === 7/30` 时当前项高亮。 | 图表窗口切换为近 7 日或近 30 日。 | 已覆盖周切月。 | 需补切回周和数据点/轴文案变化。 |
| 乳房健康信息按钮 | 卡片标题问号按钮。 | 打开 `breast-info` 详情 sheet。 | 未覆盖。 | P0 补 info 与 diary 两个不同入口。 |
| 查看《乳房健康日记》 | CTA 按钮。 | 打开 `breast-detail` sheet；可关闭。 | 已覆盖。 | 需补 sheet 内按钮/内容完整度。 |
| 查看计划 | 产后恢复 CTA。 | 打开 `postpartum-detail` sheet。 | 已覆盖。 | 需补训练条目点击/提示态。 |
| 补能与休息信息按钮 | 卡片标题问号按钮。 | 打开 `rest-info` sheet。 | 未覆盖。 | P1 补。 |
| 奶量摄入信息按钮 | 宝宝视图指标问号。 | 打开 `baby-feed-info`，仍复用 mom panel sheet。 | 未覆盖。 | P1 补。 |
| 成长发育：修改指标 | 主 CTA。 | 打开成长指标编辑抽屉；提交后刷新指标并闪烁成长曲线。 | Flutter 当前是本地“已添加”。 | P0 补编辑抽屉/保存/取消/校验，而不是单次 toast。 |
| 成长发育：成长 milestone | 次 CTA。 | 打开 `growth-milestone` sheet。 | 只覆盖按钮存在。 | P0 补打开/关闭和内容。 |
| 宝宝成长曲线 体重/身高 | 两个小按钮；当前项高亮。 | 图表在体重和身高曲线间切换。 | 已覆盖切身高。 | 需补切回体重和 chart label。 |
| 宝宝健康：查看健康信息 | CTA。 | 打开 `baby-health` sheet。 | 未覆盖。 | P1 补。 |
| 宝宝睡眠：查看报告 | CTA。 | 打开 `baby-sleep` sheet。 | 未覆盖。 | P1 补。 |

## 计划

| 控件 | 旧 Web 状态机 | 点击结果 | Flutter 测试覆盖 | 缺口 |
| --- | --- | --- | --- | --- |
| 周视图左右箭头 | 普通按钮。 | 改变 `weekOffset`，日期 strip 切到上一/下一周。 | 未覆盖。 | P0 补 week navigation 与回今天。 |
| 日期按钮 | 选中日期高亮；只有真实今天显示 `今`。 | 更新 `selectedDate`，标题、任务、空态、按钮集合随日期切换。 | 已覆盖日期切换和 `今`。 | 需补过去/未来/今天三类按钮可见性矩阵。 |
| 今天 FAB | 只在非今天或非当前周显示。 | `selectedDate=todayDate` 且 `weekOffset=0`。 | 已覆盖。 | 无。 |
| Header 提醒按钮 | 开启时显示铃铛；关闭时显示 BellOff；未来未规划日隐藏。 | 开启点击直接开启；关闭点击先打开确认弹层。 | 当前 Flutter 直接切换。 | P0 补确认弹层，并更新测试。 |
| Agent 卡：提醒开关 | 与 Header 提醒按钮共用 handler。 | 同上，关闭前确认。 | 当前 Flutter 直接切换。 | P0 同上。 |
| Agent 卡：对话 | 普通主色按钮。 | `navigate("/", { state: { agentPrefill: "我想调整今天的吸乳排期" } })`。 | 未覆盖。 | P0 补从计划跳到 Agent 并预填草稿。 |
| 下一任务：手动完成并记录数据 | 主按钮。 | 打开吸奶/喂养补录 sheet，提交后完成任务。 | Flutter 只有“手动完成”。 | P0 补文案、补录弹层、完成状态。 |
| 下一任务：顺延半小时 | 次按钮。 | 调用 delay，任务时间 +30 分钟；失败 alert。 | 未覆盖。 | P0 补按钮、状态变化、失败 copy。 |
| 下一任务：跳过这次任务 | 次按钮。 | 标记 skipped，显示“已跳过”。 | 未覆盖。 | P0 补按钮和 skipped badge。 |
| 今日任务说明 | 问号按钮。 | 打开说明 dialog；点击遮罩或关闭按钮关闭。 | 已覆盖 dialog。 | 需补遮罩关闭。 |
| 调整日程 | 图片按钮；忙碌时禁用并显示 spinner。 | 打开上传 picker；`scheduleAdjusting` 防重复。 | 当前 Flutter 点击后直接“已提交”。 | P0 补上传入口/忙碌禁用，而不是直接成功。 |
| 添加任务 | 加号按钮。 | 打开 AddTaskDialog；提交后新增任务。 | 当前 Flutter 直接新增本地任务。 | P0 补 dialog 流程、取消/提交。 |
| 任务行点击 | 今日且未完成/未跳过时可编辑。 | 进入编辑态：时间按钮、标题 input、删除按钮；失焦/Enter 保存。 | 未覆盖。 | P0 补编辑态、保存、非今日不可编辑。 |
| 任务删除 | 删除按钮；删除中禁用并显示 spinner。 | 删除任务；失败 alert。 | 只覆盖删除图标存在。 | P1 补删除中和删除结果。 |
| 任务 checkbox | 普通 checkbox。 | done/skipped 状态切换；计数、进度条、badge 更新。 | 已覆盖勾选计数。 | 需补取消完成。 |
| 吸奶补录/喂养记录 | 空态底部快捷按钮。 | 打开对应补录 sheet；提交后新增记录。 | 当前 Flutter 直接添加本地记录。 | P1 补弹层流程。 |

## 智能体主页

| 控件 | 旧 Web 状态机 | 点击结果 | Flutter 测试覆盖 | 缺口 |
| --- | --- | --- | --- | --- |
| 自动语音按钮 | `aria-pressed`；开时 Volume2，关时 VolumeX。 | 开启会 prime 播放；关闭停止当前播报。 | Agent 单测覆盖部分。 | 需补 shell parity 与跨 Tab 保持。 |
| 新建会话 | 顶部加号。 | 取消流、清空图片、清空输入、重置 thread、插入 greeting、toast。 | Agent 单测覆盖清空部分不足。 | P0 补运行中禁用/取消、greeting、附件清理。 |
| 回到最新消息 | 只有滚动离底部时显示。 | 平滑滚到底部并隐藏按钮。 | 未覆盖。 | P1 补。 |
| 查看更早对话 | 有历史窗口时显示。 | 非运行态加载更早；运行/发送中禁用，文案变为“回复结束后可查看更早对话”。 | 未覆盖。 | P1 补。 |
| 图片按钮 | 默认可点；发送运行中禁用。 | 打开 photo menu；再次点击关闭。 | Flutter 直接调 pickImage，无菜单。 | P0 补拍照/上传菜单、关闭按钮。 |
| Photo menu：拍照 | 菜单按钮。 | 触发 camera file input。 | 未覆盖。 | P0 补菜单测试与 file picker adapter。 |
| Photo menu：上传 | 菜单按钮。 | 触发 upload file input。 | 未覆盖。 | P0 补。 |
| 图片预览移除 | 每张预览右上角 X。 | 从 staged image 中删除；发送按钮是否可点随之变化。 | Agent 单测覆盖 remove before send。 | 需补 ready/uploading/failed 三态。 |
| 输入框 Enter | 中文 composition 期间不发送；普通 Enter 发送。 | 清空输入、追加用户气泡、启动流。 | 部分覆盖发送。 | P1 补 composition 和多行高度。 |
| 发送按钮空态 | 无文字、无图片、非运行时置灰禁用。 | 点击无效。 | 已覆盖无 runner disabled。 | 需补有 runner 但空内容禁用。 |
| 发送按钮有内容 | 主色可点。 | 停止语音听写、清 quick replies、追加用户气泡、启动流。 | 已覆盖 optimistic bubble。 | 需补图片-only 文案对齐：旧 Web 是“请看这张图片”。 |
| 发送中空输入 | 按钮变 stop/square。 | 点击中断当前流；短时间重复 stop 被忽略。 | Agent 单测覆盖 stop。 | 需补 shell parity 与重复点击。 |
| 发送中有新内容 | 仍允许作为新一轮发送。 | 先 interrupt 当前流，再发送新内容。 | 未覆盖。 | P1 补。 |
| 语音按钮 | 点击切到按住说话模式；听写/转写中 disabled 或高亮。 | 按住开始，松开填入输入框但不自动发送。 | 已覆盖语音填草稿不发送。 | 需补按住/取消、permission denied、恢复文字草稿。 |
| 路由预填 | 计划页传 `agentPrefill`。 | 输入框填充；若 `agentAutoSend=true` 则自动发送一次，然后清空 route state。 | 未覆盖。 | P0 补计划到 Agent 预填。 |
| 底部 Tab 切换 | 页面本地状态不重置。 | 草稿、图片、语音/图表/日期等恢复。 | 部分覆盖。 | P0 补 Agent 草稿/附件跨 Tab。 |

## 下一轮测试提交粒度

1. `test: add legacy button interaction matrix coverage`
   - 只补 failing widget tests，不改实现。
   - 覆盖：计划提醒确认、计划对话预填、计划 next task 三按钮、Agent 图片菜单、Agent route prefill、状态 info/sheet 入口。

2. `fix: align schedule button state machine`
   - 修计划页确认弹层、next task 三按钮、添加/调整弹层外壳、任务编辑态。

3. `fix: align agent composer button state machine`
   - 修图片菜单、图片-only 文案、route prefill、发送中 stop/new turn、草稿/附件保持。

4. `fix: align status detail button state machine`
   - 修宝宝和我所有 info/sheet 入口、成长指标编辑抽屉、睡眠/健康/milestone。

每个提交后运行：

```bash
npm run flutter:test -- test/features/app_pages/status_schedule_agent_legacy_widget_parity_test.dart test/features/agent_hub/agent_hub_page_test.dart
```
