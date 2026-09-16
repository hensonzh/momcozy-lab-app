# Baby 生长测量选项、数值与日期边界

从正式用户 App 的 More → Baby → 生长卡片进入；实际操作身长、头围、体重入口、校验、批量保存，再经“查看全部记录”→“生长”→编辑→返回。393 px / 1x 和 320 px / 2x 使用同一生产组件、GoRouter、Repository 与 codec；会话、HTTP、时钟和原生依赖隔离，未向真实账号写记录。

## 操作与实际结果

- 首页身长、头围卡片分别打开对应测量项目，未改动关闭不产生放弃确认；随后从体重卡片进入。
- 空数值保存出现“请至少填写一项测量数值。”；输入 oops、0、50.1 后分别点击保存，均出现单位/数值校验，没有写请求。
- 体重输入 50 后切身长，体重显示已填写勾号。身长输入 150.1 后切头围，点击保存会自动切回身长并显示错误；未隐藏错误或提交部分数据。
- 身长改为 150，头围 150.1 被拒绝，改为 150 后三项目均可提交。50 kg、150 cm 仅用于验证当前客户端上限，属于隔离边界 fixture，不是实际宝宝数据或正常范围结论。
- 测量日期打开后取消，今天与三项数值保留。再次打开，输入出生前一天 2026-08-21、未来一天 2026-09-14，均由选择器“超出范围。”拒绝；出生当天 2026-08-22 可进入草稿。最终改为 2026-09-12 实际提交。
- 点击保存后返回首页，三个测量一起保存为三条记录，同为 2026-09-12；首页卡片及体重趋势图反映边界值，显示批量保存及撤销提示。
- 生长历史显示三条记录；编辑体重时“测量项目”只包含体重，没有切成身长或头围的选项。
- 清空历史体重后保存，必填校验阻止写入、原版本仍为 1。输入首尾空格包裹的 4.25 后保存，同一记录更新为 version=2、value=4.25；其余两条记录保留。
- 重开确认 4.25 回显；未修改关闭不出现确认，返回 Baby 后首页及图表刷新，再回 More。

上述日期上下界是在实际 Picker 内被拒绝，不把未发生的 Controller 日期错误当作截图。本批没有点击批量撤销，既有撤销与失败重试链见 [Baby 路由链](BABY-JOURNEYS.md)。

## 完整图像与视觉检查

34 个逻辑状态、68 个视口变体，37 张完整长图，7 个状态使用长图作主图。105 张原始 PNG 切成 240 个连续全宽片段，144 个唯一片段；122 个新片段组成 21 页，全部审阅，另 22 个片段与此前已审阅画面逐像素相同。来源尺寸、SHA、全高连续性及审阅页对应像素校验通过，见 [来源](baby-growth-control-visual-review/sources.json) 与 [证据审计](baby-growth-control-evidence-audit.json)。

- 320 px / 2x 新增标题分两行，测量选项纵向排列；日期、说明、错误信息与唯一固定保存按钮在长图中完整。历史编辑仅单个项目，标题和按钮保持可见。
- 数值错误卡在大字下换多行，长图高度随错误状态增加；没有将原始滚动窗口中被固定页头遮住的字段误判为内容缺失。
- 日期输入器保留帮助标题、大字日期、输入框、范围错误和确认/取消；393 px 初始是日历，320 px / 2x 初始为输入模式。
- 边界体重 50 kg 保存后，图表纵轴扩展至约 51.9，参考带压缩到下方；改为 4.25 后纵轴恢复较小范围。该图表现为产品实际自动缩放。
- 历史大字下单位及数据来源文案自动换行，完整长图含三条记录、添加记录、数据来源和保存 Snackbar；导航与固定操作没有重复拼入正文。

## 状态与前驱

| 实际触发动作 | 截图、长图与前驱 |
| --- | --- |
| Confirm date before birth → picker range error | [运行证据](../04-baby/baby-growth-controls-date-before-birth/README.md) |
| Confirm birth date → earliest date accepted in draft | [运行证据](../04-baby/baby-growth-controls-date-birth/README.md) |
| Cancel date → today and three values retained | [运行证据](../04-baby/baby-growth-controls-date-cancelled/README.md) |
| Confirm tomorrow → picker range error | [运行证据](../04-baby/baby-growth-controls-date-future/README.md) |
| Open measurement date with birth-to-today range | [运行证据](../04-baby/baby-growth-controls-date-open/README.md) |
| Set yesterday for saved measurements | [运行证据](../04-baby/baby-growth-controls-date-previous-day/README.md) |
| Tap save → 请至少填写一项测量数值。; no write request | [运行证据](../04-baby/baby-growth-controls-empty-rejected/README.md) |
| Close unchanged 头围 editor → home without confirmation | [运行证据](../04-baby/baby-growth-controls-head-closed/README.md) |
| Switch to head circumference → hidden invalid length remains draft | [运行证据](../04-baby/baby-growth-controls-head-empty/README.md) |
| Tap 头围 home card → matching measurement selected | [运行证据](../04-baby/baby-growth-controls-head-entry/README.md) |
| Enter head circumference above maximum | [运行证据](../04-baby/baby-growth-controls-head-over/README.md) |
| Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request | [运行证据](../04-baby/baby-growth-controls-head-over-rejected/README.md) |
| Save from head tab → focus invalid length tab; no write | [运行证据](../04-baby/baby-growth-controls-hidden-length-rejected/README.md) |
| Open growth history → three saved measurements | [运行证据](../04-baby/baby-growth-controls-history/README.md) |
| Enter decimal weight with surrounding spaces | [运行证据](../04-baby/baby-growth-controls-history-decimal/README.md) |
| Edit saved weight → metric cannot change, original value restored | [运行证据](../04-baby/baby-growth-controls-history-editor/README.md) |
| Clear weight and save → required error; saved value unchanged | [运行证据](../04-baby/baby-growth-controls-history-empty-rejected/README.md) |
| Reopen weight → trimmed parsed value persisted | [运行证据](../04-baby/baby-growth-controls-history-reopened/README.md) |
| Save edit → 4.25 kg, same record, two other measurements retained | [运行证据](../04-baby/baby-growth-controls-history-saved/README.md) |
| More → Baby before growth controls | [运行证据](../04-baby/baby-growth-controls-home-entry/README.md) |
| Return Baby after history weight edit | [运行证据](../04-baby/baby-growth-controls-home-return/README.md) |
| Close unchanged 身长 editor → home without confirmation | [运行证据](../04-baby/baby-growth-controls-length-closed/README.md) |
| Switch to length → completed weight indicator retained | [运行证据](../04-baby/baby-growth-controls-length-empty/README.md) |
| Tap 身长 home card → matching measurement selected | [运行证据](../04-baby/baby-growth-controls-length-entry/README.md) |
| Save atomic batch → three boundary fixture measurements shown on home | [运行证据](../04-baby/baby-growth-controls-maxima-saved/README.md) |
| Baby → More after growth control chain | [运行证据](../04-baby/baby-growth-controls-more-return/README.md) |
| All three values at accepted client maxima; boundary fixture only | [运行证据](../04-baby/baby-growth-controls-three-maxima/README.md) |
| Tap weight home card → weight selected | [运行证据](../04-baby/baby-growth-controls-weight-entry/README.md) |
| Enter weight oops before save validation | [运行证据](../04-baby/baby-growth-controls-weight-malformed/README.md) |
| Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request | [运行证据](../04-baby/baby-growth-controls-weight-malformed-rejected/README.md) |
| Enter weight 50.1 before save validation | [运行证据](../04-baby/baby-growth-controls-weight-over/README.md) |
| Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request | [运行证据](../04-baby/baby-growth-controls-weight-over-rejected/README.md) |
| Enter weight 0 before save validation | [运行证据](../04-baby/baby-growth-controls-weight-zero/README.md) |
| Tap save → 请检查测量数值和单位。体重为 kg，身长与头围为 cm。; no write request | [运行证据](../04-baby/baby-growth-controls-weight-zero-rejected/README.md) |

## 验证与剩余范围

- [严格采集](runs/20260913T223019-targeted/capture.log)：2 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-growth-control-analyze.log)：No issues found，退出码 0；新增测试只读格式检查 0 changed。
- 初次测试用精确类型查找泛型 ChoiceField，未找到已显示的控件；改为 Widget 类型判定并断言唯一测量选项后通过。随后修正一处函数声明 lint 并重新严格采集，图像基线未变。
- 本批未修改业务代码，未执行原生键盘、实体设备或 iOS 输入。
- 剩余：非有限数/负数与极小正数、单项/两项提交、清除非当前项目草稿、身长/头围历史编辑、年月导航及缺失出生日期、不同保存错误/版本冲突、保存中关闭/未确认流程、系统输入层。
- 发育观察的每项选择仍单列待补；生长图各曲线切换与批量撤销已有早期链路，但全体历史图像及条件分支的最终审计未完成，见 [控件清单](BABY-CONTROL-COVERAGE.md)。

本批证据补齐了一条操作链，不代表全 App UI/UX 状态盘点已完成。
