# Unified App 智能体交接文档

> 更新时间：2026-08-19（Asia/Shanghai）
>
> 适用分支：`integration/unified-app`
>
> 功能实现基线：`451e7221c1ed94cc6563cfa0ec5729bca67d57b7`
>
> App 版本：`1.0.0+55`

本文面向接手当前 Flutter 合并工作的智能体。目标是让接手者先恢复正确的
系统边界和验证上下文，再修改代码；不要仅凭目录名或本地已有 APK 推断集成状态。

## 1. 30 秒结论

- 合并已完成，最终策略不是“一个项目覆盖另一个项目”，而是：
  - MomCozyApp 负责产品壳、视觉、页面、MotionPose、媒体和 Agent 对话表现层。
  - 原当前项目负责 Product/Agent 服务边界、认证会话、Agent Runtime 契约、
    BLE/Pump 原生链路和已部署业务兼容性。
- 两份冻结 OpenAPI 是当前发布边界；Product 与 Agent 必须使用不同 origin。
- 审查发现的 15 项契约、计划、媒体和附件问题已在 `451e7221` 统一修复。
- 代码、冻结契约、全量 Flutter 测试和 local debug APK 已验证。
- **尚未完成真实 staging 端到端联调或真机验收，不能宣称线上链路全部打通。**
- 随包 staging 自签名证书已于 **2026-08-15 11:46:00 UTC** 过期；在使用
  `lute-momcozylab.luteos.cloud:8443` 前必须更新证书和 App 资产。

接手后的第一组命令：

```bash
cd /Users/lute/project/momcozy-lab/app
git status --short
git branch --show-current
git log -3 --oneline --decorate
python3 scripts/validate_backend_contract.py
flutter analyze --no-pub
```

预期分支为 `integration/unified-app`。如工作树不干净，先确认变更归属，不要覆盖、
reset 或 checkout 掉用户和其他智能体的改动。

## 2. 冻结合并基线

| 项目 | 值 |
| --- | --- |
| 原当前项目 tag | `pre-merge-current-20260815` |
| MomCozyApp tag | `pre-merge-momcozyapp-20260815` |
| 初次整合 commit | `af114a05` |
| 历史合并 commit | `eefd4f47` |
| 审查修复 commit | `451e7221` |
| Product OpenAPI SHA-256 | `6467b3007bd43009949fdcc0e8f8e61b66d44b74611c9afdf63d97af8fddcc72` |
| Agent OpenAPI SHA-256 | `7feb27ebafd21dfcf69612678d81435e8cc89db14fbf2d6973b9945a5d4a7e7f` |

快照文件：

- `docs/backend-contract/product.openapi.generated.json`
- `docs/backend-contract/agent-runtime.openapi.generated.json`

不要用后端移动中的 `main` 分支静默替换这两份快照。升级契约时应显式更新快照、
兼容说明、smoke flows、客户端适配器和回归测试。

## 3. 系统边界

```text
Flutter App
├─ Product transport
│  ├─ auth / profile / infants
│  ├─ records / plans
│  └─ files / product assets
│     origin = MOMCOZY_API_BASE_URL
└─ Agent Runtime transport
   ├─ threads / runs / stream / events
   ├─ actions / confirm / reject
   └─ cancel / client-events / artifacts
      origin = MOMCOZY_AGENT_API_BASE_URL

Agent Runtime --服务端受控 action/outbox--> Product business services
Flutter <---应用事件 + 权威资源重载--- Product / Agent Runtime
```

关键约束：

- 本地默认 Product 为 `http://127.0.0.1:8769`，Agent 为
  `http://127.0.0.1:8010`。
- Android 模拟器访问宿主机通常使用 `10.0.2.2`；真机不能用 `127.0.0.1`
  访问电脑服务。
- staging/production 构建必须显式提供两个非 loopback HTTPS URL。
- bearer token 只进入 `Authorization` header，不进入 URL、日志或事件 payload。
- Agent 写操作仍以服务端 action、confirmation、audit/outbox 为权威；Flutter
  不从自然语言回复反推业务状态。

## 4. 双方保留模块

### 4.1 MomCozyApp 侧

- 产品壳与设计：Me、Baby、Cozymate、Plan、More，主题、路由和视觉资产。
- `profile_overview`：Me/Baby 概览、记录入口、头像展示模式。
- `plan`：计划、日程任务、任务三态和计划详情。
- `body_profile`、`more`、`notifications`。
- `onboarding` 与头像生成流程。
- `motion_assessment`、CameraX、MediaPipe MotionPose 和语音指导。
- Agent Hub 的 transcript、work status、artifact、form、action、voice、media UI。
- 图片、PDF、视频和 Product asset 查看能力。
- MomCozyApp namespace/applicationId/bundleId、flavor 和打包结构。

### 4.2 原当前项目侧

- `core/agent_stream`：请求、SSE、replay、reducer、cancel、action 和 401 refresh。
- `core/auth`、`core/network`、`core/storage`：secure session、token refresh、
  API envelope、错误模型和登录/退出。
- observability、privacy redaction、route intent、staging smoke 和发布 gate。
- BLE 泵奶协议、Pump 前台服务、后台 runner、通知恢复、设备快照和 Agent context
  上传链路。
- Product/Agent 已部署服务边界与冻结客户端兼容规则。
- 旧外部入口兼容：`/status -> /me`、`/schedule -> /plan`。
- 原孕期计划和孕期日记以 Cozymate 能力继续存在，不再维护独立 Flutter 镜像状态。

### 4.3 融合模块的职责

| 最终模块 | 表现层来源 | 运行时/数据边界来源 |
| --- | --- | --- |
| `agent_hub` | MomCozyApp 对话、卡片、表单、语音、媒体 | 原项目 Agent request/event/action 契约 |
| `auth` | 登录入口与 Shell 接入 | secure session、refresh、logout、账号隔离 |
| `records` | Me/Baby 表单与卡片 | 冻结 Product schema、infant scope、幂等 |
| `plan` | MomCozyApp Plan 信息架构 | 原 Schedule 任务语义和权威状态写入 |
| `pump_session` | Pump 页面 | BLE、前台服务、后台同步、通知恢复 |
| `media` | 查看与预览 UI | Product 文件/资源 API 和传输安全 |
| `hospital_bag` | 新壳内入口和 artifact 卡片 | 购物车状态、Agent 事件和恢复逻辑 |
| `app_pages` | 新页面与导航 | Device、Pump、IBCLC 等既有业务链路 |

最终 `lib/features/` 包含：

```text
agent_hub  app_pages  auth  body_profile  hospital_bag  media  more
motion_assessment  notifications  onboarding  plan  profile_overview
pump_session  records
```

没有保留为重复目录的旧模块：

- `status/`：由 `/me` 和 `/baby` 替代。
- `schedule/`：由 `/plan` 替代。
- `pregnancy_plan/`、`pregnancy_diary/`：转为 Cozymate/Agent 交互能力。
- Android `ScheduleReminderReceiver`、`ScheduleReminderScheduler`：未恢复。
- 旧混合 `openapi.generated.json`：已删除。

## 5. 路由与能力门禁

主要业务路由：

- `/`：Cozymate / Agent Hub
- `/me`、`/baby`、`/baby/development`
- `/plan`
- `/pump`、`/calibration`
- `/notifications`
- `/device`、`/device/manage`、`/device/user`
- `/hospital-bag-cart`、`/ibclc-chat.html`、`/media-viewer`
- `/more/body-profile`、`/motion-assessment`（受门禁控制）

能力配置位于 `lib/core/config/momcozy_app_capabilities.dart`：

| Dart define | 默认 | 说明 |
| --- | --- | --- |
| `MOMCOZY_ENABLE_ONBOARDING` | `false` | 后端驱动 onboarding 与 avatar 路由 |
| `MOMCOZY_ENABLE_RELEASE_RESET` | `false` | 仅与 onboarding 同时为 true 时生效 |
| `MOMCOZY_ENABLE_AGENT_HISTORY` | `false` | 当前 Agent OpenAPI 没有 history endpoint，必须保持关闭 |
| `MOMCOZY_ENABLE_EXTENDED_PRODUCT_API` | `false` | Body Profile、Motion Assessment 和扩展 Me/Baby 资源 |

默认配置仍可加载冻结 Product 快照支持的 profile、infants、feeding、growth、
milk trends 和 plans。以下扩展路径不会在默认配置中请求：

```text
/v1/care-overview/me
/v1/records/feeding-summary
/v1/records/water
/v1/records/water-trends
/v1/records/vitals
/v1/records/sleep
/v1/records/diaper
```

Onboarding 关闭时，`/onboarding`、`/avatar/*` 深链会被净化，不会在登录后回跳
到未注册页面。

## 6. 已冻结的客户端契约决策

### 6.1 Product records

- Feeding create/read 使用扁平字段：

  ```json
  {
    "infant_id": "uuid",
    "feed_time": "date-time",
    "feed_type": "bottle",
    "volume_ml": 80,
    "duration_seconds": 120,
    "plan_task_id": "uuid"
  }
  ```

- 不得恢复 `feeding_method`、`milk_components`、`breast_side` 写字段。
- Pumping create/read 使用 `milk_volume_ml`；UI 左右侧数值只在本地合计后上传。
- 不得恢复 wire `outputs` 或 `is_post_feed_pumping`。
- Milk trend 使用 `pumped_milk_volume_ml`、`pumping_count`、`measured_only`。
- `measured_only=false` 时不能把聚合数值展示成“精确测量奶量”。
- 正常记录重试复用稳定 `Idempotency-Key`；计划记录还必须发送稳定
  `plan_task_id`。

### 6.2 Infant 与 Plan

- `/v1/profile/infants` 是 owner-scoped。session baby ID 无效时选择服务端列表中的
  第一个有效 infant，先尝试持久化，再用该 ID 请求 feeding/growth。
- session 持久化失败不能阻断当前 Baby 页面加载；后续 refresh 会重试持久化。
- `PlanRead.starts_on`、`PlanRead.ends_on` 从顶层读取，不从 payload 读取旧日期键。
- `milk_management` 映射为 lactation plan。
- 任务必须保留 `pending/completed/skipped` 三态；skipped 不能成为 next。
- 任务开始必须保留 task ID 和 kind：
  - pumping -> `/pump`，记录发送 `plan_task_id`
  - feeding -> `/baby` composer，记录发送 `plan_task_id`
  - pregnancy/yoga/pelvic/general -> Agent auto-run，source 中携带稳定 task ID
- 权威任务状态写入使用 `PATCH /v1/plans/tasks/{task_id}/state`，写后重载当前日期。
- `pregnancy_plan.changed`、`milk_plan.changed` 只作为失效信号，客户端重载权威 Plan；
  不从事件 payload 构造计划。

### 6.3 Media 与附件

- 文件内容只使用 `/v1/files/{file_id}/content`；不存在 thumbnail endpoint。
- Agent/Product 图片只渲染稳定 `/v1/assets/{asset_id}` 引用。
- `/skill-assets/...`、临时外链和旧图片引用必须 fail closed，不能拼到 Product origin。
- 上传接口不支持 `temporary=true`，不得重新加入。
- App 对未发送的已上传附件负责：移除、synthetic quick reply/form、新会话或会话切换
  前先调用删除；删除失败保留草稿并提示用户。
- 删除已成功但后续新会话动作失败时，也不能保留指向已删除对象的本地引用。

### 6.4 Agent Runtime

- run create 必须发送 `runtime_pattern: proprietary_runtime`。
- attachment 是 typed reference：image 使用 `asset_id`，file 使用 `file_id`；不要发送
  schema 禁止字段。
- `client_context` 只允许白名单字段，包含 timezone 和 `message_sent_at`。
- create/stream/status/action/cancel/client-event 都复用同一认证与 401 单次刷新策略。
- confirm/reject 的 `Idempotency-Key` 在刷新重试中保持不变。
- reducer 以 `event_id`/sequence 去重，并按 message/action/artifact ID 合并；不得修改旧
  state 的 replay-key Set。
- 重复 `message.completed` 按 `message_id` 合并，并保留最新 quick replies。
- `tool.completed` 的媒体语音只读取 `payload.output_summary`；不要读取原始 tool output、
  `safe_output` 或其他可能泄漏内部结果的字段。
- 当前 Agent OpenAPI只有 thread list/read、run/event/stream/action 等接口，**没有**
  `/threads/{id}/history` 或按 thread 列 runs 的接口。默认必须向 Agent Hub 注入
  `conversationRepository: null`。

## 7. `451e7221` 审查问题闭环

| 问题组 | 根因修复 |
| --- | --- |
| 多宝宝账号 | owner-scoped 有效 infant 解析、持久化、失败降级和 dependent read 顺序 |
| Feeding 写/读 | 全面切换冻结 `feed_type`、`volume_ml` schema |
| Pump milk | 全面切换 `milk_volume_ml`，左右侧只做本地合计 |
| Milk trend | 使用冻结字段并正确处理 `measured_only` |
| Plan task | 保留 task ID/kind/三态，接入 state PATCH 和 record completion |
| Plan 日期/分类 | 顶层 `starts_on/ends_on`，`milk_management -> lactation` |
| Plan 事件 | 使用 `pregnancy_plan.changed`、`milk_plan.changed` |
| Agent media voice | 恢复且只信任 `output_summary.media_voice` |
| Media content | 去掉不存在的 thumbnail 路径 |
| Attachment 生命周期 | 删除成功后再丢弃本地 draft；失败保持可重试 |
| Profile dead API | 删除不受支持的 `updateDeliveryType`/PUT |
| 包体资源 | 删除旧 `nursery_camera.png` 三密度版本，仅保留 clean 版本 |
| Fixture 漂移 | `postpartum_day20.v5` 动态对照冻结 OpenAPI allowed/required 字段 |

## 8. 关键文件导航

| 主题 | 文件 |
| --- | --- |
| App Shell、路由、Agent 注入 | `lib/app/momcozy_app.dart` |
| Product/Agent runtime 组装 | `lib/app/momcozy_api_runtime.dart` |
| 能力门禁 | `lib/core/config/momcozy_app_capabilities.dart` |
| Agent transport/reducer | `lib/core/agent_stream/` |
| Agent Hub UI | `lib/features/agent_hub/agent_hub_page.dart` |
| Agent media voice | `lib/features/agent_hub/domain/agent_media_voice.dart` |
| Records adapter | `lib/features/records/data/records_api_repository.dart` |
| Profile/infant adapter | `lib/features/profile_overview/data/profile_overview_api_repository.dart` |
| Profile orchestration | `lib/features/profile_overview/presentation/profile_overview_controller.dart` |
| Me/Baby UI 与 record composer | `lib/features/profile_overview/presentation/me_baby_overview_page.dart` |
| Plan adapter/domain/controller | `lib/features/plan/` |
| Pump/Device/IBCLC/Viewer 路由页 | `lib/features/app_pages/momcozy_feature_pages.dart` |
| Media file content | `lib/features/media/data/media_content_repository.dart` |
| 合并原则 | `docs/flutter/unified-app-integration.md` |
| 后端交接 | `docs/backend-contract/api-contract-handoff.md` |
| Flutter 契约兼容 | `docs/backend-contract/flutter-client-compatibility.md` |

`momcozy_feature_pages.dart` 仍是较大的聚合文件，这是已知结构债。后续可以按 feature
迁移，但不要在修复线上契约问题时顺带进行无回归保护的大拆分，也不要引入第二套路由或
状态管理框架。

## 9. 已完成验证

以下结果对应功能实现 commit `451e7221`：

- `flutter test --no-pub`：**1168/1168 passed**。
- `flutter analyze --no-pub`：0 issue。
- `python3 scripts/validate_backend_contract.py`：
  - 4 条 smoke flow
  - 70 条 Product path
  - 19 条 Agent Runtime path
- Python contract/config tests：14/14 passed。
- Dart format、JSON parse、`git diff --check` 通过。
- local debug APK 构建与 PDF packaging 验证通过。
- APK 路径（本机 ignored artifact）：
  `build/app/outputs/flutter-apk/app-local-debug.apk`
- 当时 APK SHA-256：
  `cb40a6a634cd7bb41c84227ad1dbf4d8c4ec35d5aa19866cd1e5da27a40a097e`
- APK 内只包含 `nursery_camera_clean.png` 三密度版本和固定 MotionPose 模型。

复现命令：

```bash
python3 scripts/validate_backend_contract.py
python3 -m unittest \
  scripts.tests.test_validate_backend_contract \
  scripts.tests.test_flutter_api_config
flutter analyze --no-pub
flutter test --no-pub
node scripts/build-flutter-android-apk.mjs --mode debug --flavor local
```

Gradle 当前会提示 App、`flutter_timezone`、`flutter_webrtc` 仍使用 Kotlin Gradle
Plugin，未来 Flutter 版本需要迁移到 Built-in Kotlin；该警告不影响当前构建。

## 10. 未完成项与发布阻断

### P0：staging 证书已过期

`assets/certificates/lute-momcozylab-staging.pem` 当前证书信息：

```text
CN=lute-momcozylab.luteos.cloud
notAfter=Aug 15 11:46:00 2026 GMT
SHA256=89:E3:1D:8C:1C:E8:48:EB:5A:AF:FF:44:A9:F0:A7:8B:DD:00:4F:16:AE:96:73:9F:3F:D2:02:9E:A5:59:EA:BC
```

当前日期晚于有效期。在该 host/8443 上执行 staging smoke 或分发前：

1. 更新服务端证书；优先使用受信任 CA。
2. 如仍需 pin 自签名证书，同步替换 App 内 PEM。
3. 重新构建 staging APK，并验证主机名、链和有效期，禁止关闭 TLS 校验。

### 尚未完成的真实环境验证

- 未在真实 staging URL 上执行带真实账号的完整 Product smoke。
- 未验证 App -> Agent -> Product action/outbox/业务事件回流闭环。
- 未在 `451e7221` 之后构建并验收新的 staging release APK；不要复用旧产物。
- 未完成真机 MotionPose、camera/microphone/gallery 权限 smoke。
- 未完成真机 BLE、Pump 前台/后台服务、通知恢复、Doze 和真泵 smoke。
- Agent history 后端契约缺失，功能仍关闭。
- Onboarding、Body Profile、Motion Assessment 和扩展 Me/Baby API 仍需对应 staging
  schema 验收后才能启用。

## 11. 下一位智能体的建议执行顺序

### A. 先复验本地基线

```bash
flutter pub get
python3 scripts/validate_backend_contract.py
flutter analyze --no-pub
flutter test --no-pub
node scripts/build-flutter-android-apk.mjs --mode debug --flavor local
```

不要并行运行多个 Flutter test/build 进程；共享 native-assets/build 目录曾出现过瞬时
code-sign 竞态。

### B. 恢复 staging TLS 后做只读 smoke

```bash
MOMCOZY_STAGING_SMOKE=1 \
MOMCOZY_API_BASE_URL=https://<product-staging-host> \
MOMCOZY_AGENT_API_BASE_URL=https://<agent-staging-host> \
MOMCOZY_API_TOKEN=<staging-token> \
MOMCOZY_DEFAULT_USER_ID=<staging-user-uuid> \
MOMCOZY_DEFAULT_BABY_ID=<staging-infant-uuid> \
dart run tool/staging_smoke.dart
```

先只读；确认隔离账号和数据清理方案后，才显式加入：

```bash
MOMCOZY_STAGING_SMOKE_MUTATE=1
MOMCOZY_STAGING_SMOKE_AGENT=1
```

环境变量中的 token、URL 和账号 ID 不得写入文档、Git、截图或测试 fixture。

### C. 构建 staging release

```bash
MOMCOZY_API_BASE_URL=https://<product-staging-host> \
MOMCOZY_AGENT_API_BASE_URL=https://<agent-staging-host> \
make flutter-release-gate
```

staging/production 构建配置会拒绝空 URL、loopback、非 HTTPS，以及通过 extra defines
覆盖两个保留 URL key 的行为。

### D. 按真实业务链验收

至少覆盖：

1. invite/login、refresh、logout、账号切换和 secure-session upgrade。
2. 多 infant 账号进入 Baby，并确认 feeding/growth 使用有效 UUID。
3. feeding、pumping 创建、重试幂等和 reload 后数据一致。
4. Plan 顶层日期、milk plan、skipped task、task state PATCH。
5. pumping/feeding plan task 完成时 `plan_task_id` 与幂等键稳定。
6. Agent SSE 首帧、reconnect/replay、cancel、action confirm/reject 和 token refresh。
7. 文件 upload/content/delete、synthetic reply 丢弃附件和失败保留草稿。
8. Agent action 生效后收到变更事件，并重载 Product 权威数据。
9. MotionPose、权限、BLE、前台服务、后台恢复和通知点击路由。

## 12. 不得回退的规则

- 不合并 Product 与 Agent OpenAPI，不把 `/v1/agent/*` 发往 Product origin。
- 不恢复旧 Feeding/Pumping/Trend wire 字段。
- 不恢复 `/v1/files/{id}/thumbnail`、`temporary=true` 或 `/skill-assets` URL 拼接。
- 不从 tool 原始输出或 assistant 文本提取权威业务状态。
- 不把 queued action 渲染为 applied。
- 不原地修改 reducer 旧 state 的 replay key 集合。
- 不恢复独立 Status/Schedule 页面树或 retired Schedule native receivers。
- 不在缺少 OpenAPI 和 staging 回归时打开 history/onboarding/extended API flags。
- 不把 MotionPose 模型二进制直接提交为任意来源文件；继续使用固定 SHA、Gradle
  cache 和 `MOMCOZY_POSE_MODEL_FILE` 离线入口。
- 不把 release keystore、token、健康数据、儿童数据或真实附件写入仓库。

## 13. “接口全部打通”的完成定义

只有同时满足以下条件，才可对外声明 App、Product backend 和 Agent 全链路打通：

- 两个真实 staging origin 的健康检查、认证、refresh 和权限全部通过。
- Product profile/infant/records/plans/files/assets 读写 smoke 通过。
- Agent create/stream/replay/cancel/action/client-event 在真实服务通过。
- Agent action 触发 Product 权威写入，业务事件回流并驱动 App 重载。
- local、staging release 和至少一台真机完成安装、登录、权限和核心任务 smoke。
- capability-gated 功能只有在其 endpoint/schema 单独验收后才标记可用。
- staging TLS、签名、日志脱敏和回滚路径完成发布 gate。

在这些条件完成前，准确状态应描述为：**客户端实现与冻结契约已对齐，真实环境端到端
联调尚待验收。**
