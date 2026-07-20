# Flutter Release Gate

## 命令

```bash
make flutter-release-gate
```

该 gate 会在仓库根目录顺序执行：

```text
node scripts/check-flutter-android-packaging.mjs
node scripts/check-flutter-security-privacy.mjs
flutter pub get
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/staging_smoke.dart
flutter build apk --debug --flavor local
flutter build apk --release --flavor staging --dart-define=MOMCOZY_ENV=staging
```

`tool/staging_smoke.dart` 默认安全 skip；只有设置 `MOMCOZY_STAGING_SMOKE=1` 才会直连后端。

`scripts/build-flutter-android-apk.mjs` 在构建 release APK 前会执行 `flutter clean` 和 `flutter pub get`，避免分发包复用上一源码版本的 AOT 快照。debug 构建仍保留增量构建以缩短本地开发反馈时间。

## 内测构建与上传

```bash
./scripts/build-flutter-app.sh
```

该脚本默认在构建下载页、APK 和二维码后，将 `dist/android-apk/` 上传到 `ubuntu@54.254.112.41:/var/www/momcozy/android-apk/`。上传使用 rsync delay-updates，旧版本 APK 会保留。

只生成本地产物、不上传：

```bash
MOMCOZY_SKIP_UPLOAD=1 ./scripts/build-flutter-app.sh
```

可通过 `MOMCOZY_UPLOAD_TARGET` 和 `MOMCOZY_RSYNC_RSH` 覆盖上传目标与 SSH 参数。

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
