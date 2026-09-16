# 宝宝记录历史与共享编辑器交付

宝宝记录历史及喂养、睡眠、尿便、生长、发育记录弹窗已按妈妈页设计体系完成 Figma 与 Flutter 实现。范围是最终清单中的 6 类页面状态和 8 类浮层状态；19 条原始证据、28 个设计画板及不同字号运行截图均不作为新增页面计数。整个 Goal 仍在进行。

## 设计与实现

[历史页设计](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=329-1086)、[喂养编辑器](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=329-1199)、[大字号编辑器](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=330-1804)先于相应 Flutter 实现完成。完整节点见 [figma-nodes.json](figma-nodes.json)，[设计读取](figma-design-context.json)、[最终实时核对](figma-live-verification.json)与[导出指纹](figma-artifacts.json)可追溯。

历史页将类型和月份组织为一张筛选卡，记录卡分离记录事实、发生时间和编辑／删除操作。编辑器统一奶油背景、白色表单卡、玫瑰色保存按钮、薄荷色选中状态与 Mom 字体。复用 MomSettingsCard、Mom ChoiceField、momSettingsTheme 和 MomHomeTokens。

表单正文可滚动，标题、关闭和保存操作保持可用。窄屏大字号下关闭按钮独立在标题上方，标题使用完整宽度，避免末字单独换行；历史标题使用 24 字号。长表单复核了首段、中部和末端。Figma 使用示例日期与值，App 保持原有记录事实、单位、日期和时区计算；原生日期／时间控件通过主题复用，未更换其选择协议。Figma 初次生成脚本保留在 figma-design.js；实时节点与最终导出为后续色点、字号、响应式标题调整后的权威设计。

## 最终清单与验证

| 页面状态 | 设计节点 | 实现证据 |
| --- | --- | --- |
| 空 | 330:1086 | records-current-empty，类型切换后空态 |
| 列表 | 329:1086、329:1141 | records-current-list，51 条记录首批 50 条 |
| 种类和日期切换 | 330:1117 | records-current-month，睡眠与上一月 |
| 加载 | 330:1148 | records-current-page-loading，挂起下一页响应 |
| 错误 | 330:1203 | records-current-page-error／page-recovered，失败保留前页，重试恢复 |
| 删除与撤销 | 330:1262 | baby_pages_test 的 history edits and restores，编辑、删除、撤销保持同一记录和宝宝 |

浮层的喂养、睡眠、尿布、生长、发育、编辑、校验、保存分别对应 Figma 的 feeding／nursing、sleep／sleep-active、wet／stool、growth、development、edit、validation、saving。baby_pages_test 覆盖五种记录、历史编辑删除恢复和窄屏键盘；baby_editor_states_test 覆盖亲喂可选时长、睡眠开始／结束、备注展开收起与未确认保存重试；baby_save_feedback_test 覆盖首页保存、校验、撤销和恢复。日期／时间测试在默认与 Mom 主题下断言选中绝对时间一致。

[最终联合回归](joint-tests.log)：20 个测试文件、185 项通过，执行时未更新截图基准。[静态分析](analyze.log)：4 个生产文件与 3 个测试文件无问题；补充的编辑器测试文件见 [分析](final-editor-analyze.log)。前置失败与基准更新过程分别保存在 red-tests.log、joint-tests-initial.log、implementation-update.log、typography-update.log；更新基准本身不作为最终验收。随后补充生长非法值与挂起保存的同一操作用例，[编辑器复核](final-editor-tests.log)覆盖本文件 26 项，其中 25 项与联合回归重合，总计 186 个不同用例。

[68 张运行视口](app-artifacts.json)包含 35 张受影响既有基准和 33 张针对分页、大字号及滚动位置的新基准。已检查最终长表单及大字号标题；其余字号沿用同批回归。运行证据来自真实 Flutter 组件与隔离仓库，不是线上设备或发布验收。删除确认、放弃及日期时间选择沿用已有 Mom 主题系统控件。

[保留项核对](preservation-check.json)：两个业务控制器逐字节未变，19 张原始来源图与盘点 manifest 未变。[实现差异](implementation.diff)相对本轮 before/，避免混入其他会话修改；旧基准备份在 before-goldens/。保存、校验、撤销、数据归属和时间逻辑继续由原控制器处理。

下一步复核最终清单中无效路由与无正常入口动作评估的已有截图，然后完成有限页面／浮层状态的全局交付对照，只补真实缺口。
