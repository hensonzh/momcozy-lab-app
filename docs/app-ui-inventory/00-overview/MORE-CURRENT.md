# 当前 More：入口、账号资料与退出登录

本批使用正式 App、GoRouter、Repository、Controller 与通知协调器，从 Me 实际点击 More。393 px / 1x 与 320 px / 2x 分别运行；仅注入隔离 HTTP、内存会话及模拟原生通知依赖，不写真实账号、健康记录或购买数据。

## 已实际运行的链路

- More → 隐私 → 返回 More；保存完整隐私长图。本批未操作授权开关，既有链路见 [隐私报告](PRIVACY-JOURNEYS.md)。
- More → 账号设置 → Link Google 密码确认 → Cancel → 删除账号确认 → Cancel → 返回 More。未调用真实 Google 授权或删除账号。
- More → 通知（保留 from=/more）→ Mark all read → 未读数从 3 变为 0 → 通知设置 → 返回通知 → 返回 More，首页未读徽标消失。
- More → 专家支持 → 服务目录 → 查看我的服务 → 已购服务详情 → 返回目录 → 返回 More。目录、服务正文及固定底部操作均有完整长图。
- More → 滚动到退出登录 → 点击退出：远端撤销挂起期间，本地会话立即清空并进入登录页；远端成功后仍保持登录页。另一个场景注入远端 503，登录页显示退出失败 Snackbar，提示消失后仍未登录。
- 身份资料两接口挂起时展示加载态；姓名先返回仍等待邮箱。两者完成后同时展示。姓名失败、邮箱失败、两者失败分别保留可用字段或显示真实兜底文案。
- 长姓名与长邮箱来自隔离 HTTP，101 条未读通知从初始化接口加载，More 显示 99+，没有直接改 UI 状态制造徽标。

## 截图和视觉审阅

38 个状态、76 个视口变体、46 张完整长图，10 个状态以长图为主图。122 张原图连续分成 284 段，107 个唯一片段；102 个新片段组成 17 张审阅页，均已查看，5 个片段与此前已审阅图像逐像素一致。来源和连续覆盖见 [图像映射](more-current-visual-review/sources.json)、[证据审计](more-current-evidence-audit.json)。

- 窄屏大字下 More 头像移至身份信息上方，长姓名与邮箱换行，设置、专家入口、退出登录和底部导航均在完整长图中保留。
- 当前账号设置采用新卡片与返回图标；Google 确认框 Current password 完整显示，Continue / Cancel 纵向排列。删除确认按钮与取消按钮均可见。
- 320 px / 2x 下通知标题 Notifications、设置类别 Appointments 会拆词换行；登录页 Momcozy 拆成 Momcoz / y，输入提示带省略号。记录为当前视觉问题，本任务未修改产品设计。
- 退出失败 Snackbar 在窗口及长图底部保留；More 的退出挂起态实际上已是登录页，没有虚构 More 加载指示器。
- 采集期间 More 与 Account 被工作区其他修改更新，已按最新组件重新采集。隐私返回等待路由动画结束，避免半透明中间帧。最后严格采集后，当前 lib 文件与采集前快照一致；历史其他批次不因此自动获得时效证明。

## 逐状态入口与前驱

| 实际动作 | 截图、长图和前驱 |
| --- | --- |
| Account settings row → real account details and methods | [运行证据](../07-me/more-current-account/README.md) |
| Cancel deletion → account retained | [运行证据](../07-me/more-current-account-delete-cancel/README.md) |
| Request account deletion → confirmation only | [运行证据](../07-me/more-current-account-delete-confirm/README.md) |
| Cancel password confirmation → account unchanged | [运行证据](../07-me/more-current-account-link-cancel/README.md) |
| Link Google → password confirmation, before native sign in | [运行证据](../07-me/more-current-account-link-confirm/README.md) |
| Tap page Back → /more | [运行证据](../07-me/more-current-account-return/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-both-unavailable-mom/README.md) |
| Tap page Back → /more | [运行证据](../07-me/more-current-catalog-return/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-email-unavailable-mom/README.md) |
| Expert support card → real service catalog | [运行证据](../07-me/more-current-expert-catalog/README.md) |
| My service → purchased package details | [运行证据](../07-me/more-current-expert-package/README.md) |
| More identity both-unavailable from independent HTTP responses | [运行证据](../07-me/more-current-identity-both-unavailable/README.md) |
| More identity email-unavailable from independent HTTP responses | [运行证据](../07-me/more-current-identity-email-unavailable/README.md) |
| More identity long from independent HTTP responses | [运行证据](../07-me/more-current-identity-long/README.md) |
| Name response arrived, email pending → combined identity still loading | [运行证据](../07-me/more-current-identity-name-only-arrived/README.md) |
| More identity name-unavailable from independent HTTP responses | [运行证据](../07-me/more-current-identity-name-unavailable/README.md) |
| Both identity endpoints pending → loading account card | [运行证据](../07-me/more-current-identity-pending/README.md) |
| Both responses arrived → name and email displayed | [运行证据](../07-me/more-current-identity-resolved/README.md) |
| Mark all read → inbox read and count zero | [运行证据](../07-me/more-current-inbox-read/README.md) |
| Tap page Back → /more | [运行证据](../07-me/more-current-inbox-return/README.md) |
| Notifications row → real inbox preserving from=/more | [运行证据](../07-me/more-current-inbox-unread/README.md) |
| Remote logout-session completed → login remains | [运行证据](../07-me/more-current-logout-complete/README.md) |
| Snackbar expires → anonymous login persists | [运行证据](../07-me/more-current-logout-error-dismissed/README.md) |
| Remote revoke returns 503 → login with sign-out failure Snackbar | [运行证据](../07-me/more-current-logout-error-message/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-logout-error-mom/README.md) |
| More before failed remote revoke | [运行证据](../07-me/more-current-logout-error-ready/README.md) |
| Sign out → local session cleared and login immediately, remote revoke pending | [运行证据](../07-me/more-current-logout-remote-pending/README.md) |
| Scroll More to sign-out control | [运行证据](../07-me/more-current-logout-visible/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-long-mom/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-name-unavailable-mom/README.md) |
| Inbox settings → real preferences and authorization state | [运行证据](../07-me/more-current-notification-settings/README.md) |
| Tap page Back → /services | [运行证据](../07-me/more-current-package-return/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-pending-mom/README.md) |
| More privacy → real privacy page | [运行证据](../07-me/more-current-privacy/README.md) |
| Tap page Back → /more | [运行证据](../07-me/more-current-privacy-return/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/more-current-routes-mom/README.md) |
| More current identity and three unread notifications | [运行证据](../07-me/more-current-routes-ready/README.md) |
| Tap page Back → /notifications | [运行证据](../07-me/more-current-settings-return/README.md) |

## 验证及未完成范围

- [严格采集](runs/20260913T234029-targeted/capture.log)：14 项通过，未更新 Golden 基线。场景建立与工作区页面变化后的基线更新属于此前步骤。
- [全仓静态检查](more-current-analyze.log)：No issues found，退出码 0；本批测试只读格式检查 0 changed。
- [文件完整性](more-current-final-verify.log) 只验证文件、元数据和引用，不证明全部交互已覆盖。
- 测试入口：`test/modules/profile/more_current_inventory_test.dart`；本批未构建设备包、调用真实系统授权、执行真实支付或修改健康记录。
- 通知全部动作与失败分支见 [通知链路](NOTIFICATION-JOURNEYS.md)、[通知后续](NOTIFICATION-FOLLOWUP.md)，服务深层流程见 [服务链路](SERVICE-JOURNEYS.md)，认证辅助链见 [认证后续](AUTH-FOLLOWUP.md)。这些历史证据仍需结合当前源码逐项复核。
- 本批仅完成账号进入、确认及取消；后续 [当前账号页链路](ACCOUNT-CURRENT.md) 已补加载重试、默认 Google 不可用、删除和退出。当前没有解绑入口。更多模块的系统权限、深层业务分支和历史长图审阅仍待继续。

全 App 完成状态：**NOT_PROVEN**。本批五个 More 入口已实际到达其目标，但不代表每个目标页面的全部控件和业务分支已完成。
