# 当前 Account：加载、密码确认、删除与退出

正式 Me → More → 账号设置，使用当前 MomCozyFlutterApp、GoRouter、账号页面、Auth Repository 和会话控制器，分别运行 393 px / 1x、320 px / 2x。所有 HTTP 和会话数据均隔离；没有删除真实用户或调用生产外部交易。

## 实际点击与状态

- 账号 GET 挂起 → Loading account → 503 → Account unavailable → Retry → 再次加载 → 成功；最后通过页面返回按钮回到 More。
- Email-only 账号 → Link Google → 空密码 Continue：弹窗直接关闭，没有校验错误，也不提交请求。再次输入密码 → Cancel；再输入并 Continue，真实 NativeGoogleSignInGateway 因当前构建未配置客户端 ID 返回不可用提示。重新打开确认框后取消，旧错误仍保留。
- 删除账号 → 确认 → Cancel，不发生 DELETE。再次确认 → DELETE 挂起，绑定、退出、删除按钮禁用；503 后账号仍登录，显示内联错误。重试须再次确认，提交后旧错误清除；DELETE 成功后本地会话清空并进入登录页，显示数据擦除待处理 Snackbar，再记录提示消失后的状态。此路径不重复发远端 logout-session。
- 账号页 Sign out → 本地会话先清空，远端撤销挂起期间已到登录页；分别记录远端成功和 503。失败使用账号页专属文案，与 More 的较短退出提示不同；提示到时消失，登录页保留。
- API 返回仅 Google、无登录方式/disabled/无邮箱、长邮箱/deletion_pending/多登录方式时，均从正常入口进入账号页；当前组件按接口字段展示状态徽标与登录方式，随后实际返回 More。`custom` 仅用来触发已有未知方式兜底，不表示已上线新的认证方式。

## 范围与来源限定

- 当前账号页没有解绑操作，已从待办中删除虚构的“解绑链”。
- 本地默认构建没有 Google 客户端 ID；因此绑定成功、提供商取消及 OAuth 服务错误属于配置具备后的条件路径。本批保留真实默认网关，没有替换成会返回成功 token 的组件测试替身。既有组件级绑定测试不升级为正常构建可达证明。
- disabled/deletion_pending 等截图证明前端能处理给定 API 响应，不证明后端允许该账号状态继续取得有效会话；其服务端约束仍需另行核验。
- 没有真实删除、真实登录、真实凭据输入或健康记录写入；密码为明确的测试文本。原生输入法和 Google 系统授权界面未在本批运行。

## 截图与视觉核验

52 个状态、104 个视口变体、52 张完整长图；8 个状态以长图为主图。156 张原图全宽连续分成 359 段，102 个唯一片段；61 个新片段组成 11 张审阅页，已逐张查看，41 个片段与之前已审阅图片逐像素一致。[图像映射](account-current-visual-review/sources.json)、[证据审计](account-current-evidence-audit.json)、[源码快照](account-current-capture-source-snapshot.json)。

- 窄屏大字号下长邮箱、登录方式和删除说明自动换行，长图保留完整身份信息、账号操作和底部删除说明；当前视口可能停在下方错误信息处，不能只看窗口判定顶部内容缺失。
- 等待 DELETE 时加载条位于登录方式卡底部；三项业务操作禁用，页面返回按钮仍可见。等待期间返回的行为尚未采集。
- 密码输入保持遮蔽；有焦点时标签上浮，空输入和已输入分别采集。本文不把宿主输入状态当真实系统键盘。
- 退出和删除成功提示均作为登录页 Snackbar 保存；长图只保留一次提示和页面内容。登录页大字号品牌文字断行仍是当前视觉问题。
- 采集中设置主题被工作区其他修改更新，最后按最新源码再次严格采集，图片哈希与已审阅版本一致；当前账号页及相关主题源码与最终采集快照一致。同期通知页已发生新设计变化，其旧截图需后续单独更新。

## 逐状态证据

| 操作或返回数据 | 截图、长图、前驱 |
| --- | --- |
| Cancel deletion → no mutation | [运行证据](../07-me/account-current-delete-cancelled/README.md) |
| Request deletion → confirmation | [运行证据](../07-me/account-current-delete-confirm/README.md) |
| DELETE 503 → account retained with inline error | [运行证据](../07-me/account-current-delete-error/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-delete-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-delete-more/README.md) |
| Confirm → DELETE pending, account actions disabled | [运行证据](../07-me/account-current-delete-pending/README.md) |
| Account before deletion | [运行证据](../07-me/account-current-delete-ready/README.md) |
| Retry deletion → confirmation again | [运行证据](../07-me/account-current-delete-retry-confirm/README.md) |
| Confirm retry → clear error and disable actions | [运行证据](../07-me/account-current-delete-retry-pending/README.md) |
| Erasure Snackbar expires → login remains | [运行证据](../07-me/account-current-deleted-login/README.md) |
| DELETE succeeds → local session cleared, login and erasure Snackbar | [运行证据](../07-me/account-current-deleted-login-message/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-disabled-empty-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-disabled-empty-more/README.md) |
| Account GET disabled-empty → real identity status and provider layout | [运行证据](../07-me/account-current-disabled-empty-ready/README.md) |
| Tap page Back → /more | [运行证据](../07-me/account-current-disabled-empty-return/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-google-only-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-google-only-more/README.md) |
| Account GET google-only → real identity status and provider layout | [运行证据](../07-me/account-current-google-only-ready/README.md) |
| Tap page Back → /more | [运行证据](../07-me/account-current-google-only-return/README.md) |
| Retry Link Google → password dialog reopens | [运行证据](../07-me/account-current-google-reopen/README.md) |
| Cancel retry → previous error remains | [运行证据](../07-me/account-current-google-retry-cancelled/README.md) |
| Native gateway lacks build client ID → inline unavailable feedback | [运行证据](../07-me/account-current-google-unavailable/README.md) |
| Account GET pending → loading | [运行证据](../07-me/account-current-loading/README.md) |
| Sign-out error expires → login | [运行证据](../07-me/account-current-logout-error-dismissed/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-logout-error-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-logout-error-more/README.md) |
| Sign out → login while remote revoke pending | [运行证据](../07-me/account-current-logout-error-pending/README.md) |
| Account before sign out | [运行证据](../07-me/account-current-logout-error-ready/README.md) |
| Remote revoke 503 → Account-specific sign-out Snackbar | [运行证据](../07-me/account-current-logout-error-result/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-logout-success-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-logout-success-more/README.md) |
| Sign out → login while remote revoke pending | [运行证据](../07-me/account-current-logout-success-pending/README.md) |
| Account before sign out | [运行证据](../07-me/account-current-logout-success-ready/README.md) |
| Remote revoke success → login | [运行证据](../07-me/account-current-logout-success-result/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-long-pending-other-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-long-pending-other-more/README.md) |
| Account GET long-pending-other → real identity status and provider layout | [运行证据](../07-me/account-current-long-pending-other-ready/README.md) |
| Tap page Back → /more | [运行证据](../07-me/account-current-long-pending-other-return/README.md) |
| Cancel filled password → no binding | [运行证据](../07-me/account-current-password-cancelled/README.md) |
| Link Google → empty password confirmation | [运行证据](../07-me/account-current-password-empty/README.md) |
| Continue empty password → silently return without mutation | [运行证据](../07-me/account-current-password-empty-dismissed/README.md) |
| Enter password → obscured input | [运行证据](../07-me/account-current-password-entered/README.md) |
| Authenticated Me before More navigation | [运行证据](../07-me/account-current-password-mom/README.md) |
| More before Account settings | [运行证据](../07-me/account-current-password-more/README.md) |
| Email-only account | [运行证据](../07-me/account-current-password-ready/README.md) |
| Tap page Back → /more | [运行证据](../07-me/account-current-password-return/README.md) |
| GET 503 → account error and Retry | [运行证据](../07-me/account-current-read-error/README.md) |
| Authenticated Me | [运行证据](../07-me/account-current-read-mom/README.md) |
| More before account read failure | [运行证据](../07-me/account-current-read-more/README.md) |
| Tap page Back → /more | [运行证据](../07-me/account-current-read-return/README.md) |
| Retry → loading again | [运行证据](../07-me/account-current-retry-pending/README.md) |
| Retried GET succeeds → active verified email account | [运行证据](../07-me/account-current-retry-ready/README.md) |

## 验证与后续

- [最终严格采集](runs/20260913T235259-targeted/capture.log)：16 项通过，未更新 Golden 基线。新测试此前建立基线；仅修正测试中三处 if 大括号 lint 后复跑。
- [静态检查](account-current-analyze.log)：No issues found。测试格式检查 0 changed。
- [完整性验证](account-current-final-verify.log) 仅证明文件、长图尺寸、元数据和前驱引用有效。
- 测试文件：`test/modules/profile/account_current_inventory_test.dart`。新增测试、截图、报告；未修改产品业务代码。
- 尚待补充：加载/删除请求挂起期间离页、真实存储失败及网络边界、其他实际错误码分支、配置 Google 后的系统层与服务返回链；同类提示相同也不自动视为业务分支已验。
- More 本体见 [上一批报告](MORE-CURRENT.md)。全 App 的所有深层入口、系统层与历史长图审阅仍需继续。

全 App 完成状态仍为 **NOT_PROVEN**，当前批次测试通过不等于所有 Page × State × Interaction 已覆盖。
