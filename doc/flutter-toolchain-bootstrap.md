# Flutter 工具链启动手册

> 状态：Phase 0 工具链准入手册，本机安装已完成。  
> 范围：确认并记录 Flutter / Android 构建环境，作为 `flutter_app/` 初始化和后续 CI 固定的基线。

---

## 1. 为什么先做这个

当前迁移已经准备好蓝图、API 合同、storage / route / BLE / AG-UI fixtures 和 P0 smoke checklist。创建 Flutter shell 前必须先通过工具链准入；本机已完成这一步。

不要在没有工具链的机器上手工创建半截 `flutter_app/`。半截工程会让后续迁移很难判断是业务问题、模板问题，还是工具链问题。

---

## 2. 准入命令

在 `MomCozyApp/` 下执行：

```bash
npm run flutter:check
```

这个命令只检查环境，不写文件。它会确认：

- `flutter --version --machine` 可执行，且版本匹配 `flutter-toolchain.json`；
- `java -version` 可执行，且 JDK 版本匹配 `flutter-toolchain.json`；
- Android SDK platform、build-tools、NDK、CMake 目录存在；
- `adb version` 是否可用且版本匹配，用于真机 smoke test。

脚本会自动把默认用户目录工具链加入子进程环境：

```text
MOMCOZY_TOOLCHAIN_ROOT 默认值：
/Users/lute/.local/share/momcozy-toolchains
```

如果未来要换安装位置，可以在执行命令前设置 `MOMCOZY_TOOLCHAIN_ROOT`。

版本基线写在仓库根目录：

```text
flutter-toolchain.json
```

当前实测状态：

```text
[x] Flutter SDK 可用：3.44.4 stable
[x] Dart 可用：3.12.2
[x] Java runtime 可用：Temurin OpenJDK 17.0.19+10
[x] Android SDK 可用：platform android-36，build-tools 36.0.0
[x] adb / Android platform-tools 可用：36.0.0-13206524
[x] Gradle debug APK 构建可用
[x] Android licenses 已接受
```

本机工具链安装在：

```text
/Users/lute/.local/share/momcozy-toolchains
```

备注：

- Android platform-tools 37.0.0 的 `adb` 在本机启动会卡住；当前已改用 platform-tools 36.0.0，并把 37.0.0 备份移到工具链根目录外层，避免 `sdkmanager` 误扫描。
- Android Gradle Plugin 9.0.1 默认下载的 Maven AAPT2 在本机也会触发同类 mutex 启动失败；`flutter_app/android/gradle.properties` 已通过 `android.aapt2FromMavenOverride` 固定到 SDK build-tools 36.0.0 自带的 `aapt2`。

---

## 3. 初始化 Flutter shell

当 `npm run flutter:check` 通过后，执行：

```bash
npm run flutter:init
```

它会执行：

```bash
flutter create \
  --platforms=android \
  --org com.momcozymai \
  --project-name momcozy_flutter_app \
  flutter_app
```

安全规则：

- 如果 `flutter_app/pubspec.yaml` 已存在，脚本会跳过创建。
- 如果 `flutter_app/` 存在但没有 `pubspec.yaml`，脚本会拒绝覆盖。
- 初始化完成后再进入 `flutter_app/` 跑 `flutter pub get`、`flutter test` 和 debug APK 构建。

当前本机状态：

```text
[x] `flutter_app/` 已创建
[x] `flutter_app/pubspec.yaml` 已生成
[x] `flutter_app/pubspec.lock` 已生成
```

---

## 4. 版本固定

P0 决策：暂不引入 FVM，采用仓库级 `flutter-toolchain.json` 作为机器可读版本源；本地脚本和后续 CI 镜像都必须按这份文件校验。

当前固定版本：

```text
[x] Flutter framework: 3.44.4 stable
[x] Dart: 3.12.2
[x] Android SDK platform: android-36
[x] Android build-tools: 36.0.0
[x] Android platform-tools: 36.0.0-13206524
[x] JDK: Temurin OpenJDK 17.0.19+10
[x] NDK: 28.2.13676358
[x] CMake: 3.22.1
[x] P0 不采用 FVM；CI 后续读取 `flutter-toolchain.json` 固定版本
```

版本固定位置：

- `flutter_app/README.md`
- `flutter-toolchain.json`
- CI 配置或 release checklist（接入 CI 时必须复用同一文件）

---

## 5. 初始化后第一组验证

初始化后必须先跑这些命令，再开始移植页面：

```bash
cd flutter_app
flutter pub get
flutter test
flutter build apk --debug
```

当前本机验证：

```text
[x] npm run flutter:check
[x] npm run flutter:init
[x] cd flutter_app && flutter test
[x] cd flutter_app && flutter build apk --debug
```

`flutter doctor -v` 当前只剩 iOS/macOS 相关告警：Xcode 未完整安装、CocoaPods 未安装。P0 为 Android-first，这两项不阻塞 Android shell 和 APK 构建。

然后把现有 fixtures 拷贝或链接到 Flutter 测试目录：

```text
test/fixtures/ble
test/fixtures/ag_ui
test/fixtures/api
test/fixtures/storage_migration
test/fixtures/route_intents
```

第一批 Flutter 测试不应该从 UI 开始，而应该先验证：

- BLE 协议 golden bytes；
- AG-UI SSE / WebSocket transport parity；
- API response envelope 和错误模型；
- legacy storage migration；
- route intent 解析和一次性消费。
