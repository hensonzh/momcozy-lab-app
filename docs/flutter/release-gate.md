# Flutter Release Gate

## 命令

```bash
MOMCOZY_API_BASE_URL=https://product-staging.example.test \
MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test \
make flutter-release-gate
```

`example.test` 是文档占位域名，实际执行发布 gate 时必须替换为已验收的
staging 服务地址。

该 gate 会在仓库根目录顺序执行：

```text
node scripts/check-flutter-android-packaging.mjs
node scripts/check-flutter-security-privacy.mjs
flutter pub get
dart format --set-exit-if-changed lib test integration_test tool
flutter analyze
flutter test
dart run tool/staging_smoke.dart
node scripts/build-flutter-android-apk.mjs --mode debug --flavor local
node scripts/build-flutter-android-apk.mjs --mode release --flavor staging \
  --dart-define=MOMCOZY_ENV=staging \
  --dart-define=MOMCOZY_API_BASE_URL=https://product-staging.example.test \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test
```

所有受支持的打包封装都会执行同一套 API 配置校验。`local` 缺省注入 Product
`http://127.0.0.1:8769` 与 Agent `http://127.0.0.1:8010`；`staging` 和
`production` 必须显式提供两个非空、非 loopback HTTPS URL，否则在运行
Flutter/Gradle 前失败。可用下面的命令只检查 release gate 配置：

```bash
MOMCOZY_API_BASE_URL=https://product-staging.example.test \
MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test \
node scripts/run-flutter-release-gate.mjs --check-config
```

`tool/staging_smoke.dart` 默认安全 skip；只有设置 `MOMCOZY_STAGING_SMOKE=1` 才会直连后端。

`scripts/build-flutter-android-apk.mjs` 在构建 release APK 前会执行 `flutter clean` 和 `flutter pub get`，避免分发包复用上一源码版本的 AOT 快照。debug 构建仍保留增量构建以缩短本地开发反馈时间。

## 动态姿态 Release 真机门禁

动态姿态相关改动在 ARM64 Android 设备或模拟器上额外执行 release 集成测试。默认门禁只有在端侧模型明确发出 `model_ready`，并连续取得 3 帧相机推理结果后才通过：

```bash
cd android
./gradlew app:clean app:connectedStagingReleaseAndroidTest --no-build-cache \
  -Ptarget="$(pwd)/../integration_test/motion_pose_android_test.dart"
```

测试 instrumentation 会在启动前授予 CAMERA。若设备摄像头画面包含单人全身，可在命令末尾追加 `-Pdart-defines=TU9USU9OX1BPU0VfUkVRVUlSRV9QRVJTT049dHJ1ZQ==`，启用严格门禁：连续 3 帧都必须识别到 33 个关键点。该值是 `MOTION_POSE_REQUIRE_PERSON=true` 的 Base64 编码。测试使用干净构建的 release/R8 产物，避免 Gradle 增量任务复用普通 App 入口的原生库，并专门防止仅在 debug 包正常、release 包因混淆而无法加载 MediaPipe 的回归。

## 内测构建与发布

```bash
MOMCOZY_API_BASE_URL=https://product-staging.example.test \
MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test \
./scripts/build-flutter-app.sh
```

该脚本默认将 APK 和 SHA256 文件上传到公开仓库
`hensonzh/momcozy-lab-releases` 的 GitHub Release，并更新同仓库的
GitHub Pages 极简下载页。APK 不进入 Git 历史。

只生成本地产物、不上传：

```bash
MOMCOZY_API_BASE_URL=https://product-staging.example.test \
MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test \
MOMCOZY_SKIP_UPLOAD=1 ./scripts/build-flutter-app.sh
```

可通过 `MOMCOZY_GITHUB_RELEASE_REPO` 和 `MOMCOZY_DOWNLOAD_BASE_URL`
覆盖公开仓库与 GitHub Pages 地址。发布前需要安装并登录 GitHub CLI。

## Android Flavors

| Flavor | Application ID | 用途 |
|---|---|---|
| `local` | `com.momcozymai.app.flutterpoc.local` | 本地开发和 debug smoke。 |
| `staging` | `com.momcozymai.app.flutterpoc.staging` | 后端 staging / internal distribution smoke。 |
| `production` | `com.momcozymai.app.flutterpoc` | Flutter production-shaped artifact；包名变更须经过独立发布审批。 |

## Release Signing

默认情况下，release build 使用 debug signing，仅可作为本地 smoke artifact。

CI / internal distribution 如果要启用真实 release signing，需要通过环境变量注入：

```text
MOMCOZY_FLUTTER_RELEASE_STORE_FILE
MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD
MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS
MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD
```

强制要求 release signing：

```bash
MOMCOZY_API_BASE_URL=https://product-staging.example.test \
MOMCOZY_AGENT_API_BASE_URL=https://agent-staging.example.test \
MOMCOZY_REQUIRE_RELEASE_SIGNING=1 make flutter-release-gate
```

密钥、密码和 keystore 文件不得提交到仓库。

## 内测证书信任

当前内测包会在以下条件全部满足时加载随包证书：

- `MOMCOZY_ENV=staging`
- API 使用 `https`
- API 主机为 `lute-momcozylab.luteos.cloud`
- API 端口为 `8443`

该方案只是将指定自签名证书加入 Dart 网络栈的信任根，不会关闭主机名、有效期或证书链校验，也不会影响 `local` 和 `production` 构建。证书有效期截至 2026-08-15；服务器证书续签或替换后，必须同步替换 `assets/certificates/lute-momcozylab-staging.pem` 并重新构建内测包。

## 当前边界

- 该 gate 覆盖非真机构建、静态检查、单元/widget/fixture 测试和 staging smoke harness。
- 该 gate 静态校验 Flutter appId、FileProvider authority 和外部 deep link 边界。
- 根 release gate 仅覆盖当前 Flutter 客户端及其原生集成。
- 真机安装、BLE、通知、后台服务、Doze、电池优化和真泵行为仍属于 L4 device lab。
