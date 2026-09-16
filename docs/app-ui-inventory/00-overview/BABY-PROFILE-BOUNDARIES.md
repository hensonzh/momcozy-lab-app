# 宝宝资料名称边界、日期导航与资料移除

正式 App 的 More → Baby → 当前资料，实际输入、拖动、保存、重开与日期选择，最后沿冲突 → 重新载入 → 无权限 → 离开 → 切换到仍可访问的宝宝。393 px / 1x 与 320 px / 2x 使用正式 UI、GoRouter、Repository / codec，HTTP、时钟、会话为隔离 fixture，没有修改真实宝宝记录。

## 实际链路

- 输入 119、120、121 个 ASCII 字符。121 个经 TextField 限制保留前 120 个，Controller 和 TextField 均断言一致。实际横向拖至名字首端与末端，393 px 滚动范围约 710.27 px，320 px / 2x 约 1727.54 px。
- 输入 61 个 e 加组合重音字符（61 个字素、122 个 Unicode 码点），输入框接受，点击保存则出现“宝宝称呼不能超过 120 字”，且未产生写请求。UI 与 Controller 计数单位不一致如实保留。
- 重新输入 120 字 ASCII 名称并保存，首页显示真实 fixture 返回值；重开确认持久化，随后改回 Luna 并保存。
- 普通字号日历前后月份导航至七、八、九月，当前月未来日期与下月导航禁用；点击月标题打开年份列表，选择 2025，再选择 9 月 15 日并确认。
- 两种尺寸均输入 abc 触发格式错误、1899/12/31 触发最早日期范围错误；修正为 2026/9/1。普通字号再由输入切回日历，确认并保存，首页月龄刷新为 12 天。
- 资料编辑期间 fixture 版本变化导致冲突，重新载入前该宝宝从可访问列表移除。点击重新载入显示无权限并保留草稿；关闭确认离开后首页自动选择剩余宝宝 Leo，继续切 More。

年份/月日选择通过可见的本地化文字和真实按钮点击完成。大字号按当前产品代码使用 inputOnly，因此没有伪造大字号日历。没有直接调用选择器回调或跳改 Controller 值。

## 状态与前驱索引

| 实际触发 | 截图、长图与前驱 |
| --- | --- |
| Open birth date calendar or large-text input | [运行证据](../04-baby/baby-profile-boundaries-birth-open/README.md) |
| Confirm calendar selection → profile draft date changes | [运行证据](../04-baby/baby-profile-boundaries-calendar-confirmed/README.md) |
| Submit date before 1900 → range validation | [运行证据](../04-baby/baby-profile-boundaries-date-before-minimum/README.md) |
| Confirm valid date → draft September 1 | [运行证据](../04-baby/baby-profile-boundaries-date-corrected/README.md) |
| Save new birth date → home age and growth range refresh | [运行证据](../04-baby/baby-profile-boundaries-date-saved/README.md) |
| Choose September 15 in calendar | [运行证据](../04-baby/baby-profile-boundaries-day-selected/README.md) |
| More → Baby for profile boundary controls | [运行证据](../04-baby/baby-profile-boundaries-home-entry/README.md) |
| Correct typed date then return to calendar preview | [运行证据](../04-baby/baby-profile-boundaries-input-to-calendar/README.md) |
| Submit malformed date → localized format validation | [运行证据](../04-baby/baby-profile-boundaries-invalid-date-format/README.md) |
| Calendar next month → current month, future navigation disabled | [运行证据](../04-baby/baby-profile-boundaries-latest-month/README.md) |
| Reopen maximum-length saved name | [运行证据](../04-baby/baby-profile-boundaries-maximum-name-reopened/README.md) |
| Save 120-character name → home identity and knowledge label update | [运行证据](../04-baby/baby-profile-boundaries-maximum-name-saved/README.md) |
| Baby → More after profile boundary journey | [运行证据](../04-baby/baby-profile-boundaries-more-return/README.md) |
| Enter 119-character profile name | [运行证据](../04-baby/baby-profile-boundaries-name-119/README.md) |
| Enter maximum 120-character name | [运行证据](../04-baby/baby-profile-boundaries-name-120/README.md) |
| Enter 121 characters → TextField preserves first 120 | [运行证据](../04-baby/baby-profile-boundaries-name-121-truncated/README.md) |
| Drag name field left → final character of maximum-length name | [运行证据](../04-baby/baby-profile-boundaries-name-scroll-end/README.md) |
| Drag name field right → beginning of maximum-length name | [运行证据](../04-baby/baby-profile-boundaries-name-scroll-start/README.md) |
| Calendar next month → August 2026 | [运行证据](../04-baby/baby-profile-boundaries-next-month/README.md) |
| Calendar previous month → July 2026 | [运行证据](../04-baby/baby-profile-boundaries-previous-month/README.md) |
| Leave → refreshed home selects remaining accessible baby Leo | [运行证据](../04-baby/baby-profile-boundaries-remaining-baby-selected/README.md) |
| Concurrent profile update → conflict before membership is removed | [运行证据](../04-baby/baby-profile-boundaries-removed-before-reload-conflict/README.md) |
| Close removed profile draft → discard confirmation | [运行证据](../04-baby/baby-profile-boundaries-removed-leave-confirm/README.md) |
| Reload list no longer contains current baby → access error and draft retained | [运行证据](../04-baby/baby-profile-boundaries-removed-on-reload/README.md) |
| Save short name again → home header returns to compact layout | [运行证据](../04-baby/baby-profile-boundaries-short-name-restored/README.md) |
| 61 combining-accent letters exceed 120 Unicode code points → domain length validation | [运行证据](../04-baby/baby-profile-boundaries-unicode-length-validation/README.md) |
| Tap calendar month header → year picker | [运行证据](../04-baby/baby-profile-boundaries-year-list/README.md) |
| Choose year 2025 → September calendar | [运行证据](../04-baby/baby-profile-boundaries-year-selected/README.md) |

## 视觉发现

- 120 字名称在首页未限制行数。320 px / 2x 下首屏几乎全是名称，知识卡和生长说明也重复长名称，完整可滚动正文高 4404 px；393 px 下头部同样多行。编辑器标题限制三行并省略，输入本身保持横向滚动。
- 首尾拖动截图证明文字可被查看；纵向长图不会把单行输入框拉宽，也不会伪装全部名称同时可见。
- 组合字符校验提示“120 字”，没有解释实际以码点计算；输入框又隐藏计数，用户难以预判这一边界。
- 日历年份长图完整覆盖 1900–2026 年及固定顶部/底部动作；原视口停在当前年份附近。日期错误提示在普通字号与大字号均可见，大字日期头部仍有省略和较多留白。
- 资料被移除后未清空当前草稿，权限错误和离开确认可读；离开后首页与生长参考切至男宝宝 Leo，未继续显示不可访问的 Luna。

## 证据与验证

28 个逻辑状态、48 个视口变体、23 张纵向长图，8 个状态以长图为主图。71 张原图分为 175 个连续全宽片段，128 个唯一片段；96 个新片段组成 16 页，已全部查看，32 个逐像素复用之前已审阅片段。每张原图 SHA、完整纵向覆盖、审阅页对应像素与两端水平拖动元数据均校验，见 [分段来源](baby-profile-boundary-visual-review/sources.json) 和 [证据审计](baby-profile-boundary-evidence-audit.json)。

- [严格采集](runs/20260913T210602-targeted/capture.log)：2 项通过，0 失败，未更新基线；[命令](runs/20260913T210602-targeted/capture-command.json)、[退出码](runs/20260913T210602-targeted/capture-result.json) 留存。
- [全仓静态检查](baby-profile-boundary-analyze.log)：No issues found。删除新增测试的一条未使用 import 后通过，未改动产品代码。新增测试只读格式检查 0 changed。
- 新增 `test/modules/baby/baby_profile_boundary_inventory_test.dart`。最初测试把单个 emoji 误当两个 Unicode 码点，已改为真实组合字符案例；年份查找也改为当前语言的年文本。最终断言与截图均依实际组件行为通过。

剩余工作仍包括 CDC 外部来源/系统层、其他 Baby 记录逐项控件及边界、全体历史视觉审阅。参见 [控件清单](BABY-CONTROL-COVERAGE.md) 与 [全局完成审计](AUDIT.md)。本批没有重新构建原生 App 或操作实体输入法。
