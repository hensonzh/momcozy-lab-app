# App 文档目录

本文档目录统一承载 Flutter 工程、后端合同和设备协议资料。后续不要再新增根目录 `doc/`。

## 目录约定

| 目录 | 内容 |
| --- | --- |
| `backend-contract/` | 生产后端 OpenAPI 快照、Flutter client compatibility 和 smoke flows。 |
| `device/` | 硬件设备协议资料，例如 BLE 通信协议。 |
| `flutter/` | Flutter 工程化、打包、发布 gate、安全隐私和 staging smoke 文档。 |

## 常用入口

- Flutter Android 打包策略：`flutter/android-packaging.md`
- Android APK 自建下载页：`flutter/android-apk-self-hosting.md`
- Flutter 发布 gate：`flutter/release-gate.md`
- Flutter 安全隐私 gate：`flutter/security-privacy-gates.md`
- Flutter staging smoke：`flutter/staging-smoke.md`
- Flutter 真机与真泵 smoke：`flutter/p0-smoke-checklist.md`
- BLE 设备协议：`device/设备APP蓝牙通信协议.md`
- Product 合同快照：`backend-contract/product.openapi.generated.json`
- Agent Runtime 合同快照：`backend-contract/agent-runtime.openapi.generated.json`
- 后端合同交接说明：`backend-contract/api-contract-handoff.md`
- Flutter client compatibility：`backend-contract/flutter-client-compatibility.md`
