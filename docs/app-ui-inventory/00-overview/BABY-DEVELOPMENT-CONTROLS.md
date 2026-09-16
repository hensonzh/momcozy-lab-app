# Baby 发育观察选项、批量保存与逐项历史编辑

从正式用户 App 的 More → Baby →“记录发育观察”进入，实际操作全部三项行为及其选项，保存后通过“查看全部记录”→“发育观察”→编辑→返回。393 px / 1x 与 320 px / 2x 使用生产 App、GoRouter、Repository、codec；HTTP、会话、时钟与原生依赖使用隔离 fixture。本批没有向真实宝宝账号写入记录。

## 实际操作与结果

- 三项行为为“看向靠近的脸”“听到声音后有动作或表情反应”“俯卧时短暂抬起头”。每项依次点击“观察到”“暂未观察到”“不确定”，再点击已选“不确定”清除，逐步断言选择值与错误清除。
- 初始全部未选择、逐项操作后全部清除，均实际点击保存并显示“至少记录一项具体行为，拿不准可以选择‘不确定’。”，没有写请求。截图使用实际双引号文案。
- 再分别选择观察到、暂未观察到、不确定，三项同时保留。关闭脏草稿出现“离开这次记录？”；点击“继续填写”保留所有选择，本批未点击“离开”。
- 观察日期打开与取消保留今天；再次打开输入昨天 2026-09-12，确认后作为三条观察的共同日期。本批没有运行日期范围错误和年月导航。
- 模拟批量保存 HTTP 503：记录未写入，Controller editable=false，显示内容保留、保存结果未确认与“重试确认保存”。关闭出现专用未确认提示，继续填写仍保留原草稿。
- 点击重试后暂停 HTTP 响应，实际采集“正在保存…”以及不可点击的保存动作；随后放行请求，返回首页并生成三条记录，status 依次为 observed、not_observed、unsure，recorded_on 均为 2026-09-12。没有重复生成记录。
- 历史显示三条具体行为。分别编辑每一条时，仅该行为可见，不能改成另一种行为；点击其原状态清除再保存，必填校验阻止写入、version 仍为 1。
- 三条记录分别改为暂未观察到、不确定、观察到并实际保存，每条同一 id 更新到 version=2，总数始终为 3。每次修改后的历史均有截图，确认其他行为保留。
- 重新打开首条确认暂未观察到已回显；无修改关闭不出现放弃确认，返回 Baby，再切回 More。

通过 WidgetTester 实际点击/输入驱动以上变化，未调用 onChanged 或直接写 Controller 草稿。HTTP 写入与错误仅发生在隔离 fixture；不代表服务端整条业务链已经部署验证。

## 完整截图与视觉检查

46 个逻辑状态、92 个视口变体，50 张完整长图，9 个状态以长图为主图。142 张原始 PNG 拆成 326 个连续全宽片段，其中 179 个唯一片段；153 个新片段组成 26 页，全部查看，另 26 个与此前已审阅图像逐像素一致。来源 SHA、尺寸、全高连续性和审阅页对应像素均通过校验，见 [分段来源](baby-development-control-visual-review/sources.json) 与 [证据审计](baby-development-control-evidence-audit.json)。

- 393 px 每组选项横向三列；320 px / 2x 纵向排列，标题为两行。完整长图保留三组行为、所有选项、说明、观察日期、错误与唯一保存动作。
- 大字历史中行为名、状态与数据来源自然换行；完整长图保留三条记录、添加记录和数据来源，保存 Snackbar 只出现一次。
- 大字历史返回或重新加载后，横向分类条可能回到左侧，当前“发育观察”标签暂时不在可见范围，但实际路由和记录仍为发育观察；本批如实记录，没有将可见的“喂养”文字视为分类切换成功。
- 503 保存错误沿用“暂时无法载入，请稍后重试”，文案与保存场景不完全匹配；内容保留及保存未确认解释完整可见。
- 请求未确认及保存中，选项保留原外观，日期与保存动作呈禁用样式；保存中关闭图标变得非常暗。此处记录现状，不将视觉外观等同于可点击性。
- 观察日期选择器在小屏大字下默认输入模式，普通尺寸默认日历；确认/取消及日期内容完整。脏草稿和未确认两种确认框的文字均可见。

## 状态与前驱

| 实际触发动作 | 截图、长图与前驱 |
| --- | --- |
| Tap save → 至少记录一项具体行为，拿不准可以选择“不确定”。; no write request | [运行证据](../04-baby/baby-development-controls-all-cleared-rejected/README.md) |
| Choose 不确定 for 俯卧时短暂抬起头 while preserving other groups | [运行证据](../04-baby/baby-development-controls-batch-lifts-head/README.md) |
| Choose 观察到 for 看向靠近的脸 while preserving other groups | [运行证据](../04-baby/baby-development-controls-batch-looks-at-face/README.md) |
| Choose 暂未观察到 for 听到声音后有动作或表情反应 while preserving other groups | [运行证据](../04-baby/baby-development-controls-batch-responds-to-sound/README.md) |
| Retry acknowledged → three dated observations saved together | [运行证据](../04-baby/baby-development-controls-batch-saved/README.md) |
| Cancel observation date → date and statuses retained | [运行证据](../04-baby/baby-development-controls-date-cancelled/README.md) |
| Input yesterday before confirming observation date | [运行证据](../04-baby/baby-development-controls-date-input/README.md) |
| Open observation date constrained by birth and today | [运行证据](../04-baby/baby-development-controls-date-open/README.md) |
| Confirm yesterday → all observations share selected date | [运行证据](../04-baby/baby-development-controls-date-selected/README.md) |
| Close dirty observation draft → discard confirmation | [运行证据](../04-baby/baby-development-controls-discard-confirm/README.md) |
| Continue filling → three selections retained | [运行证据](../04-baby/baby-development-controls-discard-retained/README.md) |
| Tap developmental observation → three unselected behavior groups | [运行证据](../04-baby/baby-development-controls-editor-empty/README.md) |
| Open developmental history → each behavior and saved status | [运行证据](../04-baby/baby-development-controls-history/README.md) |
| Choose 观察到 for this existing behavior | [运行证据](../04-baby/baby-development-controls-history-lifts-head-changed/README.md) |
| Clear original status and save → required validation; stored record unchanged | [运行证据](../04-baby/baby-development-controls-history-lifts-head-cleared/README.md) |
| Edit 俯卧时短暂抬起头 → only original behavior available | [运行证据](../04-baby/baby-development-controls-history-lifts-head-open/README.md) |
| Save changed status → same record updated; other behaviors retained | [运行证据](../04-baby/baby-development-controls-history-lifts-head-saved/README.md) |
| Choose 暂未观察到 for this existing behavior | [运行证据](../04-baby/baby-development-controls-history-looks-at-face-changed/README.md) |
| Clear original status and save → required validation; stored record unchanged | [运行证据](../04-baby/baby-development-controls-history-looks-at-face-cleared/README.md) |
| Edit 看向靠近的脸 → only original behavior available | [运行证据](../04-baby/baby-development-controls-history-looks-at-face-open/README.md) |
| Save changed status → same record updated; other behaviors retained | [运行证据](../04-baby/baby-development-controls-history-looks-at-face-saved/README.md) |
| Reopen first edited behavior → saved status persists | [运行证据](../04-baby/baby-development-controls-history-reopened/README.md) |
| Choose 不确定 for this existing behavior | [运行证据](../04-baby/baby-development-controls-history-responds-to-sound-changed/README.md) |
| Clear original status and save → required validation; stored record unchanged | [运行证据](../04-baby/baby-development-controls-history-responds-to-sound-cleared/README.md) |
| Edit 听到声音后有动作或表情反应 → only original behavior available | [运行证据](../04-baby/baby-development-controls-history-responds-to-sound-open/README.md) |
| Save changed status → same record updated; other behaviors retained | [运行证据](../04-baby/baby-development-controls-history-responds-to-sound-saved/README.md) |
| More → Baby before developmental observation controls | [运行证据](../04-baby/baby-development-controls-home-entry/README.md) |
| Return Baby after developmental history edits | [运行证据](../04-baby/baby-development-controls-home-return/README.md) |
| Tap selected unsure again → clear 俯卧时短暂抬起头 | [运行证据](../04-baby/baby-development-controls-lifts-head-cleared/README.md) |
| Select 俯卧时短暂抬起头 → 暂未观察到 | [运行证据](../04-baby/baby-development-controls-lifts-head-notObserved/README.md) |
| Select 俯卧时短暂抬起头 → 观察到 | [运行证据](../04-baby/baby-development-controls-lifts-head-observed/README.md) |
| Select 俯卧时短暂抬起头 → 不确定 | [运行证据](../04-baby/baby-development-controls-lifts-head-unsure/README.md) |
| Tap selected unsure again → clear 看向靠近的脸 | [运行证据](../04-baby/baby-development-controls-looks-at-face-cleared/README.md) |
| Select 看向靠近的脸 → 暂未观察到 | [运行证据](../04-baby/baby-development-controls-looks-at-face-notObserved/README.md) |
| Select 看向靠近的脸 → 观察到 | [运行证据](../04-baby/baby-development-controls-looks-at-face-observed/README.md) |
| Select 看向靠近的脸 → 不确定 | [运行证据](../04-baby/baby-development-controls-looks-at-face-unsure/README.md) |
| Baby → More after developmental observation chain | [运行证据](../04-baby/baby-development-controls-more-return/README.md) |
| Tap save → 至少记录一项具体行为，拿不准可以选择“不确定”。; no write request | [运行证据](../04-baby/baby-development-controls-required-error/README.md) |
| Tap selected unsure again → clear 听到声音后有动作或表情反应 | [运行证据](../04-baby/baby-development-controls-responds-to-sound-cleared/README.md) |
| Select 听到声音后有动作或表情反应 → 暂未观察到 | [运行证据](../04-baby/baby-development-controls-responds-to-sound-notObserved/README.md) |
| Select 听到声音后有动作或表情反应 → 观察到 | [运行证据](../04-baby/baby-development-controls-responds-to-sound-observed/README.md) |
| Select 听到声音后有动作或表情反应 → 不确定 | [运行证据](../04-baby/baby-development-controls-responds-to-sound-unsure/README.md) |
| Batch POST fails 503 → unconfirmed save, draft locked and retry | [运行证据](../04-baby/baby-development-controls-save-uncertain/README.md) |
| Retry save → pending request and disabled saving action | [运行证据](../04-baby/baby-development-controls-saving/README.md) |
| Close unconfirmed observation save → uncertainty warning | [运行证据](../04-baby/baby-development-controls-uncertain-close/README.md) |
| Stay on unconfirmed draft without resubmitting | [运行证据](../04-baby/baby-development-controls-uncertain-retained/README.md) |

## 验证与待补范围

- [严格采集](runs/20260913T223727-targeted/capture.log)：2 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-development-control-analyze.log)：No issues found，退出码 0。新测试只读格式检查 0 changed。
- 新增测试初次运行两尺寸通过；静态检查发现一处 if 缺大括号，修正后重新严格采集，图像基线未变。本批未修改业务代码。
- 尚未覆盖：未确认保存后离开、保存中平台返回、权限/版本冲突及其他错误、日期范围/年月/缺失出生日期、单项与两项创建的其余组合、各观察删除/恢复、原生输入和系统层。
- 剩余分支见 [Baby 控件清单](BABY-CONTROL-COVERAGE.md)。本批没有把已有通用删除链当作所有发育观察删除状态均已覆盖，也没有声称 Android/iOS 实体设备验证。

全 App UI/UX 盘点继续保持未完成；本批统计和完整性通过不能证明全体交互已覆盖。


## Android 原生补验

[实际放弃草稿与重新进入](../native/baby-development-discard/README.md)：11 张原生窗口，已实际选择第一项、关闭、点击“离开”、重新进入确认空草稿，再恢复原 Mia 首页。上述 host 批次未点离开的缺口在普通脏草稿场景已补；保存未确认后离开仍未覆盖。


日期边界、月切换、单项保存与未确认离开后重新进入已在 [后续补验](BABY-DEVELOPMENT-BOUNDARIES.md) 执行；本报告上文待办为原批次范围，以 Baby 控件清单的当前条目为准。


单项、两项创建及三类记录的删除/取消/恢复已在 [记录管理补验](BABY-DEVELOPMENT-MANAGEMENT.md) 完成，异常删除与并发仍待补齐。
