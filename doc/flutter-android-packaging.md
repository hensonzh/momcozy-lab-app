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
[x] appId 与深链、通知、FileProvider authorities 矩阵
[x] 数据迁移和回滚包策略
[ ] 真机覆盖当前生产 App 与 Flutter PoC 同装场景
```

## AppId / Deep Link / FileProvider 矩阵

| 项目 | 当前 Capacitor App | Flutter local | Flutter staging | Flutter production-shaped |
| --- | --- | --- | --- | --- |
| Application ID | `com.momcozymai.app` | `com.momcozymai.app.flutterpoc.local` | `com.momcozymai.app.flutterpoc.staging` | `com.momcozymai.app.flutterpoc` |
| Launcher label | `Momcozy` | `Momcozy Local` | `Momcozy Staging` | `Momcozy` |
| Deep link / custom scheme | `custom_url_scheme=com.momcozymai.app`；当前 manifest 未声明外部 `VIEW/BROWSABLE` filter | 未声明 | 未声明 | 未声明 |
| FileProvider authority | `${applicationId}.fileprovider`，即 `com.momcozymai.app.fileprovider` | 未声明 | 未声明 | 未声明 |
| Notification owner | 当前 Capacitor Android resources 和 services | Flutter PoC foreground service notification，独立 appId scope | 同左 | 同左 |
| 数据作用域 | 当前生产 WebView/Capacitor storage 和 Android native service store | Flutter PoC 独立安装，不覆盖生产数据 | 同左 | 同左，cutover 前仍不覆盖生产 appId |

静态校验命令：

```bash
npm run flutter:packaging-check
```

该命令会校验当前 Capacitor rollback appId 保持 `com.momcozymai.app`，Flutter PoC flavor appId 保持独立，且 Flutter PoC 当前不声明 FileProvider authority 或外部 deep link。

## 回滚包和数据迁移策略

- 迁移期间当前 Capacitor App 仍是 rollback source，`npm run build` 必须保持可用；`npm run flutter:release-gate` 已把这一步纳入非真机 gate。
- Flutter PoC 使用独立 appId，同机安装不会覆盖当前生产 App 的 WebView storage、Android native service store、通知渠道、权限授权或 FileProvider authority。
- 正式 cutover 前不能把 Flutter production-shaped appId 改成 `com.momcozymai.app`；如需覆盖生产包，必须先完成真机同装/覆盖、storage migration、通知渠道、BLE 绑定和 rollback package rehearsal。
- 回滚时优先发布现有 Capacitor 包的更高 versionCode hotfix；Flutter 独立 PoC 包可直接停止灰度或下架，不影响生产 App 数据。
- 非真机 gate 会执行 `npm run flutter:rollback-check`，在 `dist/flutter-rollback-manifest.json` 写入 Web rollback bundle 和 Flutter APK artifact 的 size / sha256，作为发布交接和回滚包核对清单。
- 已迁移到 Flutter 的 legacy storage 规则以 `dart run tool/storage_migration_dry_run.dart` 为非真机前置；真实 installed data rollback 仍需 device lab 和 release owner 确认。

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
