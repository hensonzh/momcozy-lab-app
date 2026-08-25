# Flutter 安全与隐私准入

## 范围

MomCozy App 会处理妈妈、宝宝、泵奶、喂养、成长、健康问题、语音和咨询数据。Flutter 客户端及其原生集成必须按同一敏感数据等级处理。

## P0 阻塞门槛

启用 Android platform channel 能力前，必须满足：

```text
[x] Flutter 侧提供统一日志脱敏工具：`core/privacy/log_redactor.dart`
[x] Flutter 测试覆盖 token/user/conversation/session/device id 脱敏
[x] Native fake failure stream 使用统一脱敏工具
[x] HTTP/SSE/WS/voice client 接入统一脱敏工具后才能输出请求日志；release gate 已加入 `make flutter-security-check`
[x] Android platform channel event/failure log 不输出原始 device id、pump request body 或通知正文；release gate 已加入静态检查
[x] token/secret 不落普通 preferences；Flutter session bootstrap 已接入 secure storage，dart-define 仅作为 dev/staging fallback
[x] crash/perf report 接入前必须有敏感字段 denylist；`redactCrashReport()`/`redactCrashContext()` 已覆盖 free-form message、用户、会话、设备、健康容器
[x] Flutter telemetry / diagnostics 接入前必须走统一脱敏事件模型；`MomCozyObservability` 已覆盖 route、API、Agent lifecycle、feature event 和 non-fatal event，默认 Noop sink 不外发
[x] fixtures、golden、截图不得包含真实用户数据；`fixture_privacy_test.dart` 已纳入完整 Flutter test gate
```

## 日志规则

允许记录：

```text
method name
route name
HTTP status
business error code
retryable flag
elapsed time
payload shape / field count
redacted URL
redacted failure payload
```

禁止记录：

```text
Authorization
token / bearerToken / accessToken / refreshToken
user_id / userId
conversation_id / conversationId / threadId / sessionId
deviceId / bleDeviceId
完整妈妈/宝宝/健康/喂养/泵奶 payload
语音原文、转写全文、咨询全文
本地文件路径中可识别用户身份的片段
```

Flutter 日志脱敏统一使用：

```dart
redactLogMap(payload)
redactLogValue(value)
redactUrlForLog(url)
isSensitiveLogKey(key)
```

## Transport 安全规则

```text
[x] 生产和候选包只允许 HTTPS / WSS；HTTP/WS 仅允许 localhost/127.0.0.1/::1 开发入口
[x] SSE、WebSocket 与 voice transport 都必须复用同一 auth injection 和 redacted logging
[x] 明确 dev endpoint allowlist，避免 release 包连接本地/明文地址
[x] upload、voice、agent stream、device reminder 断线日志只输出 redacted URL、payload shape 或错误码
```

当前进展：

```text
[x] Agent stream SSE/WebSocket transport shell 已复用 `AgentStreamEndpoint` 做 token/header 注入，并通过 `redactedLogContext()` 接入统一脱敏工具
[x] Agent voice API 已复用 `TransportSecurityPolicy`，并提供 redacted realtime stream/session log context
```

## 存储规则

```text
[x] token、refresh token、长期 session secret 进入 secure storage
[x] demo/dev user id 明确标记 dev-only，不作为正式身份体系；正式 session 由 `MomCozySession`/secure store 管理
[x] 账户偏好通过 `userScopedStorageKey()` 按 user scope 隔离
[x] 多用户切换清理 chat、calibration、device、pending route、pump runtime scoped cache；`MomCozySessionManager.switchAccount()` 先调用 `MomCozyScopedCacheStore`
[x] 登出/删除用户后清理 scoped cache 和 native pending state；logout 已接入 `MomCozyScopedCacheStore`，账户删除流程必须复用同一 hook
```

## Native Bridge 规则

```text
[x] `PumpAgentUploadPlatform` fake failure payload 已脱敏
[x] Android `MmcBle` event log 不输出原始 device id，必要时使用短 hash
[x] Pump foreground service notification payload 不包含 token/user/conversation；静态 gate 禁止 foreground notice 携带 `EXTRA_NOTIFY_JSON`
[x] Native pending route 只传 event type 和必要 route，不传完整业务 payload；`PumpNavigationBridge` 会 sanitize `notifyJson`
[x] Native upload/background request 日志只输出 payload shape；failure log 不回传 token/user/conversation 明文
```

## 验收命令

```bash
flutter test test/core/privacy/log_redactor_test.dart
flutter test test/native/p0_platform_interfaces_test.dart
make flutter-security-check
```

进入核心迁移前，完整 gate 至少执行：

```bash
make flutter-check
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443 \
make flutter-release-gate
```
