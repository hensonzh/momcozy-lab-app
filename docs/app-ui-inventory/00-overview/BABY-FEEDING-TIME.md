# Baby 喂养日期、时间与有效边界保存

通过正式用户 App 的 More → Baby → 今日吃奶，使用实际路由、Repository 与 codec，隔离 HTTP/会话/时钟；393 px / 1x 与 320 px / 2x 均经真实组件点击和文本输入。未对真实账号写入喂养数据，未调用按钮回调或直接改写编辑器草稿。

## 运行结果

- 打开“发生时间”，普通字号先显示日历，大字号直接显示日期输入；注入的当前日期为 2026-09-13，当前时间为上海 16:00，已断言选择器 currentDate。
- 取消日期选择保持原值。输入前一天并确认后进入第二步时间选择，此时编辑器仍保持原时间；取消时间后，刚选的前一天也被丢弃。
- 输入次日 2026-09-14 并确认，日期框显示“超出范围”，不进入时间选择。
- 改为当天后，输入 24:60 并确认，提示“请输入有效的时间”；改为 16:01 可进入记录草稿，但保存被“发生时间不能晚于现在”拒绝，断言没有写请求。
- 重新选为当前 16:00 后可保存。亲喂右侧且时长留空，历史显示“时长未填写”，重开时仍为空；没有虚构时长。
- 历史中改为 1 分钟并保存，再重开验证最小有效时长。切成瓶喂母乳并以 1000 ml 实际保存、重开，返回数据保留 1000，旧侧别和亲喂时长为空。该链补足 [前批](BABY-FEEDING-CONTROLS.md) 仅输入 1000、未以该值提交的边界。
- 编辑器重开奶量显示 `1000.0`，列表与首页显示 `1000 ml`。这是现有数值格式差异，初始测试误期望字符串 `1000`，已按真实 DTO double 回显修正，未改产品格式。
- 从历史返回 Baby 后摘要显示 1 次和已记录瓶喂 1000 ml，最后切 More。

## 视觉检查

22 个状态、44 个视口、16 张长图；60 张原始 PNG 分为 142 个连续全宽片段、95 个唯一片段。58 个新片段的 10 张审阅页全部查看，37 个片段与此前审阅的图像逐像素一致。来源 SHA、完整纵向覆盖和每个片段对应审阅页的像素均核对通过，见 [来源](baby-feeding-time-visual-review/sources.json) 与 [审计](baby-feeding-time-evidence-audit.json)。

- 大字号日期输入框留白较多，但输入、错误提示、取消与确定完整可见；正常字号日历将未来日期置灰。
- 时间错误在普通字号合并显示一条，在大字号两个字段下分别显示。**大字模式修正数值后，旧错误仍保留到再次点击确定；普通字号修正后已清除。** 如实保留两种显示差异，不把输入已合法等同于错误文字已消失。
- 时间选择器叠在喂养编辑器之上，背景两层遮罩；长图选取最上层滚动区域，没有将下层编辑器正文混入日期弹窗。
- “时长未填写”在大字历史卡换为多行；保存提示与底部操作可见。原始交互视口与完整长图单独保留。

## 状态和前驱

| 实际触发 | 截图、长图与前驱 |
| --- | --- |
| Select exactly now → future validation cleared | [运行证据](../04-baby/baby-feeding-time-current-minute-restored/README.md) |
| Cancel date → original instant unchanged | [运行证据](../04-baby/baby-feeding-time-date-cancelled/README.md) |
| Open occurred date; today follows fixed timezone clock | [运行证据](../04-baby/baby-feeding-time-date-open/README.md) |
| Confirm tomorrow → date range validation, no time picker | [运行证据](../04-baby/baby-feeding-time-future-date-rejected/README.md) |
| Correct to 16:01 on today; one minute after current time | [运行证据](../04-baby/baby-feeding-time-future-minute-input/README.md) |
| Tap save → 发生时间不能晚于现在。; no write request | [运行证据](../04-baby/baby-feeding-time-future-minute-rejected/README.md) |
| Confirm syntactically valid future minute into draft | [运行证据](../04-baby/baby-feeding-time-future-minute-selected/README.md) |
| More → Baby before time controls | [运行证据](../04-baby/baby-feeding-time-home-entry/README.md) |
| Return Baby → actual 1000 ml home summary | [运行证据](../04-baby/baby-feeding-time-home-volume-refreshed/README.md) |
| Confirm hour 24/minute 60 → invalid time; picker remains | [运行证据](../04-baby/baby-feeding-time-invalid-clock/README.md) |
| Change to expressed milk; enter maximum 1000 ml | [运行证据](../04-baby/baby-feeding-time-maximum-volume-ready/README.md) |
| Reopen and verify 1000 ml persisted | [运行证据](../04-baby/baby-feeding-time-maximum-volume-reopened/README.md) |
| Save maximum bottle volume; nursing fields removed | [运行证据](../04-baby/baby-feeding-time-maximum-volume-saved/README.md) |
| Save minimum one-minute duration in history | [运行证据](../04-baby/baby-feeding-time-minimum-duration-saved/README.md) |
| Baby → More after time and valid-boundary chain | [运行证据](../04-baby/baby-feeding-time-more-return/README.md) |
| Choose nursing/right with optional duration empty | [运行证据](../04-baby/baby-feeding-time-nursing-ready/README.md) |
| Open history → saved nursing without invented duration | [运行证据](../04-baby/baby-feeding-time-optional-duration-history/README.md) |
| Reopen history → empty optional duration and current instant persisted | [运行证据](../04-baby/baby-feeding-time-optional-duration-reopened/README.md) |
| Save nursing at current minute without duration → one count | [运行证据](../04-baby/baby-feeding-time-optional-duration-saved/README.md) |
| Enter previous date before confirmation | [运行证据](../04-baby/baby-feeding-time-previous-day-input/README.md) |
| Cancel second-stage time → selected date also discarded | [运行证据](../04-baby/baby-feeding-time-time-cancelled/README.md) |
| Confirm date → time picker; editor instant still unchanged | [运行证据](../04-baby/baby-feeding-time-time-open/README.md) |

## 验证及剩余范围

- [严格采集](runs/20260913T215431-targeted/capture.log)：2 项通过，未更新 Golden 基线。同目录执行命令和退出码留存。
- [全仓分析](baby-feeding-time-analyze.log)：No issues found，退出码 0。仅移除了新增测试中未使用的 import；产品代码未改动。
- 只读格式检查：新增测试 0 changed。
- 未在设备运行键盘；时区回拨/跳时、其他日期导航与输入分支、2000 字备注、权限和冲突等仍按当前实现继续盘点。此测试使用上海时区，不代表验证了所有时区。

所有有意义控件分支及全体历史图像的审阅仍未完成，见 [Baby 控件清单](BABY-CONTROL-COVERAGE.md) 与 [完成审计](AUDIT.md)。
