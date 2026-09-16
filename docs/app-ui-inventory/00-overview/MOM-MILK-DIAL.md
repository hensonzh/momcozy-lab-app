# 泌乳时钟表盘、模式切换与横向输入滚动

正式用户 App 的 More → Me → 记录一次泌乳 → 保存 → 编辑 → 关闭 → More。393 px 与 320 px 均为 1x 字号，使用现有 App / GoRouter / Controller / Repository；时钟、时区、HTTP 和会话为隔离 fixture。未创建真实账号健康记录。

## 实际操作

- 填写泵奶 120 ml，从 16:00 打开表盘。实际点击时钟画布的 9 点与 45 分位置，得到 21:45；点击顶部小时回到小时盘，再点 11 点与 20 分得到 23:20。切为上午，确认并保存 11:20。
- 编辑后重开，选时器回显已保存值。切换输入模式，输入 00 小时与 60 分钟，确认被拒绝，编辑草稿仍为 11:20。
- 320 px 输入框有 40px 横向滚动范围。实际向右拖至 0px，向左拖至 40px，两端分别截图；元数据保存水平位置与实际 drag 事件。
- 修正为 12:00 AM，点击时钟图标回表盘，断言午夜为 00:00；切到下午变为正午 12:00。点击顶部分钟切换分钟盘，确认后保存版本 2。
- 再编辑、打开表盘并点 3 点，选择器临时值为 15:00。点击取消后记录草稿仍为正午；关闭记录编辑器、确认离开，原保存版本 2 保留，返回首页再切 More。

表盘数字由 SDK canvas 绘制，测试按实际测得的表盘边界计算数字位置并派发点击；仅读取 SDK Widget 的 selectedTime 与模式做断言，没有直接调用选时回调。标题、模式切换、确认与取消均实际点击。

## 页面与状态链

| 操作 | 截图、长图与前驱 |
| --- | --- |
| Confirm dial → draft 11:20 | [运行证据](../03-mom/mom-milk-dial-accepted/README.md) |
| Select AM on dial → 11:20 | [运行证据](../03-mom/mom-milk-dial-am/README.md) |
| Reopen noon and select hour 3 → unsaved picker value 15:00 | [运行证据](../03-mom/mom-milk-dial-cancel-selection/README.md) |
| Cancel picker → draft stays noon | [运行证据](../03-mom/mom-milk-dial-cancelled/README.md) |
| Close record editor → discard confirmation | [运行证据](../03-mom/mom-milk-dial-close-confirm/README.md) |
| Record milk → enter pump 120 ml | [运行证据](../03-mom/mom-milk-dial-form-filled/README.md) |
| More → Me | [运行证据](../03-mom/mom-milk-dial-home-entry/README.md) |
| Discard editor → saved noon record retained, home | [运行证据](../03-mom/mom-milk-dial-home-return/README.md) |
| Tap hour 11 → minute dial with 45 retained | [运行证据](../03-mom/mom-milk-dial-hour-eleven/README.md) |
| Tap hour header → switch back to hour dial | [运行证据](../03-mom/mom-milk-dial-hour-header/README.md) |
| Tap dial hour 9 → minute dial, 21:00 | [运行证据](../03-mom/mom-milk-dial-hour-nine/README.md) |
| Clock → manual input mode | [运行证据](../03-mom/mom-milk-dial-input-mode/README.md) |
| Submit hour 00 and minute 60 → invalid picker input, draft unchanged | [运行证据](../03-mom/mom-milk-dial-invalid-input/README.md) |
| Drag picker right → horizontal left edge shows help and AM/PM | [运行证据](../03-mom/mom-milk-dial-invalid-input-left-edge/README.md) |
| Drag picker left → horizontal right edge shows minutes and confirmation | [运行证据](../03-mom/mom-milk-dial-invalid-input-right-edge/README.md) |
| Correct to 12:00 AM → return to clock showing midnight | [运行证据](../03-mom/mom-milk-dial-midnight-dial/README.md) |
| Tap minute 45 → 21:45 | [运行证据](../03-mom/mom-milk-dial-minute-forty-five/README.md) |
| Tap minute header → minute dial at noon | [运行证据](../03-mom/mom-milk-dial-minute-header/README.md) |
| Tap minute 20 → 23:20 | [运行证据](../03-mom/mom-milk-dial-minute-twenty/README.md) |
| Me → More | [运行证据](../03-mom/mom-milk-dial-more-return/README.md) |
| Confirm noon → draft 12:00 | [运行证据](../03-mom/mom-milk-dial-noon-accepted/README.md) |
| Select PM → noon 12:00 | [运行证据](../03-mom/mom-milk-dial-noon-dial/README.md) |
| Save noon → record version 2 | [运行证据](../03-mom/mom-milk-dial-noon-saved/README.md) |
| Open clock at 16:00 → hour dial | [运行证据](../03-mom/mom-milk-dial-open/README.md) |
| Edit saved record → picker retains 11:20 | [运行证据](../03-mom/mom-milk-dial-reopened/README.md) |
| Save pump 120 ml at 11:20 → list | [运行证据](../03-mom/mom-milk-dial-saved/README.md) |

## 视觉发现与范围

26 个逻辑状态、50 个视口变体、12 张纵向长图，6 个状态以长图为主图。62 张原图连续分为 124 段，共 80 个唯一像素片段；66 个新片段组成 11 张审阅图，全部已查看；14 个与此前已审阅图片逐像素一致。新增左右滑动后重新生成审阅图，未变的 1–6 页 SHA 已核对，变化的 7–11 页重新查看。见 [分段来源](mom-milk-dial-visual-review/sources.json) 与 [证据审计](mom-milk-dial-evidence-audit.json)。

- 320 px / 1x 下，表盘顶部分钟“00”会拆为上下两行，第二行被固定高度裁切；20、45 等较窄组合仍为一行。393 px 未观察到该裁切。画布上选中值、确认后的实际时间与保存值一致，不能把业务成功当作布局正确。
- 320 px 输入模式的左右两端各有内容被遮挡：左端可见完整“请输入有效的时间”和上午/下午，分钟及确认按钮右侧被裁；右端可见两个输入框与确认，但帮助文字、上午/下午和时钟图标左侧被裁。40px 横向拖动可切换两端，没有一次同时完整展示。两端截图如实保留，没有拉宽弹窗或伪造完整视口。
- 记录保存后顶部首页刷新为 120 ml，记录列表回显 11:20 / 12:00 与成功提示。原长页面包含底部记录行和固定导航。
- 本轮验证宿主 Flutter 组件的点击和拖动，没有执行 Android / iOS 键盘、系统手势或实体设备。大字号会使用另一种竖向输入界面，已由 [泌乳校验](MOM-MILK-VALIDATION.md) 覆盖部分链路，不将本轮普通字号表盘结果外推为大字号表盘。

## 验证与后续

- [最终严格采集](runs/20260913T203820-targeted/capture.log)：2 项通过，0 失败；[命令](runs/20260913T203820-targeted/capture-command.json)、[退出码](runs/20260913T203820-targeted/capture-result.json) 留存。新增状态先建立基线，最终采集未更新基线。
- [全仓静态检查](mom-milk-dial-analyze.log)：No issues found；新增测试格式检查 0 changed。
- 补入左右滑动状态导致后续观察序号改变，10 条旧观察已 [单独归档](runs/20260913T203820-targeted/superseded-observations/README.md)，当前 raw 只使用最终运行的 50 条观察。
- 新增 `test/modules/mom/mom_milk_dial_inventory_test.dart`；没有修改生产 UI 或通用采集器。

表盘点选、时/分标题切换、输入切回表盘、午夜/正午、确认/取消与窄屏水平滚动已有实际证据。原生设备状态、其他有意义数据条件和全体历史长图审阅仍待补。[全局完成审计](AUDIT.md) 继续保持未完成。
