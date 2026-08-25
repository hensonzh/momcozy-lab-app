# Flutter CI/CD 与 Staging 发布

当前只有 `local`、CI 和 `staging` 交付链路，没有 production 发布配置。
`unified` 是 Android 安装/分发 flavor，不是新的服务器环境：它使用独立的
`com.momcozymai.app.flutterpoc.unified` applicationId，但编译时固定注入
`MOMCOZY_ENV=staging`，连接现有 Product Backend 与 Agent Runtime staging SNI
入口。

## 持续集成

`.github/workflows/app-ci.yml` 在 pull request、`main` 和
`integration/**` push 上运行，并固定 Flutter 3.44.4、Java 17、Node 20 和
Python 3.13。门禁包括：

1. 构建脚本与双服务 OpenAPI 快照契约测试；
2. Android packaging 与安全隐私静态检查；
3. `dart format`、`flutter analyze --no-pub`、`flutter test --no-pub`；
4. 使用两个 staging HTTPS 地址构建 `unified` debug smoke APK；
5. 将该 APK 保存为短期 workflow artifact。

CI 不签正式包、不写 GitHub Releases、不更新 Pages，也不部署后端。

## 受保护的 Staging 发布

`.github/workflows/app-staging-release.yml` 只能手动触发，使用 GitHub
`staging` environment 和串行 concurrency。应为该 environment 配置 required
reviewer，并设置：

- `FLUTTER_RELEASE_KEYSTORE_BASE64`
- `FLUTTER_RELEASE_STORE_PASSWORD`
- `FLUTTER_RELEASE_KEY_ALIAS`
- `FLUTTER_RELEASE_KEY_PASSWORD`
- `STAGING_APP_API_TOKEN`
- `STAGING_APP_USER_ID`
- `STAGING_APP_BABY_ID`
- `RELEASES_GH_TOKEN`，仅授予 `hensonzh/momcozy-lab-releases` 所需的
  Releases/Contents 权限
- `STAGING_SSH_HOST`、`STAGING_SSH_PORT`、`STAGING_SSH_USER`、
  `STAGING_SSH_PRIVATE_KEY`、`STAGING_SSH_KNOWN_HOSTS`，只读获取当前两份
  `/opt/momcozy-lab/current/*/release-manifest.json`

手动输入必须来自已经部署的两份服务 release manifest：

- Product Backend full commit、image digest、OpenAPI SHA-256；
- Agent Runtime full commit、image digest、OpenAPI SHA-256。

工作流会先校验 full commit/digest 格式，通过已验证 host key 的 SSH 读取当前部署
manifest 并与全部输入逐项比对，确认 OpenAPI hash 与 App 固定快照一致，再通过内置
staging CA 下载两个公网 `/openapi.json` 并做 JSON 语义等价校验。之后强制正式签名，
记录签名证书 SHA-256，并同时启用 Product smoke 与 Agent SSE smoke；任一 smoke
被关闭或失败都不会构建可发布结果。

release gate 只构建一次 `app-unified-release.apk`。发布步骤通过
`MOMCOZY_APK_INPUT` 复用这同一文件，生成 SHA-256、下载页和包含 App commit、
两份服务 commit/image digest/OpenAPI hash 的 manifest。GitHub Release tag 和
APK 名分别为：

```text
unified-android-v<version>-<build>
momcozy-unified-android-staging-<version>-<build>.apk
```

每个 tag 同时保存 APK、checksum 和一份不含生成时间的 provenance JSON；后者固定
App commit、服务 commit/digest/OpenAPI hash、签名证书和 APK hash。已存在 tag 时，
脚本只接受三份文件逐字相同；任一内容不同都会失败并要求增加 build number，绝不
覆盖资产。Pages 只写 `/unified/` 命名空间，不改动仓库根页面或其他项目目录。

## 版本、回滚与边界

- 每次对外内测发布先递增 `pubspec.yaml` build number。
- APK、SHA-256、immutable provenance、下载页 manifest 和 workflow artifact 都来自
  同一个已签名 APK。
- App 回滚是重新分发一个更高 build number、但指向兼容服务合同的新包；不要覆盖
  已发布 tag/asset。
- 后端回滚不会自动触发 App 回滚。发布 App 前必须重新执行双服务 live join gate。
- keystore 只物化在 runner 临时目录，任务结束时删除；密码和 token 不写入产物。
- production flavor 仍仅用于 production-shaped 本地验证，当前工作流拒绝发布它。
