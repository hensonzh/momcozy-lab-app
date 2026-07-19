# Flutter Staging Smoke

## 目标

`tool/staging_smoke.dart` 用于在不连接真机、不连接真泵的前提下，验证 Flutter runtime 可以直接访问后端 staging：

- 只读 HTTP：Status、Schedule、Records。
- 显式启用后才执行的写入类探针：Pump workstate、client-event、Hospital Bag cart、Media upload。
- 显式启用后才执行的 Agent SSE 文本流探针。

默认不运行真实后端请求，避免本地和 CI 在没有凭证时误写数据。

## 本地命令

```bash
dart run tool/staging_smoke.dart
```

默认输出应为 skipped。

## 真实 Staging Smoke

只读探针：

```bash
MOMCOZY_STAGING_SMOKE=1 \
MOMCOZY_API_BASE_URL=https://staging-api.example.com \
MOMCOZY_API_TOKEN=replace-with-staging-token \
MOMCOZY_DEFAULT_USER_ID=replace-with-staging-user \
MOMCOZY_DEFAULT_BABY_ID=replace-with-staging-baby \
dart run tool/staging_smoke.dart
```

包含写入探针：

```bash
MOMCOZY_STAGING_SMOKE_MUTATE=1
```

包含 Agent SSE 文本流：

```bash
MOMCOZY_STAGING_SMOKE_AGENT=1
MOMCOZY_AGENT_RUNS_URL=https://staging-api.example.com/v1/agent/runs
```

## 退出码

- 全部通过或全部被显式跳过：`0`
- 任一探针失败：`1`

## 安全边界

- token 通过 `Authorization: Bearer ...` 注入，不写入日志。
- smoke 失败信息会脱敏 Bearer token 和 `token=` query 参数。
- 写入类探针必须显式设置 `MOMCOZY_STAGING_SMOKE_MUTATE=1`。
- Agent 文本流必须显式设置 `MOMCOZY_STAGING_SMOKE_AGENT=1`。
