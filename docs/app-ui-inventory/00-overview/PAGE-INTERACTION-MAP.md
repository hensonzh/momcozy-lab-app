# 独立页面与操作链对应

每个页面的状态图集中在页面目录；下表把实际进入、编辑、提交、错误恢复、返回及跳转证据接到同一入口。配置、兜底、无入口代码与默认页面分开，不用截图数量代替页面数量。

| 页面／范围 | 从哪里进入 | 需对应的状态 | 现有操作证据 |
| --- | --- | --- | --- |
| [登录](pages/auth-login.md) / default | 未登录打开受保护页面 | 初始、密码可见、提交中、认证错误、成功跳转、Google 不可用 | [AUTH-CURRENT](AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT](AUTH-SUBMIT-FEEDBACK-CURRENT.md) |
| [注册](pages/auth-register.md) / default | 登录 → Create an account | 空表单、校验错误、提交中、发送验证码、服务错误 | [AUTH-CURRENT](AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT](AUTH-SUBMIT-FEEDBACK-CURRENT.md) |
| [邮箱验证](pages/auth-verify.md) / default | 注册或未验证账号登录 | 待输入、验证码错误、重发等待与反馈、提交中、验证成功 | [AUTH-CURRENT](AUTH-CURRENT.md) · [AUTH-SUBMIT-FEEDBACK-CURRENT](AUTH-SUBMIT-FEEDBACK-CURRENT.md) |
| [找回密码](pages/auth-forgot.md) / default | 登录 → Forgot password | 初始、校验错误、提交中、发送失败、进入重置 | [AUTH-CURRENT](AUTH-CURRENT.md) |
| [重置密码](pages/auth-reset.md) / default | 找回密码发送验证码成功 | 初始、密码和验证码校验、提交中、失败、成功返回登录 | [AUTH-CURRENT](AUTH-CURRENT.md) |
| [妈妈首页](pages/mom-home.md) / default | Me Tab | 初始、有记录、已购服务、部分数据、加载、局部错误 | [MOM-JOURNEYS](MOM-JOURNEYS.md) · [MOM-CONTROL-COVERAGE](MOM-CONTROL-COVERAGE.md) · [SERVICE-JOURNEYS](SERVICE-JOURNEYS.md) |
| [今日状态记录页](pages/mom-diary.md) / default | 妈妈首页 → 今日状态 | 身体、休息、心情、加载、空记录、保存与失败 | [MOM-JOURNEYS](MOM-JOURNEYS.md) · [MOM-BODY-CONTROLS](MOM-BODY-CONTROLS.md) · [MOM-REST-CONTROLS](MOM-REST-CONTROLS.md) · [MOM-MOOD-CONTROLS](MOM-MOOD-CONTROLS.md) |
| [泌乳记录与趋势](pages/mom-lactation.md) / default | 妈妈首页 → 查看记录 | 空记录、有记录与趋势、日期切换、加载、错误、删除与撤销 | [MOM-JOURNEYS](MOM-JOURNEYS.md) · [MOM-MILK-CONTROLS](MOM-MILK-CONTROLS.md) · [MOM-MILK-VALIDATION](MOM-MILK-VALIDATION.md) |
| [宝宝首页](pages/baby-home.md) / default | Baby Tab | 无宝宝、有宝宝、有记录、加载、局部错误、生长曲线切换 | [BABY-JOURNEYS](BABY-JOURNEYS.md) · [BABY-PROFILE-CONTROLS](BABY-PROFILE-CONTROLS.md) · [BABY-KNOWLEDGE-SOURCES](BABY-KNOWLEDGE-SOURCES.md) |
| [宝宝记录历史](pages/baby-records.md) / default | 宝宝首页 → 记录历史 | 空、列表、种类和日期切换、加载、错误、删除与撤销 | [BABY-JOURNEYS](BABY-JOURNEYS.md) · [BABY-FEEDING-CONTROLS](BABY-FEEDING-CONTROLS.md) · [BABY-DIAPER-CONTROLS](BABY-DIAPER-CONTROLS.md) · [BABY-SLEEP-CONTROLS](BABY-SLEEP-CONTROLS.md) · [BABY-GROWTH-CONTROLS](BABY-GROWTH-CONTROLS.md) · [BABY-DEVELOPMENT-CONTROLS](BABY-DEVELOPMENT-CONTROLS.md) |
| [Cozymate 对话](pages/agent-home.md) / default | Cozymate Tab | 初始、对话、生成中、结构化卡片、输入及附件、语音、失败与重试、会话恢复 | [AGENT-CURRENT-REUSE](AGENT-CURRENT-REUSE.md) · [AGENT-JOURNEYS](AGENT-JOURNEYS.md) · [AGENT-RESOURCE-JOURNEYS](AGENT-RESOURCE-JOURNEYS.md) · [AGENT-ENTRY-CURRENT](AGENT-ENTRY-CURRENT.md) |
| [日程](pages/schedule.md) / default | Schedule Tab | 空日期、有事项、月和日期切换、任务状态、预约卡、加载、错误 | [SCHEDULE-CURRENT](SCHEDULE-CURRENT.md) · [SCHEDULE-FEEDBACK-CURRENT](SCHEDULE-FEEDBACK-CURRENT.md) · [SCHEDULE-JOURNEYS](SCHEDULE-JOURNEYS.md) |
| [More](pages/more.md) / default | More Tab | 身份完整与缺失、加载、未读变化、退出等待与错误 | [MORE-CURRENT](MORE-CURRENT.md) |
| [账号设置](pages/account.md) / default | More → Account | 身份、密码确认、Google 绑定反馈、删除账号、退出 | [ACCOUNT-CURRENT](ACCOUNT-CURRENT.md) |
| [隐私与授权](pages/privacy.md) / default | More → Privacy | 无服务、按服务授权、开启与关闭、加载、保存失败 | [PRIVACY-JOURNEYS](PRIVACY-JOURNEYS.md) |
| [通知中心](pages/notifications.md) / default | More → Notifications | 空、未读与已读、分页、归档、加载、错误、跳转反馈 | [NOTIFICATION-CURRENT](NOTIFICATION-CURRENT.md) · [NOTIFICATION-NAVIGATION-CURRENT](NOTIFICATION-NAVIGATION-CURRENT.md) · [AGENT-ENTRY-CURRENT](AGENT-ENTRY-CURRENT.md) |
| [通知设置](pages/notification-settings.md) / default | 通知中心 → Settings | 分类开关、未申请、允许、拒绝、设备注册中、注册错误、不可用 | [NOTIFICATION-PERMISSION-CURRENT](NOTIFICATION-PERMISSION-CURRENT.md) · [NATIVE-NOTIFICATION-PERMISSIONS](NATIVE-NOTIFICATION-PERMISSIONS.md) |
| [专家服务目录](pages/service-catalog.md) / default | 妈妈首页 → 专家陪伴计划 | 四套餐、空、加载、错误 | [SERVICE-CURRENT](SERVICE-CURRENT.md) |
| [服务套餐详情](pages/service-package.md) / default | 服务目录 → 查看方案 | 四套餐内容、未购、待付、已购、不可购买、缺失、加载、错误 | [SERVICE-CURRENT](SERVICE-CURRENT.md) · [PURCHASE-CURRENT](PURCHASE-CURRENT.md) · [PURCHASE-BRANCHES-CURRENT](PURCHASE-BRANCHES-CURRENT.md) |
| [服务详情与时间线](pages/service-progress.md) / default | 已购计划 → 服务进度 | 进行中、暂停、到期、次数用尽、最近与更早、加载、错误 | [PROGRESS-CURRENT](PROGRESS-CURRENT.md) |
| [续购服务](pages/service-renew.md) / default | 服务进度或 Agent → 续购 | 可续购、暂停、到期、无套餐、加载、错误、购买入口 | [RENEW-CURRENT](RENEW-CURRENT.md) · [RENEW-PENDING-CURRENT](RENEW-PENDING-CURRENT.md) · [RENEW-JOURNEYS](RENEW-JOURNEYS.md) |
| [预约与预约内详情](pages/booking.md) / default | 已购计划 → 预约咨询 | 前确认入口、时段列表、保留、已确认、咨询中、业务拒绝、等待、错误恢复 | [BOOKING-PRECHECK-CURRENT](BOOKING-PRECHECK-CURRENT.md) · [BOOKING-SELECTION-CURRENT](BOOKING-SELECTION-CURRENT.md) · [BOOKING-RECOVERY-CURRENT](BOOKING-RECOVERY-CURRENT.md) · [BOOKING-REMINDER-ENTRY-CURRENT](BOOKING-REMINDER-ENTRY-CURRENT.md) |
| [独立预约详情](pages/appointment.md) / default | 通知或日程 → 指定预约 | held、confirmed、in_progress、completed、cancelled、expired、加载、错误 | [BOOKING-RECOVERY-CURRENT](BOOKING-RECOVERY-CURRENT.md) · [NOTIFICATION-NAVIGATION-CURRENT](NOTIFICATION-NAVIGATION-CURRENT.md) |
| [咨询信息采集表](pages/intake.md) / default | 预约确认 → 信息采集 | 初始、已填写、补充展开、基础信息、授权、校验、保存中、错误、已保存 | [INTAKE-CURRENT](INTAKE-CURRENT.md) · [INTAKE-FEEDBACK-CURRENT](INTAKE-FEEDBACK-CURRENT.md) |
| [咨询准备、通话与结束](pages/consultation.md) / default | 预约详情 → 咨询前准备／进入咨询 | 准备、等待专家、可进入、通话、断线与恢复、离开、结束、取消、过期、加载、错误 | [CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT](CONSULTATION-PREFLIGHT-FEEDBACK-CURRENT.md) · [CONSULTATION-LIVE-CURRENT](CONSULTATION-LIVE-CURRENT.md) · [CONSULTATION-OUTCOME-CURRENT](CONSULTATION-OUTCOME-CURRENT.md) |
| [咨询总结与后续任务](pages/summary.md) / default | 咨询结束或通知 → 总结 | 首次加载、待发布、尚未产生总结、咨询未完成、读取失败及重试、已发布：当前行动／后续行动／观察目标／更多帮助、无行动、服务信息折叠／展开、行动详情及四种进度、更新中与关闭禁用、更新结果不确定及重试、方案替换及重新载入、行动移除提示、刷新失败保留内容、完整行动计划与服务进度入口 | [CONSULTATION-SUMMARY-CURRENT](CONSULTATION-SUMMARY-CURRENT.md) |
| [媒体查看器](pages/media.md) / default | Agent 资源或图片 → 查看 | 图片、PDF 多页与缩放、视频、加载、解码与网络错误、资源缺失 | [AGENT-RESOURCE-JOURNEYS](AGENT-RESOURCE-JOURNEYS.md) · [NATIVE-RESOURCE-JOURNEYS](NATIVE-RESOURCE-JOURNEYS.md) |
| [视频全屏](pages/video-fullscreen.md) / navigator | 媒体视频 → 全屏 | 播放、暂停、进度、控件显示与隐藏、返回 | [AGENT-RESOURCE-JOURNEYS](AGENT-RESOURCE-JOURNEYS.md) · [NATIVE-RESOURCE-JOURNEYS](NATIVE-RESOURCE-JOURNEYS.md) |
| [邀请登录](pages/invite.md) / configured | internalInviteOnly 配置 | 输入、校验、提交、错误 | [CONFIGURED-PAGES-CURRENT](CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT](CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT](CONFIGURED-ERRORS-CURRENT.md) |
| [首次使用资料](pages/onboarding.md) / configured | 开启 onboarding 后按引导进入 | 加载、错误、基本资料、分娩资料、宝宝资料、校验与保存 | [CONFIGURED-PAGES-CURRENT](CONFIGURED-PAGES-CURRENT.md) |
| [数字形象创建](pages/avatar-create.md) / configured | 开启 onboarding 后按引导进入 | 默认选择、照片、上传、生成中、失败、重试 | [CONFIGURED-PAGES-CURRENT](CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT](CONFIGURED-SUBMISSION-CURRENT.md) · [CONFIGURED-ERRORS-CURRENT](CONFIGURED-ERRORS-CURRENT.md) |
| [数字形象确认](pages/avatar-review.md) / configured | 开启 onboarding 后按引导进入 | 候选选择、默认确认、激活中、失败、完成 | [CONFIGURED-PAGES-CURRENT](CONFIGURED-PAGES-CURRENT.md) · [CONFIGURED-SUBMISSION-CURRENT](CONFIGURED-SUBMISSION-CURRENT.md) |
| [无效路由提示](pages/not-found.md) / fallback | 无效深链 / errorBuilder | 未找到页面、返回 | [ENTRY-STATUS](ENTRY-STATUS.md) |
| [动作评估](pages/motion.md) / unreachable | Agent 动作卡当前目的路由未注册 | 预览、评估、结果 | [ENTRY-STATUS](ENTRY-STATUS.md) |

## 如何区分证据

- 页面目录中的每张代表图链接原始 README，保留触发操作、前驱、实际路由与完整图；同像素组的其它入口保留在原索引。
- [35 类浮层对应](OVERLAY-EVIDENCE-MAP.md)列出实际展开截图；函数式弹窗不能因组件扫描为 0 而被判成缺图。
- 已到达目标页与目标页内部控件已遍历分开记录；例如总结任务引用总结报告，不能只引用通知到达总结页。
- 旧报告中的额外尺寸、请求时序、错误码和字段组合不是自动追加采集的理由；只有具体控件产生了未被现图覆盖的可见变化才成为缺口。
- 当前映射完成了“页面 → 状态目录／操作报告”的归属；每个必需状态的最终验收仍须按证据范围判断，不能把索引完整直接写成全 UI 验收通过。

[原要求](REQUEST.md) · [最终收尾范围](REMAINING-VISUAL-REVIEW.md) · [系统窗口](NATIVE-WINDOWS-CATALOG.md)。
