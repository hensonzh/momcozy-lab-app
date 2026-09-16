# Baby 发育观察：年份、日期格与未登记出生日期

正式 More → Baby → 发育观察日期 → 放弃草稿 → 宝宝切换器 → 清除并保存出生日期 → 再次发育观察 → 日期范围校验 → 放弃草稿 → More。393 px / 1x 与 320 px / 2x 使用正式 App、路由、Repository 和 Controller，只替换隔离 HTTP 与会话数据，没有修改真实宝宝资料或健康记录。

## 实际运行结果

- 已知出生日期为 2026-08-22，当前日期为 2026-09-13。普通字号打开年份列表，仅 2026 年可用，其它填充年份显示禁用。点选 2026，再选择 9 月 12 日、确认，草稿日期更新。
- 大字号实际使用 inputOnly，没有年月切换按钮；输入 2026/9/12 并确认。日期修改后关闭会显示放弃确认，离开后没有新增记录。
- 返回 Baby 顶部点击 Luna，打开切换器并编辑当前宝宝资料；实际清除出生日期并保存。隔离服务返回 birth_date=null，再开观察编辑器，Controller 读取到无出生日期，选择器 firstDate=1900-01-01。
- 无出生日期时，普通日历年份列表可滚动，完整长图保留 1900 至 2026 年。点击 2025 年后进入 2025 年 9 月；再点选 15 日、确认。大字号用对应日期输入完成同一日期变更。
- 重开 2025-09-15 日期，普通字号切入输入模式；输入 1899/12/31 并确定，出现“超出范围。”，底层草稿仍为 2025-09-15。改为 1900/1/1 后确认成功，草稿接受最早日期。
- 最早日期仅用于检查选择器下限，没有保存观察记录。再次关闭并确认离开，records 仍为空，最后点击 More。

## 视觉与交互观察

29 个状态、49 个视口变体、19 张完整长图；6 个状态选用长图为主图。68 张原图全宽连续检查，共 167 段、101 个唯一片段。47 个新片段组成 8 张审阅页，均已查看；54 个片段与此前审阅图像逐像素一致。详见 [图像来源映射](baby-development-date-visual-review/sources.json) 和 [证据审计](baby-development-date-evidence-audit.json)。

- 大字编辑器的短窗口会停留在底部日期与保存按钮，完整长图保留三组行为、提示、日期和保存动作，不能只看窗口判断缺项。
- 年份列表长图保留固定的日期标题及确定/取消按钮，年度从顶部连续到 2026，未把多屏各自的标题重复拼入内容。
- 纯输入模式下，输入文字尚未确认时顶部仍显示先前日期；确认后草稿才变化。范围校验错误也不更新底层草稿。
- 只改变日期、未选择任何行为，同样会触发关闭确认。这是实际 dirty 状态逻辑。
- 初次采集后工作区 More 更新了 MomSettingsRow；本批已重采返回页面，8 张审阅页基于最终截图。最终采集前后 lib 源码哈希一致，并保存 [采集前源码快照](baby-development-date-capture-source-snapshot.json)。这不代表旧批次的 More 各种状态都已更新，仍需另行复核当前 More 的完整链路。

## 逐状态路径

| 实际动作 | 截图、完整长图与前驱 |
| --- | --- |
| Tap Luna → baby switcher | [运行证据](../04-baby/baby-development-date-baby-switcher/README.md) |
| Submit Dec 31 1899 → range validation, draft unchanged | [运行证据](../04-baby/baby-development-date-before-minimum-rejected/README.md) |
| Clear birth date in profile draft | [运行证据](../04-baby/baby-development-date-birth-cleared/README.md) |
| Switch reopened calendar to date text input | [运行证据](../04-baby/baby-development-date-earlier-date-input-mode/README.md) |
| Reopen picker at selected date Sep 15 2025 | [运行证据](../04-baby/baby-development-date-earlier-date-reopened/README.md) |
| Open development observation editor | [运行证据](../04-baby/baby-development-date-editor/README.md) |
| More → Baby before date navigation | [运行证据](../04-baby/baby-development-date-home-entry/README.md) |
| Scroll Baby back to profile header | [运行证据](../04-baby/baby-development-date-home-top/README.md) |
| Confirm Sep 12 → observation draft date changes | [运行证据](../04-baby/baby-development-date-known-birth-confirmed/README.md) |
| Tap day grid Sep 12 → selected, still awaiting confirmation | [运行证据](../04-baby/baby-development-date-known-birth-day-selected/README.md) |
| Close date-modified draft → discard confirmation | [运行证据](../04-baby/baby-development-date-known-birth-discard/README.md) |
| Large text input-only picker: enter Sep 12 | [运行证据](../04-baby/baby-development-date-known-birth-input/README.md) |
| Discard changed observation date → Baby, no records written | [运行证据](../04-baby/baby-development-date-known-birth-left/README.md) |
| Open date with known birth → range Aug 22 through Sep 13 | [运行证据](../04-baby/baby-development-date-known-birth-picker/README.md) |
| Select 2026 → September calendar | [运行证据](../04-baby/baby-development-date-known-birth-year-selected/README.md) |
| Tap calendar header → only birth/current year selectable | [运行证据](../04-baby/baby-development-date-known-birth-years/README.md) |
| Confirm Jan 1 1900 → accepted as draft, no observation saved | [运行证据](../04-baby/baby-development-date-minimum-confirmed/README.md) |
| Close minimum-date draft → discard confirmation | [运行证据](../04-baby/baby-development-date-minimum-discard/README.md) |
| Baby → More after date navigation; only isolated profile fixture changed | [运行证据](../04-baby/baby-development-date-more-return/README.md) |
| Confirm earlier year → no-birth observation draft accepts date | [运行证据](../04-baby/baby-development-date-no-birth-confirmed/README.md) |
| Select Sep 15 2025 on day grid | [运行证据](../04-baby/baby-development-date-no-birth-day-selected/README.md) |
| Open observation for baby without birth date | [运行证据](../04-baby/baby-development-date-no-birth-editor/README.md) |
| Save profile with no birth date → Baby | [运行证据](../04-baby/baby-development-date-no-birth-home/README.md) |
| Large text input-only picker: enter Sep 15 2025 | [运行证据](../04-baby/baby-development-date-no-birth-input/README.md) |
| Discard date-only draft → Baby with no observations | [运行证据](../04-baby/baby-development-date-no-birth-left/README.md) |
| No birth date → earliest selectable date Jan 1 1900 | [运行证据](../04-baby/baby-development-date-no-birth-picker/README.md) |
| Select 2025 → September calendar | [运行证据](../04-baby/baby-development-date-no-birth-year-selected/README.md) |
| Open year list without birth date → earlier years available | [运行证据](../04-baby/baby-development-date-no-birth-years/README.md) |
| Edit current baby profile through switcher | [运行证据](../04-baby/baby-development-date-profile-editor/README.md) |

## 验证与剩余范围

- [严格采集](runs/20260913T232223-targeted/capture.log)：2 项通过，正式采集未更新 Golden 基线。新场景先建立基线，More 变化后更新对应基线并再次严格采集。
- [全仓静态检查](baby-development-date-analyze.log)：No issues found，退出码 0。
- 初次测试返回 Baby 后向下寻找已在上方的 Luna，导致测试找不到控件；已改为实际向上滚动，并独立保存回到顶部的状态。没有修改业务逻辑。
- 本批未进行设备构建、原生系统输入法或真实账号写入。Android 发育观察放弃链见 [原生报告](../native/baby-development-discard/README.md)。
- 创建/编辑权限与版本冲突、多记录交错、提交后丢响应、未确认时重复撤销、挂起期间离开及系统输入层仍未完成。年份与日期格在普通字号可用，大字号没有对应控件，不复制虚构状态。

[最终文件完整性检查](baby-development-date-final-verify.log)：PASS，2079 条目、1858 张宿主长图、1703 个正常路由状态；goal_completion=NOT_PROVEN。全 App 仍未完成；文件完整性检查不作为全部 Page × State × Interaction 覆盖证明。
