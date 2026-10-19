# MomCozy Flutter App

IBCLC 使用独立 Flutter 入口 `lib/main_ibclc.dart`；本地运行与当前实现范围见 [工作台说明](docs/ibclc-workbench.md)。完整重构状态见 [产品基线清单](docs/product-baseline-refactor.md)。

Production Flutter client for MomCozyApp.

对话优先 App 端基础版已按 [`docs/flutter/chat-first-product-architecture.md`](docs/flutter/chat-first-product-architecture.md) 收口：登录与角色引导、对话单首页、侧栏、真实资料和记录、宝宝知识到草稿的链路走当前本地服务契约。白板每日建议、供应商语音／哭声分析、旧 UI/API 破坏性清退不包含在本阶段；当前新引导需配套的 Product Backend 合同，不能直接视为兼容尚未升级的线上服务。未推送或发布。

本地 Demo 增量对照：只读取 `../momcozy-lab-demo` 本地已提交 `main/f8118ab`，没有拉取远端。Flutter 端增加对话内哭声本地录音/试听卡和便便照片任务卡，以及记录表单的时间/奶量优先交互；便便照片确认后走现有图片上传和 Agent Run，失败与未同步明确区分。原始哭声音频不上传，分析尚无正式服务契约，按钮保持不可用；本机便便照片预览离页清理、不跨冷启动。当前代码与门禁范围详见 [增量账本](docs/flutter/chat-first-product-architecture.md#本地-demo-f8118ab-已提交版本增量仅-app)。不包含后端/Agent 改造、推送或部署。

Human-facing documentation uses the canonical service names `Product Backend
(backend/)` and `Agent Runtime (agent/)`. Existing build variables
`MOMCOZY_API_BASE_URL` and `MOMCOZY_AGENT_API_BASE_URL` remain stable
compatibility names.

The Flutter application now lives directly at the repository root. Supporting
documentation remains under `docs/`, automation under `scripts/`, and Flutter
tests plus shared fixtures under `test/`.

## Toolchain Baseline

The local toolchain is installed under:

```text
/Users/lute/.local/share/momcozy-toolchains
```

Pinned local versions:

```text
Flutter: 3.44.4 stable
Dart: 3.12.2
JDK: Temurin OpenJDK 17.0.19+10
Android SDK platform: android-36
Android build-tools: 36.0.0
Android platform-tools: 36.0.0-13206524
Android NDK: 28.2.13676358
CMake: 3.22.1
```

From the `MomCozyApp/` repository root:

```bash
make flutter-check
make flutter-invite-dev
make flutter-release-gate
make flutter-emulator-smoke
```

The canonical environment and release workflow is documented in
[`docs/deployment/environment-workflow.md`](docs/deployment/environment-workflow.md).

Pinned versions live in [`flutter-toolchain.json`](flutter-toolchain.json);
`make flutter-check` validates the local SDK/JDK/Android directories and versions against that file.
`make flutter-release-gate` runs the non-device release gate: format, analyze,
tests, staging smoke harness, local debug APK, and staging release APK. It
requires explicit HTTPS, non-loopback `MOMCOZY_API_BASE_URL` and
`MOMCOZY_AGENT_API_BASE_URL` values. The staging flavor is an isolated install identity and uses `MOMCOZY_ENV=staging`.
`make flutter-emulator-smoke` installs the local debug APK on an online Android emulator, launches the app, captures Agent Hub / Schedule / Device screenshots under `build/emulator-smoke/`, and checks the process/window/crash log.

Direct Flutter commands also run from the repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor local
flutter build apk --release --flavor staging \
  --dart-define=MOMCOZY_ENV=staging \
  --dart-define=MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

在 `app/` 目录可用一个入口初始化并启动 Product Backend、Agent Runtime 及其依赖，随后执行跨服务登录验收：

```bash
make local-dev-up
```

该命令会在缺失时从示例创建两个仓库各自被忽略的 `env/local.env`，生成本地 JWT 私钥，对齐服务密钥、issuer、audience 和端口，然后依次启动 Backend 与 Agent。Android 模拟器在线后，启动 Android App 使用：

```bash
make local-dev-start
```

`local-dev-up`、`local-dev-start` 和 `local-dev-app` 会自动准备一个已验证的本地邮箱账号：

- Email：`dev@example.test`
- 初始 Password：`MomcozyLocal123!`

账号缺少资料时会补入示例姓名 `Mia`，以及初始化当天往前 21 天的分娩日期，
让首页显示姓名和产后阶段。后续启动保留已填写的资料，产后天数随日期递增。

每次需要重新构建并刷新 Android Studio Emulator，且自动登录一个全新测试账号时，使用：

```bash
make local-dev-refresh
```

该命令会启动并验证本地双服务、重新构建 `local` debug APK、创建一个**没有示例姓名、分娩日期或宝宝档案**的全新已验证本地账号，卸载模拟器中旧的 local App 后安装新版本，并自动登录。**默认且唯一的停留点是登录后的新手引导角色选择首屏**（“你是宝宝的哪位家人？”）；冷启动后仍停留在该页，不自动选择身份或写入引导资料。脚本在输入密码前核验并截取新账号邮箱的 UI，再从本地 Backend 核验账号归属与空引导状态；截图为 `build/emulator-refresh/login-account.png` 和 `role.png`。命令只打印账号邮箱和 ID，不打印生成的密码；不会发布 APK 或修改云端。

Android Studio 同时运行多台设备时，使用 `MOMCOZY_FLUTTER_EMULATOR_DEVICE=emulator-5556 make local-dev-refresh` 指定当前设备（运行前用 `adb devices` 核对编号）。原 `MOMCOZY_LOCAL_REFRESH_ROLE`、`MOMCOZY_LOCAL_REFRESH_STATUS`、`MOMCOZY_LOCAL_REFRESH_BABY_DETAILS` 自动完成引导的标志不再属于刷新入口；用户可自行从首屏开始体验流程，其他专项端到端测试另行执行。

已启动本地双服务和 iOS Simulator 时，可运行 `python3 scripts/local_ios_chat_first_smoke.py`；妈妈六段引导和记录联调可运行 `MOMCOZY_IOS_SMOKE_ROLE=mother python3 scripts/local_ios_chat_first_smoke.py`。每次均新建空资料账号，真实登录并核对后端持久化与已登录渲染；妈妈路径还会从 App 保存亲喂、配方奶、瓶喂母乳、吸奶和生长记录，再由 Backend 按账号回读验证实际字段，确认无真实宝宝时尿布、睡眠不可保存。要验证有真实宝宝时的尿布和睡眠写入，运行 `MOMCOZY_IOS_SMOKE_ROLE=mother MOMCOZY_IOS_SMOKE_BABY_RECORDS=1 python3 scripts/local_ios_chat_first_smoke.py`：App 创建并选中当前账号的宝宝，再由 Backend 回读核对宝宝归属、记录种类及字段。截图保存在忽略的 `build/ios/chat-first-smoke/`（妈妈路径在 `mother/`；有宝宝路径在 `mother-with-baby/`）。测试结束会用**正常本地签名的 Debug App**替换包含临时测试参数的集成测试 App，再冷启动并保存截图；不要改用 `--no-codesign` 安装，它无法读取已保存的 iOS Keychain 会话。临时账号密码不会写入仓库或输出日志。
上述有宝宝路径还会核验知识页进入对话后的草稿内容，不会自动发起用户提问 Run。

妈妈记录联调还会在保存吸奶记录后重新打开妈妈信息页，刷新同一账号的今日记录，核对 **45 ml · 1 次**和详情，并保存 `ios-chat-first-mother-pumping.png`。该概览读取首页「记录」的 `/v1/records/pumping`；原有泌乳管理读取独立的 `/v1/lactation/records`，两者目前不会自动合并。

要核验妈妈资料变化后欢迎语重新生成且冷启动不重复发起 Run，可运行 `MOMCOZY_IOS_SMOKE_ROLE=mother MOMCOZY_IOS_SMOKE_WELCOME_REFRESH=1 python3 scripts/local_ios_chat_first_smoke.py`。该模式使用另一全新测试账号，检查修改当前账号的真实资料前后各有一个已完成、签名不同的 Agent 欢迎 Run；正常签名冷启动后再次核对没有第三个。该模式不同时开启宝宝记录写入，截图保存在忽略的 `mother-welcome-refresh/`。它不替代跨日边界验收。

在登录页使用上述账号即可进入 App，无需邮件验证码。仅在 `APP_ENV=local` 下创建，
不授予管理员权限。重复启动保留已有账号、修改后的密码和业务数据。
统一启动入口默认保留 App 数据，首次登录后后续启动恢复保存的会话。
若要测试全新安装，可使用 `MOMCOZY_RESET_INVITE_APP=1 make local-dev-start`。
服务已启动时，可用 `make local-dev-account` 单独准备账号，无需重建服务。

常用维护命令为 `make local-dev-verify`、`make local-dev-status`、`make local-dev-logs` 和 `make local-dev-down`。`local-dev-down` 保留数据库与对象存储卷，方便下一次增量启动。

日常开发只需在工作开始时执行一次 `make local-dev-up`。`make local-dev-start` 保持 Flutter 会话常驻，可直接使用 hot reload；无需发布云端测试环境。服务代码变化后重新执行 `make local-dev-up` 会复用 Docker 构建层和数据卷。

仅启动邀请码登录 App 时使用：

```bash
make flutter-invite-dev
```

该命令默认将 Product Backend 和 Agent Runtime 分别连接到
`http://10.0.2.2:8769` 与
`http://10.0.2.2:8010`，不会传入 `MOMCOZY_API_TOKEN` 或
`MOMCOZY_REFRESH_TOKEN`，并会先清理 local flavor 安装包，确保进入邀请码登录页。
如需覆盖模拟器或后端地址：

```bash
MOMCOZY_FLUTTER_EMULATOR_DEVICE=emulator-5554 \
MOMCOZY_API_BASE_URL=http://10.0.2.2:8769 \
MOMCOZY_AGENT_API_BASE_URL=http://10.0.2.2:8010 \
make flutter-invite-dev
```

Agent Hub 默认使用 SSE transport，并可通过 dart-define 配置：

```bash
flutter run \
  --dart-define=MOMCOZY_API_BASE_URL=http://192.168.x.x:8769 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=http://192.168.x.x:8010 \
  --dart-define=MOMCOZY_API_TOKEN=APP_API_TEST \
  --dart-define=MOMCOZY_DEFAULT_USER_ID=demo-user
```

Product Backend 请求始终使用 `MOMCOZY_API_BASE_URL`；所有 Agent Runtime
`/v1/agent/*` HTTP/SSE 请求使用独立的 `MOMCOZY_AGENT_API_BASE_URL`。Android 真机不能使用
`127.0.0.1` 访问电脑上的服务，需要改成手机可访问的局域网或公网地址；
Android emulator 可使用 `10.0.2.2`。

当前部署契约使用 `runtime_pattern: proprietary_runtime`。客户端不会把 Product
Backend 和 Agent Runtime OpenAPI 合并成一个服务，也不会把 bearer token 放进 URL。

Current Android package IDs:

- `local` applicationId: `com.momcozymai.app.flutterpoc.local`
- `staging` applicationId: `com.momcozymai.app.flutterpoc.staging`（测试环境分发）
- `production` applicationId: `com.momcozymai.app.flutterpoc`
- Packaging policy: [docs/flutter/android-packaging.md](docs/flutter/android-packaging.md)
- Release gate: [docs/flutter/release-gate.md](docs/flutter/release-gate.md)
- CI/CD: [docs/flutter/ci-cd.md](docs/flutter/ci-cd.md)

## New-user onboarding

Onboarding is enabled by default for new authenticated users. A compatible
Product Backend must be deployed before distributing this build; if a local or
older Backend has no onboarding endpoints, opt out explicitly with
`--dart-define=MOMCOZY_ENABLE_ONBOARDING=false` for that environment. The gate
holds users with incomplete setup on the full-screen `/onboarding` route. In
three steps it collects name, age, this delivery's date, gestational weeks/days,
number of deliveries, delivery method, baby count, prior cesarean history (only
when applicable), and **current feeding methods**. Direct breastfeeding,
expressed breast milk and formula can be selected together; “Not sure yet” is
exclusive. The Me profile edits the same multi-select field and keeps maternal
and current-baby feeding summaries in sync. Saving completes onboarding and
opens the App directly. Portrait/avatar creation is retired. Only
`GET /v1/onboarding/me` and `PUT /v1/onboarding/me/profile` are used for setup.
No old-account data migration or database wipe is performed by this App change;
use a fresh user data set for rollout.

The destructive internal-test release reset is disabled by default and runs
only when onboarding is enabled (the default) **and**
`MOMCOZY_ENABLE_RELEASE_RESET=true` is explicitly supplied as a `--dart-define`.
The reset flag alone has no effect if onboarding is explicitly disabled. With
both capabilities enabled, startup
compares the installed runtime version and build number (for example
`1.0.0+57`) with the last launched release. A changed release clears the local
session, all user-scoped secure storage, product media caches,
and prior onboarding completion markers while preserving the device ID and
last invite code. After the user signs in, the App performs the matching
idempotent cloud reset before loading onboarding. Reset failure keeps the user
behind the onboarding gate. Completion is recorded per user, so another
account on the same device still receives its own reset and onboarding flow.

Cozymate phase one includes the current text conversation, attachments, and
owner-scoped recovery of the latest real conversation. Users can page backward
inside that conversation while drafts and attachment references remain local to
the signed-in account. Every entry refreshes the current conversation, or
discovers the latest owned conversation when none is selected, and opens at its
latest content. A reply received while the user is manually browsing older
messages does not force-scroll; the ordinary latest-message control remains
available. New-session, conversation-list/switching, voice playback, structured
resource/result cards, forms, and action confirmation are removed. The former
`MOMCOZY_ENABLE_AGENT_HISTORY` flag is no longer supported; current-conversation
recovery is part of the default Agent experience.

The extended Product API rollout flag remains gated by backend availability:
- `MOMCOZY_ENABLE_EXTENDED_PRODUCT_API=true` enables Motion Assessment routes
  and other optional resources that depend on the extended Product Backend API.
  By default, the supported profile, feeding, growth, milk-trend, and Schedule
  data remains available while unsupported summaries show an explicit
  unavailable state.

See [the integration baseline](docs/flutter/staging-app-integration.md) for
contract ownership and verification gates.

Versioned UI design contracts and durable visual evidence live under
[`design-contract/`](design-contract/README.md). Workspace-level
`../design-assets/` content is a dated local archive and must not be used as a
runtime, test, or documentation dependency.

## Contract and Regression Tests

Current Dart test coverage:

- Agent event fixtures parse equivalently across JSONL and SSE eventstream forms.
- Agent stream reducer fixtures cover reconnect replay idempotency by `event_id` and `sequence`.
- API envelope fixtures distinguish success, business errors, HTTP errors, and legacy snake/camel aliases.
- Agent voice fixtures cover STT multipart chunk transcription, timeout fallback, realtime PCM stream cancellation, realtime voice session frames, and WebSocket disconnect behavior.
- Agent Hub widget tests cover composer text send, image attachment payloads, voice transcription fill-in, stop, retry, and user-facing work progress.
- Test smoke CLI validates env parsing, safe default skip, optional test HTTP/client-event/media upload probes, and optional Agent SSE probe.
- Privacy fixtures cover shared log redaction for sensitive keys and URL query parameters.
- BLE fixtures cover request packet goldens, standalone hex files, valid/invalid frame parsing, parser edge cases, cross-platform parity cases, and side mapping.
- Route intent fixtures cover native notification navigation plus unsafe/unknown fallback routes.
- Pump device snapshot reducer fixtures cover E1/D0/D6/0x80/BF protocol frames and left/right side isolation.
- Pump device snapshot binding fixtures cover BLE notification stream consumption and notify subscription seeding.
- Pump agent upload snapshot sync fixtures cover forwarding live pump snapshots into `PumpAgentUploadPlatform.updateDeviceSnapshot`.
- BLE pump protocol platform fixtures cover command packet goldens over `BlePlatform.writeWithoutResponse`.
- Pump native runtime coordinator fixtures cover snapshot, upload sync, and BLE protocol state resolver wiring.
- Android pump agent upload body builder maintains the native process `cap_data` frame history.
- Android pump agent background runner shell refreshes native progress while the foreground service is active.
- Pump agent upload adapter fixtures cover native process progress and process reply event streams.
- Android pump foreground notification click writes a one-shot `/pump` pending route and restore snapshot.
- Android pump completion and auto-end notices are backed by local notifications.
- Android route intent adapter covers pending route consumption and native active route events.
- P0 native fake platform interfaces cover BLE permission/settings/scan failure/notification/read/write/subscribe flows, pump protocol command schemas, pump foreground lifecycle/notice events, wake lock reference counting, and one-shot route consumption/active dispatch.
- Android MethodChannel adapter fixtures cover `MmcBle` BLE method schemas/events and `PumpSessionNotification` foreground method schemas.
- Onboarding fixtures cover postpartum profile serialization, delivery/infant collection, three-step route gating, save failure/retry, and completed-user bypass.
- Pump agent upload MethodChannel adapter fixtures cover native method schemas and failure events.
- Pump agent upload fake platform fixtures cover method schemas, call/failure streams, sensitive failure redaction, and duplicate upload dedupe keys.
- Agent Hub runtime fixtures cover default SSE runner injection, production run payload generation, and route-shell composer send-ready state.

Remaining device-lab gap:

- Run Android real-device P0 smoke for BLE, foreground service, background runner uploads, and notification recovery.

## Engineering Notes

- Add fixtures before feature UI: BLE protocol, Agent SSE stream, API envelope, and route intents.
- Keep native Android capabilities behind typed platform interfaces.
- Keep `android/gradle.properties` host-portable. If Maven AAPT2 cannot start on a
  particular development machine, put `android.aapt2FromMavenOverride` with that
  machine's SDK path in the user's `~/.gradle/gradle.properties`; never commit the
  workstation-specific path.
