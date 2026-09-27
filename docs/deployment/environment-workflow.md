# Momcozy AI 配置文件与环境发布工作流

> 最后更新：2026-09-25
> 适用仓库：`backend/`、`agent/`、`app/`
> 本文说明仓库配置与操作入口，不代表 staging/production 已完成部署或 App Store 已上传。
> **新设计（2026-09-27，尚未实施）：** 现有邀请码 APK 与未来北美 Play/TestFlight 两条预发布链路的隔离、风险和实施门禁见 [双链路设计稿](dual-staging-release-lanes.md)。本文描述的是当前单套 staging/production 配置，不意味着新链路可用。

## 1. 统一环境语义

| 环境 | 用途 | 可部署 | 数据与凭据 |
| --- | --- | --- | --- |
| `local` | 开发机联调 | 否 | 本机 ignored `env/local.env` |
| `staging` | 内部预发布、联调、TestFlight/Android 内测前验证 | 是 | GitHub Environment + 服务器私有 env |
| `production` | 正式线上与商店发行 | 是 | GitHub Environment + 服务器私有 env |
| `test` | 单元测试、集成测试、临时 CI fixture | 否 | 测试进程临时注入 |

`test` 不再作为服务器名称、Flutter flavor 或发布清单的环境值。现有 staging DNS
仍暂时包含 `-test`（例如 `backend-test...`），这是基础设施命名遗留，不改变其
`staging` 语义；后续改 DNS 时只更新 staging 配置源和证书，不再改应用代码。

## 2. 配置文件地图（路径均相对工作区根目录）

### 每个文件负责什么

| 文件 | 职责；不要误用为 |
| --- | --- |
| `backend/Dockerfile`、`agent/Dockerfile` | 各服务各构建一份镜像；API、worker、迁移复用同一镜像并覆盖启动命令。不是按环境区分的 Dockerfile。镜像仅安装本服务的 `requirements.txt`。 |
| 两个服务各自的 `docker-compose.local.yml` | 本机完整开发栈（服务与依赖），使用各自被忽略的 `env/local.env`。不是服务器部署拓扑。 |
| 两个服务各自的 `docker-compose.ci.yml` | **只**与本服务的 `docker-compose.local.yml` 按此顺序叠加，注入 `APP_ENV=test` 等 CI 覆盖值；不能单独使用，也不部署到服务器。 |
| 两个服务各自的 `docker-compose.deploy.yml` | `staging` 和 `production` 共用的唯一服务器 Compose 模板；从环境私有 env 注入差异，使用 CI 产出的不可变镜像引用，不在服务器重新构建。 |
| `backend/env/{local,staging,production}.env.example`、`agent/env/{local,staging,production}.env.example` | 三套环境的**模板**，不是凭据或三个同时加载的文件。`local.env` 留在开发机；staging/production 的真实 env 留在各自部署主机并保持 `0600`。 |
| `backend/requirements.txt`、`agent/requirements.txt` | 各服务自己的生产运行依赖，分别由自己的 Dockerfile 安装；与环境名无关。 |
| 两个服务各自的 `requirements-dev.txt` | `-r requirements.txt` 加上测试、lint、类型检查工具，只在开发机/CI 安装。`pyproject.toml` 管理项目与工具配置，不是第二份运行依赖清单。 |
| `backend/requirements-rtc-test.txt` | 在 dev 依赖上增加可选 LiveKit RTC 测试客户端；仅手动跑媒体集成测试时安装（见 `backend/docs/consultation-rooms.md`），不进入镜像或常规 CI。 |
| `app/config/environments/{local,staging}.json`、`production.json.example` | Flutter 编译时环境、Product/Agent API URL。生产须先复制为被忽略的 `production.json` 并替换占位 URL。 |
| `app/android/app/build.gradle.kts`、`app/ios/Runner.xcodeproj` | Android 有 `local/staging/production` 三个原生 flavor；iOS 已有独立 `staging` scheme（`com.momcozy.mai.staging`）用于内部 TestFlight 准备，`Runner` 的生产 Bundle ID 尚待确认；iOS 不是三套原生 scheme。 |

### 选哪一组文件、走哪个入口

| 场景 | Backend + Agent 环境与 Compose | Flutter 配置 | 执行入口 |
| --- | --- | --- | --- |
| `local` | 各自 `env/local.env`（由 `.example` 初始化）；各自 `docker-compose.local.yml` | `app/config/environments/local.json` | `cd app && make local-dev-up`，App 构建用 `make app-build-local-apk`；详见第 3 节。 |
| `test`（CI 临时） | CI 使用 `env/local.env.example`、`docker-compose.local.yml` + `docker-compose.ci.yml`，测试进程注入 `APP_ENV=test` | 无 `test` flavor | `backend-ci.yml`、`agent-ci.yml`、`app-ci.yml`；不是服务器环境。 |
| `staging` | 对应 `env/staging.env.example` **生成主机私有 env**；各自 `docker-compose.deploy.yml` | `app/config/environments/staging.json` | 先 `backend-delivery.yml`，再 `agent-delivery.yml`；通过联调门禁后才用 `app-staging-release.yml`。 |
| `production` | 对应 `env/production.env.example` **生成独立的主机私有 env**；各自仍用 `docker-compose.deploy.yml` | 从 `production.json.example` 准备私有 `production.json` | 先 Backend 再 Agent 的受保护发布流程；App 正式构建还需要签名、最终 iOS Bundle ID 等条件。 |

Backend 和 Agent 的两份部署 env 必须针对**同一环境**对齐共享网络、数据库、服务身份与公开 URL（见第 5 节）；不得把 `staging` env 配给 `production`。`docker compose --env-file` 用于 Compose 变量插值，服务内的 `env_file:` 将选定的私有配置交给容器；不要再叠加第二份 provider env。`backend/scripts/release.py` 和 `agent/scripts/release.py` 分别由受保护的 GitHub 发布工作流调用；`make *-staging-config` / `make *-production-config` 只检查模板可渲染，**不代表凭据齐全或已部署**。

Agent 之前额外的本机 `env/azure.staging.env` 没有被 Compose 或发布脚本引用；已原样移至被忽略且权限为 `0700` 的 `agent/.local/config-archive/`，文件自身保持 `0600`。它是未启用的私有实验配置，不算第四套环境。若决定启用 Azure，审核后只将所需 provider 参数写入**目标环境现有的私有 service env**，按 `agent/docs/model-providers.md` 的 drain/切换流程发布，不要在 Compose 增加第二个 `env_file`。

### 无副作用的配置检查

```bash
# 从 momcozy-lab 工作区根目录开始
cd backend && make backend-staging-config backend-production-config
cd ../agent && make agent-staging-config agent-production-config
cd ../app && make workspace-environment-check
make app-config-check APP_ENVIRONMENT=staging APP_MODE=release
```

上述检查不启动服务、不构建 App。两个服务的 staging/production `.example` 可通过 Compose 语法检查，但其中的占位密钥会被 `scripts/release.py` 拒绝；App 的 `production.json.example` 也不是可直接发布的正式配置。

真实密钥只允许存在于：

1. 本机被 Git 忽略的 `env/*.env`；
2. 部署主机权限为 `0600` 的私有 env 文件；
3. GitHub Environment secrets；
4. Apple/Google 的官方签名与发布系统。

禁止把真实 API key、JWT 私钥、数据库密码、签名 keystore、`.p12`、`.mobileprovision`
或 App Store Connect API key 提交到仓库。

## 3. Local 工作流

从 `app/` 统一管理本地全栈：

```bash
cd app
make workspace-environment-check
make local-dev-init
make local-dev-up
make local-dev-verify
make local-dev-app
```

`local-dev-init` 会：

- 将旧的 ignored `env/compose.local.env` 安全迁移为 `env/local.env`（仅当新文件不存在）；
- 缺失时从 `env/local.env.example` 创建私有文件并设置 `0600`；
- 生成本地 JWT 私钥；
- 对齐 Backend 与 Agent 的 issuer、audience 和服务间密钥。

本地端口：

```text
Product Backend  http://127.0.0.1:8769
Agent Runtime     http://127.0.0.1:8010
```

## 4. CI 与部署职责

### Pull request / main CI

CI 使用 `APP_ENV=test`，只做临时验证：lint、类型检查、单元/集成测试、迁移检查、
OpenAPI/契约检查和容器 smoke。成功的 `main` 构建发布一个按完整 commit SHA 标记的
镜像，并生成包含 digest 的不可变 image manifest。

CI 不部署服务器，也不把 `test` 写入部署 manifest。

### Backend 发布

运行 `backend-delivery`，选择 `staging` 或 `production`，再选择：

- `bootstrap`：首次创建该环境共享的 PostgreSQL、Redis、MinIO 和 Docker network；
- `deploy`：拉取 CI 已验证的 digest 镜像，必要时备份、迁移、切换并健康检查；
- `rollback`：仅回滚应用镜像，不自动降级数据库。

### Agent 发布

Backend 必须先成功发布。随后运行 `agent-delivery`，选择相同环境。Agent 会校验：

- Backend release manifest 的环境和身份；
- 固定的 Product OpenAPI hash；
- 当前活动 Run/Context job 已安全 drain；
- 迁移、worker heartbeat、内部与公开 readiness。

### GitHub Environment 配置

在 `staging` 和 `production` 两个 GitHub Environment 中分别配置同名变量/密钥：

Variables：

```text
RELEASE_ROOT
SERVICE_ENV_FILE
CA_FILE
PUBLIC_URL
RELEASE_LOCK_PATH
```

Secrets：

```text
SSH_HOST
SSH_PORT
SSH_USER
SSH_PRIVATE_KEY
SSH_KNOWN_HOSTS
```

`RELEASE_APPROVERS` 是仓库级变量；正式环境仍应使用 GitHub Environment required
reviewers 作为最终审批门禁。

`RELEASE_ROOT` 必须按环境固定：staging 使用现有的 `/opt/momcozy-lab`，production 使用
`/opt/momcozy-lab-production`。两个仓库的同一环境必须指向同一 root，`SERVICE_ENV_FILE`
和 `RELEASE_LOCK_PATH` 必须在该 root 的 `shared/` 下；Backend 与 Agent 的锁路径也必须
相同。发布脚本在写入快照或操作 `current/previous` 前校验“环境—根目录”配对，避免
同主机部署时互相覆盖。现有 staging 根目录无需整体迁移；生产目录、私有 env、证书、
数据库和网络均须单独预置，不得复用 staging。

**现有云端 staging 切换尚未执行：**旧的 `test` env/manifest 不能直接被新发布脚本当作
`staging` 使用。操作前先检查主机现有容器、卷、指针、数据库版本和备份，留存旧镜像与
回滚信息；将私有配置按 staging 模板迁移为 mode `0600` 的独立 env（不在日志中输出
密钥），确认网络、Compose project 和 Nginx upstream 的切换方案；先以已通过 CI 的
镜像受控发布 Backend，再发布 Agent。只有两份活动 release manifest 均标记
`staging`、公开 API/契约及 smoke 通过后，才运行 App staging 发布流水线。不要仅
修改 manifest 的 `environment` 字段或直接对旧数据卷执行未经审核的 bootstrap。

## 5. 部署拓扑契约

Backend 的私有部署 env 是共享基础设施的权威来源；Agent 私有 env 中对应值必须一致：

```text
MOMCOZY_BACKEND_COMPOSE_PROJECT
MOMCOZY_AGENT_COMPOSE_PROJECT
MOMCOZY_NETWORK_NAME
MOMCOZY_BACKEND_API_BIND
MOMCOZY_AGENT_API_BIND
MOMCOZY_POSTGRES_ADMIN_USER
MOMCOZY_AGENT_POSTGRES_DB
MOMCOZY_AGENT_POSTGRES_USER
MOMCOZY_AGENT_POSTGRES_PASSWORD
MOMCOZY_AGENT_REDIS_PASSWORD
MOMCOZY_AGENT_MINIO_BUCKET
MOMCOZY_AGENT_MINIO_ACCESS_KEY
MOMCOZY_AGENT_MINIO_SECRET_KEY
```

Backend 独占基础设施生命周期；Agent 的 deploy Compose 只加入 external network，绝不
创建第二套数据库、Redis 或 MinIO。两个环境必须使用不同的 Compose project、network、
database、bucket 和凭据。

## 6. App 构建入口

统一命令：

```bash
cd app
node scripts/build-mobile-app.mjs \
  --platform <android|ios> \
  --environment <local|staging|production> \
  --mode <debug|release> \
  --format <apk|appbundle|ios|ipa> \
  [--unsigned] \
  [--check-config]
```

常用 Make target：

```bash
make app-build-local-apk
make app-build-staging-apk
make app-build-production-aab
make app-build-staging-ios       # 独立 staging Bundle ID，无签名编译预检
make app-build-production-ipa    # 需要 Apple 签名
```

构建脚本会检查：

- 环境名与配置文件中的 `MOMCOZY_ENV` 完全一致；
- staging/production API 必须为 HTTPS 且不能是 loopback；
- production API 不能沿用 example 模板中的占位域名；
- production Android release 必须提供完整签名变量；
- production iOS 禁止 `--unsigned`；
- Android APK/AAB 都经过 PDF native library 打包校验。

## 7. App 发布状态与阻塞项

产品正式名称已确认：`momcozy AI`。它是一个新的 App，不是已有 Momcozy App 的更新。

截至 2026-09-24，以下事项仍阻塞生产 iOS 上传：

1. 正式 Bundle ID 尚未确认；当前 `com.momcozymai.app.flutterpoc` 只能视为临时值。
2. Apple 团队类型必须确认是可公开上架的 Apple Developer Program；Enterprise Program
   只能用于企业内部分发。
3. 需要由有权限的成员创建 App ID 和 App Store Connect App 记录，并授予当前账号访问。
4. 本机/CI 尚需 Distribution certificate、App Store provisioning profile 或受控自动签名。
5. `config/environments/production.json` 尚未创建；必须从 example 复制并填入正式 HTTPS API。
6. Google 登录、Sign in with Apple、推送、隐私声明、商店素材和审核账号仍需逐项验收。

在上述条件满足前，只允许执行 staging 构建和 iOS `--unsigned` 编译预检。

## 8. 推荐发布顺序

1. Backend CI 通过并生成 image manifest。
2. `backend-delivery` 部署目标环境并生成 Backend release manifest。
3. Agent CI 通过并生成 image manifest。
4. `agent-delivery` 校验 Backend manifest 后部署 Agent。
5. App staging workflow 同时校验两份 release manifest 与公开 OpenAPI，再构建签名 APK。
6. 生产 App 构建必须使用 `production.json`，并分别生成 Android AAB 与 iOS IPA。
7. iOS 先上传 TestFlight，完成内部测试后再提交 App Review；首版建议手动发布。

## 9. 回滚与故障边界

- Backend/Agent rollback 只切换到上一份不可变镜像，不自动降级数据库。
- Schema 不兼容时必须 roll forward，不能强行回滚。
- Backend 失败时停止 Agent 新流量；Agent 失败不应破坏 Product Backend 数据。
- App 发布物绑定 Backend/Agent commit、image digest 和 OpenAPI hash；服务身份不一致时拒绝发布。
- staging 与 production 的锁、env、证书、网络和数据卷必须隔离。

## 10. 本地验证与剩余门禁（2026-09-24）

- Backend/Agent：全量测试此前分别为 699 passed / 69 skipped 和 660 passed /
  7 skipped；本轮根目录隔离改动后，定向发布契约测试分别为 22 和 18 passed，
  Ruff 和差异检查通过。两份 delivery workflow 均通过 YAML 语法解析。
- App：跨仓库配置校验、46 项脚本测试、`flutter analyze --no-pub`、19 项定向
  Dart 测试、安全与 Android 打包检查通过。
- iOS：staging `--no-codesign` Release 编译成功（`Runner.app`，约 126 MB，
  临时 Bundle ID）；无签名包不可安装分发，也不可上传 App Store。后续 Android
  `flutter clean` 会删除当前 `build/ios` 临时目录，成功证据是构建命令的退出码，
  非当前目录是否仍存在。
- Android：统一入口完成 staging Release APK 构建并验证 PDF 原生资源，产物为
  `build/app/outputs/flutter-apk/app-staging-release.apk`，SHA-256 为
  `7714f39ad92bab36d62b54c88906ff401619b7a939b187a6ca909c36596024c9`。
  APK 身份为 `com.momcozymai.app.flutterpoc.staging`（1.0.0+57），显示名
  `momcozy AI`；签名证书为 `CN=Android Debug`，**不是内测发布或商店签名**。
  此次仅是本地构建，未发布；macOS 使用固定 SDK 内的 AAPT2
  避免系统 Maven 版本 daemon 启动失败。
- App 全量视觉/Golden 门禁**尚未通过**：大量历史 Golden 未标记 `golden` tag，
  `--exclude-tags=golden` 也会运行并失败。并行登录 UI/Golden 改动不得为了本次
  发布配置任务而覆盖；最终候选版仍需逐组视觉验收并修复 CI 分类。
- 尚未连接/迁移云端现有 `test` manifest，尚未提供 production 私有 env、真实
  API、正式 Bundle ID、商店签名材料或 Apple 团队/权限确认；因此不能直接启动
  production 部署或上传 iOS IPA。

## 11. 清理后的旧名称

以下入口已退役，不应重新引入：

```text
env/compose.local.env.example
env/compose.test.env.example
docker-compose.test.yml
scripts/test_release.py
backend-test-delivery.yml
agent-test-delivery.yml
Android flavor unified
MOMCOZY_ENV=test（用于可部署 App）
```

`test` 仍可用于 pytest/Flutter test/CI fixture，不得用作可部署环境身份。
