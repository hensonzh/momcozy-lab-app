# Baby 尿布类型、颜色、质地与历史编辑

从正式用户 App 的 More → Baby → 今日尿湿卡片进入，完成选项操作与保存，再通过“查看全部记录”→“尿便”→编辑→返回。393 px / 1x 与 320 px / 2x 均运行真实 GoRouter、Repository 和 codec；HTTP、会话、时钟与原生依赖使用隔离 fixture。操作通过 WidgetTester 实际点击或输入，不直接调用回调修改草稿。

## 已验证的操作与结果

- 尿湿卡片预选“尿湿”；再次点击该类型取消选择。点击保存出现“先选择这次换到的尿布”，写请求数保持不变。
- 选“便便”后出现可选颜色、质地与观察项。八种颜色逐项选择：黄色、黄褐色、绿色、棕色、黑色、红色、灰白/很浅、不确定；再次点击已选“不确定”清空颜色。
- 六种质地逐项选择：水样、稀软、糊状、成形、干硬、不确定；再次点击已选“不确定”清空质地。
- “看到血丝/血迹”和“看到黏液”依次形成单选血迹、两项同时选、仅黏液、全部取消四种状态。
- 选择红色、黑色、灰白或血迹时，当前实际界面只改变选中状态，没有新增提示弹窗或指导卡。本批记录产品现状，不将旧候选说明中的 guidance 当作已出现的界面。
- 展开备注，输入带换行和首尾空格的 35 字符文本后折叠。切成尿湿隐藏便便字段，未保存的颜色/质地/观察项仍保留；切回“尿湿和便便”可见原选择。
- 真正保存“尿湿和便便”后，返回记录含 yellow、loose、mucus，备注首尾空格移除为 31 字符，正文换行保留。首页尿湿和便便各计 1 次，实际只有一条记录。
- 从历史重开，所有保存值回显。改成尿湿并保存后版本变为 2，便便颜色/质地清空、观察项为空；重新打开再切便便不会恢复旧的已保存字段。
- 便便的颜色、质地和观察项均为空时仍可保存，版本为 3；重开再次确认空值持久化。未改动关闭不出现放弃确认，返回 Baby 后仅便便 1 次，尿湿为未记录，最后回 More。

所有 fixture 写入只发生在隔离测试中，没有向原账号新增健康记录。

## 完整截图与视觉检查

38 个逻辑状态、76 个视口变体，65 张完整长图，30 个状态以长图为主图。141 张原始 PNG 拆成 353 个连续全宽片段，其中 201 个唯一片段；182 个新片段组成 31 页，全部查看；19 个片段与此前已审阅图像逐像素一致。来源尺寸、SHA、纵向连续性和审阅页对应像素均校验通过，见 [分段来源](baby-diaper-control-visual-review/sources.json) 与 [证据审计](baby-diaper-control-evidence-audit.json)。

- 393 px 普通字号下颜色为四列、质地为两列；320 px / 2x 均纵向排列，表单明显增高。完整长图保留类型、时间、全部选项、备注、校验信息与唯一固定保存动作。
- 大字下新增标题换两行；首页统计卡呈居中窄列。历史中的组合事实和备注自动换行，当前尿便分类可见，其他分类可水平滚动。
- 空备注提示在 320 px / 2x 显示“备注（可…”省略；输入后的浮动标签完整。35→31 字符计数与首尾空格清理一致。
- 保存后的 Snackbar 出现在历史页底部；未将滚动视口中的裁切当作长图内容缺失。长图中保存按钮、导航没有重复拼入正文。

## Android 实际输入层

[原生链](../native/baby-diaper-input/README.md)补充 12 张窗口：从真实 Mia 会话进入 Luna 尿湿记录、展开备注、聚焦、浮动工具条菜单、浮动字母键盘、系统返回并恢复 Mia。两次 Gboard 操作使用已查看截图中的坐标；其他点击与 UI XML 对应。没有输入文字或点击保存。

当前模拟器中，一次 Back 同时关闭键盘与空编辑器，不能把它描述为单纯隐藏键盘。前后 Baby/Mia 的 UI 树除根 View focused 属性外一致。原生窗口是输入层证据，不替代上述完整长图。

## 状态与前驱

| 实际触发动作 | 截图、长图与前驱 |
| --- | --- |
| History diaper tab → combined diaper facts | [运行证据](../04-baby/baby-diaper-controls-both-history/README.md) |
| Edit combined diaper → all saved optional fields restored | [运行证据](../04-baby/baby-diaper-controls-both-reopened/README.md) |
| Choose wet and dirty → original stool selections restored | [运行证据](../04-baby/baby-diaper-controls-both-restores-stool/README.md) |
| Save combined diaper → one record with stool fields and trimmed note | [运行证据](../04-baby/baby-diaper-controls-both-saved/README.md) |
| Select stool color 黑色 | [运行证据](../04-baby/baby-diaper-controls-color-black/README.md) |
| Select stool color 棕色 | [运行证据](../04-baby/baby-diaper-controls-color-brown/README.md) |
| Tap selected unsure color → optional color cleared | [运行证据](../04-baby/baby-diaper-controls-color-cleared/README.md) |
| Select stool color 绿色 | [运行证据](../04-baby/baby-diaper-controls-color-green/README.md) |
| Select stool color 灰白 / 很浅 | [运行证据](../04-baby/baby-diaper-controls-color-pale/README.md) |
| Select stool color 红色 | [运行证据](../04-baby/baby-diaper-controls-color-red/README.md) |
| Select stool color 不确定 | [运行证据](../04-baby/baby-diaper-controls-color-unsure/README.md) |
| Select stool color 黄色 | [运行证据](../04-baby/baby-diaper-controls-color-yellow/README.md) |
| Select stool color 黄褐色 | [运行证据](../04-baby/baby-diaper-controls-color-yellowBrown/README.md) |
| Tap selected unsure consistency → optional consistency cleared | [运行证据](../04-baby/baby-diaper-controls-consistency-cleared/README.md) |
| Select stool consistency 成形 | [运行证据](../04-baby/baby-diaper-controls-consistency-formed/README.md) |
| Select stool consistency 干硬 | [运行证据](../04-baby/baby-diaper-controls-consistency-hard/README.md) |
| Select stool consistency 稀软 | [运行证据](../04-baby/baby-diaper-controls-consistency-loose/README.md) |
| Select stool consistency 糊状 | [运行证据](../04-baby/baby-diaper-controls-consistency-pasty/README.md) |
| Select stool consistency 不确定 | [运行证据](../04-baby/baby-diaper-controls-consistency-unsure/README.md) |
| Select stool consistency 水样 | [运行证据](../04-baby/baby-diaper-controls-consistency-watery/README.md) |
| Reopen wet then switch dirty → no stale saved stool selections | [运行证据](../04-baby/baby-diaper-controls-dirty-optional-empty/README.md) |
| Reopen dirty diaper → empty optional values persisted | [运行证据](../04-baby/baby-diaper-controls-dirty-optional-reopened/README.md) |
| Save dirty diaper with optional color/consistency/signs empty | [运行证据](../04-baby/baby-diaper-controls-dirty-optional-saved/README.md) |
| Choose dirty diaper → optional stool controls appear | [运行证据](../04-baby/baby-diaper-controls-dirty-selected/README.md) |
| Change saved combined diaper to wet → stool controls hidden | [运行证据](../04-baby/baby-diaper-controls-edit-wet/README.md) |
| Return Baby → dirty count updated, wet count removed | [运行证据](../04-baby/baby-diaper-controls-home-dirty-only/README.md) |
| More → Baby before diaper controls | [运行证据](../04-baby/baby-diaper-controls-home-entry/README.md) |
| Tap save → 先选择这次换到的尿布。; no write request | [运行证据](../04-baby/baby-diaper-controls-kind-required/README.md) |
| Baby → More after diaper controls | [运行证据](../04-baby/baby-diaper-controls-more-return/README.md) |
| Expand optional diaper note | [运行证据](../04-baby/baby-diaper-controls-note-expanded/README.md) |
| Enter multiline diaper note with surrounding whitespace | [运行证据](../04-baby/baby-diaper-controls-note-filled/README.md) |
| Select blood sign → one selected observation | [运行证据](../04-baby/baby-diaper-controls-sign-blood/README.md) |
| Select mucus as well → both observations selected | [运行证据](../04-baby/baby-diaper-controls-sign-both/README.md) |
| Deselect mucus → no observations selected | [运行证据](../04-baby/baby-diaper-controls-sign-cleared/README.md) |
| Deselect blood → mucus remains selected | [运行证据](../04-baby/baby-diaper-controls-sign-mucus/README.md) |
| Switch to wet → stool controls hidden; draft retained | [运行证据](../04-baby/baby-diaper-controls-wet-hides-stool/README.md) |
| Save wet type → stool fields omitted from returned record | [运行证据](../04-baby/baby-diaper-controls-wet-history-saved/README.md) |
| Tap wet status card → wet diaper selected | [运行证据](../04-baby/baby-diaper-controls-wet-open/README.md) |

## 验证与待补范围

- [严格采集](runs/20260913T220113-targeted/capture.log)：2 项通过，未更新 Golden 基线；同目录保留命令和退出结果。
- [全仓静态检查](baby-diaper-control-analyze.log)：No issues found，退出码 0。新增测试只读格式检查 0 changed。
- 本批没有修改业务代码。最初小屏测试用位置索引查找尚未创建的懒加载卡片失败；改为按 BabyStatusCard 的“尿湿”标签查找并实际滚动至控件，随后两个尺寸通过，未绕过入口调用编辑器。
- 尿便的时间/未来时间、2000 字与文本选择、权限/冲突、保存中关闭、系统大字键盘和 iOS 分支仍待补。已有通用记录新增/删除/撤销证据见 [Baby 路由链](BABY-JOURNEYS.md)；剩余范围见 [控件清单](BABY-CONTROL-COVERAGE.md)。

全 App UI/UX 盘点继续保持未完成；本批数量及校验通过不证明全体交互已覆盖。
