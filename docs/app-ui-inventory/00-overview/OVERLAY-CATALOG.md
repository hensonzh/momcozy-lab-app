# 弹窗与浮层清单

这些是页面的附属交互，不增加独立页面计数。类名在截图树中出现只作定位线索，不证明浮层在顶层显示。函数式弹窗、系统窗口须结合文字与点击链核对；其状态清单有限列明，不枚举字段组合。

| ID / 名称 | 宿主 | 实际触发 | 需覆盖状态 | 类型观察候选数 |
| --- | --- | --- | --- | ---: |
| mom-diary-editor / 妈妈记录弹窗 | mom-home, mom-diary | 今日状态卡／快捷心情 | 身体；休息；心情；编辑；校验；保存；放弃 | 238 |
| lactation-editor / 泌乳记录弹窗 | mom-home, mom-lactation | 记录一次泌乳／编辑 | 新增；编辑；左右侧；泵奶与亲喂；校验；保存错误 | 119 |
| baby-profile / 宝宝资料弹窗 | baby-home | 添加宝宝／编辑资料 | 新增；编辑；校验；保存；关闭确认 | 79 |
| baby-record / 宝宝记录弹窗 | baby-home, baby-records | 对应记录按钮／历史编辑 | 喂养；睡眠；尿布；生长；发育；编辑；校验；保存 | 252 |
| baby-saved / 宝宝保存反馈 | baby-home, baby-records | 记录保存成功 | 保存成功；后续记录 | 28 |
| baby-switcher / 宝宝切换 | baby-home | 首页宝宝名称 | 列表；当前选择；取消 | 0 |
| knowledge / 知识来源与说明 | mom-home, baby-home | 知识卡来源入口；当前妈妈首页已移除旧知识卡 | 来源说明；关闭 | 161 |
| agent-history / 对话历史抽屉 | agent-home | 全局历史能力开启，或从通知进入带 conversationId 的会话 → 历史按钮 | 列表／当前会话；空；加载；加载错误；回复锁定；切换中；切换失败；关闭 | 10 |
| agent-menu / 消息操作菜单 | agent-home | 长按消息 | 操作项；复制反馈 | 212 |
| agent-form / Agent 结构化表单 | agent-home | 结构化卡 → 填写 | 各表单 schema；校验；提交；失败 | 25 |
| agent-image / 对话图片预览 | agent-home | 已发送或草稿图片 | 加载；图片；失败；关闭 | 12 |
| schedule-editor / 个人日程表单 | schedule | 添加／编辑日程 | 新增；编辑；时间；校验；保存；错误 | 44 |
| schedule-delete / 日程删除确认 | schedule | 事项菜单 → 删除 | 确认；取消；等待；失败 | 2 |
| provider-team / 专家团队介绍 | service-catalog, service-package | 查看专家团队 | 团队；空；关闭 | 13 |
| purchase / 购买服务流程 | service-package, service-renew | 购买／继续付款 | 资格；付款；校验；拒付；额外验证；待付；取消；成功；同步权益；错误 | 109 |
| booking-precheck / 预约前确认 | booking | 预约入口／开始确认 | 州选择；适用性；风险；等待；拒绝；重试 | 32 |
| booking-review / 确认预约时间 | booking | 选时段／查看所选时间 | held；提醒草稿；过期；确认中；错误；已确认 | 28 |
| appointment-cancel / 取消预约 | booking, appointment, consultation, mom-home | 取消预约 | 确认；保留；等待；未知；状态变化；恢复 | 14 |
| home-consultation / 首页预约浮层 | mom-home | 首页 → 查看预约 | 准备；信息采集入口；取消；过期；错误 | 117 |
| intake-consent / 信息使用说明 | intake | 信息使用 → 查看说明 | 说明；关闭 | 2 |
| intake-saved / 信息采集保存成功 | intake | 保存信息采集表成功 | 保存成功；预咨询；稍后 | 3 |
| device-check / 咨询设备检查 | consultation, mom-home | 咨询准备 → 设备检查 | 权限未授权；检查中；预览；错误；通过 | 9 |
| video-consent / 视频咨询授权 | consultation, mom-home | 准备进入视频咨询 | 未勾选；勾选；同意；关闭 | 6 |
| consultation-start / 进入咨询确认 | consultation, mom-home | 设备检查后进入 | 准备；确认；等待；失败 | 24 |
| consultation-leave / 暂时离开咨询 | consultation | 咨询中返回 | 确认；留下；处理中；失败 | 0 |
| notification-education / 通知授权说明 | notification-settings, booking, appointment | 开启提醒 | 说明；暂不；继续；拒绝后去设置 | 0 |
| auth-language / 登录语言选择 | auth-login | 登录页语言按钮；源码改动需核对 | 语言列表；选中；取消 | 0 |
| account-confirm / 账号敏感操作确认 | account | 账号页对应操作 | 密码确认；绑定 Google；删除账号；错误 | 0 |
| date-time / 日期／时间选择器 | shared | 各表单日期时间字段，共享实现按上下文引用 | 日历；年份；输入；时钟；校验；取消；确认 | 125 |
| discard / 放弃修改确认 | shared | 修改表单后返回 | 脏草稿；未知保存结果；留下；放弃 | 0 |
| snackbar / 操作反馈条 | shared | 对应操作产生反馈；具体来源保留在证据 | 成功；错误；撤销；自动消失 | 79 |
| tooltip / 控件提示 | shared | 支持提示的图标长按；挂载 Tooltip 不等于提示已显示 | 出现；消失 | 1999 |
| system / 原生系统浮层 | shared | App 操作触发系统 UI；原生证据独立核对 | 键盘；照片／文件选择；通知；相机；麦克风；系统设置 | 0 |
| avatar-dialogs / 数字形象选择与确认 | onboarding, avatar-create, avatar-review | 配置开启时的引导入口 | 照片来源；默认确认；生成交接（等待／进入 App）；生成完成；激活确认 | 4 |
| summary-task-detail / 咨询行动详情 | summary | 本次咨询总结 → 查看怎么做／后续行动卡 | 待完成；进行中；已完成；暂时跳过；更新中；结果不确定／重试；方案替换／重新载入；行动移除／关闭 | 12 |
