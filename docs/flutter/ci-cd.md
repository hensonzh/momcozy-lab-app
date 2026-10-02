# Flutter CI/CD 与发布

更新日期：2026-10-02。环境统一为 `local`、`staging`、`production`；`test`
仅表示自动化测试，不再是 Flutter flavor 或部署环境。

## CI

`.github/workflows/app-ci.yml` 在 pull request、`main` 和 `integration/**`
push 上执行：

1. Python 构建/契约测试；
2. Android packaging 与安全隐私检查；
3. Dart format、Flutter analyze 和非 golden 测试；
4. macOS 15 上的 golden 测试；
5. 使用 A 的 `staging` flavor 编译 Android arm64 debug APK 并核对 PDF native library。

现有 `app-ci.yml` 不上传 artifact；CI 不连接 staging，不签正式包，也不发布 GitHub Release 或 App Store。

### B 美东 `dev` CI

`.github/workflows/app-b-ci.yml` 在目标为 `dev` 的 PR、`dev` push 或手动派发时运行，与 A 的发布流程分离：

1. 用经审核的非密钥 `config/release-lanes/north-america-staging.ci.json` 校验 B 两个 HTTPS 域名、Play 包名与 iOS Bundle ID；生成临时 Flutter defines，强制 `MOMCOZY_INTERNAL_INVITE_LOGIN=false`。该文件只是 CI 编译输入，不是商店发布配置。
2. 运行脚本/后端契约、Android 打包与隐私检查、Dart format/analyze、非 golden 测试、显式邮箱登录模式 Widget 测试及 macOS golden 测试。
3. 独立 runner 编译 Play flavor 的 **debug APK**（检查包名及 PDF native library）和 iOS staging scheme 的**无签名 simulator App**（检查 Bundle ID）。B 的公信 CA 域名不能启用 A 的内部 CA 信任路径。
4. `b-ci` 汇总门禁要求上述四项作业全部成功。工作流不获取签名或商店密钥、不生成可分发的 AAB/IPA、不上传商店、不部署后端。push 到 `dev` 的 CI 成功也不意味着 B 已部署或 App 已发布。

A 的 `app-ci.yml` 原本监听所有 PR，因此目标为 `dev` 的 PR 也可能同时运行通用/A 导向检查；B 的 CI 以独立 `app-b-ci / b-ci` 汇总作业为准。B 的签名构建由新发布标签触发，不自动上传商店。

## B 商店包：从远程 `dev` 提交自动签名构建

截至 2026-10-02，`1.0.0+67` 的 `b-store-v1.0.0-67` 标签指向 App 提交
`427a7dcfb0105b95cdd45d921c31b2cb6948e22c`；该提交的 `app-b-ci` push run
`37008400750` 通过。`app-b-store-build.yml` **不会由普通 `dev` push 自动触发**，
只响应新的 `b-store-v*` 标签。签名构建运行 `37009537423` 的第 2 次尝试中，
preflight、Android AAB、iOS IPA 全部成功并上传加密 Actions artifact。

1. App 源码先提交到远程 `dev`，同一 SHA 的 B CI push run 必须成功。GitHub 上的
   `dev` branch ruleset 禁止删除和非快进更新；**目前没有强制 PR 评审或 required
   status check**，不能把 workflow 的 tag preflight 当作分支合并保护。
2. 独立 GitHub Environment `b-store-build` 仅允许 `b-store-v*` tag 访问 B 专属
   签名密钥；无 Required reviewers、无等待计时，满足门禁即自动启动；管理员绕过
   仍被禁用。另一条 tag ruleset 禁止改写或删除现有 `b-store-v*` tag，两条规则集
   都无 bypass actors。仓库管理员须定期核对这些**仓库侧**保护及密钥配置；
   workflow 的默认令牌不能自证管理员设置。Environment 的非秘密变量为
   `B_PLAY_UPLOAD_CERT_SHA256` 和 `B_IOS_TEAM_ID`；签名/加密 secrets 仍仅存放
   于这个 Environment，不写入仓库，也不复用 A 的 `staging` Environment。
3. 每次构建须先核对商店已使用的最高 build number、提高 `pubspec.yaml` build
   number，等待远程 `dev` 该 SHA 的 B CI 成功，然后在**当前远程 `dev` HEAD**
   新建唯一 tag `b-store-v<version>-<build>`。不能移动旧标签。preflight 再校验
   精确 SHA、同 SHA 的成功 B CI、版本号、B HTTPS ready 与线上 OpenAPI/固定快照。
4. 独立 runner 从该 SHA 构建 Play 签名 AAB 与 TestFlight 签名 IPA，校验包名、
   build number、上传证书/IPA 签名与描述文件。仅上传加密后的短期 Actions artifact，
   附密文和明文 SHA-256、源码 SHA；接收方解密后须重算明文哈希并复核签名。
   **构建成功不等于上传或分发**：Google Play/TestFlight 上传、测试群组和审核
   仍需独立受控流程及商店接收回执。

`1.0.0+67` 首次尝试在旧审批规则下等待；移除 Required reviewers 后 GitHub
把尚未启动 runner 的两个作业标为失败。对**同一运行、同一 tag/SHA**执行失败作业
rerun 后，第 2 次尝试无需审批并成功。这不是新建版本或重用另一构建号。

## Staging Android 发布

`.github/workflows/app-staging-release.yml` 只能从 `main` 手动触发，并绑定
GitHub `staging` Environment。它从
`config/environments/staging.json` 读取两项非秘密 API URL，并要求：

```text
STAGING_APPROVERS                         repository variable
RELEASE_ROOT                             staging environment variable
RELEASE_LOCK_PATH                        staging environment variable
SSH_HOST / SSH_PORT / SSH_USER           staging environment secrets
SSH_PRIVATE_KEY / SSH_KNOWN_HOSTS        staging environment secrets
FLUTTER_RELEASE_KEYSTORE_BASE64          staging environment secret
FLUTTER_RELEASE_STORE_PASSWORD           staging environment secret
FLUTTER_RELEASE_KEY_ALIAS                staging environment secret
FLUTTER_RELEASE_KEY_PASSWORD             staging environment secret
STAGING_SMOKE_INVITE_CODE                staging environment secret
STAGING_SMOKE_DEVICE_ID                  staging environment secret
RELEASES_GH_TOKEN                        staging environment secret
```

工作流校验 Backend/Agent 的 commit、image digest、OpenAPI hash 和 release
manifest，运行 staging live smoke，构建签名 APK，再在相同跨仓库锁下重新读取
manifest 后发布 GitHub Release 与 `/staging/` 下载页。

## Production 商店构建

统一入口：

```bash
node scripts/build-mobile-app.mjs \
  --platform android \
  --environment production \
  --mode release \
  --format appbundle

node scripts/build-mobile-app.mjs \
  --platform ios \
  --environment production \
  --mode release \
  --format ipa
```

生产构建要求先从 `config/environments/production.json.example` 创建被 Git
忽略的 `production.json`，并填入已审核的 HTTPS API。Android release 还要求完整
keystore 环境变量；iOS IPA 要求已确认 Bundle ID、Apple Team、distribution
certificate 和 provisioning profile。当前尚未自动上传 App Store Connect。

详细顺序见 [`../deployment/environment-workflow.md`](../deployment/environment-workflow.md)。
