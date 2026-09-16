# 身体与泌乳备注边界、内部滚动与保存回显

正式用户 App：More → Me → 身体与精力 → 保存 / 重开 / 放弃草稿 → 记录一次泌乳 → 保存 / 编辑 / 放弃草稿 → 关闭回首页 → More。393 px / 1x 与 320 px / 2x 均实际执行。正式 GoRouter、Controller、Repository 与编解码保留，HTTP 和会话使用隔离 fixture；不写入真实账号。

## 行为证据

- 两类备注均执行空值 → 1999 字 → 2000 字 → 尝试输入第 2001 字，断言输入框与草稿保留前 2000 字。测试文本以“开始”起首、以“完成”结尾，便于检查边界。
- 实际拖动输入框到开头和结尾，断言内部 ScrollPosition 为 min/max；截图显示对应文本，计数维持 2000/2000。
- 保存后重开，逐字断言 2000 字完整保留。清空只改变草稿；关闭 → 放弃后保存版本仍为 1，原备注保留。
- 身体仅填写备注可保存，首页完成数变成 1/3，但身体卡标题仍为“待记录”，副文案为“未补充不适情况”。该不一致是实际 UI，不把它描述为完整身体指标已填写。
- 泌乳未填写可选奶量也可保存；首页按 1 次计数，列表显示奶量未填写，趋势不生成虚假的 ml 值。

## 状态与前后关系

| 实际操作 | 截图、长图与前驱 |
| --- | --- |
| Enter body note one character below limit → 1999/2000 | [运行证据](../03-mom/mom-note-boundary-body-1999/README.md) |
| Enter body note at limit → 2000/2000 | [运行证据](../03-mom/mom-note-boundary-body-2000/README.md) |
| Clear saved body note in draft → 0/2000 | [运行证据](../03-mom/mom-note-boundary-body-cleared/README.md) |
| Close cleared body note → discard confirmation | [运行证据](../03-mom/mom-note-boundary-body-discard-confirm/README.md) |
| Body editor → focus empty optional note | [运行证据](../03-mom/mom-note-boundary-body-empty/README.md) |
| Close saved body note → home counts 1/3; body headline remains 待记录 | [运行证据](../03-mom/mom-note-boundary-body-home/README.md) |
| Drag body note to end → 完成 | [运行证据](../03-mom/mom-note-boundary-body-note-scroll-end/README.md) |
| Drag body note to start → 开始 | [运行证据](../03-mom/mom-note-boundary-body-note-scroll-start/README.md) |
| Attempt 2001 body characters → formatter retains first 2000 | [运行证据](../03-mom/mom-note-boundary-body-overflow-truncated/README.md) |
| Reopen saved body note → all 2000 characters retained | [运行证据](../03-mom/mom-note-boundary-body-reopened/README.md) |
| Discard cleared draft → saved body note remains | [运行证据](../03-mom/mom-note-boundary-body-retained/README.md) |
| Save body note at maximum → success feedback | [运行证据](../03-mom/mom-note-boundary-body-saved/README.md) |
| More → Me → initial home | [运行证据](../03-mom/mom-note-boundary-home-entry/README.md) |
| Close lactation list → home | [运行证据](../03-mom/mom-note-boundary-home-return/README.md) |
| Enter lactation note one character below limit → 1999/2000 | [运行证据](../03-mom/mom-note-boundary-milk-1999/README.md) |
| Enter lactation note at limit → 2000/2000 | [运行证据](../03-mom/mom-note-boundary-milk-2000/README.md) |
| Clear maximum lactation note in draft → 0/2000 | [运行证据](../03-mom/mom-note-boundary-milk-cleared/README.md) |
| Cancel cleared lactation note → discard confirmation | [运行证据](../03-mom/mom-note-boundary-milk-discard-confirm/README.md) |
| Open lactation optional note → empty | [运行证据](../03-mom/mom-note-boundary-milk-empty/README.md) |
| Drag lactation note to end → 完成 | [运行证据](../03-mom/mom-note-boundary-milk-note-scroll-end/README.md) |
| Drag lactation note to start → 开始 | [运行证据](../03-mom/mom-note-boundary-milk-note-scroll-start/README.md) |
| Attempt 2001 lactation characters → formatter retains first 2000 | [运行证据](../03-mom/mom-note-boundary-milk-overflow-truncated/README.md) |
| Edit saved lactation → all 2000 characters retained | [运行证据](../03-mom/mom-note-boundary-milk-reopened/README.md) |
| Discard cleared note → original long record remains | [运行证据](../03-mom/mom-note-boundary-milk-retained/README.md) |
| Save maximum note without optional measurement → long record list | [运行证据](../03-mom/mom-note-boundary-milk-saved-long-note/README.md) |
| Bottom More → original tab | [运行证据](../03-mom/mom-note-boundary-more-return/README.md) |

## 长图与视觉范围

26 个逻辑状态，52 个视口变体，46 张外层页面长图；其中 23 个状态以长图为主图。98 张原图连续全宽分为 343 段，256 种唯一像素片段。219 个新片段组成 37 张审阅图，已全部查看；37 个片段逐像素匹配此前已审阅证据。来源、连续范围和审阅图位置见 [分段清单](mom-note-boundary-visual-review/sources.json) 与 [证据审计](mom-note-boundary-evidence-audit.json)。

采集器识别“一个外层表单 + 其内部 EditableText 滚动区”，只展开外层文档；输入框保持实际尺寸与当前内部滚动位置。元数据明确 `nested_editable_contents_expanded=false`，首尾滚动另有实际拖动截图。没有把完整表单长图当作展开全部输入文本的截图。两个独立滚动页面仍保留人工复核判定。状态 README 已补充该边界。

- 320 px / 2x 身体输入框的标签省略，视口末端的字数计数可被表单底部截断；完整外层长图能显示计数和保存按钮。
- 保存后的泌乳列表把完整备注放在狭窄的记录信息列，小屏大字时每行约两字。最长原图 320 × 35327，放弃清空后的保留列表为 320 × 35249；从标题、趋势、记录行直到“完成”和列表底部均已连续检查。这是实际布局带来的阅读负担，不通过截断记录或缩小字号掩盖。
- 拼接保留滚动区域的实际全宽画面，弹窗外背景在长图两侧可能出现条带；主文档的文字按真实滚动偏移连续保留。
- 指针起点文字只是矩形附近匹配，可能包含被遮挡背景，并非命中测试。README 已明确说明；实际操作目标由测试 Finder、状态断言与独立 journey trigger 证明。
- 本轮是宿主 Flutter 实际组件与路由交互，未将文字注入当作原生键盘、输入法组合文本或复制粘贴菜单验收。

## 验证

- [最终严格采集](runs/20260913T201608-targeted/capture.log)：2 项通过，0 失败；[命令](runs/20260913T201608-targeted/capture-command.json) 与 [退出码](runs/20260913T201608-targeted/capture-result.json) 留存，未放宽金图比较。调试阶段产生的 34 条过期观察已归档在该运行目录，当前索引只使用 52 条最新观察。
- [全仓静态检查](mom-note-boundary-analyze.log)：No issues found；两个修改的 Dart 文件格式检查 0 changed；索引脚本语法检查通过。
- 采集器跨模块回归执行 Auth / Baby / Schedule 三个测试文件：[25 项通过、2 项失败](mom-note-collector-regression.log)。成功产生的 254 张视口及长图与既有证据全部逐字节一致，见 [比较结果](mom-note-collector-comparison.json)。其中 66 张为长图。
- 两项失败均在 [关闭采集器的普通测试中独立复现](mom-note-date-baseline-regression.log)，位于 Baby 生长记录日期选择器及日程新增日期选择器。已查看日程对比，选择日仍为 9 月 13 日，但实际日跨到 14 日后增加“今天”描边；[原基线](mom-note-date-regression/schedule-journey-date-picker-393_masterImage.png) 与 [当前图](mom-note-date-regression/schedule-journey-date-picker-393_testImage.png) 留存。未更新这两张基线来掩盖时间不稳定性，该轮跨模块回归不能声称全绿；后续已完成时钟修复，60 项测试与 27 项严格采集通过，267 张既有图片不变，见 [日期回归解决记录](DATE-CLOCK-REGRESSION.md)。

## 修改与待补

新增 `test/modules/mom/mom_note_boundary_inventory_test.dart`；修改测试采集器 `test/support/ui_inventory_capture.dart` 与索引脚本 `scripts/index-app-ui-inventory.py`。生产 UI 未修改。

备注边界已补齐；后续 [泌乳数值/时间校验与返回流程](MOM-MILK-VALIDATION.md) 已补验。[表盘点选](MOM-MILK-DIAL.md) 后续已补验；原生键盘、设备返回与全体历史截图审阅仍待补。[控件清单](MOM-CONTROL-COVERAGE.md) 和 [全局完成审计](AUDIT.md) 保持未完成。
