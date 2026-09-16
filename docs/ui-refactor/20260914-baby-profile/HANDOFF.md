# 宝宝资料编辑器

宝宝新增与编辑资料弹窗已按妈妈页设计体系完成 Figma 和 Flutter 重构。将称呼与出生日期、出生记录性别与喂养方式分为两张卡片，固定标题、关闭和保存区域，正文独立滚动。复用 MomHomeTokens、MomSettingsCard、momSettingsTheme 与 ChoiceField 的 Mom 样式，没有增加独立的页面配色或新基础组件。

范围仅为共享 BabyProfileEditor。宝宝首页、切换器及记录页面不会因为承载此弹窗而被标记完成。累计完成范围更新为 34 个，Goal 继续 active。

## 设计与截图依据

阅读 [79 个既有截图状态](source-inventory.json)，分布于 7 张 source-review 联系表；均没有待补充长截图标记。先在 Figma 完成 [26 个画板](figma-nodes.json)，读取设计上下文后再实现 Flutter。代表设计：[已有资料](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=317-1120)、[新增资料](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=317-1086)、[大字号](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=317-1540)、[保存中](https://www.figma.com/design/ePIoJkiMiXiug9ibpcgRbl?node-id=317-1814)。

覆盖默认、清除日期、选择菜单、长称呼、校验、冲突、无权限、不可用、保存中和结果未确认状态；包含普通、大字号及键盘压缩后的可用高度。确认弹窗复用日记设计，日期控件复用已确认的原生日期样式。[覆盖映射](coverage.json) 逐条记录状态族复用，不声称重新执行全部 79 条来源旅程。归档时实际查询 [31 个 Figma 节点](figma-live-nodes.json)，26 个本轮画板及 5 个复用节点均存在。

最终 26 张 Figma 导出图和 105 张 App 验证图已经视觉检查。[图像指纹](verified-images.json) 对应 verified/ 中的最终图。保存、重新载入中的最后 12 张图见 [settled-review.jpg](settled-review.jpg)：截图等待按钮颜色动画完成，并断言禁用文字使用次级文字色。这批图替代早期 app-review 联系表中的动画起始截图。原始 Figma 生成脚本未包含后续视觉修正，最终画板及 [导出清单](figma-images.json) 为设计交付依据。

## 行为与验证

生产改动仅在 baby_profile_editor.dart。控制器与重构前副本逐字节相同；入口、关闭、日期选择、保存、重新载入和 dispose 方法仅增加可选局部主题或格式变化，见 [行为对照](behavior-preservation.json) 与 [实现差异](implementation.diff)。

- 保留原称呼 120 字符输入限制及控制器的 Unicode 校验，不修改业务规则。
- 出生日期仍限于 1900 年至当前日期，允许清除；日期输入拒绝早于下限和未来日期。
- 冲突后保留草稿，重新载入更新字段与版本；无权限错误仍保留输入。
- 保存结果未确认时保留原请求、版本与幂等键；重试不产生新的意图。
- 忙碌时禁止重复保存和编辑；关闭确认、继续填写及返回结果保留原流程。

[164 项联测全部通过](joint-final-tests.log)，命令列出 17 个明确测试文件，见 [joint-command.json](joint-command.json)。最后调整截图等待和文字颜色断言后，受影响测试文件 [12 项再次通过](settled-final-tests.log)，与 164 项重叠，不重复累加。[静态分析](analyze-final.log) 两个文件无问题。最终比较未启用更新基线。

验证包含 320、390、430 宽度、1 倍和 2 倍字号、短屏、长称呼，以及 320 宽度下键盘占据 300 高度后的保存可达性。共新增 96 张状态回归图，按新版设计更新 9 张既有资料弹窗基线；旧基线保存在 baseline-before/。没有运行清单采集测试，测试进程移除了 MOMCOZY_UI_INVENTORY_DIR。

## 验证边界与下一步

Figma 展示独立弹窗与奶油底色，组件测试背景使用最小宿主页；真实宿主页由现有入口测试覆盖，不能据此声称宝宝首页已完成重构。菜单、日期文本格式与原生控件由 Flutter 和 locale 决定；长输入仍支持原生横向编辑，标题保持原有最多三行、键盘打开时单行省略规则。此轮没有真机验收、构建或发布。

源目录保持只读，444 个来源文件指纹归档核验一致。当前截图清单仍为 2818 个状态，[增量检查](inventory-delta.json) 没有新增、替换或移除。下一步处理已有截图中的宝宝首页，再推进宝宝记录和其余未重构范围。
