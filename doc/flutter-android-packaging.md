# Flutter Android 打包策略

## P0 临时策略

当前 Flutter shell 仍是迁移 PoC，不作为商店或内部正式分发包。

| 项目 | P0 决策 |
| --- | --- |
| 现有 Capacitor appId | `com.momcozymai.app` |
| Flutter local appId | `com.momcozymai.app.flutterpoc.local` |
| Flutter staging appId | `com.momcozymai.app.flutterpoc.staging` |
| Flutter production-shaped appId | `com.momcozymai.app.flutterpoc` |
| Flutter namespace | `com.momcozymai.momcozy_flutter_app` |
| App label | `Momcozy Local` / `Momcozy Staging` / `Momcozy` |
| Debug signing | 使用 Android debug keystore，仅用于本机和真机 smoke。 |
| Release signing | 通过环境变量注入；未注入时 release build 使用 debug signing，仅允许作为本地 smoke artifact。 |
| Gradle flavor | 已启用 `local`、`staging`、`production` 三个 flavor。 |

## 为什么 PoC appId 必须独立

- 可与当前 Web/Capacitor 包 `com.momcozymai.app` 同机安装，便于对照测试。
- 不会覆盖用户已有的生产 App 数据、通知、权限和 BLE 绑定状态。
- 后续 Android platform channel PoC 可以单独验证，不影响当前可交付 App。

## Flavor 矩阵

当前 Gradle productFlavors：

```text
local: 本地开发和 debug smoke，独立 appId。
staging: 后端 staging / internal distribution smoke，独立 appId。
production: production-shaped artifact；正式 cutover 前仍不覆盖当前 Capacitor appId。
```

进入真实分发或灰度前必须先完成：

```text
[x] CI 固定 Flutter / Android / JDK 版本
[x] release keystore secret 注入方案
[ ] appId 与深链、通知、FileProvider authorities 矩阵
[ ] 数据迁移和回滚包策略
[ ] 真机覆盖当前生产 App 与 Flutter PoC 同装场景
```

Release signing 环境变量：

```text
MOMCOZY_FLUTTER_RELEASE_STORE_FILE
MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD
MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS
MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD
```

CI / internal distribution 可用 `MOMCOZY_REQUIRE_RELEASE_SIGNING=1` 强制缺少 signing env 时失败。

## 当前构建命令

```bash
npm run flutter:release-gate
```

或在 `flutter_app/` 下单独构建：

```bash
flutter build apk --debug --flavor local
flutter build apk --release --flavor staging --dart-define=MOMCOZY_ENV=staging
```

当前本机验证：

```text
[x] local debug APK `build/app/outputs/flutter-apk/app-local-debug.apk` 可生成
[x] staging release APK `build/app/outputs/flutter-apk/app-staging-release.apk` 可生成
```
