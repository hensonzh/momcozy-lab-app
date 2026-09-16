# 宝宝资料冲突、重新载入与保存恢复

More → Baby → 当前资料编辑器的实际操作链。393 px / 1x 与 320 px / 2x 均运行正式 MomCozyFlutterApp、GoRouter、生产 Repository / codec。隔离 HTTP fixture 检查 expected_version，模拟另一客户端修改、403 / 503 和请求等待；未改动真实账号。

## 实际动作及结果

1. 输入本地姓名，模拟服务端从版本 1 更新为版本 2。点击保存，旧版本被拒绝，界面保留本地草稿并显示冲突及重新载入入口。
2. 点击重新载入，挂起资料响应，捕获忙碌状态。返回 503 后保留本地姓名，恢复编辑，但重新载入入口消失。
3. 再次保存旧版本，冲突提示恢复；点击重新载入成功，姓名、喂养方式和版本更新为服务端值，TextField 也回显最新姓名。
4. 编辑姓名后保存返回 403，显示当前账号没有访问权限；关闭、确认离开，首页重新读取服务端资料，拒绝的草稿没有保存。
5. 再编辑并保存返回 503，进入结果未确认状态。关闭、确认离开、重开，显示实际已保存版本 2，而非未确认的本地姓名。
6. 再次编辑并保存，响应挂起。点击禁用的关闭按钮并派发 Flutter 平台返回，编辑器保持且没有新增写请求。响应确认后自动关闭、首页刷新为版本 3；重开核对姓名，再关闭并返回 More。

保存中拦截返回的两个观察点可呈现相同画面，保留它们用于证明返回未绕过忙碌保护，不把它们当作两种不同视觉设计。

## 状态索引

| 操作 | 截图、完整长图及前驱 |
| --- | --- |
| Tap disabled close then platform back → saving editor stays open | [运行证据](../04-baby/baby-profile-recovery-busy-close-blocked/README.md) |
| Save stale version → conflict, retain local draft and offer reload | [运行证据](../04-baby/baby-profile-recovery-conflict/README.md) |
| Save stale draft again → conflict restores reload action | [运行证据](../04-baby/baby-profile-recovery-conflict-again/README.md) |
| Close rejected draft → discard confirmation | [运行证据](../04-baby/baby-profile-recovery-forbidden-discard-confirm/README.md) |
| Confirm leave → refreshed home shows server profile | [运行证据](../04-baby/baby-profile-recovery-forbidden-discarded/README.md) |
| More → Baby before profile recovery | [运行证据](../04-baby/baby-profile-recovery-home-entry/README.md) |
| Edit name locally; server version remains 1 | [运行证据](../04-baby/baby-profile-recovery-local-draft/README.md) |
| Close unchanged editor → More | [运行证据](../04-baby/baby-profile-recovery-more-return/README.md) |
| Reload succeeds → latest server name and feeding mode replace draft | [运行证据](../04-baby/baby-profile-recovery-reload-current/README.md) |
| Click reload while profile response pending → controls disabled | [运行证据](../04-baby/baby-profile-recovery-reload-pending/README.md) |
| Reload fails 503 → preserved local draft; reload action disappears | [运行证据](../04-baby/baby-profile-recovery-reload-unavailable/README.md) |
| Save returns 403 → access error, editable draft and no server update | [运行证据](../04-baby/baby-profile-recovery-save-forbidden/README.md) |
| Save response pending → disabled save, fields and close | [运行证据](../04-baby/baby-profile-recovery-save-pending/README.md) |
| Response acknowledged → refreshed home with version 3 | [运行证据](../04-baby/baby-profile-recovery-saved/README.md) |
| Reopen saved profile → confirmed name persisted | [运行证据](../04-baby/baby-profile-recovery-saved-reopened/README.md) |
| Save returns 503 → pending result and locked draft | [运行证据](../04-baby/baby-profile-recovery-unconfirmed/README.md) |
| Close pending save → uncertain-result warning | [运行证据](../04-baby/baby-profile-recovery-unconfirmed-leave-dialog/README.md) |
| Confirm leave → home refreshes unchanged server profile | [运行证据](../04-baby/baby-profile-recovery-unconfirmed-left/README.md) |
| Reopen → persisted profile, no unconfirmed local draft | [运行证据](../04-baby/baby-profile-recovery-unconfirmed-reopened/README.md) |

## 视觉与交互发现

- 冲突后的重新载入失败会移除重新载入按钮，用户需再次尝试保存、重新出现冲突后才能再载入；当前路径可恢复，但操作绕行且没有直接提示。
- 重新载入与保存共用 busy，读取等待中的底部按钮写“正在保存…”。这属于文案与实际动作不符，盘点如实保留。
- 重新载入成功后输入框和喂养方式为服务端新值，但本次打开的页头仍显示原姓名，直到关闭重开才更新。
- 大字号页头占三行，禁用关闭图标与深色背景对比度很低；完整长图保留所有字段与底部动作。较长姓名的单行输入自动滚至尾部，左侧字符有裁切；名称横向滚动边界仍需专门补验。
- 403 与未确认保存采用不同的离开提示，继续填写/离开均完整可见；已购或真实记录等无关数据未人为生成。

## 证据验证

19 个状态、38 个视口变体、25 张完整长图，9 个状态以长图为主图。63 张原图连续全宽分为 151 段，110 个唯一片段；80 个新片段组成 14 页，全部已查看，30 个复用此前已审阅的相同像素。原图 SHA、每张原图从顶部到底部的连续分段及审阅页像素全部校验，见 [来源](baby-profile-recovery-visual-review/sources.json) 和 [审计](baby-profile-recovery-evidence-audit.json)。

- [最终严格采集](runs/20260913T205832-targeted/capture.log)：2 项通过、0 失败，未更新 Golden 基线；[命令](runs/20260913T205832-targeted/capture-command.json) 与 [退出码](runs/20260913T205832-targeted/capture-result.json) 留存。
- [全仓静态检查](baby-profile-recovery-analyze.log)：No issues found。新增测试只读格式检查 0 changed。
- 新增 `test/modules/baby/baby_profile_recovery_inventory_test.dart`；没有修改生产 UI 或通用采集器。fixture 首次构造使用了错误的喂养 wire 值，按现有 codec 改为 formula_feeding 后全部通过，没有放宽生产解析。

本批是运行中 Flutter UI 的实际点击与平台返回测试，没有执行实体设备或系统输入法。[名称边界、资料移除和日历导航](BABY-PROFILE-BOUNDARIES.md) 已后续补验；CDC 外部来源和其他 Baby 记录分支仍见 [控件清单](BABY-CONTROL-COVERAGE.md)。[整体目标](AUDIT.md) 继续未完成。
