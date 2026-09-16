# Mom 正常入口链补验

使用实际 MomCozyFlutterApp、GoRouter、生产 Repository 与 DTO/codec。入口固定为已登录 More → 底部 Me；仅 HTTP、会话存储和原生依赖使用隔离测试实现，不向真实账号写健康记录或购买数据。每张截图记录实际顶层路由、前驱截图、点击动作和测试路径。

## 已运行的 10 条流程

1. 首页 → 新增泵奶 → 数值校验 → 保存失败/重试 → 历史编辑 → 删除 → 恢复失败/重试 → 返回首页。
2. 身体/休息/心情快捷记录 → 空提交校验 → 放弃确认/保留 → 保存失败/成功 → 独立日记详情三 Tab → 修改保存 → 返回。
3. AI 卡 → Cozymate 上下文预填（断言未发送）→ Me → 服务目录 → 返回。
4. 亲喂 → 时长校验 → 可选感受/备注 → 时间表盘/键盘/校验 → 取消与保留 → 保存中/完成 → 放弃另一条新记录。
5. 身体不适 → 程度/影响 → 如厕与盆底 → 备注 → 休息可选项 → 多选压力/排他选项 → 放弃草稿 → 首页心情预填。
6. 含缺失日期的历史泵奶数据 → 7 天/30 天/7 天趋势切换 → 返回今日统计。
7. 日记版本冲突 → 重新载入确认 → 保留草稿 → 确认放弃 → 重新填写 → 保存中/成功 → 首页刷新。
8. 泌乳版本冲突 → 放弃重载 → 删除失败 → 新增保存结果不确定 → 关闭警告 → 保留并重试保存 → 返回。
9. 已购但未记录首页 → 服务进度 → 返回 → 预约前确认 → 关闭 → 预约页 → 返回首页。
10. 首屏加载 → 初始数据 → 局部日记读取失败/重试 → 泌乳历史读取失败/重试 → 日记读取失败/重试。

共 **85 个运行状态、61 张主长图**。索引包含进入、动作、返回关系；预约前确认后的提交、咨询、续购完整流程仍待专家服务专项补齐，不能用此入口验证替代。

## 验证证据与采集修正

- 最终全量严格采集：71 个文件，930 通过、6 个既有跳过，0 失败（约 49 秒）。命令和结果位于 [capture-command.json](capture-command.json)、[capture.log](capture.log)、[capture-result.json](capture-result.json)。未通过截图不会登记；正常金图建立与严格证据采集分开执行。
- 全仓静态检查 No issues found；3 个本轮 Dart 文件格式检查 0 changed。[mom-journey-analyze.log](mom-journey-analyze.log) 保存静态检查；Python 采集、索引、验证脚本已语法检查。
- 本次补全时间 Picker 取消按钮的作用域，按实际日记确认按钮“放弃修改”点击；没有为测试修改产品按钮。
- 先解码泌乳 hero 图片，避免首次保存后的正常截图误记录为图片未加载。
- 长图改用重叠区域内侧拼接，移除中段重复出现的弹窗底部圆角。另修复流式聊天已排队的自动滚动夺走采集起点的问题；每次滚动后确认实际位置，无法稳定则明确标记待审。
- 完整性验证新增所有变体长图的起始偏移、单调偏移、内容高度与最终图片尺寸检查。这仍不能证明所有入口已覆盖。

## 视觉复核

85 个窗口截图的汇总图及源哈希保存在 [mom-visual-review/sources.json](mom-visual-review/sources.json)。已查看本轮全部窗口汇总，重点单独查看：AI 预填、可选身体备注长图、休息展开长图、泌乳保存/恢复长图、已购首页长图、服务目录全长图、30 天趋势、日记保存中，以及修正后的 Agent 流式大字长图。

实际产品观察：30 天趋势最后一个日期与“今日”标签距离过近；大字号 Agent 底部导航存在较多换行。当前任务保留真实截图并记录，不把这些问题从证据中消除。固定于屏幕的渐变背景在长图接缝处可能发生色带变化，长图展示实际滚动窗口，不重绘背景。

本轮未声称 216 张主长图全部逐张审完。仍需逐模块核对其他入口、按钮分支、OS 权限和未观察代码。妈妈模块后续需要补充资料读错/权限变更、更多记录字段改变、有效时间修改确认、服务状态变化及预约后入口。

## 逐状态索引

| 状态 | 实际路由 | 用户动作 | 截图 |
| --- | --- | --- | --- |
| ai-context-draft | `/` | Home AI card → Cozymate with prefilled prompt, not sent | [页面与证据](../03-mom/mom-journey-ai-context-draft/README.md) |
| body-discomfort-expanded | `/me` | Select discomfort site → severity and impact questions appear | [页面与证据](../03-mom/mom-journey-body-discomfort-expanded/README.md) |
| body-note | `/me` | Enter optional body note | [页面与证据](../03-mom/mom-journey-body-note/README.md) |
| body-optional-expanded | `/me` | Expand optional toilet and pelvic floor questions | [页面与证据](../03-mom/mom-journey-body-optional-expanded/README.md) |
| diary-body-empty | `/me` | Home body card → quick body record | [页面与证据](../03-mom/mom-journey-diary-body-empty/README.md) |
| diary-conflict | `/me` | Save returns version conflict → draft preserved | [页面与证据](../03-mom/mom-journey-diary-conflict/README.md) |
| diary-conflict-reload-confirm | `/me` | Reload conflicting diary → explicit discard confirmation | [页面与证据](../03-mom/mom-journey-diary-conflict-reload-confirm/README.md) |
| diary-conflict-reloaded | `/me` | Confirm discard → reload latest empty diary | [页面与证据](../03-mom/mom-journey-diary-conflict-reloaded/README.md) |
| diary-conflict-resolved | `/me` | Save response → persisted diary feedback | [页面与证据](../03-mom/mom-journey-diary-conflict-resolved/README.md) |
| diary-conflict-retained | `/me` | Keep draft after conflict → conflict and entered fields remain | [页面与证据](../03-mom/mom-journey-diary-conflict-retained/README.md) |
| diary-conflict-return-home | `/me` | Close saved diary → body state refreshed on home | [页面与证据](../03-mom/mom-journey-diary-conflict-return-home/README.md) |
| diary-detail-body | `/me/diary` | Standalone diary → Body tab | [页面与证据](../03-mom/mom-journey-diary-detail-body/README.md) |
| diary-detail-mood | `/me/diary` | Standalone diary → Mood tab | [页面与证据](../03-mom/mom-journey-diary-detail-mood/README.md) |
| diary-detail-rest | `/me/diary` | Completed daily status → standalone diary detail | [页面与证据](../03-mom/mom-journey-diary-detail-rest/README.md) |
| diary-detail-updated | `/me/diary` | Save changed mood → updated standalone diary | [页面与证据](../03-mom/mom-journey-diary-detail-updated/README.md) |
| diary-discard-confirm | `/me` | Close unsaved three-section diary → discard confirmation | [页面与证据](../03-mom/mom-journey-diary-discard-confirm/README.md) |
| diary-discarded-home | `/me` | Confirm discard → home remains unrecorded | [页面与证据](../03-mom/mom-journey-diary-discarded-home/README.md) |
| diary-draft-retained | `/me` | Continue editing → selected mood and other draft sections remain | [页面与证据](../03-mom/mom-journey-diary-draft-retained/README.md) |
| diary-empty-validation | `/me` | Save empty diary → validation | [页面与证据](../03-mom/mom-journey-diary-empty-validation/README.md) |
| diary-home-complete | `/me` | Close editor → all three home status groups completed | [页面与证据](../03-mom/mom-journey-diary-home-complete/README.md) |
| diary-modal-saved | `/me` | Retry save → saved feedback in quick editor | [页面与证据](../03-mom/mom-journey-diary-modal-saved/README.md) |
| diary-mood-empty | `/me` | Quick diary → Mood tab | [页面与证据](../03-mom/mom-journey-diary-mood-empty/README.md) |
| diary-optional-discard-confirm | `/me` | Close optional diary draft → discard confirmation | [页面与证据](../03-mom/mom-journey-diary-optional-discard-confirm/README.md) |
| diary-read-error | `/me` | Open quick diary → independent diary load error | [页面与证据](../03-mom/mom-journey-diary-read-error/README.md) |
| diary-read-recovered | `/me` | Retry diary read → empty body form | [页面与证据](../03-mom/mom-journey-diary-read-recovered/README.md) |
| diary-rest-empty | `/me` | Quick diary → Rest tab | [页面与证据](../03-mom/mom-journey-diary-rest-empty/README.md) |
| diary-return-home | `/me` | Close standalone diary → home reloads changed mood | [页面与证据](../03-mom/mom-journey-diary-return-home/README.md) |
| diary-save-error | `/me` | Save diary → API error preserves entries | [页面与证据](../03-mom/mom-journey-diary-save-error/README.md) |
| diary-saving | `/me` | Submit replacement draft → controls disabled while pending | [页面与证据](../03-mom/mom-journey-diary-saving/README.md) |
| home-diary-partial-error | `/me` | Pull refresh → diary request fails while other modules remain available | [页面与证据](../03-mom/mom-journey-home-diary-partial-error/README.md) |
| home-loaded-empty | `/me` | All requests resolve → initial cards | [页面与证据](../03-mom/mom-journey-home-loaded-empty/README.md) |
| home-loading | `/me` | Me tab entered with homepage data requests pending | [页面与证据](../03-mom/mom-journey-home-loading/README.md) |
| home-partial-recovered | `/me` | Retry failed section → empty daily status restored | [页面与证据](../03-mom/mom-journey-home-partial-recovered/README.md) |
| initial-home | `/me` | More → Me with no diary or milk records | [页面与证据](../03-mom/mom-journey-initial-home/README.md) |
| milk-conflict | `/me/lactation` | Edit saved milk and receive conflict → draft preserved | [页面与证据](../03-mom/mom-journey-milk-conflict/README.md) |
| milk-conflict-reload-confirm | `/me/lactation` | Reload conflicted milk → discard confirmation | [页面与证据](../03-mom/mom-journey-milk-conflict-reload-confirm/README.md) |
| milk-conflict-reloaded | `/me/lactation` | Discard conflict draft → latest saved list | [页面与证据](../03-mom/mom-journey-milk-conflict-reloaded/README.md) |
| milk-delete-failed | `/me/lactation` | Delete rejected → record stays visible with error | [页面与证据](../03-mom/mom-journey-milk-delete-failed/README.md) |
| milk-filled | `/me` | Enter 80 ml and select right side | [页面与证据](../03-mom/mom-journey-milk-filled/README.md) |
| milk-history | `/me/lactation` | Home View records → standalone lactation history/trend | [页面与证据](../03-mom/mom-journey-milk-history/README.md) |
| milk-history-deleted | `/me/lactation` | Delete record directly → deletion feedback with undo | [页面与证据](../03-mom/mom-journey-milk-history-deleted/README.md) |
| milk-history-edit | `/me/lactation` | History edit → record editor | [页面与证据](../03-mom/mom-journey-milk-history-edit/README.md) |
| milk-history-empty | `/me/lactation` | Home View records → empty standalone lactation history | [页面与证据](../03-mom/mom-journey-milk-history-empty/README.md) |
| milk-history-read-error | `/me/lactation` | Enter standalone lactation page → records request error | [页面与证据](../03-mom/mom-journey-milk-history-read-error/README.md) |
| milk-history-read-recovered | `/me/lactation` | Retry standalone records → empty history | [页面与证据](../03-mom/mom-journey-milk-history-read-recovered/README.md) |
| milk-history-restored | `/me/lactation` | Retry undo → record restored | [页面与证据](../03-mom/mom-journey-milk-history-restored/README.md) |
| milk-history-updated | `/me/lactation` | Save changed volume → refreshed history and update feedback | [页面与证据](../03-mom/mom-journey-milk-history-updated/README.md) |
| milk-home-refreshed | `/me` | Close saved panel → home displays 80 ml | [页面与证据](../03-mom/mom-journey-milk-home-refreshed/README.md) |
| milk-invalid-volume | `/me` | Submit out of range pump volume → validation | [页面与证据](../03-mom/mom-journey-milk-invalid-volume/README.md) |
| milk-modal-saved | `/me` | Retry save → actual record list and saved feedback | [页面与证据](../03-mom/mom-journey-milk-modal-saved/README.md) |
| milk-new-pump | `/me` | Home record lactation → new pump editor | [页面与证据](../03-mom/mom-journey-milk-new-pump/README.md) |
| milk-restore-error | `/me/lactation` | Undo → API failure preserves undo entry | [页面与证据](../03-mom/mom-journey-milk-restore-error/README.md) |
| milk-return-home | `/me` | Close history → original home refreshes 95 ml | [页面与证据](../03-mom/mom-journey-milk-return-home/README.md) |
| milk-save-error | `/me` | Save → HTTP failure, draft locked pending retry | [页面与证据](../03-mom/mom-journey-milk-save-error/README.md) |
| milk-uncertain-leave-confirm | `/me/lactation` | Close uncertain record → reconciliation warning | [页面与证据](../03-mom/mom-journey-milk-uncertain-leave-confirm/README.md) |
| milk-uncertain-retried | `/me/lactation` | Retry same pending save → saved list | [页面与证据](../03-mom/mom-journey-milk-uncertain-retried/README.md) |
| milk-uncertain-return-home | `/me` | Return from reconciled save → updated home total | [页面与证据](../03-mom/mom-journey-milk-uncertain-return-home/README.md) |
| milk-uncertain-save | `/me/lactation` | Unavailable create response → uncertain result and retry controls | [页面与证据](../03-mom/mom-journey-milk-uncertain-save/README.md) |
| mood-exclusive-pressure | `/me` | Select unclear pressure → exclusive choice replaces selected sources | [页面与证据](../03-mom/mom-journey-mood-exclusive-pressure/README.md) |
| mood-multiple-pressures | `/me` | Mood tab → select two pressure sources | [页面与证据](../03-mom/mom-journey-mood-multiple-pressures/README.md) |
| mood-quick-prefilled | `/me` | Home quick mood → diary with mood preselected, no write yet | [页面与证据](../03-mom/mom-journey-mood-quick-prefilled/README.md) |
| nursing-cancel-confirm | `/me/lactation` | Cancel record → discard confirmation | [页面与证据](../03-mom/mom-journey-nursing-cancel-confirm/README.md) |
| nursing-cancel-retained | `/me/lactation` | Continue editing → all entered fields remain | [页面与证据](../03-mom/mom-journey-nursing-cancel-retained/README.md) |
| nursing-duration-invalid | `/me/lactation` | Submit duration over limit → validation | [页面与证据](../03-mom/mom-journey-nursing-duration-invalid/README.md) |
| nursing-empty | `/me/lactation` | History Add → switch to nursing form | [页面与证据](../03-mom/mom-journey-nursing-empty/README.md) |
| nursing-new-discarded | `/me/lactation` | Cancel another new record and discard → existing history unchanged | [页面与证据](../03-mom/mom-journey-nursing-new-discarded/README.md) |
| nursing-optional-filled | `/me/lactation` | Expand feeling and notes → enter optional observation | [页面与证据](../03-mom/mom-journey-nursing-optional-filled/README.md) |
| nursing-saved | `/me/lactation` | Response received → saved nursing history | [页面与证据](../03-mom/mom-journey-nursing-saved/README.md) |
| nursing-saving | `/me/lactation` | Submit nursing while response pending → saving state | [页面与证据](../03-mom/mom-journey-nursing-saving/README.md) |
| nursing-time-input | `/me/lactation` | Time picker → keyboard time entry | [页面与证据](../03-mom/mom-journey-nursing-time-input/README.md) |
| nursing-time-invalid | `/me/lactation` | Invalid hour → time picker error | [页面与证据](../03-mom/mom-journey-nursing-time-invalid/README.md) |
| nursing-time-picker | `/me/lactation` | Record time → time picker | [页面与证据](../03-mom/mom-journey-nursing-time-picker/README.md) |
| purchased-booking-cancel-precheck | `/services/episodes/inventory-episode/booking` | Cancel suitability check → booking page | [页面与证据](../03-mom/mom-journey-purchased-booking-cancel-precheck/README.md) |
| purchased-booking-precheck | `/services/episodes/inventory-episode/booking` | Book from home → actual booking route and suitability dialog | [页面与证据](../03-mom/mom-journey-purchased-booking-precheck/README.md) |
| purchased-booking-return | `/me` | Booking back → active plan unchanged | [页面与证据](../03-mom/mom-journey-purchased-booking-return/README.md) |
| purchased-home | `/me` | Me with active plan → both catalog entry and owned service card | [页面与证据](../03-mom/mom-journey-purchased-home/README.md) |
| purchased-progress | `/services/episodes/inventory-episode` | Owned plan → actual service timeline route | [页面与证据](../03-mom/mom-journey-purchased-progress/README.md) |
| purchased-progress-return | `/me` | Timeline back → owned plan on home | [页面与证据](../03-mom/mom-journey-purchased-progress-return/README.md) |
| rest-optional-expanded | `/me` | Rest tab → expand continuous rest, naps and interruption causes | [页面与证据](../03-mom/mom-journey-rest-optional-expanded/README.md) |
| service-catalog | `/services` | Home expert companionship entry → real service catalog | [页面与证据](../03-mom/mom-journey-service-catalog/README.md) |
| service-return-home | `/me` | Service catalog Back → Mom home | [页面与证据](../03-mom/mom-journey-service-return-home/README.md) |
| trend-return-home | `/me` | Close trend → today total independent of historical measurements | [页面与证据](../03-mom/mom-journey-trend-return-home/README.md) |
| trend-seven-days | `/me/lactation` | Home history → seven-day measured curve with gaps | [页面与证据](../03-mom/mom-journey-trend-seven-days/README.md) |
| trend-seven-days-return | `/me/lactation` | Return to 7 days → shorter curve | [页面与证据](../03-mom/mom-journey-trend-seven-days-return/README.md) |
| trend-thirty-days | `/me/lactation` | Select 30 days → expanded period and older measurements | [页面与证据](../03-mom/mom-journey-trend-thirty-days/README.md) |
