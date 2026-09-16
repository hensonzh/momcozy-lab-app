# 宝宝资料逐项控件与知识转入 Cozymate

正式用户 App 的 More → Baby → 宝宝切换器 → 编辑当前资料，完成保存后从知识卡进入全文，再将文章标题预填到 Cozymate，返回 Baby / More。393 px / 1x 与 320 px / 2x 均运行实际 App、GoRouter、生产 Repository / codec。HTTP、会话、时钟和语音播放为隔离 fixture，未修改真实宝宝资料或发送消息。

## 实际操作与数据断言

- 出生记录性别：男宝宝、暂不填写、女宝宝依次点击；喂养方式五个选项分别展开菜单并选中。
- 出生日期：打开已有日期，普通字号由日历切输入；未来日期被范围校验拒绝，改为有效日期后确认，再清除日期并保存。首页显示月龄待完善和生长参考资料缺失，重开资料确认空值持久化。
- 空日期选择器以注入的今天打开。输入日期后取消，空草稿保持；再次输入并确认恢复出生日期。
- 名称仅空格时保存被拒绝，版本 2 保持。修正姓名后，模拟 PUT 503，草稿锁定、保存结果未确认；关闭触发确认，继续填写返回同一待确认草稿。恢复服务后点击重试确认保存，版本更新为 3。
- 重新打开确认姓名、日期、性别和喂养方式回显；未改动关闭不产生确认弹窗。
- 知识卡 → 全文 → 问问 Cozymate，实际路由转为 `/`，文章标题进入输入框，断言没有产生 `/runs` 写请求。点击 Baby 返回，已保存资料保持，再切 More。

## 状态与前驱索引

| 实际触发 | 截图、长图及前驱 |
| --- | --- |
| Cancel typed birth date → draft remains empty | [运行证据](../04-baby/baby-profile-controls-birth-cancelled/README.md) |
| Confirm valid birth date August 10 | [运行证据](../04-baby/baby-profile-controls-birth-changed/README.md) |
| Clear birth date → draft unregistered | [运行证据](../04-baby/baby-profile-controls-birth-cleared/README.md) |
| Confirm future birth date → picker range error; original date preserved | [运行证据](../04-baby/baby-profile-controls-birth-future-rejected/README.md) |
| Calendar → birth date input | [运行证据](../04-baby/baby-profile-controls-birth-input/README.md) |
| Open existing birth date picker | [运行证据](../04-baby/baby-profile-controls-birth-open/README.md) |
| Confirm restored birth date August 22 | [运行证据](../04-baby/baby-profile-controls-birth-restored/README.md) |
| Baby switcher → edit Luna profile | [运行证据](../04-baby/baby-profile-controls-editor/README.md) |
| Select feeding mode breastfeeding | [运行证据](../04-baby/baby-profile-controls-feeding-breastfeeding/README.md) |
| Select feeding mode expressedMilk | [运行证据](../04-baby/baby-profile-controls-feeding-expressedMilk/README.md) |
| Select feeding mode formula | [运行证据](../04-baby/baby-profile-controls-feeding-formula/README.md) |
| Open feeding mode menu before choosing breastfeeding | [运行证据](../04-baby/baby-profile-controls-feeding-menu-breastfeeding/README.md) |
| Open feeding mode menu before choosing expressedMilk | [运行证据](../04-baby/baby-profile-controls-feeding-menu-expressedMilk/README.md) |
| Open feeding mode menu before choosing formula | [运行证据](../04-baby/baby-profile-controls-feeding-menu-formula/README.md) |
| Open feeding mode menu before choosing mixed | [运行证据](../04-baby/baby-profile-controls-feeding-menu-mixed/README.md) |
| Open feeding mode menu before choosing unknown | [运行证据](../04-baby/baby-profile-controls-feeding-menu-unknown/README.md) |
| Select feeding mode mixed | [运行证据](../04-baby/baby-profile-controls-feeding-mixed/README.md) |
| Select feeding mode unknown | [运行证据](../04-baby/baby-profile-controls-feeding-unknown/README.md) |
| More → Baby | [运行证据](../04-baby/baby-profile-controls-home-entry/README.md) |
| Ask Cozymate → normal Agent route with article title prefilled, not sent | [运行证据](../04-baby/baby-profile-controls-knowledge-agent-prefill/README.md) |
| Cozymate → Baby, saved profile retained | [运行证据](../04-baby/baby-profile-controls-knowledge-baby-return/README.md) |
| Tap knowledge card → full article | [运行证据](../04-baby/baby-profile-controls-knowledge-detail/README.md) |
| Open missing birth date → initial date is injected today | [运行证据](../04-baby/baby-profile-controls-missing-birth-picker/README.md) |
| Reopen profile → cleared date persisted | [运行证据](../04-baby/baby-profile-controls-missing-birth-reopened/README.md) |
| Save cleared birth date → home missing age and growth reference | [运行证据](../04-baby/baby-profile-controls-missing-birth-saved/README.md) |
| Baby → More | [运行证据](../04-baby/baby-profile-controls-more-return/README.md) |
| Correct profile name → validation clears | [运行证据](../04-baby/baby-profile-controls-name-corrected/README.md) |
| Save whitespace name → required validation, saved profile untouched | [运行证据](../04-baby/baby-profile-controls-name-empty-validation/README.md) |
| Retry confirms save → home identity and age restored | [运行证据](../04-baby/baby-profile-controls-retry-saved/README.md) |
| Profile PUT returns 503 → locked draft and retry confirmation | [运行证据](../04-baby/baby-profile-controls-save-unconfirmed/README.md) |
| Reopen saved profile → all saved fields restored | [运行证据](../04-baby/baby-profile-controls-saved-reopened/README.md) |
| Select profile sex female | [运行证据](../04-baby/baby-profile-controls-sex-female/README.md) |
| Select profile sex male | [运行证据](../04-baby/baby-profile-controls-sex-male/README.md) |
| Select profile sex unspecified | [运行证据](../04-baby/baby-profile-controls-sex-unspecified/README.md) |
| Close unconfirmed save → uncertain-result leave dialog | [运行证据](../04-baby/baby-profile-controls-uncertain-leave-confirm/README.md) |
| Continue filling → same locked pending draft | [运行证据](../04-baby/baby-profile-controls-uncertain-stay/README.md) |
| Close unchanged profile → home without discard confirmation | [运行证据](../04-baby/baby-profile-controls-unchanged-close/README.md) |

## 完整截图与视觉检查

37 个逻辑状态、73 个视口变体、33 张完整长图，7 个状态以长图为主图。106 张原图分为 239 个连续全宽片段，共 150 个唯一片段；148 个新片段组成 25 页，全部审阅；另 2 个与此前已审阅证据逐像素一致。来源 SHA、纵向连续性、全部片段与审阅页对应像素均校验通过，见 [分段来源](baby-profile-control-visual-review/sources.json) 和 [审计](baby-profile-control-evidence-audit.json)。

- 320 px / 2x 资料标题从两行变为更新姓名后的三行，占用较大固定页头；表单仍可滚动至所有字段及保存按钮。长图完整保留标题、正文和页脚，没有缩小字号。
- 大字下性别选项纵向排列，五种喂养菜单选项均可见。出生日期输入器头部留白较大，日期星期文本有省略，范围错误与确认/取消可达。
- 无出生日期时不显示虚构月龄或生长参考线；宝宝首页在窄屏大字下部分统计卡呈居中窄列，作为现状保留。
- 保存失败的 ProductErrorView 使用“暂时无法载入，请稍后重试”，与保存场景不完全匹配；锁定草稿与“重试确认保存”动作可见。
- 知识全文的三条要点、来源入口、说明及固定提问按钮均保留。Cozymate 的预填输入、发送按钮、快速提问和导航在完整截图中可追溯；大字短视口有“回到最新消息”浮层。

## 日期时钟修复与验证

资料日期选择器原先未传 `currentDate`，宿主实际日期与 Controller 时区内的 today 不同，跨日时高亮不稳定。新增断言先复现两个尺寸失败，随后在 `baby_profile_editor.dart` 传入 Controller.today 对应的日期，不写死测试日期。

- [修复前断言](baby-profile-control-date-red.log)：两项日期断言失败；[最终严格采集](runs/20260913T204751-targeted/capture.log)：2 项通过，未更新金图基线。
- [既有资料与路由回归](baby-profile-control-regression.log)：25 项通过，覆盖 controller、editor、profiles、Baby journey 四个测试文件。
- [全仓静态检查](baby-profile-control-analyze.log)：No issues found；新增测试与修改编辑器格式检查 0 changed。

本批未执行实体设备、Android/iOS 输入法，也未点击 CDC 外部来源、资料冲突重新载入、权限失败、120 字名称边界及保存未确认后真正离开。后续 [资料恢复链](BABY-PROFILE-RECOVERY.md) 已补齐冲突重载、保存权限失败、保存中及未确认后离开，其余仍列入 [Baby 控件清单](BABY-CONTROL-COVERAGE.md)，全局 [完成审计](AUDIT.md) 保持未完成。
