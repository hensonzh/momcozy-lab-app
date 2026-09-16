# Baby 发育观察历史：错误恢复、等待响应与撤销生命周期

More → Baby → 实际创建一条观察 → 查看全部记录 → 发育观察 → 删除/恢复错误与重试 → 离开并重新进入。393 px / 1x 与 320 px / 2x 均使用正式 App 路由、Repository、Controller 和页面。HTTP fixture 注入指定响应或挂起 Future；没有向真实账号写入记录。

## 实际操作结果

- 创建“看向靠近的脸 · 观察到”，确认保存为一条 version=1 的记录，再进入历史。
- 删除先后返回 403、409，原记录与版本不变，不出现“操作结果还未确认”提示，编辑按钮仍启用。403 显示访问权限错误及“重试”，409 显示记录更新提示及“重新载入”；实际点击后重读列表，不再次删除。
- 删除返回 503 后，原记录保留，显示未确认提示。编辑和上个月按钮的 onPressed 均为空。再点击重试并暂停响应，拍摄等待状态；放行后列表为空，删除回执 version=2。
- 撤销恢复依次返回 403、409，列表仍空，原删除回执和“撤销删除”入口保留。点击错误区域的重试/重新载入只重读空列表，不执行恢复。
- 再次撤销返回 503，进入恢复未确认状态。实际点击重试，暂停并放行响应，原 id 的记录恢复到 version=3，撤销回执消失。
- 再次删除后离开历史返回 Baby，再进入发育观察历史：记录仍为空，之前的“撤销删除”入口不再出现。撤销回执仅存在于先前页面 Controller 的生命周期中。

403/409 是 HTTP 结果注入，并未模拟另一个客户端实际更新版本；503 在服务端写入之前失败，也不证明“服务器已写入但响应丢失”的情况。测试只证明这些响应下当前 App 的界面和操作路径。

## 视觉检查及现有问题

22 个状态、44 个视口变体、21 张完整长图，3 个状态以长图为主图。65 张原图全宽连续拆成 146 段，其中 90 个唯一片段；53 个新片段组成 9 张审阅页，全部查看，37 个片段与此前已审阅图像逐像素一致。详见 [来源映射](baby-development-recovery-visual-review/sources.json) 和 [证据审计](baby-development-recovery-evidence-audit.json)。

- 403/409 后重读列表成功，原 mutationFailure 仍保留，错误提示继续显示。这是当前产品行为；页面允许继续编辑/删除。不能把仍显示错误的截图当成重新载入未被执行。
- 503 的确定动作与恢复动作使用同一“暂时无法载入”文案，随后有未确认解释。等待请求时错误框被清除，未确认文案保留；页面没有额外的旋转加载图标，主要通过禁用按钮表示等待。
- 删除未确认时记录仍在列表；恢复未确认时仍显示空态与删除反馈。大字长图完整保留错误、重试、未确认说明、记录/空态、去记录或添加记录及数据来源。
- 恢复未确认但未 busy 时，“撤销删除”仍显示为可用样式；本批选择错误框的“重试”恢复。等待响应时该入口变灰。本批未点击未确认状态下的重复撤销入口。
- 重新进入空历史的截图没有旧回执区域，仍提供去记录与数据来源。滚动窗口可能看不到标题，完整长图从顶部到页底均保留。

## 状态与路径

| 实际动作 | 截图、完整长图与前驱 |
| --- | --- |
| Delete returns HTTP 403 → error, record retained and other edits enabled | [运行证据](../04-baby/baby-development-recovery-delete-403/README.md) |
| Retry confirmed HTTP 403 failure → reload history without deleting | [运行证据](../04-baby/baby-development-recovery-delete-403-reload/README.md) |
| Delete returns HTTP 409 → error, record retained and other edits enabled | [运行证据](../04-baby/baby-development-recovery-delete-409/README.md) |
| Retry confirmed HTTP 409 failure → reload history without deleting | [运行证据](../04-baby/baby-development-recovery-delete-409-reload/README.md) |
| Retry deletion with response pending → controls stay locked | [运行证据](../04-baby/baby-development-recovery-delete-pending/README.md) |
| Delete fails 503 → unconfirmed mutation, record retained and month/edit locked | [运行证据](../04-baby/baby-development-recovery-delete-unconfirmed/README.md) |
| Delete acknowledged → empty list and undo | [运行证据](../04-baby/baby-development-recovery-deleted/README.md) |
| Delete restored record → version 4 receipt before leaving history | [运行证据](../04-baby/baby-development-recovery-deleted-before-leave/README.md) |
| Open development history with one saved behavior | [运行证据](../04-baby/baby-development-recovery-history/README.md) |
| Leave history after deletion → Baby | [运行证据](../04-baby/baby-development-recovery-home-after-delete/README.md) |
| More → Baby before history mutation recovery | [运行证据](../04-baby/baby-development-recovery-home-entry/README.md) |
| Return More after mutation recovery | [运行证据](../04-baby/baby-development-recovery-more-return/README.md) |
| Reenter development history → empty list without prior undo receipt | [运行证据](../04-baby/baby-development-recovery-reentered-empty/README.md) |
| Undo returns HTTP 403 → error and retained deletion receipt | [运行证据](../04-baby/baby-development-recovery-restore-403/README.md) |
| Retry confirmed restore failure → reload empty history; undo remains | [运行证据](../04-baby/baby-development-recovery-restore-403-reload/README.md) |
| Undo returns HTTP 409 → error and retained deletion receipt | [运行证据](../04-baby/baby-development-recovery-restore-409/README.md) |
| Retry confirmed restore failure → reload empty history; undo remains | [运行证据](../04-baby/baby-development-recovery-restore-409-reload/README.md) |
| Retry restore → response pending while empty list remains | [运行证据](../04-baby/baby-development-recovery-restore-pending/README.md) |
| Undo fails 503 → unconfirmed restore with retry | [运行证据](../04-baby/baby-development-recovery-restore-unconfirmed/README.md) |
| Restore acknowledged → same record version 3, undo receipt cleared | [运行证据](../04-baby/baby-development-recovery-restored/README.md) |
| Save observation before history recovery | [运行证据](../04-baby/baby-development-recovery-saved/README.md) |
| Choose one observed behavior | [运行证据](../04-baby/baby-development-recovery-selected/README.md) |

## 验证及剩余范围

- [严格采集](runs/20260913T231126-targeted/capture.log)：2 项通过，未更新 Golden 基线。
- [全仓静态检查](baby-development-recovery-analyze.log)：No issues found，退出码 0。
- 初次测试错误地用“重试”查找冲突按钮、用 Tooltip 节点读取 IconButton，已按当前 UI 修正。静态检查补齐 if 大括号，并使用已有编辑器助手断言实际选择；复跑后图像哈希与已审阅产物一致。未修改业务代码。
- 剩余：编辑/创建的权限与真实版本冲突、多记录交错、服务器提交后响应丢失、未确认状态下重复撤销、挂起期间离开及重入、年份/日期格/无出生日期与原生系统层。三种记录普通删除恢复见 [记录管理](BABY-DEVELOPMENT-MANAGEMENT.md)。

全 App 覆盖继续保持未完成。六个未被自动类型匹配的用户侧文件已有 [入口单列说明](ENTRY-STATUS.md)，其中包含无正常入口、专家专用和函数式弹窗；不能按这个数字推断缺少六张页面截图。

[最终完整性检查](baby-development-recovery-final-verify.log) 通过：2050 个条目、3856 份视口元数据、1839 份长图范围，goal_completion=NOT_PROVEN。新增测试只读格式检查 0 changed。
