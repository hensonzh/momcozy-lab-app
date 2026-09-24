# momcozy AI iOS / App Store 发布交接文档

> **文档定位：** 这是后续智能体处理 iOS 签名、TestFlight、App Store 提审与发布时的唯一入口文档。先读本文件，再按需阅读同目录下的专项草稿。
>
> **最后核验日期：** 2026-09-24
>
> **当前结论：** 本地 iOS Release 无签名构建已经成功，但正式 Bundle ID、Apple 签名、生产 API、登录策略、推送、支付合规、正式图标和商店资料尚未全部就绪，当前绝对不能上传或提交审核。

---

## 0. 下一位智能体先做什么

进入仓库后，先执行以下只读检查，不要直接修改、清理或上传：

```bash
cd /Users/lute/project/momcozy-lab/app
pwd
git status --short --branch
git log -5 --oneline --decorate
git diff --check
grep '^version:' pubspec.yaml
flutter --version
xcodebuild -version
security find-identity -v -p codesigning
```

然后依次确认：

1. 用户是否已经给出**最终 Bundle ID**。
2. Apple 团队是普通的 **Apple Developer Program（Organization）**，还是只用于内部分发的 **Apple Developer Enterprise Program**。
3. App Store Connect 中是否已经创建新的 `momcozy AI` App 记录。
4. 当前用户是否已获得该 App 的访问权限，以及 `Certificates, Identifiers & Profiles` 权限。
5. 生产 Product API 和 Agent API 是否已经确认。
6. Google 登录、Sign in with Apple、推送和 Stripe 的首发策略是否已经决定。
7. 工作区是否仍有未提交改动；不要覆盖或回滚用户的工作。

任何一项没有确认，都只能继续做本地准备，不能跨越对应发布门禁。

---

## 1. 项目目标与背景

### 1.1 发布目标

- Flutter 工程：`/Users/lute/project/momcozy-lab/app`
- App Store 正式名称：`momcozy AI`
- 发布类型：**全新的 App Store App**
- 不是更新任何已有的 Momcozy 商店条目
- 当前计划：优先内部 TestFlight，验证通过后再提交 App Review
- 推荐发布控制：审核通过后由团队**手动发布**，不要首版自动上线

### 1.2 用户 Apple 账号现状

用户提供的 App Store Connect 权限截图表明，当前角色是 **Developer**。可见能力包括：

- 上传构建版本；
- 管理内部 TestFlight 构建和内部测试员；
- 查看指标和诊断；
- 查看 App 隐私信息；
- 对商店素材、元数据、能力等大多是只读权限。

因此当前账号通常可以在 App 已存在并被分配后上传构建、做内部 TestFlight，但不能独立完成以下工作：

- 创建新的 App Store Connect App；
- 完整编辑 App Store 元数据；
- 提交 App Review；
- 正式发布；
- 处理部分合同、税务或协议。

推荐让团队管理员执行以下一种方案：

- **方案 A（推荐）：** 将用户提升为 `App Manager`，并开放 `Certificates, Identifiers & Profiles`；
- **方案 B：** 保留 `Developer`，由 Admin/App Manager 创建 App、配置 Bundle ID、编辑元数据并最终提交审核，用户只负责签名构建、上传和内部 TestFlight。

另外必须确认团队 Membership 类型。公开 App Store 上架要求使用普通 Apple Developer Program 团队；Apple Developer Enterprise Program 仅用于企业内部员工分发，不能代替公开 App Store 团队。

### 1.3 已确认和未确认的产品标识

| 项目 | 当前状态 |
| --- | --- |
| Store 名称 | 已确认：`momcozy AI` |
| iOS 桌面显示名称 | 已改为 `momcozy AI` |
| Flutter 标题 | 已改为 `momcozy AI` |
| Android 显示名称 | 已同步为 `momcozy AI` |
| 正式 Bundle ID | **待公司确认** |
| 当前临时 Bundle ID | `com.momcozymai.app.flutterpoc`，禁止默认作为正式值 |
| 当前版本 | `1.0.0+57` |
| SKU 建议 | `momcozy-ai-ios`，最终由 App Store 管理员确认 |

Bundle ID 是 Apple 生态中的不可随意替换身份。创建 App Store Connect App 之后，不能把同一商店记录改成另一个 Bundle ID。必须在创建 App ID、App Store 记录、Google OAuth、Firebase 和 APNs 之前一次性确认。

---

## 2. 当前仓库与本机快照

以下是 2026-09-24 最后一次核验结果，下一位智能体必须重新运行命令确认是否发生变化。

### 2.1 Git 状态

```text
仓库：/Users/lute/project/momcozy-lab/app
分支：main
本交接准备开始时的基线 HEAD：cbfb231180b904c01a739c99adc88896d03ba7f3
基线短 SHA：cbfb2311
基线相对 origin/main：ahead 3
```

本交接文档提交后 HEAD/ahead 数会变化，接手时必须以 `git rev-parse HEAD` 和 `git status --short --branch` 的实时结果为准。

当前私有源码没有得到“允许推送 origin”的授权。不要自行 push。

当前工作区仍有未提交的发布准备改动，主要包括：

- iOS、Flutter、Android 显示名称改为 `momcozy AI`；
- 发布脚本和 Android 包装检查中的显示名称同步；
- 修复安全隐私检查仍引用已删除 Agent voice 文件的问题；
- 删除遗留且引用已删除场景的 `integration_test/mom_home_handoff_test.dart`；
- 少量 `dart format` 格式修复；
- `docs/ios/` 下的发布、隐私、元数据和本交接文档目前是未跟踪文件。

在准备本次提交时还检测到另一组并发的登录页视觉调整，包括 `design-contract/login/`、`lib/features/auth/presentation/auth_login_chrome.dart`、`test/features/auth/login_visual_contract_test.dart` 和相关 auth Golden。这组修改不属于 iOS 发布交接提交，已明确保留在工作区且未暂存。接手时先重新检查它们是否已由对应工作流提交，不要误删或混入发布提交。

不要使用以下命令清理工作区：

```bash
# 禁止直接执行
# git reset --hard
# git clean -fd
# git checkout -- .
```

先用 `git diff` 审核，再决定如何拆分提交。

### 2.2 工具链

| 工具 | 当前版本/状态 |
| --- | --- |
| Flutter | 3.44.4 stable |
| Dart | 3.12.2 |
| Xcode | 26.6，Build 17F113 |
| iOS SDK（已构建产物） | iPhoneOS 26.5 |
| 最低 iOS | 15.0 |
| 架构 | arm64 |
| CocoaPods | 未安装 |
| Fastlane | 未安装 |
| App Store Connect API Key | 未配置 |
| 有效代码签名证书 | 0 |
| Provisioning Profile | 0 |

当前 iOS 工程使用 Flutter Swift Package Manager 集成，本地无 CocoaPods 仍完成了完整无签名构建。因此 CocoaPods 不是当前立即阻塞项；但新增插件或 Flutter 工具链变化若回退到 CocoaPods，需要安装后重新验证。

当前没有 Fastlane、`ExportOptions.plist` 或 iOS 自动上传脚本。首个版本推荐先使用 Xcode 自动签名和 Organizer，稳定后再引入自动化。

### 2.3 现有发布工具的边界

仓库已有的以下脚本主要服务 Android APK、GitHub Release 和下载页，不是 iOS/App Store 发布入口：

```text
scripts/build-flutter-app.sh
scripts/build-flutter-android-apk.mjs
scripts/build-flutter-apk-download-site.mjs
```

不要为了发布 iOS 而调用这些脚本，也不要把 Android GitHub Release 视为 App Store 发布。当前仓库没有正式的 iOS 自动发布流水线；iOS 第一版应按本文使用 Xcode Archive/Organizer。

本次没有部署或变更后端。无签名预检只编入了下面两个 test 地址：

```text
https://backend-test.lute-momcozylab.luteos.cloud:8443
https://agent-test.lute-momcozylab.luteos.cloud:8443
```

它们不是已经批准的 App Store 生产地址。正式发布前必须由后端/平台负责人提供生产地址、发布状态、可用性和兼容性证据。

仓库/技能中的旧发布说明可能引用 `/Users/lute/project/momcozy/...` 等历史路径，实际工程路径以当前仓库 `/Users/lute/project/momcozy-lab/app` 为准。

### 2.4 Xcode 工程关键值

```text
PRODUCT_BUNDLE_IDENTIFIER = com.momcozymai.app.flutterpoc
CURRENT_PROJECT_VERSION = 57
IPHONEOS_DEPLOYMENT_TARGET = 15.0
TARGETED_DEVICE_FAMILY = 1,2
CODE_SIGN_IDENTITY = iPhone Developer
DEVELOPMENT_TEAM = 未配置
```

说明：

- `TARGETED_DEVICE_FAMILY = 1,2` 表示同时支持 iPhone 和 iPad；
- 如果保持 iPad 支持，必须做 iPad 真机/模拟器验收并准备 iPad 截图；
- 如果首版只做 iPhone，需要显式修改并执行回归，不要只在 App Store Connect 中忽略 iPad。

### 2.5 本机 Apple 凭证

```text
有效签名身份：0
Provisioning Profile：0
Xcode Team：未配置
App Store Connect API Key：未配置
```

在用户通过 Xcode 登录公司 Apple 账号、管理员完成团队权限和 App ID 之前，不能生成可安装或可上传的正式 IPA。

---

## 3. 已完成的本地工作与证据

### 3.1 名称统一

已完成：

- `ios/Runner/Info.plist`：`CFBundleDisplayName = momcozy AI`
- `lib/app/momcozy_app.dart`：Flutter title 为 `momcozy AI`
- Android main/local/unified/production 显示名称为 `momcozy AI`
- 构建脚本、下载页和原生配置测试同步

测试文件：

```text
test/app/momcozy_native_launch_config_test.dart
```

注意：内部 Dart package 名称 `momcozy_flutter_app` 和 iOS `CFBundleName` 仍为工程内部名称，不是商店用户可见名称，不需要仅为上架而强行重命名。

### 3.2 代码质量门禁

最后一次结果：

```text
dart format：615 files，0 changed
flutter analyze --no-pub：No issues found
安全隐私检查：通过
Android packaging 检查：通过
非视觉测试：816 passed
```

非视觉测试之所以使用独立筛选，是因为当前多数 Golden 测试文件并没有正确添加 `golden` tag。仓库文档中的：

```bash
flutter test --exclude-tags=golden
```

并不能可靠排除全部视觉测试。这是现有测试基础设施缺口，不要误判为已解决。

当前可靠的非视觉测试命令：

```bash
python3 - <<'PY'
from pathlib import Path
import subprocess

files = []
for path in sorted(Path('test').rglob('*_test.dart')):
    text = path.read_text(errors='ignore')
    if 'matchesGoldenFile' not in text:
        files.append(str(path))

raise SystemExit(subprocess.call(['flutter', 'test', '--no-pub', *files]))
PY
```

### 3.3 Visual/Golden 状态

最后一次完整 `flutter test` 观察到：

```text
passed：1614
skipped：6
failed：250
```

失败主要是大范围 Golden 像素差异，以及 Golden 失败后测试继续交互导致的 `Bad state: No element`。独立复跑 Agent 页面 Golden 后仍可稳定复现视觉差异。

处理原则：

- 不要批量执行 `--update-goldens`；
- 不要因为无签名 iOS 构建成功就忽略视觉回归；
- 应按最终品牌、字体、登录页和页面设计逐组审核；
- Golden 更新必须有视觉对比证据和产品/设计确认。

当前 `cbfb2311` 已提交登录页重设计和相关 Golden，下一位智能体仍应在最终 RC 前重新跑完整视觉测试，不能只引用历史结果。

### 3.4 iOS 无签名 Release 构建

已成功执行：

```bash
flutter build ios \
  --release \
  --no-codesign \
  --no-pub \
  --build-name=1.0.0 \
  --build-number=57 \
  --dart-define=MOMCOZY_ENV=test \
  --dart-define=MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

结果：

```text
build/ios/iphoneos/Runner.app
约 121 MiB on disk
arm64
iOS 15.0+
```

保存的预检包：

```text
build/ios/preflight/momcozy-ai-ios-unsigned-1.0.0-57.zip
SHA-256: 96d8e2db9bbe61e03653fdefb04e3224cdcc875d2632431500105eb2c43ff944
```

**该产物禁止上传或外部分发**，原因：

- 未签名；
- Bundle ID 仍是临时值；
- 编入测试 Product/Agent API；
- Google iOS URL Scheme 解析为空；
- 推送未配置；
- 图标仍是 Flutter 默认图标。

---

## 4. 已知问题与发布阻塞矩阵

| 优先级 | 问题 | 当前状态 | 必须由谁确认/处理 | 未解决时的限制 |
| --- | --- | --- | --- | --- |
| P0 | 正式 Bundle ID | 未确认 | 公司 Apple 管理员/产品负责人 | 不能创建 App ID、ASC App、OAuth、Firebase 或正式签名 |
| P0 | Apple 团队类型 | 未明确验证 | Account Holder/Admin | 若只有 Enterprise Program，不能公开上架 |
| P0 | 创建新 App Store Connect App | 未创建 | Admin/App Manager | Developer 不能独立完成完整流程 |
| P0 | 本机签名身份和 Team | 均为空 | Apple 管理员 + 用户 | 不能生成签名 Archive/IPA |
| P0 | 生产 Product API / Agent API | 未确认 | 后端/平台负责人 | 不能构建 App Store RC |
| P0 | 正式 App Icon | 当前是 Flutter 默认图标 | 品牌/设计 | 不应提交审核 |
| P0 | 登录策略 | Google 已露出，但 iOS 配置缺失；Apple 登录未实现 | 产品/后端/iOS | 容易构建失败或审核被拒 |
| P0 | 推送策略 | entitlement 已开，Firebase/APNs 未配置 | 产品/后端/iOS | 必须配置并真机验证，或首版关闭 |
| P0 | Stripe 合规分类 | 未确认 | 产品/法务 | 数字内容若外部付款会有审核风险 |
| P0 | 隐私政策/App Privacy | 仅有工程草稿 | 法务/隐私负责人 | 不能提交审核 |
| P1 | Support URL | 缺失 | 产品/运营 | 商店资料不完整 |
| P1 | 启动页 | 1×1 透明占位图，实际白屏 | 品牌/设计/iOS | 品牌体验不合格 |
| P1 | iPhone/iPad 范围 | 当前 Universal | 产品/QA | 决定截图和测试范围 |
| P1 | Golden 视觉回归 | 大量未审核差异 | 设计/前端/QA | RC 视觉门禁未通过 |
| P1 | App 自有 Privacy Manifest | 尚无 | iOS/隐私 | 签名 Archive 后必须检查隐私报告 |
| P2 | Fastlane/CI | 未建立 | 发布工程 | 首版可用 Xcode 手工完成 |
| P2 | CocoaPods | 未安装 | 本机环境 | 当前 SwiftPM 构建成功；插件变化后再判断 |

---

## 5. 必须做出的产品与合规决策

在改 Bundle ID 或创建 App Store 记录之前，至少把以下内容写成明确结论：

```text
Apple 团队类型：Apple Developer Program Organization / Enterprise Program
最终 Bundle ID：
App Store 主要语言：
首发国家或地区：
是否包含中国大陆：
主分类：Medical / Health & Fitness / 其他
是否保留 iPad：是 / 否
生产 Product API：
生产 Agent API：
登录：邮箱 only / Google + Sign in with Apple
推送：首版启用 / 首版关闭
Stripe 对应商品：仅同步一对一人工服务 / 包含数字内容
发布：审核后手动发布 / 自动发布
Support URL：
隐私政策是否明确覆盖该 App：是 / 否
品牌方是否批准名称和图标：是 / 否
```

### 5.1 推荐的首版降风险方案

如果目标是尽快完成第一版上架，推荐：

- 首版先采用邮箱注册/登录；
- 暂时隐藏 Google 登录，避免同时实施 Sign in with Apple 和 OAuth 配置；
- 推送若无法完成真实 APNs/FCM 验证，则首版关闭 entitlement 和后台通知模式；
- Stripe 只有在法律确认所有付费项目均为同步一对一人工服务后保留；
- 先支持 iPhone，若 iPad 未充分设计和测试则明确改为 iPhone only；
- 使用公开受信任 TLS 的生产 API；
- 先内部 TestFlight，再提交审核；
- 审核通过后手动发布。

该方案只是工程建议，不能代替产品和法务决策。

---

## 6. Apple 侧完整准备方案

### 6.1 确认 Membership 和权限

管理员需要确认：

1. 团队是可公开上架的 Apple Developer Program 组织账号；
2. 公司协议、税务和付费协议状态正常；
3. 用户至少被分配到新 App；
4. 用户有签名资源访问权限；
5. 若用户要独立填写元数据和提交审核，角色调整为 App Manager 或 Admin。

### 6.2 注册 Explicit App ID

Bundle ID 最终确认后，由有权限的人在 Certificates, Identifiers & Profiles 中：

1. 新建 `Identifiers > App IDs > App`；
2. Description 建议使用 `momcozy AI`；
3. Bundle ID 选择 Explicit；
4. 只启用首版真正需要的 capabilities。

能力建议：

| Capability | 何时启用 |
| --- | --- |
| Push Notifications | 只有首版配置并验证 APNs/FCM 时 |
| Sign in with Apple | 保留 Google 等第三方登录时 |
| Associated Domains | 当前没有外部 Deep Link；以后需要再开 |
| Background Modes | 在 Xcode 中只保留 Remote notifications 等实际需要项 |
| Game Center | 当前不需要，不要因截图中的账号权限而误开启 |

### 6.3 创建 App Store Connect App

由 Admin/App Manager 创建：

```text
Platform: iOS
Name: momcozy AI
Primary Language: 待产品确认
Bundle ID: 最终 Explicit Bundle ID
SKU: 建议 momcozy-ai-ios
User Access: 分配给当前 Developer 用户
```

注意：

- App Store 名称需要全局可用；若 `momcozy AI` 不可用，需要产品决定商店名称变体；
- 设备上的 `CFBundleDisplayName` 仍可保持 `momcozy AI`；
- 创建记录前再次核对 Bundle ID，因为绑定后不可替换。

### 6.4 Xcode 登录和自动签名

用户在 Xcode 中：

1. `Xcode > Settings > Accounts` 登录公司 Apple 账号；
2. 确认能看到正确团队；
3. 打开 `ios/Runner.xcworkspace`；
4. Runner target > Signing & Capabilities；
5. 选择正确 Team；
6. 首版建议勾选 Automatically manage signing；
7. 确认 Release 使用 Apple Distribution/App Store provisioning；
8. 不要选择个人团队或错误企业团队。

完成后重新检查：

```bash
security find-identity -v -p codesigning
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -showBuildSettings | egrep 'DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN|PROVISIONING'
```

---

## 7. Flutter/iOS 工程改造方案

### 7.1 Bundle ID

优先通过 Xcode 修改 Runner target 的 Bundle Identifier，不要只做字符串替换。必须同步检查：

- Runner Debug/Profile/Release；
- RunnerTests 的 Bundle ID；
- App ID；
- App Store Connect；
- Firebase iOS App；
- Google iOS OAuth Client；
- APNs；
- 后续 Universal Links/Associated Domains。

当前临时值出现于：

```text
ios/Runner.xcodeproj/project.pbxproj
```

修改后验证：

```bash
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER
```

### 7.2 版本与 Build Number

版本源是：

```yaml
# pubspec.yaml
version: 1.0.0+57
```

Xcode 使用 `$(FLUTTER_BUILD_NAME)` 和 `$(FLUTTER_BUILD_NUMBER)`，不要另行手改 Info.plist 中版本。

规则：

- App Store 同一版本中的 build number 不能重复；
- 预检无签名 build 57 没有上传，不会占用 App Store build number；
- 但每个真正准备上传的 RC 应拥有唯一 build number；
- 创建 App Store 记录后先查询已存在 build，再确定最终编号；
- 建议把上传 build 的版本变更单独提交。

### 7.3 生产环境编译参数

当前默认值是本地 loopback，因此正式构建必须显式提供：

```text
MOMCOZY_ENV=production
MOMCOZY_API_BASE_URL=https://<production-product-api>
MOMCOZY_AGENT_API_BASE_URL=https://<production-agent-api>
```

推荐把非代码配置放在不进入 Git 的 JSON 文件，并使用：

```bash
flutter build ipa \
  --release \
  --build-name=<version> \
  --build-number=<build> \
  --dart-define-from-file=/secure/path/momcozy-ai-ios-production.json
```

示例文件结构：

```json
{
  "MOMCOZY_ENV": "production",
  "MOMCOZY_API_BASE_URL": "https://product.example.com",
  "MOMCOZY_AGENT_API_BASE_URL": "https://agent.example.com",
  "MOMCOZY_GOOGLE_SERVER_CLIENT_ID": "...",
  "MOMCOZY_GOOGLE_IOS_CLIENT_ID": "...",
  "MOMCOZY_FIREBASE_API_KEY": "...",
  "MOMCOZY_FIREBASE_APP_ID": "...",
  "MOMCOZY_FIREBASE_SENDER_ID": "...",
  "MOMCOZY_FIREBASE_PROJECT_ID": "..."
}
```

不要把该文件、`.p8` 私钥、密码或 token 提交到仓库。

### 7.4 测试 CA 与正式 TLS

仓库包含：

```text
assets/certificates/momcozy-test-internal-ca.pem
```

代码只在以下条件全部满足时启用该测试 CA：

- `MOMCOZY_ENV=test`；
- HTTPS；
- 精确匹配两个 test host；
- 端口 8443。

生产构建必须使用 `MOMCOZY_ENV=production` 和公开受信任的生产 TLS。构建后必须确认：

- 没有 `127.0.0.1`；
- 没有错误 test endpoint；
- 只有预期生产域名；
- 生产路径不会启用内部 CA。

可执行：

```bash
rg -a -n '127\.0\.0\.1|backend-test|agent-test|https://<expected-production-host>' \
  build/ios/archive/Runner.xcarchive \
  build/ios/ipa 2>/dev/null
```

测试 CA 证书不是私钥，但生产包是否继续携带该资源应由安全负责人决定；最少要求是生产路径绝不激活它。

### 7.5 App Icon 和 Launch Screen

当前状态：

- AppIcon 槽位齐全；
- 1024×1024 marketing icon 没有 alpha；
- 但图像内容仍是 Flutter 默认 Logo；
- LaunchImage 三个文件均是 1×1 透明图，启动页实际接近纯白。

正式发布前：

1. 由品牌提供 1024×1024、无透明通道、无圆角蒙版的原始 App Icon；
2. 生成并检查全部 iPhone/iPad icon 尺寸；
3. 更新 LaunchScreen，保持简单、静态、无误导内容；
4. 真机检查浅色/深色模式、冷启动和首帧切换；
5. 更新 `test/app/momcozy_native_launch_config_test.dart` 中对应校验哈希；
6. 不要把 Android 192 px 图标放大为 App Store 图标。

### 7.6 Google 登录与 Sign in with Apple

当前：

- UI 显示 `Continue with Google`；
- Dart 端需要 server client ID 和 iOS client ID；
- `ios/Flutter/GoogleAuth.xcconfig` 不存在；
- 模板是 `ios/Flutter/GoogleAuth.xcconfig.example`；
- 无签名包中的 Google URL Scheme 为空；
- Sign in with Apple 尚未实现。

如果保留 Google：

1. 用最终 Bundle ID 创建 Google iOS OAuth Client；
2. 创建本地且被忽略的 `ios/Flutter/GoogleAuth.xcconfig`；
3. 填入 reversed client ID；
4. 构建时提供 Google server/iOS client ID；
5. 实现 Sign in with Apple 的客户端和后端 token 校验/账号绑定；
6. 测试首次登录、取消、错误账号、账号关联、注销和账号删除。

如果首版不做 Apple 登录：

1. 从 iOS 首版 UI 隐藏 Google 登录；
2. 移除或避免输出空的 Google URL Scheme；
3. 保留邮箱登录；
4. 更新测试、截图、审核说明和隐私披露。

不要发布“看得到 Google 按钮但点击后不可用”的构建。

### 7.7 推送通知

当前工程：

- `Runner.entitlements` 包含 `aps-environment`；
- Release 为 production；
- Info.plist 包含 `remote-notification`；
- Firebase Messaging 使用 Dart defines 初始化；
- 没有真实 Firebase/APNs 项目配置和真机验证。

启用方案：

1. 最终 Bundle ID 开启 Push Notifications；
2. Firebase 创建匹配 Bundle ID 的 iOS App；
3. 将 APNs Authentication Key 配入 Firebase；
4. 提供四个 Firebase Dart defines；
5. 使用签名真机验证权限、APNs token、FCM token、前台、后台、点击路由、token refresh、登出和账号切换；
6. 确认通知内容不泄露敏感母婴/健康数据。

关闭方案：

- 删除/关闭 Push capability；
- 移除 `aps-environment`；
- 移除不需要的 `remote-notification` background mode；
- 确保 UI 对通知不可用状态有正确降级。

### 7.8 Stripe 与 Apple IAP

客户端存在外部 Stripe Checkout 流程。提审前必须书面确认：

- Stripe 购买是否全部对应同步的一对一人工专业服务；
- 是否存在数字内容、AI 权益、订阅、群组服务或功能解锁；
- 付款后 App 内获得的权益是什么；
- 审核账号如何在不真实扣款的情况下验证。

如果包含数字内容或 App 功能权益，应由产品/法务评估 Apple In-App Purchase，不要仅凭客户端当前实现直接提交。

### 7.9 iPhone / iPad

当前为 Universal。两种合法路径：

**保留 iPad：**

- 检查所有关键页面、横竖屏、键盘、媒体、支付和视频咨询；
- 提供 iPad 截图；
- 在 iPad 真机或对应模拟器完成 RC smoke。

**改为 iPhone only：**

- 修改 Targeted Device Family；
- 重新 Archive；
- 检查 Designed for iPad 行为和商店设备兼容性；
- 更新截图及测试计划。

---

## 8. 隐私、医疗与商店合规方案

### 8.1 App Privacy

客户端代码显示 App 可能处理：

- 邮箱、显示名称、账号 ID；
- 妈妈和宝宝健康/照护记录；
- AI 对话和笔记；
- 图片、视频、音频、PDF、头像；
- 设备/安装标识和推送 token；
- 日程、预约、服务订单和支付状态；
- 安全诊断信息。

完整工程草稿见：

```text
docs/ios/app-privacy-draft.md
```

该文档只代表客户端代码审计。最终 App Privacy 必须同时核对：

- 生产后端字段；
- 数据库、对象存储和备份；
- AI 提供商是否保留或训练；
- Firebase、LiveKit/WebRTC、Stripe、邮件、监控和客服系统；
- 数据保留、删除和跨境处理；
- 宝宝数据的监护人授权与删除规则。

### 8.2 权限说明

Info.plist 已有：

- Camera；
- Microphone；
- Photo Library。

现有说明为中文。首发市场若包含英语地区，建议配置本地化 `InfoPlist.strings`，不要让英文系统界面只显示中文权限说明。

### 8.3 账号删除

App 内已实现账号删除入口，但后端和法务必须确认：

- 删除的是完整账号，不只是清理本地 token；
- AI 对话、上传媒体、宝宝数据、推送安装记录如何处理；
- 依法保留的服务/付款记录及期限；
- 用户是否能看到删除请求状态；
- 审核员无需联系客服即可发起删除。

### 8.4 隐私政策与条款

当前登录页链接：

```text
https://momcozy.com/pages/privacy-security
https://momcozy.com/pages/terms-conditions
```

2026-09-24 检查均返回 HTTP 200。但可访问不等于已满足该 App 的披露。法务必须确认覆盖：

- AI 输入、输出、模型提供商和训练政策；
- 妈妈/宝宝健康数据；
- 媒体与文档上传；
- 视频咨询和专家访问；
- motion camera/audio 处理；
- 推送与设备标识；
- Stripe/服务订单；
- 跨境传输；
- 账号删除和保留；
- 支持与隐私联系渠道。

### 8.5 医疗健康定位

商店文案和审核说明应明确：

- App 提供记录、信息整理、AI 支持和可用的专业服务；
- 不替代医生诊断；
- 不用于紧急医疗；
- 对高风险建议应引导联系合格专业人士或当地急救服务。

避免在没有相应证据和监管审查时使用“诊断、治疗、保证改善”等强医疗声明。

### 8.6 Privacy Manifest / 第三方 SDK

无签名包已包含 Flutter、WebRTC、Firebase、Google Sign-In 和若干插件的 Privacy Manifest；App 自身目前没有 `PrivacyInfo.xcprivacy`。

正式签名 Archive 后必须：

1. 在 Xcode Organizer 生成/检查 Privacy Report；
2. 查看 Required Reason API 警告；
3. 确认所有列入 Apple 清单的 SDK 版本和签名要求；
4. 必要时添加 App 自有 `PrivacyInfo.xcprivacy`；
5. 保证 manifest、App Privacy 问卷和真实数据处理一致。

### 8.7 中国大陆等地区

若将中国大陆加入可售地区，需要由公司法务/运营确认当时适用的 App 备案、许可、健康/医疗、生成式 AI、隐私和跨境数据要求。工程智能体不能默认勾选中国大陆，也不能把“技术可上传”当作“地区合规已完成”。

---

## 9. 商店资料与审核准备

元数据草稿见：

```text
docs/ios/app-store-metadata-draft.md
```

提交前需要最终确认：

- App 名称和副标题；
- 简体中文/英文描述；
- 关键词；
- 主/次分类；
- 年龄评级问卷；
- Support URL；
- Privacy Policy URL；
- Copyright；
- 价格和地区；
- 出口合规；
- 内容版权；
- App Privacy；
- 审核联系人；
- 审核账号；
- 审核说明；
- iPhone 和可能的 iPad 截图。

截图规则：

- 只用合成账号和合成母婴数据；
- 不展示真实妈妈、宝宝、患者、订单或咨询内容；
- 在最终图标、生产配置和视觉验收后再拍；
- 截图中不得出现测试服务器、Debug Banner、失败占位、内部邀请入口或沙盒支付卡号；
- 审核账号必须稳定，验证码/MFA 要么关闭，要么提供可执行说明。

---

## 10. 推荐发布流水线

### Gate A：身份与产品决策

通过条件：

- 最终 Bundle ID；
- 正确 Apple 团队；
- App Store Connect App 已创建；
- 用户已获得 App 访问和签名权限；
- iPhone/iPad、登录、推送、支付策略已确认。

未通过：禁止创建正式 Archive。

### Gate B：生产配置

通过条件：

- 生产 Product/Agent API 可从公网访问；
- 使用公开受信任 TLS；
- 登录配置完成；
- 推送配置完成或已完全关闭；
- 支付合规路径完成；
- 正式图标、启动页和权限本地化完成；
- Bundle ID 在所有服务一致。

未通过：只允许本地或内部工程测试。

### Gate C：代码质量与视觉

顺序执行，不要与 Flutter build 并发运行：

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test tool
flutter analyze --no-pub
node scripts/check-flutter-security-privacy.mjs
node scripts/check-flutter-android-packaging.mjs
```

然后运行非视觉测试和分组 Golden 审核。所有失败必须归类为：

- 产品回归；
- 预期设计变更并已批准；
- 测试基础设施问题。

未归类失败不得进入 RC。

### Gate D：签名 Archive

推荐首版使用 Xcode：

```bash
open ios/Runner.xcworkspace
```

在 Xcode 中：

1. Runner Scheme；
2. Release；
3. Any iOS Device (arm64)；
4. Product > Archive；
5. Organizer > Validate App；
6. 检查签名、entitlement、隐私和 SDK 警告。

也可在签名已稳定后使用：

```bash
flutter build ipa \
  --release \
  --build-name=<version> \
  --build-number=<build> \
  --dart-define-from-file=/secure/path/momcozy-ai-ios-production.json
```

当前没有可复用的 `ExportOptions.plist`，不要凭经验创建一个未经验证的文件。

### Gate E：归档内容验证

至少验证：

```text
Display Name = momcozy AI
Bundle ID = 最终值
Version/build = 目标值
MinimumOSVersion = 15.0（除非产品决定变化）
签名 Team = 正确公司团队
Provisioning = App Store distribution
aps-environment = production（仅当推送启用）
Google URL Scheme = 正确且非空（仅当 Google 启用）
API endpoints = 生产域名
loopback/test endpoints = 不存在
App Icon = 正式品牌图标
Privacy manifests/report = 无阻断
```

记录：

- Git full SHA；
- dirty/clean 状态；
- Xcode/Flutter 版本；
- Bundle ID；
- Team ID；
- version/build；
- 编译参数文件哈希；
- Archive 路径；
- IPA SHA-256；
- Xcode Validate 结果。

### Gate F：真机 RC 验收

必须使用签名 RC，而不是 Debug 或无签名包。覆盖：

- 冷启动、升级和重装；
- 邮箱注册/验证/登录/重置；
- Google 和 Apple 登录（若启用）；
- 账号删除；
- AI 对话、取消、重试和弱网；
- 图片、视频、PDF 上传与预览；
- 相机、麦克风、相册权限允许/拒绝/设置页恢复；
- 妈妈和宝宝记录；
- 日程和提醒；
- 视频咨询；
- motion assessment；
- 推送前台/后台/点击/登出（若启用）；
- Stripe 购买和返回（若启用）；
- 网络断开、超时、账号切换；
- iPad 全流程（若支持）。

### Gate G：内部 TestFlight

推荐通过 Xcode Organizer 上传：

1. Distribute App；
2. App Store Connect；
3. Upload；
4. 等待处理完成；
5. 处理 export compliance；
6. 分配内部测试组；
7. 至少一台真实设备安装并完成 RC smoke。

当前 `Developer` 角色通常能管理内部 TestFlight，但前提是 App 已创建并分配给该用户。

不要使用已废弃的 `altool`。当前本机也没有 Fastlane 和独立 Transporter 配置。

### Gate H：提交审核

由 App Manager/Admin：

1. 选择通过 TestFlight 验证的同一 build；
2. 填完元数据、截图、隐私、评级和地区；
3. 提供可用审核账号；
4. 对登录、权限、Stripe、AI、视频咨询给出清晰审核步骤；
5. 回答加密/export compliance；
6. 提交 App Review；
7. 选择手动发布。

### Gate I：审核通过与上线

上线前再确认：

- 生产 API readiness；
- 服务监控、告警、客服和删除流程；
- App Store 版本/构建匹配；
- 发布说明；
- 回滚负责人；
- 是否分阶段发布。

首版推荐人工点击发布；不要假设审核通过等于应该立刻上线。

---

## 11. 上传后的故障处理与回滚

### 构建处理失败

- 不要覆盖相同 build number；
- 查看 App Store Connect/Xcode 邮件中的具体错误；
- 修复后增加 build number，重新 Archive 和上传。

### TestFlight 崩溃或关键流程失败

- 停止分配该 build；
- 不提交审核；
- 记录构建 SHA 和复现设备；
- 修复后上传新 build。

### 已提交但未审核

- 可在 App Store Connect 撤回提交；
- 修复并上传新 build；
- 重新选择 build 和提交。

### 审核被拒

- 先判断是元数据、账号、权限、支付、隐私还是功能问题；
- 不要只写解释而不修复可复现缺陷；
- 回复审核团队时提供具体路径和测试账号；
- 代码变化必须使用新 build number。

### 已上线严重问题

- 优先停止分阶段发布或下架新版本；
- 服务端可安全降级的功能使用 feature flag；
- 不要通过关闭认证/隐私校验来“快速修复”；
- 准备修复 build；
- 保留上一版本后端兼容性，避免强制破坏旧客户端。

---

## 12. 安全与秘密管理

禁止在聊天、日志、Git 或截图中暴露：

- Apple ID 密码；
- App Store Connect `.p8` 私钥；
- API key private content；
- Provisioning Profile 内部信息的完整导出；
- 生产 access/refresh token；
- Stripe secret；
- 后端、Firebase 或 AI provider 私钥。

可以报告：

- Team ID；
- Key ID；
- Issuer ID；
- Bundle ID；
- 客户端 ID；
- 凭证是否存在；
- 文件安全路径；
- 非秘密的 API 域名。

当前 `ios/Flutter/GoogleAuth.xcconfig` 已被 `.gitignore` 忽略。创建其他本地配置前先检查是否会被 Git 跟踪。

---

## 13. 文件地图

### 核心 iOS 配置

```text
ios/Runner.xcodeproj/project.pbxproj        Bundle ID、部署目标、签名设置
ios/Runner.xcworkspace                      打开和 Archive 的 workspace
ios/Runner/Info.plist                       显示名称、权限、URL Scheme、后台模式
ios/Runner/Runner.entitlements              APNs entitlement
ios/Flutter/Debug.xcconfig                   Debug entitlement/Google include
ios/Flutter/Release.xcconfig                 Release entitlement/Google include
ios/Flutter/GoogleAuth.xcconfig.example      Google URL Scheme 模板
ios/Runner/Assets.xcassets/AppIcon.appiconset
ios/Runner/Base.lproj/LaunchScreen.storyboard
```

### 运行时配置

```text
lib/app/momcozy_api_runtime.dart
lib/features/agent_hub/agent_hub_runtime.dart
lib/core/network/test_certificate_trust.dart
lib/core/auth/google_sign_in_gateway.dart
lib/features/notifications/data/firebase_push_messaging.dart
```

### 审核高风险功能

```text
lib/features/auth/                          登录、账号删除
lib/modules/services/                       购买与咨询 UI
lib/services/care/                          Stripe Checkout/API
lib/services/consultations/                 LiveKit 视频咨询
lib/features/motion_assessment/             相机、实时语音/姿态
lib/features/notifications/                 APNs/FCM 与通知路由
lib/features/agent_hub/                     AI 对话与媒体上传
```

### 发布资料

```text
docs/ios/ios-app-store-handoff.md           本交接文档
docs/ios/app-store-readiness.md              技术预检与阻塞项
docs/ios/app-store-metadata-draft.md         中英文商店文案/截图/审核草稿
docs/ios/app-privacy-draft.md                App Privacy 工程清单
```

### 当前预检产物

```text
build/ios/iphoneos/Runner.app
build/ios/preflight/momcozy-ai-ios-unsigned-1.0.0-57.zip
build/ios/preflight/momcozy-ai-ios-unsigned-1.0.0-57.zip.sha256
```

这些产物位于 ignored build 目录，不是发布源文件，也不是长期制品仓库。

---

## 14. Git 提交与发布证据建议

在用户确认可以提交后，建议把工作拆成可审计的小提交：

1. `chore(ios): prepare momcozy AI store branding`
2. `fix(test): remove retired mom handoff integration entry`
3. `fix(security): align privacy gate with active motion voice transport`
4. `docs(ios): add App Store release handoff`
5. Bundle ID 确认后：`chore(ios): configure production app identity`
6. 上传 RC 前：`chore(release): bump iOS build to <build>`

不要把用户未授权的其他改动混入发布提交。提交前执行：

```bash
git diff --check
git status --short
git diff --stat
```

私有 `origin` 不应自动 push；必须得到用户明确授权。

每次上传都记录一个 release evidence 文件，至少包含：

```text
source_commit=
bundle_id=
team_id=
version=
build=
flutter_version=
xcode_version=
product_api=
agent_api=
archive_path=
ipa_sha256=
xcode_validation=
testflight_processing=
real_device_smoke=
app_store_submission_id=
```

---

## 15. 下一位智能体的首轮执行清单

### 如果 Bundle ID 仍未确认

只做：

- 重跑本地门禁；
- 推进图标/启动页/视觉审核；
- 整理隐私和商店资料；
- 让管理员确认团队类型和权限；
- 确认生产 API；
- 确认登录、推送、支付和 iPad 策略。

不要做：

- 注册临时 Bundle ID；
- 创建错误 App Store 记录；
- 生成或上传“正式”包；
- 把测试 API 包提交审核。

### 如果 Bundle ID 已确认但 Apple App 未创建

- 让 Admin/App Manager 创建 Explicit App ID 和 App Store Connect App；
- 明确 capabilities；
- 将 App 分配给用户；
- 再配置 Xcode。

### 如果 Apple App 和签名都已准备

按顺序：

1. 修改 Bundle ID/Team；
2. 完成登录、推送和生产参数；
3. 替换图标/启动页；
4. 重跑代码、视觉和真机门禁；
5. Archive + Validate；
6. 内部 TestFlight；
7. 修复问题并上传新 build；
8. 元数据/隐私/审核账号完成后提交审核。

---

## 16. 完成定义

只有以下条件全部满足，才可以报告“iOS 已发布”：

- 新 App 使用确认后的正式 Bundle ID；
- Archive 使用正确公司 Team 和 App Store distribution 签名；
- 正式 IPA 不包含 loopback 或错误 test endpoint；
- 登录、推送、支付按最终策略工作；
- 正式图标、启动页、权限本地化完成；
- 代码门禁、视觉门禁和真实设备 smoke 通过；
- Xcode Validate 无阻断错误；
- TestFlight build 处理成功并完成内部验收；
- App Privacy、隐私政策、元数据、截图和审核账号完成；
- App Manager/Admin 已提交审核；
- Apple 审核通过；
- 团队执行了发布动作，并在目标地区的 App Store 验证可见；
- 生产后端、监控和支持流程正常；
- 已记录最终 commit、version/build、IPA SHA-256 和商店版本链接。

“本地构建成功”“上传成功”“进入 TestFlight”都不等于已经发布。

---

## 17. 官方资料复核入口

Apple 规则会变化。每次准备上传前，应只以 Apple 官方资料和 App Store Connect 当前界面为准，至少复核：

```text
https://developer.apple.com/news/upcoming-requirements/
https://developer.apple.com/app-store/review/guidelines/
https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/
https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/
https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
https://developer.apple.com/support/offering-account-deletion-in-your-app/
https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
https://developer.apple.com/support/third-party-SDK-requirements/
```

截至 2026-09-24，本机 Xcode 26.6 / iOS 26.5 SDK 满足最近一次检查到的提交工具链要求；下一次实际上传前仍必须重新查看 Upcoming Requirements，不能永久依赖本结论。
