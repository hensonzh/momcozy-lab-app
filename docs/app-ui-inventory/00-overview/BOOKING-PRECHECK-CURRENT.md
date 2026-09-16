# 当前预约前确认及可用时段恢复

从正式 App 的 More → Me → 已购计划 → 预约咨询进入。使用现有 GoRouter、BookingPage、BookingPrecheckDialog、BookingController、AppointmentApiRepository 和正式 codec；仅网络、会话与业务数据使用隔离替身。393 px / 1x 和 320 px / 2x 各运行两条操作链，未创建真实预约。

## 实际执行的操作

| 入口或操作 | 到达的界面与结果 |
| --- | --- |
| 首页预约咨询 | 预约上下文加载 → HTTP 503 → 重试成功 → 自动打开预约前确认 |
| 关闭／重新打开 | 关闭回到“先做个预约前确认”，点击开始确认重新打开；结束后返回妈妈首页 |
| 当前所在州 | 打开 CA / NY / TX 下拉菜单；选择 NY 显示不支持提示；改选 CA 清除提示 |
| 服务适用性 | 勾选、取消勾选、重新勾选；缺少任何必要确认时继续按钮不可用 |
| 紧急风险 | 选择“有，或我不确定”显示帮助提示且不能继续；选择“目前没有上述紧急情况”后可继续 |
| 提交确认 | 验证真实请求的 region、service_suitable、emergency_status；挂起时关闭、输入和继续禁用，框架返回不能关闭弹窗 |
| 资格失败 | HTTP 503 → 原表单保留并显示重试提示；继续提交可恢复 |
| 服务端不符合条件 | emergency_help、service_unsuitable、region_not_supported 各自返回对应文案；保留本地已填输入及继续按钮，下一次成功后进入时间选择 |
| 资格成功但时段等待 | 弹窗仍显示正在确认且不能关闭，底层页面已切到时间选择；时段请求结束才关闭弹窗 |
| 时段错误／重试 | HTTP 503 显示在时间选择页；点击重试显示局部加载；空列表显示暂无可选时间；刷新恢复可用和占用时段 |
| 占用时段 | 实际点击已占用时段，无 hold 请求，不产生预约；滚动位置随实际点击保留 |

两条测试链均从底部导航进入，并最终沿返回按钮回到妈妈首页。没有直接调用控制器改变页面，也没有将隔离响应当成真实服务交易。

## 图像审阅与证据

29 个状态、58 份视口、35 张完整长图，10 个状态以长图为主图。93 张 PNG 拆为 209 个连续全宽片段，其中 122 个唯一片段均已审阅：104 个新增片段组成 18 张审阅页，18 个引用此前已审阅且像素一致的片段。

- 表单长图完整覆盖州选择、适用性、风险、错误说明和继续按钮；时间选择长图覆盖专家、时区、日期和全部时段。
- 视口图保留真实操作后的滚动位置；完整长图补齐上下文，不将被滚动遮挡的首屏内容误报为缺失。
- 320 px / 2x 下预约前确认标题分两行，闭合的州选择框只显示 California，完整 California (CA) 可在下拉选项中看到；记录为当前视觉表现。长表单需滚动到继续按钮，完整长图包含按钮。
- 服务端拒绝提示在弹窗和遮罩后的页面均出现，按当前实际布局保留。拒绝后的继续按钮仍可提交，与本地紧急风险选择禁用按钮的行为不同。

[全宽审阅映射](booking-precheck-current-visual-review/sources.json) · [像素／源码／前驱审计](booking-precheck-current-evidence-audit.json) · [采集源码快照](booking-precheck-current-capture-source-snapshot.json)。

## 逐状态入口与图片

| 实际操作 | 图片与运行来源 |
| --- | --- |
| Retry accepted → provider, date and available/occupied times | [状态证据](../08-expert-service/booking-precheck-current-accepted-slots/README.md) |
| Availability succeeds with no slots | [状态证据](../08-expert-service/booking-precheck-current-availability-empty/README.md) |
| Availability HTTP 503 → picker with retry error | [状态证据](../08-expert-service/booking-precheck-current-availability-error/README.md) |
| More → Me → owned plan | [状态证据](../08-expert-service/booking-precheck-current-availability-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-precheck-current-availability-home-return/README.md) |
| Eligibility accepted → availability pending; dialog remains waiting | [状态证据](../08-expert-service/booking-precheck-current-availability-pending/README.md) |
| Complete region, suitability and risk inputs | [状态证据](../08-expert-service/booking-precheck-current-availability-ready/README.md) |
| Refresh booking → available and occupied times | [状态证据](../08-expert-service/booking-precheck-current-availability-restored/README.md) |
| Retry availability → picker loading spinner | [状态证据](../08-expert-service/booking-precheck-current-availability-retry-pending/README.md) |
| Close precheck → start confirmation card | [状态证据](../08-expert-service/booking-precheck-current-closed/README.md) |
| Booking context returns HTTP 503 | [状态证据](../08-expert-service/booking-precheck-current-context-error/README.md) |
| Book consultation → booking context pending | [状态证据](../08-expert-service/booking-precheck-current-context-loading/README.md) |
| More → Me → owned plan | [状态证据](../08-expert-service/booking-precheck-current-controls-home/README.md) |
| Booking Back → Me | [状态证据](../08-expert-service/booking-precheck-current-controls-home-return/README.md) |
| Select emergency or uncertain → urgent help notice | [状态证据](../08-expert-service/booking-precheck-current-emergency-help/README.md) |
| Retry booking context → automatic precheck | [状态证据](../08-expert-service/booking-precheck-current-initial/README.md) |
| Tap occupied time → no hold request and unchanged picker | [状态证据](../08-expert-service/booking-precheck-current-occupied-disabled/README.md) |
| Select no emergency → continue enabled | [状态证据](../08-expert-service/booking-precheck-current-ready/README.md) |
| Current state dropdown → CA / NY / TX choices | [状态证据](../08-expert-service/booking-precheck-current-region-menu/README.md) |
| Select CA → suitable service region | [状态证据](../08-expert-service/booking-precheck-current-region-supported/README.md) |
| Select NY → unsupported region notice | [状态证据](../08-expert-service/booking-precheck-current-region-unsupported/README.md) |
| Start confirmation → blank precheck | [状态证据](../08-expert-service/booking-precheck-current-reopened/README.md) |
| Continue → server ineligible: emergency_help | [状态证据](../08-expert-service/booking-precheck-current-server-emergency_help/README.md) |
| Continue → server ineligible: region_not_supported | [状态证据](../08-expert-service/booking-precheck-current-server-region_not_supported/README.md) |
| Continue → server ineligible: service_unsuitable | [状态证据](../08-expert-service/booking-precheck-current-server-service_unsuitable/README.md) |
| Pending back blocked; eligibility HTTP 503 → retryable notice | [状态证据](../08-expert-service/booking-precheck-current-submit-error/README.md) |
| Continue → eligibility request pending; controls disabled | [状态证据](../08-expert-service/booking-precheck-current-submit-pending/README.md) |
| Check lactation or feeding consultation suitability | [状态证据](../08-expert-service/booking-precheck-current-suitable/README.md) |
| Uncheck service suitability → continue disabled | [状态证据](../08-expert-service/booking-precheck-current-suitable-cleared/README.md) |

## 验证与后续范围

4 项严格截图采集通过，未更新 Golden；`flutter --suppress-analytics analyze --no-pub lib test integration_test` 通过。本次仅新增采集测试与证据，未修改产品代码。当前全仓分析另受咨询页面文档目录的旧代码快照导入错误影响，不将代码目录专项通过表述为全仓通过。

- [严格采集日志](runs/20260914T020033-targeted/capture.log)
- [实际代码及测试静态检查](booking-precheck-current-analyze.log)
- [完整性检查](booking-precheck-current-final-verify.log)

专家切换、日期选择、占位及确认预约、提醒、取消、信息采集和咨询内部流程尚待继续按当前源码实际运行；本批不代表预约全链完成。完整目标保持 **NOT_PROVEN**。
