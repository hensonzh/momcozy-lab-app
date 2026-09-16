# Baby 发育观察：单项/两项创建与逐类删除恢复

通过正式用户 App 的 More → Baby → 记录发育观察 → 保存 → 查看全部记录 → 发育观察继续操作。三种单项和三种两项组合分别运行 393 px / 1x、320 px / 2x，共 12 条独立路径。每条路径重建隔离 HTTP 数据与会话，真实用户记录不受影响；没有绕过 UI 修改 Controller 草稿。

## 已执行操作

- 三项行为分别为看向靠近的脸（观察到）、听到声音后有动作或表情反应（暂未观察到）、俯卧时短暂抬起头（不确定）。每种单项和三种两项组合实际逐项点击，选择结果保留前项；保存后断言记录数量、item_id 和 status 均与所选集合一致。
- 首页成功反馈没有“撤销”入口，这与当前生产实现对发育观察禁用首页撤销一致。随后实际点击查看全部记录与发育观察分类，核对每条行为和状态。没有创建虚构的首页撤销按钮截图。
- 三条单项路径分别点击删除，确认框带该行为、状态和宝宝名称。点击“保留”后原 id、version=1 不变，再次删除并确认后记录为空、删除版本为 2，列表显示“本月还没有发育观察记录”和“撤销删除”。
- 实际点击撤销删除，恢复原 id、version=3，没有重复创建。再次点编辑，确认原行为和状态回显；不修改直接关闭，返回历史再返回 Baby 和 More。
- 两项路径验证保存及两张历史卡片，不将三种单项删除成功扩大为多记录交错删除/恢复已覆盖。

测试数据写入仅发生在内存 HTTP fixture；不代表生产服务端事务、权限或并发行为已经验证。

## 截图与视觉核验

57 个状态、114 个尺寸/字号变体、54 张完整长图，18 个状态以长图为主图。168 张源 PNG 全宽连续拆分为 435 段；91 个唯一片段中，50 个新片段组成 9 页，全部查看，另 41 个与已审阅旧片段逐像素一致。[来源映射](baby-development-management-visual-review/sources.json) 与 [证据审计](baby-development-management-evidence-audit.json) 保存连续全高、源哈希和审阅页像素核对。

- 大字删除确认框按记录长度增高，标题和最长行为名换行；“保留”“删除”均可见，没有文字溢出。确认内容准确区分三类行为和状态。
- 空历史仍展示删除反馈、撤销动作、去记录及数据来源；大字长图完整保留它们，未把空记录误显示为零次行为。
- 两项历史中第二张卡片可能超出当前窗口，完整长图包含两条记录、各自编辑/删除、添加记录和数据来源。长行为名在大字号下多行显示。
- 恢复后编辑弹窗只显示原行为，不重新展示其他两组；大字纵向排列全部选项，长图保留说明、日期及唯一保存按钮。
- 返回或重新加载后大字横向分类栏可能回到左侧，发育观察标签不总在当前可见范围；记录仍属于发育观察。路径与选中状态由运行断言确认，不把“喂养”字样视为切换成功。

## 状态与入口索引

| 实际动作 | 截图、长图与前驱 |
| --- | --- |
| Delete face → record-specific confirmation | [运行证据](../04-baby/baby-development-management-face-delete-confirm/README.md) |
| Keep → original face record unchanged | [运行证据](../04-baby/baby-development-management-face-delete-kept/README.md) |
| Confirm delete → empty development history and undo action | [运行证据](../04-baby/baby-development-management-face-deleted/README.md) |
| History development tab → face-head records with each saved status | [运行证据](../04-baby/baby-development-management-face-head-history/README.md) |
| More → Baby before face-head observation management | [运行证据](../04-baby/baby-development-management-face-head-home-entry/README.md) |
| History Back → Baby after face-head management | [运行证据](../04-baby/baby-development-management-face-head-home-return/README.md) |
| Baby → More after face-head management | [运行证据](../04-baby/baby-development-management-face-head-more-return/README.md) |
| Save face-head → 2 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-face-head-saved/README.md) |
| Choose 不确定 for 俯卧时短暂抬起头; retain previous choices | [运行证据](../04-baby/baby-development-management-face-head-selected-lifts-head/README.md) |
| Choose 观察到 for 看向靠近的脸; retain previous choices | [运行证据](../04-baby/baby-development-management-face-head-selected-looks-at-face/README.md) |
| History development tab → face records with each saved status | [运行证据](../04-baby/baby-development-management-face-history/README.md) |
| More → Baby before face observation management | [运行证据](../04-baby/baby-development-management-face-home-entry/README.md) |
| History Back → Baby after face management | [运行证据](../04-baby/baby-development-management-face-home-return/README.md) |
| Baby → More after face management | [运行证据](../04-baby/baby-development-management-face-more-return/README.md) |
| Undo delete → same face record restored with version 3 | [运行证据](../04-baby/baby-development-management-face-restored/README.md) |
| Edit restored face → original behavior and status preserved | [运行证据](../04-baby/baby-development-management-face-restored-edit/README.md) |
| Close unchanged restored record → history without discard prompt | [运行证据](../04-baby/baby-development-management-face-restored-edit-closed/README.md) |
| Save face → 1 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-face-saved/README.md) |
| Choose 观察到 for 看向靠近的脸; retain previous choices | [运行证据](../04-baby/baby-development-management-face-selected-looks-at-face/README.md) |
| History development tab → face-sound records with each saved status | [运行证据](../04-baby/baby-development-management-face-sound-history/README.md) |
| More → Baby before face-sound observation management | [运行证据](../04-baby/baby-development-management-face-sound-home-entry/README.md) |
| History Back → Baby after face-sound management | [运行证据](../04-baby/baby-development-management-face-sound-home-return/README.md) |
| Baby → More after face-sound management | [运行证据](../04-baby/baby-development-management-face-sound-more-return/README.md) |
| Save face-sound → 2 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-face-sound-saved/README.md) |
| Choose 观察到 for 看向靠近的脸; retain previous choices | [运行证据](../04-baby/baby-development-management-face-sound-selected-looks-at-face/README.md) |
| Choose 暂未观察到 for 听到声音后有动作或表情反应; retain previous choices | [运行证据](../04-baby/baby-development-management-face-sound-selected-responds-to-sound/README.md) |
| Delete head → record-specific confirmation | [运行证据](../04-baby/baby-development-management-head-delete-confirm/README.md) |
| Keep → original head record unchanged | [运行证据](../04-baby/baby-development-management-head-delete-kept/README.md) |
| Confirm delete → empty development history and undo action | [运行证据](../04-baby/baby-development-management-head-deleted/README.md) |
| History development tab → head records with each saved status | [运行证据](../04-baby/baby-development-management-head-history/README.md) |
| More → Baby before head observation management | [运行证据](../04-baby/baby-development-management-head-home-entry/README.md) |
| History Back → Baby after head management | [运行证据](../04-baby/baby-development-management-head-home-return/README.md) |
| Baby → More after head management | [运行证据](../04-baby/baby-development-management-head-more-return/README.md) |
| Undo delete → same head record restored with version 3 | [运行证据](../04-baby/baby-development-management-head-restored/README.md) |
| Edit restored head → original behavior and status preserved | [运行证据](../04-baby/baby-development-management-head-restored-edit/README.md) |
| Close unchanged restored record → history without discard prompt | [运行证据](../04-baby/baby-development-management-head-restored-edit-closed/README.md) |
| Save head → 1 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-head-saved/README.md) |
| Choose 不确定 for 俯卧时短暂抬起头; retain previous choices | [运行证据](../04-baby/baby-development-management-head-selected-lifts-head/README.md) |
| Delete sound → record-specific confirmation | [运行证据](../04-baby/baby-development-management-sound-delete-confirm/README.md) |
| Keep → original sound record unchanged | [运行证据](../04-baby/baby-development-management-sound-delete-kept/README.md) |
| Confirm delete → empty development history and undo action | [运行证据](../04-baby/baby-development-management-sound-deleted/README.md) |
| History development tab → sound-head records with each saved status | [运行证据](../04-baby/baby-development-management-sound-head-history/README.md) |
| More → Baby before sound-head observation management | [运行证据](../04-baby/baby-development-management-sound-head-home-entry/README.md) |
| History Back → Baby after sound-head management | [运行证据](../04-baby/baby-development-management-sound-head-home-return/README.md) |
| Baby → More after sound-head management | [运行证据](../04-baby/baby-development-management-sound-head-more-return/README.md) |
| Save sound-head → 2 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-sound-head-saved/README.md) |
| Choose 不确定 for 俯卧时短暂抬起头; retain previous choices | [运行证据](../04-baby/baby-development-management-sound-head-selected-lifts-head/README.md) |
| Choose 暂未观察到 for 听到声音后有动作或表情反应; retain previous choices | [运行证据](../04-baby/baby-development-management-sound-head-selected-responds-to-sound/README.md) |
| History development tab → sound records with each saved status | [运行证据](../04-baby/baby-development-management-sound-history/README.md) |
| More → Baby before sound observation management | [运行证据](../04-baby/baby-development-management-sound-home-entry/README.md) |
| History Back → Baby after sound management | [运行证据](../04-baby/baby-development-management-sound-home-return/README.md) |
| Baby → More after sound management | [运行证据](../04-baby/baby-development-management-sound-more-return/README.md) |
| Undo delete → same sound record restored with version 3 | [运行证据](../04-baby/baby-development-management-sound-restored/README.md) |
| Edit restored sound → original behavior and status preserved | [运行证据](../04-baby/baby-development-management-sound-restored-edit/README.md) |
| Close unchanged restored record → history without discard prompt | [运行证据](../04-baby/baby-development-management-sound-restored-edit-closed/README.md) |
| Save sound → 1 observations, homepage feedback without undo | [运行证据](../04-baby/baby-development-management-sound-saved/README.md) |
| Choose 暂未观察到 for 听到声音后有动作或表情反应; retain previous choices | [运行证据](../04-baby/baby-development-management-sound-selected-responds-to-sound/README.md) |

## 验证与后续

- [严格采集](runs/20260913T230052-targeted/capture.log)：12 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-development-management-analyze.log)：No issues found，退出码 0。未修改产品代码。
- 三项全部一起保存和逐项状态编辑见 [控件报告](BABY-DEVELOPMENT-CONTROLS.md)；日期及未确认返回见 [日期边界](BABY-DEVELOPMENT-BOUNDARIES.md)。
- 剩余：年份/日期格/缺失出生日期、权限与版本冲突、多记录交错删除/恢复、删除及恢复失败/挂起、离页后的撤销生命周期、服务器已写入但响应丢失和原生系统层。

全 App 盘点仍未完成。本批测试和资产校验通过仅证明所列路径与截图。

[最终完整性检查](baby-development-management-final-verify.log) 通过：2028 个条目、3812 份视口元数据、1818 份长图范围，goal_completion=NOT_PROVEN。新增测试只读格式检查 0 changed。


后续已补 [删除与恢复错误、挂起及离页重入](BABY-DEVELOPMENT-RECOVERY.md)，原批次剩余项以 Baby 控件清单当前条目为准。
