# Flutter 安全与隐私准入

## 范围

MomCozy App 会处理妈妈、宝宝、泵奶、喂养、成长、健康问题、语音和咨询数据。Flutter 迁移期间，Web/Capacitor baseline 和 Flutter PoC 必须按同一敏感数据等级处理。

## P0 阻塞门槛

进入 Android platform channel PoC 前，必须满足：

```text
[x] Flutter 侧提供统一日志脱敏工具：`core/privacy/log_redactor.dart`
[x] Flutter 测试覆盖 token/user/conversation/session/device id 脱敏
[x] Native fake failure stream 使用统一脱敏工具
[ ] HTTP/SSE/WS client 接入统一脱敏工具后才能输出请求日志
[ ] Android platform channel event/failure log 接入统一脱敏工具
[x] token/secret 不落普通 preferences；Flutter session bootstrap 已接入 secure storage，dart-define 仅作为 dev/staging fallback
[ ] crash/perf report 接入前必须有敏感字段 denylist
[ ] fixtures、golden、截图不得包含真实用户数据
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
[ ] 生产和候选包只允许 HTTPS / WSS
[ ] SSE 与 WebSocket transport 都必须复用同一 auth injection 和 redacted logging
[ ] 明确 dev endpoint allowlist，避免 release 包连接本地/明文地址
[ ] upload、voice、agent stream、device reminder 断线日志只输出 redacted URL 和错误码
```

当前进展：

```text
[x] Agent stream SSE/WebSocket transport shell 已复用 `AgentStreamEndpoint` 做 token/header 注入，并通过 `redactedLogContext()` 接入统一脱敏工具
```

## 存储规则

```text
[x] token、refresh token、长期 session secret 进入 secure storage
[ ] demo/dev user id 明确标记 dev-only，不作为正式身份体系
[ ] conversation/thread id 迁移时按 user scope 隔离
[ ] 多用户切换清理 chat、calibration、device、pending route、pump runtime scoped cache
[ ] 登出/删除用户后清理 scoped cache 和 native pending state；当前已覆盖 secure session token 清理
```

## Native Bridge 规则

```text
[x] `PumpAgentUploadPlatform` fake failure payload 已脱敏
[ ] Android `MmcBle` event log 不输出原始 device id，必要时使用短 hash
[ ] Pump foreground service notification payload 不包含 token/user/conversation
[ ] Native pending route 只传 event type 和必要 route，不传完整业务 payload
[ ] Native upload failure 只回传 method/code/retryable/redacted payload
```

## 验收命令

```bash
cd flutter_app
flutter test test/core/privacy/log_redactor_test.dart
flutter test test/native/p0_platform_interfaces_test.dart
```

进入核心迁移前，完整 gate 至少执行：

```bash
npm run flutter:check
npm run flutter:release-gate
```
