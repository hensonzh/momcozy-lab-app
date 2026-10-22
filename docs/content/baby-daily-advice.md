# 出生后 0–364 天 Banner 通用文案（草案）

- 数据文件：`../../assets/content/baby_daily_advice_0_364.json`，365 个显式条目，每条有 `day`、`topic`、`text`。出生当天为日龄 0；日龄 365 起不在本文件范围。
- 文案为内容草案，**没有完成儿科/临床及中文编辑审核，不应标作已审核内容**。按喂养、尿布、安全睡眠、发育、互动和安全等主题逐日安排；并非每天都预测一个医学上独立的发育事件。独特条目不等于逐日证据结论。
- 参考基础：CDC 发育里程碑（https://www.cdc.gov/act-early/milestones/index.html）、CDC 安全睡眠（https://www.cdc.gov/sudden-infant-death/sleep-safely/index.html）、CDC 辅食引入（https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/when-what-and-how-to-introduce-solid-foods.html）、AAP 新生儿喂养（https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/how-often-and-how-much-should-your-baby-eat.aspx）。这些是主题来源，不表示各日条目逐条获得临床背书。
- 个性化仅在当前选中宝宝最近两天的记录完整读回、与当天主题相符时，将“已记录 X 次喂养/换尿布/睡眠”等**明确的记录事实**接到当天基础建议的动作句；不推断健康、奶量充足、睡眠质量或“未记录即未发生”。记录缺失、部分分页、解析错误和读取失败均原样显示当天通用文案。妈妈单独记录不当作宝宝记录。
- Banner 按**当前选中宝宝的出生日期**和账号时区计算日龄；前台停留时在账号当地日界（每天 0 点）刷新当天条目，后台跨日后恢复前台时重新读取。出生当天为日龄 0；0–364 天显示对应通用文案，已有符合条件的记录才补充个性化事实。
- 一天一条不是需要一年365条医学结论。发布前需逐条审核年龄适用性、早产儿/特殊疾病提示、中文准确性、负面情绪和危险信号，并根据获批版本更新内容与测试。

## 来源标记与人工审核

每个条目携带 `source_ids` 供审核人员定位主题资料：

| ID | 来源页面 |
| --- | --- |
| `cdc_milestones` | https://www.cdc.gov/act-early/milestones/index.html |
| `cdc_sleep` | https://www.cdc.gov/sudden-infant-death/sleep-safely/index.html |
| `cdc_solids` | https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/when-what-and-how-to-introduce-solid-foods.html |
| `cdc_choking` | https://www.cdc.gov/infant-toddler-nutrition/foods-and-drinks/choking-hazards.html |
| `aap_feeding` | https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/how-often-and-how-much-should-your-baby-eat.aspx |
| `aap_stool` | https://www.healthychildren.org/English/ages-stages/baby/Pages/The-Many-Colors-of-Poop.aspx |

`source_ids` 是主题线索，不是“这一天发生特定里程碑”的医学证据。人工审核完成之前，所有条目的状态仍为 `draft-requires-clinical-review`。

## 本轮修订与待完成事项

本轮按“家长看完知道观察什么或做什么、尽可能口语化”的标准重写逐日草案；不再靠每周阶段前缀形成表面上的 365 种文案。机械结果及复核清单见 [`baby-daily-advice-mechanical-audit.md`](baby-daily-advice-mechanical-audit.md)。这些文字仍是**未审核草案**；内容重复感、具体风险表述与来源适配仍需临床和中文编辑逐条确认。当前记录个性化只在可靠读取后补充客观次数，不是医学趋势分析；没有记录则完整显示当天通用文案。
