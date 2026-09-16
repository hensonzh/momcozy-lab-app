# Baby 睡眠时间、进行中记录与历史编辑

从正式用户 App 的 More → Baby → 睡眠卡片进入，完成时间与备注操作、保存、记录醒来，再通过“查看全部记录”→“睡眠”→编辑→返回。393 px / 1x 与 320 px / 2x 均运行真实 GoRouter、Repository 和 codec；HTTP、会话、时钟与原生依赖为隔离 fixture。通过 WidgetTester 实际点击和输入，未直接调用回调修改草稿。

## 已验证的操作与结果

- 新增默认入睡时间为 16:00，醒来时间为空。入睡日期确认后打开时间选择器，取消保持原入睡时间；空醒来时间打开当前日期/16:00，取消仍为空。
- 将入睡设为 16:01，草稿可暂存；点击保存显示“发生时间不能晚于现在。”，没有写请求。改为 15:00 后错误清除。
- 醒来依次选 15:00（等于入睡）、14:59（早于入睡）、16:01（晚于现在），均实际点击保存并被“醒来时间需要晚于入睡时间，且不能晚于现在。”拒绝，没有写请求。
- 选择 16:00 为有效草稿；点击“清除时间”恢复空结束时间与进行中保存动作。
- 备注展开、输入首尾空格及换行、折叠，保留草稿。新建保存后仅一条记录，入睡 15:00、ended_at=null，备注由 33 字符清理为 29 字符，正文换行保留。
- 首页重新点睡眠进入进行中简版卡片；展开“调整时间和备注”、收起、再次展开，保存的备注与时间回显。
- 手动选醒来 15:30 后仅保存于草稿，本批没有提交该值。清除后点击“记录醒来时间为现在”，同一条记录结束于 16:00，version=2；首页显示累计 1 小时。
- 从睡眠历史编辑已完成记录，清除醒来并保存，ended_at=null、version=3；历史重开可确认其已恢复进行中。此入口直接展示可编辑时间，不使用首页的进行中简版卡片。
- 未修改关闭没有放弃确认，返回 Baby 显示进行中，再回 More。

所有写请求发生在隔离 fixture，未向原账号新增健康记录。本批没有运行 Android/iOS 睡眠输入链。

## 完整截图与视觉检查

36 个逻辑状态、72 个视口变体，49 张完整长图，19 个状态以长图为主图。121 张原始 PNG 拆成 284 个连续全宽片段，其中 179 个唯一片段；157 个新片段组成 27 页，全部查看；22 个片段与此前已审阅图像逐像素一致。来源 SHA、尺寸、全高连续性及审阅页对应像素均校验通过，见 [分段来源](baby-sleep-control-visual-review/sources.json) 与 [证据审计](baby-sleep-control-evidence-audit.json)。

- 320 px / 2x 编辑器标题及“记录醒来时间为现在”分两行，按钮仍完整可见。长图完整保留起止、备注、校验、固定标题与唯一保存操作。
- 393 px 进行中简版卡片下方有较大留白，源于当前最小高度；本次如实保留。首页在记录完成后显示累计 1 小时，历史清除结束时间保存后恢复“记录中”。
- 320 px / 2x 空备注提示为“备注（可…”省略，填入后浮动标签完整，计数 33→29。历史备注自动换行。
- 日期选择器在 320 px / 2x 默认输入模式，普通尺寸为日历；时间输入两列。验证文字、确认与取消按钮均可见，没有以缩小字体规避布局。
- 历史中清除结束时间尚未保存时仍显示原说明；提交后重新打开说明消失，与编辑目标更新时机一致。

## 状态与前驱

| 实际触发动作 | 截图、长图与前驱 |
| --- | --- |
| Collapse time and note controls without modifying record | [运行证据](../04-baby/baby-sleep-controls-active-collapsed/README.md) |
| Expand active sleep times and saved note | [运行证据](../04-baby/baby-sleep-controls-active-expanded/README.md) |
| Choose manual wake 15:30 in active editor | [运行证据](../04-baby/baby-sleep-controls-active-manual-wake/README.md) |
| Tap active sleep → compact status and record wake now | [运行证据](../04-baby/baby-sleep-controls-active-open/README.md) |
| Save active sleep with empty wake → home active record | [运行证据](../04-baby/baby-sleep-controls-active-saved/README.md) |
| Clear manual wake → record wake now action restored | [运行证据](../04-baby/baby-sleep-controls-active-wake-cleared/README.md) |
| Record wake now → same record updated, one hour complete | [运行证据](../04-baby/baby-sleep-controls-completed-now/README.md) |
| Reopen active interval from history → editable times visible | [运行证据](../04-baby/baby-sleep-controls-history-active-reopened/README.md) |
| Save history edit with no wake → active interval persisted | [运行证据](../04-baby/baby-sleep-controls-history-active-saved/README.md) |
| History sleep tab → completed record with start/end and note | [运行证据](../04-baby/baby-sleep-controls-history-completed/README.md) |
| Edit completed sleep → start, wake and note restored | [运行证据](../04-baby/baby-sleep-controls-history-editor/README.md) |
| Clear saved wake in history editor → draft becomes open interval | [运行证据](../04-baby/baby-sleep-controls-history-wake-cleared/README.md) |
| Return Baby → reopened sleep shown as active | [运行证据](../04-baby/baby-sleep-controls-home-active-return/README.md) |
| More → Baby before sleep controls | [运行证据](../04-baby/baby-sleep-controls-home-entry/README.md) |
| Baby → More after sleep control chain | [运行证据](../04-baby/baby-sleep-controls-more-return/README.md) |
| Tap sleep status → start now, optional wake empty | [运行证据](../04-baby/baby-sleep-controls-new-open/README.md) |
| Collapse filled note → value retained | [运行证据](../04-baby/baby-sleep-controls-note-collapsed/README.md) |
| Expand optional sleep note | [运行证据](../04-baby/baby-sleep-controls-note-expanded/README.md) |
| Enter short sleep note with surrounding spaces and newline | [运行证据](../04-baby/baby-sleep-controls-note-filled/README.md) |
| Cancel start clock → original start retained | [运行证据](../04-baby/baby-sleep-controls-start-cancelled/README.md) |
| Open sleep start date picker | [运行证据](../04-baby/baby-sleep-controls-start-date/README.md) |
| Choose start one minute in future | [运行证据](../04-baby/baby-sleep-controls-start-future/README.md) |
| Tap save → 发生时间不能晚于现在。; no write request | [运行证据](../04-baby/baby-sleep-controls-start-future-rejected/README.md) |
| Correct start to 15:00, validation cleared | [运行证据](../04-baby/baby-sleep-controls-start-past/README.md) |
| Confirm date → sleep start time picker | [运行证据](../04-baby/baby-sleep-controls-start-time/README.md) |
| Select wake 14:59 before validation | [运行证据](../04-baby/baby-sleep-controls-wake-before/README.md) |
| Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request | [运行证据](../04-baby/baby-sleep-controls-wake-before-rejected/README.md) |
| Cancel wake clock → optional wake remains empty | [运行证据](../04-baby/baby-sleep-controls-wake-cancelled/README.md) |
| Clear wake → active sleep save action restored | [运行证据](../04-baby/baby-sleep-controls-wake-cleared/README.md) |
| Open empty wake date → current date | [运行证据](../04-baby/baby-sleep-controls-wake-date-empty/README.md) |
| Select wake 15:00 before validation | [运行证据](../04-baby/baby-sleep-controls-wake-equal/README.md) |
| Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request | [运行证据](../04-baby/baby-sleep-controls-wake-equal-rejected/README.md) |
| Select wake 16:01 before validation | [运行证据](../04-baby/baby-sleep-controls-wake-future/README.md) |
| Tap save → 醒来时间需要晚于入睡时间，且不能晚于现在。; no write request | [运行证据](../04-baby/baby-sleep-controls-wake-future-rejected/README.md) |
| Confirm wake date → current clock, not yet committed | [运行证据](../04-baby/baby-sleep-controls-wake-time-empty/README.md) |
| Choose valid wake at current time → validation cleared | [运行证据](../04-baby/baby-sleep-controls-wake-valid/README.md) |

## 验证与待补范围

- [严格采集](runs/20260913T221646-targeted/capture.log)：2 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-sleep-control-analyze.log)：No issues found，退出码 0；新增测试只读格式检查 0 changed。
- 本批未修改业务代码。初次测试在保存后向下寻找上方懒加载卡片失败；修正为实际反向滚动到 Luna 再点击睡眠卡片，两个尺寸随后通过。
- 跨午夜、时区/DST、其余日期选择分支、手动醒来 15:30 的实际提交、active_sleep_exists、权限/版本冲突、保存未确认及保存中关闭、2000 字和系统输入仍待补。
- 共同新增/删除/撤销链见 [Baby 路由链](BABY-JOURNEYS.md)，剩余范围见 [控件清单](BABY-CONTROL-COVERAGE.md)。时间输入 helper 的后续重复步骤虽有真实点击，本批仅在首次起止时间选择时采集中间选择器，不宣称覆盖所有日期与时间模式组合。

全 App UI/UX 盘点保持未完成；本批数量与完整性校验不证明全体交互覆盖。
