# 心情记录逐控件补验

正式用户 App：More → Me → 今日心情。393 px / 1x 逐项点击 4 组全部 19 个选项，以及首页 3 个快捷心情；320 px / 2x 每组选择末项，继续执行排他转换、清空、恢复、保存、重开和空记录校验。正式 GoRouter、Repository、编解码与界面均运行，HTTP 和会话使用隔离 fixture，不写入当前真实账号。

## 选项与运行证据

| 组 | 实际点击选项 | 选中状态、长图与前驱 |
| --- | --- | --- |
| 心情 | 还算平稳 | [运行证据](../03-mom/mom-mood-control-tone-steady/README.md) |
| 心情 | 有点绷着 | [运行证据](../03-mom/mom-mood-control-tone-tense/README.md) |
| 心情 | 低落 / 没力气 | [运行证据](../03-mom/mom-mood-control-tone-low/README.md) |
| 心情 | 很容易被触发 | [运行证据](../03-mom/mom-mood-control-tone-reactive/README.md) |
| 心情 | 说不清楚 | [运行证据](../03-mom/mom-mood-control-tone-unclear/README.md) |
| 压力来源 | 担心宝宝 | [运行证据](../03-mom/mom-mood-control-pressure-babyWorry/README.md) |
| 压力来源 | 喂养压力 | [运行证据](../03-mom/mom-mood-control-pressure-feedingPressure/README.md) |
| 压力来源 | 身体恢复 | [运行证据](../03-mom/mom-mood-control-pressure-bodyRecovery/README.md) |
| 压力来源 | 睡不好 | [运行证据](../03-mom/mom-mood-control-pressure-sleepLoss/README.md) |
| 压力来源 | 和家人相处 | [运行证据](../03-mom/mom-mood-control-pressure-familyFriction/README.md) |
| 压力来源 | 对自己没信心 | [运行证据](../03-mom/mom-mood-control-pressure-selfDoubt/README.md) |
| 压力来源 | 没有自己的时间 | [运行证据](../03-mom/mom-mood-control-pressure-noTime/README.md) |
| 压力来源 | 说不清楚 | [运行证据](../03-mom/mom-mood-control-pressure-unclear/README.md) |
| 心情影响 | 没有影响 | [运行证据](../03-mom/mom-mood-control-impact-none/README.md) |
| 心情影响 | 有一点影响 | [运行证据](../03-mom/mom-mood-control-impact-some/README.md) |
| 心情影响 | 很难完成日常事情 | [运行证据](../03-mom/mom-mood-control-impact-hard/README.md) |
| 支持情况 | 有人帮到我 | [运行证据](../03-mom/mom-mood-control-support-supported/README.md) |
| 支持情况 | 有人，但主要还是我在扛 | [运行证据](../03-mom/mom-mood-control-support-carryingMost/README.md) |
| 支持情况 | 基本靠自己 | [运行证据](../03-mom/mom-mood-control-support-alone/README.md) |

## 提交与返回链

首页“不太好 / 一般 / 不错”分别预填 low / unclear / steady 草稿；关闭后出现确认弹窗，放弃修改返回未记录首页，Repository 仍无记录。点击“今日心情”标题则打开无预填的编辑器。

普通压力 7 项可多选，选择“说不清楚”会替换所有普通项；再次点击它清空，再恢复后点击“担心宝宝”会移除排他项。普通项随后逐个重新加入、逐个取消，最后集合为空，再选择一项用于保存。心情、影响、支持三个单选组均实际再次点击清空，然后恢复选项。

保存成功显示绿色提示，首页刷新；通过标题重新打开时，四组值均与提交值一致。随后逐组清空已保存内容，最后提交空草稿显示“先记录一项今天的状态，再保存。”，保存版本保持 1。关闭并放弃草稿后首页仍有原心情记录。这是空提交校验，不是删除成功。

| 其余操作 | 实际到达状态 |
| --- | --- |
| Home Mood title → empty editor without preset | [截图与前驱](../03-mom/mom-mood-control-empty/README.md) |
| Close cleared existing diary → discard confirmation | [截图与前驱](../03-mom/mom-mood-control-empty-replacement-discard-confirm/README.md) |
| Attempt to save emptied existing diary → validation; saved version unchanged | [截图与前驱](../03-mom/mom-mood-control-empty-replacement-validation/README.md) |
| More → Me → initial home | [截图与前驱](../03-mom/mom-mood-control-home-entry/README.md) |
| Close saved mood → refreshed home with steady mood | [截图与前驱](../03-mom/mom-mood-control-home-refreshed/README.md) |
| Discard empty draft → home retains saved mood | [截图与前驱](../03-mom/mom-mood-control-home-retained/README.md) |
| Tap selected mood impact → cleared | [截图与前驱](../03-mom/mom-mood-control-impact-cleared/README.md) |
| Restore no impact | [截图与前驱](../03-mom/mom-mood-control-impact-restored/README.md) |
| Bottom More → original tab | [截图与前驱](../03-mom/mom-mood-control-more-return/README.md) |
| Deselect ordinary pressure 担心宝宝 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-babyWorry/README.md) |
| Deselect ordinary pressure 身体恢复 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-bodyRecovery/README.md) |
| Deselect ordinary pressure 和家人相处 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-familyFriction/README.md) |
| Deselect ordinary pressure 喂养压力 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-feedingPressure/README.md) |
| Deselect ordinary pressure 没有自己的时间 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-noTime/README.md) |
| Deselect ordinary pressure 对自己没信心 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-selfDoubt/README.md) |
| Deselect ordinary pressure 睡不好 | [截图与前驱](../03-mom/mom-mood-control-pressure-clear-sleepLoss/README.md) |
| Tap selected unclear pressure → empty pressure set | [截图与前驱](../03-mom/mom-mood-control-pressure-exclusive-cleared/README.md) |
| Restore exclusive unclear pressure | [截图与前驱](../03-mom/mom-mood-control-pressure-exclusive-restored/README.md) |
| Select baby worry while unclear is selected → unclear removed | [截图与前驱](../03-mom/mom-mood-control-pressure-exclusive-to-ordinary/README.md) |
| Add ordinary pressure 身体恢复 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-bodyRecovery/README.md) |
| Add ordinary pressure 和家人相处 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-familyFriction/README.md) |
| Add ordinary pressure 喂养压力 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-feedingPressure/README.md) |
| Add ordinary pressure 没有自己的时间 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-noTime/README.md) |
| Add ordinary pressure 对自己没信心 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-selfDoubt/README.md) |
| Add ordinary pressure 睡不好 after exclusive transition | [截图与前驱](../03-mom/mom-mood-control-pressure-refill-sleepLoss/README.md) |
| Choose baby worry after clearing all pressures | [截图与前驱](../03-mom/mom-mood-control-pressure-restored/README.md) |
| Home quick mood 不太好 → prefilled draft without save | [截图与前驱](../03-mom/mom-mood-control-quick-low/README.md) |
| Close quick 不太好 draft → discard confirmation | [截图与前驱](../03-mom/mom-mood-control-quick-low-discard-confirm/README.md) |
| Discard quick 不太好 draft → home remains unrecorded | [截图与前驱](../03-mom/mom-mood-control-quick-low-discarded/README.md) |
| Home quick mood 不错 → prefilled draft without save | [截图与前驱](../03-mom/mom-mood-control-quick-steady/README.md) |
| Close quick 不错 draft → discard confirmation | [截图与前驱](../03-mom/mom-mood-control-quick-steady-discard-confirm/README.md) |
| Discard quick 不错 draft → home remains unrecorded | [截图与前驱](../03-mom/mom-mood-control-quick-steady-discarded/README.md) |
| Home quick mood 一般 → prefilled draft without save | [截图与前驱](../03-mom/mom-mood-control-quick-unclear/README.md) |
| Close quick 一般 draft → discard confirmation | [截图与前驱](../03-mom/mom-mood-control-quick-unclear-discard-confirm/README.md) |
| Discard quick 一般 draft → home remains unrecorded | [截图与前驱](../03-mom/mom-mood-control-quick-unclear-discarded/README.md) |
| Reopen mood by title → all four saved groups preserved | [截图与前驱](../03-mom/mom-mood-control-reopened/README.md) |
| Save mood record through production repository → success feedback | [截图与前驱](../03-mom/mom-mood-control-saved/README.md) |
| Clear last saved field → empty draft, persisted record remains | [截图与前驱](../03-mom/mom-mood-control-saved-all-cleared/README.md) |
| Clear saved impact in draft | [截图与前驱](../03-mom/mom-mood-control-saved-impact-cleared/README.md) |
| Clear saved pressure in draft | [截图与前驱](../03-mom/mom-mood-control-saved-pressure-cleared/README.md) |
| Clear saved mood tone in draft | [截图与前驱](../03-mom/mom-mood-control-saved-tone-cleared/README.md) |
| Tap selected support → cleared | [截图与前驱](../03-mom/mom-mood-control-support-cleared/README.md) |
| Restore supported | [截图与前驱](../03-mom/mom-mood-control-support-restored/README.md) |
| Tap selected mood tone again → no tone selected | [截图与前驱](../03-mom/mom-mood-control-tone-cleared/README.md) |
| Choose steady mood after clearing | [截图与前驱](../03-mom/mom-mood-control-tone-restored/README.md) |

## 视觉审阅

- 64 个逻辑状态、95 个视口变体、87 张长图变体，共 182 原图；59 个状态主图为长图。所有原图按 650 px 连续全宽分段，共 418 段、168 种唯一像素片段。
- 150 个新片段组成 25 张审阅图，均已查看；另外 18 个片段与此前已审阅的身体/休息截图逐像素相同，复用原审阅引用。[分段与来源 SHA](mom-mood-control-visual-review/sources.json) 保留每张原图从顶部到底部的定位。证据检查同时核验原图分段与实际审阅图对应区域像素一致。
- 393 px 下选项高亮、取消、保存和校验提示可辨识；“很难完成日常事情”在三列控件中换行。已保存且未修改时保存按钮禁用。
- 320 px / 2x 下固定页头占用较多空间，正文窗口较短，完整长图仍覆盖所有字段及底部按钮；确认弹窗标题换行、操作纵向排列，两项操作可见。首页导航文字存在多行换行，这是当前实际表现。
- 没有修改产品 UI 或修饰截图；此处是 Flutter 宿主测试，未将其描述为 Android 原生键盘或系统权限证据。

## 验证与未完成范围

- [严格采集](runs/20260913T194038-targeted/capture.log)：2 项通过，0 失败，8 秒。保留 [命令](runs/20260913T194038-targeted/capture-command.json) 和 [退出码](runs/20260913T194038-targeted/capture-result.json)，未跳过金图比较。
- [全仓静态检查](mom-mood-control-analyze.log)：No issues found。
- [证据审计](mom-mood-control-evidence-audit.json)：19 个选项、95 个路由观察点、PNG 哈希、连续分段与审阅图像素匹配。
- 新增测试：`test/modules/mom/mom_mood_control_inventory_test.dart`；共用采集器及生产代码未修改。
- 休息其余单选组逐个清空已在 [后续补验](MOM-REST-CLEAR-CONTROLS.md) 完成；身体备注长度边界、泌乳逐控件分支、原生权限条件及全部历史长图审阅仍待完成，见 [控件清单](MOM-CONTROL-COVERAGE.md) 与 [完成审计](AUDIT.md)。本报告不宣称全 App 盘点完成。
