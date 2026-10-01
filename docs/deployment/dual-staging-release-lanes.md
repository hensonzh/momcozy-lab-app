# 两条预发布部署与 App 分发链路（设计稿）

> 日期：2026-09-27。状态：**A 旧应用容器已停并完成离线备份，新 A 仍待首次部署；B 未实施北美基础设施**。A 的最新执行状态见 [全新空数据重建交接](a-full-rebuild-2026-09-27.md)。下文旧 API 兼容约束属于停机前设计，不覆盖后来的新版优先决定。
> 范围：工作区 `backend/`（Product Backend）、`agent/`（Agent Runtime）、`app/`（Flutter）。既有配置事实和入口参见 [环境工作流](environment-workflow.md)；Resend 交接见工作区 `backend/docs/resend-auth-email-handoff-checklist.md`。实际操作前重新核对仓库、服务器、平台和用户批准。

> **2026-09-30 更新：以下早期 B 方案中关于 Kubernetes／托管数据库、缓存和 S3 的描述已废止；以 [美东单机自托管 Compose 策略](b-us-east-single-host-uat.md) 为准。本设计稿保留 A 的历史记录及 B App 的交付边界，不可作为 B 服务器部署清单。**

## 0. 本地实施进度与下一道门禁

| 切片 | 本地状态 | 仍需完成／不得误认为已上线 |
| --- | --- | --- |
| A 邀请码管理现状 | 2026-09-27 只读检查：未认证请求旧 `/v1/admin/invite-codes/ui` 返回 200 HTML；按用户决定**不实施针对 `SERVICE_API_KEY` 暴露的隔离**，本地 410 禁用改动已撤回，线上未作修改 | 旧页仍可能暴露服务密钥，未查看线上正文，不能断言是否已泄漏；独立操作员鉴权/BFF/审计管理后台未实现。后续发布不能误称此风险已修复，也不能顺带停用旧页或轮换密钥。 |
| A APK 编译／发布门禁 | `app-staging-release.yml` 声明 `legacy-staging` 与 `MOMCOZY_INTERNAL_INVITE_LOGIN=true`；release gate 实际传入 define，并运行登录页 Widget 检查；预构建 APK 发布要求同配置构建记录与 SHA256；人工脚本锁定 A URL 和邀请码模式，实际发布及显式 A 构建会拒绝缺失 release signing 的环境。Backend、Agent、App 的本地 Product OpenAPI 快照已对齐。只读核对旧的本地 staging APK：包名 `com.momcozymai.app.flutterpoc.staging`，build 57，两份旧包均为 Android Debug 证书签名 | **旧包不是本次门禁产物，不能作签名/登录模式验收**；尚未生成或验收新的可分发 APK。构建记录不是独立签名的供应链证明；GitHub Environment 仍名为 `staging`，A 专属环境迁移未做。 |
| B 目标预检（未启用发布） | Backend、Agent 的 `scripts/release.py --deployment-target north-america-staging` 已识别 B，但在任何发布动作前明确拒绝；各有 `config/release-targets/north-america-staging.json.example` 与无副作用的 root/lock/env/URL 防串线检查。App 的目标模板与 `build-mobile-app.mjs --release-lane north-america-staging --check-config` 校验 B API、邮箱模式、AAB/IPA 与原生身份 | B 独立 Compose、只读私有 env 预检与 GitHub `dev` 的验证 CI 已通过；验证通过后的独立镜像任务可向私有 GHCR 发布 B 镜像，但**不部署目标机**。美东主机已安装 Docker 并建立 B 专属 root/锁/0600 私有配置；两个域名已确定并解析到主机，但 TLS/入口未通，真实密钥、数据去留、三项状态服务真实恢复与离机留存、可执行发布/回滚 runner、Agent 10 并发验收和 App 签名/分发仍待落地。B 实际发布被阻断，镜像或预检成功不等于上线。 |

从 `app/` 执行本地无发布检查：

```bash
python3.12 -m unittest scripts.tests.test_legacy_invite_release_lane scripts.tests.test_north_america_staging_target scripts.tests.test_store_release_lane -q
flutter test --no-pub --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=true test/features/auth/release_lane_auth_mode_test.dart
flutter test --no-pub --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=false test/features/auth/release_lane_auth_mode_test.dart
node scripts/check-north-america-staging-target.mjs # 当前因 B 值未批准／未填写而预期失败
```

Backend/Agent 分别提供同名但独立的 `config/release-targets/north-america-staging.json.example` 与 `scripts/check_release_target.py --config <文件>`。各自模板已填 B 专属 root/lock/私有 env 路径和域名（Backend `backend-us-dev.lute-momcozylab.luteos.cloud`、Agent `agent-us-dev.lute-momcozylab.luteos.cloud`）。模板的只读元数据检查可通过，但**不代表 DNS/TLS/服务通过验收**，不会启动 Compose，也不会开启 B 发布。实际 B 发布 CLI 仍拒绝执行。

App 的非密钥声明须在审批后由 `.example` 复制到被 Git 忽略的 `config/release-lanes/north-america-staging.json`；真实密钥只进入目标环境的私有 secret。两个 B API 域名已填，但 iOS Bundle ID 仍为 `TBD`，且 HTTPS 尚未可达；不要绕开检查或拿 A 的 `staging.json` 代替 B。`--release-lane north-america-staging --check-config` 仅验证声明；不带 `--check-config` 的 B 构建仍拒绝。

## 1. 决策与边界

| | A：现有邀请制 APK 内测链路 | B：新北美商店外测链路 |
| --- | --- | --- |
| 用途 | 保留当前内测能力和历史安装用户 | 非团队用户通过商店测试渠道体验，正常邮箱注册／登录 |
| 部署目标 | **现有**服务器、Product/Agent 域名、内部 CA、现有 PostgreSQL/Redis/MinIO 与发布机制（实际云主机所在区域需以资源清单复核） | **美东独立服务器**上的 Docker Compose；新 Product/Agent 域名及 TLS；在 B 主机上自启动隔离的 PostgreSQL、Redis、MinIO，具体主机/端口/卷仍待验证 |
| API | 保留现有 Product/Agent 路由与现有客户端兼容性门禁；记录该链路独立的已部署 OpenAPI 版本/hash | 独立的部署快照、Product/Agent OpenAPI 版本/hash 与兼容门禁；从同一源码按目标发布生成，**不因为换域名就复制一套接口**；若新链路需破坏性接口变化，明确版本及两端客户端迁移 |
| 身份 | 独立的邀请码登录，邀请码数据留在 A；不把邀请码嵌入包 | 邮箱注册、收码验证、密码登录、找回/重置；Resend 仅处理事务邮件，账号/会话仍由 Product Backend 管理；不接 A 的邀请码库 |
| Android | 仅签名 APK；固定 A 的 package ID、staging 两个 API URL 和邀请码开关；独立下载页/二维码指向当前经校验的 APK | 适配 Google Play 的**签名 AAB**、独立并最终确认的 package ID、B 的 API URL；选择内测/封闭测试轨道及目标国家，按 Play Console 当前要求审核；不复用 A 的 APK 下载站 |
| iOS | 不构建、不上传、不分发 | iOS staging 的 IPA、Apple 签名/App Store Connect、TestFlight 外部测试；B 的 API URL 与邮箱登录；Build 59 仅作历史记录，后续使用新的 build number |
| 运维/发布 | 使用 A 专属 GitHub Environment、锁、签名、发布仓库/Pages；邀请码管理使用**单独受保护的管理入口** | 使用 B 专属 GitHub `dev` 源码、独立构建/发布流水线、单机发布 root/锁/私有 env、签名和 Play/Apple 平台密钥；不碰 A 的资产、邀请名单或发布标签 |

**两条链路都是预发布，而非正式生产。**建议区分 `deployment_target=legacy-staging` / `north-america-staging`，而服务进程的 `APP_ENV`、Flutter `MOMCOZY_ENV` 均暂保持 `staging`。`deployment_target` 已作为 Backend/Agent 发布 CLI 的可选显式参数；旧 `staging` CLI 缺省仍映射 A，`production` 仍映射 production。**B 参数虽被识别，但所有发布动作均在执行前拒绝**；现有 root、Compose 与 GitHub workflow 仍只可执行 A/production，绝不能把 B 伪装成 `production` 或直接改几个 URL 指向 B。

```text
A APK (invite only) ── A Product API ── A Agent API
                        └── A PostgreSQL / Redis / MinIO
A 管理后台(私有入口) ── A 管理 API（独立操作员鉴权）
A 下载页/二维码 ── A 签名 APK（只提供安装，不下发邀请码）

B Play AAB / TestFlight IPA (email) ── B Product API ── B Agent API
                                        ├── B 单机 PostgreSQL / Redis / MinIO
                                        └── B 邮件 worker ── Resend SMTP
```

## 2. A：最小变更，保住原链路

### 后端

1. 将现有服务器及域名、部署清单、数据库/缓存/桶、Agent 对接、`APP_ENV=staging`、既有 Nginx 与 CA 固定为 A；发布仍按 `backend-delivery.yml` → `agent-delivery.yml`，由独立 commit、CI 镜像 digest、迁移/备份、健康检查、OpenAPI hash 和回滚清单驱动。不可为迁就 B 在 A 部署破坏当前 APK 的认证或请求结构。对已安装客户端进行向后兼容审查，尤其是新增必填字段。
2. 邀请码 API 现有 `POST/GET /v1/admin/invite-codes`、`POST /{code}/disable` 与设备绑定逻辑可作为业务基础。当前 `GET /v1/admin/invite-codes/ui` **无需操作员登录即返回 HTML，并把 `SERVICE_API_KEY` 直接嵌入浏览器脚本**（`backend/app/modules/invites/router.py`）；只读核查确认线上未认证访问返回 200 HTML。用户决定不对此实施专项隔离；不擅自禁用路由、轮换密钥或修改线上配置。下一阶段如获单独确认，再设计独立管理域名/入口（VPN/企业 SSO/MFA + RBAC + 审计），服务级凭据只留在服务端、最小权限，不让网页或 APK 获得全局 service key；不能仅靠“独立 URL”代替鉴权。此处是未解决的风险，不能因 A APK 构建门禁通过就宣称管理后台安全。
3. 管理后台的“独立”指**与公开 APK 下载页隔离的私有 URL、鉴权和发布边界**，不强制另建数据库；邀请码仍由 A 后端持久化，管理前端通过受保护的 BFF/会话或经评审的同源机制调用 A 管理 API。下载页不可显示管理入口、邀请码或任何密钥。

### App / 分发

1. 保留现有 `app/scripts/build-flutter-app.sh` → A 专属 GitHub Release APK + Pages `/staging/` 下载页/二维码和 SHA256/provenance 验证；Android `staging` flavor 当前 package ID 实际由 provisional `com.momcozymai.app.flutterpoc` 加 `.staging` 组成，**在实施前核查已安装包的真实 applicationId 与签名，避免覆盖/不可升级**。不从 B 发布同一 tag、APK 或二维码。
2. A 的发布脚本现已强制 `MOMCOZY_INTERNAL_INVITE_LOGIN=true`，构建门禁运行编译期 Widget 断言，并核对预构建 APK 的构建记录与 SHA256；低层 `build-mobile-app.mjs --release-lane legacy-staging` 的本地预检也固定 A URL/邀请码模式。**尚未构建本次门禁的可安装 APK，不能据此断言历史包是 invite-only**；真实包签名、安装升级与登录仍需单独验收。
3. 发布顺序：A Backend 健康与兼容 → A Agent 健康与契约 → A App 门禁（含登录模式、CA、签名、API URL、源 commit、build number、两份 manifest）→ 发布 APK/页面 → 新设备扫码安装、邀请码创建/禁用及设备绑定验收。二维码即使公开，未经授权的邀请码仍不能登入。

## 3. B：美东单机独立拓扑（2026-09-30 决策）

服务器端采用独立 Docker Compose，Backend 自启动 B 的 PostgreSQL、Redis、
MinIO 与 API/worker；Agent 以独立 Compose 项目加入 B 的网络，不再使用
Kubernetes 或托管 RDS/ElastiCache/S3。两套数据库、一套 Redis DB 0（分前缀和
ACL 身份）、两个 MinIO 桶；Agent worker 每进程目标 10 并发，需压测。
**B Compose 模板和私有 env 静态预检已实现，但发布 CLI 仍拒绝 B，不得从 A 的 `staging` 入口偷换目标。**
具体拓扑、迁移数据、备份恢复、发布门禁和 App 验收见
[美东单机自托管 Compose 策略](b-us-east-single-host-uat.md)。

## 4. 发布系统改造与防串线门禁

| 门禁 | A | B |
| --- | --- | --- |
| 发布身份 | `legacy-staging`；保留现有服务器/root/CA/Android APK 下载站 | `north-america-staging`；新环境 root/锁/公有 CA/Play + ASC |
| 不可变输入 | Backend、Agent、App 各自 commit；镜像 digest；每目标的 Product/Agent OpenAPI hash | 同左，**从 B 已部署实例**检验而不是从 A 查询 |
| 配置和密钥 | A 专属私有 env、签名和邀请码管理操作员身份 | B 专属单机私有 env、Compose 项目/卷/网络、MinIO 身份、Resend key、Google/Apple signing |
| 发布前拒绝 | A API/CA 不符、邀请码开关缺失、APK 身份/签名不符、管理 UI 安全门禁未过 | URL 或资源仍占位、落到 A 域名/库/桶、App 仍显示邀请码、AAB/IPA 身份不符、合规资料未齐 |
| 回退 | 回滚 A Backend/Agent 镜像或停止新 APK 发放；保留旧客户端兼容，DB 不自动降级 | B 独立回退；暂停 Play 轨道/TestFlight 链接或构建分发；DB 迁移审查后滚前/向前修复，不影响 A |

实施建议切片（**每一片完成 CI 和独立确认后再继续**）：

1. 固定 A 的既有发布资产与运行时清单；修复管理后台服务密钥暴露，锁定 A invite-only 产物，建立 A 下载/邀请管理的权限隔离和回归测试。
2. 增加明确的 `deployment_target`/环境配置契约：后端和 Agent `release.py`、两条 GitHub workflow 的 root/lock/host guard，App 构建/发布命令与两份目标 config；**不要**把两套目标都映射成现有单个 `staging` 发布入口。加错配/占位值失败测试。
3. 批准 B 的基础设施和域名，在独立主机建立自托管 PostgreSQL/Redis/MinIO 与网络/卷，测空库迁移、连接/恢复，发布 B Backend → Agent；核验 B live OpenAPI 与两个 manifest，禁止跨目标调用。
4. 获得 Resend 所需域名、DNS 和 key 授权，部署 B 邮件 worker，真实收件箱完整登录/重置闭环；对 B App 源码做契约和端到端测试。
5. 按两套 **分别**预留版本号/build number、签名与发布：A 仅 APK+二维码+私有邀请码后台；B Play AAB 测试轨道和 TestFlight 新 IPA。各自记录不可变构建来源、签名、API URL、契约 hash、审核与真实设备验收。

**目前的阻断项（不得写成“已经实现两套”）：** B 主机和两个 DNS 已准备，但 HTTPS 入口/证书、持久数据卷正式初始化、独立原生 Android 身份的发布验收、目标机发布入口/Play 身份及 Resend 端到端未就绪；B 发布 CLI 和 App 实际构建被明确阻断。A 的邀请码本地门禁已补，但尚无新 APK 真实构建/发布验证，独立管理入口未实现。现有可执行部署 workflow 仍只有 A 的 `staging` 及另一个 `production` 目标；不得把静态预检或 B 镜像发布当作两条完整云端发布链路。

## 5. 必须留给负责人确认的决定

- A 的现有资源清单、谁有 DNS/下载仓库/邀请码后台管理权限、管理页安全修复与 key 事故处理方案。
- B 的云供应商/具体北美区域、B 单机 PostgreSQL/Redis/MinIO 容量与隔离、备份保留与数据驻留/隐私要求、外部 API 域名及 TLS。
- 是否让 B iOS 继续沿用 `com.momcozy.mai.staging`；B Android 新 Play 包名与平台账号、测试轨道、发布地区；A/B 是否必须可同时安装。
- Product/Agent 接口若有差异，谁审批新增/废弃 endpoint 和客户端兼容窗口；两链路各自锁定哪一组源 commit。
- B 的 Resend 发件子域名、第三方数据处理、审核账号、用户外测方式；每个云端改动、DNS/key/商店提审均在实际操作时再确认。

验收标准不是“两个包都能编译”：A 和 B 都要拿**各自**的 Backend+Agent manifest 与 live OpenAPI、证书、数据库/缓存/桶隔离证据、登录方式和真实设备安装流程逐项对照；不能用 A 的通过记录给 B 背书。

参考：Google 官方 [Android App Bundle](https://developer.android.com/guide/app-bundle)；Apple 官方 [TestFlight 外部测试](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)；具体政策与费用发布前复核最新版本。
