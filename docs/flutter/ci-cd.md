# Flutter CI/CD 与发布

更新日期：2026-09-24。环境统一为 `local`、`staging`、`production`；`test`
仅表示自动化测试，不再是 Flutter flavor 或部署环境。

## CI

`.github/workflows/app-ci.yml` 在 pull request、`main` 和 `integration/**`
push 上执行：

1. Python 构建/契约测试；
2. Android packaging 与安全隐私检查；
3. Dart format、Flutter analyze 和非 golden 测试；
4. macOS 15 上的 golden 测试；
5. 使用 `config/environments/local.json` 构建可安装的 local debug APK；
6. 上传短期 CI artifact。

CI 不连接 staging，不签正式包，也不发布 GitHub Release 或 App Store。

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
