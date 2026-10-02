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

A 的 `app-ci.yml` 原本监听所有 PR，因此目标为 `dev` 的 PR 也可能同时运行通用/A 导向检查；B 的合并门禁以独立 `app-b-ci / b-ci` 为准。B 正式商店构建/上传另走审批后的发布作业。

## B 商店包：从远程不可变提交构建（待配置启用）

上一轮本地 worktree 的 AAB/IPA 只作为测试证据；已上传的 iOS build 64 不能复用。
当前源码预留 `1.0.0+65`。`.github/workflows/app-b-store-build.yml` **不会由普通 `dev` push 自动触发**：

1. B App 源码合入远程 `dev`，其准确 commit 的 `app-b-ci` push run 通过；GitHub `dev` 分支保护须要求 PR 评审、`b-ci` 必需检查且禁止 force push。
2. 在 GitHub 建立独立 `b-store-build` Environment，**由管理员配置** required reviewers、仅允许 B 发布 tag 的 deployment branch/tag policy；为 `b-store-v*` 设置禁止删除/更新的 tag ruleset。仅在此 Environment 设置 B 专属密钥：`B_STORE_BUILD_APPROVED=north-america-staging`、`B_STORE_ENCRYPT_CERT_BASE64`（接收方 X.509 **公钥证书**）、`B_PLAY_KEYSTORE_BASE64`、`B_PLAY_STORE_PASSWORD`、`B_PLAY_KEY_ALIAS`、`B_PLAY_KEY_PASSWORD`、`B_IOS_P12_BASE64`、`B_IOS_P12_PASSWORD`、`B_IOS_PROFILE_BASE64`，以及 vars `B_PLAY_UPLOAD_CERT_SHA256`、`B_IOS_TEAM_ID`。iOS 描述文件必须对应 `com.momcozy.mai.staging` 的 App Store Connect 分发身份，Play 上传证书指纹须和预期一致；解密私钥不得放入 GitHub 或仓库。A 的 `staging` Environment 不复用。GitHub 作业的默认令牌不能读取管理权限 API，因此保护/审批设置必须由管理员在启用前独立验收，不能假装已被作业自证。
3. 核对商店当前最高 build/version 后，在已通过 CI 的**当前远程 `dev` HEAD** 建立并推送唯一 tag `b-store-v1.0.0-65`。工作流检查 tag、源码 SHA、同 SHA 的成功 CI push run、B HTTPS ready 和**线上 OpenAPI 与 App 固定快照一致**；不满足就失败，不生成发布包。tag 不是普通 `dev` push，也不应重新指向其他 SHA；今后每次分发都先提高 build number。
4. 审批后，独立 GitHub runner 检出精确 SHA，各自签名构建 Play AAB / TestFlight IPA；验证 AAB 签名与上传证书指纹、IPA 代码签名/导出描述文件/entitlements、包身份与 build number。只上传加密后的短期 Actions artifact，附密文 SHA-256、明文 SHA-256 和源码 SHA；接收方解密后重新计算明文 SHA-256 再交商店。**该作业不自动上传 Google Play、App Store Connect，也不扩大测试群组或提交生产审核**；商店上传需要单独受控流程和接收状态验收。缺少实际受控签名构建与商店接收回执时，不能称为分发验收通过。

此流程目前只有代码草稿；远程 `dev` 尚无这些提交，仓库也没有 `dev` 分支保护或 `b-store-build` Environment，更没有经 CI 跑通的正式制品。不能因本地脚本通过就称为已经启用。

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
