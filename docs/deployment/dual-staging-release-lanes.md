# 两条预发布部署与 App 分发链路（设计稿）

> 日期：2026-09-27。状态：**A 旧应用容器已停并完成离线备份，新 A 仍待首次部署；B 未实施北美基础设施**。A 的最新执行状态见 [全新空数据重建交接](a-full-rebuild-2026-09-27.md)。下文旧 API 兼容约束属于停机前设计，不覆盖后来的新版优先决定。
> 范围：工作区 `backend/`（Product Backend）、`agent/`（Agent Runtime）、`app/`（Flutter）。既有配置事实和入口参见 [环境工作流](environment-workflow.md)；Resend 交接见工作区 `backend/docs/resend-auth-email-handoff-checklist.md`。实际操作前重新核对仓库、服务器、平台和用户批准。

## 0. 本地实施进度与下一道门禁

| 切片 | 本地状态 | 仍需完成／不得误认为已上线 |
| --- | --- | --- |
| A 邀请码管理现状 | 2026-09-27 只读检查：未认证请求旧 `/v1/admin/invite-codes/ui` 返回 200 HTML；按用户决定**不实施针对 `SERVICE_API_KEY` 暴露的隔离**，本地 410 禁用改动已撤回，线上未作修改 | 旧页仍可能暴露服务密钥，未查看线上正文，不能断言是否已泄漏；独立操作员鉴权/BFF/审计管理后台未实现。后续发布不能误称此风险已修复，也不能顺带停用旧页或轮换密钥。 |
| A APK 编译／发布门禁 | `app-staging-release.yml` 声明 `legacy-staging` 与 `MOMCOZY_INTERNAL_INVITE_LOGIN=true`；release gate 实际传入 define，并运行登录页 Widget 检查；预构建 APK 发布要求同配置构建记录与 SHA256；人工脚本锁定 A URL 和邀请码模式，实际发布及显式 A 构建会拒绝缺失 release signing 的环境。Backend、Agent、App 的本地 Product OpenAPI 快照已对齐。只读核对旧的本地 staging APK：包名 `com.momcozymai.app.flutterpoc.staging`，build 57，两份旧包均为 Android Debug 证书签名 | **旧包不是本次门禁产物，不能作签名/登录模式验收**；尚未生成或验收新的可分发 APK。构建记录不是独立签名的供应链证明；GitHub Environment 仍名为 `staging`，A 专属环境迁移未做。 |
| B 目标预检（未启用发布） | Backend、Agent 的 `scripts/release.py --deployment-target north-america-staging` 已识别 B，但在任何发布动作前明确拒绝；各有 `config/release-targets/north-america-staging.json.example` 与无副作用的 root/lock/env/URL 防串线检查。App 的目标模板与 `build-mobile-app.mjs --release-lane north-america-staging --check-config` 校验 B API、邮箱模式、AAB/IPA 与原生身份 | 只完成**静态预检／拒绝误部署**；Backend/Agent 托管服务 Compose、B 实际 root/lock/主机/域名、B Android 独立原生 flavor、签名、Resend、Play/TestFlight workflow 未实现。App 的 B 实际构建仍被主动阻断；预检通过不表示可发布。 |

从 `app/` 执行本地无发布检查：

```bash
python3.12 -m unittest scripts.tests.test_legacy_invite_release_lane scripts.tests.test_north_america_staging_target scripts.tests.test_store_release_lane -q
flutter test --no-pub --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=true test/features/auth/release_lane_auth_mode_test.dart
flutter test --no-pub --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=false test/features/auth/release_lane_auth_mode_test.dart
node scripts/check-north-america-staging-target.mjs # 当前因 B 值未批准／未填写而预期失败
```

Backend/Agent 分别提供同名但独立的 `config/release-targets/north-america-staging.json.example` 与 `scripts/check_release_target.py --config <文件>`。各自模板中的 root、lock、私有 env 路径及 URL 在审批前保留 `TBD`，执行模板预检预期失败；检查只读声明，不会启动 Compose，也不会开启 B 发布。实际 B 发布 CLI 仍拒绝执行。

App 的非密钥声明须在审批后由 `.example` 复制到被 Git 忽略的 `config/release-lanes/north-america-staging.json`；真实密钥只进入目标环境的私有 secret。域名、Android Play 包名、iOS Bundle ID 未确认时保留 `TBD`，不要绕开检查或拿 A 的 `staging.json` 代替 B。`--release-lane north-america-staging --check-config` 仅验证声明；不带 `--check-config` 的 B 构建仍拒绝。

## 1. 决策与边界

| | A：现有邀请制 APK 内测链路 | B：新北美商店外测链路 |
| --- | --- | --- |
| 用途 | 保留当前内测能力和历史安装用户 | 非团队用户通过商店测试渠道体验，正常邮箱注册／登录 |
| 部署目标 | **现有**服务器、Product/Agent 域名、内部 CA、现有 PostgreSQL/Redis/MinIO 与发布机制（实际云主机所在区域需以资源清单复核） | **新的北美**主机或容器运行环境；新 Product/Agent 域名与受信任 TLS；托管 PostgreSQL、Redis 及对象存储（优先与主机同区域的 S3，若选 OSS 须补网络与合规评审）。主机、域名、供应商、账号及区域目前**未选定** |
| API | 保留现有 Product/Agent 路由与现有客户端兼容性门禁；记录该链路独立的已部署 OpenAPI 版本/hash | 独立的部署快照、Product/Agent OpenAPI 版本/hash 与兼容门禁；从同一源码按目标发布生成，**不因为换域名就复制一套接口**；若新链路需破坏性接口变化，明确版本及两端客户端迁移 |
| 身份 | 独立的邀请码登录，邀请码数据留在 A；不把邀请码嵌入包 | 邮箱注册、收码验证、密码登录、找回/重置；Resend 仅处理事务邮件，账号/会话仍由 Product Backend 管理；不接 A 的邀请码库 |
| Android | 仅签名 APK；固定 A 的 package ID、staging 两个 API URL 和邀请码开关；独立下载页/二维码指向当前经校验的 APK | 适配 Google Play 的**签名 AAB**、独立并最终确认的 package ID、B 的 API URL；选择内测/封闭测试轨道及目标国家，按 Play Console 当前要求审核；不复用 A 的 APK 下载站 |
| iOS | 不构建、不上传、不分发 | iOS staging 的 IPA、Apple 签名/App Store Connect、TestFlight 外部测试；B 的 API URL 与邮箱登录；Build 59 仅作历史记录，后续使用新的 build number |
| 运维/发布 | 使用 A 专属 GitHub Environment、锁、签名、发布仓库/Pages；邀请码管理使用**单独受保护的管理入口** | 使用 B 专属 GitHub Environment、锁、签名和 Play/Apple 平台密钥；不碰 A 的资产、邀请名单或发布标签 |

**两条链路都是预发布，而非正式生产。**建议区分 `deployment_target=legacy-staging` / `north-america-staging`，而服务进程的 `APP_ENV`、Flutter `MOMCOZY_ENV` 均暂保持 `staging`。`deployment_target` 已作为 Backend/Agent 发布 CLI 的可选显式参数；旧 `staging` CLI 缺省仍映射 A，`production` 仍映射 production。**B 参数虽被识别，但所有发布动作均在执行前拒绝**；现有 root、Compose 与 GitHub workflow 仍只可执行 A/production，绝不能把 B 伪装成 `production` 或直接改几个 URL 指向 B。

```text
A APK (invite only) ── A Product API ── A Agent API
                        └── A PostgreSQL / Redis / MinIO
A 管理后台(私有入口) ── A 管理 API（独立操作员鉴权）
A 下载页/二维码 ── A 签名 APK（只提供安装，不下发邀请码）

B Play AAB / TestFlight IPA (email) ── B Product API ── B Agent API
                                        ├── B 托管 PostgreSQL / Redis / S3
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

## 3. B：北美预发布独立拓扑

### 待确定的资源表（**占位，不表示已创建**）

| 对象 | 待填 | 验收要点 |
| --- | --- | --- |
| 云供应商/北美区域/运行形态 | `TBD` | 主机/容器、出站 Resend、容灾、审计与数据驻留 |
| Product API HTTPS 域名 | `TBD` | 公网可受信 TLS，API URL/issuer/trusted-host 与 App 配置一致 |
| Agent API HTTPS 域名 | `TBD` | WebSocket/stream 路径与移动端一致，安全访问 Product 内网接口 |
| PostgreSQL（Product/Agent 隔离） | `TBD` | 各自 DB/角色/迁移、私有连接、TLS、备份及恢复演练 |
| 托管 Redis | `TBD` | 两服务独立命名空间/账号、TLS、持久性/故障恢复契约 |
| S3/OSS 桶 | `TBD` | Product/Agent 独立桶或隔离前缀/权限、私有 ACL、加密、生命周期/备份、外部资源签名访问 |
| 邮件发件域名/区域 | `TBD` | 公司授权域名、Resend DNS 验证、发送权限受限 key、投递与配额 |
| Android Play package / iOS Bundle ID | `TBD` / `TBD`（可评估沿用已注册 iOS staging ID） | A/B 安装和审核身份隔离；证书/profile/Play signing 不自动改动 |
| 平台账号/测试轨道、受众国家 | `TBD` | Play Console/ASC 权限、TestFlight 外测审核；公开链接并非北美地理封锁 |

B 必须有独立 VPC/安全组、主机/资源、部署 root/lock、GitHub Environment、镜像/manifest、密钥（含 JWT issuer/audience/JWKS、跨服务 key）、日志/告警、测试账号和数据。代码与不可变镜像**可以复用相同版本**，但数据库、对象存储、认证身份和客户数据不能混用；不把 A 的备份或用户表直接导入 B。不要把管理型 PostgreSQL/Redis/S3 连接凭据放到 Flutter。

现有 `backend/docker-compose.deploy.yml` 同时定义本机 PostgreSQL/Redis/MinIO 并用 `postgres`/`redis`/`minio` 网络别名构造连接；**不能原样把 B 指到托管服务后照常部署**。实施阶段应保持 A Compose 不变，为 B 增加受测试的无本机 stateful 服务拓扑/覆盖，显式注入托管连接与 TLS 参数、Product/Agent 独立权限；审查迁移、备份钩子、健康检查和回滚。`agent` 的数据库/Redis/对象存储与 Product 同步迁移设计；网络出口和 CORS/trusted hosts/跨域上传回调也要评审。OpenAPI 属于应用协议而非域名：为每个 B 发布记录**独立的候选/已部署 Product 与 Agent 快照、SHA256、客户端兼容矩阵**，不因部署目标而默认 fork 两份不同业务 API。

### B App / 商店交付

- Android：新建/评审 B 专属 `applicationId`、图标/品牌、Play App Signing 与签名材料、签名 AAB、target SDK/权限和商店隐私资料；选择 Google Play **内部或封闭测试轨道**，按目标账号资格及审核流程执行。现有 `make app-build-production-aab` 读取 `production.json.example` 而不是 B 的 staging 配置，**不得直接当作 B 发布命令**；需新增受保护 B 入口，锁定正确 ID、B HTTPS URL、邮箱模式并验证 AAB 元数据。Google Play 新 App 以 AAB 为交付物，非 A 的旁加载 APK。
- iOS：评审 B 的 Bundle ID 是沿用已注册 `com.momcozy.mai.staging` 还是另建标识，必要时核对 Apple Team、证书/profile 与能力；选 B API URL 构建新版本 IPA，正常 App Store Connect 出口合规/隐私/测试信息、可登录的合成数据审核账号、Beta App Review，批准后才开放外部 TestFlight。用户先前选择公开链接，链接可能传播到北美外，**不能当作地理访问控制**；变更原“不在法国分发”答案需独立评估。不得自动操作现有证书/profile/设备。
- B 的邮箱/密码由 Backend 管理，Resend 只负责注册/重置邮件。上线 B 的真实邮件域名/DNS/key/SMTP、worker 健康、北美收件箱闭环见 Resend 交接；**不把服务商 key 内置在 App**。App 验收必须覆盖注册收码、后台验码、登录、重置与退出/重登。

## 4. 发布系统改造与防串线门禁

| 门禁 | A | B |
| --- | --- | --- |
| 发布身份 | `legacy-staging`；保留现有服务器/root/CA/Android APK 下载站 | `north-america-staging`；新环境 root/锁/公有 CA/Play + ASC |
| 不可变输入 | Backend、Agent、App 各自 commit；镜像 digest；每目标的 Product/Agent OpenAPI hash | 同左，**从 B 已部署实例**检验而不是从 A 查询 |
| 配置和密钥 | A 专属私有 env、签名和邀请码管理操作员身份 | B 专属私有 env、托管服务权限、Resend key、Google/Apple signing |
| 发布前拒绝 | A API/CA 不符、邀请码开关缺失、APK 身份/签名不符、管理 UI 安全门禁未过 | URL 或资源仍占位、落到 A 域名/库/桶、App 仍显示邀请码、AAB/IPA 身份不符、合规资料未齐 |
| 回退 | 回滚 A Backend/Agent 镜像或停止新 APK 发放；保留旧客户端兼容，DB 不自动降级 | B 独立回退；暂停 Play 轨道/TestFlight 链接或构建分发；DB 迁移审查后滚前/向前修复，不影响 A |

实施建议切片（**每一片完成 CI 和独立确认后再继续**）：

1. 固定 A 的既有发布资产与运行时清单；修复管理后台服务密钥暴露，锁定 A invite-only 产物，建立 A 下载/邀请管理的权限隔离和回归测试。
2. 增加明确的 `deployment_target`/环境配置契约：后端和 Agent `release.py`、两条 GitHub workflow 的 root/lock/host guard，App 构建/发布命令与两份目标 config；**不要**把两套目标都映射成现有单个 `staging` 发布入口。加错配/占位值失败测试。
3. 批准 B 的基础设施和域名，建私有托管存储与网络，测空库迁移、连接/恢复，发布 B Backend → Agent；核验 B live OpenAPI 与两个 manifest，禁止跨目标调用。
4. 获得 Resend 所需域名、DNS 和 key 授权，部署 B 邮件 worker，真实收件箱完整登录/重置闭环；对 B App 源码做契约和端到端测试。
5. 按两套 **分别**预留版本号/build number、签名与发布：A 仅 APK+二维码+私有邀请码后台；B Play AAB 测试轨道和 TestFlight 新 IPA。各自记录不可变构建来源、签名、API URL、契约 hash、审核与真实设备验收。

**目前的阻断项（不得写成“已经实现两套”）：** B 的主机/域名/托管存储/独立原生 Android 身份/发布入口/Play 身份及 Resend 未就绪；B 发布 CLI 和 App 实际构建被明确阻断。A 的邀请码本地门禁已补，但尚无新 APK 真实构建/发布验证，独立管理入口未实现。现有可执行 workflow 仍只有 A 的 `staging` 及另一个 `production` 目标；不得把静态预检当作两条完整云端发布链路。

## 5. 必须留给负责人确认的决定

- A 的现有资源清单、谁有 DNS/下载仓库/邀请码后台管理权限、管理页安全修复与 key 事故处理方案。
- B 的云供应商/具体北美区域、托管 PostgreSQL/Redis/S3(或 OSS) 选型、备份保留与数据驻留/隐私要求、外部 API 域名及 TLS。
- 是否让 B iOS 继续沿用 `com.momcozy.mai.staging`；B Android 新 Play 包名与平台账号、测试轨道、发布地区；A/B 是否必须可同时安装。
- Product/Agent 接口若有差异，谁审批新增/废弃 endpoint 和客户端兼容窗口；两链路各自锁定哪一组源 commit。
- B 的 Resend 发件子域名、第三方数据处理、审核账号、用户外测方式；每个云端改动、DNS/key/商店提审均在实际操作时再确认。

验收标准不是“两个包都能编译”：A 和 B 都要拿**各自**的 Backend+Agent manifest 与 live OpenAPI、证书、数据库/缓存/桶隔离证据、登录方式和真实设备安装流程逐项对照；不能用 A 的通过记录给 B 背书。

参考：Google 官方 [Android App Bundle](https://developer.android.com/guide/app-bundle)；Apple 官方 [TestFlight 外部测试](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)；具体政策与费用发布前复核最新版本。
