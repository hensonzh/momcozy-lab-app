# 休息单选取消与恢复补验

在正式用户 App 中从 More 点击 Me，再打开“昨夜休息”，补齐五个单选组的选中 → 再次点击清空 → 重新选择 → 保存 → 重开链。393 px / 1x 与 320 px / 2x 均实际点击这些步骤。GoRouter、记录 Repository 与编解码使用正式实现，HTTP 和会话隔离，不更改真实账号记录。

| 控件 | 初次选中 | 再次点击 | 恢复并保存 |
| --- | --- | --- | --- |
| 夜里被打断次数 | 记不清 | 空 | 没有 |
| 醒来感觉 | 很疲惫 | 空 | 有恢复 |
| 最长完整休息 | 记不清 | 空 | <1 小时 |
| 不被打扰的休息 | ≥1 小时 | 空 | 没有 |
| 再入睡难度 | 很难 | 空 | 容易 |

每次取消均断言正式 ChoiceField 的 selected 为空。保存之前 fixture 中无记录，保存后恰好一条；重新打开后核对全部五个恢复值。睡眠总时长和影响原因从未填写，重开时仍为空，首页休息卡显示“有恢复”，没有补造时长。

## 状态索引

| 实际操作 | 截图、完整长图与前驱 |
| --- | --- |
| Tap selected 今天有没有一段不被打扰的休息 again → no selection | [运行证据](../03-mom/mom-rest-clear-day-rest-cleared/README.md) |
| Restore 今天有没有一段不被打扰的休息 with 没有 | [运行证据](../03-mom/mom-rest-clear-day-rest-restored/README.md) |
| Rest / 今天有没有一段不被打扰的休息 → select ≥1 小时 | [运行证据](../03-mom/mom-rest-clear-day-rest-selected/README.md) |
| Home Rest card → empty editor | [运行证据](../03-mom/mom-rest-clear-empty/README.md) |
| More → Me → unrecorded home | [运行证据](../03-mom/mom-rest-clear-home-entry/README.md) |
| Close saved record → home reflects rest without duration | [运行证据](../03-mom/mom-rest-clear-home-refreshed/README.md) |
| Close unchanged record → home without discard prompt | [运行证据](../03-mom/mom-rest-clear-home-return/README.md) |
| Tap selected 夜里大约被打断几次 again → no selection | [运行证据](../03-mom/mom-rest-clear-interruptions-cleared/README.md) |
| Restore 夜里大约被打断几次 with 没有 | [运行证据](../03-mom/mom-rest-clear-interruptions-restored/README.md) |
| Rest / 夜里大约被打断几次 → select 记不清 | [运行证据](../03-mom/mom-rest-clear-interruptions-selected/README.md) |
| Bottom More → original tab | [运行证据](../03-mom/mom-rest-clear-more-return/README.md) |
| Expand optional rest fields | [运行证据](../03-mom/mom-rest-clear-optional-open/README.md) |
| Tap selected 今天醒来时感觉怎样 again → no selection | [运行证据](../03-mom/mom-rest-clear-recovery-cleared/README.md) |
| Restore 今天醒来时感觉怎样 with 有恢复 | [运行证据](../03-mom/mom-rest-clear-recovery-restored/README.md) |
| Rest / 今天醒来时感觉怎样 → select 很疲惫 | [运行证据](../03-mom/mom-rest-clear-recovery-selected/README.md) |
| Reopen saved rest → interruptions and recovery restored; duration unset | [运行证据](../03-mom/mom-rest-clear-reopened/README.md) |
| Expand saved optional fields → three restored values preserved; disruptions unset | [运行证据](../03-mom/mom-rest-clear-reopened-optional/README.md) |
| Tap selected 醒来后容易再睡着吗 again → no selection | [运行证据](../03-mom/mom-rest-clear-resleep-cleared/README.md) |
| Restore 醒来后容易再睡着吗 with 容易 | [运行证据](../03-mom/mom-rest-clear-resleep-restored/README.md) |
| Rest / 醒来后容易再睡着吗 → select 很难 | [运行证据](../03-mom/mom-rest-clear-resleep-selected/README.md) |
| Save restored five rest fields → success | [运行证据](../03-mom/mom-rest-clear-saved/README.md) |
| Tap selected 最长一段完整休息 again → no selection | [运行证据](../03-mom/mom-rest-clear-stretch-cleared/README.md) |
| Restore 最长一段完整休息 with <1 小时 | [运行证据](../03-mom/mom-rest-clear-stretch-restored/README.md) |
| Rest / 最长一段完整休息 → select 记不清 | [运行证据](../03-mom/mom-rest-clear-stretch-selected/README.md) |

## 视觉与证据核对

24 个逻辑状态、48 个视口变体、38 张长图变体，共 86 原图；15 个状态的主图为长图。全部原图连续全宽分成 234 段，其中 116 种唯一像素片段：60 个新片段组成 10 张审阅图，均已查看；56 个片段与已审阅的休息、身体或心情片段相同。审计逐一验证原图 SHA、从 y=0 到底部的连续覆盖、审阅图对应区域像素一致，见 [分段来源](mom-rest-clear-visual-review/sources.json) 和 [证据审计](mom-rest-clear-evidence-audit.json)。

393 px 下四列日间休息选项中“30–60 分钟”换行；320 px / 2x 选项改为单列，固定页头较高，正文滚动窗口较短。所有字段及保存按钮均在完整长图内。未修改生产 UI，保留当前表现。成功提示呈绿色，重开后未修改的保存按钮禁用。没有将宿主测试当作实体真机或原生键盘验证。

## 验证

- [严格截图采集](runs/20260913T194940-targeted/capture.log)：2 项通过，0 失败，5 秒；[命令](runs/20260913T194940-targeted/capture-command.json) 与 [退出码](runs/20260913T194940-targeted/capture-result.json) 留存，未放宽金图匹配。
- [全仓静态检查](mom-rest-clear-analyze.log)：No issues found。首次检查发现新增测试有一个未使用 import，已删除后通过。
- 新测试 `test/modules/mom/mom_rest_clear_inventory_test.dart`、截图和报告已归档；生产组件及共用采集器未修改。
- 结合 [原休息逐项选择](MOM-REST-CONTROLS.md)，六个单选组均已有清空及恢复证据，多选原因也有逐个取消证据。所有选项的任意组合不是此次穷举对象；通用记录条件、泌乳控件、原生层及全部历史视觉审阅仍按 [控件清单](MOM-CONTROL-COVERAGE.md) 和 [完成审计](AUDIT.md) 推进。
