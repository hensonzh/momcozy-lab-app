# Flutter Release Gate

## 命令

```bash
make flutter-release-gate
```

该 gate 会在 `flutter_app/` 中顺序执行：

```text
node scripts/check-flutter-android-packaging.mjs
node scripts/check-flutter-security-privacy.mjs
flutter pub get
dart format --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/staging_smoke.dart
dart run tool/storage_migration_dry_run.dart
flutter build apk --debug --flavor local
flutter build apk --release --flavor staging --dart-define=MOMCOZY_ENV=staging
```

`tool/staging_smoke.dart` 默认安全 skip；只有设置 `MOMCOZY_STAGING_SMOKE=1` 才会直连后端。

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

- 该 gate 覆盖非真机构建、静态检查、单元/widget/fixture 测试、staging smoke harness 和 storage migration dry-run。
- 该 gate 静态校验 Flutter appId、FileProvider authority 和外部 deep link 边界。
- 根 release gate 仅覆盖当前 Flutter 客户端及其原生集成。
- 真机安装、BLE、通知、后台服务、Doze、电池优化和真泵行为仍属于 L4 device lab。
