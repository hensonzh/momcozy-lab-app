# Baby 发育观察：日期边界、单项保存与异常返回

沿正式用户 App 的 More → Baby → 记录发育观察操作，393 px / 1x 和 320 px / 2x 均使用生产路由、Controller、Repository 与 codec；HTTP、会话、时钟及平台依赖为隔离 fixture。只创建测试观察，没有操作真实宝宝数据。Android 普通草稿放弃另见 [原生补验](../native/baby-development-discard/README.md)。

## 已执行链路

- 仅选中“看向靠近的脸 → 观察到”。打开日期后依次输入 invalid、出生前一天 2026-08-21、明天 2026-09-14，并分别点击确定。实际显示“格式无效。”或“超出范围。”，对话框保持打开，编辑器日期仍为 2026-09-13，尚未创建记录。
- 输入出生当天 2026-08-22 并确定，日期接受。普通字号重新打开日历，点击下一月到九月，再点击上一月返回八月，取消后仍保留出生当天。大字号按产品现状仅支持输入模式，没有日历/月切换；这一状态单独命名，没有强行输出不存在的月份变体。
- 点击保存，暂停 HTTP 响应，采集保存中状态。实际点击禁用关闭，再发送平台 Back，两步分别截图；编辑器仍 busy，没有出现放弃确认。放行响应后恰好创建一条 looks-at-face/observed 记录，日期为出生当天。
- 再打开空编辑器，选“不确定”，模拟 HTTP 503。出现内容保留、保存未确认与重试按钮。发送平台 Back，显示专用未确认提示；实际点击“离开”返回 Baby，fixture 中仍只有此前成功的一条记录。
- 重新进入时没有旧选择或 uncertain 标记，日期重置为当天，草稿可重新编辑。未修改关闭后返回 More。

失败 fixture 明确在写入前返回 503；这里不能证明生产环境所有超时都没有写入，也不覆盖“服务器已提交但响应丢失”的另一种结果。用户仍应遵从页面提示刷新记录，避免重复填写。

## 截图与视觉审核

21 个逻辑状态、38 个视口变体、15 张完整长图，4 个状态以长图为主图。53 张源 PNG 按全宽连续分成 129 段，76 个唯一片段；其中 30 个新片段分布于 5 张审阅页，全部查看，其余 46 个与先前已审阅片段逐像素一致。[分段来源](baby-development-boundary-visual-review/sources.json) 和 [证据审计](baby-development-boundary-evidence-audit.json) 校验 SHA、连续全高及审阅页像素。

- 输入错误在普通与大字号下均清晰展示；大字日期标题可能出现省略号，输入框仍显示完整日期，底部确认/取消在后续连续片段中保留。
- 八月日历把出生日前的日期置灰；九月把未来日期置灰，取消浏览未改变原选中日期。本批没有点击灰色日期或年份标题。
- 保存中日期、按钮变灰，关闭图标在深色标题背景上很暗；实际点击和平台返回均验证被阻止。大字正文可滚动，长图保留三组选择、日期和唯一保存按钮。
- 503 提示仍使用“暂时无法载入，请稍后重试”，与保存动作语义不完全匹配；未确认提示及重试按钮在长图中完整。这里如实记录现有产品文案。
- 单项保存后成功 Snackbar 只出现一次；Baby 长图覆盖从顶部到睡眠监测、记录入口和固定底部导航。普通窗口位于先前滚动位置，不冒充完整主页。

## 状态索引

| 实际操作 | 截图、完整长图与前驱 |
| --- | --- |
| Reopen birth date and switch to calendar | [运行证据](../04-baby/baby-development-boundaries-birth-calendar/README.md) |
| Reopen birth date at large text → input-only picker without month navigation | [运行证据](../04-baby/baby-development-boundaries-birth-input-only/README.md) |
| Confirm birth date → earliest valid observation date | [运行证据](../04-baby/baby-development-boundaries-birth-selected/README.md) |
| Cancel month browsing → birth date and choice retained | [运行证据](../04-baby/baby-development-boundaries-calendar-cancel/README.md) |
| Submit before-birth date → picker validation, draft date unchanged | [运行证据](../04-baby/baby-development-boundaries-date-before-birth-rejected/README.md) |
| Submit format date → picker validation, draft date unchanged | [运行证据](../04-baby/baby-development-boundaries-date-format-rejected/README.md) |
| Submit future date → picker validation, draft date unchanged | [运行证据](../04-baby/baby-development-boundaries-date-future-rejected/README.md) |
| Open observation date: birth 8/22 through today 9/13 | [运行证据](../04-baby/baby-development-boundaries-date-open/README.md) |
| More → Baby before date and save boundaries | [运行证据](../04-baby/baby-development-boundaries-home-entry/README.md) |
| Close unchanged editor → More | [运行证据](../04-baby/baby-development-boundaries-more-return/README.md) |
| Next month → September calendar | [运行证据](../04-baby/baby-development-boundaries-next-month/README.md) |
| Choose observed for one behavior only | [运行证据](../04-baby/baby-development-boundaries-one-selected/README.md) |
| Platform Back during save → editor remains without discard dialog | [运行证据](../04-baby/baby-development-boundaries-pending-back-blocked/README.md) |
| Tap disabled close → saving editor remains | [运行证据](../04-baby/baby-development-boundaries-pending-close-blocked/README.md) |
| Previous month → August calendar | [运行证据](../04-baby/baby-development-boundaries-previous-month/README.md) |
| Reopen after unconfirmed leave → fresh empty editable draft dated today | [运行证据](../04-baby/baby-development-boundaries-reopened-clean/README.md) |
| Save single observation → request pending | [运行证据](../04-baby/baby-development-boundaries-save-pending/README.md) |
| Second draft save fails 503 → unconfirmed result | [运行证据](../04-baby/baby-development-boundaries-save-unconfirmed/README.md) |
| Response acknowledged → exactly one observation on birth date | [运行证据](../04-baby/baby-development-boundaries-single-saved/README.md) |
| Platform Back on unconfirmed save → uncertainty discard confirmation | [运行证据](../04-baby/baby-development-boundaries-unconfirmed-back-confirm/README.md) |
| Choose leave → Baby without acknowledged second write | [运行证据](../04-baby/baby-development-boundaries-unconfirmed-left/README.md) |

## 验证与剩余范围

- [严格采集](runs/20260913T225446-targeted/capture.log)：2 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-development-boundary-analyze.log)：No issues found，退出码 0。
- 初次生成基线时，大字分支尝试寻找产品不存在的月份按钮失败；根据 inputOnly 实现拆分了路径，最终两尺寸均通过。未修改业务代码。
- 仍待补齐年份/日格点击、无出生日期范围、权限/版本冲突、服务器已提交但响应丢失、其他单项与两项创建、各项删除恢复及原生系统层。已有批量和历史编辑见 [发育观察控件](BABY-DEVELOPMENT-CONTROLS.md)。

本批不是全 App 完成证明；完整目标继续保持未完成。

[最终资产完整性检查](baby-development-boundary-final-verify.log) 通过：1971 个条目、3698 份元数据、1764 份长图范围，goal_completion=NOT_PROVEN。新增测试只读格式检查 0 changed。
