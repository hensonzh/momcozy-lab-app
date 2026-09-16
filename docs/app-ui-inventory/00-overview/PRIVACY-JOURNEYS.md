# 隐私与数据：正式入口及授权操作链

从已登录用户的 More 页点击“隐私”，使用正式 App、GoRouter、PrivacyPage、PrivacyController、Care/Intake API Repository；HTTP 层隔离服务目录、两个已购服务及各自的版本化授权记录。通知设置往返使用现有 NotificationCoordinator。没有调用真实账号的授权写接口。

本轮新增 **36 个状态、60 个尺寸/字号窗口、40 张完整长图变体（22 张主长图）**；9 项测试通过。主要交互同时覆盖 393/1x 和 320/2x；额外加载、空态、重新读取与版本冲突在 393 上验证。没有改变生产代码或采集器。

## 当前页面实际提供的控制

- 服务下拉选择器；IBCLC、视频咨询、Cozymate 上下文三个独立开关。
- “接收服务提醒”是跳转“管理通知与提醒”的说明区，没有第四个提醒 Switch，也没有“App 服务全局授权”开关。
- 保存更改；关闭必要授权的确认/继续保留/关闭按钮；离开时的放弃/继续查看。
- 读取失败重试；未确认保存重试；重新读取授权；版本冲突重新载入。

## 已实际验证的行为

1. 可选 Cozymate 授权直接保存；IBCLC 与视频授权由开启改为关闭时，保存前出现二次确认。点击“继续保留”或关闭按钮不写入服务端，但也不会重置页面开关——它们仍是待保存草稿。重新启用授权不出现撤销确认。
2. 切换服务有未保存草稿时会确认放弃。“继续查看”将选择器回滚到原服务并保留草稿；“放弃并离开”在此处切换到另一服务，并不退出页面。保存第二服务后，第一服务的授权不变；测试验证请求 episode_id 与存储值。
3. 保存挂起时，返回、服务选择器、开关及提醒入口锁定。多项保存按关闭优先顺序进行；第一项已成功、下一项 503 时，进入未确认状态。重试只发送未完成的一项，scope/active/expected_version/policy_version 与首次请求一致，不重发已成功项。
4. 未确认状态离开会提示再次进入后重新读取。选择继续查看再重试可完成保存。也可主动重新读取授权，此操作不再次写入、放弃未确认草稿，并使用服务端已保存值。
5. HTTP 409 后显示“记录已在其他页面更新，请重新载入后核对”；开关和保存按钮锁定。重新载入成功后可再次编辑保存。
6. 服务概览加载失败/重试、无已购服务、所选服务授权加载失败/重试均已捕获；读取失败时不把未知值呈现成可编辑的默认关闭状态。
7. “管理通知与提醒”进入实际 `/notifications/settings`。点击页面的返回箭头回到隐私页，草稿保留。隐私页自身“返回”经放弃确认后回到 `/more`；重新进入显示服务端值，不恢复已放弃草稿。

## 状态证据

每条 README 包含前驱截图、实际触发与路由。需要滚动的页面默认图是完整长图，同时保留操作时所在位置的窗口。

| 状态 | 实际触发 | 截图和入口链 |
| --- | --- | --- |
| conflict-reloaded | Reload latest consent versions → editing unlocked | [证据](../07-me/privacy-journey-conflict-reloaded/README.md) |
| conflict-resaved | Edit after reload → successful new save | [证据](../07-me/privacy-journey-conflict-resaved/README.md) |
| consent-loading | Overview loads → selected consent read pending | [证据](../07-me/privacy-journey-consent-loading/README.md) |
| consent-read-error | Consent read fails → retry, no fake unchecked controls | [证据](../07-me/privacy-journey-consent-read-error/README.md) |
| consent-read-retried | Retry consent HTTP → editable existing values | [证据](../07-me/privacy-journey-consent-read-retried/README.md) |
| empty-back | Empty page back → More | [证据](../07-me/privacy-journey-empty-back/README.md) |
| empty-services | Retry with no owned services → empty state and no editable defaults | [证据](../07-me/privacy-journey-empty-services/README.md) |
| granted | Re-enable three permissions → save without revocation confirmation | [证据](../07-me/privacy-journey-granted/README.md) |
| leave-confirm | Back with draft → discard confirmation | [证据](../07-me/privacy-journey-leave-confirm/README.md) |
| leave-discarded | Discard and leave → original More route | [证据](../07-me/privacy-journey-leave-discarded/README.md) |
| leave-kept | Continue viewing → draft retained | [证据](../07-me/privacy-journey-leave-kept/README.md) |
| loaded | More privacy → first service three editable permissions | [证据](../07-me/privacy-journey-loaded/README.md) |
| notification-settings | Manage reminders → actual notification settings route with privacy draft underneath | [证据](../07-me/privacy-journey-notification-settings/README.md) |
| notifications-return | Back from notification settings → unsaved privacy draft retained | [证据](../07-me/privacy-journey-notifications-return/README.md) |
| optional-dirty | Turn off Cozymate context → unsaved draft | [证据](../07-me/privacy-journey-optional-dirty/README.md) |
| optional-saved | Save optional change → versioned HTTP write and saved message | [证据](../07-me/privacy-journey-optional-saved/README.md) |
| optional-uncertain | Optional write HTTP failure → uncertain state | [证据](../07-me/privacy-journey-optional-uncertain/README.md) |
| overview-error | Overview HTTP failure → error and retry | [证据](../07-me/privacy-journey-overview-error/README.md) |
| overview-loading | Privacy entry → overview HTTP pending | [证据](../07-me/privacy-journey-overview-loading/README.md) |
| partial-uncertain | Required revocation succeeds; optional write 503 → unresolved change and retry | [证据](../07-me/privacy-journey-partial-uncertain/README.md) |
| reentered | Re-enter privacy → persisted server values, discarded draft absent | [证据](../07-me/privacy-journey-reentered/README.md) |
| reread | Re-read discards unresolved draft; uses stored consent without retrying write | [证据](../07-me/privacy-journey-reread/README.md) |
| revoke-closed | Close confirmation icon → draft remains, no write | [证据](../07-me/privacy-journey-revoke-closed/README.md) |
| revoke-confirm | Disable case and video → save requests required-scope confirmation | [证据](../07-me/privacy-journey-revoke-confirm/README.md) |
| revoke-kept | Keep authorization → dialog closes; toggled draft remains unsaved | [证据](../07-me/privacy-journey-revoke-kept/README.md) |
| revoked | Confirm required revocation → both HTTP writes and saved state | [证据](../07-me/privacy-journey-revoked/README.md) |
| saving | Confirm revocation → pending HTTP locks back, selector and switches | [证据](../07-me/privacy-journey-saving/README.md) |
| second-service-saved | Save second service → first service stays unchanged | [证据](../07-me/privacy-journey-second-service-saved/README.md) |
| service-picker | Tap service picker → list of owned services | [证据](../07-me/privacy-journey-service-picker/README.md) |
| service-picker-reopened | Tap service picker → list of owned services | [证据](../07-me/privacy-journey-service-picker-reopened/README.md) |
| switch-cancelled | Keep draft → picker rolls back to original service | [证据](../07-me/privacy-journey-switch-cancelled/README.md) |
| switch-confirm | Select another service with dirty draft → discard confirmation | [证据](../07-me/privacy-journey-switch-confirm/README.md) |
| switched | Discard previous draft → second service permissions loaded | [证据](../07-me/privacy-journey-switched/README.md) |
| uncertain-leave-confirm | Back while result uncertain → explanation to re-read on return | [证据](../07-me/privacy-journey-uncertain-leave-confirm/README.md) |
| uncertain-retried | Retry only unresolved optional write with same version; saved required scope not resent | [证据](../07-me/privacy-journey-uncertain-retried/README.md) |
| version-conflict | Consent write 409 → reload required and switches locked | [证据](../07-me/privacy-journey-version-conflict/README.md) |

## 检查与视觉边界

- [最终严格采集日志](runs/20260913T141442-targeted/capture.log)：9 PASS；没有在采集时更新 Golden 或放宽容差。
- [静态检查](privacy-journey-analyze.log)：2 个文件 No issues found；格式检查 2 files / 0 changed。
- [逐图来源及 SHA-256](privacy-visual-review/sources.json)：100 个原始图片（60 窗口 + 40 长图）。156 个连续片段在 18 张联系表中已全部查看，最终复跑后哈希一致。下方提供完整联系表索引。
- 长图覆盖页面头部、全部三项授权、提醒入口、错误说明及页底保存控件；弹窗按前景滚动区采集。320/2x 的撤销确认轻微超出窗口时也生成了前景长图，背景没有重复拉长。
- 320/2x 下选择器关闭时只能看到套餐名称及分隔符，日期被控件高度裁掉；打开下拉后可见完整日期。本轮如实保留，不把它描述为全部文案无裁切。英文通知类别及底部导航会跨行，仍按实际窗口保留。
- 第二维服务故意缺少目录名称，实际显示“专家支持服务”兜底；不是伪造某个实际购买套餐。没有进入真实视频房间验证授权撤销后的远端断连，也没有模拟真实后台通知发送。
- 本轮未执行原生设备截图；宿主 Widget 运行证明的是正式客户端页面/路由/Repository 交互，不等于已验证 iOS/Android 系统权限提示。

[片段 01](privacy-visual-review/sheet-01.png) · [片段 02](privacy-visual-review/sheet-02.png) · [片段 03](privacy-visual-review/sheet-03.png) · [片段 04](privacy-visual-review/sheet-04.png) · [片段 05](privacy-visual-review/sheet-05.png) · [片段 06](privacy-visual-review/sheet-06.png) · [片段 07](privacy-visual-review/sheet-07.png) · [片段 08](privacy-visual-review/sheet-08.png) · [片段 09](privacy-visual-review/sheet-09.png) · [片段 10](privacy-visual-review/sheet-10.png) · [片段 11](privacy-visual-review/sheet-11.png) · [片段 12](privacy-visual-review/sheet-12.png) · [片段 13](privacy-visual-review/sheet-13.png) · [片段 14](privacy-visual-review/sheet-14.png) · [片段 15](privacy-visual-review/sheet-15.png) · [片段 16](privacy-visual-review/sheet-16.png) · [片段 17](privacy-visual-review/sheet-17.png) · [片段 18](privacy-visual-review/sheet-18.png)

## 尚未据此证明的范围

`initialEpisodeId` 的未找到指定服务状态已有组件测试，但当前隐私入口来自 More 和 Baby 历史页，均不传 episode 参数；不能将强制传参的组件预览算作实际入口。本轮未遍历系统返回手势、确认弹窗点击外侧、每一种授权 HTTP 错误文案或原生设备授权层。整个 App 的剩余入口、媒体/权限分支和全体长图最终审核仍需完成。
