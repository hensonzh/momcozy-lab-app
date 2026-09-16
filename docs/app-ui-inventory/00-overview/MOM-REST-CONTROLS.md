# 休息记录控件与状态补验

本轮补齐妈妈首页 → 昨夜休息的 7 组选项操作：393 px / 1x 实际点击全部 32 个选项；320 px / 2x 实际点击每组末项并走完清空、保存和重新打开。正式 App、GoRouter、Repository 与编解码器均在运行，仅 HTTP、会话、时钟及平台依赖隔离；未写入实际账号记录。本证据是 Flutter 宿主运行，不是新增原生设备测试。

## 实际点击链

More → 底部 Me → 昨夜休息 → 三组基础选择 → 展开补充休息情况 → 四组补充选择 → 逐个取消全部影响原因 → 恢复喂奶 → 再点已选睡眠时长清空 → 选择 3–4 小时 → 折叠补充项 → 保存 → 关闭 → 首页刷新 → 再开休息 → 展开已保存补充项 → 关闭 → More。

所有选择后均断言 ChoiceField 当前值；保存前隔离 transport 的 diaries 为空，保存后恰好一条。重新打开后再次断言已保存选择。每个观察点保留真实前驱、触发动作和当前路由，见各状态 README。

## 控件逐项证据

| 组 | 实际点击选项 | 结果截图与入口链 |
| --- | --- | --- |
| 昨夜大约睡了多久 | <3 小时 | [选中态](../03-mom/mom-rest-control-duration-underThreeHours/README.md) |
| 昨夜大约睡了多久 | 3–4 小时 | [选中态](../03-mom/mom-rest-control-duration-threeToFourHours/README.md) |
| 昨夜大约睡了多久 | 4–5 小时 | [选中态](../03-mom/mom-rest-control-duration-fourToFiveHours/README.md) |
| 昨夜大约睡了多久 | 5–6 小时 | [选中态](../03-mom/mom-rest-control-duration-fiveToSixHours/README.md) |
| 昨夜大约睡了多久 | ≥6 小时 | [选中态](../03-mom/mom-rest-control-duration-sixHoursPlus/README.md) |
| 昨夜大约睡了多久 | 记不清 | [选中态](../03-mom/mom-rest-control-duration-unknown/README.md) |
| 夜里大约被打断几次 | 没有 | [选中态](../03-mom/mom-rest-control-interruptions-none/README.md) |
| 夜里大约被打断几次 | 1–2 次 | [选中态](../03-mom/mom-rest-control-interruptions-oneToTwo/README.md) |
| 夜里大约被打断几次 | 3–4 次 | [选中态](../03-mom/mom-rest-control-interruptions-threeToFour/README.md) |
| 夜里大约被打断几次 | 5 次以上 | [选中态](../03-mom/mom-rest-control-interruptions-fivePlus/README.md) |
| 夜里大约被打断几次 | 记不清 | [选中态](../03-mom/mom-rest-control-interruptions-unknown/README.md) |
| 今天醒来时感觉怎样 | 有恢复 | [选中态](../03-mom/mom-rest-control-recovery-restored/README.md) |
| 今天醒来时感觉怎样 | 勉强能撑 | [选中态](../03-mom/mom-rest-control-recovery-managing/README.md) |
| 今天醒来时感觉怎样 | 很疲惫 | [选中态](../03-mom/mom-rest-control-recovery-exhausted/README.md) |
| 最长一段完整休息 | <1 小时 | [选中态](../03-mom/mom-rest-control-stretch-underOneHour/README.md) |
| 最长一段完整休息 | 1–2 小时 | [选中态](../03-mom/mom-rest-control-stretch-oneToTwoHours/README.md) |
| 最长一段完整休息 | 2–3 小时 | [选中态](../03-mom/mom-rest-control-stretch-twoToThreeHours/README.md) |
| 最长一段完整休息 | ≥3 小时 | [选中态](../03-mom/mom-rest-control-stretch-threeHoursPlus/README.md) |
| 最长一段完整休息 | 记不清 | [选中态](../03-mom/mom-rest-control-stretch-unknown/README.md) |
| 今天有没有一段不被打扰的休息 | 没有 | [选中态](../03-mom/mom-rest-control-day-rest-none/README.md) |
| 今天有没有一段不被打扰的休息 | <30 分钟 | [选中态](../03-mom/mom-rest-control-day-rest-underThirtyMinutes/README.md) |
| 今天有没有一段不被打扰的休息 | 30–60 分钟 | [选中态](../03-mom/mom-rest-control-day-rest-thirtyToSixtyMinutes/README.md) |
| 今天有没有一段不被打扰的休息 | ≥1 小时 | [选中态](../03-mom/mom-rest-control-day-rest-sixtyMinutesPlus/README.md) |
| 醒来后容易再睡着吗 | 容易 | [选中态](../03-mom/mom-rest-control-resleep-easy/README.md) |
| 醒来后容易再睡着吗 | 有点难 | [选中态](../03-mom/mom-rest-control-resleep-somewhatHard/README.md) |
| 醒来后容易再睡着吗 | 很难 | [选中态](../03-mom/mom-rest-control-resleep-hard/README.md) |
| 影响休息的原因 | 喂奶 | [选中态](../03-mom/mom-rest-control-disruption-feeding/README.md) |
| 影响休息的原因 | 宝宝醒了 | [选中态](../03-mom/mom-rest-control-disruption-baby/README.md) |
| 影响休息的原因 | 身体不适 | [选中态](../03-mom/mom-rest-control-disruption-discomfort/README.md) |
| 影响休息的原因 | 睡不回去 | [选中态](../03-mom/mom-rest-control-disruption-cannotSleep/README.md) |
| 影响休息的原因 | 环境影响 | [选中态](../03-mom/mom-rest-control-disruption-environment/README.md) |
| 影响休息的原因 | 其他 | [选中态](../03-mom/mom-rest-control-disruption-other/README.md) |

## 清空、展开及保存

| 操作 | 到达状态 |
| --- | --- |
| Home Rest card → empty quick rest editor | [截图与来源](../03-mom/mom-rest-control-empty/README.md) |
| Expand rest optional fields | [截图与来源](../03-mom/mom-rest-control-optional-open/README.md) |
| Deselect rest disruption 喂奶 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-feeding/README.md) |
| Deselect rest disruption 宝宝醒了 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-baby/README.md) |
| Deselect rest disruption 身体不适 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-discomfort/README.md) |
| Deselect rest disruption 睡不回去 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-cannotSleep/README.md) |
| Deselect rest disruption 环境影响 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-environment/README.md) |
| Deselect rest disruption 其他 | [截图与来源](../03-mom/mom-rest-control-disruption-clear-other/README.md) |
| Select feeding disruption after clearing all | [截图与来源](../03-mom/mom-rest-control-disruption-restored/README.md) |
| Tap selected sleep duration again → no duration selected | [截图与来源](../03-mom/mom-rest-control-duration-cleared/README.md) |
| Select 3–4 hours after clearing duration | [截图与来源](../03-mom/mom-rest-control-duration-restored/README.md) |
| Collapse filled optional rest fields → filled indicator retained | [截图与来源](../03-mom/mom-rest-control-optional-collapsed/README.md) |
| Save complete rest record through production repository → saved feedback | [截图与来源](../03-mom/mom-rest-control-saved/README.md) |
| Close saved rest editor → home shows 3–4 hours and one completed group | [截图与来源](../03-mom/mom-rest-control-home-refreshed/README.md) |
| Home Rest card → persisted rest record reopened | [截图与来源](../03-mom/mom-rest-control-reopened/README.md) |
| Expand persisted optional rest values | [截图与来源](../03-mom/mom-rest-control-reopened-optional/README.md) |
| Close unchanged rest record → home without discard prompt | [截图与来源](../03-mom/mom-rest-control-home-return/README.md) |
| Bottom More → original tab | [截图与来源](../03-mom/mom-rest-control-more-return/README.md) |

## 长图与视觉观察

- 51 个逻辑状态、72 个视口变体、53 张长图变体，共 125 张原始 PNG；其中 33 个状态的主图为长图。
- 125 张原图按全宽连续 650px 分段，321 段中仅完全相同像素合并审阅，得到 167 个唯一片段、28 张审阅图。全部已查看，分段连续覆盖每张原图顶部到底部；[原图与分段 SHA](mom-rest-control-visual-review/sources.json) 和 [核验结果](mom-rest-control-evidence-audit.json) 可追溯。
- 393 px 下所有选择均可读，选中描边/底色可区分。保存后出现绿色成功文案，再次打开保存按钮禁用，已保存补充选择保留。
- 320 px / 2x 下弹窗固定标题区域约占半屏，实际可滚动正文窗口较短；长图仍包含全部选项和底部保存按钮。原始窗口在滚动边界出现部分文字裁切属于真实滚动视口，未当成完整长图交付。
- 大字号首页的 AI 不可用标题、Cozymate 文案及底部英文导航出现多行换行。记录后的 AI 状态从等待变为不可用，符合当前未接入每日洞察 API 的实际行为；没有替换为虚构结果。
- 编辑时页头的“1/3 已记录”随草稿变化出现，不代表已经提交；测试独立验证保存前没有日记写入。以上是当前产品表现，盘点没有改动生产 UI。

## 验证命令与边界

```sh
python3 scripts/capture-app-ui-inventory.py --flutter /Users/lute/.local/share/momcozy-toolchains/flutter/bin/flutter --test test/modules/mom/mom_rest_control_inventory_test.dart
flutter analyze --no-pub
python3 scripts/verify-app-ui-inventory.py
```

- [严格采集日志](runs/20260913T191815-targeted/capture.log)：2 项通过，退出码 0；先生成新增基线，再以严格金图比较采集。未改动共用采集器。
- [静态检查](mom-rest-control-analyze.log)：全仓 No issues found。
- 首次窄屏测试因首页计数在滚动列表上方未挂载而失败，增加实际向上滚动后重跑通过；修正测试操作，没有修改产品代码。
- [妈妈控件覆盖清单](MOM-CONTROL-COVERAGE.md) 单列其余未核实选项。休息字段的 32 个选择已遍历，尚不证明三类记录所有条件与整个 App 都覆盖；其它单选组逐项取消、系统键盘和心情分支等仍按产品实际行为继续核验；身体选项后续证据见 [身体控件](MOM-BODY-CONTROLS.md)。


## 后续取消操作证据

其余五个单选组清空、恢复与保存重开已补验，见 [休息单选取消与恢复](MOM-REST-CLEAR-CONTROLS.md)。本页原始运行数量和证据保持不变。
