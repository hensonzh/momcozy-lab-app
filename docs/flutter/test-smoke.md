# Flutter Test Smoke

## 目标

`tool/test_environment_smoke_test.dart` 用于在不连接真机、不连接真泵的前提下，验证 Flutter runtime 可以直接访问后端 test：

- 只读 HTTP：Status、Schedule、Records。
- 显式启用后才执行的写入类探针：Pump workstate、client-event，以及 Media
  upload/read/byte-compare/delete 的完整对象存储闭环。
- 显式启用后才执行的 Agent SSE 文本流探针。

默认不运行真实后端请求，避免本地和 CI 在没有凭证时误写数据。

## 本地命令

```bash
flutter test --no-pub tool/test_environment_smoke_test.dart
```

默认输出应为 skipped。

## 真实 Test Smoke

只读探针：

```bash
MOMCOZY_TEST_SMOKE=1 \
MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
MOMCOZY_API_TOKEN=replace-with-test-token \
MOMCOZY_DEFAULT_USER_ID=replace-with-test-user \
MOMCOZY_DEFAULT_BABY_ID=replace-with-test-baby \
flutter test --no-pub tool/test_environment_smoke_test.dart
```

包含写入探针：

```bash
MOMCOZY_TEST_SMOKE_MUTATE=1
```

包含 Agent SSE 文本流：

```bash
MOMCOZY_TEST_SMOKE_AGENT=1
MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

## 退出码

- 全部通过或全部被显式跳过：`0`
- 任一探针失败：`1`

## 安全边界

- token 通过 `Authorization: Bearer ...` 注入，不写入日志。
- smoke 失败信息会脱敏 Bearer token 和 `token=` query 参数。
- 写入类探针必须显式设置 `MOMCOZY_TEST_SMOKE_MUTATE=1`。
- Agent 文本流必须显式设置 `MOMCOZY_TEST_SMOKE_AGENT=1`。
- Agent 探针只接受带非空 assistant response 的 `run.completed`；`run.failed`、
  `run.cancelled`、`run.expired` 等终态均失败。
- Product Backend 和 Agent Runtime 探针分别使用 `MOMCOZY_API_BASE_URL` 与
  `MOMCOZY_AGENT_API_BASE_URL`，不会把两个服务折叠到同一 origin。
