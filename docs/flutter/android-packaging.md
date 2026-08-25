# Flutter Android 打包策略

## 当前策略

当前 Flutter 客户端保持既有 appId，并通过 flavor 隔离 local、staging 和 production-shaped 构建。

| 项目 | 当前值 |
| --- | --- |
| Flutter local appId | `com.momcozymai.app.flutterpoc.local` |
| Flutter staging appId | `com.momcozymai.app.flutterpoc.staging` |
| Flutter production-shaped appId | `com.momcozymai.app.flutterpoc` |
| Flutter namespace | `com.momcozymai.momcozy_flutter_app` |
| App label | 当前三个 flavor 统一为 `Momcozy Lab`；安装隔离仍由 appId 保证。 |
| Debug signing | 使用 Android debug keystore，仅用于本机和真机 smoke。 |
| Release signing | 通过环境变量注入；未注入时 release build 使用 debug signing，仅允许作为本地 smoke artifact。 |
| Gradle flavor | 已启用 `local`、`staging`、`production` 三个 flavor。 |

## 为什么当前 appId 保持不变

- 避免未规划的包迁移破坏用户已安装数据、通知、权限和 BLE 绑定状态。
- local、staging 和 production flavor 仍有清晰的安装与发布边界。

## Flavor 矩阵

当前 Gradle productFlavors：

```text
local: 本地开发和 debug smoke，独立 appId。
staging: 后端 staging / internal distribution smoke，独立 appId。
production: production-shaped artifact；保持当前基础 appId。
```

进入真实分发或灰度前必须先完成：

```text
[x] CI 固定 Flutter / Android / JDK 版本
[x] release keystore secret 注入方案
[x] appId 与深链、通知、FileProvider authorities 矩阵
[x] 数据迁移 dry-run 策略
[ ] 真机升级、覆盖安装和回滚场景
```

## AppId / Deep Link / FileProvider 矩阵

| 项目 | Flutter local | Flutter staging | Flutter production-shaped |
| --- | --- | --- | --- |
| Application ID | `com.momcozymai.app.flutterpoc.local` | `com.momcozymai.app.flutterpoc.staging` | `com.momcozymai.app.flutterpoc` |
| Launcher label | `Momcozy Lab` | `Momcozy Lab` | `Momcozy Lab` |
| Deep link / custom scheme | 未声明 | 未声明 | 未声明 |
| FileProvider authority | 未声明 | 未声明 | 未声明 |
| Notification owner | Flutter foreground service notification，独立 appId scope | 同左 | 同左 |
| 数据作用域 | flavor 独立安装与存储 | 同左 | production scope |

静态校验命令：

```bash
make flutter-packaging-check
```

该命令会校验 Flutter flavor appId 保持独立，且 Flutter 当前不声明 FileProvider authority 或外部 deep link。

## 数据迁移策略

- 当前 appId 保持不变；未来如需变更，必须先评估 installed data、Android native service store、通知渠道、权限授权和 FileProvider authority。
- 包名变更前必须完成真机升级/覆盖、storage migration、通知渠道和 BLE 绑定验证。

Release signing 环境变量：

```text
MOMCOZY_FLUTTER_RELEASE_STORE_FILE
MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD
MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS
MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD
```

## MotionPose 模型供应

Android 构建继续使用固定版本的 MediaPipe Pose Landmarker Lite 模型，并在打包前校验固定 SHA-256。首次在线构建会把校验后的模型写入 Gradle User Home 的 Momcozy 专用缓存；后续 clean build 可复用该缓存。

离线或隔离网络环境可显式提供已经过审批的模型文件：

```bash
MOMCOZY_POSE_MODEL_FILE=/absolute/path/to/pose_landmarker_lite.task \
  node scripts/build-flutter-android-apk.mjs \
    --mode release \
    --flavor staging \
    --dart-define=MOMCOZY_ENV=staging \
    --dart-define=MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
    --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

本地文件仍必须匹配 Gradle 配置中的固定 SHA-256；离线模式下既没有有效缓存、也没有提供该变量时，构建会快速失败，不会隐式访问网络。

CI / internal distribution 可用 `MOMCOZY_REQUIRE_RELEASE_SIGNING=1` 强制缺少 signing env 时失败。

## 当前构建命令

```bash
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443 \
make flutter-release-gate
```

或直接在仓库根目录构建：

```bash
node scripts/build-flutter-android-apk.mjs \
  --mode debug \
  --flavor local

node scripts/build-flutter-android-apk.mjs \
  --mode release \
  --flavor staging \
  --dart-define=MOMCOZY_ENV=staging \
  --dart-define=MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

低层 APK、下载页和一键发布封装共享同一配置校验。`local` 缺省注入 Product
`http://127.0.0.1:8769` 与 Agent `http://127.0.0.1:8010`；`staging` /
`production` 必须显式传入两个非 loopback HTTPS URL。直接调用裸
`flutter build` 不具备这层 fail-closed 门禁，不应用于分发产物。

当前本机验证：

```text
[x] local debug APK `build/app/outputs/flutter-apk/app-local-debug.apk` 可生成
[x] staging release APK `build/app/outputs/flutter-apk/app-staging-release.apk` 可生成
```
