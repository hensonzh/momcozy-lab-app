# Flutter Android 打包策略

## P0 临时策略

当前 Flutter shell 仍是迁移 PoC，不作为商店或内部正式分发包。

| 项目 | P0 决策 |
| --- | --- |
| 现有 Capacitor appId | `com.momcozymai.app` |
| Flutter PoC appId | `com.momcozymai.app.flutterpoc` |
| Flutter namespace | `com.momcozymai.momcozy_flutter_app` |
| App label | `Momcozy Flutter PoC` |
| Debug signing | 使用 Android debug keystore，仅用于本机和真机 smoke。 |
| Release signing | 暂不接入正式签名；当前 release 只允许作为本机构建 smoke artifact。 |
| Gradle flavor | P0 不启用 productFlavors，避免破坏 `flutter build apk --debug` 的简单构建路径。 |

## 为什么 PoC appId 必须独立

- 可与当前 Web/Capacitor 包 `com.momcozymai.app` 同机安装，便于对照测试。
- 不会覆盖用户已有的生产 App 数据、通知、权限和 BLE 绑定状态。
- 后续 Android platform channel PoC 可以单独验证，不影响当前可交付 App。

## Flavor 引入条件

在进入真实分发或灰度前，再引入 Gradle productFlavors：

```text
internal: 内部测试包，独立 appId，接入测试后端和 debug/adhoc 签名。
candidate: 生产候选包，接近正式 appId，接入 release signing dry-run。
production: 仅在迁移 cutover 获批后使用 `com.momcozymai.app`。
```

引入 flavor 前必须先完成：

```text
[ ] CI 固定 Flutter / Android / JDK 版本
[ ] release keystore secret 注入方案
[ ] appId 与深链、通知、FileProvider authorities 矩阵
[ ] 数据迁移和回滚包策略
[ ] 真机覆盖当前生产 App 与 Flutter PoC 同装场景
```

## 当前构建命令

```bash
cd flutter_app
flutter build apk --debug
flutter build apk --release
```

预期 debug APK applicationId：

```text
com.momcozymai.app.flutterpoc
```

当前本机验证：

```text
[x] debug APK build/app/outputs/flutter-apk/app-debug.apk 可生成
[x] release APK build/app/outputs/flutter-apk/app-release.apk 可生成
```
