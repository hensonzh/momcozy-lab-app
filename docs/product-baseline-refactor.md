# Momcozy Lab 产品基线重构

状态：本地产品基线重构完成（2026-09-09）。本文记录可复核的实现证据；云端部署、真实支付/视频供应商和医学质量评测仍需独立验收。

## 设计依据与优先级

原稿位于 `../momcozy-lab产品设计`（相对于 `momcozy-lab/` 的同级目录）。
2026-09-08 核对了 PRD、架构文档、HANDOFF、React 页面/领域类型、已批准视觉系统及最近截图。
原稿不是 Git 仓库。发生冲突时，以当前可运行页面和最新专项验收为准，再参考 PRD 的业务约束。

- `src/pages/UserApp.tsx`、`src/components/MeOverview.tsx`：妈妈端页面与行为。
- `src/pages/Workbench.tsx`：专家端页面；最新一级导航包含今日预约、今日跟进、我的日程、我的客户、工作提醒。
- `src/types.ts` 与 `src/features/consultation/`：对象关系及服务状态。标注 legacy/deprecated 的字段不迁移。
- `产品需求文档-React-Web-UI优先MVP.md`：服务包、状态机、权限、发布、异常恢复及路由验收。
- `产品架构-APP与IBCLC工作台.md`：共享服务与角色职责。
- `me-ui-optimization/02-approved-system/生活陪伴型-design-system.md`：暖色表面、深棕主操作、语义状态色。
- `me-agent-style-sync/online/`、`baby-me-style-sync/images/`：最新 Me/Baby/Cozymate 与工作台渲染基线。

本次是页面旅程、领域模型和工程结构重构。原生 Flutter 是当前产品载体，
不会把 React 的巨型页面或浏览器本地业务 store 原样搬进 Flutter。
专家工作台采用独立 Flutter 入口与响应式工作区，复用 Dart 领域和数据访问层。
后端沿用 Product Backend；Agent Runtime 继续只负责智能体执行。
实施、验证和本地预览在本任务内；付费供应商接入、真实医疗服务上线和云端发布不是本任务的隐含完成条件。

## 当前工程盘点

工作区有三个独立 Git 仓库：`app/`、`backend/`、`agent/`；父目录不是 Git 仓库。
开始时三个仓库的现有状态以各自 `git status` 为准。App 起点为 `9d17834a`，Backend 为 `2395ef4`。
初始 App 静态检查：`flutter analyze` 通过（2026-09-08）。

| 现有位置 | 状态 / 问题 | 处理 |
| --- | --- | --- |
| `app/momcozy_app.dart`（1836 行） | 初始化、路由、导航、主题、页面分发混合 | 拆为 bootstrap、母端路由/壳、专家路由/壳、共享主题 |
| `features/app_pages/momcozy_feature_pages.dart`（6708 行） | 设备、商品、咨询演示、媒体及公共 UI 混合 | 按新产品用途拆分；移除废弃页面 |
| `features/profile_overview/` | 妈妈/宝宝页面共用巨大 controller，包含旧阶段和数据回显别名 | 独立 mom/baby 模块，共享档案和记录模型 |
| `features/plan/` | Plan dashboard 与旧泌乳计划呈现 | 已删除；由 `modules/schedule` 月历聚合预约、专业任务、个人日程 |
| `features/more/` | Body Profile 代替我的，底栏禁用 | 已删除；`modules/profile` 提供账户、服务资产、通知、隐私和退出 |
| `features/agent_hub/` | 可用 SSE、附件、语音和结构化卡片；咨询保存在本地 store | 复用传输/控制能力，统一视觉与服务入口；咨询事实改由 Product Backend 提供 |
| `features/records/` | 部分模型含旧 milk components、测量场景；宝宝睡眠/尿布缺少可用后端 | 统一事件模型、补字段及 CRUD，按妈妈/宝宝作用域隔离 |
| `features/onboarding/` | 邀请登录、最小资料能力可复用；头像与后置阶段混入主路径 | 保留认证和必要资料，按新基线精简入口 |
| `core/auth`、`core/network`、`core/agent_stream` | 安全存储、刷新、错误、流式恢复已存在 | 复用并清除因新流程废弃的适配 |
| Backend `profiles/records/plans` | 已有所有者权限、持久化、审计与 OpenAPI | 在业务域内演进，不让页面拼接旧 DTO |
| IBCLC 工作台 | 当前 Flutter 不存在 | `main_ibclc.dart` 独立模块与入口，共享服务、记录、报告、权限契约 |

## 保留 / 重构 / 新增 / 删除

保留认证与会话刷新、受控网络、Agent 流式事件与附件/语音基础、媒体资源、
现有后端用户/宝宝身份、审计与迁移机制，以及符合设计的 Momcozy/Cozymate 资产。

重构五个用户入口及其导航、全部状态/表单、共享档案/记录/服务数据、
日程与专业任务关系、服务推荐跳转、前端缓存归属和 OpenAPI 客户端映射。

新增妈妈每日休息/身体/心情日记、单侧泌乳事件、宝宝完整照护记录、
服务包→适用性→订单/权益→预约→Intake/Consent→咨询→报告/任务→跟进/转介闭环，
以及 IBCLC 预约、每日跟进、日程、客户档案、AI 报告、私密记录、方案发布和工作提醒。

删除新基线不使用的商品演示、社区占位、内部设备参数入口、旧 Body Profile 主入口、
旧计划页面、旧阶段示例内容、`ibclc-chat.html` 本地咨询页与持久化、
旧兼容字段/解析别名及仅保护废弃行为的 fixtures/goldens。设备和媒体只保留设计中仍可达且真实可用的能力。
删除必须同时处理路由、调用方、测试、资源声明和接口消费者，不能只隐藏入口。

## 目标结构

```text
lib/
  app/                       # 母端 bootstrap、router、shell；专家独立入口装配
  core/                      # 认证、网络、平台、日志、流式基础设施
  domain/
    shared/                  # 日期、分页、版本和通用错误
    mother/                  # 母亲档案、结构化每日自述
    baby/                    # 宝宝档案与照护事件
    lactation/               # 妈妈单侧泵奶 / 亲喂事件
    care/                    # 商品、订单、权益、周期、预约、Consent、方案、任务
    ibclc/                   # 专家分配、工作队列、AI 报告、私密记录、跟进
  services/                  # DTO ↔ domain、API repository；禁止依赖页面
  shared/                    # 设计令牌、表单、空/错/加载状态、可访问性原语
  modules/
    mom/ baby/ schedule/ profile/ services/ consultation/
    ibclc/
      appointments/ users/ reports/ services/ follow_up/
  features/agent_hub/         # 可复用现有智能体能力，按需要继续拆分
  main.dart                  # 用户 App
  main_ibclc.dart             # 专家入口
test/                        # 领域、repository、controller、widget 与渲染验证
```

使用当前 ChangeNotifier/controller 的主状态模式，不在本次引入第二套状态库。
`app → modules → domain`；`services → domain/core`；`shared` 不反向依赖页面。
同一业务对象只在 `domain` 定义一次，IBCLC 不复制妈妈或宝宝模型。
后端在 `modules/mother`、`records`、`care`、`ibclc` 中承载业务；身份来自已认证会话。

## 核心模型与不变量

| 对象 | 权威字段与关联 | 规则 |
| --- | --- | --- |
| MotherProfile / BabyProfile | 用户 ID、真实分娩日期、宝宝 ID/出生日期/性别 | 不保存冗余月龄/产后天数；按日期计算，未知保留空值 |
| MotherDiaryEntry | 母亲、日期、rest/body/mood、版本 | 每人每天一条；分组部分更新；没有旧整体自述或健康评分 |
| LactationRecord | 母亲、事件 ID、发生时间、pump/nurse、left/right、实测量或时长、感受、备注 | 单侧；亲喂不折算 ml；未知量与 0 不混淆；汇总由事件派生 |
| Baby care records | 宝宝 ID、喂养方式/实测量/亲喂时长、睡眠起止、尿布、单指标生长与行为观察 | 母亲泵出量不作为宝宝摄入；切换宝宝隔离数据；事件可编辑、删除/恢复 |
| ServicePackage / Order | 稳定商品 ID、周期、次数、价格币种；订单状态、幂等键 | 当前仅 3/7/14 天四种设计套餐；沙盒支付结果明确 |
| CareEpisode / Entitlement | owner、baby、package/order、专家、起止、状态、剩余次数、版本 | App 和工作台读取同一周期；终止/完成规则由后端决定 |
| Appointment / Consultation | episode、专家、时间/时区、Intake/Consent、房间、参与者与结果 | 用户离开不结束；只有 assigned IBCLC 可开始/结束；正常完成最多扣减一次 |
| Intake / Consent | 预约、主诉、目标、版本化授权 scope、提交/撤回时间 | 撤回影响后续读取和入场；病例分配不自动等于获得全部字段权限 |
| AIReport / ClinicalNote | episode/consultation、来源、生成状态、内容、review、签署版本 | AI 是待复核草稿；私密 Note 不出现在用户接口；已签署不可原地覆盖 |
| CarePlan / CareTask | episode、publication/version、目标/观察/升级条件、稳定任务源键 | 发布需签署记录；重复发布不复制任务；用户仅反馈执行状态 |
| FollowUp / Referral | 同一 episode、日期、专家反馈、状态、去向 | 可回溯同一服务，不建立孤立副本；工作提醒只含专家事件 |

DTO 只识别当前 snake_case 契约。原稿的 `baby`/`babies` 别名、`order`/`orders` 快照、
legacy sleep、双侧泌乳总量/拆分字段、旧喂养组件和 old route aliases 不作为新基线保留。
展示分组和时间线投影在 domain/application 层完成，页面只处理输入和显示。

## 实施和验收清单

所有未勾选项均是剩余工作，不能以文档或单测替代页面/接口完成。

- [x] 找到原稿，梳理当前页面/组件/模型/结构，完成四类改造清单。
- [x] 写出目标模块边界、共享模型及状态不变量。
- [x] 共享日期、身份、妈妈日记、泌乳、宝宝事件模型；清除旧字段。
- [x] 共享商品/订单/周期/预约/授权/咨询/报告/任务/跟进模型及 REST 契约。
- [x] 后端模型、迁移、权限、幂等、审计和接口；App/Agent 消费者同步。
- [x] 新视觉令牌、五入口导航、独立专家壳和入口、深链与返回。
- [x] Me：四个状态卡、知识、日记记录与历史、泌乳 CRUD、专家支持/服务进度。
- [x] Baby：档案切换、睡眠/尿湿/便便/喂养、成长曲线/记录、发展观察。
- [x] Cozymate：原稿视觉、历史、流式/停止/重试、附件、语音、服务推荐。
- [x] Schedule：月历、预约/专业任务/个人日程、日期筛选、任务反馈。
- [x] More：真实账号信息、订单/服务、通知/授权与退出。
- [x] 服务：四套餐、适用性、支付沙盒恢复、预约/冲突/取消/重约、Intake/Consent。
- [x] 咨询：准备/设备/所在地/授权、等待/加入/重连/离开/专家结束及异常结果。
- [x] IBCLC：今日预约、每日跟进、日期/时间日程、客户搜索/筛选/详情、多服务关系。
- [x] IBCLC：AI 报告来源/复核、私密 Note 草稿/签署/版本、Care Plan 预览/发布。
- [x] 双端：同一服务和宝宝数据、任务执行反馈、持续跟进、总结/续购/自主管理/转介。
- [x] 清理旧页面、路由、状态、兼容 DTO、无引用资源及旧测试；历史服务端模块已标记 `deprecated_api`，新客户端不依赖。
- [x] 验证空/加载/错误/权限/离线/冲突/成功/恢复，不能用假成功或样例数据替代。
- [x] Dart format/analyze、领域/controller/widget、后端契约/迁移/越权与双端闭环测试。
- [x] 实际渲染与原稿比对：320/390/430px 用户端、1024/1280px 工作台、长文/大字/键盘。
- [x] 逐项完成最终证据审计，README、运行方式、变更与剩余限制同步。

每一步完成后在本文追加命令、结果和可定位证据。当前代码、契约和测试均已同步到本地可复核状态。

## 实施证据（2026-09-08，持续追加）

### 每日跟进与报告（最新）

- Runtime 内部来源/结构化生成契约、Product 的持久化报告 worker 与复核版本、Flutter 多服务跟进列表与报告详情已接通。来源范围同时受病例授权、AI 授权与显式服务对话关联限制；私人 SOAP 不作为模型输入。
- 不同来源生成新版本；两个 worker、过期租约、三次有界重试、迟到结果/撤回丢弃、多服务状态、并发复核冲突均有真实 PostgreSQL 测试。生成提醒随业务事务写入，复核意见不作为用户通知。
- 工作台/共享网络 65 项测试通过；后端 OpenAPI、迁移、Runtime 契约、专用客户端和交付配置 31 项检查通过。Runtime 报告/请求边界 24 项检查通过；八项离线合成评测通过，尚未执行真实模型医学质量评测。
- 1024/1280px 跟进、报告、复核区渲染已目视检查；390px 双倍文字、反馈校验、授权拒绝清除与日期深链有验证。独立 Web 重建通过，Chrome + 隔离 PostgreSQL 已验证报告来源、反馈保存和重载恢复。
- 新配置和运行说明在 `backend/docs/care-reports.md`、`agent/docs/care-report-evals.md`；未部署云端。宝宝来源已接入，按服务关联宝宝和所有者过滤；妈妈端显式服务对话入口、用户可见服务反馈与阶段闭环已通过当前本地验收。

- `lib/modules/mom`：新首页、三组日记编辑、单侧泌乳记录列表/编辑/删除恢复与 7/30 天图表已接真实 repository。首页保存后刷新，未知量和实测 0 分开。
- `lib/modules/services`：四个服务包、适用性、沙盒订单/支付恢复、预约和信息采集、咨询总结、基础服务进度；订单、周期和发布方案由后端保存。持续跟进和服务时间线已接入工作台及服务进度页面。
- `lib/shared/design_system` 和独立底栏：采用原稿暖色、字体、知识渐变及五入口。旧入口已替换为当前五入口壳，公共页面保留真实加载、错误和空状态。
- Flutter `analyze --no-pub` 通过；`lactation_test.dart` 10 项、`mother_home_test.dart` 5 项、`service_purchase_test.dart` 7 项通过。320/390/430px 渲染在 `test/goldens/product_baseline`；全局大字和工作台验收已纳入本地回归及最终审计。
- Backend 新增 `mother`、`lactation`、`care` 业务域，含所有者隔离、版本冲突、创建幂等、软删除恢复、沙盒支付原子创建周期。新的三个迁移已实际应用到隔离的 PostgreSQL 测试库。
- `tests/test_care_purchase.py`、`test_lactation_records.py`、`test_migration_smoke.py` 共 16 项通过；早先妈妈日记、OpenAPI 与迁移组合 27 项通过。本轮新增接口已重新导出并检查契约。
- 本地数据库仅用于迁移与并发验证，采用 [PostgreSQL 官方源代码](https://www.postgresql.org/ftp/source/v16.15/) 编译，监听 loopback，数据位于临时目录；未部署云端或修改既有数据库。

### 宝宝档案与五类记录（已完成本地验收）

- 后端已建立五类记录的严格契约、按宝宝隔离、真实时间/日历日期、版本编辑、删除恢复和幂等批量保存。生长/发育不构造虚拟测量时间；同一宝宝最多一条活动睡眠。
- 宝宝档案移至 `baby` 业务域，新 `/v1/babies` API 与 `BabyProfileRead` 共用于 App 和咨询资料；迁移保留 ID/外键，删除旧出生体重、出生孕周及旧档案入口。AI 档案工具、上下文和类型同步收敛。
- 本地 PostgreSQL 已升级至 `20260908_0014`，Alembic 差异检查通过；相关后端 49 项、Flutter 档案/记录/咨询资料 13 项测试通过。App 解析夹具来自实际隔离数据库的合成响应。
- WHO 12 份官方工作簿的 252 个参考值已与产品稿逐项核对，数据和来源哈希在 `docs/baby-growth-reference.json`；使用真实日历月份，超出默认范围的测量扩展坐标轴。宝宝档案编辑的保存重试/冲突及 320/390/430px 双倍文字测试已通过。
- Baby 首页、照护表单/历史/WHO 曲线界面和旧 Flutter 档案入口清理已完成；细节见 `backend/docs/baby-records.md`，并已由最终 App 回归覆盖。

### 预约与信息采集

- 真实路由 `/services/episodes/:episodeId/booking` 与 `/services/appointments/:appointmentId/intake` 已接入购买后的旅程。
- `domain/care/appointment.dart` 与 `intake.dart` 同时供妈妈端和后续工作台使用。后端 `appointments` 与 `consultations` 分开承载日历/预约和咨询准备/授权。
- 预约前确认、专家与日期选择、10 分钟占位、确认、取消/重新预约、未确认提交的幂等重试已实现。时区来自专家 IANA 配置；夏令时跳时和重复小时均有测试。Flutter 使用 [timezone 官方包](https://pub.dev/packages/timezone) 显示实际时区时间。
- 信息采集表关联真实宝宝与预约，存储出生/分娩日期，不保存派生产后天数、月龄标签或客户端风险等级。每次提交追加版本，重约可带入旧内容但要重新确认。
- 授权按服务和 scope 保存版本历史。仅被分配的 IBCLC 能读取获授权表单；撤回阻止后续读取，旧保存重试不能重新授权。视频授权独立于“允许查看此表”。
- PostgreSQL `alembic upgrade head` 到 `20260908_0006` 和 `alembic check` 均通过；无模型与迁移差异。真实并发测试验证同一时段只有一个占位成功、确认重试/取消不扣次数、占位过期和私密日程冲突；预约与信息采集共 7 项后端测试通过。
- Flutter 预约 8 项、信息采集 7 项通过；相关 320/390/430px 截图已生成并目视核对。妈妈/服务/领域/设计令牌聚合测试 54 项通过，`flutter analyze --no-pub` 通过。

### 咨询房间与设备检查

- 预约详情已接 `/services/appointments/:appointmentId/room`，房间单独放在 `modules/consultation`，供妈妈和专家入口共同使用。
- 已接入显式视频授权、当前位置确认、设备检查、等待室、加入/重连/离开、专家开始/结束及未到场/技术失败等结果。妈妈端咨询结束后进入本次咨询总结。
- Flutter 使用 LiveKit `2.12.0`；设备预览只在点击后申请权限，不发布至远程房间，关闭后释放资源。界面明确区分真实媒体和无音视频的沙盒流程。
- 后端新增咨询、参与者、所在地检查、次数消费与持久化房间命令。用户离开不会改变咨询状态；正常完成原子扣减一次，其他结束原因不扣减；撤回授权关闭媒体，恢复后使用新的房间名称。
- `20260908_0007` 已在独立本地 PostgreSQL 上完成升级与差异检查。新增房间与媒体/迁移测试通过；预约、信息采集、房间、OpenAPI、迁移和 Compose 约束组合 39 项通过。房间的真实双端媒体验证单独记录，不能用沙盒测试替代。
- Flutter 咨询模块 16 项通过；妈妈/服务/咨询/领域/设计令牌/五入口大字导航聚合 73 项通过，`flutter analyze --no-pub` 通过。新增 320/390/430px 准备和等待室截图已目视检查；320px 的 2 倍字体、离开确认、页面重建不换连接有行为测试。
- LiveKit 服务端 `v1.13.6` 已从官方源代码在临时目录编译，仅监听本地 loopback。`test_care_livekit_integration.py` 真实连接测试通过：两端均收到合成音视频，专家开始前核对真实参与者，结束后 durable worker 关房并断开两端，次数仅扣一次。使用 Python RTC `1.1.18`；未使用真实摄像头、未验证外网网络质量，测试后已停止临时 LiveKit 服务。未部署云端。

### 专业记录、方案发布与用户总结

- 后端 `modules/documentation` 和 Flutter `domain/care` 共享专业记录、修订、方案草稿、发布快照和任务进度。私密 SOAP 内容仅通过被分配且获授权的 IBCLC 接口读取；妈妈端 DTO 只含其预约、服务和发布方案。
- SOAP 草稿有并发版本；签署后不可原地编辑，修订必须说明理由并生成新记录。草稿版本与修订号同时校验，旧标签页不能覆盖新修订。授权撤回后，旧读取和幂等重放同样被阻止。
- 发布要求当前 SOAP 已签署、方案完整。重复请求只生成一个发布版本与任务集合；后续版本保留内容未变化的任务进度，旧发布快照保持不变。首次发布启动服务周期，后续发布不重置服务期限。
- `modules/ibclc/documentation` 提供专业记录与护理方案编辑、签署确认、修订理由、版本查看及发布预览；独立工作台入口和列表已接通。妈妈端 `/services/appointments/:appointmentId/summary` 展示总结、任务、目标、真实服务期限与剩余次数，并可反馈任务进度。
- 网络结果未确认时冻结原始提交及幂等键；仅刷新失败时不重发已确认的操作。发布版本过期的任务反馈要求重新读取方案。
- `20260908_0008` 已在隔离 PostgreSQL 升级，`alembic check` 无差异。专业记录、预约、信息采集、房间、迁移组合 19 项通过；新增 Flutter controller/API/widget 16 项通过，包含 2 倍文字的反馈操作。
- 妈妈端 320/390/430px 总结和工作台 1024/1280px 专业记录/方案截图已生成并目视核对。契约样本来自本地真实后端 Pydantic 输出，仅包含合成测试数据。

### 独立工作台登录与客户入口

- 已新增 `main_ibclc.dart`、独立运行环境、身份路由和响应式工作区，接入今日预约、客户搜索/服务筛选/多服务详情、授权 Intake、共享咨询室与专业记录。随后已接入日程、今日跟进和工作提醒，工作台入口已完成本地迁移。
- 后端 `/ibclc/auth/login` → `/verify` 使用邮箱密码和真实 TOTP，存储加密秘密、一次性挑战与 MFA 会话时间。连续错误锁定和挑战限频会实际提交；普通用户登录不授予专家角色。新增迁移 `20260908_0009` 已在隔离 PostgreSQL 应用并检查无差异。
- 专家 API 每次核对有效会话、MFA 时间和专家状态。查询按照当前分配和病例授权返回字段，未授权不返回姓名、分娩日期或宝宝关联。后端 `test_workbench_auth.py` 4 项、`test_workbench_queries.py` 3 项已通过（含正在接入的周日历查询）。
- 修复既有刷新令牌的并发轮换与撤销回滚问题：同一设备会话串行化刷新/退出，重复使用会提交撤销。新增 2 项真实 PostgreSQL HTTP 回归验证，认证相关组合共 31 项通过；OpenAPI/接口目录已重新导出，契约测试 11 项通过。
- 客户端安全存储读写/清除串行执行，过期验证码响应、刷新响应与资料读取不能恢复已退出的会话。新增工作台 controller/widget/transport 共 22 项通过；1024/1280px 预约/客户截图已目视检查并修复字体与标志裁切，390px 两倍文字可操作。
- 独立 Web 构建通过，Chrome 已连接隔离的本地后端，验证合成专家账号的密码/TOTP、重载恢复、预约/客户/Intake 读取、深链更新和退出清除。修复了嵌套路由遮蔽工作区无障碍节点和只读文本不可朗读的问题，相关 3 项回归通过。临时后端、Web 服务与浏览器测试页已关闭。运行说明在 `docs/ibclc-workbench.md`；这仍不是全部服务闭环的浏览器验收。

### 工作台周日程与服务事件

- 周日程复用预约投影和共享月份选择器，按专家时区加载所有分页，跨午夜按区间重叠显示。夏令时 23/25 小时的日期使用带时区的列表，早晚预约会扩展时间轴。后端 4 项查询测试覆盖周界、夏令时、取消过滤和授权；客户端 4 项日程逻辑及月份大字操作测试通过。
- 新增共享 `CareServiceEvent` 与已读回执，预约确认/取消、资料提交、授权撤回、咨询结束和方案发布与业务变更一起提交。工作提醒只返回当前收件人且当前分配仍有效的记录；撤回后姓名隐藏。迁移 `20260908_0010` 已实际应用并检查无差异。
- 工作提醒页面支持两类分组、分页、未读统计、持久化已读和业务跳转。修复共享 Web transport 不接受 204 成功确认的问题，并保留空 200 响应的契约错误。
- 工作台/专业记录/总结/网络组合 52 项 Flutter 测试通过；新增日程与提醒 1024/1280px 截图已目视核对，390px 两倍文字能切月份和标记已读。后端事件/已读重放、事务回滚、异专家隔离、分配变更和授权撤回均通过。OpenAPI/API surface 已重新导出，11 项契约检查通过。

上方清单已完成本地逐项审计；剩余限制仅为云端发布、真实供应商和医学质量评测。

### 最终审计（2026-09-09）

- App：`flutter analyze --no-pub` 无问题；`flutter test --no-pub` 925 项通过；黄金测试单独通过，新增 `test/modules/schedule/schedule_page_golden_test.dart` 与 `test/goldens/product_baseline/schedule-390.png`。
- Backend：隔离 PostgreSQL 已应用 Alembic `20260909_0015`；`pytest -q` 通过 746 项、跳过 2 项；OpenAPI 与 API surface 已重新导出，并同步到 App/Agent 契约目录。
- Agent：`pytest -q` 通过 599 项、跳过 7 项；Runtime contract catalog 导出检查通过。
- 契约：`python scripts/validate_backend_contract.py` 通过；仅报告 Runtime 快照中两个 Product 内部 care-report 路径的既有边界提示。旧 `/v1/plans` 与 `/v1/pregnancy-diary` 服务端路由已标记 `deprecated_api`，当前客户端不引用。
- 未执行云端部署、真实支付/视频供应商接入及真实模型医学质量评测；这些不作为本地重构的完成条件。
