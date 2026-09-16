# Baby 喂养方式、侧别与数值控件

通过正式用户 App 的 More → Baby → 今日吃奶记录，再进入历史编辑与返回。393 px / 1x 和 320 px / 2x 使用实际 GoRouter、生产 Repository / codec；仅 HTTP、会话、时钟与原生依赖使用隔离 fixture。所有选择、输入、保存和返回均通过 WidgetTester 的点击或文本输入完成，没有直接调用按钮回调或改写 Controller 草稿。

## 已验证链路

- 亲喂、瓶喂母乳、配方奶逐项选择；再次点击已选方式取消选择。亲喂左侧、右侧、两侧逐项选择并取消侧别；保存时分别出现缺少方式或侧别校验。
- 亲喂时长 0、241、1.5 分别触发范围或整数校验；输入 240 后继续切换方式，回到亲喂时仍保留 240 与左侧。最终真正保存 240 分钟，历史回显一致。
- 瓶喂量 0、1001、abc 分别触发范围或格式校验；输入 1000 后错误消失并在切换至配方奶时保留。**1000 在本批仅验证输入与草稿保留，没有以 1000 保存，不作为上限提交成功证据。**
- 备注展开、输入包含首尾空格与换行的短文本、折叠后再次切换方式。保存后首尾空格被移除，换行和正文保留，重开编辑时备注默认展开。
- 从历史编辑把已保存亲喂改成配方奶 90.5 ml：实际保存后版本为 2，奶量回显 90.5，亲喂侧别和时长为空。随后清空可选奶量并再次保存，版本为 3，历史显示“奶量未填写”，首页显示 1 次而不虚构奶量。
- 未修改的编辑器可直接关闭，不出现放弃草稿确认。历史通过真实“返回”按钮回 Baby，最后切 More。
- 每次校验拒绝均断言写请求数不变；实际保存后核对 Repository 返回的记录类型、数值与版本。没有写入真实账号数据。

## 视觉检查

112 张原始 PNG（68 个视口、44 张长图）分为 260 个连续全宽片段，其中 172 个唯一片段。155 个新片段组成 26 页，已全部查看；17 个片段与此前已审阅图像逐像素一致。长图从页头到页脚连续覆盖，保存按钮与固定导航只在对应位置保留，不把滚动后的局部视口冒充完整页面。见 [分段来源](baby-feeding-control-visual-review/sources.json) 与 [证据审计](baby-feeding-control-evidence-audit.json)。

- 窄屏大字下新增记录标题换为两行，方式和侧别纵向排列，日期时间换行；错误提示完整换行，正文可滚动，固定关闭和保存入口可见。
- 空备注的输入提示在 320 px / 2x 显示为“备注（可…”；输入后浮动标签显示完整。这是现有 UI 的省略现象，未通过改小字体隐藏。
- 数值输入后视口可能停在表单中下部，长图仍保留方式、时间、数值、备注、统计说明与底部动作。英文短备注在大字下换为多行。
- 历史大字模式的分类条水平滚动，当前视口不能同时容纳所有分类；本批只沿喂养标签操作，不声称覆盖其他分类的横向行为。
- 保存成功提示“记录已保存”在历史页底部展示；首页亲喂保存结果包含撤销入口，本批未再次点击撤销，已有新增/撤销链见 [Baby 路由链](BABY-JOURNEYS.md)。

## 实际状态与前驱

| 触发动作 | 截图、长图与前驱 |
| --- | --- |
| Tap save → 亲喂时长请填写整数分钟。; no write request | [运行证据](../04-baby/baby-feeding-controls-duration-fraction/README.md) |
| Tap save → 亲喂时长需要为 1–240 分钟，也可以留空。; no write request | [运行证据](../04-baby/baby-feeding-controls-duration-over-limit/README.md) |
| Enter valid 240 minute upper bound → validation cleared | [运行证据](../04-baby/baby-feeding-controls-duration-upper-bound/README.md) |
| Tap save → 亲喂时长需要为 1–240 分钟，也可以留空。; no write request | [运行证据](../04-baby/baby-feeding-controls-duration-zero/README.md) |
| Change saved nursing to formula and enter decimal 90.5 ml | [运行证据](../04-baby/baby-feeding-controls-edit-formula-decimal/README.md) |
| Switch to expressed milk → volume replaces nursing controls; nursing draft retained | [运行证据](../04-baby/baby-feeding-controls-expressed-milk-selected/README.md) |
| Reopen saved formula → decimal restored, no stale nursing fields | [运行证据](../04-baby/baby-feeding-controls-formula-history-reopened/README.md) |
| Save type change → formula shown, nursing fields omitted | [运行证据](../04-baby/baby-feeding-controls-formula-history-saved/README.md) |
| Switch expressed milk → formula; bottle volume retained | [运行证据](../04-baby/baby-feeding-controls-formula-selected/README.md) |
| History Back → home counts feeding without invented ml | [运行证据](../04-baby/baby-feeding-controls-home-count-only/README.md) |
| More → Baby before adding feeding | [运行证据](../04-baby/baby-feeding-controls-home-entry/README.md) |
| Tap save → 先选择这次的喂养方式。; no write request | [运行证据](../04-baby/baby-feeding-controls-method-deselected/README.md) |
| Baby → More after feeding controls | [运行证据](../04-baby/baby-feeding-controls-more-return/README.md) |
| Collapse note → filled marker and draft retained | [运行证据](../04-baby/baby-feeding-controls-note-collapsed/README.md) |
| Expand optional feeding note | [运行证据](../04-baby/baby-feeding-controls-note-expanded/README.md) |
| Enter multiline note with boundary whitespace | [运行证据](../04-baby/baby-feeding-controls-note-filled/README.md) |
| Reselect nursing → original side and duration return | [运行证据](../04-baby/baby-feeding-controls-nursing-draft-restored/README.md) |
| View all records → saved nursing with duration and note | [运行证据](../04-baby/baby-feeding-controls-nursing-history/README.md) |
| Edit saved nursing → persisted values, note expanded | [运行证据](../04-baby/baby-feeding-controls-nursing-history-edit/README.md) |
| Save nursing → home refresh; dormant bottle value omitted and note trimmed | [运行证据](../04-baby/baby-feeding-controls-nursing-saved/README.md) |
| Select nursing → side and optional duration appear | [运行证据](../04-baby/baby-feeding-controls-nursing-selected/README.md) |
| Clear optional bottle volume before saving | [运行证据](../04-baby/baby-feeding-controls-optional-volume-cleared/README.md) |
| Reopen formula without volume → empty optional field persisted | [运行证据](../04-baby/baby-feeding-controls-optional-volume-reopened/README.md) |
| Save formula without measured volume → count-only history | [运行证据](../04-baby/baby-feeding-controls-optional-volume-saved/README.md) |
| Tap 两侧 → selected nursing side | [运行证据](../04-baby/baby-feeding-controls-side-both/README.md) |
| Tap save → 请选择这次亲喂的侧别。; no write request | [运行证据](../04-baby/baby-feeding-controls-side-deselected/README.md) |
| Tap 左侧 → selected nursing side | [运行证据](../04-baby/baby-feeding-controls-side-left/README.md) |
| Tap save → 请选择这次亲喂的侧别。; no write request | [运行证据](../04-baby/baby-feeding-controls-side-required/README.md) |
| Tap 右侧 → selected nursing side | [运行证据](../04-baby/baby-feeding-controls-side-right/README.md) |
| Close unchanged saved record → no discard dialog | [运行证据](../04-baby/baby-feeding-controls-unchanged-editor-closed/README.md) |
| Tap save → 请检查瓶喂量。; no write request | [运行证据](../04-baby/baby-feeding-controls-volume-not-number/README.md) |
| Tap save → 瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。; no write request | [运行证据](../04-baby/baby-feeding-controls-volume-over-limit/README.md) |
| Enter 1000 ml upper bound → validation cleared | [运行证据](../04-baby/baby-feeding-controls-volume-upper-bound/README.md) |
| Tap save → 瓶喂量需要大于 0 且不超过 1000 ml，也可以留空。; no write request | [运行证据](../04-baby/baby-feeding-controls-volume-zero/README.md) |

## 验证与边界

- [严格采集](runs/20260913T214319-targeted/capture.log)：2 项通过，不更新 Golden 基线。同目录保留执行命令和返回结果。
- [全仓静态检查](baby-feeding-control-analyze.log)：No issues found，进程退出码 0。首次分析虽已输出无问题，随后因遥测连接异常退出 255；此处采用关闭本次命令遥测后的成功重试，不把首次异常当作成功。
- 新增测试只读格式检查 0 changed；本批没有修改产品业务代码。
- 本批没有运行 Android/iOS 键盘或实体设备。时间选择器、未来时间、备注 2000 字与输入滚动、亲喂可选时长留空保存、其他有效边界、权限和冲突分支仍需补齐，详见 [Baby 控件清单](BABY-CONTROL-COVERAGE.md)。

当前全 App 盘点仍未完成；状态和文件数仅说明已有资产，不代表所有交互已覆盖。
