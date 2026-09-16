# 妈妈首页交付报告 · 2026-09-13

当前工作区的最新验证以 [原始交接任务复核](RECHECK.md) 顶部记录为准：51 项首页专项测试及实际代码与测试目录静态检查通过；6 个核心 Dart 文件格式检查和 19 项资源校验通过。全仓静态检查受咨询页面文档目录中的旧代码快照导入错误影响，未通过。本轮没有重复修改首页业务代码或重新执行原生构建。下文各轮结果为历史记录。

已将本次交付包接入现有用户 App 的 `/me` 首页。初始、有记录、已购服务三种状态已在真实 Flutter 组件与 Android 模拟器上验证。每日记录与服务购买是独立数据维度，已购且无记录也能正常展示。工作台不在本次范围。

## 来源与工程检查

- 用户原始说明：[HANDOFF.md](HANDOFF.md)；原始 ZIP 完整留存于 [original.zip](original.zip)，演示入口没有复制进正式 `main.dart`。
- 当前 Figma：`ePIoJkiMiXiug9ibpcgRbl`，常规 `19:2`、初始 `88:2`、已购 `88:111`。三个节点均取得设计上下文与截图，保存于本目录的 `*-figma.md/.png`。
- Flutter 3.44.4 / Dart 3.12.2；现有 GoRouter、ChangeNotifier、Repository、ResourceState/ProductFailure、运行时 Observability 均继续复用。
- 本次按三状态演示先运行交付包（3 个预览通过），再接入实际 App；未添加业务依赖。
- 资源：交付包三张头像 PNG 与 Figma 导出的 16 个 SVG 持久化在 `assets/images/mom_home/`；[assets.json](assets.json) 记录来源、大小与 SHA-256，不依赖临时网络链接。
- 字体：复用现有 Noto Sans CJK SC Regular；补充官方 Bold 和 SIL OFL 授权文件，仅通过 `NotoSansSCHome` 为首页相关组件注册字重，不改变其它页面字体族。来源为 `notofonts/noto-cjk` 的 `Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Bold.otf` 与 `Sans/LICENSE`。

## 复用与组件实现

- `MotherHomePage` 是现有入口，保留生命周期刷新、跨日刷新和下拉刷新。
- `MomHomeHeader / MomAiInsightCard / MomLactationCard / MomRecoveryStatus / MomExpertPlanEntry / MomHomeSkeleton` 对应交付包组件层级。
- `MomHomeTokens` 集中本次 Figma 特有的渐变、间距、圆角和文字样式；不新增全局主题或另一套导航。
- `MotherHomeController` 继续并行独立读取资料、日记与泌乳数据；`MomHomeViewData` 负责真实数据到页面的投影；新增可注入的 `MomDailyInsightRepository` 边界。
- `ExpertSupportSection / ExpertServiceCard` 继续使用原 CareOverviewController、服务与预约模型；保留已预约、问卷、入会前检查和倒计时逻辑。
- 记录复用 `MotherDiaryEditor`、`LactationPanel`。心情快捷选项只预填草稿，用户保存才提交，不自动产生健康记录。
- 删除旧首页中的静态知识卡、记录选择弹窗和“其它功能”占位入口；它们不再出现在当前首页。旧设计映射单独归档，不把历史截图当成本次证据。

## 数据与状态映射

| 模块 | 现有来源及处理 |
| --- | --- |
| 问候/阶段 | profile 的 displayName、deliveryDate 与本地日期；复用产后阶段规则，无分娩日期显示“陪伴每个阶段” |
| 今日泌乳 | `/v1/lactation/records` → LactationDaySummary，按当前用户和日期汇总测量量、泵奶/亲喂次数；只有亲喂时显示分钟或次数 |
| 今日状态 | `/v1/mother/diary` → body.energy、discomfortSites/impact、rest.total/recovery、mood.tone；分组缺项独立显示待记录，不因有泌乳就假定三组均完成 |
| 休息对比 | 对比前一天的真实时长区间；无精确时长时不生成“多睡 1 小时” |
| 心情快捷项 | 低落/紧张/波动归入“不太好”，unclear 对应“一般”，steady 对应“不错”；卡片同时保留真实枚举文案 |
| 每日洞察 | 尚无正式 API；等待首次记录、生成中、已生成、不可用分别建模。生产无适配器时明确不可用，点击仍可打开 Cozymate 对话上下文 |
| 专家入口与计划 | `/v1/care/catalog` + `/v1/care/overview`；始终保留服务总入口。计划名称、专家姓名、状态、剩余次数来自真实目录/episode，支持期限优先按 endsAt 计算 |
| 预约 | 复用现有 booking context/appointment 数据及路由；暂停、过期、次数耗尽不能新预约，仍可查看进度；已有预约入口保留原检查 |
| 图片 | 正式页使用目录姓名与单人占位图；portrait ImageProvider 注入点支持缓存图片提供器，并处理加载与解码失败。Jamie Lee 仅在测试 Mock 中使用 |

首帧骨架、局部错误与重试、部分数据、缺分娩日期、分析生成中/失败、记录保存后分析失效并刷新、已购无记录、失效服务、头像失败均有处理。目录缺少某个已购套餐时保留该计划的资料重试与服务进度入口，不静默丢弃购买记录。

## 路由、回调与埋点

| 入口 | 行为 | `feature.event` 的 action（feature=`mom_home`） |
| --- | --- | --- |
| AI 卡 | 复用 onAsk → Cozymate，预填今天状态的问题，用户自行发送 | `mom_home_ai_insight_click` |
| 记录一次泌乳 | 现有新增泌乳弹窗，保存后刷新 | `mom_home_lactation_record_click` |
| 查看记录 | `/me/lactation` 现有历史/趋势页，返回刷新 | `mom_home_lactation_trend_click` |
| 今日状态及身体/休息/心情 | `/me/diary` 或对应现有快速记录编辑器 | `mom_home_recovery_click` |
| 专家陪伴计划 | 现有服务目录路由 | `mom_home_expert_plan_click` |
| 服务进度 | 当前 episode 的服务详情与时间线 | `mom_home_service_progress_click` |
| 预约咨询 | 当前 episode 的预约流程与现有可用性检查 | `mom_home_consultation_book_click` |

埋点不附带日记内容、情绪、奶量、用户姓名等敏感值。底部导航直接复用 MomCozyBottomNavigation 与原路由。

## 视觉核对与合理差异

Figma G1/G2–G4/G5：PASS（G5 包含以下明确披露的适配差异）。已核对三份 Figma、393 宽金图与 Android 实际截图：顺序、16 左右边距、14 主间距、渐变、导出装饰、单人/多人头像用途、固定底部导航一致。

- 设计中的部分 30–38 高按钮扩展为至少 44dp 点击区；标题附近间距相应调整。大字与窄屏自动增高、换行、双列改为纵向，避免裁切。
- 当前真实身体状态只有枚举，显示“有力气”等，不虚构 70% 恢复分。休息数据是区间，显示 4–5 小时等，不虚构精确小时差。
- 已购 Mock 套餐名称采用当前 Figma 的“新手妈妈开奶陪跑计划”，而非 ZIP 的旧示例“奶量管理”；正式页显示实际购买的套餐。
- 常规 Figma 与 ZIP 的记录值存在差别；数据由 Repository 决定，三种 Mock 核心状态使用交付包业务样例，均不作为用户真实记录。
- 正式 AI 文案及专家头像受接口缺项影响，明确使用不可用状态/单人占位；截图中的生成结论和 Jamie 头像来自测试注入。
- 底部五项导航、已有服务预约后的附加信息按当前产品流程保留，不在本页创建设计稿专用的第二套导航。

## 尚需业务接口补齐

1. 每日洞察 API：生成状态、日期、生成时间、detailId、数据更新后的版本约定。现有注入接口与测试 Mock 可运行，生产默认未对接。
2. 专家目录目前没有头像资产及资质字段。需要业务授权的真实头像和资源/缓存契约；现有 App 资产流水线接受 `/v1/assets/:id`，没有擅自添加任意 CDN 域名。已知 IBCLC 专家显示其角色；其它详细资质不编造。
3. 若要展示恢复百分比、精确休息时长变化，需要后端提供相应真实字段或经确认的计算规则；现有展示如实使用枚举与区间。

上述缺项不阻塞 Mock 验收及当前真实记录/购买/预约流程；不声称这些缺失接口已经上线。

## 验证与复现

详细日志和原生截图保存在 [evidence](evidence/)。三状态测试不写入真实账号健康记录或购买数据。

```sh
flutter pub get
flutter test test/modules/mom/mom_home_handoff_test.dart --no-pub
flutter test --no-pub --reporter expanded
flutter analyze
flutter test integration_test/mom_home_handoff_test.dart -d emulator-5554 --flavor local --no-pub --no-uninstall
```

本机工具链位于 `/Users/lute/.local/share/momcozy-toolchains/`；原生运行使用 Java 17、Android SDK 与 local flavor，完整环境见现有本地启动说明。本次还修复了记录日期选择器没有传递已注入时钟的问题，使“今天”高亮遵从记录时区，避免跨日导致的 3 张既有金图漂移。

全仓格式检查首次发现既有格式差异，已按交接文档要求执行 `dart format --set-exit-if-changed .` 统一格式；额外涉及的文件仅格式调整，在变更清单中单独标记。原有未提交功能改动保留。

验收结果及变更文件明细在本报告末尾记录。

## 最终检查结果

- 交付包 Demo：3 个预览通过。
- 新首页专项：29 项测试；连同既有首页路由回归共 37 项通过，含 36 张三状态/三宽/双字号金图。
- 全量 `flutter test --no-pub --reporter expanded`：**1752 通过，6 项既有跳过，0 失败**（59 秒）；日志保留跳过原因。
- Android integration：三状态 × 1x/2x，主要入口点击与埋点通过；保存 12 张原生截图，测试步骤运行 18 秒。
- `dart format --set-exit-if-changed .`：**831 文件，0 changed**；生成的 iOS vendor 目录中一条 analysis_options 路径警告不影响成功退出。
- 真机范围：已验证 Android 模拟器；未声称执行实体 iOS/Android 真机或生产支付、专家预约端到端交易。

## 文件清单

逐文件变更类型与 SHA-256 见 [changed-files.json](changed-files.json)，只列本任务相对开始时快照的差异，区分新增、修改及单纯格式调整。参考稿、截图、日志与原始 ZIP 均在本目录，不覆盖先前页面证据。

主要代码：

- `lib/app/mom_module_routes.dart`
- `lib/shared/design_system/mom_home_tokens.dart`
- `lib/shared/widgets/date_time_picker.dart`
- `lib/shared/widgets/zoned_datetime_field.dart`
- `lib/modules/services/presentation/expert_support_section.dart`
- `lib/modules/mom/application/mother_home_controller.dart`
- `lib/modules/mom/application/mom_home_view_data.dart`
- `lib/modules/mom/presentation/mother_home_page.dart`
- `lib/modules/mom/presentation/mother_diary_editor.dart`
- `lib/modules/mom/presentation/mom_home_sections.dart`
- `test/support/input_confirmation_scenarios.dart`
- `test/support/momcozy_test_fonts.dart`
- `test/support/mom_home_handoff_scenarios.dart`
- `test/modules/mom/mom_home_handoff_test.dart`
- `test/modules/mom/mother_home_test.dart`
- `integration_test/mom_home_handoff_test.dart`

资源：19 张首页 PNG/SVG，Noto Sans CJK SC Bold 与许可证；pubspec 登记。金图覆盖首页及共享专家服务卡受影响场景。另更新页面映射与生成脚本，避免重新生成清单时恢复旧首页参考。

- 最终 `flutter analyze --no-pub`：**No issues found**。格式化后显露的三处 if 大括号 lint 已补齐，仅风格调整。
- 常规本地 debug APK 构建通过（Gradle 15 秒），安装后已冷启动验证 Mia 的新首页；仍使用真实本地 API 与原登录会话。截图见 [live-home.png](evidence/live-home.png)。
- 主 App `flutter pub get`：成功；未升级依赖约束。
- 实际账号路由补验：从首页进入真实泌乳历史/趋势、身体记录编辑器、专家服务目录均成功，未提交测试健康记录或购买；最终返回 Mia 首页。证据为 `live-lactation`、`live-diary`、`live-catalog` 截图与 UI XML。


## 当前工作区复核

再次读取用户指定的 Downloads 原始 MD 和 ZIP，其 SHA-256 与本目录归档完全一致；本轮确认已有实现，未重复接入或覆盖其他未提交修改。

- 当前首页专项复跑：`flutter test --no-pub test/modules/mom/mom_home_handoff_test.dart test/modules/mom/mother_home_test.dart test/modules/mom/mom_home_inventory_states_test.dart --reporter expanded`，**51 项通过，0 失败**。包括三状态、320/360/393 宽度、1x/2x 字号、记录保存刷新、局部失败、缺少分娩日期、服务不可预约和头像兜底。
- 当前 `flutter analyze --no-pub`：**No issues found**。
- 资源清单 19 个文件逐一校验 SHA-256，全部一致。
- 本次日志：[专项测试](evidence/recheck-tests.log)、[静态检查](evidence/recheck-analyze.log)。上文全量测试和 Android 验证为此前已完成的执行记录，本轮没有重新执行原生构建或全量测试。
- 每日洞察正式 API、真实专家头像及详细资质字段仍按上文列为接口缺项；没有将 Mock 标记为生产能力。


## 最新输入复核结果

本轮读取 Downloads 中指定的 MD 与 ZIP，SHA-256 与本目录归档一致。已有首页实现满足交接中的客户端接入范围，本轮未重复改写首页代码，也未修改其它任务的业务代码。

- 首页专项：**51 项通过，0 失败**，包含三状态、320/360/393 宽度及 1x/2x 字号，日志见 [current-tests.log](evidence/current-tests.log)。
- 首页相关代码及测试静态检查：**No issues found**，见 [current-scoped-analyze.log](evidence/current-scoped-analyze.log)。
- 核心首页的 6 个 Dart 文件格式检查：0 changed，退出码 0。
- 当前全仓静态检查退出码为 1：`test/support/service_inventory_transport.dart` 第 119、235 行有 2 条 `curly_braces_in_flow_control_structures` info，属于服务清单测试辅助代码。本轮未修改这些文件，不能将全仓检查记为通过。见 [current-analyze.log](evidence/current-analyze.log)。
- 资源清单中的 19 个首页图片 SHA-256 全部匹配。重新查看了已购态 393 px 基准截图，服务总入口与我的陪伴计划同时展示，固定导航正常。
- 本轮没有重新构建或执行原生测试；前文 Android 模拟器截图及验证属于此前完成的记录。每日洞察正式接口、专家头像与详细资质字段仍按上文披露，生产环境未将 Mock 当作真实数据。
