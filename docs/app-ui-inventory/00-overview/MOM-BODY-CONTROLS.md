# 身体记录逐控件补验

正式用户 App：More → Me → 身体与精力。393 px / 1x 逐项点击 7 组全部 24 个选项；320 px / 2x 每组选择末项，继续完成清空、关联项消失与恢复、备注输入、保存和重新打开。正式 GoRouter、Repository、编解码与界面均运行，HTTP 和会话使用隔离 fixture，不写入当前真实账号。

## 选择项与来源

| 组 | 实际点击选项 | 选中状态 / 完整长图 / 前驱 |
| --- | --- | --- |
| 今天身体的电量 | 有力气 | [运行证据](../03-mom/mom-body-control-energy-energized/README.md) |
| 今天身体的电量 | 勉强应付 | [运行证据](../03-mom/mom-body-control-energy-managing/README.md) |
| 今天身体的电量 | 身体被掏空 | [运行证据](../03-mom/mom-body-control-energy-depleted/README.md) |
| 今天哪里最需要照顾？ | 下腹 / 宫缩 | [运行证据](../03-mom/mom-body-control-site-lowerAbdomen/README.md) |
| 今天哪里最需要照顾？ | 会阴 / 伤口 | [运行证据](../03-mom/mom-body-control-site-perineum/README.md) |
| 今天哪里最需要照顾？ | 剖腹产切口 | [运行证据](../03-mom/mom-body-control-site-cesarean/README.md) |
| 今天哪里最需要照顾？ | 腰背 | [运行证据](../03-mom/mom-body-control-site-back/README.md) |
| 今天哪里最需要照顾？ | 头痛 / 胸闷 | [运行证据](../03-mom/mom-body-control-site-headChest/README.md) |
| 今天哪里最需要照顾？ | 其他 | [运行证据](../03-mom/mom-body-control-site-other/README.md) |
| 这种不适有多难受？ | 轻微 | [运行证据](../03-mom/mom-body-control-severity-mild/README.md) |
| 这种不适有多难受？ | 明显 | [运行证据](../03-mom/mom-body-control-severity-noticeable/README.md) |
| 这种不适有多难受？ | 很难忽略 | [运行证据](../03-mom/mom-body-control-severity-hardToIgnore/README.md) |
| 这种不适影响到你了吗？ | 没有影响 | [运行证据](../03-mom/mom-body-control-impact-none/README.md) |
| 这种不适影响到你了吗？ | 有一点影响 | [运行证据](../03-mom/mom-body-control-impact-some/README.md) |
| 这种不适影响到你了吗？ | 影响走路 / 抱宝宝 | [运行证据](../03-mom/mom-body-control-impact-careLimited/README.md) |
| 和昨天相比，身体感觉 | 好一些 | [运行证据](../03-mom/mom-body-control-trend-better/README.md) |
| 和昨天相比，身体感觉 | 差不多 | [运行证据](../03-mom/mom-body-control-trend-same/README.md) |
| 和昨天相比，身体感觉 | 更不舒服 | [运行证据](../03-mom/mom-body-control-trend-worse/README.md) |
| 排尿 | 正常 | [运行证据](../03-mom/mom-body-control-urination-normal/README.md) |
| 排尿 | 尿急 / 漏尿 | [运行证据](../03-mom/mom-body-control-urination-leakingUrgency/README.md) |
| 排尿 | 刺痛 / 困难 | [运行证据](../03-mom/mom-body-control-urination-painfulDifficult/README.md) |
| 排便 | 顺畅 | [运行证据](../03-mom/mom-body-control-bowel-smooth/README.md) |
| 排便 | 费力 | [运行证据](../03-mom/mom-body-control-bowel-difficult/README.md) |
| 排便 | 疼痛 / 痔疮 | [运行证据](../03-mom/mom-body-control-bowel-painfulPiles/README.md) |

## 清空、条件联动与提交链

所有六个单选组均再次点击当前选项清空后重新选择。不适部位六项在 393 px 下逐项选中，再逐项取消；取消最后一项时程度和影响两个字段消失，测试同时断言对应值为 null。重新选择部位后两字段出现，但此前数值不会恢复；实际再选择后保存。

| 操作 | 实际到达证据 |
| --- | --- |
| Tap selected bowel again → cleared | [状态截图](../03-mom/mom-body-control-bowel-cleared/README.md) |
| Select smooth bowel after clearing | [状态截图](../03-mom/mom-body-control-bowel-restored/README.md) |
| Fill returned severity and impact | [状态截图](../03-mom/mom-body-control-dependent-refilled/README.md) |
| Home Body card → empty quick body editor | [状态截图](../03-mom/mom-body-control-empty/README.md) |
| Tap selected energy again → cleared | [状态截图](../03-mom/mom-body-control-energy-cleared/README.md) |
| Choose energized after clearing | [状态截图](../03-mom/mom-body-control-energy-restored/README.md) |
| More → Me → initial home | [状态截图](../03-mom/mom-body-control-home-entry/README.md) |
| Close saved body editor → home displays updated body summary | [状态截图](../03-mom/mom-body-control-home-refreshed/README.md) |
| Close unchanged record without discard prompt → home | [状态截图](../03-mom/mom-body-control-home-return/README.md) |
| Scroll refreshed home to unrecorded lactation card after saving body data | [状态截图](../03-mom/mom-body-control-home-unrecorded-lactation-visible/README.md) |
| Tap selected discomfort impact again → cleared | [状态截图](../03-mom/mom-body-control-impact-cleared/README.md) |
| Restore discomfort impact | [状态截图](../03-mom/mom-body-control-impact-restored/README.md) |
| Bottom More → original tab | [状态截图](../03-mom/mom-body-control-more-return/README.md) |
| Clear body note → empty value and character count | [状态截图](../03-mom/mom-body-control-note-cleared/README.md) |
| Enter body note → visible value and character count | [状态截图](../03-mom/mom-body-control-note-entered/README.md) |
| Enter final body note and leave input | [状态截图](../03-mom/mom-body-control-note-restored/README.md) |
| Collapse filled toileting options | [状态截图](../03-mom/mom-body-control-optional-collapsed/README.md) |
| Expand toileting and pelvic floor options | [状态截图](../03-mom/mom-body-control-optional-open/README.md) |
| Reopen Body → assert all saved values | [状态截图](../03-mom/mom-body-control-reopened/README.md) |
| Expand persisted toileting values | [状态截图](../03-mom/mom-body-control-reopened-optional/README.md) |
| Save body through production repository → success feedback | [状态截图](../03-mom/mom-body-control-saved/README.md) |
| Tap selected severity again → cleared | [状态截图](../03-mom/mom-body-control-severity-cleared/README.md) |
| Restore discomfort severity | [状态截图](../03-mom/mom-body-control-severity-restored/README.md) |
| Deselect discomfort site 腰背 | [状态截图](../03-mom/mom-body-control-site-clear-back/README.md) |
| Deselect discomfort site 剖腹产切口 | [状态截图](../03-mom/mom-body-control-site-clear-cesarean/README.md) |
| Deselect discomfort site 头痛 / 胸闷 | [状态截图](../03-mom/mom-body-control-site-clear-headChest/README.md) |
| Deselect discomfort site 下腹 / 宫缩 | [状态截图](../03-mom/mom-body-control-site-clear-lowerAbdomen/README.md) |
| Deselect discomfort site 其他 | [状态截图](../03-mom/mom-body-control-site-clear-other/README.md) |
| Deselect discomfort site 会阴 / 伤口 | [状态截图](../03-mom/mom-body-control-site-clear-perineum/README.md) |
| Reselect first discomfort site → dependent severity and impact return empty | [状态截图](../03-mom/mom-body-control-site-restored-dependent-empty/README.md) |
| Tap selected body trend again → cleared | [状态截图](../03-mom/mom-body-control-trend-cleared/README.md) |
| Select better trend after clearing | [状态截图](../03-mom/mom-body-control-trend-restored/README.md) |
| Tap selected urination again → cleared | [状态截图](../03-mom/mom-body-control-urination-cleared/README.md) |
| Select normal urination after clearing | [状态截图](../03-mom/mom-body-control-urination-restored/README.md) |

备注实际输入 → 清空 → 重新输入 → 失焦，保存前断言 diaries 为空，保存后恰好一条。重新进入身体页后断言电量、不适部位、程度、影响、趋势、排尿、排便与备注全部保持最终提交值。关闭未修改的记录直接返回首页，再通过底部导航回到 More。

## 视觉审阅

- 58 个逻辑状态，94 个视口变体与 92 张完整长图变体，共 186 原图；57 个状态主图为长图。每张原图从 y=0 到底部分成 650px 连续全宽片段，共 462 段；完全一致像素共用审阅引用，207 个唯一片段已全部查看。35 张初始审阅图与 1 张追加图见 [逐图 SHA 和分段](mom-body-control-visual-review/sources.json)。
- 393 px 下选中、取消、条件字段显示/隐藏、备注计数与保存成功提示均明确可见。已保存后再次打开，保存按钮禁用。
- 320 px / 2x 下固定标题区域较高、正文滚动窗口短，长图仍包含全部字段和底部按钮；身体标题换行，备注标签会显示省略号。如厕与盆底在填入数据后仍显示“可选”，这是当前界面行为。
- 首页在仅填写身体、尚无泌乳时，泌乳“暂未记录”字号比全空态大，因为当前组件按 hasTodayRecords 决定字号。针对疑似字形接缝额外实际滚到泌乳卡拍原始窗口，确认原始视口与长图一致，见 [直接渲染](../03-mom/mom-body-control-home-unrecorded-lactation-visible/README.md)。没有修改产品或修饰截图。
- 大字号导航和专家入口继续存在多行换行；此次保留当前实际表现。输入截图来自 Flutter 宿主，没有把测试文字输入当成 Android 系统键盘证据。

## 测试与范围

```sh
python3 scripts/capture-app-ui-inventory.py --flutter /Users/lute/.local/share/momcozy-toolchains/flutter/bin/flutter --test test/modules/mom/mom_body_control_inventory_test.dart
flutter analyze --no-pub
python3 scripts/index-app-ui-inventory.py
python3 scripts/verify-app-ui-inventory.py
```

- [最终严格采集日志](runs/20260913T193137-targeted/capture.log)：2 项通过，0 失败，10 秒；[命令](runs/20260913T193137-targeted/capture-command.json) 与 [退出码](runs/20260913T193137-targeted/capture-result.json) 留存。新增基线生成后严格比较采集，没有跳过金图对比。
- [全仓静态检查](mom-body-control-analyze.log)：No issues found。
- [逐项证据核验](mom-body-control-evidence-audit.json) 包含源哈希、24 个选项、94 个有序路由观察点与图片分段验证。
- 生产 UI 与共用采集器均未修改。本轮新增 `test/modules/mom/mom_body_control_inventory_test.dart`、金图、原始截图及本报告。
- 身体备注 2000 字边界及原生输入层未在本轮补验；心情压力、影响、支持等仍待逐项点击。当前全 App 完整盘点未完成，见 [控件清单](MOM-CONTROL-COVERAGE.md) 和 [完成审计](AUDIT.md)。
