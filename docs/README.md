# MomCozyApp 文档目录

本文档目录统一承载 Flutter 工程、后端合同和设备协议资料。后续不要再新增根目录 `doc/`。

## 目录约定

| 目录 | 内容 |
| --- | --- |
| `backend-contract/` | 随后端发布同步、供 Flutter 校验使用的 OpenAPI 和 smoke flows 机器契约。 |
| `device/` | 硬件设备协议资料，例如 BLE 通信协议。 |
| `flutter/` | Flutter 工程化、打包、发布 gate、安全隐私和 staging smoke 文档。 |

## 常用入口

- Flutter Android 打包策略：`flutter/android-packaging.md`
- Android APK GitHub Releases 分发：`flutter/android-apk-github-releases.md`
- Flutter 发布 gate：`flutter/release-gate.md`
- Flutter 安全隐私 gate：`flutter/security-privacy-gates.md`
- Flutter staging smoke：`flutter/staging-smoke.md`
- Flutter 真机与真泵 smoke：`flutter/p0-smoke-checklist.md`
- App UI/UX V3 更新方案：`flutter/ui-ux-v3-update-plan.md`
- BLE 设备协议：`device/设备APP蓝牙通信协议.md`
- 后端合同快照：`backend-contract/openapi.generated.json`
- 后端合同交接说明：[MomCozyAgent API contract handoff](https://github.com/hensonzh/MomCozyAgent/blob/main/docs/api-contract-handoff.md)
- Flutter client compatibility：[MomCozyAgent Flutter compatibility](https://github.com/hensonzh/MomCozyAgent/blob/main/docs/flutter-client-compatibility.md)

人读合同以 MomCozyAgent 仓库为唯一来源，本仓库不维护手工副本。

在两个仓库相邻检出时，运行 `make backend-contract-validate-source`。该
门禁会逐字节比对 Agent 的 OpenAPI 与 smoke-flow 源文件，并继续校验
关键路径、查询参数、鉴权和幂等要求；CI 若使用其他目录，可通过
`BACKEND_SOURCE_REPO=/path/to/MomCozyAgent` 指定检出位置。单仓库环境可用
`make backend-contract-validate` 校验已提交快照。

GitHub 的 `backend-contract` gate 会对比 MomCozyAgent `main`，因此破坏性契约
变更应先合并 Agent，再合并携带新快照的 App。
