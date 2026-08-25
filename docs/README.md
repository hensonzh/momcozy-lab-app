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
- Flutter CI/CD 与 staging 发布：`flutter/ci-cd.md`
- Android APK GitHub Releases 分发：`flutter/android-apk-github-releases.md`
- Flutter 发布 gate：`flutter/release-gate.md`
- Flutter 安全隐私 gate：`flutter/security-privacy-gates.md`
- Flutter staging smoke：`flutter/staging-smoke.md`
- Flutter 真机与真泵 smoke：`flutter/p0-smoke-checklist.md`
- App UI/UX V3 更新方案：`flutter/ui-ux-v3-update-plan.md`
- BLE 设备协议：`device/设备APP蓝牙通信协议.md`
- Product Backend 合同快照：`backend-contract/product.openapi.generated.json`
- Agent Runtime 合同快照：`backend-contract/agent-runtime.openapi.generated.json`
- 后端合同交接说明：`backend-contract/api-contract-handoff.md`
- Flutter client compatibility：`backend-contract/flutter-client-compatibility.md`
- 合并基线与能力门禁：`flutter/unified-app-integration.md`

Product Backend 和 Agent Runtime 是独立的合同来源。App 提交两份快照，并通过
`python3 scripts/validate_backend_contract.py` 校验服务归属、鉴权、幂等、
查询参数和 Agent Runtime pattern；任何一侧的破坏性变更都需要协调 App
版本和兼容窗口。
