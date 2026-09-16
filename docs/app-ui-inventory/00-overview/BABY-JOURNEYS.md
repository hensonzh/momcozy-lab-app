# Baby 正式路由链补验

本轮使用正式 MomCozyFlutterApp、GoRouter、生产 Repository 与 JSON codec；从已登录 More 点击 Baby，沿实际 UI 操作。HTTP 传输、登录持久化和时间使用隔离测试依赖，没有写入本地账号或真实宝宝记录。共 9 条测试、86 个状态观察点。

## 本轮覆盖

- 喂养：空表单、校验、输入、保存失败、确认重试、首页刷新、历史编辑、删除确认/取消/成功、撤销恢复、类别/月份切换。
- 资料：宝宝切换与登录会话同步、编辑/保存、新建校验、放弃/保留草稿、无资料创建、缺失出生资料入口、喂养方式菜单。
- 睡眠/尿便/知识：知识详情、睡眠起止及备注、撤销新增、尿湿/便便切换、颜色/血丝选中、放弃草稿、生长曲线切换、发育观察保存。
- 生长：空值/无效值、三项测量切换及批量保存、日期日历/输入/无效/选定、批量撤销失败与重试、反馈关闭。
- 历史：删除与恢复的未确认错误/重试；数据来源 → 隐私与授权 → 返回历史；51 条记录的第一页、分页错误、加载中、全部加载完成。
- 独立请求失败与下拉刷新；记录加载中、保存忙碌与成功。

所有观察点的根入口、前驱截图、触发动作与当前路径见下表和 [完整路由链](VERIFIED-JOURNEYS.md)。它们证明对应动作在运行的 App 中发生，不代表外部服务交易已经验收。

## 修正的采集证据问题

1. 长图滚动会解码懒加载图片；先预缓存本地头像与监控示意图，保证普通截图与滚动采集的背景状态一致。
2. 模拟服务返回需补充 `unit` / `label` 等服务端派生字段。新增保存后编辑器关闭的断言，防止只凭模拟存储写入就将界面标记成功。
3. 正式 App 的嵌套导航中，背景 PageRoute 在根导航弹窗出现后仍可能是 current。采集器现优先最上层 PopupRoute：无溢出的弹窗只保留窗口，有溢出才对弹窗内容拼长图。
4. 拼接帧采完整根 RenderView，保留真实灰色遮罩和背景；此前仅采 RenderRepaintBoundary 会遗漏根画面。
5. 输入后先推进一帧，再等待 250ms 提示文字动画结束，避免把旧输入或半透明提示重叠当作稳定状态。

## 验证

- 最新全量视觉采集：70 文件，**920 通过、6 既有跳过、0 失败**，见 [capture.log](capture.log)。
- 本轮 Baby + Auth 正式路由专项：11 条通过，见 [专项日志](runs/20260913T111148-targeted/capture.log)。
- 三个新增/修改测试辅助文件格式检查通过；全仓静态检查见 [baby-journey-analyze.log](baby-journey-analyze.log)。
- 文件、PNG 哈希及路由链接检查见 [artifact-verification.json](artifact-verification.json)，该检查不证明全部状态覆盖。
- 已检查 86 个窗口的缩略概览，并单独查看六个溢出弹窗长图、输入修正图、生长保存首页长图，以及分页长图顶部/中部/底部。复核图见 [baby-visual-review](baby-visual-review/)；窗口来源哈希见 [sources.json](baby-visual-review/sources.json)。全量长图逐项审阅仍在总清单待办中。

## 未覆盖完的 Baby 分支

后续已完成 [资料逐控件与知识转入 Cozymate](BABY-PROFILE-CONTROLS.md)：37 状态、73 视口、33 长图。余项以 [Baby 控件清单](BABY-CONTROL-COVERAGE.md) 为准。

知识详情转入 Cozymate、资料出生日期及性别修改已有后续证据。资料冲突、重新载入失败恢复、403 保存、未确认后离开和保存中返回已由 [恢复链](BABY-PROFILE-RECOVERY.md) 补验。仍需补齐其余记录选项及时间选择完整链、资料/历史其他读取失败、批量撤销部分失败等当前实现支持的分支。已有组件测试不能代替这些正常入口链的运行证据。本文件不是 Baby 模块完成声明。

## 状态入口索引

| 状态 | 实际触发 | 当前路径 | 截图 |
| --- | --- | --- | --- |
| [baby-journey-delete-cancelled](../04-baby/baby-journey-delete-cancelled/README.md) | Keep record → same history record | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-delete-cancelled/default.png) |
| [baby-journey-delete-confirm](../04-baby/baby-journey-delete-confirm/README.md) | Record Delete → confirmation | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-delete-confirm/default.png) |
| [baby-journey-development-editor](../04-baby/baby-journey-development-editor/README.md) | Tap record developmental observation | `/baby` | [图](../04-baby/baby-journey-development-editor/default.png) |
| [baby-journey-development-saved](../04-baby/baby-journey-development-saved/README.md) | Save observation → home with completion feedback | `/baby` | [图](../04-baby/baby-journey-development-saved/default.png) |
| [baby-journey-development-unsure](../04-baby/baby-journey-development-unsure/README.md) | Select unsure observation status | `/baby` | [图](../04-baby/baby-journey-development-unsure/default.png) |
| [baby-journey-empty-home](../04-baby/baby-journey-empty-home/README.md) | More → Baby, owned profiles without records | `/baby` | [图](../04-baby/baby-journey-empty-home/default.png) |
| [baby-journey-feeding-empty](../04-baby/baby-journey-feeding-empty/README.md) | Tap today feeding card → feeding editor | `/baby` | [图](../04-baby/baby-journey-feeding-empty/default.png) |
| [baby-journey-feeding-filled](../04-baby/baby-journey-feeding-filled/README.md) | Select expressed milk and enter 80 ml | `/baby` | [图](../04-baby/baby-journey-feeding-filled/default.png) |
| [baby-journey-feeding-mode-menu](../04-baby/baby-journey-feeding-mode-menu/README.md) | Profile feeding mode → dropdown options | `/baby` | [图](../04-baby/baby-journey-feeding-mode-menu/default.png) |
| [baby-journey-feeding-mode-selected](../04-baby/baby-journey-feeding-mode-selected/README.md) | Select mixed feeding | `/baby` | [图](../04-baby/baby-journey-feeding-mode-selected/default.png) |
| [baby-journey-feeding-nursing-left](../04-baby/baby-journey-feeding-nursing-left/README.md) | Select nursing method and left side | `/baby` | [图](../04-baby/baby-journey-feeding-nursing-left/default.png) |
| [baby-journey-feeding-save-error](../04-baby/baby-journey-feeding-save-error/README.md) | Save → HTTP 503 from isolated transport | `/baby` | [图](../04-baby/baby-journey-feeding-save-error/default.png) |
| [baby-journey-feeding-saved](../04-baby/baby-journey-feeding-saved/README.md) | Retry succeeds → home refresh and saved feedback | `/baby` | [图](../04-baby/baby-journey-feeding-saved/default.png) |
| [baby-journey-feeding-validation](../04-baby/baby-journey-feeding-validation/README.md) | Submit without feeding method → validation | `/baby` | [图](../04-baby/baby-journey-feeding-validation/default.png) |
| [baby-journey-first-profile-created](../04-baby/baby-journey-first-profile-created/README.md) | Save minimum profile → new baby home with missing birth date and sex | `/baby` | [图](../04-baby/baby-journey-first-profile-created/default.png) |
| [baby-journey-first-profile-form](../04-baby/baby-journey-first-profile-form/README.md) | Empty page CTA → first baby form | `/baby` | [图](../04-baby/baby-journey-first-profile-form/default.png) |
| [baby-journey-growth-batch-saved](../04-baby/baby-journey-growth-batch-saved/README.md) | Save → atomic measurement batch and home latest metrics | `/baby` | [图](../04-baby/baby-journey-growth-batch-saved/default.png) |
| [baby-journey-growth-batch-undone](../04-baby/baby-journey-growth-batch-undone/README.md) | Retry undo → all three batch measurements removed | `/baby` | [图](../04-baby/baby-journey-growth-batch-undone/default.png) |
| [baby-journey-growth-curve-head](../04-baby/baby-journey-growth-curve-head/README.md) | Switch growth curve to 头围 | `/baby` | [图](../04-baby/baby-journey-growth-curve-head/default.png) |
| [baby-journey-growth-curve-length](../04-baby/baby-journey-growth-curve-length/README.md) | Switch growth curve to 身长 | `/baby` | [图](../04-baby/baby-journey-growth-curve-length/default.png) |
| [baby-journey-growth-curve-weight](../04-baby/baby-journey-growth-curve-weight/README.md) | Switch growth curve to 体重 | `/baby` | [图](../04-baby/baby-journey-growth-curve-weight/default.png) |
| [baby-journey-growth-date-calendar](../04-baby/baby-journey-growth-date-calendar/README.md) | Measurement date → calendar picker | `/baby` | [图](../04-baby/baby-journey-growth-date-calendar/default.png) |
| [baby-journey-growth-date-input](../04-baby/baby-journey-growth-date-input/README.md) | Switch date picker to text input | `/baby` | [图](../04-baby/baby-journey-growth-date-input/default.png) |
| [baby-journey-growth-date-invalid](../04-baby/baby-journey-growth-date-invalid/README.md) | Confirm invalid date text → picker validation | `/baby` | [图](../04-baby/baby-journey-growth-date-invalid/default.png) |
| [baby-journey-growth-date-selected](../04-baby/baby-journey-growth-date-selected/README.md) | Choose previous measurement date → editor preserves all three values | `/baby` | [图](../04-baby/baby-journey-growth-date-selected/default.png) |
| [baby-journey-growth-empty-validation](../04-baby/baby-journey-growth-empty-validation/README.md) | Save without measurements → required validation | `/baby` | [图](../04-baby/baby-journey-growth-empty-validation/default.png) |
| [baby-journey-growth-empty](../04-baby/baby-journey-growth-empty/README.md) | Baby growth weight card → measurement editor | `/baby` | [图](../04-baby/baby-journey-growth-empty/default.png) |
| [baby-journey-growth-feedback-dismissed](../04-baby/baby-journey-growth-feedback-dismissed/README.md) | Dismiss undo feedback → empty latest measurements | `/baby` | [图](../04-baby/baby-journey-growth-feedback-dismissed/default.png) |
| [baby-journey-growth-invalid-value](../04-baby/baby-journey-growth-invalid-value/README.md) | Save zero weight → measurement range validation | `/baby` | [图](../04-baby/baby-journey-growth-invalid-value/default.png) |
| [baby-journey-growth-profile-entry](../04-baby/baby-journey-growth-profile-entry/README.md) | Growth reference missing data → complete profile | `/baby` | [图](../04-baby/baby-journey-growth-profile-entry/default.png) |
| [baby-journey-growth-three-values](../04-baby/baby-journey-growth-three-values/README.md) | Fill weight, length and head circumference across measurement tabs | `/baby` | [图](../04-baby/baby-journey-growth-three-values/default.png) |
| [baby-journey-growth-undo-error](../04-baby/baby-journey-growth-undo-error/README.md) | Undo batch → API failure retains saved measurements and retry | `/baby` | [图](../04-baby/baby-journey-growth-undo-error/default.png) |
| [baby-journey-history-all-pages](../04-baby/baby-journey-history-all-pages/README.md) | Second page resolves → all 51 records and no load more button | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-all-pages/default.png) |
| [baby-journey-history-delete-error](../04-baby/baby-journey-history-delete-error/README.md) | Confirm deletion → service unavailable, record remains | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-delete-error/default.png) |
| [baby-journey-history-delete-retry](../04-baby/baby-journey-history-delete-retry/README.md) | Retry unconfirmed deletion → deleted record and undo | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-delete-retry/default.png) |
| [baby-journey-history-deleted](../04-baby/baby-journey-history-deleted/README.md) | Confirm deletion → empty list with undo | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-deleted/default.png) |
| [baby-journey-history-development-empty](../04-baby/baby-journey-history-development-empty/README.md) | Tap 发育观察 filter → empty category | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-development-empty/default.png) |
| [baby-journey-history-diaper-empty](../04-baby/baby-journey-history-diaper-empty/README.md) | Tap 尿便 filter → empty category | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-diaper-empty/default.png) |
| [baby-journey-history-edit](../04-baby/baby-journey-history-edit/README.md) | History → Edit saved feeding | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-edit/default.png) |
| [baby-journey-history-edited](../04-baby/baby-journey-history-edited/README.md) | Save edited volume → list and saved Snackbar | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-edited/default.png) |
| [baby-journey-history-feeding](../04-baby/baby-journey-history-feeding/README.md) | Saved home → View all records | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-feeding/default.png) |
| [baby-journey-history-first-page](../04-baby/baby-journey-history-first-page/README.md) | Baby → monthly feeding history with 51 records, first 50 loaded | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-first-page/default.png) |
| [baby-journey-history-formula](../04-baby/baby-journey-history-formula/README.md) | Baby → all records with existing formula record | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-formula/default.png) |
| [baby-journey-history-growth-empty](../04-baby/baby-journey-history-growth-empty/README.md) | Tap 生长 filter → empty category | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-growth-empty/default.png) |
| [baby-journey-history-month-picker](../04-baby/baby-journey-history-month-picker/README.md) | Tap month → date picker | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-month-picker/default.png) |
| [baby-journey-history-more-error](../04-baby/baby-journey-history-more-error/README.md) | Load more → page failure keeps first page visible | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-more-error/default.png) |
| [baby-journey-history-more-loading](../04-baby/baby-journey-history-more-loading/README.md) | Retry page load while response pending | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-more-loading/default.png) |
| [baby-journey-history-previous-month](../04-baby/baby-journey-history-previous-month/README.md) | Previous month → August | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-previous-month/default.png) |
| [baby-journey-history-privacy](../04-baby/baby-journey-history-privacy/README.md) | Record data source → Privacy and authorization with no service | `/privacy` | [图](../04-baby/baby-journey-history-privacy/default.png) |
| [baby-journey-history-restore-error](../04-baby/baby-journey-history-restore-error/README.md) | Undo deletion → service unavailable, restore retry state | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-restore-error/default.png) |
| [baby-journey-history-restore-retry](../04-baby/baby-journey-history-restore-retry/README.md) | Retry restore → original formula record returns | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-restore-retry/default.png) |
| [baby-journey-history-restored](../04-baby/baby-journey-history-restored/README.md) | Undo deletion → restored record | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-restored/default.png) |
| [baby-journey-history-sleep-empty](../04-baby/baby-journey-history-sleep-empty/README.md) | Tap 睡眠 filter → empty category | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-sleep-empty/default.png) |
| [baby-journey-history-source-expanded](../04-baby/baby-journey-history-source-expanded/README.md) | Expand data source and privacy explanation | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-history-source-expanded/default.png) |
| [baby-journey-home-save-undone](../04-baby/baby-journey-home-save-undone/README.md) | Undo from save feedback → record removed | `/baby` | [图](../04-baby/baby-journey-home-save-undone/default.png) |
| [baby-journey-knowledge-detail](../04-baby/baby-journey-knowledge-detail/README.md) | Tap knowledge card → full educational article | `/baby` | [图](../04-baby/baby-journey-knowledge-detail/default.png) |
| [baby-journey-no-profile](../04-baby/baby-journey-no-profile/README.md) | More → Baby with no owned profile | `/baby` | [图](../04-baby/baby-journey-no-profile/default.png) |
| [baby-journey-nursing-saved](../04-baby/baby-journey-nursing-saved/README.md) | Server acknowledges nursing → home and saved feedback | `/baby` | [图](../04-baby/baby-journey-nursing-saved/default.png) |
| [baby-journey-privacy-return-history](../04-baby/baby-journey-privacy-return-history/README.md) | Privacy Back → same baby record history | `/babies/inventory-baby/records` | [图](../04-baby/baby-journey-privacy-return-history/default.png) |
| [baby-journey-profile-change-discarded](../04-baby/baby-journey-profile-change-discarded/README.md) | Discard feeding-mode change → saved profile remains unchanged | `/baby` | [图](../04-baby/baby-journey-profile-change-discarded/default.png) |
| [baby-journey-profile-discard-confirm](../04-baby/baby-journey-profile-discard-confirm/README.md) | Edit name then close → discard confirmation | `/baby` | [图](../04-baby/baby-journey-profile-discard-confirm/default.png) |
| [baby-journey-profile-draft-preserved](../04-baby/baby-journey-profile-draft-preserved/README.md) | Continue editing → draft name preserved | `/baby` | [图](../04-baby/baby-journey-profile-draft-preserved/default.png) |
| [baby-journey-profile-existing](../04-baby/baby-journey-profile-existing/README.md) | Switcher → edit current profile | `/baby` | [图](../04-baby/baby-journey-profile-existing/default.png) |
| [baby-journey-profile-new-validation](../04-baby/baby-journey-profile-new-validation/README.md) | Save without baby name → required validation | `/baby` | [图](../04-baby/baby-journey-profile-new-validation/default.png) |
| [baby-journey-profile-new](../04-baby/baby-journey-profile-new/README.md) | Switcher → add baby | `/baby` | [图](../04-baby/baby-journey-profile-new/default.png) |
| [baby-journey-profile-saved](../04-baby/baby-journey-profile-saved/README.md) | Save profile → updated home identity | `/baby` | [图](../04-baby/baby-journey-profile-saved/default.png) |
| [baby-journey-record-discard](../04-baby/baby-journey-record-discard/README.md) | Close dirty record → discard confirmation | `/baby` | [图](../04-baby/baby-journey-record-discard/default.png) |
| [baby-journey-record-discarded](../04-baby/baby-journey-record-discarded/README.md) | Confirm leave → no saved records | `/baby` | [图](../04-baby/baby-journey-record-discarded/default.png) |
| [baby-journey-record-read-error](../04-baby/baby-journey-record-read-error/README.md) | More → Baby; record API fails, profile remains usable | `/baby` | [图](../04-baby/baby-journey-record-read-error/default.png) |
| [baby-journey-record-read-recovered](../04-baby/baby-journey-record-read-recovered/README.md) | Pull to refresh → independently loaded empty records | `/baby` | [图](../04-baby/baby-journey-record-read-recovered/default.png) |
| [baby-journey-record-saving](../04-baby/baby-journey-record-saving/README.md) | Submit feeding while response pending → disabled save controls | `/baby` | [图](../04-baby/baby-journey-record-saving/default.png) |
| [baby-journey-records-loaded](../04-baby/baby-journey-records-loaded/README.md) | Pending records resolve → empty cards and growth curve | `/baby` | [图](../04-baby/baby-journey-records-loaded/default.png) |
| [baby-journey-records-loading](../04-baby/baby-journey-records-loading/README.md) | Baby entered; profile ready while records requests are pending | `/baby` | [图](../04-baby/baby-journey-records-loading/default.png) |
| [baby-journey-returned-home](../04-baby/baby-journey-returned-home/README.md) | History Back → Baby with refreshed 100 ml record | `/baby` | [图](../04-baby/baby-journey-returned-home/default.png) |
| [baby-journey-sleep-active-editor](../04-baby/baby-journey-sleep-active-editor/README.md) | Tap active sleep → record wake time action | `/baby` | [图](../04-baby/baby-journey-sleep-active-editor/default.png) |
| [baby-journey-sleep-adjust](../04-baby/baby-journey-sleep-adjust/README.md) | Expand active sleep time and note controls | `/baby` | [图](../04-baby/baby-journey-sleep-adjust/default.png) |
| [baby-journey-sleep-ended](../04-baby/baby-journey-sleep-ended/README.md) | Save wake time → completed sleep and home refresh | `/baby` | [图](../04-baby/baby-journey-sleep-ended/default.png) |
| [baby-journey-sleep-note](../04-baby/baby-journey-sleep-note/README.md) | Expand note and enter observation | `/baby` | [图](../04-baby/baby-journey-sleep-note/default.png) |
| [baby-journey-sleep-start-editor](../04-baby/baby-journey-sleep-start-editor/README.md) | Tap sleep summary → new active sleep editor | `/baby` | [图](../04-baby/baby-journey-sleep-start-editor/default.png) |
| [baby-journey-sleep-started](../04-baby/baby-journey-sleep-started/README.md) | Start sleep → active sleep stored and home feedback | `/baby` | [图](../04-baby/baby-journey-sleep-started/default.png) |
| [baby-journey-stool-blood](../04-baby/baby-journey-stool-blood/README.md) | Select observed blood sign | `/baby` | [图](../04-baby/baby-journey-stool-blood/default.png) |
| [baby-journey-stool-red](../04-baby/baby-journey-stool-red/README.md) | Choose red stool color → recorded color and guidance | `/baby` | [图](../04-baby/baby-journey-stool-red/default.png) |
| [baby-journey-stool-tab](../04-baby/baby-journey-stool-tab/README.md) | Within status editor → stool tab | `/baby` | [图](../04-baby/baby-journey-stool-tab/default.png) |
| [baby-journey-switched-leo](../04-baby/baby-journey-switched-leo/README.md) | Choose Leo → second profile and independently empty records | `/baby` | [图](../04-baby/baby-journey-switched-leo/default.png) |
| [baby-journey-switcher](../04-baby/baby-journey-switcher/README.md) | Tap baby name → two-profile switcher | `/baby` | [图](../04-baby/baby-journey-switcher/default.png) |
| [baby-journey-wet-tab](../04-baby/baby-journey-wet-tab/README.md) | Within status editor → wet diaper tab | `/baby` | [图](../04-baby/baby-journey-wet-tab/default.png) |
