# IBCLC 独立入口

本模块仍在产品基线重构中。当前可用入口包括两步登录、今日预约、今日跟进、周日程、客户搜索/筛选/多服务详情、工作提醒、咨询前资料、共享咨询室、报告来源与专业复核，以及专业记录/护理方案编辑与发布。用户可见反馈及完整服务闭环还在实施，不能将当前入口视为全部工作台验收完成。

## 本地运行

先启动 Product Backend，应用数据库迁移，并按 [工作台身份配置](../../backend/docs/workbench-auth.md) 为已有专家账号配置认证器。浏览器入口需使用同源代理，或在后端明确设置 `CORS_ALLOWED_ORIGINS=http://127.0.0.1:5173`。

```sh
flutter pub get
flutter run -d chrome -t lib/main_ibclc.dart \
  --web-hostname=127.0.0.1 --web-port=5173 \
  --dart-define=MOMCOZY_API_BASE_URL=http://127.0.0.1:8769
```

构建静态 Web 资源：

```sh
flutter build web -t lib/main_ibclc.dart --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=MOMCOZY_API_BASE_URL=http://127.0.0.1:8769
```

`--pwa-strategy=none` 在当前 Flutter 版本中已标记废弃，但仍用于明确关闭生成的离线服务工作线程；升级 SDK 时需检查替代方式。构建产物位于 `build/web`，运行时采用 hash 深链。部署需配置真实 HTTPS API 地址；本任务未部署云端。

工作台使用独立的令牌/设备存储命名空间，不初始化妈妈端运行环境，也不创建虚拟宝宝。原生妈妈入口仍是 `lib/main.dart`。

## 结构与数据

- `app/ibclc/` 负责独立运行环境、身份路由和响应式工作区。
- `modules/ibclc/` 负责登录、队列、客户资料和专业记录；咨询房间复用 `modules/consultation/`。
- `domain/care` 与 `domain/ibclc` 是共享业务模型。`services/ibclc` 将当前后端 DTO 转成领域对象。
- 工作台只读取当前专家的分配范围；病例资料另需用户授权。授权错误会清除本地页面数据，用户退出后旧请求不能把资料交给新会话。
- 列表每 30 秒及恢复前台时重新读取，分页/筛选请求采用版本标记，过期响应不能替换当前结果。
- 今日跟进按客户汇总当前多个服务，全部完成当天复核才标为已跟进；搜索命中一个套餐仍保留同一客户的其他服务。历史日期没有报告时显示待汇总，不自动生成完成状态。
- `/ibclc/followups/{patientRef}?episode={episodeId}&date=YYYY-MM-DD` 可重载服务与日期。报告每 15 秒刷新，展示来源摘录、真实问答、资料缺口及复核记录。确认或意见始终绑定打开时的报告和复核版本，旧意见不能提交到新报告。
- 病例与 AI 授权必须同时有效。报告内容是专业待复核资料，私人意见不直接发给用户；生成服务配置见 [报告运行说明](../../backend/docs/care-reports.md)。
- 周日程按专家 IANA 时区加载完整一周，排除取消预约，跨午夜按时间重叠显示。日间范围会扩展以包含早晚预约；夏令时切换周使用带时区的日期列表。月份导航和窄屏日期列表采用同一数据集。
- 工作提醒来自共享服务事件，支持分组、分页、未读统计和持久化已读；链接会重新加载当前客户/咨询资料。只有服务仍分配给当前专家时才能读取或标记。
- 只有明确的 HTTP 401 会触发同一会话的单次令牌刷新重试；网络失败不会自动重发写操作。签署与发布沿用专业记录模块的幂等键和并发版本。

## 已完成的局部验证

- 工作台、专业记录、咨询总结和共享网络层共 65 项 controller/widget/transport 回归通过。
- 1024/1280px 预约、客户、日程、工作提醒、跟进列表、报告与复核区已有截图；390px 两倍文字下可使用导航、月份切换、已读和复核操作。图片在 `test/goldens/product_baseline/ibclc-*`。
- `flutter analyze --no-pub` 通过；`flutter build web -t lib/main_ibclc.dart` 构建通过，Chrome 已验证真实本地后端的密码/TOTP 登录、会话重载和预约读取；测试数据均为合成病例。另已验证客户/Intake 深链、朗读节点和退出清除；临时服务与浏览器页面已关闭。
- 完整验收与剩余项目见 [产品基线清单](product-baseline-refactor.md)。
- 报告接入后重新完成 `analyze` 与独立 Web 构建；Chrome 使用隔离 PostgreSQL 合成病例，验证密码/TOTP 登录、提醒→服务/日期报告深链、查看泵奶来源、保存反馈、整页重载后的复核恢复与退出清除。临时 API、静态服务器、标签页和测试凭据已清理。该验证不代表真实模型质量验收。
