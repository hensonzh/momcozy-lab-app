# 页面盘点校正

2026-09-12 逐页核对 MorePage 后：

- 移除 `profile/personal` 的错误独立页面登记。设计 MorePage 仅有账号卡；当前与 HEAD 原生 MorePage 均无个人资料弹窗或独立路由。资料步骤仍由 auth/onboarding-profile 覆盖。不是删除已有用户功能。
- `profile/notification-settings` 原先错误关联 MorePage；设计 MorePage 没有通知设置稿。已按用户批准补为衍生规范，仍待页面验收。
- `services/team` 已补精确原生文件映射，之前是空值；对应目录/详情共用的团队弹窗。

- `baby/records` 原先关联 BabyPage，实际独立设计组件为 RecordsPage；已修正源符号，并补拍 `baby/records-viewport.png`。该页仍需单独验收。

- `schedule/task` 原先误记为“专业任务详情与反馈”独立弹窗；PlanPage 实际为行内任务状态菜单，已修正标题与 popover 类型。保留已有查看服务计划入口，不新增虚构任务详情页。新增/编辑/删除实现拆出共享表单文件，映射同时登记关联实现。

- `baby/feeding-saved` 的设计反馈发生在 BabyPage 首页，非记录编辑器内部；已将关联原生页面校正为 BabyHomePage。当前首页只有保存 SnackBar，缺少原稿的保存后撤销入口，继续标记待复核。

- 再核对 RecordsPage 与 /me/diary 路由：RecordsPage 只展示当前宝宝的五类记录，与 `baby/records` 是同一个设计页面；删除误记为“家庭记录聚合”的重复 `mom/records` 行（当前无对应聚合页面）。保留既有参考截图作为历史来源，文档指向宝宝记录。
- 原 `mom/diary-history` 实际映射 MotherDiaryPage，是 /me/diary 独立日记编辑页，未提供历史列表。保留稳定 ID、修正标题，并按用户授权登记为沿用日记组件的衍生设计，仍待独立路由验收。总项数因此减少一项，不代表减少用户 App 功能。
