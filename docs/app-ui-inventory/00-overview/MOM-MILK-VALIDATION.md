# 泌乳数值、时间校验与返回路径

正式用户 App 的 More → Me → 记录一次泌乳入口，沿真实新增、保存、编辑和返回链执行。393 px / 1x 与 320 px / 2x 均使用正式 GoRouter、Controller、Repository 和编解码，HTTP、会话、时钟与时区使用隔离 fixture；不写入真实账号。

## 实际行为

- 泵奶提交 -1、2001、abc、NaN 均被拒绝，断言具体字段错误且未写入记录。改为 0 后错误清除并成功保存；编辑为 2000 后保存为版本 2。
- 从泵奶切换亲喂会清空测量草稿。提交 -1、241、1.5 均被拒绝，原版本 2 保留；240 与 0 均能保存，分别变为版本 3、4。0 是已记录数值，与“未填写”不同。
- 固定当前时间 16:00，实际打开选择器、进入输入模式、选择下午并输入 05:00。选择器接受 17:00，保存记录时拒绝未来时间，版本 4 不变。重新打开、选择上午、输入 08:00，确认后清除错误并成功保存版本 5。
- 编辑页顶部“返回记录”即使没有修改字段仍弹出放弃确认。“继续填写”保留草稿；再次返回并选择“离开”回到记录列表，保存版本 5 不变。
- 重新编辑后派发 Flutter 平台返回事件，同样出现确认；选择“离开”关闭面板并回到首页，版本 5 不变。这与顶部“返回记录”回列表的去向不同。

## 状态与前驱

| 实际操作 | 截图、长图与前驱 |
| --- | --- |
| Dispatch platform back → discard confirmation | [运行证据](../03-mom/mom-milk-validation-back-confirm/README.md) |
| Reopen saved record before platform back | [运行证据](../03-mom/mom-milk-validation-back-editor/README.md) |
| Confirm platform back → preserve saved record | [运行证据](../03-mom/mom-milk-validation-back-left/README.md) |
| Home record milk → empty pump form | [运行证据](../03-mom/mom-milk-validation-empty/README.md) |
| Accept valid clock 17:00 → record draft has future time | [运行证据](../03-mom/mom-milk-validation-future-time-accepted/README.md) |
| Select PM and enter 05:00 → 17:00 after fixed current 16:00 | [运行证据](../03-mom/mom-milk-validation-future-time-input/README.md) |
| Save future record → validation, version 4 retained | [运行证据](../03-mom/mom-milk-validation-future-time-rejected/README.md) |
| More → Me | [运行证据](../03-mom/mom-milk-validation-home-entry/README.md) |
| Close remaining panel → home | [运行证据](../03-mom/mom-milk-validation-home-return/README.md) |
| Me → More | [运行证据](../03-mom/mom-milk-validation-more-return/README.md) |
| Submit nursing 241 → out_of_range; saved version remains 2 | [运行证据](../03-mom/mom-milk-validation-nurse-above-limit/README.md) |
| Convert pump to nursing → numeric draft clears | [运行证据](../03-mom/mom-milk-validation-nurse-empty/README.md) |
| Submit nursing 1.5 → invalid_number; saved version remains 2 | [运行证据](../03-mom/mom-milk-validation-nurse-fraction/README.md) |
| Correct nursing to upper boundary 240 | [运行证据](../03-mom/mom-milk-validation-nurse-limit-filled/README.md) |
| Save nursing 240 minutes → version 3 | [运行证据](../03-mom/mom-milk-validation-nurse-limit-saved/README.md) |
| Submit nursing -1 → out_of_range; saved version remains 2 | [运行证据](../03-mom/mom-milk-validation-nurse-negative/README.md) |
| Edit nursing → lower boundary 0 | [运行证据](../03-mom/mom-milk-validation-nurse-zero-filled/README.md) |
| Save nursing 0 minutes → version 4 | [运行证据](../03-mom/mom-milk-validation-nurse-zero-saved/README.md) |
| Accept 08:00 → future error clears | [运行证据](../03-mom/mom-milk-validation-past-time-accepted/README.md) |
| Enter past time 08:00 AM | [运行证据](../03-mom/mom-milk-validation-past-time-input/README.md) |
| Save corrected past time → version 5 | [运行证据](../03-mom/mom-milk-validation-past-time-saved/README.md) |
| Submit pump 2001 → out_of_range; no write | [运行证据](../03-mom/mom-milk-validation-pump-above-limit/README.md) |
| Edit pump → upper boundary 2000 | [运行证据](../03-mom/mom-milk-validation-pump-limit-filled/README.md) |
| Save pump 2000 ml → version 2 | [运行证据](../03-mom/mom-milk-validation-pump-limit-saved/README.md) |
| Submit pump -1 → out_of_range; no write | [运行证据](../03-mom/mom-milk-validation-pump-negative/README.md) |
| Submit pump NaN → out_of_range; no write | [运行证据](../03-mom/mom-milk-validation-pump-not-finite/README.md) |
| Submit pump abc → invalid_number; no write | [运行证据](../03-mom/mom-milk-validation-pump-not-number/README.md) |
| Correct pump to lower boundary 0 → error clears | [运行证据](../03-mom/mom-milk-validation-pump-zero-filled/README.md) |
| Save pump 0 ml → one real fixture record | [运行证据](../03-mom/mom-milk-validation-pump-zero-saved/README.md) |
| Tap top Return records → discard confirmation | [运行证据](../03-mom/mom-milk-validation-return-record-confirm/README.md) |
| Return records → leave → unchanged list | [运行证据](../03-mom/mom-milk-validation-return-record-left/README.md) |
| Continue editing → same draft | [运行证据](../03-mom/mom-milk-validation-return-record-stay/README.md) |
| Select AM instead of PM | [运行证据](../03-mom/mom-milk-validation-time-am-selected/README.md) |
| Time dial → input mode | [运行证据](../03-mom/mom-milk-validation-time-input/README.md) |
| Open time picker at current 16:00 | [运行证据](../03-mom/mom-milk-validation-time-open/README.md) |

## 视觉证据与发现

35 个逻辑状态，69 个视口变体、52 张外层页面长图、25 个以长图为主图的状态。121 张原图按全宽连续切成 250 段，158 个唯一像素片段；126 个新片段组成 21 张审阅图，均已查看，其余 32 个逐像素匹配此前已审阅片段。最终严格采集后的原图 SHA 与审阅来源完全一致；段落连续性、像素和审阅图坐标均再次校验。见 [分段来源](mom-milk-validation-visual-review/sources.json) 和 [证据审计](mom-milk-validation-evidence-audit.json)。

- 所有数值错误与未来时间错误使用同一段“请检查记录时间和数值”提示。未来时间没有明确解释“不能晚于当前时间”，用户需自行判断；17:00 草稿保留。
- 320 px / 2x 的 2000 ml 趋势值拆为两行，第一行为“200”，第二行为“0 ml”；已保存记录中的时间与编辑/删除操作挤压记录说明列，亲喂侧别会逐字换行。保留原状作为后续重构依据。
- 大字号错误消息多行显示，完整长图包含提示和底部取消、保存按钮。普通字号为原生 Material 时钟/输入切换，小屏大字号自动使用竖向输入选择器；本轮均保留上午/下午选中状态。
- `abc`、NaN 通过宿主文本输入协议进入真实输入框，证明 Controller 的防御校验；没有证明设备数字键盘能直接输入这些字符，也没有验收原生粘贴菜单。
- 返回事件由 `tester.binding.handlePopRoute()` 派发，覆盖正式 Flutter 返回处理；本轮没有操作 Android 物理返回键或系统手势。后续 [表盘点选与横向滚动](MOM-MILK-DIAL.md) 已补验，原生输入层仍待补。
- 外层长图保留真实弹窗边界与背景，不能据此声称整个 App 的历史长图已全部审阅。

## 验证

- [最终严格采集日志](runs/20260913T202707-targeted/capture.log)：2 项通过，0 失败。初始建立新增状态金图后，最终运行未更新基线；[命令](runs/20260913T202707-targeted/capture-command.json)、[退出码](runs/20260913T202707-targeted/capture-result.json) 留存。
- [全仓静态检查](mom-milk-validation-analyze.log)：No issues found。测试中的两处缺失大括号已修正，最终采集使用修正后的源文件。
- 新增测试 `test/modules/mom/mom_milk_validation_inventory_test.dart`；泌乳生产行为未修改。此前阻断跨模块采集的两项日期时钟问题已另行修复，见 [日期回归](DATE-CLOCK-REGRESSION.md)。

本报告只证明上述链路、状态与图像审阅。[控件清单](MOM-CONTROL-COVERAGE.md) 与 [全局完成审计](AUDIT.md) 仍保留剩余逐入口条件、系统状态和历史视觉审阅。
