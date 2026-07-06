# Flutter 正式取代旧 Web 版推进计划

> 目标：让 `flutter_app/` 成为 MomCozyApp 的正式移动端实现；`legacy_web/` 从主发布链路退为 rollback-only，最终在完成观察窗口后退役。  
> 当前状态：Phase 0 本地非真机 gate 已通过，等待 emulator smoke / Phase 1 外部凭证。
> 结论规则：任何 P0 blocker 未关闭前，不允许正式替代旧 Web/Capacitor 版。

## 1. 范围和原则

### 1.1 替代范围

Flutter 正式替代的用户可见范围包括：

- Agent Hub / 智能体主页。
- 宝宝和我 / Status。
- 计划 / Schedule。
- 设备、设备管理、用户设备配置。
- Pump session、校准、后台通知恢复。
- IBCLC、Media Viewer、Hospital Bag、W1、Community 空态。
- 旧 Web 已退役的 Records 可见路由不作为 Flutter cutover 阻断项；records repository/API contract 继续由测试和 smoke 覆盖。

### 1.2 非目标

- 不在 cutover 前重启旧 Web 新功能开发。
- 不把旧 Web React/TS 测试原封不动迁到 Flutter；以 Flutter widget/golden/fixture/release gate 作为新验收标准。
- 不在缺少 release signing、真机 P0 和 rollback 预案时发布 production cutover 包。

### 1.3 工程原则

- 后端是权威业务状态，Flutter 只保存 UI 状态、缓存、编辑草稿和可恢复 intent。
- Agent UI 消费稳定 stream event，不从自然语言文本反推业务状态。
- Flutter production cutover 必须保留旧 Web rollback artifact，直到灰度观察窗口完成。
- 密钥、token、keystore、真实用户数据和真机日志不得提交到仓库。

## 2. Phase 总览

| Phase | 名称 | 当前状态 | 退出条件 |
|---|---|---|---|
| 0 | 准入冻结和合并 | In progress | `feat/test2` 已合入目标分支，非真机 gate 全绿，emulator smoke 待跑。 |
| 1 | 生产形态补齐 | Pending | appId、release signing、生产/staging env、CI signing gate 明确并可产包。 |
| 2 | 真机 P0 验收 | Blocked by device lab | Android 版本矩阵、BLE、真泵、后台、通知恢复和 Agent stream P0 通过。 |
| 3 | 灰度发布 | Blocked by signed production candidate | internal/alpha/beta/staged rollout 观察指标达标。 |
| 4 | 正式 cutover | Blocked by rollout decision | Flutter 成为唯一正式 App 入口，旧 Web 冻结为 rollback-only。 |
| 5 | 旧版退役 | Blocked by stable observation window | 旧 Web 从默认 CI/npm scripts/发布链路移除，仅保留必要归档和迁移资料。 |

## 3. Phase 0：准入冻结和合并

### 3.1 准入项

- [x] `feat/test2` worktree 干净。
- [x] `feat/test2` 合入目标分支，冲突必须人工确认。
- [x] Flutter 非真机测试通过。
- [x] Flutter release gate 通过。
- [ ] Android emulator smoke 通过。
- [x] rollback manifest 生成。

### 3.2 执行命令

在目标分支合并后执行：

```bash
npm run flutter:check
npm run flutter:release-gate
npm run flutter:emulator-smoke
```

如只需局部确认：

```bash
cd flutter_app
PATH="$HOME/.local/share/momcozy-toolchains/flutter/bin:$PATH" flutter test
```

### 3.3 退出标准

- [x] `flutter test` 全绿。
- [x] `npm run flutter:release-gate` 全绿。
- [ ] `npm run flutter:emulator-smoke` 全绿。
- [ ] 无未提交变更。
- [ ] 无 P0 文档缺口阻断 Phase 1。

### 3.4 当前记录

| Item | Status | Notes |
|---|---|---|
| Agent Hub parity | Passed | 已覆盖多轮历史、失败重试、头像状态、语音输入、自动播放、tool/artifact/action 等。 |
| UI/UX parity | Passed for current scope | 已按当前 golden/widget 范围通过，后续真机仍需人工 spot check。 |
| Non-device tests | Passed | `npm run flutter:check` 和 `npm run flutter:release-gate` 已在目标分支通过。 |
| Release gate | Passed | 已产出 `app-local-debug.apk`、`app-staging-release.apk` 和 `legacy_web/dist/flutter-rollback-manifest.json`。 |
| Emulator smoke | Pending latest target branch run | 合并后重新跑。 |
| Android built-in Kotlin | Partially migrated | app 模块已移除显式 KGP；full built-in Kotlin 被 `flutter_secure_storage 10.3.1` 仍应用 `kotlin-android` 阻断，当前保留 `android.builtInKotlin=false` opt-out。 |

## 4. Phase 1：生产形态补齐

### 4.1 App ID 和 flavor 决策

当前 Flutter flavor：

| Flavor | Application ID | Cutover 决策 |
|---|---|---|
| `local` | `com.momcozymai.app.flutterpoc.local` | 保留开发用途。 |
| `staging` | `com.momcozymai.app.flutterpoc.staging` | 保留 internal/staging 分发用途。 |
| `production` | `com.momcozymai.app.flutterpoc` | 正式替代前必须决定是否改为旧 App 正式包名。 |

决策项：

- [ ] 确认是否沿用旧 Android package name。
- [ ] 确认是否需要同包名覆盖升级旧 Capacitor App。
- [ ] 确认 FileProvider authority、deep link、通知 channel 和 pending intent 与旧包兼容。

### 4.2 Release signing

需要 CI / 发布机注入：

```text
MOMCOZY_FLUTTER_RELEASE_STORE_FILE
MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD
MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS
MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD
```

强制签名 gate：

```bash
MOMCOZY_REQUIRE_RELEASE_SIGNING=1 npm run flutter:release-gate
```

退出标准：

- [ ] production/staging release APK 使用正式 release signing。
- [ ] keystore 不入库。
- [ ] CI 失败日志不打印 secret。

### 4.3 后端和 runtime env

需要确认：

- [ ] `MOMCOZY_API_BASE_URL`
- [ ] 正式登录/session 或 token bootstrap 方案。
- [ ] `MOMCOZY_AGENT_SSE_URL`
- [ ] `MOMCOZY_AGENT_CANCEL_URL`
- [ ] 文件上传、media viewer、client event endpoints。
- [ ] staging smoke 凭证和测试用户。

退出标准：

- [ ] `MOMCOZY_STAGING_SMOKE=1 dart run tool/staging_smoke.dart` 通过。
- [ ] Agent SSE、client event、media upload smoke 通过。
- [ ] 业务错误、HTTP 错误和 token 过期不泄漏敏感信息。

## 5. Phase 2：真机 P0 验收

执行清单来源：

- `docs/flutter/p0-smoke-checklist.md`

### 5.1 设备矩阵

- [ ] Android 11 或以下权限模型。
- [ ] Android 12 BLE runtime permission 模型。
- [ ] Android 13+ notification runtime permission 模型。
- [ ] 低端或内存紧张设备。
- [ ] 厂商深度定制系统设备。
- [ ] 左侧真泵、右侧真泵、双侧真泵。

### 5.2 P0 场景

- [ ] BOOT / AUTH / PERM / BLE / CAL 全部通过。
- [ ] Pump 启动、暂停、恢复、结束、后台、通知恢复通过。
- [ ] summary、milk record、Agent context 只上传一次。
- [ ] 后台 workstate、process data、process upload 和 progress/reply 通过。
- [ ] Agent text stream、tool stream、artifact、取消、断线通过。
- [ ] 日志、截图、crash 不含 token、真实 user id、真实健康数据。

### 5.3 Blocker 规则

以下任一项失败即阻断正式替换：

- Pump session 丢失、重复上传或无法恢复。
- BLE 左右侧串扰。
- Android 13+ 通知权限导致前台服务不可恢复且无降级。
- Agent 无法多轮连续对话。
- 登录/session 跨用户串数据。
- P0 crash 或 ANR。

## 6. Phase 3：灰度发布

### 6.1 渠道

- [ ] Internal build：团队/QA。
- [ ] Alpha：内部业务用户。
- [ ] Beta：小范围真实用户。
- [ ] Staged rollout：5% -> 10% -> 25% -> 50% -> 100%。

### 6.2 监控指标

- crash-free sessions。
- ANR。
- cold start。
- Agent SSE failure rate。
- API 4xx/5xx。
- BLE connection failure。
- Pump session interruption。
- upload duplicate / missing rate。
- notification recovery success rate。

### 6.3 暂停条件

- crash-free 明显低于旧版。
- Pump session 丢失或重复上传。
- BLE 连接失败率异常。
- Agent 无法连续对话。
- 登录/session 异常。
- 大量用户卡在启动页、权限页或主 tab 空态。

## 7. Phase 4：正式 Cutover

### 7.1 执行项

- [ ] 冻结旧 Web/Capacitor 发布。
- [ ] Flutter production 包签名并发布。
- [ ] 旧 Web dist 仅作为 rollback artifact。
- [ ] 后端确认旧 Web API 兼容窗口。
- [ ] Flutter API contract 成为主兼容目标。
- [ ] Release note 说明 native Flutter cutover。

### 7.2 Rollback 预案

必须保留：

- [ ] 上一版旧 Web/Capacitor 发布包或 bundle。
- [ ] `legacy_web/dist/flutter-rollback-manifest.json`。
- [ ] Flutter APK/AAB sha256。
- [ ] 数据迁移幂等说明。
- [ ] 不可逆迁移项清单。

Rollback 触发条件：

- P0 crash/ANR 指标恶化。
- Pump session 数据可靠性问题。
- 大范围登录/session 失败。
- 后端兼容性导致核心页面不可用。

## 8. Phase 5：旧版退役

### 8.1 软退役

- [ ] `legacy_web/` 标记为 rollback-only。
- [ ] 旧 Web 不再接收新功能。
- [ ] 旧 Web 相关 issue 默认转 Flutter。

### 8.2 硬隔离

- [ ] 根目录 `npm run dev/build/test` 默认不再指向旧 Web。
- [ ] CI 默认只跑 Flutter。
- [ ] 旧 Web build/test 移入 rollback job。

### 8.3 清理

- [ ] 删除旧 Web-only docs。
- [ ] 删除旧 Web-only assets。
- [ ] 删除旧 Web-only API wrapper。
- [ ] 保留 migration docs、storage migration fixtures、API contract、rollback manifest。

## 9. 推进日志

| Date | Phase | Action | Result | Commit / Artifact |
|---|---|---|---|---|
| 2026-07-06 | 0 | 创建 cutover 计划 | Done | `docs/flutter/flutter-web-cutover-plan.md` |
| 2026-07-06 | 0 | 合入 `feat/test2` | Done | 无冲突，目标分支提交 `f6e0fa1`。 |
| 2026-07-06 | 0 | Flutter 非真机 release gate | Done | `npm run flutter:release-gate` 通过，rollback manifest 已生成。 |
| 2026-07-06 | 0 | Android KGP app 模块迁移 | Partial | app 模块 KGP 已移除；full built-in Kotlin 等待 `flutter_secure_storage` 支持。 |
