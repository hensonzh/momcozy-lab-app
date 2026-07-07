# Flutter Auth 自动续期方案

目标：用户使用 App 时，短效 access token 过期不应打断普通业务流程。客户端应自动使用 refresh token 换取新的 token pair，更新安全存储和运行时 session，并重试原请求一次。只有 refresh token 失效、撤销或复用风险时，用户才需要重新登录。

## 1. 验收标准

- JSON 业务请求返回 `401 authentication_required` 或 access-token 过期类错误时，自动调用 `/v1/auth/refresh`。
- 同一时间多个请求同时遇到 401 时，只发起一次 refresh，其余请求等待同一个结果。
- refresh 成功后：
  - 更新 `FlutterSecureMomCozySessionStore`。
  - 更新 `MomCozyRuntimeController` 当前 session。
  - 使用新 access token 重试原请求一次。
  - 用户不看到登录过期提示。
- refresh 失败、缺少 refresh token、refresh token 过期或复用检测时：
  - 将 session 标记为 `expired` 或 `revoked`。
  - 清空 access/refresh token。
  - 触发路由 guard 回到 `/login`。
  - 用户看到重新登录入口。
- 原请求最多重试一次，避免循环 refresh。
- refresh 请求本身不走 refresh-aware transport，避免递归。
- 日志、错误和 telemetry 不输出 access token、refresh token 或 Authorization 明文。

## 2. 客户端结构

```text
feature repository
  -> AuthenticatedApiJsonTransport
    -> attach current access token
    -> send request
    -> if 401 auth error:
       -> MomCozySessionRefreshCoordinator.refresh()
       -> update secure store
       -> notify MomCozyRuntimeController
       -> retry once with fresh token
    -> return response / throw mapped error
```

`MomCozySessionRefreshCoordinator` 继续作为唯一 refresh lock。它负责复用并发 refresh、写入新 session、缺少 refresh token 时标记 session expired。

## 3. 覆盖范围

本机制按“请求级 401 兜底 + session runtime 热替换”的方式覆盖：

- `ApiJsonTransport`：业务 JSON API、登录后页面同步、records/status/schedule/device 等。
- `ApiMultipartTransport`：文件上传、图片上传。
- Agent SSE run create / stream / cancel / action 的 Authorization 头动态读取当前 session token。
- voice/transcribe 相关 API：分片转写走 multipart 自动续期；实时语音 HTTP/WS 在建连时动态读取当前 session token。
- native pump upload token provider：启动 native runtime 时使用当前 session token。

已登录用户不会因为普通 access token 过期被打断；只有 refresh token 不存在、过期、被撤销或后端拒绝 refresh 时，才会更新为 expired session 并交给路由 guard 返回登录页。

## 4. 测试计划

- Unit：refresh coordinator 并发、缺 token、refresh 成功写 store。
- Unit：refresh-aware JSON transport 401 后 refresh 并重试，且 header 使用新 token。
- Unit：并发 401 请求共享同一次 refresh。
- Unit：refresh-aware multipart transport 401 后 refresh 并重试。
- Unit：Agent endpoint 和 realtime voice header 懒读取最新 token。
- Unit：refresh 失败后 session expired 并触发 runtime 更新。
- Runtime：`MomCozyRuntimeController` session 更新后 router guard 可回登录页。
- Regression：普通非 401 HTTP 错误不触发 refresh。

## 5. 后续增强

当前后端返回 `expires_in`，后续可在 `MomCozySession` 中保存 `accessTokenExpiresAt`，在请求前提前刷新，减少一次 401 往返。本轮先实现 401 兜底自动续期，保证用户无感恢复。
