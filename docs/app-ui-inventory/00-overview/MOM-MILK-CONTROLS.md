# 泌乳记录逐控件补验

正式用户 App：More → Me → 记录一次泌乳 → 新增表单 → 保存列表 → 编辑 → 关闭 → 首页“查看记录” → 历史页编辑 → 取消确认 → 返回首页与 More。393 px / 1x 和 320 px / 2x 均实际运行。正式 GoRouter、Controller、Repository、编解码与 UI 保留，HTTP 和会话使用隔离 fixture，不写入当前账号健康记录。

## 控件与保存行为

| 控件 / 操作 | 实际行为与断言 |
| --- | --- |
| 侧别 | 右侧 → 左侧，选中状态与奶量标签随之变化 |
| 记录方式 | 泵奶 80.5 → 亲喂空值 → 填 12 分钟 → 泵奶空值；互切清空数值，不把 ml 当作分钟 |
| 乳房感受 | 舒服、胀满、疼痛、说不清楚四项逐个选择并再次点击取消；均断言空值，随后恢复舒服 |
| 备注 | 输入 → 清空 → 再输入 → 收起，草稿与“已填写”状态保留 |
| 时间 | 普通字号表盘切输入模式，大字号直接显示输入表单；输入下午 12:34 → 确定 → 编辑器与再次打开的选择器均保持时间 → 取消不改变时间 |
| 保存泵奶 | 新增 80.5 ml、左侧、舒服、备注及 12:34；保存前无记录，保存后恰好一条，重开核对全部字段 |
| 修改已存方式 | 转为亲喂后测量值为空，侧别、时间、感受与备注保留；提交后版本变为 2，仍为同一条记录 |
| 未填写亲喂时长 | 可保存，列表显示“时长未填写”；首页显示“1 次 / 泵奶 0 次 · 亲喂 1 次”，不生成奶量或分钟数 |
| 取消未修改的已有记录 | 仍弹出离开确认；确认离开后版本保持 2；历史页关闭回首页 |

## 全部状态与跳转

| 实际操作 | 截图、完整长图与前驱 |
| --- | --- |
| Cancel unchanged lactation editor → confirmation still shown | [运行证据](../03-mom/mom-milk-control-cancel-confirm/README.md) |
| Confirm leave → history retains version 2 | [运行证据](../03-mom/mom-milk-control-cancel-return-history/README.md) |
| Select breast comfort 舒服 | [运行证据](../03-mom/mom-milk-control-comfort-comfortable/README.md) |
| Tap 舒服 again → comfort cleared | [运行证据](../03-mom/mom-milk-control-comfort-comfortable-cleared/README.md) |
| Select breast comfort 胀满 | [运行证据](../03-mom/mom-milk-control-comfort-full/README.md) |
| Tap 胀满 again → comfort cleared | [运行证据](../03-mom/mom-milk-control-comfort-full-cleared/README.md) |
| Select breast comfort 疼痛 | [运行证据](../03-mom/mom-milk-control-comfort-painful/README.md) |
| Tap 疼痛 again → comfort cleared | [运行证据](../03-mom/mom-milk-control-comfort-painful-cleared/README.md) |
| Restore comfortable breast feeling | [运行证据](../03-mom/mom-milk-control-comfort-restored/README.md) |
| Select breast comfort 说不清楚 | [运行证据](../03-mom/mom-milk-control-comfort-uncertain/README.md) |
| Tap 说不清楚 again → comfort cleared | [运行证据](../03-mom/mom-milk-control-comfort-uncertain-cleared/README.md) |
| Home View records → nursing history | [运行证据](../03-mom/mom-milk-control-history/README.md) |
| History Edit → saved nursing with empty duration and retained note | [运行证据](../03-mom/mom-milk-control-history-reopened/README.md) |
| More → Me → initial home | [运行证据](../03-mom/mom-milk-control-home-entry/README.md) |
| Close saved nursing → home count without invented milk amount | [运行证据](../03-mom/mom-milk-control-home-nursing-only/README.md) |
| History close → home | [运行证据](../03-mom/mom-milk-control-home-return/README.md) |
| Bottom More → original tab | [运行证据](../03-mom/mom-milk-control-more-return/README.md) |
| Clear optional note | [运行证据](../03-mom/mom-milk-control-note-cleared/README.md) |
| Enter optional note | [运行证据](../03-mom/mom-milk-control-note-filled/README.md) |
| Enter nursing duration 12 minutes | [运行证据](../03-mom/mom-milk-control-nurse-duration/README.md) |
| Save converted nursing with optional duration unset → updated record | [运行证据](../03-mom/mom-milk-control-nurse-no-duration-saved/README.md) |
| Switch pump to nurse → measurement cleared and minutes shown | [运行证据](../03-mom/mom-milk-control-nurse-switch-cleared/README.md) |
| Collapse filled optional fields → filled indicator remains | [运行证据](../03-mom/mom-milk-control-optional-collapsed/README.md) |
| Expand breast comfort and note | [运行证据](../03-mom/mom-milk-control-optional-open/README.md) |
| Enter decimal pump volume 80.5 ml | [运行证据](../03-mom/mom-milk-control-pump-decimal/README.md) |
| Home record once → pump editor | [运行证据](../03-mom/mom-milk-control-pump-empty/README.md) |
| Edit saved pump → all fields retained and optional section expanded | [运行证据](../03-mom/mom-milk-control-pump-reopened/README.md) |
| Save pump through production repository → list and saved feedback | [运行证据](../03-mom/mom-milk-control-pump-saved/README.md) |
| Switch back to pump → nursing number cleared | [运行证据](../03-mom/mom-milk-control-pump-switch-cleared/README.md) |
| Switch saved pump to nursing → clear numeric value, preserve side, note and comfort | [运行证据](../03-mom/mom-milk-control-saved-switch-to-nurse/README.md) |
| Select left breast → left volume label | [运行证据](../03-mom/mom-milk-control-side-left/README.md) |
| Select right breast → right volume label | [运行证据](../03-mom/mom-milk-control-side-right/README.md) |
| Confirm valid time → editor displays 12:34 | [运行证据](../03-mom/mom-milk-control-time-accepted/README.md) |
| Cancel picker → accepted time unchanged | [运行证据](../03-mom/mom-milk-control-time-cancelled/README.md) |
| Time dial → manual input | [运行证据](../03-mom/mom-milk-control-time-input-mode/README.md) |
| Open record time picker | [运行证据](../03-mom/mom-milk-control-time-open/README.md) |
| Reopen time picker → accepted time retained | [运行证据](../03-mom/mom-milk-control-time-reopened/README.md) |
| Enter valid record time 12:34 | [运行证据](../03-mom/mom-milk-control-time-valid-input/README.md) |

## 视觉核对

38 个逻辑状态、75 个视口变体、54 张长图变体，共 129 原图；22 个状态主图为长图。全部原图连续全宽分为 279 段，137 种唯一像素片段。123 个新片段组成 21 张审阅图，均已查看；14 个片段逐像素匹配之前已审阅的截图。每张原图从顶部到底部及其审阅图位置可追溯，见 [分段来源](mom-milk-control-visual-review/sources.json) 和 [证据审计](mom-milk-control-evidence-audit.json)。

- 393 px 选择高亮、单位切换、感受取消、备注计数、时间回填、保存/更新提示明确可见。
- 320 px / 2x 下空备注标签出现省略号；“保存这次记录”、表单标题和趋势标题换行。列表中的记录内容因时间与操作区占宽而窄幅换行，备注有时每行仅两字。这些是当前实际布局，未修饰或改动生产组件。
- 列表滚动后顶部关闭按钮可能未挂载；采集测试实际向上滚回找到关闭按钮再点击，完整长图包含顶部、趋势、汇总、记录行及底部内容。
- 大字号时间选择器使用可滚动输入表单，上午/下午与确定/取消可见；本次使用下午 12:34，没有把宿主文字输入等同于原生系统键盘验证。

## 验证与范围

- [严格采集](runs/20260913T195730-targeted/capture.log)：2 项通过，0 失败，5 秒；保留 [命令](runs/20260913T195730-targeted/capture-command.json) 与 [退出码](runs/20260913T195730-targeted/capture-result.json)，未放宽金图比较。
- [全仓静态检查](mom-milk-control-analyze.log)：No issues found。
- 新增 `test/modules/mom/mom_milk_control_inventory_test.dart`。基线调试修正了测试中编辑提交按钮名称和历史页关闭定位，最终沿当前真实控件完成流程；未修改生产 UI 或共用采集器。
- 原有新增/编辑/删除/撤销、冲突与失败重试、7/30 天趋势入口见 [Mom 流程](MOM-JOURNEYS.md)。本轮未重复宣称这些流程重新执行。
- 备注 2000 字边界、未来时间与数值校验的全部有意义分支、时间选择器上午/下午及表盘选择分支、顶部“返回记录”与系统返回仍需逐项核对已有证据。原生输入、权限及全体历史视觉审阅未完成，详见 [控件清单](MOM-CONTROL-COVERAGE.md) 和 [完成审计](AUDIT.md)。
